use futures_util::TryStreamExt;
use mongodb::{
    bson::{doc, oid::ObjectId, Document},
    Database,
};
use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    responder::Responder,
    routing::Params,
    utils::{json, Form, Json, State},
};

use crate::{
    auth::AuthSession,
    utils::{oid_to_hex, parse_oid, ApiMessage},
};

#[derive(Debug, Serialize)]
struct Channel<'a> {
    name: &'a str,
    member: Vec<ObjectId>,
    owner: ObjectId,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CreateChannelForm {
    name: String,
}

pub async fn create(
    database: State<Database>,
    session: AuthSession,
    query: Query<CreateChannelForm>,
) -> skyzen::Result<Json> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("create_channel").await?;
    let Query(form) = query;
    let channel = database.collection::<Channel>("channel");
    let result = channel
        .insert_one(
            Channel {
                member: vec![auth.uid()],
                name: &form.name,
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

pub async fn delete(
    database: State<Database>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    session.into_auth().await?;
    let channel = database.collection::<Channel>("channel");
    let id = params.get("id")?;
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
    session: AuthSession,
) -> skyzen::Result<impl Responder> {
    session.into_auth().await?;
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
