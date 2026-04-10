use models::NotificationType;
use serde::{Deserialize, Serialize};
use skyzen::{extract::Query, utils::Json, utils::State};
use sqlx::Row;
use time::OffsetDateTime;
use tracing::error;

use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    push::PushHub,
    utils::{ApiMessage, Id},
};

// ---------------------------------------------------------------------------
// Response types
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize)]
pub struct NotificationResponse {
    pub id: Id,
    pub user_id: Id,
    pub notification_type: String,
    pub payload: serde_json::Value,
    pub read_at: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct UnreadCountResponse {
    pub count: i64,
}

#[derive(Debug, Serialize)]
pub struct NotificationPreferenceResponse {
    pub notification_type: String,
    pub enabled: bool,
}

// ---------------------------------------------------------------------------
// Request types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    pub unread_only: Option<String>,
    pub limit: Option<i64>,
    pub before: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct MarkReadForm {
    pub ids: Option<Vec<String>>,
    pub all: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct UpdatePreferencesForm {
    pub preferences: Vec<PreferenceEntry>,
}

#[derive(Debug, Deserialize)]
pub struct PreferenceEntry {
    pub notification_type: String,
    pub enabled: bool,
}

// ---------------------------------------------------------------------------
// SSE push payload
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize)]
pub struct NotificationPush {
    pub id: Id,
    pub notification_type: String,
    pub payload: serde_json::Value,
    pub created_at: String,
}

// ---------------------------------------------------------------------------
// Internal helpers — used by trigger points in message/activity/record
// ---------------------------------------------------------------------------

/// Create a notification for a single user, respecting their preferences.
pub async fn create_notification(
    database: &AppDatabase,
    hub: &PushHub,
    user_id: Id,
    notification_type: NotificationType,
    payload_json: &str,
) {
    if !is_notification_enabled(database, &user_id, notification_type).await {
        return;
    }

    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    let result = sqlx::query(
        database
            .sql(
                "INSERT INTO notifications (id, user_id, notification_type, payload, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(user_id.to_string())
    .bind(notification_type.as_str())
    .bind(payload_json)
    .bind(&now)
    .execute(database.sqlx())
    .await;

    if let Err(err) = result {
        error!(error = %err, "Failed to insert notification");
        return;
    }

    let payload_value: serde_json::Value =
        serde_json::from_str(payload_json).unwrap_or(serde_json::Value::Null);
    let push_payload = NotificationPush {
        id,
        notification_type: notification_type.as_str().to_string(),
        payload: payload_value,
        created_at: now,
    };
    hub.send_json_to_user(user_id, "notification", &push_payload)
        .await;
}

/// Create notifications for multiple users, respecting each user's preferences.
pub async fn create_notifications_batch(
    database: &AppDatabase,
    hub: &PushHub,
    user_ids: &[Id],
    notification_type: NotificationType,
    payload_json: &str,
) {
    for &user_id in user_ids {
        create_notification(database, hub, user_id, notification_type, payload_json).await;
    }
}

/// Serialize a typed payload to JSON, logging errors.
pub fn serialize_payload<T: serde::Serialize>(payload: &T) -> Option<String> {
    match serde_json::to_string(payload) {
        Ok(json) => Some(json),
        Err(err) => {
            error!(error = %err, "Failed to serialize notification payload");
            None
        }
    }
}

async fn is_notification_enabled(
    database: &AppDatabase,
    user_id: &Id,
    notification_type: NotificationType,
) -> bool {
    let row = sqlx::query(
        database
            .sql(
                "SELECT enabled FROM notification_preferences WHERE user_id = ?1 AND notification_type = ?2",
            )
            .as_ref(),
    )
    .bind(user_id.to_string())
    .bind(notification_type.as_str())
    .fetch_optional(database.sqlx())
    .await;

    match row {
        Ok(Some(row)) => {
            let enabled: i32 = row.try_get("enabled").unwrap_or(1);
            enabled != 0
        }
        Ok(None) => true, // default: enabled
        Err(err) => {
            error!(error = %err, "Failed to check notification preference");
            true // fail-open: send the notification
        }
    }
}

// ---------------------------------------------------------------------------
// API: List notifications
// ---------------------------------------------------------------------------

#[skyzen::error]
pub enum ListNotificationsError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    query: Query<ListQuery>,
    session: AuthSession,
) -> Result<Json<Vec<NotificationResponse>>, ListNotificationsError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListNotificationsError::SessionExpired,
        _ => ListNotificationsError::Forbidden,
    })?;

    let Query(params) = query;
    let unread_only = params.unread_only.as_deref() == Some("1");
    let limit = params.limit.unwrap_or(50).min(200);

    let mut sql = String::from("SELECT id, user_id, notification_type, payload, read_at, created_at FROM notifications WHERE user_id = ?1");
    let mut bind_idx = 1;

    if unread_only {
        sql.push_str(" AND read_at IS NULL");
    }
    if params.before.is_some() {
        bind_idx += 1;
        sql.push_str(&format!(" AND created_at < ?{bind_idx}"));
    }
    bind_idx += 1;
    sql.push_str(&format!(" ORDER BY created_at DESC LIMIT ?{bind_idx}"));

    let sql = database.sql(&sql);
    let mut query = sqlx::query(sql.as_ref()).bind(auth.uid().to_string());

    if let Some(before) = &params.before {
        query = query.bind(before.clone());
    }
    query = query.bind(limit);

    let rows = query
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");

    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let id: Id = row
            .get::<String, _>("id")
            .parse()
            .expect("Database error");
        let user_id: Id = row
            .get::<String, _>("user_id")
            .parse()
            .expect("Database error");
        let payload_str: String = row.get("payload");
        let payload: serde_json::Value =
            serde_json::from_str(&payload_str).unwrap_or(serde_json::Value::Null);

        result.push(NotificationResponse {
            id,
            user_id,
            notification_type: row.get("notification_type"),
            payload,
            read_at: row.get("read_at"),
            created_at: row.get("created_at"),
        });
    }

    Ok(Json(result))
}

// ---------------------------------------------------------------------------
// API: Mark notifications as read
// ---------------------------------------------------------------------------

#[skyzen::error]
pub enum MarkReadError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn mark_read(
    database: State<AppDatabase>,
    form: Json<MarkReadForm>,
    session: AuthSession,
) -> Result<ApiMessage, MarkReadError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => MarkReadError::SessionExpired,
        _ => MarkReadError::Forbidden,
    })?;

    let Json(form) = form;
    let now = OffsetDateTime::now_utc().to_string();

    if form.all == Some(true) {
        sqlx::query(
            database
                .sql("UPDATE notifications SET read_at = ?1 WHERE user_id = ?2 AND read_at IS NULL")
                .as_ref(),
        )
        .bind(&now)
        .bind(auth.uid().to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");
    } else if let Some(ids) = form.ids {
        for id_str in &ids {
            sqlx::query(
                database
                    .sql("UPDATE notifications SET read_at = ?1 WHERE id = ?2 AND user_id = ?3")
                    .as_ref(),
            )
            .bind(&now)
            .bind(id_str)
            .bind(auth.uid().to_string())
            .execute(database.sqlx())
            .await
            .expect("Database error");
        }
    }

    Ok(ApiMessage::new("Notifications marked as read"))
}

// ---------------------------------------------------------------------------
// API: Unread count
// ---------------------------------------------------------------------------

#[skyzen::error]
pub enum UnreadCountError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn unread_count(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<Json<UnreadCountResponse>, UnreadCountError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => UnreadCountError::SessionExpired,
        _ => UnreadCountError::Forbidden,
    })?;

    let row = sqlx::query(
        database
            .sql("SELECT COUNT(*) as cnt FROM notifications WHERE user_id = ?1 AND read_at IS NULL")
            .as_ref(),
    )
    .bind(auth.uid().to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("Database error");

    let count: i64 = row.try_get("cnt").unwrap_or(0);
    Ok(Json(UnreadCountResponse { count }))
}

// ---------------------------------------------------------------------------
// API: Get preferences
// ---------------------------------------------------------------------------

#[skyzen::error]
pub enum PreferencesError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::openapi]
pub async fn get_preferences(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<Json<Vec<NotificationPreferenceResponse>>, PreferencesError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => PreferencesError::SessionExpired,
        _ => PreferencesError::Forbidden,
    })?;

    let rows = sqlx::query(
        database
            .sql("SELECT notification_type, enabled FROM notification_preferences WHERE user_id = ?1")
            .as_ref(),
    )
    .bind(auth.uid().to_string())
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut saved: std::collections::HashMap<String, bool> = std::collections::HashMap::new();
    for row in rows {
        let nt: String = row.get("notification_type");
        let enabled: i32 = row.try_get("enabled").unwrap_or(1);
        saved.insert(nt, enabled != 0);
    }

    let result: Vec<NotificationPreferenceResponse> = NotificationType::ALL
        .iter()
        .map(|nt| NotificationPreferenceResponse {
            notification_type: nt.as_str().to_string(),
            enabled: saved.get(nt.as_str()).copied().unwrap_or(true),
        })
        .collect();

    Ok(Json(result))
}

// ---------------------------------------------------------------------------
// API: Update preferences
// ---------------------------------------------------------------------------

#[skyzen::openapi]
pub async fn update_preferences(
    database: State<AppDatabase>,
    form: Json<UpdatePreferencesForm>,
    session: AuthSession,
) -> Result<ApiMessage, PreferencesError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => PreferencesError::SessionExpired,
        _ => PreferencesError::Forbidden,
    })?;

    let Json(form) = form;

    for entry in &form.preferences {
        // Validate the notification type
        if NotificationType::from_str(&entry.notification_type).is_none() {
            continue;
        }

        // Delete existing and insert fresh (UPSERT equivalent)
        sqlx::query(
            database
                .sql(
                    "DELETE FROM notification_preferences WHERE user_id = ?1 AND notification_type = ?2",
                )
                .as_ref(),
        )
        .bind(auth.uid().to_string())
        .bind(&entry.notification_type)
        .execute(database.sqlx())
        .await
        .expect("Database error");

        sqlx::query(
            database
                .sql(
                    "INSERT INTO notification_preferences (user_id, notification_type, enabled) VALUES (?1, ?2, ?3)",
                )
                .as_ref(),
        )
        .bind(auth.uid().to_string())
        .bind(&entry.notification_type)
        .bind(if entry.enabled { 1 } else { 0 })
        .execute(database.sqlx())
        .await
        .expect("Database error");
    }

    Ok(ApiMessage::new("Preferences updated"))
}
