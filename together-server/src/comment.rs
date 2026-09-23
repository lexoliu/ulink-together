use crate::{auth::Auth, oid_to_hex, parse_oid, user};
use bytestr::ByteStr;
use futures_util::TryStreamExt;
use levin::{
    responder::Responder,
    routing::Params,
    utils::{json, Json, State},
};
use mongodb::{
    bson::{
        doc,
        oid::ObjectId,
        serde_helpers::{
            serialize_bson_datetime_as_rfc3339_string, serialize_object_id_as_hex_string,
        },
        DateTime,
    },
    Database,
};
use serde::{Deserialize, Serialize};

pub async fn list(database: State<Database>, params: Params) -> levin::Result<impl Responder> {
    #[derive(Serialize, Deserialize)]
    pub struct Comment {
        #[serde(rename(deserialize = "_id"))]
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        id: ObjectId,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        author: ObjectId,
        #[serde(default)]
        author_name: String,
        content: String,
        #[serde(serialize_with = "serialize_bson_datetime_as_rfc3339_string")]
        date: DateTime,
    }

    let activity_id = parse_oid(params.get("id").unwrap())?;

    let collection = database.collection::<Comment>("comment");
    let mut result: Vec<Comment> = collection
        .find(doc! {"activity":activity_id}, None)
        .await?
        .try_collect()
        .await?;

    for comment in result.iter_mut() {
        comment.author_name = user::get_name(&database, comment.author).await?;
    }

    Ok(Json(result))
}

pub async fn post(
    database: State<Database>,
    auth: Auth,
    params: Params,
    body: ByteStr,
) -> levin::Result<Json> {
    #[derive(Serialize)]
    struct Comment<'a> {
        author: ObjectId,
        activity: ObjectId,
        content: &'a str,
        date: DateTime,
    }
    let activity_id = parse_oid(params.get("id").unwrap())?;
    let collection = database.collection::<Comment>("comment");
    let result = collection
        .insert_one(
            Comment {
                author: auth.uid(),
                activity: activity_id,
                content: body.as_str(),
                date: DateTime::now(),
            },
            None,
        )
        .await?;
    Ok(Json(json!( {
        "message": "Post comment successfully",
        "comment_id": oid_to_hex(result.inserted_id).unwrap(),
    })))
}
