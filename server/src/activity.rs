use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    record, user,
    utils::{parse_oid, ApiMessage, Id},
};
use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
};
use sqlx::{QueryBuilder, Row, Sqlite};
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub struct ListActivityQuery {
    #[schema(value_type = String, nullable)]
    user: Option<Id>,
    display_all: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ActivityState {
    Going,
    NeedVolunteer,
    Ended,
    Canneled,
}

impl ActivityState {
    fn as_str(self) -> &'static str {
        match self {
            ActivityState::Going => "going",
            ActivityState::NeedVolunteer => "need_volunteer",
            ActivityState::Ended => "ended",
            ActivityState::Canneled => "canneled",
        }
    }

    fn from_db(value: &str) -> Option<Self> {
        Some(match value {
            "going" => ActivityState::Going,
            "need_volunteer" => ActivityState::NeedVolunteer,
            "ended" => ActivityState::Ended,
            "canneled" => ActivityState::Canneled,
            _ => return None,
        })
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ActivitySummary {
    #[schema(value_type = String)]
    id: Id,
    name: String,
    location: String,
    volunteer_num: u16,
    max_volunteer_num: Option<u16>,
    #[schema(value_type = String)]
    promoter: Id,
    promoter_name: String,
    date: Option<String>,
    brief_description: String,
    duration: u16,
    state: ActivityState,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ActivityDetail {
    id: Id,
    name: String,
    location: String,
    volunteer_num: u16,
    max_volunteer_num: Option<u16>,
    promoter: Id,
    promoter_name: String,
    date: Option<String>,
    description: String,
    volunteers: Vec<Id>,
    duration: u16,
    state: ActivityState,
}

#[derive(Debug, Deserialize, ToSchema)]
pub(crate) struct CreateActivityForm {
    name: String,
    date: Option<String>,
    max_volunteer_num: Option<u16>,
    description: String,
    location: String,
    brief_description: String,
    duration: u16,
}

#[skyzen::error]
pub enum ListActivitiesError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity state", status = INTERNAL_SERVER_ERROR)]
    InvalidState,

    #[error("Promoter not found", status = NOT_FOUND)]
    PromoterNotFound,
}

#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    query: Query<ListActivityQuery>,
    session: AuthSession,
) -> Result<Json<Vec<ActivitySummary>>, ListActivitiesError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListActivitiesError::SessionExpired,
        _ => ListActivitiesError::Forbidden,
    })?;
    let Query(query) = query;
    let mut builder = QueryBuilder::<Sqlite>::new(
        "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, brief_description, duration_minutes FROM activities WHERE 1=1",
    );

    if query.display_all.is_none() {
        builder
            .push(" AND state = ")
            .push_bind(ActivityState::NeedVolunteer.as_str());
    }

    if let Some(user) = query.user {
        builder
            .push(" AND promoter_id = ")
            .push_bind(user.to_string());
    }

    let rows = builder
        .build()
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");

    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let promoter = row
            .get::<String, _>("promoter_id")
            .parse()
            .map_err(|_| ListActivitiesError::InvalidState)?;
        let promoter_name = user::get_name(&database, promoter)
            .await
            .map_err(|_| ListActivitiesError::PromoterNotFound)?;
        let state = ActivityState::from_db(row.get::<String, _>("state").as_str())
            .ok_or(ListActivitiesError::InvalidState)?;
        result.push(ActivitySummary {
            id: row
                .get::<String, _>("id")
                .parse()
                .map_err(|_| ListActivitiesError::InvalidState)?,
            name: row.get("name"),
            location: row.get("location"),
            volunteer_num: row.get::<i64, _>("volunteer_num") as u16,
            max_volunteer_num: row
                .get::<Option<i64>, _>("max_volunteer_num")
                .map(|v| v as u16),
            promoter,
            promoter_name,
            date: row.get("date"),
            brief_description: row.get("brief_description"),
            duration: row.get::<i64, _>("duration_minutes") as u16,
            state,
        });
    }

    Ok(Json(result))
}

#[skyzen::error]
pub enum GetActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid activity state", status = INTERNAL_SERVER_ERROR)]
    InvalidState,

    #[error("Promoter not found", status = NOT_FOUND)]
    PromoterNotFound,
}

/// Get activity detail by ID
#[skyzen::openapi]
pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<Json<ActivityDetail>, GetActivityError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => GetActivityError::SessionExpired,
        _ => GetActivityError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| GetActivityError::InvalidActivityId)?,
    )
    .map_err(|_| GetActivityError::InvalidActivityId)?;
    let row = sqlx::query(
        "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, description, duration_minutes FROM activities WHERE id = ?1",
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(GetActivityError::NotFound)?;

    let promoter_hex: String = row
        .try_get("promoter_id")
        .map_err(|_| GetActivityError::InvalidState)?;
    let promoter: Id = promoter_hex
        .parse()
        .map_err(|_| GetActivityError::InvalidState)?;
    let promoter_name = user::get_name(&database, promoter)
        .await
        .map_err(|_| GetActivityError::PromoterNotFound)?;
    let state = ActivityState::from_db(
        row.try_get::<String, _>("state")
            .map_err(|_| GetActivityError::InvalidState)?
            .as_str(),
    )
    .ok_or(GetActivityError::InvalidState)?;
    let volunteers = record::get_volunteers(&database, id)
        .await
        .expect("Database error");

    Ok(Json(ActivityDetail {
        id,
        name: row.try_get("name").expect("Database error"),
        location: row.try_get("location").expect("Database error"),
        volunteer_num: row
            .try_get::<i64, _>("volunteer_num")
            .expect("Database error") as u16,
        max_volunteer_num: row
            .try_get::<Option<i64>, _>("max_volunteer_num")
            .expect("Database error")
            .map(|v| v as u16),
        promoter,
        promoter_name,
        date: row.try_get("date").expect("Database error"),
        description: row.try_get("description").expect("Database error"),
        volunteers,
        duration: row
            .try_get::<i64, _>("duration_minutes")
            .expect("Database error") as u16,
        state,
    }))
}

#[skyzen::error]
pub enum JoinActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("The activity needn't more people", status = FORBIDDEN)]
    Full,

    #[error("You had already joined!", status = FORBIDDEN)]
    AlreadyJoined,
}

/// Join an activity
#[skyzen::openapi]
pub async fn join(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, JoinActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => JoinActivityError::SessionExpired,
        _ => JoinActivityError::Forbidden,
    })?;
    let activity_id = parse_oid(
        params
            .get("id")
            .map_err(|_| JoinActivityError::InvalidActivityId)?,
    )
    .map_err(|_| JoinActivityError::InvalidActivityId)?;

    let row = sqlx::query("SELECT volunteer_num, max_volunteer_num FROM activities WHERE id = ?1")
        .bind(activity_id.to_string())
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error")
        .ok_or(JoinActivityError::NotFound)?;

    let volunteer_num = row
        .try_get::<i64, _>("volunteer_num")
        .expect("Database error");
    if let Some(max) = row
        .try_get::<Option<i64>, _>("max_volunteer_num")
        .expect("Database error")
    {
        if volunteer_num >= max {
            return Err(JoinActivityError::Full);
        }
    }

    let existing =
        sqlx::query("SELECT 1 FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
            .bind(activity_id.to_string())
            .bind(auth.uid().to_string())
            .fetch_optional(database.sqlx())
            .await
            .expect("Database error");
    if existing.is_some() {
        return Err(JoinActivityError::AlreadyJoined);
    }

    record::create_record(&database, auth.uid(), activity_id)
        .await
        .expect("Database error");
    sqlx::query("UPDATE activities SET volunteer_num = volunteer_num + 1 WHERE id = ?1")
        .bind(activity_id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(ApiMessage::new("Join activity successfully"))
}

#[skyzen::error]
pub enum DeleteActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,
}

/// Delete an activity
#[skyzen::openapi]
pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, DeleteActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => DeleteActivityError::SessionExpired,
        _ => DeleteActivityError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| DeleteActivityError::InvalidActivityId)?,
    )
    .map_err(|_| DeleteActivityError::InvalidActivityId)?;
    let activity = sqlx::query("SELECT promoter_id FROM activities WHERE id = ?1")
        .bind(id.to_string())
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error")
        .ok_or(DeleteActivityError::NotFound)?;
    let promoter_hex: String = activity.try_get("promoter_id").expect("Database error");

    if promoter_hex != auth.uid().to_string()
        && !auth
            .match_authority("delete_activity_anyway")
            .await
            .map_err(|_| DeleteActivityError::Forbidden)?
    {
        return Err(DeleteActivityError::Forbidden);
    }

    sqlx::query("DELETE FROM activities WHERE id = ?1")
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(ApiMessage::new("Delete activity successfully"))
}

#[skyzen::error]
pub enum CreateActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<CreateActivityForm>,
) -> Result<Json<ActivityDetail>, CreateActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => CreateActivityError::SessionExpired,
        _ => CreateActivityError::Forbidden,
    })?;
    auth.ensure_authority("create_activity")
        .await
        .map_err(|_| CreateActivityError::Forbidden)?;
    let Json(form) = form;
    let CreateActivityForm {
        name,
        date,
        max_volunteer_num,
        description,
        location,
        brief_description,
        duration,
    } = form;
    let id = Id::new();

    sqlx::query(
        r#"
        INSERT INTO activities (
            id,
            promoter_id,
            name,
            location,
            state,
            volunteer_num,
            max_volunteer_num,
            date,
            brief_description,
            description,
            duration_minutes
        ) VALUES (?1, ?2, ?3, ?4, ?5, 0, ?6, ?7, ?8, ?9, ?10)
        "#,
    )
    .bind(id.to_string())
    .bind(auth.uid().to_string())
    .bind(&name)
    .bind(&location)
    .bind(ActivityState::NeedVolunteer.as_str())
    .bind(max_volunteer_num.map(|v| v as i64))
    .bind(date.as_deref())
    .bind(&brief_description)
    .bind(&description)
    .bind(i64::from(duration))
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let promoter_name = user::get_name(&database, auth.uid())
        .await
        .expect("Database error");

    Ok(Json(ActivityDetail {
        id,
        name,
        location,
        volunteer_num: 0,
        max_volunteer_num,
        promoter: auth.uid(),
        promoter_name,
        date,
        description,
        volunteers: Vec::new(),
        duration,
        state: ActivityState::NeedVolunteer,
    }))
}

#[skyzen::error]
pub enum ChangeActivityStateError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

async fn change_state(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
    state: ActivityState,
) -> Result<ApiMessage, ChangeActivityStateError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ChangeActivityStateError::SessionExpired,
        _ => ChangeActivityStateError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| ChangeActivityStateError::InvalidActivityId)?,
    )
    .map_err(|_| ChangeActivityStateError::InvalidActivityId)?;
    sqlx::query("UPDATE activities SET state = ?1 WHERE id = ?2")
        .bind(state.as_str())
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");
    Ok(ApiMessage::new(format!(
        "Activity is {} now",
        state.as_str()
    )))
}

#[skyzen::error]
pub enum TurnNeedVolunteerError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

#[skyzen::openapi]
pub async fn turn_need_volunteer(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnNeedVolunteerError> {
    change_state(database, params, session, ActivityState::NeedVolunteer)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnNeedVolunteerError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnNeedVolunteerError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => {
                TurnNeedVolunteerError::InvalidActivityId
            }
        })
}

#[skyzen::error]
pub enum TurnGoingError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

#[skyzen::openapi]
pub async fn turn_going(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnGoingError> {
    change_state(database, params, session, ActivityState::Going)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnGoingError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnGoingError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnGoingError::InvalidActivityId,
        })
}

#[skyzen::error]
pub enum TurnEndedError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

/// Change activity state to `Ended`
#[skyzen::openapi]
pub async fn turn_ended(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnEndedError> {
    change_state(database, params, session, ActivityState::Ended)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnEndedError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnEndedError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnEndedError::InvalidActivityId,
        })
}

#[skyzen::error]
pub enum TurnCanceledError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

/// Change activity state to `Canceled`
#[skyzen::openapi]
pub async fn turn_canceled(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnCanceledError> {
    change_state(database, params, session, ActivityState::Canneled)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnCanceledError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnCanceledError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnCanceledError::InvalidActivityId,
        })
}
