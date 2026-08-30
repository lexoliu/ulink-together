use std::path::{Component, Path};

use crate::{auth::AuthSession, database::AppDatabase, utils::Id};
use async_std::{
    fs::{remove_file, File},
    io::{self, BufReader},
};

use serde::{Deserialize, Serialize};
use skyzen::{extract::Query, routing::Params, utils::Json, utils::State, Body};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateResourceQuery {
    name: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ResourceCreated {
    id: Id,
    filename: String,
    path: String,
}

#[skyzen::error]
pub enum CreateResourceError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Invalid resource name", status = BAD_REQUEST)]
    InvalidName,
}

#[skyzen::openapi]
pub async fn create(
    session: AuthSession,
    database: State<AppDatabase>,
    body: Body,
    query: Query<CreateResourceQuery>,
) -> Result<Json<ResourceCreated>, CreateResourceError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| CreateResourceError::SessionExpired)?;
    let Query(CreateResourceQuery { name }) = query;
    let sanitized_name = sanitize_filename(&name).ok_or(CreateResourceError::InvalidName)?;
    let (base, extension) = sanitized_name
        .rsplit_once('.')
        .map(|(b, e)| (b.to_owned(), sanitize_extension(e)))
        .unwrap_or_else(|| (sanitized_name.to_owned(), "unknown".to_string()));
    let id = Id::new();
    let id_hex = id.to_string();
    let filename = format!("{id_hex}.{}", extension);

    async_std::fs::create_dir_all("./resource")
        .await
        .expect("Create resource directory failed");
    sqlx::query(
        database
            .sql(
                "INSERT INTO resources (id, creator_id, name, extension, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(&id_hex)
    .bind(auth.uid().to_string())
    .bind(&base)
    .bind(&extension)
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let mut file = File::create(format!("./resource/{filename}"))
        .await
        .expect("Create resource file failed");
    io::copy(&mut body.into_reader(), &mut file)
        .await
        .expect("Write resource file failed");
    file.sync_all().await.expect("Flush resource file failed");

    Ok(Json(ResourceCreated {
        id,
        filename: filename.clone(),
        path: format!("/api/v1/resource/{filename}"),
    }))
}

#[skyzen::error]
pub enum AccessResourceError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Illegal access", status = FORBIDDEN)]
    IllegalAccess,
}

pub async fn access(params: Params, session: AuthSession) -> Result<Body, AccessResourceError> {
    session
        .into_auth()
        .await
        .map_err(|_| AccessResourceError::SessionExpired)?;
    let filename = params
        .get("filename")
        .map_err(|_| AccessResourceError::IllegalAccess)?;
    let filename = sanitize_filename(filename).ok_or(AccessResourceError::IllegalAccess)?;
    let filename = Path::new(filename);

    let resource_dir = Path::new("./resource");
    let full_path = resource_dir.join(filename);

    if !full_path.is_file() {
        return Err(AccessResourceError::IllegalAccess);
    }
    let file = File::open(&full_path)
        .await
        .expect("Open resource file failed");
    let len = file
        .metadata()
        .await
        .expect("Read resource metadata failed")
        .len() as usize;
    Ok(Body::from_reader(BufReader::new(file), len))
}

#[skyzen::error]
pub enum DeleteResourceError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Illegal access", status = FORBIDDEN)]
    IllegalAccess,

    #[error("Delete resource failed", status = INTERNAL_SERVER_ERROR)]
    DeleteFailed,
}

#[skyzen::openapi]
pub async fn delete(
    params: Params,
    session: AuthSession,
    database: State<AppDatabase>,
) -> Result<crate::utils::ApiMessage, DeleteResourceError> {
    let auth = session
        .into_auth()
        .await
        .map_err(|_| DeleteResourceError::SessionExpired)?;
    let filename = params
        .get("filename")
        .map_err(|_| DeleteResourceError::IllegalAccess)?;
    let filename = sanitize_filename(filename).ok_or(DeleteResourceError::IllegalAccess)?;
    let filename_path = Path::new(filename);
    let (resource_id, extension) =
        parse_resource_identity(filename_path).ok_or(DeleteResourceError::IllegalAccess)?;

    let resource = sqlx::query(
        database
            .sql("SELECT creator_id, extension FROM resources WHERE id = ?1")
            .as_ref(),
    )
    .bind(resource_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(DeleteResourceError::IllegalAccess)?;

    let creator_id: String = resource.try_get("creator_id").expect("Database error");
    let stored_extension: String = resource.try_get("extension").expect("Database error");
    if creator_id != auth.uid().to_string() || stored_extension != extension {
        return Err(DeleteResourceError::IllegalAccess);
    }

    sqlx::query(database.sql("DELETE FROM resources WHERE id = ?1").as_ref())
        .bind(resource_id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    let full_path = Path::new("./resource").join(filename_path);
    match remove_file(&full_path).await {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::NotFound => {}
        Err(_) => return Err(DeleteResourceError::DeleteFailed),
    }

    Ok(crate::utils::ApiMessage::new(
        "Delete resource successfully",
    ))
}

fn sanitize_filename(name: &str) -> Option<&str> {
    if name.is_empty() {
        return None;
    }
    let path = Path::new(name);
    let mut components = path.components();
    match (components.next(), components.next()) {
        (Some(Component::Normal(os)), None) if os.to_str() == Some(name) => Some(name),
        _ => None,
    }
}

fn parse_resource_identity(filename: &Path) -> Option<(Id, String)> {
    let id = filename.file_stem()?.to_str()?.parse().ok()?;
    let extension = filename.extension()?.to_str()?;
    Some((id, sanitize_extension(extension)))
}

fn sanitize_extension(extension: &str) -> String {
    let filtered: String = extension
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric())
        .collect();
    if filtered.is_empty() {
        "unknown".to_string()
    } else {
        filtered
    }
}
