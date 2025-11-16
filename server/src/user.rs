use std::ops::Deref;

use mongodb::{
    bson::{doc, oid::ObjectId, serde_helpers::serialize_object_id_as_hex_string, Document},
    error::WriteFailure,
    Database,
};
use rand::{distributions::Uniform, prelude::Distribution};
use serde::{Deserialize, Serialize};
use skyzen::{
    responder::Responder,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
};

use crate::{
    auth::{get_group_id, AuthSession},
    utils::{parse_oid, sha256, ApiMessage, ProjectOption},
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
    database: State<Database>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<impl Responder> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("view_user").await?;
    #[derive(Serialize, Deserialize)]
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
    let id = params.get("id")?;
    let result = user
        .find_one(doc! {"_id":parse_oid(id)?}, None)
        .await?
        .ok_or(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;

    Ok(Json(result))
}

pub async fn delete(
    database: State<Database>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("delete_user").await?;
    let user = database.collection::<Document>("user");
    let id = params.get("id")?;
    let result = user.delete_one(doc! {"_id":parse_oid(id)?}, None).await?;

    if result.deleted_count == 0 {
        return Err(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND));
    }

    Ok(ApiMessage::new("Delete successfully"))
}

pub async fn get_name(database: &Database, uid: ObjectId) -> skyzen::Result<String> {
    #[derive(Deserialize)]
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

pub async fn get_classname(database: &Database, uid: ObjectId) -> skyzen::Result<String> {
    #[derive(Deserialize)]
    pub struct Schema {
        classname: String,
    }
    let collection = database.collection::<Schema>("user");
    let result = collection
        .find_one(
            doc! {"_id":uid},
            ProjectOption::new(doc! {"_id":0,"classname":1}),
        )
        .await?
        .ok_or(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;
    Ok(result.classname)
}

pub async fn register(
    database: State<Database>,
    form: Json<RegisterForm>,
) -> skyzen::Result<ApiMessage> {
    #[derive(Serialize)]
    struct User<'a> {
        email: &'a str,
        realname: &'a str,
        gender: &'a str,
        description: &'a str,
        classname: &'a str,
        password: String,
        salt: String,
        group: ObjectId,
    }

    let Json(form) = form;

    let user = database.collection::<User>("user");
    let salt = rand_string(16);

    let result = user
        .insert_one(
            User {
                email: form.email.as_str(),
                realname: form.realname.as_str(),
                password: sha256(form.password.clone() + &salt),
                salt,
                group: get_group_id(&database, "student").await?.unwrap(),
                classname: form.classname.as_str(),
                gender: form.gender.as_str(),
                description: "",
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
