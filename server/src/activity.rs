use crate::{
    auth::AuthSession,
    database::AppDatabase,
    record, user,
    utils::{parse_oid, ApiMessage},
};
use bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
};
use sqlx::{QueryBuilder, Row, Sqlite};

#[derive(Debug, Deserialize)]
pub struct ListActivityQuery {
    user: Option<ObjectId>,
    display_all: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
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

#[derive(Debug, Serialize)]
pub struct ActivitySummary {
    id: ObjectId,
    name: String,
    location: String,
    volunteer_num: u16,
    max_volunteer_num: Option<u16>,
    promoter: ObjectId,
    promoter_name: String,
    date: Option<String>,
    brief_description: String,
    duration: u16,
    state: ActivityState,
}

#[derive(Debug, Serialize)]
pub struct ActivityDetail {
    id: ObjectId,
    name: String,
    location: String,
    volunteer_num: u16,
    max_volunteer_num: Option<u16>,
    promoter: ObjectId,
    promoter_name: String,
    date: Option<String>,
    description: String,
    volunteers: Vec<ObjectId>,
    duration: u16,
    state: ActivityState,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CreateActivityForm {
    name: String,
    date: Option<String>,
    max_volunteer_num: Option<u16>,
    description: String,
    location: String,
    brief_description: String,
    duration: u16,
}

fn parse_db_oid(hex: &str) -> skyzen::Result<ObjectId> {
    ObjectId::parse_str(hex).map_err(|_| {
        Error::msg("Corrupted activity data").set_status(StatusCode::INTERNAL_SERVER_ERROR)
    })
}

fn build_activity_summary(
    row: &sqlx::sqlite::SqliteRow,
    promoter: ObjectId,
    promoter_name: String,
) -> skyzen::Result<ActivitySummary> {
    let state =
        ActivityState::from_db(row.try_get::<String, _>("state")?.as_str()).ok_or_else(|| {
            Error::msg("Invalid activity state").set_status(StatusCode::INTERNAL_SERVER_ERROR)
        })?;
    Ok(ActivitySummary {
        id: parse_db_oid(&row.try_get::<String, _>("id")?)?,
        name: row.try_get("name")?,
        location: row.try_get("location")?,
        volunteer_num: row.try_get::<i64, _>("volunteer_num")? as u16,
        max_volunteer_num: row
            .try_get::<Option<i64>, _>("max_volunteer_num")?
            .map(|v| v as u16),
        promoter,
        promoter_name,
        date: row.try_get("date")?,
        brief_description: row.try_get("brief_description")?,
        duration: row.try_get::<i64, _>("duration_minutes")? as u16,
        state,
    })
}

pub async fn list(
    database: State<AppDatabase>,
    query: Query<ListActivityQuery>,
    session: AuthSession,
) -> skyzen::Result<Json<Vec<ActivitySummary>>> {
    session.into_auth().await?;
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
        builder.push(" AND promoter_id = ").push_bind(user.to_hex());
    }

    let rows = builder.build().fetch_all(database.sqlx()).await?;

    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let promoter = parse_db_oid(&row.try_get::<String, _>("promoter_id")?)?;
        let promoter_name = user::get_name(&database, promoter).await?;
        result.push(build_activity_summary(&row, promoter, promoter_name)?);
    }

    Ok(Json(result))
}

pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<Json<ActivityDetail>> {
    session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    let row = sqlx::query(
        "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, description, duration_minutes FROM activities WHERE id = ?1",
    )
    .bind(id.to_hex())
    .fetch_optional(database.sqlx())
    .await?
    .ok_or_else(|| Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;

    let promoter = parse_db_oid(&row.try_get::<String, _>("promoter_id")?)?;
    let promoter_name = user::get_name(&database, promoter).await?;
    let state =
        ActivityState::from_db(row.try_get::<String, _>("state")?.as_str()).ok_or_else(|| {
            Error::msg("Invalid activity state").set_status(StatusCode::INTERNAL_SERVER_ERROR)
        })?;
    let volunteers = record::get_volunteers(&database, id).await?;

    Ok(Json(ActivityDetail {
        id,
        name: row.try_get("name")?,
        location: row.try_get("location")?,
        volunteer_num: row.try_get::<i64, _>("volunteer_num")? as u16,
        max_volunteer_num: row
            .try_get::<Option<i64>, _>("max_volunteer_num")?
            .map(|v| v as u16),
        promoter,
        promoter_name,
        date: row.try_get("date")?,
        description: row.try_get("description")?,
        volunteers,
        duration: row.try_get::<i64, _>("duration_minutes")? as u16,
        state,
    }))
}

pub async fn join(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let activity_id = parse_oid(params.get("id")?)?;

    let row = sqlx::query("SELECT volunteer_num, max_volunteer_num FROM activities WHERE id = ?1")
        .bind(activity_id.to_hex())
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;

    let volunteer_num = row.try_get::<i64, _>("volunteer_num")?;
    if let Some(max) = row.try_get::<Option<i64>, _>("max_volunteer_num")? {
        if volunteer_num >= max {
            return Err(
                Error::msg("The activity needn't more people").set_status(StatusCode::FORBIDDEN)
            );
        }
    }

    let existing =
        sqlx::query("SELECT 1 FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
            .bind(activity_id.to_hex())
            .bind(auth.uid().to_hex())
            .fetch_optional(database.sqlx())
            .await?;
    if existing.is_some() {
        return Err(Error::msg("You had already joined!").set_status(StatusCode::FORBIDDEN));
    }

    record::create_record(&database, auth.uid(), activity_id).await?;
    sqlx::query("UPDATE activities SET volunteer_num = volunteer_num + 1 WHERE id = ?1")
        .bind(activity_id.to_hex())
        .execute(database.sqlx())
        .await?;

    Ok(ApiMessage::new("Join activity successfully"))
}

pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    let activity = sqlx::query("SELECT promoter_id FROM activities WHERE id = ?1")
        .bind(id.to_hex())
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Activity not exists").set_status(StatusCode::NOT_FOUND))?;
    let promoter_hex: String = activity.try_get("promoter_id")?;

    if promoter_hex != auth.uid().to_hex()
        && !auth.match_authority("delete_activity_anyway").await?
    {
        return Err(
            Error::msg("You have no access to this activity").set_status(StatusCode::FORBIDDEN)
        );
    }

    sqlx::query("DELETE FROM activities WHERE id = ?1")
        .bind(id.to_hex())
        .execute(database.sqlx())
        .await?;

    Ok(ApiMessage::new("Delete activity successfully"))
}

pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<CreateActivityForm>,
) -> skyzen::Result<Json<ActivityDetail>> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("create_activity").await?;
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
    let id = ObjectId::new();

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
    .bind(id.to_hex())
    .bind(auth.uid().to_hex())
    .bind(&name)
    .bind(&location)
    .bind(ActivityState::NeedVolunteer.as_str())
    .bind(max_volunteer_num.map(|v| v as i64))
    .bind(date.as_deref())
    .bind(&brief_description)
    .bind(&description)
    .bind(i64::from(duration))
    .execute(database.sqlx())
    .await?;

    let promoter_name = user::get_name(&database, auth.uid()).await?;

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

async fn change_state(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
    state: ActivityState,
) -> skyzen::Result<ApiMessage> {
    session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    sqlx::query("UPDATE activities SET state = ?1 WHERE id = ?2")
        .bind(state.as_str())
        .bind(id.to_hex())
        .execute(database.sqlx())
        .await?;
    Ok(ApiMessage::new(format!(
        "Activity is {} now",
        state.as_str()
    )))
}

pub async fn turn_need_volunteer(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    change_state(database, params, session, ActivityState::NeedVolunteer).await
}

pub async fn turn_going(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    change_state(database, params, session, ActivityState::Going).await
}

pub async fn turn_ended(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    change_state(database, params, session, ActivityState::Ended).await
}

pub async fn turn_canceled(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    change_state(database, params, session, ActivityState::Canneled).await
}

pub async fn get_name(database: &AppDatabase, id: ObjectId) -> Result<Option<String>, sqlx::Error> {
    sqlx::query("SELECT name FROM activities WHERE id = ?1")
        .bind(id.to_hex())
        .fetch_optional(database.sqlx())
        .await?
        .map(|row| row.try_get("name"))
        .transpose()
}
