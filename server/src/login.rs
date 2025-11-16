use crate::{
    database::AppDatabase,
    utils::{sha256, ApiMessage},
};
use bson::oid::ObjectId;
use serde::Deserialize;
use skyzen::utils::cookie::{Cookie, CookieJar};
use skyzen::utils::Json;
use skyzen::Result;
use skyzen::{extract::ClientIp, utils::State, Error, StatusCode};
use sqlx::Row;
use std::net::IpAddr;
use time::{Duration, OffsetDateTime};

#[derive(Debug, Deserialize)]
pub(crate) struct Form<'a> {
    email: std::borrow::Cow<'a, str>,
    password: String,
}

pub async fn handler(
    database: State<AppDatabase>,
    ip: ClientIp,
    mut cookies: CookieJar,
    form: Json<Form<'_>>,
) -> Result<(ApiMessage, CookieJar)> {
    #[derive(Deserialize)]
    struct UserRow {
        id: String,
        password_hash: String,
        salt: String,
    }
    let Json(form) = form;

    let users = sqlx::query("SELECT id, password_hash, salt FROM users WHERE email = ?1")
        .bind(form.email.as_ref())
        .fetch_optional(database.sqlx())
        .await?;

    let row =
        users.ok_or_else(|| Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;
    let user_id: String = row.try_get("id")?;
    let password_hash: String = row.try_get("password_hash")?;
    let salt: String = row.try_get("salt")?;

    if sha256(form.password + &salt) == password_hash {
        let session = generate_session(&database, &user_id, ip.0).await?;
        cookies.add(
            Cookie::build(("uid", user_id.clone()))
                .expires(OffsetDateTime::now_utc() + Duration::weeks(2))
                .path("/")
                .build(),
        );
        cookies.add(
            Cookie::build(("session", session))
                .expires(OffsetDateTime::now_utc() + Duration::weeks(2))
                .http_only(true)
                .path("/")
                .build(),
        );
    } else {
        return Err(Error::msg("Wrong email or password").set_status(StatusCode::FORBIDDEN));
    }

    Ok(((ApiMessage::new("Login successfully")), cookies))
}

async fn generate_session(
    database: &AppDatabase,
    uid_hex: &str,
    ip: IpAddr,
) -> skyzen::Result<String> {
    let session_id = ObjectId::new().to_hex();

    sqlx::query("INSERT INTO sessions (id, user_id, generated_at, ip) VALUES (?1, ?2, ?3, ?4)")
        .bind(&session_id)
        .bind(uid_hex)
        .bind(OffsetDateTime::now_utc().to_string())
        .bind(ip.to_string())
        .execute(database.sqlx())
        .await?;

    Ok(session_id)
}
