use bytestr::ByteStr;
use futures_util::TryStreamExt;
use levin::{
    extract::Query,
    responder::Responder,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode, Uri,
};
use mongodb::{
    bson::{doc, oid::ObjectId, Bson, DateTime, Document},
    Database,
};
use serde::{Deserialize, Serialize};

use crate::{auth::Auth, parse_oid, ApiMessage};

#[derive(Debug, Deserialize, Serialize)]

pub struct Message {
    #[serde(rename(deserialize = "_id"))]
    id: Bson,
    channel: ObjectId,
    content: String,
    datetime: DateTime,
}

pub async fn find(database: State<Database>, uri: Uri) -> levin::Result<impl Responder> {
    #[derive(Deserialize)]
    struct FindQuery {
        start_date: Option<DateTime>,
        end_date: Option<DateTime>,
        channel: ObjectId,
        sender: Option<ObjectId>,
    }

    let collection = database.collection::<Message>("message");
    let Query(query) = Query::<FindQuery>::from_str(uri.query().unwrap_or(""))?;
    let mut filter = Document::new();
    filter.insert("channel", query.channel);
    let mut daterange = Document::new();
    if let Some(date) = query.start_date {
        daterange.insert("$gte", date);
    }

    if let Some(date) = query.end_date {
        filter.insert("$lte", date);
    }

    filter.insert("datetime", daterange);

    if let Some(sender) = query.sender {
        filter.insert("sender", sender);
    }

    let result: Vec<Message> = collection.find(filter, None).await?.try_collect().await?;
    Ok(Json(result))
}

pub async fn get(database: State<Database>, params: Params) -> levin::Result<impl Responder> {
    let id = params.get("id").ok_or(Error::msg("Missing param `id`"))?;
    let id = parse_oid(id)?;
    let message = database.collection::<Message>("message");
    Ok(Json(message.find_one(doc! {"_id":id}, None).await?.ok_or(
        Error::msg("Message not exist").set_status(StatusCode::NOT_FOUND),
    )?))
}

pub async fn post(
    database: State<Database>,
    content: ByteStr,
    params: Params,
    auth: Auth,
) -> levin::Result<ApiMessage> {
    #[derive(Serialize)]

    struct Message<'a> {
        channel: ObjectId,
        content: &'a str,
        datetime: DateTime,
    }
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
            Message {
                channel: channel_id,
                content: content.as_str().into(),
                datetime: DateTime::now(),
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

    collection.delete_one(doc! {"_id":id}, None).await?;

    Ok(ApiMessage::new("Delete message sucessfully"))
}
