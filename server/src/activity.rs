use std::collections::HashMap;

use crate::{
    auth::{Auth, AuthError, AuthSession},
    channel,
    database::AppDatabase,
    notification,
    push::PushHub,
    record, user,
    utils::{parse_oid, ApiMessage, Id},
};
use models::{
    ActivityDetail, ActivityState, ActivitySummary, CreateActivityForm, ListActivityQuery,
    RecordState,
};
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
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListActivitiesError::SessionExpired,
        _ => ListActivitiesError::Forbidden,
    })?;
    let Query(query_params) = query;
    let can_view_all = auth
        .match_authority("view_all_activities")
        .await
        .unwrap_or(false);

    // When display_all is set (admin/teacher mode), scope to own activities
    // unless the user has view_all_activities (admin)
    let user_filter = if query_params.display_all.is_some() && !can_view_all {
        Some(auth.uid().to_string())
    } else {
        query_params.user.map(|user| user.to_string())
    };

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
    sql_text.push_str(" ORDER BY COALESCE(date, '') ASC, name ASC");

    let sql = database.sql(&sql_text);
    let mut query = sqlx::query(sql.as_ref());
    if query_params.display_all.is_none() {
        query = query.bind(ActivityState::NeedVolunteer.as_str());
    }
    if let Some(user) = user_filter {
        query = query.bind(user);
    }

    let rows = query
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");
    let viewer_states = load_viewer_record_states(&database, auth.uid())
        .await
        .expect("Database error");

    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let id: Id = row
            .get::<String, _>("id")
            .parse()
            .map_err(|_| ListActivitiesError::InvalidState)?;
        let promoter = row
            .get::<String, _>("promoter_id")
            .parse()
            .map_err(|_| ListActivitiesError::InvalidState)?;
        let promoter_name = user::get_name(&database, promoter)
            .await
            .map_err(|_| ListActivitiesError::PromoterNotFound)?;
        let state = ActivityState::from_db(row.get::<String, _>("state").as_str())
            .ok_or(ListActivitiesError::InvalidState)?;
        let viewer_record_state = viewer_states.get(&id).copied();
        let viewer_participating = matches!(
            viewer_record_state,
            Some(RecordState::Approved) | Some(RecordState::Confirmed)
        );
        result.push(ActivitySummary {
            id,
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
            viewer_participating,
            viewer_record_state,
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
    let auth = session.into_auth().await.map_err(|err| match err {
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
    let viewer_record_state = record::get_user_record_state(&database, id, auth.uid())
        .await
        .expect("Database error");
    let viewer_participating = matches!(
        viewer_record_state,
        Some(RecordState::Approved) | Some(RecordState::Confirmed)
    );

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
        viewer_participating,
        viewer_record_state,
    }))
}

#[skyzen::error]
pub enum ApplyActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Activity is not open for joining", status = FORBIDDEN)]
    NotRecruiting,

    #[error("The activity needn't more people", status = FORBIDDEN)]
    Full,

    #[error("You had already joined!", status = FORBIDDEN)]
    AlreadyJoined,
}

/// Apply for an activity
#[skyzen::openapi]
pub async fn apply(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, ApplyActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ApplyActivityError::SessionExpired,
        _ => ApplyActivityError::Forbidden,
    })?;
    let activity_id = parse_oid(
        params
            .get("id")
            .map_err(|_| ApplyActivityError::InvalidActivityId)?,
    )
    .map_err(|_| ApplyActivityError::InvalidActivityId)?;

    let mut db_conn = database.sqlx().acquire().await.expect("Database error");
    let conn = db_conn.as_mut();
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
            .sql("SELECT volunteer_num, max_volunteer_num, state FROM activities WHERE id = ?1")
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
            return Err(ApplyActivityError::NotFound);
        }
    };

    let current_state = row.try_get::<String, _>("state").expect("Database error");
    if ActivityState::from_db(&current_state) != Some(ActivityState::NeedVolunteer) {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(ApplyActivityError::NotRecruiting);
    }

    let volunteer_num = row
        .try_get::<i64, _>("volunteer_num")
        .expect("Database error");
    if let Some(max) = row
        .try_get::<Option<i64>, _>("max_volunteer_num")
        .expect("Database error")
    {
        if volunteer_num >= max {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(ApplyActivityError::Full);
        }
    }

    let existing = sqlx::query(
        database
            .sql("SELECT id, state FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .bind(auth.uid().to_string())
    .fetch_optional(&mut *conn)
    .await
    .expect("Database error");
    match existing {
        Some(row) => {
            let existing_record_id: String = row.try_get("id").expect("Database error");
            let existing_state = row.try_get::<String, _>("state").expect("Database error");
            if RecordState::from_db(&existing_state) != Some(RecordState::Canceled) {
                let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
                return Err(ApplyActivityError::AlreadyJoined);
            }

            let now = time::OffsetDateTime::now_utc().to_string();
            sqlx::query(
                database
                    .sql("UPDATE records SET state = ?1, confirmed_minutes = 0, confirmed_at = NULL, confirmed_by = NULL, updated_at = ?2 WHERE id = ?3")
                    .as_ref(),
            )
            .bind(RecordState::PendingApproval.as_str())
            .bind(now)
            .bind(existing_record_id)
            .execute(&mut *conn)
            .await
            .expect("Database error");
        }
        None => {
            record::create_record(&database, &mut *conn, auth.uid(), activity_id)
                .await
                .expect("Database error");
        }
    }
    sqlx::query("COMMIT")
        .execute(&mut *conn)
        .await
        .expect("Database error");
    drop(db_conn);

    Ok(ApiMessage::new("Apply activity successfully"))
}

#[skyzen::error]
pub enum WithdrawActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Activity is not open for leaving", status = FORBIDDEN)]
    CannotLeaveNow,

    #[error("You have not joined this activity", status = FORBIDDEN)]
    NotJoined,
}

/// Withdraw a pending application and mark the record as canceled.
#[skyzen::openapi]
pub async fn withdraw(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, WithdrawActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => WithdrawActivityError::SessionExpired,
        _ => WithdrawActivityError::Forbidden,
    })?;
    let activity_id = parse_oid(
        params
            .get("id")
            .map_err(|_| WithdrawActivityError::InvalidActivityId)?,
    )
    .map_err(|_| WithdrawActivityError::InvalidActivityId)?;

    let mut db_conn = database.sqlx().acquire().await.expect("Database error");
    let conn = db_conn.as_mut();
    let begin_stmt = match database.kind() {
        crate::database::DatabaseKind::Sqlite => "BEGIN IMMEDIATE",
        crate::database::DatabaseKind::Postgres => "BEGIN",
    };
    sqlx::query(begin_stmt)
        .execute(&mut *conn)
        .await
        .expect("Database error");

    let activity = sqlx::query(
        database
            .sql("SELECT state FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_optional(&mut *conn)
    .await
    .expect("Database error");
    let activity = match activity {
        Some(activity) => activity,
        None => {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(WithdrawActivityError::NotFound);
        }
    };
    let current_state = activity
        .try_get::<String, _>("state")
        .expect("Database error");
    if ActivityState::from_db(&current_state) == Some(ActivityState::Ended)
        || ActivityState::from_db(&current_state) == Some(ActivityState::Canceled)
    {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(WithdrawActivityError::CannotLeaveNow);
    }

    let record = sqlx::query(
        database
            .sql("SELECT id, state FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .bind(auth.uid().to_string())
    .fetch_optional(&mut *conn)
    .await
    .expect("Database error");
    let record = match record {
        Some(record) => record,
        None => {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(WithdrawActivityError::NotJoined);
        }
    };
    let record_state = record
        .try_get::<String, _>("state")
        .expect("Database error");
    if RecordState::from_db(&record_state) != Some(RecordState::PendingApproval) {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(WithdrawActivityError::NotJoined);
    }

    let now = time::OffsetDateTime::now_utc().to_string();
    sqlx::query(
        database
            .sql("UPDATE records SET state = ?1, confirmed_minutes = 0, confirmed_at = NULL, confirmed_by = NULL, updated_at = ?2 WHERE id = ?3")
            .as_ref(),
    )
    .bind(RecordState::Canceled.as_str())
    .bind(now)
    .bind(record.try_get::<String, _>("id").expect("Database error"))
    .execute(&mut *conn)
    .await
    .expect("Database error");
    sqlx::query("COMMIT")
        .execute(&mut *conn)
        .await
        .expect("Database error");
    drop(db_conn);

    Ok(ApiMessage::new("Withdraw application successfully"))
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

    channel::ensure_activity_channel(&database, auth.uid(), id, &name)
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
        viewer_participating: false,
        viewer_record_state: None,
    }))
}

#[skyzen::error]
pub enum UpdateActivityError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,
}

#[skyzen::openapi]
pub async fn update(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
    form: Json<CreateActivityForm>,
) -> Result<Json<ActivityDetail>, UpdateActivityError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => UpdateActivityError::SessionExpired,
        _ => UpdateActivityError::Forbidden,
    })?;
    let activity_id = parse_oid(
        params
            .get("id")
            .map_err(|_| UpdateActivityError::InvalidActivityId)?,
    )
    .map_err(|_| UpdateActivityError::InvalidActivityId)?;
    ensure_manage_activity(&database, &auth, activity_id)
        .await
        .map_err(|err| match err {
            ManageActivityError::NotFound => UpdateActivityError::NotFound,
            ManageActivityError::Forbidden => UpdateActivityError::Forbidden,
        })?;

    let Json(form) = form;
    sqlx::query(
        database
            .sql(
                "UPDATE activities SET name = ?1, date = ?2, max_volunteer_num = ?3, description = ?4, location = ?5, brief_description = ?6, duration_minutes = ?7 WHERE id = ?8",
            )
            .as_ref(),
    )
    .bind(&form.name)
    .bind(form.date.as_deref())
    .bind(form.max_volunteer_num.map(i64::from))
    .bind(&form.description)
    .bind(&form.location)
    .bind(&form.brief_description)
    .bind(i64::from(form.duration))
    .bind(activity_id.to_string())
    .execute(database.sqlx())
    .await
    .expect("Database error");

    channel::rename_activity_channel(&database, activity_id, &form.name)
        .await
        .expect("Database error");

    let row = sqlx::query(
        database
            .sql(
                "SELECT id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, description, duration_minutes FROM activities WHERE id = ?1",
            )
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("Database error");
    let promoter_hex: String = row.try_get("promoter_id").expect("Database error");
    let promoter: Id = promoter_hex.parse().expect("Database error");
    let promoter_name = user::get_name(&database, promoter)
        .await
        .expect("Database error");
    let state = ActivityState::from_db(&row.try_get::<String, _>("state").expect("Database error"))
        .expect("Database error");
    let viewer_record_state = record::get_user_record_state(&database, activity_id, auth.uid())
        .await
        .expect("Database error");

    Ok(Json(ActivityDetail {
        id: activity_id,
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
        volunteers: record::get_volunteers(&database, activity_id)
            .await
            .expect("Database error"),
        duration: row
            .try_get::<i64, _>("duration_minutes")
            .expect("Database error") as u16,
        state,
        viewer_participating: matches!(viewer_record_state, Some(RecordState::Approved) | Some(RecordState::Confirmed)),
        viewer_record_state,
    }))
}

#[derive(Debug)]
enum ManageActivityError {
    NotFound,
    Forbidden,
}

async fn ensure_manage_activity(
    database: &AppDatabase,
    auth: &Auth,
    activity_id: Id,
) -> Result<(), ManageActivityError> {
    let row = sqlx::query(
        database
            .sql("SELECT promoter_id FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(ManageActivityError::NotFound)?;
    let promoter_hex: String = row.try_get("promoter_id").expect("Database error");
    if promoter_hex == auth.uid().to_string()
        || auth
            .match_authority("manage_activity_anyway")
            .await
            .map_err(|_| ManageActivityError::Forbidden)?
    {
        Ok(())
    } else {
        Err(ManageActivityError::Forbidden)
    }
}

#[skyzen::error]
pub enum ChangeActivityStateError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid state transition", status = FORBIDDEN)]
    InvalidTransition,
}

async fn change_state(
    database: State<AppDatabase>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
    target_state: ActivityState,
) -> Result<ApiMessage, ChangeActivityStateError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ChangeActivityStateError::SessionExpired,
        _ => ChangeActivityStateError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| ChangeActivityStateError::InvalidActivityId)?,
    )
    .map_err(|_| ChangeActivityStateError::InvalidActivityId)?;

    ensure_manage_activity(&database, &auth, id)
        .await
        .map_err(|err| match err {
            ManageActivityError::NotFound => ChangeActivityStateError::NotFound,
            ManageActivityError::Forbidden => ChangeActivityStateError::Forbidden,
        })?;

    let row = sqlx::query(
        database
            .sql("SELECT state, name FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(id.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("Database error");
    let current_state =
        ActivityState::from_db(&row.try_get::<String, _>("state").expect("Database error"))
            .ok_or(ChangeActivityStateError::InvalidTransition)?;
    let activity_name: String = row.try_get("name").expect("Database error");

    if !can_transition(current_state, target_state) {
        return Err(ChangeActivityStateError::InvalidTransition);
    }

    sqlx::query(
        database
            .sql("UPDATE activities SET state = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind(target_state.as_str())
    .bind(id.to_string())
    .execute(database.sqlx())
    .await
    .expect("Database error");

    if target_state == ActivityState::Canceled {
        sqlx::query(
            database
                .sql(
                    "UPDATE records SET state = 'canceled', confirmed_minutes = 0, confirmed_at = NULL, confirmed_by = NULL, updated_at = ?1 WHERE activity_id = ?2 AND state != 'confirmed'",
                )
                .as_ref(),
        )
        .bind(time::OffsetDateTime::now_utc().to_string())
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");
        record::recalculate_activity_volunteer_num(&database, id)
            .await
            .expect("Database error");
        record::sync_activity_channel_members(&database, id)
            .await
            .expect("Database error");
    }

    // Notify volunteers + promoter about state change (excluding the actor)
    notify_activity_state_change(&database, &hub, id, &activity_name, target_state, auth.uid())
        .await;

    Ok(ApiMessage::new(format!(
        "Activity is {} now",
        target_state.as_str()
    )))
}

async fn notify_activity_state_change(
    database: &AppDatabase,
    hub: &PushHub,
    activity_id: Id,
    activity_name: &str,
    new_state: ActivityState,
    actor_id: Id,
) {
    let payload = models::ActivityStatePayload {
        activity_id: activity_id.to_string(),
        activity_name: activity_name.to_string(),
        new_state: new_state.as_str().to_string(),
    };
    let Some(payload_json) = notification::serialize_payload(&payload) else {
        return;
    };

    // Load promoter id
    let promoter_row = sqlx::query(
        database
            .sql("SELECT promoter_id FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_optional(database.sqlx())
    .await;

    let promoter_id: Option<Id> = match promoter_row {
        Ok(Some(row)) => row
            .try_get::<String, _>("promoter_id")
            .ok()
            .and_then(|hex| hex.parse().ok()),
        _ => None,
    };

    // Load all users with records for this activity
    let rows = sqlx::query(
        database
            .sql("SELECT DISTINCT user_id FROM records WHERE activity_id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_all(database.sqlx())
    .await;

    let rows = match rows {
        Ok(rows) => rows,
        Err(_) => return,
    };

    let mut recipients: Vec<Id> = rows
        .iter()
        .filter_map(|row| {
            let hex: String = row.try_get("user_id").ok()?;
            hex.parse().ok()
        })
        .collect();

    // Add promoter if not already present
    if let Some(promoter) = promoter_id {
        if !recipients.contains(&promoter) {
            recipients.push(promoter);
        }
    }

    // Exclude the actor — they just performed this action
    recipients.retain(|&uid| uid != actor_id);

    notification::create_notifications_batch(
        database,
        hub,
        &recipients,
        models::NotificationType::ActivityStateChange,
        &payload_json,
    )
    .await;
}

fn can_transition(current: ActivityState, target: ActivityState) -> bool {
    match current {
        ActivityState::NeedVolunteer => {
            matches!(target, ActivityState::Going | ActivityState::Canceled)
        }
        ActivityState::Going => matches!(target, ActivityState::Ended | ActivityState::Canceled),
        ActivityState::Ended | ActivityState::Canceled => false,
    }
}

#[skyzen::error]
pub enum TurnNeedVolunteerError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid state transition", status = FORBIDDEN)]
    InvalidTransition,
}

#[skyzen::openapi]
pub async fn turn_need_volunteer(
    database: State<AppDatabase>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnNeedVolunteerError> {
    change_state(database, hub, params, session, ActivityState::NeedVolunteer)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnNeedVolunteerError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnNeedVolunteerError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => {
                TurnNeedVolunteerError::InvalidActivityId
            }
            ChangeActivityStateError::NotFound => TurnNeedVolunteerError::NotFound,
            ChangeActivityStateError::InvalidTransition => {
                TurnNeedVolunteerError::InvalidTransition
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

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid state transition", status = FORBIDDEN)]
    InvalidTransition,
}

#[skyzen::openapi]
pub async fn turn_going(
    database: State<AppDatabase>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnGoingError> {
    change_state(database, hub, params, session, ActivityState::Going)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnGoingError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnGoingError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnGoingError::InvalidActivityId,
            ChangeActivityStateError::NotFound => TurnGoingError::NotFound,
            ChangeActivityStateError::InvalidTransition => TurnGoingError::InvalidTransition,
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

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid state transition", status = FORBIDDEN)]
    InvalidTransition,
}

/// Change activity state to `Ended`
#[skyzen::openapi]
pub async fn turn_ended(
    database: State<AppDatabase>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnEndedError> {
    change_state(database, hub, params, session, ActivityState::Ended)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnEndedError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnEndedError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnEndedError::InvalidActivityId,
            ChangeActivityStateError::NotFound => TurnEndedError::NotFound,
            ChangeActivityStateError::InvalidTransition => TurnEndedError::InvalidTransition,
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

    #[error("Activity not exists", status = NOT_FOUND)]
    NotFound,

    #[error("Invalid state transition", status = FORBIDDEN)]
    InvalidTransition,
}

/// Change activity state to `Canceled`
#[skyzen::openapi]
pub async fn turn_canceled(
    database: State<AppDatabase>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, TurnCanceledError> {
    change_state(database, hub, params, session, ActivityState::Canceled)
        .await
        .map_err(|err| match err {
            ChangeActivityStateError::SessionExpired => TurnCanceledError::SessionExpired,
            ChangeActivityStateError::Forbidden => TurnCanceledError::Forbidden,
            ChangeActivityStateError::InvalidActivityId => TurnCanceledError::InvalidActivityId,
            ChangeActivityStateError::NotFound => TurnCanceledError::NotFound,
            ChangeActivityStateError::InvalidTransition => TurnCanceledError::InvalidTransition,
        })
}

async fn load_viewer_record_states(
    database: &AppDatabase,
    viewer: Id,
) -> Result<HashMap<Id, models::RecordState>, sqlx::Error> {
    let rows = sqlx::query(
        database
            .sql("SELECT activity_id, state FROM records WHERE user_id = ?1")
            .as_ref(),
    )
    .bind(viewer.to_string())
    .fetch_all(database.sqlx())
    .await?;

    let mut map = HashMap::with_capacity(rows.len());
    for row in rows {
        let activity_id: Id = row
            .try_get::<String, _>("activity_id")
            .expect("Database error")
            .parse()
            .expect("Database error");
        let state = row.try_get::<String, _>("state").expect("Database error");
        if let Some(parsed) = models::RecordState::from_db(&state) {
            map.insert(activity_id, parsed);
        }
    }
    Ok(map)
}
