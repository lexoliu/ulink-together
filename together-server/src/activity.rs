use futures_util::TryStreamExt;
use levin::{
    handler::Handler,
    routing::Params,
    utils::{json, Form, Json, State},
    Body, Error, StatusCode,
};
use mongodb::bson::serde_helpers::{
    serialize_bson_datetime_as_rfc3339_string, serialize_object_id_as_hex_string,
};
use mongodb::{
    bson::{doc, oid::ObjectId, DateTime, Document},
    Database,
};
use serde::{Deserialize, Serialize, Serializer};
use std::{borrow::Cow, fmt::Display, str::FromStr};

use crate::{
    auth::Auth, impl_error, oid_to_hex, parse_oid, record::{create_record, get_volunteers}, user, ApiMessage,
    ProjectOption,
};

#[derive(Debug, Deserialize)]
pub struct ListActivityForm {
    user: Option<ObjectId>,
}

fn serialize_option_datetime<S: Serializer>(val: &Option<DateTime>, serializer: S) -> Result<S::Ok, S::Error>{
    if let Some(datetime) = val{
        serialize_bson_datetime_as_rfc3339_string(datetime,serializer)
    }
    else{
        serializer.serialize_none()
    }
}

fn serialize_oid_vec<S: Serializer>(val: &Vec<ObjectId>, serializer: S) -> Result<S::Ok, S::Error>{
    serializer.collect_seq(val.into_iter().map(|v| v.to_hex()))
}



pub async fn list(database: State<Database>, form: Form<ListActivityForm>) -> levin::Result<Body> {
    #[derive(Debug, Serialize, Deserialize)]
    pub struct Activity {
        #[serde(rename(deserialize = "_id"))]
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        id: ObjectId,
        name: String,
        location: String,
        volunteer_num: u16,
        max_volunteer_num: Option<u16>,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        promoter: ObjectId,
        #[serde(default)]
        promoter_name: String,
        #[serde(serialize_with = "serialize_option_datetime")]
        date: Option<DateTime>,
        brief_description: String,
        duration: u16, // minutes
    }

    let activities = database.collection::<Activity>("activity");
    let mut filter = doc! {"state":ActivityState::NeedVolunteer.to_string()};
    if let Some(user) = form.user {
        filter.insert("promoter", user);
    }

    let mut result: Vec<Activity> = activities.find(filter, None).await?.try_collect().await?;

    for activity in result.iter_mut() {
        activity.promoter_name = user::get_name(&database, activity.promoter).await?;
    }
    Body::from_json(&result)
}

pub async fn get_name(
    database: &Database,
    id: ObjectId,
) -> Result<Option<String>, mongodb::error::Error> {
    #[derive(Deserialize)]
    struct Activity {
        name: String,
    }
    let collection = database.collection::<Activity>("activity");
    Ok(collection
        .find_one(doc! {"_id":id}, ProjectOption::new(doc! {"_id":0,"name":1}))
        .await?
        .map(|schema| schema.name))
}



pub async fn get(database: State<Database>, params: Params) -> levin::Result<Body> {
    #[derive(Debug, Serialize, Deserialize)]
    pub struct Activity {
        state: ActivityState,
        name: String,
        location: String,
        volunteer_num: u16,
        max_volunteer_num: Option<u16>,
        #[serde(serialize_with = "serialize_object_id_as_hex_string")]
        promoter: ObjectId,
        #[serde(default)]
        promoter_name: String,
        #[serde(serialize_with = "serialize_option_datetime")]
        date: Option<DateTime>,
        description: String,
        #[serde(default)]
        #[serde(serialize_with = "serialize_oid_vec")]
        volunteers:Vec<ObjectId>,
        duration: u16, // minutes
    }
    let collection = database.collection::<Activity>("activity");
    let activity_id = parse_oid(params.get("id").unwrap())?;
    let mut activity = collection
        .find_one(doc! {"_id":activity_id}, None)
        .await?
        .ok_or(Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;
    activity.name = get_name(&database, activity_id).await?.unwrap();
    activity.volunteers=get_volunteers(&database,activity_id).await?;
    activity.promoter_name = user::get_name(&database, activity.promoter).await?;
    Body::from_json(&activity)
}

// Warning: This method would not check the validity of activity and user.
pub async fn is_joined(
    database: &Database,
    activity_id: ObjectId,
    uid: ObjectId,
) -> levin::Result<bool> {
    let collection = database.collection::<Document>("record");
    let result = collection
        .find_one(
            doc! {"activity":activity_id,"user":uid},
            ProjectOption::new(None),
        )
        .await?;
    Ok(result.is_some())
}

pub async fn join(
    database: State<Database>,
    params: Params,
    auth: Auth,
) -> levin::Result<ApiMessage> {
    #[derive(Debug, Serialize, Deserialize)]
    pub struct Activity {
        volunteer_num: u16,
        max_volunteer_num: Option<u16>,
    }

    let activity_collection = database.collection::<Activity>("activity");

    let activity_id = parse_oid(params.get("id").unwrap())?;

    let activity = activity_collection
        .find_one(
            doc! {"_id":activity_id},
            ProjectOption::new(doc! {"_id":0,"volunteer_num":1,"max_volunteer_num":1}),
        )
        .await?
        .ok_or(Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;

    if is_joined(&database, activity_id, auth.uid()).await? {
        return Err(Error::msg("You had already joined!").set_status(StatusCode::FORBIDDEN));
    }

    if let Some(max_volunteer_num) = activity.max_volunteer_num {
        if activity.volunteer_num >= max_volunteer_num {
            return Err(
                Error::msg("The activity need't more people").set_status(StatusCode::FORBIDDEN)
            );
        }
    }

    create_record(&database, auth.uid(), activity_id).await?;
    
    activity_collection
        .update_one(
            doc! {"_id":activity_id},
            doc! {"$inc":{"volunteer_num":1}},
            None,
        )
        .await?;
    Ok(ApiMessage::new("Join activity successfully"))
}

pub async fn delete(
    database: State<Database>,
    params: Params,
    auth: Auth,
) -> levin::Result<ApiMessage> {
    let collection = database.collection::<Document>("activity");
    let id = parse_oid(params.get("id").unwrap())?;

    let result = collection
        .find_one(
            doc! {"_id":id,"promoter":auth.uid()},
            ProjectOption::new(None),
        )
        .await?;
    if !(auth.match_authority("delete_activity_anyway").await? || result.is_some()) {
        return Err(
            Error::msg("You have no access to this activity").set_status(StatusCode::FORBIDDEN)
        );
    }

    collection.delete_one(doc! {"_id":id}, None).await?;

    Ok(ApiMessage::new("Delete activity sucessfully"))
}

#[derive(Debug, Serialize, Deserialize)]
struct CreateActivityForm<'a> {
    name: Cow<'a, str>,
    date: Option<Cow<'a, str>>,
    max_volunteer_num: Option<u16>,
    description: Cow<'a, str>,
    location: Cow<'a, str>,
    brief_description: Cow<'a, str>,
    duration: u16, // minutes
}

pub async fn create(database: State<Database>, auth: Auth, mut body: Body) -> levin::Result<Json> {
    #[derive(Serialize)]
    pub struct Activity<'a> {
        state: ActivityState,
        name: Cow<'a, str>,
        location: Cow<'a, str>,
        volunteer_num: u16,
        max_volunteer_num: Option<u16>,
        promoter: ObjectId,
        date: Option<DateTime>,
        brief_description: Cow<'a, str>,
        description: Cow<'a, str>,
        duration: u16, // minutes
    }
    let activities = database.collection::<Activity>("activity");
    let form: CreateActivityForm = body.into_json().await?;
    let mut date = None;
    if let Some(original) = form.date {
        date = Some(DateTime::parse_rfc3339_str(original.as_ref())?);
    }

    let result = activities
        .insert_one(
            Activity {
                name: form.name,
                date,
                location: form.location,
                brief_description: form.brief_description,
                description: form.description,
                volunteer_num: 0,
                max_volunteer_num: form.max_volunteer_num,
                promoter: auth.uid(),
                state: ActivityState::NeedVolunteer,
                duration: form.duration,
            },
            None,
        )
        .await?;
    Ok(Json(json!( {
        "message": "Create activity successfully",
        "activity_id": oid_to_hex(result.inserted_id).unwrap(),
    })))
}

#[derive(Debug, Deserialize, Serialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
pub enum ActivityState {
    Going,
    NeedVolunteer,
    Ended,
    Canneled,
}

impl_error!(InvalidState, "The state is invalid");

impl FromStr for ActivityState {
    type Err = InvalidState;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "going" => Ok(Self::Going),
            "need_volunteer" => Ok(Self::NeedVolunteer),
            "ended" => Ok(Self::Ended),
            "canneled" => Ok(Self::Canneled),
            _ => Err(InvalidState::new()),
        }
    }
}

impl Display for ActivityState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Going => f.write_str("going"),
            Self::NeedVolunteer => f.write_str("need_volunteer"),
            Self::Ended => f.write_str("ended"),
            Self::Canneled => f.write_str("canneled"),
        }
    }
}

// TODO: support transaction
pub fn turn(target_state: ActivityState) -> impl Handler<(State<Database>, Params)> {
    move |database: State<Database>, params: Params| async move {
        #[derive(Deserialize)]
        struct Activity {
            state: ActivityState,
        }

        let collection = database.collection::<Activity>("acitivty");
        let id = parse_oid(params.get("id").unwrap())?;

        let oringal_state = collection
            .find_one(
                doc! {"_id":id},
                ProjectOption::new(doc! {"_id":0,"state":1}),
            )
            .await?
            .ok_or(Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?
            .state;

        if let ActivityState::Ended = oringal_state {
            return Err(Error::msg("Activity has already ended").set_status(StatusCode::FORBIDDEN));
        }

        collection
            .update_one(
                doc! {"_id":id},
                doc! {"state":target_state.to_string()},
                None,
            )
            .await?;

        Ok(ApiMessage::new(format!("Activity is {} now", target_state)))
    }
}
