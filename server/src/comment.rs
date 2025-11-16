use crate::{
    auth::AuthSession,
    user,
    utils::{oid_to_hex, parse_oid},
};
use bytestr::ByteStr;
use futures_util::TryStreamExt;
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
use skyzen::{
    responder::Responder,
    routing::Params,
    utils::{json, Json, State},
};

pub async fn list(
    database: State<Database>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<impl Responder> {
    session.into_auth().await?;
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

    let activity_id = parse_oid(params.get("id")?)?;

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
    session: AuthSession,
    params: Params,
    body: ByteStr,
) -> skyzen::Result<Json> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("send_comment").await?;
    #[derive(Serialize)]
    struct Comment<'a> {
        author: ObjectId,
        activity: ObjectId,
        content: &'a str,
        date: DateTime,
    }
    let activity_id = parse_oid(params.get("id")?)?;
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
