use std::str::FromStr;

use models::User;
use rand::{distributions::Uniform, prelude::Distribution};
use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;
use utoipa::ToSchema;

use crate::{
    auth::{get_group_id, AuthError, AuthSession},
    database::AppDatabase,
    utils::{sha256, ApiMessage, Id},
};

#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct RegisterPayload {
    pub email: String,
    pub realname: String,
    pub password: String,
    pub gender: String,
    pub classname: String,
    pub avatar: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone, Default, ToSchema)]
pub struct UpdateUserForm {
    pub realname: Option<String>,
    pub gender: Option<String>,
    pub description: Option<String>,
    pub classname: Option<String>,
    pub avatar: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone, Default, ToSchema)]
pub struct ListUsersQuery {
    pub group: Option<String>,
    pub search: Option<String>,
    pub limit: Option<u32>,
}

#[skyzen::error]
pub enum ListUsersError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Group filter cannot be empty", status = BAD_REQUEST)]
    InvalidGroup,

    #[error("Limit must be between 1 and 1000", status = BAD_REQUEST)]
    InvalidLimit,

    #[error("Corrupted user data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

/// List users with group and text filters
#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    query: Query<ListUsersQuery>,
    session: AuthSession,
) -> Result<Json<Vec<User>>, ListUsersError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListUsersError::SessionExpired,
        _ => ListUsersError::Forbidden,
    })?;
    auth.ensure_authority("view_user")
        .await
        .map_err(|_| ListUsersError::Forbidden)?;

    let Query(ListUsersQuery {
        group,
        search,
        limit,
    }) = query;
    let group = group.unwrap_or_else(|| "student".to_string());
    if group.trim().is_empty() {
        return Err(ListUsersError::InvalidGroup);
    }
    let search_pattern = search
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| format!("%{}%", value.to_ascii_lowercase()))
        .unwrap_or_default();
    let limit = limit.unwrap_or(200);
    if limit == 0 || limit > 1000 {
        return Err(ListUsersError::InvalidLimit);
    }

    let rows = sqlx::query(
        database
            .sql("SELECT users.id, users.email, users.realname, users.gender, users.description, users.classname, users.avatar_path, users.group_id FROM users JOIN groups ON groups.id = users.group_id WHERE groups.code = ?1 AND (?2 = '' OR LOWER(users.realname) LIKE ?2 OR LOWER(users.email) LIKE ?2 OR LOWER(users.classname) LIKE ?2) ORDER BY users.realname ASC, users.email ASC LIMIT ?3")
            .as_ref(),
    )
    .bind(group)
    .bind(search_pattern)
    .bind(i64::from(limit))
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let users = rows
        .into_iter()
        .map(|row| {
            let id = row
                .try_get::<String, _>("id")
                .map_err(|_| ListUsersError::CorruptedData)?
                .parse()
                .map_err(|_| ListUsersError::CorruptedData)?;
            let group = row
                .try_get::<String, _>("group_id")
                .map_err(|_| ListUsersError::CorruptedData)?
                .parse()
                .map_err(|_| ListUsersError::CorruptedData)?;
            Ok(User {
                id,
                email: row
                    .try_get("email")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                realname: row
                    .try_get("realname")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                gender: row
                    .try_get("gender")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                description: row
                    .try_get("description")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                classname: row
                    .try_get("classname")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                avatar: row
                    .try_get("avatar_path")
                    .map_err(|_| ListUsersError::CorruptedData)?,
                group,
            })
        })
        .collect::<Result<Vec<_>, ListUsersError>>()?;

    Ok(Json(users))
}

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
    let auth = session.into_auth().await.map_err(|_| GetUserError::Auth)?;
    let id =
        resolve_requested_user(&params, auth.uid()).map_err(|_| GetUserError::InvalidUserId)?;

    if id != auth.uid() {
        auth.ensure_authority("view_user")
            .await
            .map_err(|_| GetUserError::Auth)?;
    }

    load_user(&database, id)
        .await
        .map(Json)
        .ok_or(GetUserError::NotFound)
}

#[skyzen::error]
pub enum UpdateUserError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Invalid user ID", status = BAD_REQUEST)]
    InvalidUserId,

    #[error("User not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn update(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
    form: Json<UpdateUserForm>,
) -> Result<Json<User>, UpdateUserError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| UpdateUserError::SessionExpired)?;
    let id =
        resolve_requested_user(&params, auth.uid()).map_err(|_| UpdateUserError::InvalidUserId)?;
    if id != auth.uid() {
        auth.ensure_authority("update_user_anyway")
            .await
            .map_err(|_| UpdateUserError::Forbidden)?;
    }

    let current = load_user_row(&database, id)
        .await
        .ok_or(UpdateUserError::NotFound)?;
    let Json(form) = form;

    let realname = form.realname.unwrap_or(current.realname);
    let gender = form.gender.unwrap_or(current.gender);
    let description = form.description.unwrap_or(current.description);
    let classname = form.classname.unwrap_or(current.classname);
    let avatar = form.avatar.or(current.avatar);

    sqlx::query(
        database
            .sql(
                "UPDATE users SET realname = ?1, gender = ?2, description = ?3, classname = ?4, avatar_path = ?5 WHERE id = ?6",
            )
            .as_ref(),
    )
    .bind(&realname)
    .bind(&gender)
    .bind(&description)
    .bind(&classname)
    .bind(avatar.clone())
    .bind(id.to_string())
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(Json(User {
        id,
        email: current.email,
        realname,
        gender,
        description,
        classname,
        avatar,
        group: current.group,
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
    let result = sqlx::query(database.sql("DELETE FROM users WHERE id = ?1").as_ref())
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
    let row = sqlx::query(
        database
            .sql("SELECT realname FROM users WHERE id = ?1")
            .as_ref(),
    )
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
    form: Json<RegisterPayload>,
) -> Result<ApiMessage, RegisterError> {
    let Json(form) = form;
    let salt = rand_string(16);
    let password = sha256(form.password.clone() + &salt);
    let group_id = get_group_id(&database, "student")
        .await
        .ok_or(RegisterError::StudentGroupMissing)?;
    let user_id = Id::new();

    let result = sqlx::query(
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
            avatar_path,
            password_hash,
            salt,
            group_id
        ) VALUES (?1, ?2, ?3, ?4, '', ?5, ?6, ?7, ?8, ?9)
        "#,
            )
            .as_ref(),
    )
    .bind(user_id.to_string())
    .bind(&form.email)
    .bind(&form.realname)
    .bind(&form.gender)
    .bind(&form.classname)
    .bind(form.avatar.clone())
    .bind(password)
    .bind(&salt)
    .bind(group_id.to_string())
    .execute(database.sqlx())
    .await;

    match result {
        Ok(_) => Ok(ApiMessage::new("Register successfully")),
        Err(sqlx::Error::Database(error)) => {
            if let Some(code) = error.code() {
                if code == "2067" || code == "1555" || code == "23505" {
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

#[derive(Debug, Clone)]
struct UserRow {
    id: Id,
    email: String,
    realname: String,
    gender: String,
    description: String,
    classname: String,
    avatar: Option<String>,
    group: Id,
}

async fn load_user(database: &AppDatabase, id: Id) -> Option<User> {
    load_user_row(database, id).await.map(|row| User {
        id: row.id,
        email: row.email,
        realname: row.realname,
        gender: row.gender,
        description: row.description,
        classname: row.classname,
        avatar: row.avatar,
        group: row.group,
    })
}

async fn load_user_row(database: &AppDatabase, id: Id) -> Option<UserRow> {
    let row = sqlx::query(
        database
            .sql(
                "SELECT email, realname, gender, description, classname, avatar_path, group_id FROM users WHERE id = ?1",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")?;

    let group_id: String = row.get("group_id");
    Some(UserRow {
        id,
        email: row.get("email"),
        realname: row.get("realname"),
        gender: row.get("gender"),
        description: row.get("description"),
        classname: row.get("classname"),
        avatar: row.get("avatar_path"),
        group: Id::from_str(&group_id).expect("Database error"),
    })
}

fn resolve_requested_user(params: &Params, fallback: Id) -> Result<Id, ()> {
    let id_str = params.get("id").map_err(|_| ())?;
    if id_str == "me" {
        Ok(fallback)
    } else {
        id_str.parse::<Id>().map_err(|_| ())
    }
}

static STRING_MAP: &[u8] = b"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub fn rand_string(len: usize) -> String {
    let mut rng = rand::thread_rng();
    let uniform = Uniform::from(0..STRING_MAP.len());

    let mut vec = Vec::with_capacity(len);
    for _ in 0..len {
        vec.push(STRING_MAP[uniform.sample(&mut rng)])
    }

    unsafe { String::from_utf8_unchecked(vec) }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::build_test_database;
    use skyzen::utils::{Json, State};
    use sqlx::Row;

    async fn setup_db() -> (AppDatabase, Id) {
        let database = build_test_database().await;
        let row = sqlx::query(
            database
                .sql("SELECT id FROM groups WHERE code = ?1")
                .as_ref(),
        )
        .bind("student")
        .fetch_one(database.sqlx())
        .await
        .expect("fetch student group");
        let group_id: String = row.get("id");
        (database, group_id.parse().expect("group id"))
    }

    #[tokio::test]
    async fn register_inserts_user_with_hashed_password() {
        let (database, group_id) = setup_db().await;
        let form = RegisterPayload {
            email: "test@example.com".to_string(),
            realname: "Test User".to_string(),
            password: "secret".to_string(),
            gender: "other".to_string(),
            classname: "Class A".to_string(),
            avatar: Some("avatar.png".to_string()),
        };

        let result = register(State(database.clone()), Json(form)).await;
        assert!(result.is_ok());

        let row = sqlx::query(
            database
                .sql(
                    "SELECT email, password_hash, salt, group_id, avatar_path FROM users WHERE email = ?1",
                )
                .as_ref(),
        )
        .bind("test@example.com")
        .fetch_one(database.sqlx())
        .await
        .expect("fetch user");

        let salt: String = row.get("salt");
        let password_hash: String = row.get("password_hash");
        assert_eq!(row.get::<String, _>("email"), "test@example.com");
        assert_eq!(password_hash, sha256("secret".to_string() + &salt));
        assert_eq!(row.get::<String, _>("group_id"), group_id.to_string());
        assert_eq!(
            row.get::<Option<String>, _>("avatar_path"),
            Some("avatar.png".to_string())
        );
    }

    #[tokio::test]
    async fn register_returns_already_exists_on_duplicate_email() {
        let (database, _group_id) = setup_db().await;
        let first = register(
            State(database.clone()),
            Json(RegisterPayload {
                email: "dupe@example.com".to_string(),
                realname: "First".to_string(),
                password: "secret".to_string(),
                gender: "other".to_string(),
                classname: "A".to_string(),
                avatar: None,
            }),
        )
        .await;
        assert!(first.is_ok());

        let second = register(
            State(database),
            Json(RegisterPayload {
                email: "dupe@example.com".to_string(),
                realname: "Second".to_string(),
                password: "secret".to_string(),
                gender: "other".to_string(),
                classname: "B".to_string(),
                avatar: None,
            }),
        )
        .await;
        assert!(matches!(second, Err(RegisterError::AlreadyExists)));
    }
}
