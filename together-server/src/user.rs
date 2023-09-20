use std::{borrow::Cow, ops::Deref};

use levin::{
    routing::Params,
    utils::{Json, State},
    Body, Error, StatusCode,
};
use mongodb::{
    bson::{doc, oid::ObjectId, serde_helpers::serialize_object_id_as_hex_string, Bson, Document},
    error::WriteFailure,
    options::FindOneOptions,
    Database,
};
use rand::{distributions::Uniform, prelude::Distribution};
use serde::{Deserialize, Serialize};

use crate::{auth::get_group_id, parse_oid, sha256, ApiMessage, ProjectOption};

pub async fn get(database: State<Database>, params: Params) -> levin::Result<Body> {
    #[derive(Debug, Serialize, Deserialize)]
    pub struct User {
        email: String,
        realname: String,
        gender: String,
        description: String,
        classname: String,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        group: ObjectId,
    }
    let user = database.collection::<User>("user");
    let id = params.get("id").unwrap();

    Body::from_json(
        &user
            .find_one(doc! {"_id":parse_oid(id)?}, None)
            .await?
            .ok_or(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?,
    )
}

pub async fn delete(database: State<Database>, params: Params) -> levin::Result<ApiMessage> {
    let user = database.collection::<Document>("user");
    let id = params.get("id").unwrap();
    let result = user.delete_one(doc! {"_id":parse_oid(id)?}, None).await?;

    if result.deleted_count == 0 {
        return Err(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND));
    }

    Ok(ApiMessage::new("Delete successfully"))
}

pub async fn get_name(database: &Database, uid: ObjectId) -> levin::Result<String> {
    #[derive(Debug, Deserialize)]
    pub struct Schema {
        realname: String,
    }
    let collection = database.collection::<Schema>("user");
    let result = collection
        .find_one(
            doc! {"_id":uid},
            ProjectOption::new(doc! {"_id":0,"realname":1}),
        )
        .await?
        .ok_or(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;
    Ok(result.realname)
}

#[derive(Debug, Deserialize)]
struct RegisterForm<'a> {
    email: Cow<'a, str>,
    realname: Cow<'a, str>,
    password: String,
    gender: Cow<'a, str>,
    classname: Cow<'a, str>,
}

pub async fn register(mut body: Body, database: State<Database>) -> levin::Result<ApiMessage> {
    #[derive(Debug, Serialize, Deserialize)]
    pub struct User<'a> {
        email: Cow<'a, str>,
        realname: Cow<'a, str>,
        gender: Cow<'a, str>,
        description: Cow<'a, str>,
        classname: Cow<'a, str>,
        password: Cow<'a, str>,
        salt: Cow<'a, str>,
        group: ObjectId,
    }

    let form: RegisterForm = body.into_json().await?;
    let user = database.collection::<User>("user");
    let salt = rand_string(16);

    let result = user
        .insert_one(
            User {
                email: form.email,
                realname: form.realname,
                password: sha256(form.password + &salt).into(),
                salt: salt.into(),
                group: get_group_id(&database, "student").await?.unwrap(),
                classname: form.classname,
                gender: form.gender,
                description: "".into(),
            },
            None,
        )
        .await;

    if let Err(error) = result {
        if let mongodb::error::ErrorKind::Write(error) = error.kind.deref() {
            if let WriteFailure::WriteError(error) = error {
                if error.code == 11000 {
                    return Err(Error::msg("User already exists").set_status(StatusCode::FORBIDDEN));
                }
            }
        }
        return Err(error.into());
    }

    Ok(ApiMessage::new("Register successfully"))
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
