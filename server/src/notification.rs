use models::{CreateNotificationForm, Notification};
use skyzen::utils::{Json, State};
use sqlx::Row;
use time::OffsetDateTime;

use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    push::PushHub,
    utils::Id,
};

#[skyzen::error]
pub enum NotificationError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
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
                "SELECT id, user_id, title, content, created_at FROM notifications WHERE user_id = ?1 ORDER BY created_at DESC",
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
    .bind(form.user.to_string())
    .bind(&form.title)
    .bind(&form.content)
    .bind(&now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let notification = Notification {
        id,
        user: form.user,
        title: form.title,
        content: form.content,
        created_at: now,
    };

    hub.send_json_to_user(notification.user, "notification", &notification)
        .await;

    Ok(Json(notification))
}
