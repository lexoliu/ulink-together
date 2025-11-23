use std::str::FromStr;

use rand::{distributions::Uniform, prelude::Distribution};
use serde::{Deserialize, Serialize};
use skyzen::{
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;
use utoipa::ToSchema;

use crate::{
    auth::{get_group_id, AuthSession},
    database::AppDatabase,
    utils::{sha256, ApiMessage, Id},
};

#[derive(Deserialize, ToSchema)]
pub(crate) struct RegisterForm {
    email: String,
    realname: String,
    password: String,
    gender: String,
    classname: String,
}

#[derive(Serialize, ToSchema)]
pub struct User {
    email: String,
    realname: String,
    gender: String,
    description: String,
    classname: String,
    group: Id,
}

skyzen::ignore_openapi!(AuthSession);

#[skyzen::error]
pub enum GetUserError {
    #[error("User not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid user ID", status = BAD_REQUEST)]
    InvalidUserId,

    #[error("Forbidden", status = FORBIDDEN)]
    Auth,
}

/// Get user information by ID
#[skyzen::openapi]
pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<Json<User>, GetUserError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| GetUserError::Auth)?;
    auth.ensure_authority("view_user")
        .await
        .map_err(|_| GetUserError::Auth)?;

    let id = params
        .get("id")
        .map_err(|_| GetUserError::InvalidUserId)?
        .parse::<Id>()
        .map_err(|_| GetUserError::InvalidUserId)?;
    let pool = database.sqlx();
    let row = sqlx::query(
        "SELECT email, realname, gender, description, classname, group_id FROM users WHERE id = ?1",
    )
    .bind(&id.to_string())
    .fetch_optional(pool)
    .await
    .expect("Database error");

    let row = row.ok_or(GetUserError::NotFound)?;
    let group_id: String = row.get("group_id");
    let group = Id::from_str(&group_id).expect("Database error");

    Ok(Json(User {
        email: row.get("email"),
        realname: row.get("realname"),
        gender: row.get("gender"),
        description: row.get("description"),
        classname: row.get("classname"),
        group,
    }))
}

/// Delete a user by ID
#[skyzen::openapi]
pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, DeleteUserError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| DeleteUserError::Auth)?;
    auth.ensure_authority("delete_user")
        .await
        .map_err(|_| DeleteUserError::Auth)?;
    let id = params
        .get("id")
        .map_err(|_| DeleteUserError::InvalidUserId)?
        .parse::<Id>()
        .map_err(|_| DeleteUserError::InvalidUserId)?;
    let result = sqlx::query("DELETE FROM users WHERE id = ?1")
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    if result.rows_affected() == 0 {
        return Err(DeleteUserError::NotFound);
    }

    Ok(ApiMessage::new("Delete successfully"))
}

#[skyzen::error]
pub enum DeleteUserError {
    #[error("User not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid user ID", status = BAD_REQUEST)]
    InvalidUserId,

    #[error("Forbidden", status = FORBIDDEN)]
    Auth,
}

pub async fn get_name(database: &AppDatabase, uid: Id) -> Result<String, GetNameError> {
    let row = sqlx::query("SELECT realname FROM users WHERE id = ?1")
        .bind(uid.to_string())
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error");
    row.and_then(|row| row.get("realname"))
        .ok_or(GetNameError::NotFound)
}

#[skyzen::error]
pub enum GetNameError {
    #[error("User not exists", status = NOT_FOUND)]
    NotFound,
}

/// Register a new user
#[skyzen::openapi]
pub async fn register(
    database: State<AppDatabase>,
    form: Json<RegisterForm>,
) -> Result<ApiMessage, RegisterError> {
    let Json(form) = form;
    let salt = rand_string(16);
    let password = sha256(form.password.clone() + &salt);
    let group_id = get_group_id(&database, "student")
        .await
        .ok_or(RegisterError::StudentGroupMissing)?;
    let user_id = Id::new();

    let result = sqlx::query(
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
        ) VALUES (?1, ?2, ?3, ?4, '', ?5, ?6, ?7, ?8)
        "#,
    )
    .bind(user_id.to_string())
    .bind(&form.email)
    .bind(&form.realname)
    .bind(&form.gender)
    .bind(&form.classname)
    .bind(password)
    .bind(&salt)
    .bind(group_id.to_string())
    .execute(database.sqlx())
    .await;

    match result {
        Ok(_) => Ok(ApiMessage::new("Register successfully")),
        Err(sqlx::Error::Database(error)) => {
            if let Some(code) = error.code() {
                // SQLITE_CONSTRAINT
                if code == "2067" || code == "1555" {
                    return Err(RegisterError::AlreadyExists);
                }
            }
            panic!("Database error: {}", error);
        }
        Err(error) => panic!("Database error: {error}"),
    }
}

#[skyzen::error]
pub enum RegisterError {
    #[error("Student group not found", status = INTERNAL_SERVER_ERROR)]
    StudentGroupMissing,

    #[error("User already exists", status = FORBIDDEN)]
    AlreadyExists,
}

static STRING_MAP: &[u8] = b"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub fn rand_string(len: usize) -> String {
    let mut rng = rand::thread_rng();
    let uniform = Uniform::from(0..61);

    let mut vec = Vec::with_capacity(len);
    for _ in 0..len {
        vec.push(STRING_MAP[uniform.sample(&mut rng)])
    }

    unsafe { String::from_utf8_unchecked(vec) }
}
