use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    utils::{parse_oid, ApiMessage, Id},
};

use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Form, Json, State},
};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub(crate) struct CreateChannelForm {
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

async fn members_of(database: &AppDatabase, channel_hex: &str) -> Result<Vec<Id>, FindChannelsError> {
    let rows = sqlx::query("SELECT user_id FROM channel_members WHERE channel_id = ?1")
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

/// Create a new channel
#[skyzen::openapi]
pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    query: Query<CreateChannelForm>,
) -> Result<Json<ChannelCreated>, CreateChannelError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => CreateChannelError::SessionExpired,
        _ => CreateChannelError::Forbidden,
    })?;
    auth.ensure_authority("create_channel")
        .await
        .map_err(|_| CreateChannelError::Forbidden)?;
    let Query(CreateChannelForm { name, activity }) = query;
    let activity_hex = activity.map(|id| id.to_string());
    let id = Id::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        "INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(id.to_string())
    .bind(&name)
    .bind(auth.uid().to_string())
    .bind(activity_hex.clone())
    .bind(now)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    sqlx::query("INSERT INTO channel_members (channel_id, user_id) VALUES (?1, ?2)")
        .bind(id.to_string())
        .bind(auth.uid().to_string())
        .execute(database.sqlx())
        .await
        .expect("Database error");

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
    let row = sqlx::query("SELECT owner_id FROM channels WHERE id = ?1")
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

    sqlx::query("DELETE FROM channels WHERE id = ?1")
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
    form: Form<FindForm>,
    session: AuthSession,
) -> Result<Json<Vec<ChannelResponse>>, FindChannelsError> {
    session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => FindChannelsError::SessionExpired,
        _ => FindChannelsError::Forbidden,
    })?;
    let Form(form) = form;

    let mut builder =
        sqlx::QueryBuilder::new("SELECT id, name, owner_id, activity_id FROM channels WHERE 1=1");
    if let Some(owner) = form.owner {
        builder
            .push(" AND owner_id = ")
            .push_bind(owner.to_string());
    }
    if let Some(activity) = form.activity {
        builder
            .push(" AND activity_id = ")
            .push_bind(activity.to_string());
    }
    if let Some(member) = form.include_member {
        builder.push(" AND id IN (SELECT channel_id FROM channel_members WHERE user_id = ");
        builder.push_bind(member.to_string()).push(")");
    }

    let rows = builder
        .build()
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
