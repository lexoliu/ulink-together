use std::str::FromStr;

use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, ApiMessage, Id},
};

use bytestr::ByteStr;
use serde::Serialize;
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Debug, serde::Deserialize, ToSchema)]
pub(crate) struct FindQuery {
    start_date: Option<String>,
    end_date: Option<String>,
    channel: String,
    sender: Option<String>,
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
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindMessagesError::SessionExpired,
        _ => FindMessagesError::Forbidden,
    })?;
    let Query(query) = query;
    let channel_id =
        parse_oid(&query.channel).map_err(|_| FindMessagesError::InvalidChannelId)?;

    let mut builder = sqlx::QueryBuilder::new(
        "SELECT id, channel_id, sender_id, content, sent_at FROM messages WHERE channel_id = ",
    );
    builder.push_bind(channel_id.to_string());

    if let Some(start) = &query.start_date {
        builder.push(" AND sent_at >= ").push_bind(start);
    }
    if let Some(end) = &query.end_date {
        builder.push(" AND sent_at <= ").push_bind(end);
    }
    if let Some(sender) = &query.sender {
        let sender_id =
            parse_oid(sender).map_err(|_| FindMessagesError::InvalidSenderId)?;
        builder
            .push(" AND sender_id = ")
            .push_bind(sender_id.to_string());
    }

    builder.push(" ORDER BY sent_at DESC");

    let rows = builder
        .build()
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");
    Ok(Json(
        rows.into_iter()
            .map(|row| {
                Ok(Message {
                    id: parse_db_oid(&row.try_get::<String, _>("id").expect("Database error"))?,
                    channel: parse_db_oid(
                        &row.try_get::<String, _>("channel_id").expect("Database error"),
                    )?,
                    sender: parse_db_oid(
                        &row.try_get::<String, _>("sender_id").expect("Database error"),
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
    session.into_auth().await.map_err(|err| match err {
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
        "SELECT id, channel_id, sender_id, content, sent_at FROM messages WHERE id = ?1",
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(GetMessageError::NotFound)?;

    let channel_hex: String = row
        .try_get("channel_id")
        .map_err(|_| GetMessageError::CorruptedData)?;
    let sender_hex: String = row
        .try_get("sender_id")
        .map_err(|_| GetMessageError::CorruptedData)?;
    Ok(Json(Message {
        id,
        channel: Id::from_str(&channel_hex).map_err(|_| GetMessageError::CorruptedData)?,
        sender: Id::from_str(&sender_hex).map_err(|_| GetMessageError::CorruptedData)?,
        content: row
            .try_get("content")
            .map_err(|_| GetMessageError::CorruptedData)?,
        datetime: row
            .try_get("sent_at")
            .map_err(|_| GetMessageError::CorruptedData)?,
    }))
}

async fn ensure_channel_member(database: &AppDatabase, channel: &Id, user: &Id) -> bool {
    sqlx::query("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2 LIMIT 1")
        .bind(channel.to_string())
        .bind(user.to_string())
        .fetch_optional(database.sqlx())
        .await
        .expect("Database error")
        .is_some()
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

pub async fn post(
    database: State<AppDatabase>,
    content: ByteStr,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, PostMessageError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => PostMessageError::SessionExpired,
        _ => PostMessageError::Forbidden,
    })?;
    let channel_id =
        parse_oid(params.get("id").map_err(|_| PostMessageError::InvalidChannelId)?)
            .map_err(|_| PostMessageError::InvalidChannelId)?;
    let can_post = ensure_channel_member(&database, &channel_id, &auth.uid()).await
        || auth
            .match_authority("send_message_anyway")
            .await
            .map_err(|_| PostMessageError::Forbidden)?;
    if !can_post {
        return Err(PostMessageError::Forbidden);
    }

    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();
    sqlx::query(
        "INSERT INTO messages (id, channel_id, sender_id, content, sent_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(id.to_string())
    .bind(channel_id.to_string())
    .bind(auth.uid().to_string())
    .bind(content.as_str())
    .bind(now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    Ok(ApiMessage::new("Post message successfully"))
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
    let row = sqlx::query("SELECT sender_id FROM messages WHERE id = ?1")
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

    sqlx::query("DELETE FROM messages WHERE id = ?1")
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(ApiMessage::new("Delete message sucessfully"))
}
