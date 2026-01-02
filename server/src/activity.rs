use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    record, user,
    utils::{parse_oid, ApiMessage, Id},
};
use models::{ActivityDetail, ActivityState, ActivitySummary, CreateActivityForm, ListActivityQuery};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;

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
    let Query(query_params) = query;
    let user_filter = query_params.user.map(|user| user.to_string());

    let mut sql_text = String::from(
        "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, brief_description, duration_minutes FROM activities WHERE 1=1",
    );
    let mut bind_idx = 0;
    if query_params.display_all.is_none() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND state = ?{bind_idx}"));
    }
    if user_filter.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND promoter_id = ?{bind_idx}"));
    }

    let sql = database.sql(&sql_text);
    let mut query = sqlx::query(sql.as_ref());
    if query_params.display_all.is_none() {
        query = query.bind(ActivityState::NeedVolunteer.as_str());
    }
    if let Some(user) = user_filter {
        query = query.bind(user);
    }

    let rows = query.fetch_all(database.sqlx()).await.expect("Database error");

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
        database
            .sql(
                "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, description, duration_minutes FROM activities WHERE id = ?1",
            )
            .as_ref(),
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

    let mut conn = database
        .sqlx()
        .acquire()
        .await
        .expect("Database error");
    let conn = conn.as_mut();
    let begin_stmt = match database.kind() {
        crate::database::DatabaseKind::Sqlite => "BEGIN IMMEDIATE",
        crate::database::DatabaseKind::Postgres => "BEGIN",
    };
    sqlx::query(begin_stmt)
        .execute(&mut *conn)
        .await
        .expect("Database error");

    let row = sqlx::query(
        database
            .sql("SELECT volunteer_num, max_volunteer_num FROM activities WHERE id = ?1")
            .as_ref(),
    )
        .bind(activity_id.to_string())
        .fetch_optional(&mut *conn)
        .await
        .expect("Database error");
    let row = match row {
        Some(row) => row,
        None => {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(JoinActivityError::NotFound);
        }
    };

    let volunteer_num = row
        .try_get::<i64, _>("volunteer_num")
        .expect("Database error");
    if let Some(max) = row
        .try_get::<Option<i64>, _>("max_volunteer_num")
        .expect("Database error")
    {
        if volunteer_num >= max {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(JoinActivityError::Full);
        }
    }

    let existing =
        sqlx::query(
            database
                .sql("SELECT 1 FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
                .as_ref(),
        )
            .bind(activity_id.to_string())
            .bind(auth.uid().to_string())
            .fetch_optional(&mut *conn)
            .await
            .expect("Database error");
    if existing.is_some() {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(JoinActivityError::AlreadyJoined);
    }

    record::create_record(&database, &mut *conn, auth.uid(), activity_id)
        .await
        .expect("Database error");
    sqlx::query(
        database
            .sql("UPDATE activities SET volunteer_num = volunteer_num + 1 WHERE id = ?1")
            .as_ref(),
    )
        .bind(activity_id.to_string())
        .execute(&mut *conn)
        .await
        .expect("Database error");
    sqlx::query("COMMIT")
        .execute(&mut *conn)
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
    let activity = sqlx::query(
        database
            .sql("SELECT promoter_id FROM activities WHERE id = ?1")
            .as_ref(),
    )
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

    sqlx::query(
        database
            .sql("DELETE FROM activities WHERE id = ?1")
            .as_ref(),
    )
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
        database
            .sql(
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
            .as_ref(),
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
    sqlx::query(
        database
            .sql("UPDATE activities SET state = ?1 WHERE id = ?2")
            .as_ref(),
    )
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
    change_state(database, params, session, ActivityState::Canceled)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnCanceledError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnCanceledError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnCanceledError::InvalidActivityId,
        })
}
