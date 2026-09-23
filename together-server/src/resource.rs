use std::path::Path;

use async_std::{
    fs::File,
    io::{self, BufReader},
};
use hyper::StatusCode;
use levin::{routing::Params, utils::State, Body, Error, extract::Query};
use mongodb::{bson::doc, Database};
use serde::Deserialize;
use crate::{auth::Auth, oid_to_hex};
#[derive(Debug,Deserialize)]
pub struct CreateResourceQuery{
    name:String
}

pub async fn create(
    auth: Auth,
    database: State<Database>,
    body: Body,
    query:Query<CreateResourceQuery>
) -> levin::Result<String> {
    let Query(CreateResourceQuery{name})=&query;
    let (name, extension) = name.split_once(".").unwrap_or((name, "unknown"));
    let collection = database.collection("resource");
    let result = collection
        .insert_one(doc! {"creator":auth.uid(),"name":name}, None)
        .await?;
    let id = oid_to_hex(result.inserted_id).unwrap();
    let mut file = File::create(format!("./resource/{id}.{extension}")).await?;
    io::copy(&mut body.into_reader(), &mut file).await?;
    file.sync_all().await?;
    Ok(id)
}

pub async fn access(params: Params) -> levin::Result<Body> {
    let filename = params.get("filename")?;
    let filename = Path::new(filename);

    if !filename.is_file() {
        return Err(Error::msg("Illegal access").set_status(StatusCode::FORBIDDEN));
    }
    let file = File::open(Path::new("./resource").join(filename)).await?;
    let len = file.metadata().await?.len() as usize;
    Ok(Body::from_reader(BufReader::new(file), len))
}
