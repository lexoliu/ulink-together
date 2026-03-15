use crate::{
    auth::AuthSession,
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

#[skyzen::openapi]
pub async fn handler(
    database: State<AppDatabase>,
    ip: ClientIp,
    mut cookies: CookieJar,
    form: Json<Form<'_>>,
) -> Result<(ApiMessage, CookieJar), LoginError> {
    let Json(form) = form;

    let users = sqlx::query(
        database
            .sql("SELECT id, password_hash, salt FROM users WHERE email = ?1")
            .as_ref(),
    )
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

#[skyzen::error]
pub enum LogoutError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,
}

#[skyzen::openapi]
pub async fn logout(
    database: State<AppDatabase>,
    session: AuthSession,
    mut cookies: CookieJar,
) -> Result<(ApiMessage, CookieJar), LogoutError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| LogoutError::SessionExpired)?;

    sqlx::query(database.sql("DELETE FROM sessions WHERE id = ?1").as_ref())
        .bind(auth.session_id().to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    cookies.remove(Cookie::build(("uid", "")).path("/").build());
    cookies.remove(
        Cookie::build(("session", ""))
            .http_only(true)
            .path("/")
            .build(),
    );

    Ok((ApiMessage::new("Logout successfully"), cookies))
}

async fn generate_session(database: &AppDatabase, uid_hex: &str, ip: IpAddr) -> String {
    let session_id = Id::new().to_string();

    sqlx::query(
        database
            .sql("INSERT INTO sessions (id, user_id, generated_at, ip) VALUES (?1, ?2, ?3, ?4)")
            .as_ref(),
    )
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::build_test_database;
    use skyzen::utils::{Json, State};
    use sqlx::Row;
    use std::net::IpAddr;
    use std::str::FromStr;

    async fn setup_db_with_user(email: &str, password: &str) -> (AppDatabase, String) {
        let database = build_test_database().await;
        let user_id = Id::new().to_string();
        let salt = "salty";
        let password_hash = sha256(password.to_string() + salt);
        let group_id = Id::new().to_string();

        sqlx::query(
            database
                .sql(
                    r#"
            INSERT INTO users (
                id,
                email,
                realname,
                gender,
                description,
                classname,
                password_hash,
                salt,
                group_id
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            "#,
                )
                .as_ref(),
        )
        .bind(&user_id)
        .bind(email)
        .bind("Tester")
        .bind("other")
        .bind("")
        .bind("Class A")
        .bind(password_hash)
        .bind(salt)
        .bind(group_id)
        .execute(database.sqlx())
        .await
        .expect("insert user");

        (database, user_id)
    }

    #[tokio::test]
    async fn login_success_sets_cookies_and_session() {
        let (database, user_id) = setup_db_with_user("login@example.com", "secret").await;
        let form = Form {
            email: std::borrow::Cow::Borrowed("login@example.com"),
            password: "secret".to_string(),
        };
        let cookies = CookieJar::from_str("").expect("cookie jar");
        let ip = ClientIp(IpAddr::from([127, 0, 0, 1]));

        let (_message, jar) = handler(State(database.clone()), ip, cookies, Json(form))
            .await
            .unwrap();
        assert_eq!(jar.get("uid").unwrap().value(), user_id);
        assert!(jar.get("session").is_some());

        let sessions = sqlx::query("SELECT user_id FROM sessions")
            .fetch_all(database.sqlx())
            .await
            .expect("fetch sessions");
        assert_eq!(sessions.len(), 1);
        let stored_user_id: String = sessions[0].get("user_id");
        assert_eq!(stored_user_id, user_id);
    }

    #[tokio::test]
    async fn login_returns_wrong_password() {
        let (database, _user_id) = setup_db_with_user("login2@example.com", "secret").await;
        let form = Form {
            email: std::borrow::Cow::Borrowed("login2@example.com"),
            password: "not-secret".to_string(),
        };
        let cookies = CookieJar::from_str("").expect("cookie jar");
        let ip = ClientIp(IpAddr::from([127, 0, 0, 1]));

        let result = handler(State(database), ip, cookies, Json(form)).await;
        assert!(matches!(result, Err(LoginError::WrongPassword)));
    }

    #[tokio::test]
    async fn login_returns_not_found() {
        let database = build_test_database().await;
        let form = Form {
            email: std::borrow::Cow::Borrowed("missing@example.com"),
            password: "secret".to_string(),
        };
        let cookies = CookieJar::from_str("").expect("cookie jar");
        let ip = ClientIp(IpAddr::from([127, 0, 0, 1]));

        let result = handler(State(database), ip, cookies, Json(form)).await;
        assert!(matches!(result, Err(LoginError::NotFound)));
    }
}
