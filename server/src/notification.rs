use models::{CreateNotificationForm, Notification};
use serde::{Deserialize, Serialize};
use skyzen::{
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    push::PushHub,
    utils::{parse_oid, ApiMessage, Id},
};

#[derive(Debug, Deserialize, Serialize, ToSchema)]
pub struct CreateClassNotificationForm {
    pub classname: String,
    pub title: String,
    pub content: String,
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
pub struct CreateActivityNotificationForm {
    pub activity: Id,
    pub title: String,
    pub content: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct NotificationBatchResult {
    pub affected: u64,
}

#[skyzen::error]
pub enum NotificationError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid notification id", status = BAD_REQUEST)]
    InvalidNotificationId,

    #[error("Class name cannot be empty", status = BAD_REQUEST)]
    EmptyClassname,

    #[error("Notification not found", status = NOT_FOUND)]
    NotificationNotFound,

    #[error("Activity not exists", status = NOT_FOUND)]
    ActivityNotFound,

    #[error("No recipients found", status = NOT_FOUND)]
    NoRecipients,
}

/// List notifications for the current user.
#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<Json<Vec<Notification>>, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;

    let rows = sqlx::query(
        database
            .sql(
                "SELECT notifications.id, notifications.user_id, notifications.title, notifications.content, notifications.created_at, notification_reads.read_at FROM notifications LEFT JOIN notification_reads ON notification_reads.notification_id = notifications.id WHERE notifications.user_id = ?1 ORDER BY notifications.created_at DESC",
            )
            .as_ref(),
    )
    .bind(auth.uid().to_string())
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut notifications = Vec::with_capacity(rows.len());
    for row in rows {
        let user_hex: String = row.try_get("user_id").expect("Database error");
        notifications.push(Notification {
            id: row
                .try_get::<String, _>("id")
                .expect("Database error")
                .parse()
                .expect("Database error"),
            user: user_hex.parse().expect("Database error"),
            title: row.try_get("title").expect("Database error"),
            content: row.try_get("content").expect("Database error"),
            created_at: row.try_get("created_at").expect("Database error"),
            read_at: row.try_get("read_at").expect("Database error"),
        });
    }

    Ok(Json(notifications))
}

/// Create a notification for a user and push it immediately.
#[skyzen::openapi]
pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    hub: State<PushHub>,
    form: Json<CreateNotificationForm>,
) -> Result<Json<Notification>, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;
    auth.ensure_authority("send_notification")
        .await
        .map_err(|_| NotificationError::Forbidden)?;

    let Json(form) = form;
    let notification = create_single_notification(
        &database,
        &hub,
        form.user,
        form.title.as_str(),
        form.content.as_str(),
    )
    .await;

    Ok(Json(notification))
}

/// Mark one notification as read.
#[skyzen::openapi]
pub async fn mark_read(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
) -> Result<ApiMessage, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;
    let notification_id = parse_oid(
        params
            .get("id")
            .map_err(|_| NotificationError::InvalidNotificationId)?,
    )
    .map_err(|_| NotificationError::InvalidNotificationId)?;

    let exists = sqlx::query(
        database
            .sql("SELECT 1 FROM notifications WHERE id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(notification_id.to_string())
    .bind(auth.uid().to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .is_some();
    if !exists {
        return Err(NotificationError::NotificationNotFound);
    }

    let read_at = OffsetDateTime::now_utc().to_string();
    sqlx::query(
        database
            .sql("INSERT INTO notification_reads (notification_id, read_at) VALUES (?1, ?2) ON CONFLICT(notification_id) DO UPDATE SET read_at = excluded.read_at")
            .as_ref(),
    )
    .bind(notification_id.to_string())
    .bind(read_at)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(ApiMessage::new("Mark notification as read successfully"))
}

/// Mark all current-user notifications as read.
#[skyzen::openapi]
pub async fn mark_all_read(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<ApiMessage, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;

    let read_at = OffsetDateTime::now_utc().to_string();
    sqlx::query(
        database
            .sql("INSERT INTO notification_reads (notification_id, read_at) SELECT notifications.id, ?1 FROM notifications WHERE notifications.user_id = ?2 ON CONFLICT(notification_id) DO UPDATE SET read_at = excluded.read_at")
            .as_ref(),
    )
    .bind(read_at)
    .bind(auth.uid().to_string())
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(ApiMessage::new(
        "Mark all notifications as read successfully",
    ))
}

/// Create notifications for all students in a class.
#[skyzen::openapi]
pub async fn create_for_class(
    database: State<AppDatabase>,
    session: AuthSession,
    hub: State<PushHub>,
    form: Json<CreateClassNotificationForm>,
) -> Result<Json<NotificationBatchResult>, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;
    auth.ensure_authority("send_notification")
        .await
        .map_err(|_| NotificationError::Forbidden)?;

    let Json(form) = form;
    let classname = form.classname.trim();
    if classname.is_empty() {
        return Err(NotificationError::EmptyClassname);
    }

    let rows = sqlx::query(
        database
            .sql("SELECT users.id FROM users JOIN groups ON groups.id = users.group_id WHERE groups.code = ?1 AND users.classname = ?2 ORDER BY users.id ASC")
            .as_ref(),
    )
    .bind("student")
    .bind(classname)
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    if rows.is_empty() {
        return Err(NotificationError::NoRecipients);
    }

    let user_ids = rows
        .iter()
        .map(|row| {
            row.try_get::<String, _>("id")
                .expect("Database error")
                .parse::<Id>()
                .expect("Database error")
        })
        .collect::<Vec<_>>();

    for user_id in &user_ids {
        create_single_notification(&database, &hub, *user_id, &form.title, &form.content).await;
    }

    Ok(Json(NotificationBatchResult {
        affected: user_ids.len() as u64,
    }))
}

/// Create notifications for all active participants in an activity.
#[skyzen::openapi]
pub async fn create_for_activity(
    database: State<AppDatabase>,
    session: AuthSession,
    hub: State<PushHub>,
    form: Json<CreateActivityNotificationForm>,
) -> Result<Json<NotificationBatchResult>, NotificationError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => NotificationError::SessionExpired,
        _ => NotificationError::Forbidden,
    })?;
    auth.ensure_authority("send_notification")
        .await
        .map_err(|_| NotificationError::Forbidden)?;

    let Json(form) = form;
    let activity_id = form.activity;

    let activity_exists = sqlx::query(
        database
            .sql("SELECT 1 FROM activities WHERE id = ?1 LIMIT 1")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .is_some();
    if !activity_exists {
        return Err(NotificationError::ActivityNotFound);
    }

    let rows = sqlx::query(
        database
            .sql("SELECT DISTINCT user_id FROM records WHERE activity_id = ?1 AND state IN ('approved', 'confirmed')")
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    if rows.is_empty() {
        return Err(NotificationError::NoRecipients);
    }

    let user_ids = rows
        .iter()
        .map(|row| {
            row.try_get::<String, _>("user_id")
                .expect("Database error")
                .parse::<Id>()
                .expect("Database error")
        })
        .collect::<Vec<_>>();

    for user_id in &user_ids {
        create_single_notification(&database, &hub, *user_id, &form.title, &form.content).await;
    }

    Ok(Json(NotificationBatchResult {
        affected: user_ids.len() as u64,
    }))
}

async fn create_single_notification(
    database: &AppDatabase,
    hub: &PushHub,
    user: Id,
    title: &str,
    content: &str,
) -> Notification {
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        database
            .sql(
                "INSERT INTO notifications (id, user_id, title, content, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(user.to_string())
    .bind(title)
    .bind(content)
    .bind(&now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let notification = Notification {
        id,
        user,
        title: title.to_string(),
        content: content.to_string(),
        created_at: now,
        read_at: None,
    };
    hub.send_json_to_user(notification.user, "notification", &notification)
        .await;
    notification
}
