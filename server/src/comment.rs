use crate::{
    auth::AuthSession,
    database::AppDatabase,
    user,
    utils::{parse_oid, Id},
};
use bytestr::ByteStr;
use serde::Serialize;
use skyzen::{
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct CommentResponse {
    id: Id,
    author: Id,
    author_name: String,
    content: String,
    date: String,
}

/// List comments for an activity
#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<Json<Vec<CommentResponse>>> {
    session.into_auth().await?;
    let activity_id = parse_oid(params.get("id")?)?;
    let rows = sqlx::query(
        "SELECT id, author_id, content, created_at FROM activity_comments WHERE activity_id = ?1 ORDER BY created_at DESC",
    )
    .bind(activity_id.to_string())
    .fetch_all(database.sqlx())
    .await?;

    let mut comments = Vec::with_capacity(rows.len());
    for row in rows {
        let author: Id = row
            .try_get::<String, _>("author_id")
            .ok()
            .and_then(|hex| hex.parse().ok())
            .ok_or_else(|| {
                Error::msg("Corrupted comment data").set_status(StatusCode::INTERNAL_SERVER_ERROR)
            })?;
        let author_name = user::get_name(&database, author).await?;
        comments.push(CommentResponse {
            id: row
                .try_get::<String, _>("id")
                .ok()
                .and_then(|hex| hex.parse().ok())
                .ok_or_else(|| {
                    Error::msg("Corrupted comment data")
                        .set_status(StatusCode::INTERNAL_SERVER_ERROR)
                })?,
            author,
            author_name,
            content: row.try_get("content")?,
            date: row.try_get("created_at")?,
        });
    }

    Ok(Json(comments))
}

pub async fn post(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
    body: ByteStr,
) -> skyzen::Result<Json<CommentResponse>> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("send_comment").await?;
    let activity_id = parse_oid(params.get("id")?)?;
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        "INSERT INTO activity_comments (id, activity_id, author_id, content, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(id.to_string())
    .bind(activity_id.to_string())
    .bind(auth.uid().to_string())
    .bind(body.as_str())
    .bind(&now)
    .execute(database.sqlx())
    .await?;

    let author_name = user::get_name(&database, auth.uid()).await?;
    Ok(Json(CommentResponse {
        id,
        author: auth.uid(),
        author_name,
        content: body.as_str().to_owned(),
        date: now,
    }))
}
