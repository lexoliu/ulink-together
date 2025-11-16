use crate::{
    auth::{Auth, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, ApiMessage},
};
use bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use skyzen::{
    routing::Params,
    utils::{Form, State},
    Error, StatusCode,
};
use sqlx::{QueryBuilder, Row, Sqlite};
use time::OffsetDateTime;

#[derive(Deserialize)]
pub struct FindForm {
    user: Option<ObjectId>,
    activity: Option<ObjectId>,
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum RecordState {
    Todo,
    Done,
    Canneled,
}

impl RecordState {
    fn as_str(&self) -> &'static str {
        match self {
            RecordState::Todo => "todo",
            RecordState::Done => "done",
            RecordState::Canneled => "canneled",
        }
    }
}

impl TryFrom<&str> for RecordState {
    type Error = skyzen::Error;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        Ok(match value {
            "todo" => RecordState::Todo,
            "done" => RecordState::Done,
            "canneled" => RecordState::Canneled,
            _ => {
                return Err(Error::msg("Unknown record state")
                    .set_status(StatusCode::INTERNAL_SERVER_ERROR))
            }
        })
    }
}

#[derive(Serialize)]
pub struct RecordEntry {
    #[serde(rename = "id")]
    record_id: ObjectId,
    user: ObjectId,
    activity: ObjectId,
    state: RecordState,
}

fn parse_db_oid(value: &str) -> skyzen::Result<ObjectId> {
    ObjectId::parse_str(value).map_err(|_| {
        Error::msg("Corrupted identifier").set_status(StatusCode::INTERNAL_SERVER_ERROR)
    })
}

pub async fn create_record(
    database: &AppDatabase,
    uid: ObjectId,
    activity_id: ObjectId,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO records (id, activity_id, user_id, state, updated_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(ObjectId::new().to_hex())
    .bind(activity_id.to_hex())
    .bind(uid.to_hex())
    .bind(RecordState::Todo.as_str())
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await?;
    Ok(())
}

pub async fn get_volunteers(
    database: &AppDatabase,
    activity_id: ObjectId,
) -> Result<Vec<ObjectId>, sqlx::Error> {
    let rows =
        sqlx::query("SELECT user_id FROM records WHERE activity_id = ?1 AND state != 'canneled'")
            .bind(activity_id.to_hex())
            .fetch_all(database.sqlx())
            .await?;

    let mut volunteers = Vec::with_capacity(rows.len());
    for row in rows {
        if let Ok(hex) = row.try_get::<String, _>("user_id") {
            if let Ok(oid) = ObjectId::parse_str(&hex) {
                volunteers.push(oid);
            }
        }
    }

    Ok(volunteers)
}

pub async fn find(
    database: State<AppDatabase>,
    form: Form<FindForm>,
    session: AuthSession,
) -> skyzen::Result<skyzen::utils::Json<Vec<RecordEntry>>> {
    session.into_auth().await?;
    let Form(form) = form;

    let mut builder = QueryBuilder::<Sqlite>::new(
        "SELECT id, user_id, activity_id, state FROM records WHERE 1=1",
    );

    if let Some(user) = form.user {
        builder.push(" AND user_id = ").push_bind(user.to_hex());
    }

    if let Some(activity) = form.activity {
        builder
            .push(" AND activity_id = ")
            .push_bind(activity.to_hex());
    }

    let records = builder.build().fetch_all(database.sqlx()).await?;

    let mut result = Vec::with_capacity(records.len());
    for row in records {
        let state: RecordState =
            RecordState::try_from(row.try_get::<String, _>("state")?.as_str())?;
        result.push(RecordEntry {
            record_id: parse_db_oid(&row.try_get::<String, _>("id")?)?,
            user: parse_db_oid(&row.try_get::<String, _>("user_id")?)?,
            activity: parse_db_oid(&row.try_get::<String, _>("activity_id")?)?,
            state,
        });
    }

    Ok(skyzen::utils::Json(result))
}

async fn update_record_state(
    database: &AppDatabase,
    auth: &Auth,
    record_id: ObjectId,
    state: RecordState,
) -> skyzen::Result<()> {
    let record_hex = record_id.to_hex();
    let row = sqlx::query("SELECT activity_id FROM records WHERE id = ?1")
        .bind(&record_hex)
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Record not exists").set_status(StatusCode::NOT_FOUND))?;
    let activity_hex: String = row.try_get("activity_id")?;

    let activity = sqlx::query("SELECT promoter_id FROM activities WHERE id = ?1")
        .bind(&activity_hex)
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;
    let promoter_hex: String = activity.try_get("promoter_id")?;

    if promoter_hex != auth.uid().to_hex() && !auth.match_authority("manage_record_anyway").await? {
        return Err(
            Error::msg("You have no access to this activity").set_status(StatusCode::FORBIDDEN)
        );
    }

    sqlx::query("UPDATE records SET state = ?1, updated_at = ?2 WHERE id = ?3")
        .bind(state.as_str())
        .bind(OffsetDateTime::now_utc().to_string())
        .bind(record_hex)
        .execute(database.sqlx())
        .await?;

    Ok(())
}

pub async fn mark_done(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let record_id = parse_oid(params.get("id")?)?;
    update_record_state(&database, &auth, record_id, RecordState::Done).await?;
    Ok(ApiMessage::new("Mark done successfully"))
}

pub async fn approve_apply(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let record_id = parse_oid(params.get("id")?)?;
    update_record_state(&database, &auth, record_id, RecordState::Todo).await?;
    Ok(ApiMessage::new("Approve apply successfully"))
}

pub async fn disapprove_apply(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let record_id = parse_oid(params.get("id")?)?;
    update_record_state(&database, &auth, record_id, RecordState::Canneled).await?;
    Ok(ApiMessage::new("Disapprove apply successfully"))
}
