use std::path::Path;

use crate::{auth::AuthSession, database::AppDatabase, utils::Id};
use async_std::{
    fs::File,
    io::{self, BufReader},
};

use serde::Deserialize;
use skyzen::{extract::Query, routing::Params, utils::State, Body, Error, StatusCode};
use time::OffsetDateTime;

#[derive(Debug, Deserialize)]
pub struct CreateResourceQuery {
    name: String,
}

pub async fn create(
    session: AuthSession,
    database: State<AppDatabase>,
    body: Body,
    query: Query<CreateResourceQuery>,
) -> skyzen::Result<String> {
    let auth = session.into_auth().await?;
    let Query(CreateResourceQuery { name }) = query;
    let (base, extension) = name
        .split_once('.')
        .map(|(b, e)| (b.to_owned(), e.to_owned()))
        .unwrap_or_else(|| (name, "unknown".to_string()));
    let id = Id::new();
    let id_hex = id.to_string();

    sqlx::query(
        "INSERT INTO resources (id, creator_id, name, extension, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(&id_hex)
    .bind(auth.uid().to_string())
    .bind(&base)
    .bind(&extension)
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await?;

    let mut file = File::create(format!("./resource/{id_hex}.{}", extension)).await?;
    io::copy(&mut body.into_reader(), &mut file).await?;
    file.sync_all().await?;
    Ok(id_hex)
}

pub async fn access(params: Params, session: AuthSession) -> skyzen::Result<Body> {
    session.into_auth().await?;
    let filename = params.get("filename")?;
    let filename = Path::new(filename);

    if !filename.is_file() {
        return Err(Error::msg("Illegal access").set_status(StatusCode::FORBIDDEN));
    }
    let file = File::open(Path::new("./resource").join(filename)).await?;
    let len = file.metadata().await?.len() as usize;
    Ok(Body::from_reader(BufReader::new(file), len))
}
