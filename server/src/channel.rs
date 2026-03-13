use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    record,
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

#[derive(Debug, Deserialize, Serialize, ToSchema)]
pub struct CreateChannelForm {
    name: String,
    activity: Option<Id>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct FindForm {
    owner: Option<Id>,
    include_member: Option<Id>,
    activity: Option<Id>,
}

#[derive(Serialize, ToSchema)]
pub struct ChannelResponse {
    id: Id,
    name: String,
    owner: Id,
    members: Vec<Id>,
    activity: Option<Id>,
}

#[derive(Serialize, ToSchema)]
pub struct ChannelCreated {
    message: &'static str,
    channel_id: Id,
}

#[skyzen::error]
pub enum CreateChannelError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,
}

#[skyzen::error]
pub enum DeleteChannelError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Invalid channel id", status = BAD_REQUEST)]
    InvalidChannelId,

    #[error("Channel not exists", status = NOT_FOUND)]
    NotFound,
}

#[skyzen::error]
pub enum FindChannelsError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Corrupted channel data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

fn parse_db_oid(value: &str) -> Result<Id, FindChannelsError> {
    value
        .parse()
        .map_err(|_| FindChannelsError::CorruptedData)
}

pub async fn members_of(database: &AppDatabase, channel_hex: &str) -> Result<Vec<Id>, FindChannelsError> {
    let rows = sqlx::query(
        database
            .sql("SELECT user_id FROM channel_members WHERE channel_id = ?1")
            .as_ref(),
    )
    .bind(channel_hex)
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");
    let mut members = Vec::with_capacity(rows.len());
    for row in rows {
        members.push(parse_db_oid(&row.try_get::<String, _>("user_id").expect("Database error"))?);
    }
    Ok(members)
}

pub async fn ensure_channel_member(database: &AppDatabase, channel: &Id, user: &Id) -> bool {
    sqlx::query(
        database
            .sql("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(channel.to_string())
    .bind(user.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .is_some()
}

/// Create a new channel
#[skyzen::openapi]
pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    form: Json<CreateChannelForm>,
) -> Result<Json<ChannelCreated>, CreateChannelError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => CreateChannelError::SessionExpired,
        _ => CreateChannelError::Forbidden,
    })?;
    auth.ensure_authority("create_channel")
        .await
        .map_err(|_| CreateChannelError::Forbidden)?;
    let Json(CreateChannelForm { name, activity }) = form;
    let activity_hex = activity.map(|id| id.to_string());
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        database
            .sql(
                "INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(&name)
    .bind(auth.uid().to_string())
    .bind(activity_hex.clone())
    .bind(now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    ensure_channel_membership(&database, id, auth.uid())
        .await
        .expect("Database error");

    if let Some(activity_id) = activity {
        let volunteers = record::get_volunteers(&database, activity_id)
            .await
            .expect("Database error");
        for volunteer in volunteers {
            ensure_channel_membership(&database, id, volunteer)
                .await
                .expect("Database error");
        }
    }

    Ok(Json(ChannelCreated {
        message: "Create channel successfully",
        channel_id: id,
    }))
}

/// Delete a channel
#[skyzen::openapi]
pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> Result<ApiMessage, DeleteChannelError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => DeleteChannelError::SessionExpired,
        _ => DeleteChannelError::Forbidden,
    })?;
    let id = parse_oid(
        params
            .get("id")
            .map_err(|_| DeleteChannelError::InvalidChannelId)?,
    )
    .map_err(|_| DeleteChannelError::InvalidChannelId)?;
    let row = sqlx::query(
        database
            .sql("SELECT owner_id FROM channels WHERE id = ?1")
            .as_ref(),
    )
    .bind(id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("Database error")
    .ok_or(DeleteChannelError::NotFound)?;
    let owner_hex: String = row.try_get("owner_id").expect("Database error");

    if owner_hex != auth.uid().to_string()
        && !auth
            .match_authority("delete_channel_anyway")
            .await
            .map_err(|_| DeleteChannelError::Forbidden)?
    {
        return Err(DeleteChannelError::Forbidden);
    }

    sqlx::query(database.sql("DELETE FROM channels WHERE id = ?1").as_ref())
        .bind(id.to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

    Ok(ApiMessage::new("Delete channel successfully"))
}

/// Find channels by various criteria
#[skyzen::openapi]
pub async fn find(
    database: State<AppDatabase>,
    form: Query<FindForm>,
    session: AuthSession,
) -> Result<Json<Vec<ChannelResponse>>, FindChannelsError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindChannelsError::SessionExpired,
        _ => FindChannelsError::Forbidden,
    })?;
    let Query(form) = form;

    let owner = form.owner.map(|id| id.to_string());
    let activity = form.activity.map(|id| id.to_string());
    let member = form.include_member.map(|id| id.to_string());

    let mut sql_text =
        String::from("SELECT id, name, owner_id, activity_id FROM channels WHERE 1=1");
    let mut bind_idx = 0;
    if owner.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND owner_id = ?{bind_idx}"));
    }
    if activity.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(" AND activity_id = ?{bind_idx}"));
    }
    if member.is_some() {
        bind_idx += 1;
        sql_text.push_str(&format!(
            " AND id IN (SELECT channel_id FROM channel_members WHERE user_id = ?{bind_idx})"
        ));
    }
    if !auth
        .match_authority("view_channel_anyway")
        .await
        .map_err(|_| FindChannelsError::Forbidden)?
    {
        bind_idx += 1;
        let owner_bind = bind_idx;
        bind_idx += 1;
        let member_bind = bind_idx;
        sql_text.push_str(&format!(
            " AND (owner_id = ?{owner_bind} OR id IN (SELECT channel_id FROM channel_members WHERE user_id = ?{member_bind}))"
        ));
    }

    let sql = database.sql(&sql_text);
    let mut query = sqlx::query(sql.as_ref());
    if let Some(owner) = owner {
        query = query.bind(owner);
    }
    if let Some(activity) = activity {
        query = query.bind(activity);
    }
    if let Some(member) = member {
        query = query.bind(member);
    }
    if !auth
        .match_authority("view_channel_anyway")
        .await
        .map_err(|_| FindChannelsError::Forbidden)?
    {
        query = query.bind(auth.uid().to_string()).bind(auth.uid().to_string());
    }

    let rows = query
        .fetch_all(database.sqlx())
        .await
        .expect("Database error");
    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let id_hex: String = row.try_get("id").expect("Database error");
        let owner_hex: String = row.try_get("owner_id").expect("Database error");
        result.push(ChannelResponse {
            id: parse_db_oid(&id_hex)?,
            name: row.try_get("name").expect("Database error"),
            owner: parse_db_oid(&owner_hex)?,
            members: members_of(&database, &id_hex).await?,
            activity: row
                .try_get::<Option<String>, _>("activity_id")
                .expect("Database error")
                .map(|hex| parse_db_oid(&hex))
                .transpose()?,
        });
    }

    Ok(Json(result))
}

async fn ensure_channel_membership(
    database: &AppDatabase,
    channel_id: Id,
    user_id: Id,
) -> Result<(), sqlx::Error> {
    let exists = sqlx::query(
        database
            .sql("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2 LIMIT 1")
            .as_ref(),
    )
    .bind(channel_id.to_string())
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
        .bind(channel_id.to_string())
        .bind(user_id.to_string())
        .execute(database.sqlx())
        .await?;
    }

    Ok(())
}
