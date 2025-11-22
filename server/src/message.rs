use std::str::FromStr;

use crate::{
    auth::AuthSession,
    database::AppDatabase,
    utils::{parse_oid, ApiMessage, Id},
};

use bytestr::ByteStr;
use serde::Serialize;
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
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

fn parse_db_oid(value: &str) -> skyzen::Result<Id> {
    Id::from_str(value).map_err(|_| {
        Error::msg("Corrupted message data").set_status(StatusCode::INTERNAL_SERVER_ERROR)
    })
}

/// Find messages by various criteria
#[skyzen::openapi]
pub async fn find(
    database: State<AppDatabase>,
    query: Query<FindQuery>,
    session: AuthSession,
) -> skyzen::Result<Json<Vec<Message>>> {
    session.into_auth().await?;
    let Query(query) = query;
    let channel_id = parse_oid(&query.channel)?;

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
        let sender_id = parse_oid(sender)?;
        builder
            .push(" AND sender_id = ")
            .push_bind(sender_id.to_string());
    }

    builder.push(" ORDER BY sent_at DESC");

    let rows = builder.build().fetch_all(database.sqlx()).await?;
    Ok(Json(
        rows.into_iter()
            .map(|row| {
                Ok(Message {
                    id: parse_db_oid(&row.try_get::<String, _>("id")?)?,
                    channel: parse_db_oid(&row.try_get::<String, _>("channel_id")?)?,
                    sender: parse_db_oid(&row.try_get::<String, _>("sender_id")?)?,
                    content: row.try_get("content")?,
                    datetime: row.try_get("sent_at")?,
                })
            })
            .collect::<skyzen::Result<Vec<_>>>()?,
    ))
}

/// Get message by ID
#[skyzen::openapi]
pub async fn get(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<Json<Message>> {
    session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    let row = sqlx::query(
        "SELECT id, channel_id, sender_id, content, sent_at FROM messages WHERE id = ?1",
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await?
    .ok_or_else(|| Error::msg("Message not exist").set_status(StatusCode::NOT_FOUND))?;

    Ok(Json(Message {
        id,
        channel: parse_db_oid(&row.try_get::<String, _>("channel_id")?)?,
        sender: parse_db_oid(&row.try_get::<String, _>("sender_id")?)?,
        content: row.try_get("content")?,
        datetime: row.try_get("sent_at")?,
    }))
}

async fn ensure_channel_member(
    database: &AppDatabase,
    channel: &Id,
    user: &Id,
) -> sqlx::Result<bool> {
    Ok(
        sqlx::query("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2 LIMIT 1")
            .bind(channel.to_string())
            .bind(user.to_string())
            .fetch_optional(database.sqlx())
            .await?
            .is_some(),
    )
}

pub async fn post(
    database: State<AppDatabase>,
    content: ByteStr,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let channel_id = parse_oid(params.get("id")?)?;
    let can_post = ensure_channel_member(&database, &channel_id, &auth.uid()).await?
        || auth.match_authority("send_message_anyway").await?;
    if !can_post {
        return Err(
            Error::msg("You have no access to this channel").set_status(StatusCode::FORBIDDEN)
        );
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
    .await?;

    Ok(ApiMessage::new("Post message successfully"))
}

/// Delete a message
#[skyzen::openapi]
pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    let row = sqlx::query("SELECT sender_id FROM messages WHERE id = ?1")
        .bind(id.to_string())
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Message not exist").set_status(StatusCode::NOT_FOUND))?;
    let sender_hex: String = row.try_get("sender_id")?;

    if sender_hex != auth.uid().to_string()
        && !auth.match_authority("delete_message_anyway").await?
    {
        return Err(
            Error::msg("You have no access to this channel").set_status(StatusCode::FORBIDDEN)
        );
    }

    sqlx::query("DELETE FROM messages WHERE id = ?1")
        .bind(id.to_string())
        .execute(database.sqlx())
        .await?;

    Ok(ApiMessage::new("Delete message sucessfully"))
}
