use crate::{
    auth::{Auth, AuthError, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, ApiMessage, Id},
};

use serde::{Deserialize, Serialize};
use skyzen::{
    routing::Params,
    utils::{Form, State},
};
use sqlx::{QueryBuilder, Row, Sqlite};
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Deserialize, ToSchema)]
pub struct FindForm {
    user: Option<Id>,
    activity: Option<Id>,
}

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Eq, ToSchema)]
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

#[derive(Serialize, ToSchema)]
pub struct RecordEntry {
    #[serde(rename = "id")]
    record_id: Id,
    user: Id,
    activity: Id,
    state: RecordState,
}

pub async fn create_record(
    database: &AppDatabase,
    uid: Id,
    activity_id: Id,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO records (id, activity_id, user_id, state, updated_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(Id::new().to_string())
    .bind(activity_id.to_string())
    .bind(uid.to_string())
    .bind(RecordState::Todo.as_str())
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await?;
    Ok(())
}

pub async fn get_volunteers(
    database: &AppDatabase,
    activity_id: Id,
) -> Result<Vec<Id>, sqlx::Error> {
    let rows =
        sqlx::query("SELECT user_id FROM records WHERE activity_id = ?1 AND state != 'canneled'")
            .bind(activity_id.to_string())
            .fetch_all(database.sqlx())
            .await?;

    let mut volunteers = Vec::with_capacity(rows.len());
    for row in rows {
        if let Ok(hex) = row.try_get::<String, _>("user_id") {
            if let Ok(oid) = hex.parse() {
                volunteers.push(oid);
            }
        }
    }

    Ok(volunteers)
}

#[skyzen::error]
pub enum FindRecordsError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Corrupted identifier", status = INTERNAL_SERVER_ERROR)]
    CorruptedId,

    #[error("Corrupted record state", status = INTERNAL_SERVER_ERROR)]
    CorruptedState,
}

fn parse_db_oid(value: &str) -> Result<Id, FindRecordsError> {
    value
        .parse()
        .map_err(|_| FindRecordsError::CorruptedId)
}

/// Find records by various criteria
#[skyzen::openapi]
pub async fn find(
    database: State<AppDatabase>,
    form: Form<FindForm>,
    session: AuthSession,
) -> Result<skyzen::utils::Json<Vec<RecordEntry>>, FindRecordsError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindRecordsError::SessionExpired,
        _ => FindRecordsError::Forbidden,
    })?;
    let Form(form) = form;

    let mut builder = QueryBuilder::<Sqlite>::new(
        "SELECT id, user_id, activity_id, state FROM records WHERE 1=1",
    );

    if let Some(user) = form.user {
        builder.push(" AND user_id = ").push_bind(user.to_string());
    }

    if let Some(activity) = form.activity {
        builder
            .push(" AND activity_id = ")
            .push_bind(activity.to_string());
    }

    let records = builder
        .build()
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");

    let mut result = Vec::with_capacity(records.len());
    for row in records {
        let state_str: String = row.try_get("state").expect("Database error");
        let state = match state_str.as_str() {
            "todo" => RecordState::Todo,
            "done" => RecordState::Done,
            "canneled" => RecordState::Canneled,
            _ => return Err(FindRecordsError::CorruptedState),
        };
        result.push(RecordEntry {
            record_id: parse_db_oid(&row.try_get::<String, _>("id").expect("Database error"))?,
            user: parse_db_oid(&row.try_get::<String, _>("user_id").expect("Database error"))?,
            activity: parse_db_oid(
                &row.try_get::<String, _>("activity_id")
                    .expect("Database error"),
            )?,
            state,
        });
    }

    Ok(skyzen::utils::Json(result))
}

#[skyzen::error]
pub enum UpdateRecordError {
    #[error("Record not exists", status = NOT_FOUND)]
    RecordNotFound,

    #[error("Activity not exists", status = NOT_FOUND)]
    ActivityNotFound,

    #[error("You have no access to this activity", status = FORBIDDEN)]
    Forbidden,
}

async fn update_record_state(
    database: &AppDatabase,
    auth: &Auth,
    record_id: Id,
    state: RecordState,
) -> Result<(), UpdateRecordError> {
    let record_hex = record_id.to_string();
    let row = sqlx::query("SELECT activity_id FROM records WHERE id = ?1")
        .bind(&record_hex)
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error")
        .ok_or(UpdateRecordError::RecordNotFound)?;
    let activity_hex: String = row.try_get("activity_id").expect("Database error");

    let activity = sqlx::query("SELECT promoter_id FROM activities WHERE id = ?1")
        .bind(&activity_hex)
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error")
        .ok_or(UpdateRecordError::ActivityNotFound)?;
    let promoter_hex: String = activity.try_get("promoter_id").expect("Database error");

    if promoter_hex != auth.uid().to_string()
        && !auth
            .match_authority("manage_record_anyway")
            .await
            .map_err(|_| UpdateRecordError::Forbidden)?
    {
        return Err(UpdateRecordError::Forbidden);
    }

    sqlx::query("UPDATE records SET state = ?1, updated_at = ?2 WHERE id = ?3")
        .bind(state.as_str())
        .bind(OffsetDateTime::now_utc().to_string())
        .bind(record_hex)
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(())
}

#[skyzen::error]
pub enum MarkDoneError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid record id", status = BAD_REQUEST)]
    InvalidRecordId,

    #[error("Record not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Activity not exists", status = NOT_FOUND)]
    ActivityNotFound,
}

/// Mark a volunteer's task as done
#[skyzen::openapi]
pub async fn mark_done(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> Result<ApiMessage, MarkDoneError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => MarkDoneError::SessionExpired,
        _ => MarkDoneError::Forbidden,
    })?;
    let record_id = parse_oid(
        params
            .get("id")
            .map_err(|_| MarkDoneError::InvalidRecordId)?,
    )
    .map_err(|_| MarkDoneError::InvalidRecordId)?;
    update_record_state(&database, &auth, record_id, RecordState::Done)
        .await
        .map_err(|err| match err {
            UpdateRecordError::RecordNotFound => MarkDoneError::NotFound,
            UpdateRecordError::ActivityNotFound => MarkDoneError::ActivityNotFound,
            UpdateRecordError::Forbidden => MarkDoneError::Forbidden,
        })?;
    Ok(ApiMessage::new("Mark done successfully"))
}

#[skyzen::error]
pub enum ApproveApplyError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid record id", status = BAD_REQUEST)]
    InvalidRecordId,

    #[error("Record not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Activity not exists", status = NOT_FOUND)]
    ActivityNotFound,
}

/// Disapprove apply
#[skyzen::openapi]
pub async fn approve_apply(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> Result<ApiMessage, ApproveApplyError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ApproveApplyError::SessionExpired,
        _ => ApproveApplyError::Forbidden,
    })?;
    let record_id = parse_oid(
        params
            .get("id")
            .map_err(|_| ApproveApplyError::InvalidRecordId)?,
    )
    .map_err(|_| ApproveApplyError::InvalidRecordId)?;
    update_record_state(&database, &auth, record_id, RecordState::Todo)
        .await
        .map_err(|err| match err {
            UpdateRecordError::RecordNotFound => ApproveApplyError::NotFound,
            UpdateRecordError::ActivityNotFound => ApproveApplyError::ActivityNotFound,
            UpdateRecordError::Forbidden => ApproveApplyError::Forbidden,
        })?;
    Ok(ApiMessage::new("Approve apply successfully"))
}

#[skyzen::error]
pub enum DisapproveApplyError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid record id", status = BAD_REQUEST)]
    InvalidRecordId,

    #[error("Record not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Activity not exists", status = NOT_FOUND)]
    ActivityNotFound,
}

/// Disapprove a volunteer's application
#[skyzen::openapi]
pub async fn disapprove_apply(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> Result<ApiMessage, DisapproveApplyError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => DisapproveApplyError::SessionExpired,
        _ => DisapproveApplyError::Forbidden,
    })?;
    let record_id = parse_oid(
        params
            .get("id")
            .map_err(|_| DisapproveApplyError::InvalidRecordId)?,
    )
    .map_err(|_| DisapproveApplyError::InvalidRecordId)?;
    update_record_state(&database, &auth, record_id, RecordState::Canneled)
        .await
        .map_err(|err| match err {
            UpdateRecordError::RecordNotFound => DisapproveApplyError::NotFound,
            UpdateRecordError::ActivityNotFound => DisapproveApplyError::ActivityNotFound,
            UpdateRecordError::Forbidden => DisapproveApplyError::Forbidden,
        })?;
    Ok(ApiMessage::new("Disapprove apply successfully"))
}
