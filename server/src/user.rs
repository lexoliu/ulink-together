use bson::oid::ObjectId;
use rand::{distributions::Uniform, prelude::Distribution};
use serde::{Deserialize, Serialize};
use skyzen::{
    responder::Responder,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
};
use sqlx::Row;

use crate::{
    auth::{get_group_id, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, sha256, ApiMessage},
};

#[derive(Deserialize)]
pub(crate) struct RegisterForm {
    email: String,
    realname: String,
    password: String,
    gender: String,
    classname: String,
}

pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<impl Responder> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("view_user").await?;
    #[derive(Serialize)]
    pub struct User {
        email: String,
        realname: String,
        gender: String,
        description: String,
        classname: String,
        group: ObjectId,
    }

    let id = parse_oid(params.get("id")?)?;
    let hex = id.to_hex();
    let pool = database.sqlx();
    let row = sqlx::query(
        "SELECT email, realname, gender, description, classname, group_id FROM users WHERE id = ?1",
    )
    .bind(&hex)
    .fetch_optional(pool)
    .await?;

    let row = row.ok_or_else(|| Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;
    let group_hex: String = row.try_get("group_id")?;
    let group = ObjectId::parse_str(group_hex).map_err(|_| {
        Error::msg("User group malformed").set_status(StatusCode::INTERNAL_SERVER_ERROR)
    })?;

    Ok(Json(User {
        email: row.try_get("email")?,
        realname: row.try_get("realname")?,
        gender: row.try_get("gender")?,
        description: row.try_get("description")?,
        classname: row.try_get("classname")?,
        group,
    }))
}

pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("delete_user").await?;
    let id = parse_oid(params.get("id")?)?;
    let result = sqlx::query("DELETE FROM users WHERE id = ?1")
        .bind(id.to_hex())
        .execute(database.sqlx())
        .await?;

    if result.rows_affected() == 0 {
        return Err(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND));
    }

    Ok(ApiMessage::new("Delete successfully"))
}

pub async fn get_name(database: &AppDatabase, uid: ObjectId) -> skyzen::Result<String> {
    let row = sqlx::query("SELECT realname FROM users WHERE id = ?1")
        .bind(uid.to_hex())
        .fetch_optional(database.sqlx())
        .await?;
    row.and_then(|row| row.try_get("realname").ok())
        .ok_or_else(|| Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))
}

pub async fn register(
    database: State<AppDatabase>,
    form: Json<RegisterForm>,
) -> skyzen::Result<ApiMessage> {
    let Json(form) = form;
    let salt = rand_string(16);
    let password = sha256(form.password.clone() + &salt);
    let Some(group_id) = get_group_id(&database, "student").await? else {
        return Err(
            Error::msg("Student group not found").set_status(StatusCode::INTERNAL_SERVER_ERROR)
        );
    };
    let user_id = ObjectId::new();

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
    .bind(user_id.to_hex())
    .bind(&form.email)
    .bind(&form.realname)
    .bind(&form.gender)
    .bind(&form.classname)
    .bind(password)
    .bind(&salt)
    .bind(group_id.to_hex())
    .execute(database.sqlx())
    .await;

    match result {
        Ok(_) => Ok(ApiMessage::new("Register successfully")),
        Err(sqlx::Error::Database(error)) => {
            if let Some(code) = error.code() {
                // SQLITE_CONSTRAINT
                if code == "2067" || code == "1555" {
                    return Err(Error::msg("User already exists").set_status(StatusCode::FORBIDDEN));
                }
            }
            Err(sqlx::Error::Database(error).into())
        }
        Err(error) => Err(error.into()),
    }
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
