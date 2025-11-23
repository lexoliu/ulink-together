use crate::{
    database::AppDatabase,
    utils::{sha256, ApiMessage, Id},
};

use serde::Deserialize;
use skyzen::utils::cookie::{Cookie, CookieJar};
use skyzen::utils::Json;
use skyzen::{extract::ClientIp, utils::State};
use sqlx::Row;
use std::net::IpAddr;
use time::{Duration, OffsetDateTime};
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub(crate) struct Form<'a> {
    email: std::borrow::Cow<'a, str>,
    password: String,
}

pub async fn handler(
    database: State<AppDatabase>,
    ip: ClientIp,
    mut cookies: CookieJar,
    form: Json<Form<'_>>,
) -> Result<(ApiMessage, CookieJar), LoginError> {
    let Json(form) = form;

    let users = sqlx::query("SELECT id, password_hash, salt FROM users WHERE email = ?1")
        .bind(form.email.as_ref())
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error");

    let row = users.ok_or(LoginError::NotFound)?;
    let user_id: String = row.get("id");
    let password_hash: String = row.get("password_hash");
    let salt: String = row.get("salt");

    if sha256(form.password + &salt) == password_hash {
        let session = generate_session(&database, &user_id, ip.0).await;
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
        return Err(LoginError::WrongPassword);
    }

    Ok(((ApiMessage::new("Login successfully")), cookies))
}

async fn generate_session(database: &AppDatabase, uid_hex: &str, ip: IpAddr) -> String {
    let session_id = Id::new().to_string();

    sqlx::query("INSERT INTO sessions (id, user_id, generated_at, ip) VALUES (?1, ?2, ?3, ?4)")
        .bind(&session_id)
        .bind(uid_hex)
        .bind(OffsetDateTime::now_utc().to_string())
        .bind(ip.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    session_id
}

#[skyzen::error]
pub enum LoginError {
    #[error("User not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Wrong email or password", status = FORBIDDEN)]
    WrongPassword,
}
