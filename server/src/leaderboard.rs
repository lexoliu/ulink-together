use std::collections::HashMap;

use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    utils::Id,
};

use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    utils::{Json, State},
};
use sqlx::Row;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub struct LeaderboardQuery {
    limit: Option<u32>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct LeaderboardEntry {
    rank: u32,
    user: Id,
    realname: String,
    classname: String,
    avatar: Option<String>,
    total_minutes: u32,
}

#[skyzen::error]
pub enum ListLeaderboardError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Corrupted leaderboard data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

#[skyzen::openapi]
pub async fn list(
    database: State<AppDatabase>,
    query: Query<LeaderboardQuery>,
    session: AuthSession,
) -> Result<Json<Vec<LeaderboardEntry>>, ListLeaderboardError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ListLeaderboardError::SessionExpired,
        _ => ListLeaderboardError::Forbidden,
    })?;
    let Query(LeaderboardQuery { limit }) = query;
    let limit = limit.unwrap_or(50) as i64;

    let rows = sqlx::query(
        database
            .sql(
                r#"
                SELECT
                    users.id,
                    users.realname,
                    users.classname,
                    COALESCE(users.avatar_path, '') AS avatar_path,
                    records.confirmed_minutes
                FROM records
                JOIN users ON users.id = records.user_id
                WHERE records.state = 'done'
                ORDER BY users.realname ASC
                "#,
            )
            .as_ref(),
    )
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut totals: HashMap<Id, LeaderboardEntry> = HashMap::new();
    for row in rows {
        let user: Id = row
            .try_get::<String, _>("id")
            .map_err(|_| ListLeaderboardError::CorruptedData)?
            .parse()
            .map_err(|_| ListLeaderboardError::CorruptedData)?;
        let entry = totals.entry(user).or_insert_with(|| LeaderboardEntry {
            rank: 0,
            user,
            realname: row.try_get("realname").expect("Database error"),
            classname: row.try_get("classname").expect("Database error"),
            avatar: match row
                .try_get::<String, _>("avatar_path")
                .expect("Database error")
            {
                value if value.is_empty() => None,
                value => Some(value),
            },
            total_minutes: 0,
        });
        entry.total_minutes += row
            .try_get::<i64, _>("confirmed_minutes")
            .map_err(|_| ListLeaderboardError::CorruptedData)? as u32;
    }

    let mut result: Vec<_> = totals.into_values().collect();
    result.sort_by(|left, right| {
        right
            .total_minutes
            .cmp(&left.total_minutes)
            .then_with(|| left.realname.cmp(&right.realname))
    });
    result.truncate(limit as usize);
    for (index, entry) in result.iter_mut().enumerate() {
        entry.rank = (index + 1) as u32;
    }

    Ok(Json(result))
}
