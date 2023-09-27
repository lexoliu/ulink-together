use futures_util::TryStreamExt;
use levin::{
    responder::Responder,
    routing::Params,
    utils::{Form, Json, State},
    Error, StatusCode,
};
use mongodb::{
    bson::{doc, oid::ObjectId, serde_helpers::serialize_object_id_as_hex_string, Document},
    Database,
};
use serde::{Deserialize, Serialize};

use crate::{auth::Auth, parse_oid, ApiMessage, ProjectOption};

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RecordState {
    Todo,
    Done,
    Canneled,
}

pub async fn create_record(
    database: &Database,
    uid: ObjectId,
    activity_id: ObjectId,
) -> Result<(), mongodb::error::Error> {
    #[derive(Serialize)]
    pub struct Record {
        user: ObjectId,
        activity: ObjectId,
        state: RecordState,
    }

    let collection = database.collection("record");
    collection
        .insert_one(
            Record {
                user: uid,
                activity: activity_id,
                state: RecordState::Todo,
            },
            None,
        )
        .await?;
    Ok(())
}

pub async fn get_volunteers(
    database: &Database,
    activity_id: ObjectId,
) -> Result<Vec<ObjectId>, mongodb::error::Error> {
    #[derive(Deserialize)]
    pub struct Record {
        user: ObjectId,
    }
    let collection = database.collection("record");

    Ok(collection
        .find(
            doc! {"activity":activity_id},
            ProjectOption::new(doc! {"_id":0,"user":1}),
        )
        .await?
        .map_ok(|v: Record| v.user)
        .try_collect()
        .await?)
}

#[derive(Deserialize)]
pub struct FindForm {
    user: Option<ObjectId>,
    activity: Option<ObjectId>,
}

pub async fn find(
    database: State<Database>,
    form: Form<FindForm>,
) -> levin::Result<impl Responder> {
    #[derive(Serialize, Deserialize)]
    pub struct Record {
        #[serde(rename(deserialize = "_id"))]
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        id: ObjectId,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        user: ObjectId,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        activity: ObjectId,
        state: RecordState,
    }
    let mut filter = Document::new();
    if let Some(user) = form.user {
        filter.insert("user", user);
    }

    if let Some(activity) = form.activity {
        filter.insert("activity", activity);
    }

    let collection = database.collection::<Record>("record");
    let result: Vec<Record> = collection.find(filter, None).await?.try_collect().await?;
    Ok(Json(result))
}

pub async fn mark_done(
    database: State<Database>,
    auth: Auth,
    params: Params,
) -> levin::Result<ApiMessage> {
    let record_id = parse_oid(params.get("id").unwrap())?;
    let record_collection = database.collection::<Record>("record");

    #[derive(Deserialize)]
    struct Record {
        activity: ObjectId,
    }

    let activity_id = record_collection
        .find_one(doc! {"_id":record_id}, None)
        .await?
        .ok_or(Error::msg("Activity is not exists").set_status(StatusCode::NOT_FOUND))?
        .activity;

    let activity_collection = database.collection::<Document>("activity");
    activity_collection
        .find_one(
            doc! {"_id":activity_id,"promoter":auth.uid()},
            ProjectOption::new(None),
        )
        .await?
        .ok_or(
            Error::msg("You have no access to this activity or this activity is not exists")
                .set_status(StatusCode::FORBIDDEN),
        )?;

    record_collection
        .update_one(doc! {"_id":record_id}, doc! {"$set":{"state":"done"}}, None)
        .await?;
    Ok(ApiMessage::new("Mark done successfully"))
}
