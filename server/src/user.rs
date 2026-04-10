use std::{collections::HashSet, str::FromStr};

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
    utils::{hash_password, ApiMessage, Id},
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

#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct AdminCreateUserPayload {
    pub email: String,
    pub realname: String,
    pub password: String,
    pub gender: String,
    pub classname: String,
    pub avatar: Option<String>,
    pub group: String,
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

#[derive(Debug, Serialize, Clone, ToSchema)]
pub struct UserClassSummary {
    pub classname: String,
    pub count: u32,
}

#[derive(Debug, Serialize, Clone, ToSchema)]
pub struct UserBatchResult {
    pub affected: u64,
}

#[skyzen::error]
pub enum ListUserClassesError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Group filter cannot be empty", status = BAD_REQUEST)]
    InvalidGroup,

    #[error("Corrupted class summary data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

#[skyzen::openapi]
pub async fn list_classes(
    database: State<AppDatabase>,
    query: Query<ListUsersQuery>,
    session: AuthSession,
) -> Result<Json<Vec<UserClassSummary>>, ListUserClassesError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListUserClassesError::SessionExpired,
        _ => ListUserClassesError::Forbidden,
    })?;
    auth.ensure_authority("view_user")
        .await
        .map_err(|_| ListUserClassesError::Forbidden)?;

    let Query(ListUsersQuery { group, .. }) = query;
    let group = group.unwrap_or_else(|| "student".to_string());
    if group.trim().is_empty() {
        return Err(ListUserClassesError::InvalidGroup);
    }

    let rows = sqlx::query(
        database
            .sql("SELECT users.classname, COUNT(users.id) AS user_count FROM users JOIN groups ON groups.id = users.group_id WHERE groups.code = ?1 GROUP BY users.classname ORDER BY users.classname ASC")
            .as_ref(),
    )
    .bind(group)
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let classes = rows
        .into_iter()
        .map(|row| {
            let count = row
                .try_get::<i64, _>("user_count")
                .map_err(|_| ListUserClassesError::CorruptedData)?;
            if count < 0 {
                return Err(ListUserClassesError::CorruptedData);
            }
            Ok(UserClassSummary {
                classname: row
                    .try_get("classname")
                    .map_err(|_| ListUserClassesError::CorruptedData)?,
                count: count as u32,
            })
        })
        .collect::<Result<Vec<_>, ListUserClassesError>>()?;

    Ok(Json(classes))
}

#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct BatchImportCsvForm {
    pub csv_text: String,
    pub default_password: String,
}

#[derive(Debug, Deserialize)]
struct ImportCsvRow {
    email: String,
    realname: String,
    gender: String,
    classname: String,
    description: Option<String>,
    avatar: Option<String>,
    password: Option<String>,
}

#[derive(Debug, Clone)]
struct ParsedImportUser {
    email: String,
    realname: String,
    gender: String,
    classname: String,
    description: String,
    avatar: Option<String>,
    password: String,
}

#[skyzen::error]
pub enum ImportCsvError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("CSV text cannot be empty", status = BAD_REQUEST)]
    EmptyCsvText,

    #[error("Default password cannot be empty", status = BAD_REQUEST)]
    EmptyDefaultPassword,

    #[error("Student group not found", status = INTERNAL_SERVER_ERROR)]
    StudentGroupMissing,

    #[error("{0}", status = BAD_REQUEST)]
    InvalidCsv(String),

    #[error("{0}", status = CONFLICT)]
    Conflict(String),
}

#[skyzen::openapi]
pub async fn import_csv(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<BatchImportCsvForm>,
) -> Result<Json<UserBatchResult>, ImportCsvError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ImportCsvError::SessionExpired,
        _ => ImportCsvError::Forbidden,
    })?;
    auth.ensure_authority("update_user_anyway")
        .await
        .map_err(|_| ImportCsvError::Forbidden)?;

    let Json(BatchImportCsvForm {
        csv_text,
        default_password,
    }) = form;
    if csv_text.trim().is_empty() {
        return Err(ImportCsvError::EmptyCsvText);
    }
    let default_password = default_password.trim().to_string();
    if default_password.is_empty() {
        return Err(ImportCsvError::EmptyDefaultPassword);
    }

    let student_group_id = get_group_id(&database, "student")
        .await
        .ok_or(ImportCsvError::StudentGroupMissing)?;
    let parsed = parse_import_csv(&csv_text, &default_password)?;
    if parsed.is_empty() {
        return Err(ImportCsvError::InvalidCsv(
            "CSV does not contain any student rows".to_string(),
        ));
    }

    let mut tx = database.sqlx().begin().await.expect("Database error");
    for student in &parsed {
        let user_id = Id::new();
        let password_hash = hash_password(&student.password).expect("bcrypt hash password");

        let result = sqlx::query(
            database
                .sql("INSERT INTO users (id, email, realname, gender, description, classname, avatar_path, password_hash, group_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)")
                .as_ref(),
        )
        .bind(user_id.to_string())
        .bind(&student.email)
        .bind(&student.realname)
        .bind(&student.gender)
        .bind(&student.description)
        .bind(&student.classname)
        .bind(student.avatar.clone())
        .bind(password_hash)
        .bind(student_group_id.to_string())
        .execute(&mut *tx)
        .await;

        match result {
            Ok(_) => {}
            Err(sqlx::Error::Database(error)) => {
                if is_unique_violation(&*error) {
                    return Err(ImportCsvError::Conflict(format!(
                        "User already exists for email: {}",
                        student.email
                    )));
                }
                panic!("Database error: {}", error);
            }
            Err(error) => panic!("Database error: {error}"),
        }
    }
    tx.commit().await.expect("Database error");

    Ok(Json(UserBatchResult {
        affected: parsed.len() as u64,
    }))
}

#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct BatchUpdateClassForm {
    pub from_classname: String,
    pub to_classname: String,
}

#[skyzen::error]
pub enum BatchUpdateClassError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Source class cannot be empty", status = BAD_REQUEST)]
    EmptySourceClass,

    #[error("Target class cannot be empty", status = BAD_REQUEST)]
    EmptyTargetClass,

    #[error("Source and target classes must be different", status = BAD_REQUEST)]
    ClassUnchanged,
}

#[skyzen::openapi]
pub async fn batch_update_class(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<BatchUpdateClassForm>,
) -> Result<Json<UserBatchResult>, BatchUpdateClassError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => BatchUpdateClassError::SessionExpired,
        _ => BatchUpdateClassError::Forbidden,
    })?;
    auth.ensure_authority("update_user_anyway")
        .await
        .map_err(|_| BatchUpdateClassError::Forbidden)?;

    let Json(BatchUpdateClassForm {
        from_classname,
        to_classname,
    }) = form;
    let from_classname = from_classname.trim().to_string();
    if from_classname.is_empty() {
        return Err(BatchUpdateClassError::EmptySourceClass);
    }
    let to_classname = to_classname.trim().to_string();
    if to_classname.is_empty() {
        return Err(BatchUpdateClassError::EmptyTargetClass);
    }
    if from_classname == to_classname {
        return Err(BatchUpdateClassError::ClassUnchanged);
    }

    let result = sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE classname = ?2 AND group_id IN (SELECT id FROM groups WHERE code = ?3)")
            .as_ref(),
    )
    .bind(&to_classname)
    .bind(&from_classname)
    .bind("student")
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(Json(UserBatchResult {
        affected: result.rows_affected(),
    }))
}

#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct BatchDeleteClassForm {
    pub classname: String,
}

#[skyzen::error]
pub enum BatchDeleteClassError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Class cannot be empty", status = BAD_REQUEST)]
    EmptyClass,
}

#[skyzen::openapi]
pub async fn batch_delete_class(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<BatchDeleteClassForm>,
) -> Result<Json<UserBatchResult>, BatchDeleteClassError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => BatchDeleteClassError::SessionExpired,
        _ => BatchDeleteClassError::Forbidden,
    })?;
    auth.ensure_authority("delete_user")
        .await
        .map_err(|_| BatchDeleteClassError::Forbidden)?;

    let Json(BatchDeleteClassForm { classname }) = form;
    let classname = classname.trim().to_string();
    if classname.is_empty() {
        return Err(BatchDeleteClassError::EmptyClass);
    }

    let result = sqlx::query(
        database
            .sql("DELETE FROM users WHERE classname = ?1 AND group_id IN (SELECT id FROM groups WHERE code = ?2)")
            .as_ref(),
    )
    .bind(&classname)
    .bind("student")
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(Json(UserBatchResult {
        affected: result.rows_affected(),
    }))
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
    let password = hash_password(&form.password).expect("bcrypt hash password");
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
            group_id
        ) VALUES (?1, ?2, ?3, ?4, '', ?5, ?6, ?7, ?8)
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
    .bind(group_id.to_string())
    .execute(database.sqlx())
    .await;

    match result {
        Ok(_) => Ok(ApiMessage::new("Register successfully")),
        Err(sqlx::Error::Database(error)) => {
            if is_unique_violation(&*error) {
                return Err(RegisterError::AlreadyExists);
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

#[skyzen::error]
pub enum AdminCreateUserError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Group not found", status = BAD_REQUEST)]
    GroupNotFound,

    #[error("User already exists", status = CONFLICT)]
    AlreadyExists,

    #[error("Invalid input", status = BAD_REQUEST)]
    InvalidInput,
}

/// Create a user in a specific group (admin-only).
#[skyzen::openapi]
pub async fn admin_create(
    database: State<AppDatabase>,
    form: Json<AdminCreateUserPayload>,
    session: AuthSession,
) -> Result<ApiMessage, AdminCreateUserError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => AdminCreateUserError::SessionExpired,
        _ => AdminCreateUserError::Forbidden,
    })?;
    auth.ensure_authority("update_user_anyway")
        .await
        .map_err(|_| AdminCreateUserError::Forbidden)?;

    let Json(form) = form;

    if form.email.trim().is_empty()
        || form.password.trim().is_empty()
        || form.realname.trim().is_empty()
    {
        return Err(AdminCreateUserError::InvalidInput);
    }

    let group_id = get_group_id(&database, form.group.as_str())
        .await
        .ok_or(AdminCreateUserError::GroupNotFound)?;

    let password = hash_password(&form.password).expect("bcrypt hash password");
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
            group_id
        ) VALUES (?1, ?2, ?3, ?4, '', ?5, ?6, ?7, ?8)
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
    .bind(group_id.to_string())
    .execute(database.sqlx())
    .await;

    match result {
        Ok(_) => Ok(ApiMessage::new("User created successfully")),
        Err(sqlx::Error::Database(error)) => {
            if is_unique_violation(&*error) {
                return Err(AdminCreateUserError::AlreadyExists);
            }
            panic!("Database error: {}", error);
        }
        Err(error) => panic!("Database error: {error}"),
    }
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

fn parse_import_csv(
    csv_text: &str,
    default_password: &str,
) -> Result<Vec<ParsedImportUser>, ImportCsvError> {
    let mut reader = csv::ReaderBuilder::new()
        .trim(csv::Trim::All)
        .from_reader(csv_text.as_bytes());
    let headers = reader
        .headers()
        .map_err(|error| ImportCsvError::InvalidCsv(format!("Invalid CSV header row: {error}")))?;
    for required in ["email", "realname", "gender", "classname"] {
        if !headers.iter().any(|header| header == required) {
            return Err(ImportCsvError::InvalidCsv(format!(
                "Missing required CSV header: {required}"
            )));
        }
    }

    let mut emails = HashSet::new();
    let mut parsed = Vec::new();
    for (index, row_result) in reader.deserialize::<ImportCsvRow>().enumerate() {
        let row_number = index + 2;
        let row = row_result.map_err(|error| {
            ImportCsvError::InvalidCsv(format!("Invalid CSV row {row_number}: {error}"))
        })?;

        let email = row.email.trim().to_ascii_lowercase();
        let realname = row.realname.trim().to_string();
        let gender = row.gender.trim().to_string();
        let classname = row.classname.trim().to_string();
        if email.is_empty() || realname.is_empty() || gender.is_empty() || classname.is_empty() {
            return Err(ImportCsvError::InvalidCsv(format!(
                "Row {row_number} contains empty required fields"
            )));
        }
        if !emails.insert(email.clone()) {
            return Err(ImportCsvError::InvalidCsv(format!(
                "Duplicate email in CSV at row {row_number}: {email}"
            )));
        }

        let password = row
            .password
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or(default_password)
            .to_string();
        let description = row
            .description
            .as_deref()
            .map(str::trim)
            .unwrap_or_default()
            .to_string();
        let avatar = row
            .avatar
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string);

        parsed.push(ParsedImportUser {
            email,
            realname,
            gender,
            classname,
            description,
            avatar,
            password,
        });
    }

    Ok(parsed)
}

fn is_unique_violation(error: &(dyn sqlx::error::DatabaseError + 'static)) -> bool {
    if let Some(code) = error.code() {
        code == "2067" || code == "1555" || code == "23505"
    } else {
        false
    }
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
    use crate::{database::build_test_database, utils::verify_password};
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
                    "SELECT email, password_hash, group_id, avatar_path FROM users WHERE email = ?1",
                )
                .as_ref(),
        )
        .bind("test@example.com")
        .fetch_one(database.sqlx())
        .await
        .expect("fetch user");

        let password_hash: String = row.get("password_hash");
        assert_eq!(row.get::<String, _>("email"), "test@example.com");
        assert!(verify_password("secret", &password_hash).expect("bcrypt verify password"));
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
