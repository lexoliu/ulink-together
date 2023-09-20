use std::{borrow::Cow, str::FromStr};

use bytestr::ByteStr;
use levin::{
    routing::Params,
    utils::{Json, State},
    Body, Error, StatusCode,
};
use mongodb::{
    bson::{doc, oid::ObjectId, DateTime, Document, Bson},
    Database,
};
use serde::{Deserialize, Serialize};

use crate::{auth::Auth, parse_oid, ApiMessage};
#[derive(Debug, Deserialize, Serialize)]
pub struct Message<'a> {
    #[serde(rename(deserialize = "_id"))]
    #[serde(skip_serializing)]
    id:Bson,
    channel: ObjectId,
    content: Cow<'a, str>,
    datetime: DateTime,
}

pub async fn get(
    database: State<Database>,
    params: Params,
) -> levin::Result<Json<Message<'static>>> {
    let id = params.get("id").ok_or(Error::msg("Missing param `id`"))?;
    let id=parse_oid(id)?;
    let message = database.collection::<Message>("message");
    Ok(Json(
        message
            .find_one(doc! {"_id":id}, None)
            .await?
            .ok_or(Error::msg("Message not exist").set_status(StatusCode::NOT_FOUND))?,
    ))
}



pub async fn post(
    database: State<Database>,
    content: ByteStr,
    params: Params,
    auth: Auth,
) -> levin::Result<ApiMessage> {
    let channel_id = parse_oid(params.get("id").unwrap())?;
    let channel_collection = database.collection::<()>("channel");

    let result = channel_collection
        .find_one(doc! {"_id":channel_id,"member":auth.uid()}, None)
        .await?;

    if !(auth.match_authority("send_message_anyway").await? || result.is_some()) {
        return Err(
            Error::msg("You have no access to this channel").set_status(StatusCode::FORBIDDEN)
        );
    }
    let message_collection = database.collection("message");

    message_collection
        .insert_one(
            Message{
                id:Bson::Undefined,
                channel:channel_id,
                content:content.as_str().into(),
                datetime:DateTime::now(),
            },
            None,
        )
        .await?;
    Ok(ApiMessage::new("Post message successfully"))
}

pub async fn delete(
    database: State<Database>,
    params: Params,
    auth: Auth,
) -> levin::Result<ApiMessage> {
    let collection: mongodb::Collection<()> = database.collection::<()>("message");
    if !auth.match_authority("delete_message_anyway").await? {
        return Err(
            Error::msg("You have no access to this channel").set_status(StatusCode::FORBIDDEN)
        );
    }
    let id = parse_oid(params.get("id").unwrap())?;

    collection.delete_one(doc!{"_id":id}, None).await?;

    Ok(ApiMessage::new("Delete message sucessfully"))
}
