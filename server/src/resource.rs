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
    let (base, extension) = name
        .split_once('.')
        .map(|(b, e)| (b.to_owned(), e.to_owned()))
        .unwrap_or_else(|| (name, "unknown".to_string()));
    let id = Id::new();
    let id_hex = id.to_string();

    async_std::fs::create_dir_all("./resource")
        .await
        .expect("Create resource directory failed");
    sqlx::query(
        "INSERT INTO resources (id, creator_id, name, extension, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
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
    file.sync_all()
        .await
        .expect("Flush resource file failed");
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
    let filename = Path::new(filename);

    if filename
        .components()
        .any(|component| matches!(component, Component::ParentDir))
    {
        return Err(AccessResourceError::IllegalAccess);
    }

    let resource_dir = Path::new("./resource");
    let full_path = resource_dir.join(filename);

    if !full_path.is_file() {
        return Err(AccessResourceError::IllegalAccess);
    }
    let file = File::open(&full_path)
        .await
        .expect("Open resource file failed");
    let len = file.metadata().await.expect("Read resource metadata failed").len() as usize;
    Ok(Body::from_reader(BufReader::new(file), len))
}
