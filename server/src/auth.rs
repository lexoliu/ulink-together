use crate::{
    database::AppDatabase,
    utils::{parse_oid, Id, ParseIdError},
};
use serde::{Deserialize, Serialize};
use skyzen::extract::Extractor;
use skyzen::routing::Params;
use skyzen::utils::{cookie::Cookie, State};
use skyzen::{
    header::{self, HeaderMap},
    utils::Json,
    Request,
};
use sqlx::Row;
use utoipa::ToSchema;

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

#[derive(Debug, Serialize, ToSchema)]
pub struct GroupAuthoritySummary {
    pub code: String,
    pub allow_all_authorities: bool,
    pub authorities: Vec<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateGroupAuthoritiesForm {
    pub allow_all_authorities: bool,
    pub authorities: Vec<String>,
}

#[skyzen::error]
pub enum GroupAuthorityApiError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid group code", status = BAD_REQUEST)]
    InvalidGroupCode,

    #[error("Group not found", status = NOT_FOUND)]
    GroupNotFound,

    #[error("Invalid authority name", status = BAD_REQUEST)]
    InvalidAuthorityName,
}

#[skyzen::openapi]
pub async fn list_groups(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<Json<Vec<GroupAuthoritySummary>>, GroupAuthorityApiError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => GroupAuthorityApiError::SessionExpired,
        _ => GroupAuthorityApiError::Forbidden,
    })?;
    auth.ensure_authority("manage_authority_anyway")
        .await
        .map_err(|_| GroupAuthorityApiError::Forbidden)?;

    let groups = sqlx::query(
        database
            .sql("SELECT id, code, allow_all_authorities FROM groups ORDER BY code ASC")
            .as_ref(),
    )
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut result = Vec::with_capacity(groups.len());
    for group in groups {
        let group_id: String = group.try_get("id").expect("Database error");
        let authority_rows = sqlx::query(
            database
                .sql("SELECT authority FROM group_authorities WHERE group_id = ?1 ORDER BY authority ASC")
                .as_ref(),
        )
        .bind(&group_id)
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");
        let authorities = authority_rows
            .into_iter()
            .map(|row| {
                row.try_get::<String, _>("authority")
                    .expect("Database error")
            })
            .collect::<Vec<_>>();
        result.push(GroupAuthoritySummary {
            code: group.try_get("code").expect("Database error"),
            allow_all_authorities: group
                .try_get::<i64, _>("allow_all_authorities")
                .expect("Database error")
                != 0,
            authorities,
        });
    }

    Ok(Json(result))
}

#[skyzen::openapi]
pub async fn update_group(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
    form: Json<UpdateGroupAuthoritiesForm>,
) -> Result<Json<GroupAuthoritySummary>, GroupAuthorityApiError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => GroupAuthorityApiError::SessionExpired,
        _ => GroupAuthorityApiError::Forbidden,
    })?;
    auth.ensure_authority("manage_authority_anyway")
        .await
        .map_err(|_| GroupAuthorityApiError::Forbidden)?;

    let code = params
        .get("code")
        .map_err(|_| GroupAuthorityApiError::InvalidGroupCode)?;
    let code = code.trim();
    if code.is_empty() {
        return Err(GroupAuthorityApiError::InvalidGroupCode);
    }
    let Json(form) = form;

    let mut authorities = std::collections::BTreeSet::new();
    for authority in form.authorities {
        let trimmed = authority.trim();
        if trimmed.is_empty() {
            return Err(GroupAuthorityApiError::InvalidAuthorityName);
        }
        authorities.insert(trimmed.to_string());
    }

    let group_row = sqlx::query(
        database
            .sql("SELECT id FROM groups WHERE code = ?1 LIMIT 1")
            .as_ref(),
    )
    .bind(code)
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(GroupAuthorityApiError::GroupNotFound)?;
    let group_id: String = group_row.try_get("id").expect("Database error");

    let mut tx = database.sqlx().begin().await.expect("Database error");
    sqlx::query(
        database
            .sql("UPDATE groups SET allow_all_authorities = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind(if form.allow_all_authorities { 1 } else { 0 })
    .bind(&group_id)
    .execute(&mut *tx)
    .await
    .expect("Database error");
    sqlx::query(
        database
            .sql("DELETE FROM group_authorities WHERE group_id = ?1")
            .as_ref(),
    )
    .bind(&group_id)
    .execute(&mut *tx)
    .await
    .expect("Database error");
    for authority in &authorities {
        sqlx::query(
            database
                .sql("INSERT INTO group_authorities (group_id, authority) VALUES (?1, ?2)")
                .as_ref(),
        )
        .bind(&group_id)
        .bind(authority)
        .execute(&mut *tx)
        .await
        .expect("Database error");
    }
    tx.commit().await.expect("Database error");

    Ok(Json(GroupAuthoritySummary {
        code: code.to_string(),
        allow_all_authorities: form.allow_all_authorities,
        authorities: authorities.into_iter().collect(),
    }))
}
