use crate::{
    database::AppDatabase,
    utils::{parse_oid, Id, ParseIdError},
};
use skyzen::extract::Extractor;
use skyzen::utils::{cookie::Cookie, State};
use skyzen::{
    header::{self, HeaderMap},
    Request,
};
use sqlx::Row;

#[derive(Clone)]
pub struct Auth {
    uid: Id,
    group: Id,
    session_id: Id,
    database: AppDatabase,
}

#[derive(Clone)]
pub struct AuthSession {
    database: State<AppDatabase>,
    headers: HeaderMap,
}

fn expired_error() -> AuthError {
    AuthError::SessionExpired
}

pub async fn get_group_id(database: &AppDatabase, name: &str) -> Option<Id> {
    let row = sqlx::query(
        database
            .sql("SELECT id FROM groups WHERE code = ?1")
            .as_ref(),
    )
    .bind(name)
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error");

    row.map(|row| {
        row.get::<String, _>("id")
            .parse()
            .expect("Corrupted group ID")
    })
}

impl Auth {
    pub fn uid(&self) -> Id {
        self.uid.clone()
    }

    pub fn session_id(&self) -> Id {
        self.session_id
    }

    pub async fn match_authority(&self, authority: &str) -> Result<bool, AuthError> {
        match_group_authority(&self.database, &self.group, authority).await
    }

    pub async fn ensure_authority(&self, authority: &str) -> Result<(), AuthError> {
        if self.match_authority(authority).await? {
            Ok(())
        } else {
            Err(AuthError::Forbidden)
        }
    }
}

#[skyzen::error]
pub enum AuthError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Auth failed", status = FORBIDDEN)]
    Forbidden,

    #[error("Database should be provided", status = INTERNAL_SERVER_ERROR)]
    DatabaseMissing,

    #[error("{0}")]
    ParseId(#[from] ParseIdError),
}

impl Extractor for AuthSession {
    type Error = AuthError;
    async fn extract(request: &mut Request) -> Result<Self, Self::Error> {
        let database = request.extensions().get::<State<AppDatabase>>().cloned();
        let headers = request.headers().clone();
        let database = database.ok_or(AuthError::DatabaseMissing)?;
        Ok(AuthSession { database, headers })
    }
}
skyzen::ignore_openapi!(AuthSession);

impl AuthSession {
    pub async fn into_auth(self) -> Result<Auth, AuthError> {
        auth(&self.database, &self.headers).await
    }
}

async fn auth(database: &AppDatabase, headermap: &HeaderMap) -> Result<Auth, AuthError> {
    let cookies = headermap
        .get(header::COOKIE)
        .ok_or_else(expired_error)?
        .as_bytes();
    let cookie_str = std::str::from_utf8(cookies).map_err(|_| AuthError::SessionExpired)?;
    let cookie = Cookie::split_parse_encoded(cookie_str)
        .find_map(|cookie| {
            if let Ok(cookie) = cookie {
                if cookie.name() == "session" {
                    return Some(cookie);
                }
            }
            None
        })
        .ok_or_else(expired_error)?;
    let session_id = parse_oid(cookie.value())?;
    let session_hex = session_id.to_string();
    let pool = database.sqlx();

    let session = sqlx::query(
        database
            .sql("SELECT user_id FROM sessions WHERE id = ?1")
            .as_ref(),
    )
    .bind(&session_hex)
    .fetch_optional(pool)
    .await
    .expect("Database error")
    .ok_or_else(expired_error)?;
    let uid_hex: String = session.try_get("user_id").map_err(|_| expired_error())?;
    let uid = uid_hex.parse().map_err(|_| expired_error())?;

    let user_row = sqlx::query(
        database
            .sql("SELECT group_id FROM users WHERE id = ?1")
            .as_ref(),
    )
    .bind(&uid_hex)
    .fetch_optional(pool)
    .await
    .expect("Database error")
    .ok_or_else(expired_error)?;
    let group_hex: String = user_row.get("group_id");
    let group = group_hex.parse().map_err(|_| expired_error())?;

    Ok(Auth {
        uid,
        group,
        session_id,
        database: database.clone(),
    })
}

async fn match_group_authority(
    database: &AppDatabase,
    group: &Id,
    authority: &str,
) -> Result<bool, AuthError> {
    let group_hex = group.to_string();
    let pool = database.sqlx();

    if let Some(row) = sqlx::query(
        database
            .sql("SELECT allow_all_authorities FROM groups WHERE id = ?1")
            .as_ref(),
    )
    .bind(&group_hex)
    .fetch_optional(pool)
    .await
    .expect("Database error")
    {
        let allow_all: i64 = row.get("allow_all_authorities");
        if allow_all != 0 {
            return Ok(true);
        }
    } else {
        return Ok(false);
    }

    let has_authority = sqlx::query(
        database
            .sql("SELECT 1 FROM group_authorities WHERE group_id = ?1 AND authority = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(&group_hex)
    .bind(authority)
    .fetch_optional(pool)
    .await
    .expect("Database error")
    .is_some();

    Ok(has_authority)
}
