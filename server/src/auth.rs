use bson::oid::ObjectId;
use skyzen::extract::Extractor;
use skyzen::utils::{cookie::Cookie, State};
use skyzen::{
    header::{self, HeaderMap},
    Error, Request, StatusCode,
};
use sqlx::Row;

use crate::{database::AppDatabase, utils::parse_oid};

#[derive(Clone)]
pub struct Auth {
    uid: ObjectId,
    group: ObjectId,
    database: AppDatabase,
}

#[derive(Clone)]
pub struct AuthSession {
    database: State<AppDatabase>,
    headers: HeaderMap,
}

fn expired_error() -> skyzen::Error {
    Error::msg("Session expired").set_status(StatusCode::FORBIDDEN)
}

pub async fn get_group_id(
    database: &AppDatabase,
    name: &str,
) -> Result<Option<ObjectId>, sqlx::Error> {
    let row = sqlx::query("SELECT id FROM groups WHERE code = ?1")
        .bind(name)
        .fetch_optional(database.sqlx())
        .await?;
    Ok(row
        .and_then(|row| row.try_get::<String, _>("id").ok())
        .and_then(|hex| ObjectId::parse_str(hex).ok()))
}

impl Auth {
    pub fn uid(&self) -> ObjectId {
        self.uid.clone()
    }

    pub async fn match_authority(&self, authority: &str) -> skyzen::Result<bool> {
        match_group_authority(&self.database, &self.group, authority).await
    }

    pub async fn ensure_authority(&self, authority: &str) -> skyzen::Result<()> {
        if self.match_authority(authority).await? {
            Ok(())
        } else {
            Err(Error::msg("Auth failed").set_status(StatusCode::FORBIDDEN))
        }
    }
}

#[skyzen::error]
pub enum AuthSessionError {
    #[error("Database should be provided", status = 500)]
    DatabaseMissing,
}

impl Extractor for AuthSession {
    type Error = AuthSessionError;
    async fn extract(request: &mut Request) -> Result<Self, Self::Error> {
        let database = request.extensions().get::<State<AppDatabase>>().cloned();
        let headers = request.headers().clone();
        let database = database.ok_or(AuthSessionError::DatabaseMissing)?;
        Ok(AuthSession { database, headers })
    }
}

impl AuthSession {
    pub async fn into_auth(self) -> skyzen::Result<Auth> {
        auth(&self.database, &self.headers).await
    }
}

async fn auth(database: &AppDatabase, headermap: &HeaderMap) -> skyzen::Result<Auth> {
    let cookies = headermap
        .get(header::COOKIE)
        .ok_or_else(expired_error)?
        .as_bytes();
    let cookie = Cookie::split_parse_encoded(core::str::from_utf8(cookies)?)
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
    let session_hex = session_id.to_hex();
    let pool = database.sqlx();

    let session = sqlx::query("SELECT user_id FROM sessions WHERE id = ?1")
        .bind(&session_hex)
        .fetch_optional(pool)
        .await?
        .ok_or_else(expired_error)?;
    let uid_hex: String = session.try_get("user_id").map_err(|_| expired_error())?;
    let uid = ObjectId::parse_str(&uid_hex).map_err(|_| expired_error())?;

    let user_row = sqlx::query("SELECT group_id FROM users WHERE id = ?1")
        .bind(&uid_hex)
        .fetch_optional(pool)
        .await?
        .ok_or_else(expired_error)?;
    let group_hex: String = user_row.try_get("group_id").map_err(|_| expired_error())?;
    let group = ObjectId::parse_str(&group_hex).map_err(|_| expired_error())?;

    Ok(Auth {
        uid,
        group,
        database: database.clone(),
    })
}

async fn match_group_authority(
    database: &AppDatabase,
    group: &ObjectId,
    authority: &str,
) -> skyzen::Result<bool> {
    let group_hex = group.to_hex();
    let pool = database.sqlx();

    if let Some(row) = sqlx::query("SELECT allow_all_authorities FROM groups WHERE id = ?1")
        .bind(&group_hex)
        .fetch_optional(pool)
        .await?
    {
        let allow_all: i64 = row.try_get("allow_all_authorities").unwrap_or(0);
        if allow_all != 0 {
            return Ok(true);
        }
    } else {
        return Ok(false);
    }

    let has_authority = sqlx::query(
        "SELECT 1 FROM group_authorities WHERE group_id = ?1 AND authority = ?2 LIMIT 1",
    )
    .bind(&group_hex)
    .bind(authority)
    .fetch_optional(pool)
    .await?
    .is_some();

    Ok(has_authority)
}
