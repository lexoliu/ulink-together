use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    user,
    utils::{parse_oid, Id},
};
use serde::Serialize;
use skyzen::{
    routing::Params,
    utils::{ByteStr, Json, State},
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

#[skyzen::error]
pub enum ListCommentsError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,

    #[error("Corrupted comment data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,

    #[error("Author not exists", status = NOT_FOUND)]
    AuthorNotFound,
}

/// List comments for an activity
#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<Json<Vec<CommentResponse>>, ListCommentsError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListCommentsError::SessionExpired,
        _ => ListCommentsError::Forbidden,
    })?;
    let activity_id =
        parse_oid(params.get("id").map_err(|_| ListCommentsError::InvalidActivityId)?)
            .map_err(|_| ListCommentsError::InvalidActivityId)?;
    let rows = sqlx::query(
        database
            .sql(
                "SELECT id, author_id, content, created_at FROM activity_comments WHERE activity_id = ?1 ORDER BY created_at DESC",
            )
            .as_ref(),
    )
    .bind(activity_id.to_string())
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut comments = Vec::with_capacity(rows.len());
    for row in rows {
        let author: Id = row
            .try_get::<String, _>("author_id")
            .map_err(|_| ListCommentsError::CorruptedData)?
            .parse()
            .map_err(|_| ListCommentsError::CorruptedData)?;
        let author_name = user::get_name(&database, author)
            .await
            .map_err(|_| ListCommentsError::AuthorNotFound)?;
        comments.push(CommentResponse {
            id: row
                .try_get::<String, _>("id")
                .map_err(|_| ListCommentsError::CorruptedData)?
                .parse()
                .map_err(|_| ListCommentsError::CorruptedData)?,
            author,
            author_name,
            content: row
                .try_get("content")
                .map_err(|_| ListCommentsError::CorruptedData)?,
            date: row
                .try_get("created_at")
                .map_err(|_| ListCommentsError::CorruptedData)?,
        });
    }

    Ok(Json(comments))
}

#[skyzen::error]
pub enum PostCommentError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid activity id", status = BAD_REQUEST)]
    InvalidActivityId,
}

pub async fn post(
    database: State<AppDatabase>,
    session: AuthSession,
    params: Params,
    body: ByteStr,
) -> Result<Json<CommentResponse>, PostCommentError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => PostCommentError::SessionExpired,
        _ => PostCommentError::Forbidden,
    })?;
    auth.ensure_authority("send_comment")
        .await
        .map_err(|_| PostCommentError::Forbidden)?;
    let activity_id =
        parse_oid(params.get("id").map_err(|_| PostCommentError::InvalidActivityId)?)
            .map_err(|_| PostCommentError::InvalidActivityId)?;
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        database
            .sql(
                "INSERT INTO activity_comments (id, activity_id, author_id, content, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(activity_id.to_string())
    .bind(auth.uid().to_string())
    .bind(body.as_str())
    .bind(&now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let author_name = user::get_name(&database, auth.uid())
        .await
        .expect("Database error");
    Ok(Json(CommentResponse {
        id,
        author: auth.uid(),
        author_name,
        content: body.as_str().to_owned(),
        date: now,
    }))
}
