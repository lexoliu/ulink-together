use std::path::{Component, Path};

use crate::{auth::AuthSession, database::AppDatabase, utils::Id};
use async_std::{
    fs::File,
    io::{self, BufReader},
};

use serde::Deserialize;
use skyzen::{extract::Query, routing::Params, utils::State, Body};
use time::OffsetDateTime;

#[derive(Debug, Deserialize)]
pub struct CreateResourceQuery {
    name: String,
}

#[skyzen::error]
pub enum CreateResourceError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Invalid resource name", status = BAD_REQUEST)]
    InvalidName,
}

pub async fn create(
    session: AuthSession,
    database: State<AppDatabase>,
    body: Body,
    query: Query<CreateResourceQuery>,
) -> Result<String, CreateResourceError> {
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

    let mut file = File::create(format!("./resource/{id_hex}.{}", extension))
        .await
        .expect("Create resource file failed");
    io::copy(&mut body.into_reader(), &mut file)
        .await
        .expect("Write resource file failed");
    file.sync_all().await.expect("Flush resource file failed");
    Ok(id_hex)
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
