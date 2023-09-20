use std::borrow::Cow;

use futures_util::TryStreamExt;
use levin::{
    routing::Params,
    utils::{json, Form, Json, State},
    Body,
};
use mongodb::{
    bson::{doc, oid::ObjectId, DateTime, Document},
    Database,
};
use serde::{Deserialize, Serialize};

use crate::{auth::Auth, oid_to_hex, parse_oid, user, ApiMessage};

#[derive(Debug, Serialize)]
struct Channel<'a> {
    name: &'a str,
    member: Vec<ObjectId>,
    owner: ObjectId,
}

#[derive(Debug, Deserialize)]
struct CreateChannelForm<'a> {
    name: Cow<'a, str>,
}

pub async fn create(database: State<Database>, auth: Auth, mut body: Body) -> levin::Result<Json> {
    let channel = database.collection::<Channel>("channel");
    let form: CreateChannelForm = body.into_json().await?;
    let result = channel
        .insert_one(
            Channel {
                member: vec![auth.uid()],
                name: form.name.as_ref(),
                owner: auth.uid(),
            },
            None,
        )
        .await?;
    Ok(Json(json!( {
        "message": "Create channel successfully",
        "channel_id": oid_to_hex(result.inserted_id).unwrap(),
    })))
}

pub async fn delete(database: State<Database>, params: Params) -> levin::Result<ApiMessage> {
    let channel = database.collection::<Channel>("channel");
    let id = params.get("id").unwrap();
    channel.find(doc! {"_id":parse_oid(id)?}, None).await?;
    Ok(ApiMessage::new("Delete channel successfully"))
}

#[derive(Debug, Deserialize)]
pub struct GetMessageForm {
    channel: String,
}

pub async fn get_messages(
    database: State<Database>,
    form: Form<GetMessageForm>,
) -> levin::Result<Body> {
    #[derive(Debug, Serialize, Deserialize)]
    struct Message {
        id: ObjectId,
        sender: ObjectId,
        #[serde(default)]
        sender_name: String,
        content: String,
        datetime: DateTime,
    }
    let message = database.collection::<Message>("message");
    let cursor = message
        .find(doc! {"channel":parse_oid(&form.channel)?}, None)
        .await?;

    let mut result: Vec<Message> = cursor.try_collect().await?;

    for message in result.iter_mut() {
        message.sender_name = user::get_name(&database, message.sender).await?;
    }

    Body::from_json(&result)
}

#[derive(Debug,Deserialize)]
pub struct FindForm {
    owner: Option<ObjectId>,
    include_member:Option<ObjectId>,
    activity: Option<ObjectId>,
}

pub async fn find(database: State<Database>, form: Form<FindForm>) -> levin::Result<Body> {
    #[derive(Debug, Deserialize, Serialize)]
    struct Channel {
        name: String,
        member: Vec<ObjectId>,
        owner: ObjectId,
        activity: Option<ObjectId>,
    }
    let collection = database.collection::<Channel>("channel");
    let mut filter = Document::new();
    if let Some(owner) = form.owner {
        filter.insert("owner", owner);
    }

    if let Some(activity) = form.activity {
        filter.insert("activity", activity);
    }

    if let Some(include_member) = form.include_member {
        filter.insert("member", include_member);
    }

    let result: Vec<Channel> = collection.find(filter, None).await?.try_collect().await?;
    Body::from_json(&result)
}
