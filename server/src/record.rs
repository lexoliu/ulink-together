use crate::{
    auth::{Auth, AuthError, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, ApiMessage, Id},
};

use models::{ActivityState, FindRecordForm, RecordEntry, RecordState};
use skyzen::{
    routing::Params,
    utils::{Form, State},
};
use sqlx::{Any, Executor, Row};
use time::OffsetDateTime;

pub async fn create_record<'e, E>(
    database: &AppDatabase,
    executor: E,
    uid: Id,
    activity_id: Id,
) -> Result<(), sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    sqlx::query(
        database
            .sql(
                "INSERT INTO records (id, activity_id, user_id, state, confirmed_minutes, confirmed_at, confirmed_by, updated_at) VALUES (?1, ?2, ?3, ?4, 0, NULL, NULL, ?5)",
            )
            .as_ref(),
    )
    .bind(Id::new().to_string())
    .bind(activity_id.to_string())
    .bind(uid.to_string())
    .bind(RecordState::Todo.as_str())
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(executor)
    .await?;
    Ok(())
}

pub async fn get_volunteers(
    database: &AppDatabase,
    activity_id: Id,
) -> Result<Vec<Id>, sqlx::Error> {
    let rows = sqlx::query(
        database
            .sql(
                "SELECT user_id FROM records WHERE activity_id = ?1 AND state NOT IN ('canceled', 'canneled', 'cancelled')",
            )
            .as_ref(),
    )
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

pub async fn get_user_record_state(
    database: &AppDatabase,
    activity_id: Id,
    user_id: Id,
) -> Result<Option<RecordState>, sqlx::Error> {
    let row = sqlx::query(
        database
            .sql("SELECT state FROM records WHERE activity_id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .bind(user_id.to_string())
    .fetch_optional(database.sqlx())
    .await?;

    Ok(row.and_then(|row| {
        let state: String = row.try_get("state").ok()?;
        RecordState::from_db(&state)
    }))
}

pub async fn sync_activity_channel_member(
    database: &AppDatabase,
    activity_id: Id,
    user_id: Id,
    include: bool,
) -> Result<(), sqlx::Error> {
    let rows = sqlx::query(
        database
            .sql("SELECT id FROM channels WHERE activity_id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_all(database.sqlx())
    .await?;

    for row in rows {
        let channel_id: String = row.try_get("id")?;
        if include {
            let exists = sqlx::query(
                database
                    .sql(
                        "SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2 LIMIT 1",
                    )
                    .as_ref(),
            )
            .bind(&channel_id)
            .bind(user_id.to_string())
            .fetch_optional(database.sqlx())
            .await?
            .is_some();
            if !exists {
                sqlx::query(
                    database
                        .sql("INSERT INTO channel_members (channel_id, user_id) VALUES (?1, ?2)")
                        .as_ref(),
                )
                .bind(&channel_id)
                .bind(user_id.to_string())
                .execute(database.sqlx())
                .await?;
            }
        } else {
            sqlx::query(
                database
                    .sql("DELETE FROM channel_members WHERE channel_id = ?1 AND user_id = ?2")
                    .as_ref(),
            )
            .bind(&channel_id)
            .bind(user_id.to_string())
            .execute(database.sqlx())
            .await?;
        }
    }

    Ok(())
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
    value.parse().map_err(|_| FindRecordsError::CorruptedId)
}

/// Find records by various criteria
#[skyzen::openapi]
pub async fn find(
    database: State<AppDatabase>,
    form: Form<FindRecordForm>,
    session: AuthSession,
) -> Result<skyzen::utils::Json<Vec<RecordEntry>>, FindRecordsError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindRecordsError::SessionExpired,
        _ => FindRecordsError::Forbidden,
    })?;
    let Form(form) = form;

    let can_view_any = auth
        .match_authority("view_record_anyway")
        .await
        .map_err(|_| FindRecordsError::Forbidden)?
        || auth
            .match_authority("manage_record_anyway")
            .await
            .map_err(|_| FindRecordsError::Forbidden)?;

    let effective_activity = form.activity;
    let effective_user = if let Some(user) = form.user {
        if user != auth.uid()
            && !can_view_any
            && !is_activity_manager_opt(&database, &auth, effective_activity)
                .await
                .map_err(|_| FindRecordsError::Forbidden)?
        {
            return Err(FindRecordsError::Forbidden);
        }
        Some(user)
    } else if effective_activity.is_some()
        && is_activity_manager_opt(&database, &auth, effective_activity)
            .await
            .map_err(|_| FindRecordsError::Forbidden)?
    {
        None
    } else {
        Some(auth.uid())
    };

    let mut sql_text = String::from(
        "SELECT records.id, records.user_id, records.activity_id, records.state, records.confirmed_minutes, records.updated_at, records.confirmed_at, activities.name AS activity_name, activities.date AS activity_date, activities.duration_minutes AS activity_duration FROM records JOIN activities ON activities.id = records.activity_id WHERE 1=1",
    );
    let mut bind_idx = 0;
    if effective_user.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND records.user_id = ?{bind_idx}"));
    }
    if effective_activity.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND records.activity_id = ?{bind_idx}"));
    }
    sql_text.push_str(" ORDER BY records.updated_at DESC");

    let sql = database.sql(&sql_text);
    let mut query = sqlx::query(sql.as_ref());
    if let Some(user) = effective_user {
        query = query.bind(user.to_string());
    }
    if let Some(activity) = effective_activity {
        query = query.bind(activity.to_string());
    }

    let records = query
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");

    let mut result = Vec::with_capacity(records.len());
    for row in records {
        let state_str: String = row.try_get("state").expect("Database error");
        let state = RecordState::from_db(&state_str).ok_or(FindRecordsError::CorruptedState)?;
        result.push(RecordEntry {
            record_id: parse_db_oid(&row.try_get::<String, _>("id").expect("Database error"))?,
            user: parse_db_oid(&row.try_get::<String, _>("user_id").expect("Database error"))?,
            activity: parse_db_oid(
                &row.try_get::<String, _>("activity_id")
                    .expect("Database error"),
            )?,
            state,
            activity_name: row.try_get("activity_name").ok(),
            activity_date: row.try_get("activity_date").ok(),
            activity_duration: row
                .try_get::<i64, _>("activity_duration")
                .ok()
                .map(|duration| duration as u16),
            confirmed_minutes: row
                .try_get::<i64, _>("confirmed_minutes")
                .expect("Database error") as u16,
            updated_at: row.try_get("updated_at").expect("Database error"),
            confirmed_at: row.try_get("confirmed_at").ok(),
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

    #[error("Activity must be completed before hours can be confirmed", status = CONFLICT)]
    ActivityNotCompleted,
}

async fn update_record_state(
    database: &AppDatabase,
    auth: &Auth,
    record_id: Id,
    state: RecordState,
) -> Result<(), UpdateRecordError> {
    let record_hex = record_id.to_string();
    let row = sqlx::query(
        database
            .sql("SELECT activity_id, user_id FROM records WHERE id = ?1")
            .as_ref(),
    )
    .bind(&record_hex)
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(UpdateRecordError::RecordNotFound)?;
    let activity_hex: String = row.try_get("activity_id").expect("Database error");
    let user_hex: String = row.try_get("user_id").expect("Database error");

    let activity = sqlx::query(
        database
            .sql("SELECT promoter_id, duration_minutes, state FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(&activity_hex)
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(UpdateRecordError::ActivityNotFound)?;
    let promoter_hex: String = activity.try_get("promoter_id").expect("Database error");
    let activity_state = ActivityState::from_db(
        &activity
            .try_get::<String, _>("state")
            .expect("Database error"),
    )
    .expect("Database error");

    if promoter_hex != auth.uid().to_string()
        && !auth
            .match_authority("manage_record_anyway")
            .await
            .map_err(|_| UpdateRecordError::Forbidden)?
    {
        return Err(UpdateRecordError::Forbidden);
    }

    if state == RecordState::Done && activity_state != ActivityState::Ended {
        return Err(UpdateRecordError::ActivityNotCompleted);
    }

    let now = OffsetDateTime::now_utc().to_string();
    let confirmed_minutes = if state == RecordState::Done {
        activity
            .try_get::<i64, _>("duration_minutes")
            .expect("Database error")
    } else {
        0
    };
    let confirmed_at = if state == RecordState::Done {
        Some(now.clone())
    } else {
        None
    };
    let confirmed_by = if state == RecordState::Done {
        Some(auth.uid().to_string())
    } else {
        None
    };

    sqlx::query(
        database
            .sql(
                "UPDATE records SET state = ?1, confirmed_minutes = ?2, confirmed_at = ?3, confirmed_by = ?4, updated_at = ?5 WHERE id = ?6",
            )
            .as_ref(),
    )
    .bind(state.as_str())
    .bind(confirmed_minutes)
    .bind(confirmed_at.as_deref())
    .bind(confirmed_by.as_deref())
    .bind(&now)
    .bind(record_hex)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let activity_id: Id = activity_hex.parse().expect("Database error");
    let user_id: Id = user_hex.parse().expect("Database error");
    let include = state != RecordState::Canceled;
    sync_activity_channel_member(database, activity_id, user_id, include)
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

    #[error("Activity must be completed before hours can be confirmed", status = CONFLICT)]
    ActivityNotCompleted,
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
            UpdateRecordError::ActivityNotCompleted => MarkDoneError::ActivityNotCompleted,
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

/// Approve a volunteer application
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
            UpdateRecordError::ActivityNotCompleted => {
                unreachable!("activity completion is only required when marking records done")
            }
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
    update_record_state(&database, &auth, record_id, RecordState::Canceled)
        .await
        .map_err(|err| match err {
            UpdateRecordError::RecordNotFound => DisapproveApplyError::NotFound,
            UpdateRecordError::ActivityNotFound => DisapproveApplyError::ActivityNotFound,
            UpdateRecordError::Forbidden => DisapproveApplyError::Forbidden,
            UpdateRecordError::ActivityNotCompleted => {
                unreachable!("activity completion is only required when marking records done")
            }
        })?;
    Ok(ApiMessage::new("Disapprove apply successfully"))
}

async fn is_activity_manager_opt(
    database: &AppDatabase,
    auth: &Auth,
    activity_id: Option<Id>,
) -> Result<bool, sqlx::Error> {
    let Some(activity_id) = activity_id else {
        return Ok(false);
    };
    let row = sqlx::query(
        database
            .sql("SELECT promoter_id FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_optional(database.sqlx())
    .await?;
    Ok(match row {
        Some(row) => row.get::<String, _>("promoter_id") == auth.uid().to_string(),
        None => false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::build_test_database;
    use sqlx::Row;
    use time::OffsetDateTime;

    #[tokio::test]
    async fn create_record_inserts_todo_state() {
        let database = build_test_database().await;
        let activity_id = Id::new();
        let user_id = Id::new();

        create_record(&database, database.sqlx(), user_id, activity_id)
            .await
            .expect("create record");

        let row = sqlx::query(
            database
                .sql(
                    "SELECT state, user_id, activity_id, confirmed_minutes FROM records WHERE user_id = ?1 AND activity_id = ?2",
                )
                .as_ref(),
        )
        .bind(user_id.to_string())
        .bind(activity_id.to_string())
        .fetch_one(database.sqlx())
        .await
        .expect("fetch record");

        assert_eq!(row.get::<String, _>("state"), "todo");
        assert_eq!(row.get::<String, _>("user_id"), user_id.to_string());
        assert_eq!(row.get::<String, _>("activity_id"), activity_id.to_string());
        assert_eq!(row.get::<i64, _>("confirmed_minutes"), 0);
    }

    #[tokio::test]
    async fn get_volunteers_excludes_canneled_records() {
        let database = build_test_database().await;
        let activity_id = Id::new();
        let user_one = Id::new();
        let user_two = Id::new();
        let user_three = Id::new();
        let user_four = Id::new();

        let now = OffsetDateTime::now_utc().to_string();
        let records = vec![
            (Id::new(), user_one, "todo"),
            (Id::new(), user_two, "done"),
            (Id::new(), user_three, "canneled"),
            (Id::new(), user_four, "canceled"),
        ];

        for (record_id, user_id, state) in records {
            sqlx::query(
                database
                    .sql(
                        "INSERT INTO records (id, activity_id, user_id, state, confirmed_minutes, confirmed_at, confirmed_by, updated_at) VALUES (?1, ?2, ?3, ?4, 0, NULL, NULL, ?5)",
                    )
                    .as_ref(),
            )
            .bind(record_id.to_string())
            .bind(activity_id.to_string())
            .bind(user_id.to_string())
            .bind(state)
            .bind(&now)
            .execute(database.sqlx())
            .await
            .expect("insert record");
        }

        let volunteers = get_volunteers(&database, activity_id)
            .await
            .expect("fetch volunteers");

        assert!(volunteers.contains(&user_one));
        assert!(volunteers.contains(&user_two));
        assert!(!volunteers.contains(&user_three));
        assert!(!volunteers.contains(&user_four));
        assert_eq!(volunteers.len(), 2);
    }
}
