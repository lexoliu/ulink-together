use std::borrow::Cow;

use futures_util::TryStreamExt;
use levin::{
    extract::Query,
    responder::Responder,
    routing::Params,
    utils::{json, Form, Json, State},
    Uri,
};
use mongodb::{
    bson::{doc, oid::ObjectId, Document},
    Database,
};
use serde::{Deserialize, Serialize};

use crate::{auth::Auth, oid_to_hex, parse_oid, ApiMessage};

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

pub async fn create(database: State<Database>, auth: Auth, uri: Uri) -> levin::Result<Json> {
    let Query(form) = Query::<CreateChannelForm>::from_str(uri.query().unwrap_or(""))?;
    let channel = database.collection::<Channel>("channel");
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
pub struct FindForm {
    owner: Option<ObjectId>,
    include_member: Option<ObjectId>,
    activity: Option<ObjectId>,
}

pub async fn find(
    database: State<Database>,
    form: Form<FindForm>,
) -> levin::Result<impl Responder> {
    #[derive(Deserialize, Serialize)]
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
    Ok(Json(result))
}
