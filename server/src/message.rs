use std::str::FromStr;

use crate::{
    auth::{Auth, AuthError, AuthSession},
    channel,
    database::AppDatabase,
    notification,
    push::{MessagePush, PushHub},
    user,
    utils::{parse_oid, ApiMessage, Id},
};

use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub(crate) struct FindQuery {
    start_date: Option<String>,
    end_date: Option<String>,
    channel: String,
    sender: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
pub struct PostMessageForm {
    content: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct Message {
    id: Id,
    channel: Id,
    sender: Id,
    content: String,
    datetime: String,
}

#[skyzen::error]
pub enum FindMessagesError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid channel id", status = BAD_REQUEST)]
    InvalidChannelId,

    #[error("Invalid sender id", status = BAD_REQUEST)]
    InvalidSenderId,

    #[error("Corrupted message data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

fn parse_db_oid(value: &str) -> Result<Id, FindMessagesError> {
    Id::from_str(value).map_err(|_| FindMessagesError::CorruptedData)
}

/// Find messages by various criteria
#[skyzen::openapi]
pub async fn find(
    database: State<AppDatabase>,
    query: Query<FindQuery>,
    session: AuthSession,
) -> Result<Json<Vec<Message>>, FindMessagesError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindMessagesError::SessionExpired,
        _ => FindMessagesError::Forbidden,
    })?;
    let Query(query_params) = query;
    let channel_id =
        parse_oid(&query_params.channel).map_err(|_| FindMessagesError::InvalidChannelId)?;
    ensure_channel_visible(&database, &auth, &channel_id)
        .await
        .map_err(|_| FindMessagesError::Forbidden)?;

    let start = query_params.start_date.as_deref();
    let end = query_params.end_date.as_deref();
    let sender_hex = match &query_params.sender {
        Some(sender) => Some(
            parse_oid(sender)
                .map_err(|_| FindMessagesError::InvalidSenderId)?
                .to_string(),
        ),
        None => None,
    };

    let mut sql_text = String::from(
        "SELECT id, channel_id, sender_id, content, sent_at FROM messages WHERE channel_id = ?1",
    );
    let mut bind_idx = 1;
    if start.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND sent_at >= ?{bind_idx}"));
    }
    if end.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND sent_at <= ?{bind_idx}"));
    }
    if sender_hex.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND sender_id = ?{bind_idx}"));
    }
    sql_text.push_str(" ORDER BY sent_at DESC");

    let sql = database.sql(&sql_text);
    let mut db_query = sqlx::query(sql.as_ref());
    db_query = db_query.bind(channel_id.to_string());
    if let Some(start) = start {
        db_query = db_query.bind(start);
    }
    if let Some(end) = end {
        db_query = db_query.bind(end);
    }
    if let Some(sender_hex) = sender_hex {
        db_query = db_query.bind(sender_hex);
    }

    let rows = db_query
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");
    Ok(Json(
        rows.into_iter()
            .map(|row| {
                Ok(Message {
                    id: parse_db_oid(&row.try_get::<String, _>("id").expect("Database error"))?,
                    channel: parse_db_oid(
                        &row.try_get::<String, _>("channel_id")
                            .expect("Database error"),
                    )?,
                    sender: parse_db_oid(
                        &row.try_get::<String, _>("sender_id")
                            .expect("Database error"),
                    )?,
                    content: row.try_get("content").expect("Database error"),
                    datetime: row.try_get("sent_at").expect("Database error"),
                })
            })
            .collect::<Result<Vec<_>, _>>()?,
    ))
}

#[skyzen::error]
pub enum GetMessageError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid message id", status = BAD_REQUEST)]
    InvalidMessageId,

    #[error("Message not exist", status = NOT_FOUND)]
    NotFound,

    #[error("Corrupted message data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

/// Get message by ID
#[skyzen::openapi]
pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<Json<Message>, GetMessageError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => GetMessageError::SessionExpired,
        _ => GetMessageError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| GetMessageError::InvalidMessageId)?,
    )
    .map_err(|_| GetMessageError::InvalidMessageId)?;
    let row = sqlx::query(
        database
            .sql("SELECT id, channel_id, sender_id, content, sent_at FROM messages WHERE id = ?1")
            .as_ref(),
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(GetMessageError::NotFound)?;

    let channel_hex: String = row
        .try_get("channel_id")
        .map_err(|_| GetMessageError::CorruptedData)?;
    let channel_id = Id::from_str(&channel_hex).map_err(|_| GetMessageError::CorruptedData)?;
    ensure_channel_visible(&database, &auth, &channel_id)
        .await
        .map_err(|_| GetMessageError::Forbidden)?;
    let sender_hex: String = row
        .try_get("sender_id")
        .map_err(|_| GetMessageError::CorruptedData)?;
    Ok(Json(Message {
        id,
        channel: channel_id,
        sender: Id::from_str(&sender_hex).map_err(|_| GetMessageError::CorruptedData)?,
        content: row
            .try_get("content")
            .map_err(|_| GetMessageError::CorruptedData)?,
        datetime: row
            .try_get("sent_at")
            .map_err(|_| GetMessageError::CorruptedData)?,
    }))
}

async fn ensure_channel_visible(
    database: &AppDatabase,
    auth: &Auth,
    channel_id: &Id,
) -> Result<(), AuthError> {
    if auth.match_authority("view_channel_anyway").await? {
        return Ok(());
    }
    if channel::ensure_channel_member(database, channel_id, &auth.uid()).await {
        return Ok(());
    }

    let row = sqlx::query(
        database
            .sql("SELECT owner_id FROM channels WHERE id = ?1")
            .as_ref(),
    )
    .bind(channel_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error");
    let Some(row) = row else {
        return Err(AuthError::Forbidden);
    };
    let owner_hex: String = row.try_get("owner_id").expect("Database error");
    if owner_hex == auth.uid().to_string() {
        Ok(())
    } else {
        Err(AuthError::Forbidden)
    }
}

#[skyzen::error]
pub enum PostMessageError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid channel id", status = BAD_REQUEST)]
    InvalidChannelId,
}

#[skyzen::openapi]
pub async fn post(
    database: State<AppDatabase>,
    form: Json<PostMessageForm>,
    hub: State<PushHub>,
    params: Params,
    session: AuthSession,
) -> Result<Json<Message>, PostMessageError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => PostMessageError::SessionExpired,
        _ => PostMessageError::Forbidden,
    })?;
    let channel_id = parse_oid(
        params
            .get("id")
            .map_err(|_| PostMessageError::InvalidChannelId)?,
    )
    .map_err(|_| PostMessageError::InvalidChannelId)?;
    let can_post = channel::ensure_channel_member(&database, &channel_id, &auth.uid()).await
        || auth
            .match_authority("send_message_anyway")
            .await
            .map_err(|_| PostMessageError::Forbidden)?;
    if !can_post {
        return Err(PostMessageError::Forbidden);
    }
    if !channel::activity_channel_is_writable(&database, channel_id)
        .await
        .map_err(|_| PostMessageError::Forbidden)?
    {
        return Err(PostMessageError::Forbidden);
    }

    let Json(PostMessageForm { content }) = form;
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();
    sqlx::query(
        database
            .sql(
                "INSERT INTO messages (id, channel_id, sender_id, content, sent_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(channel_id.to_string())
    .bind(auth.uid().to_string())
    .bind(&content)
    .bind(&now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let push_payload = MessagePush {
        id,
        channel: channel_id,
        sender: auth.uid(),
        content: content.clone(),
        datetime: now.clone(),
    };
    push_message_to_channel(&database, &hub, &channel_id, &push_payload).await;

    // Trigger notifications for channel members
    notify_channel_members(&database, &hub, channel_id, auth.uid(), &content).await;

    Ok(Json(Message {
        id,
        channel: channel_id,
        sender: auth.uid(),
        content,
        datetime: now,
    }))
}

#[skyzen::error]
pub enum DeleteMessageError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid message id", status = BAD_REQUEST)]
    InvalidMessageId,

    #[error("Message not exist", status = NOT_FOUND)]
    NotFound,
}

/// Delete a message
#[skyzen::openapi]
pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, DeleteMessageError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => DeleteMessageError::SessionExpired,
        _ => DeleteMessageError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| DeleteMessageError::InvalidMessageId)?,
    )
    .map_err(|_| DeleteMessageError::InvalidMessageId)?;
    let row = sqlx::query(
        database
            .sql("SELECT sender_id FROM messages WHERE id = ?1")
            .as_ref(),
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(DeleteMessageError::NotFound)?;
    let sender_hex: String = row.try_get("sender_id").expect("Database error");

    if sender_hex != auth.uid().to_string()
        && !auth
            .match_authority("delete_message_anyway")
            .await
            .map_err(|_| DeleteMessageError::Forbidden)?
    {
        return Err(DeleteMessageError::Forbidden);
    }

    sqlx::query(database.sql("DELETE FROM messages WHERE id = ?1").as_ref())
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(ApiMessage::new("Delete message sucessfully"))
}

async fn push_message_to_channel(
    database: &AppDatabase,
    hub: &PushHub,
    channel_id: &Id,
    payload: &MessagePush,
) {
    let rows = sqlx::query(
        database
            .sql("SELECT user_id FROM channel_members WHERE channel_id = ?1")
            .as_ref(),
    )
    .bind(channel_id.to_string())
    .fetch_all(database.sqlx())
    .await;

    let rows = match rows {
        Ok(rows) => rows,
        Err(err) => {
            tracing::error!(error = %err, "Failed to load channel members for push");
            return;
        }
    };

    let mut users = Vec::with_capacity(rows.len());
    for row in rows {
        let user_hex: String = match row.try_get("user_id") {
            Ok(user_hex) => user_hex,
            Err(err) => {
                tracing::error!(error = %err, "Failed to decode channel member id");
                continue;
            }
        };
        if let Ok(user_id) = user_hex.parse() {
            users.push(user_id);
        }
    }

    hub.send_json_to_users(users, "message", payload).await;
}

async fn notify_channel_members(
    database: &AppDatabase,
    hub: &PushHub,
    channel_id: Id,
    sender_id: Id,
    content: &str,
) {
    // Load channel to get activity_id
    let channel_row = sqlx::query(
        database
            .sql("SELECT activity_id FROM channels WHERE id = ?1")
            .as_ref(),
    )
    .bind(channel_id.to_string())
    .fetch_optional(database.sqlx())
    .await;

    let channel_row = match channel_row {
        Ok(Some(row)) => row,
        _ => return,
    };

    let activity_id_hex: Option<String> = channel_row.try_get("activity_id").ok();
    let activity_id_hex = match activity_id_hex {
        Some(hex) if !hex.is_empty() => hex,
        _ => return, // Only notify for activity-bound channels
    };

    // Load activity name and promoter
    let activity_row = sqlx::query(
        database
            .sql("SELECT name, promoter_id FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(&activity_id_hex)
    .fetch_optional(database.sqlx())
    .await;

    let activity_row = match activity_row {
        Ok(Some(row)) => row,
        _ => return,
    };

    let activity_name: String = activity_row.try_get("name").unwrap_or_default();
    let promoter_hex: String = activity_row.try_get("promoter_id").unwrap_or_default();

    // Determine if this is a teacher post
    let is_teacher_post = sender_id.to_string() == promoter_hex;
    let notification_type = if is_teacher_post {
        models::NotificationType::TeacherChannelPost
    } else {
        models::NotificationType::NewChannelMessage
    };

    // Get sender name
    let sender_name = user::get_name(database, sender_id)
        .await
        .unwrap_or_else(|_| "Someone".to_string());

    let preview = if content.len() > 100 {
        format!("{}...", &content[..97])
    } else {
        content.to_string()
    };

    let payload = models::ChannelMessagePayload {
        channel_id: channel_id.to_string(),
        activity_id: activity_id_hex,
        activity_name,
        sender_name,
        message_preview: preview,
    };
    let Some(payload_json) = notification::serialize_payload(&payload) else {
        return;
    };

    // Load channel members excluding sender
    let rows = sqlx::query(
        database
            .sql("SELECT user_id FROM channel_members WHERE channel_id = ?1")
            .as_ref(),
    )
    .bind(channel_id.to_string())
    .fetch_all(database.sqlx())
    .await;

    let rows = match rows {
        Ok(rows) => rows,
        Err(_) => return,
    };

    let recipients: Vec<Id> = rows
        .iter()
        .filter_map(|row| {
            let hex: String = row.try_get("user_id").ok()?;
            let uid: Id = hex.parse().ok()?;
            if uid == sender_id {
                None
            } else {
                Some(uid)
            }
        })
        .collect();

    notification::create_notifications_batch(
        database,
        hub,
        &recipients,
        notification_type,
        &payload_json,
    )
    .await;
}
