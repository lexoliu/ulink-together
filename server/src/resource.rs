use std::path::Path;

use crate::{auth::AuthSession, utils::oid_to_hex};
use async_std::{
    fs::File,
    io::{self, BufReader},
};
use mongodb::{bson::doc, Database};
use serde::Deserialize;
use skyzen::{extract::Query, routing::Params, utils::State, Body, Error, StatusCode};

#[derive(Debug, Deserialize)]
pub struct CreateResourceQuery {
    name: String,
}

pub async fn create(
    session: AuthSession,
    database: State<Database>,
    body: Body,
    query: Query<CreateResourceQuery>,
) -> skyzen::Result<String> {
    let auth = session.into_auth().await?;
    let Query(CreateResourceQuery { name }) = query;
    let (base, extension) = name
        .split_once('.')
        .map(|(b, e)| (b.to_owned(), e.to_owned()))
        .unwrap_or_else(|| (name, "unknown".to_string()));
    let collection = database.collection("resource");
    let result = collection
        .insert_one(doc! {"creator":auth.uid(),"name":&base}, None)
        .await?;
    let id = oid_to_hex(result.inserted_id).unwrap();
    let mut file = File::create(format!("./resource/{id}.{}", extension)).await?;
    io::copy(&mut body.into_reader(), &mut file).await?;
    file.sync_all().await?;
    Ok(id)
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
