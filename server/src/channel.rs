use crate::{
    auth::AuthSession,
    database::AppDatabase,
    utils::{parse_oid, ApiMessage},
};
use bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Form, Json, State},
    Error, StatusCode,
};
use sqlx::Row;
use time::OffsetDateTime;

#[derive(Debug, Deserialize)]
pub(crate) struct CreateChannelForm {
    name: String,
    activity: Option<ObjectId>,
}

#[derive(Debug, Deserialize)]
pub struct FindForm {
    owner: Option<ObjectId>,
    include_member: Option<ObjectId>,
    activity: Option<ObjectId>,
}

#[derive(Serialize)]
pub struct ChannelResponse {
    id: ObjectId,
    name: String,
    owner: ObjectId,
    members: Vec<ObjectId>,
    activity: Option<ObjectId>,
}

#[derive(Serialize)]
pub struct ChannelCreated {
    message: &'static str,
    channel_id: ObjectId,
}

fn parse_db_oid(value: &str) -> skyzen::Result<ObjectId> {
    ObjectId::parse_str(value).map_err(|_| {
        Error::msg("Corrupted channel data").set_status(StatusCode::INTERNAL_SERVER_ERROR)
    })
}

async fn members_of(database: &AppDatabase, channel_hex: &str) -> skyzen::Result<Vec<ObjectId>> {
    let rows = sqlx::query("SELECT user_id FROM channel_members WHERE channel_id = ?1")
        .bind(channel_hex)
        .fetch_all(database.sqlx())
        .await?;
    let mut members = Vec::with_capacity(rows.len());
    for row in rows {
        members.push(parse_db_oid(&row.try_get::<String, _>("user_id")?)?);
    }
    Ok(members)
}

pub async fn create(
    database: State<AppDatabase>,
    session: AuthSession,
    query: Query<CreateChannelForm>,
) -> skyzen::Result<Json<ChannelCreated>> {
    let auth = session.into_auth().await?;
    auth.ensure_authority("create_channel").await?;
    let Query(CreateChannelForm { name, activity }) = query;
    let activity_hex = activity.map(|id| id.to_hex());
    let id = ObjectId::new();
    let now = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        "INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
    )
    .bind(id.to_hex())
    .bind(&name)
    .bind(auth.uid().to_hex())
    .bind(activity_hex.clone())
    .bind(now)
    .execute(database.sqlx())
    .await?;

    sqlx::query("INSERT INTO channel_members (channel_id, user_id) VALUES (?1, ?2)")
        .bind(id.to_hex())
        .bind(auth.uid().to_hex())
        .execute(database.sqlx())
        .await?;

    Ok(Json(ChannelCreated {
        message: "Create channel successfully",
        channel_id: id,
    }))
}

pub async fn delete(
    database: State<AppDatabase>,
    params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    let auth = session.into_auth().await?;
    let id = parse_oid(params.get("id")?)?;
    let row = sqlx::query("SELECT owner_id FROM channels WHERE id = ?1")
        .bind(id.to_hex())
        .fetch_optional(database.sqlx())
        .await?
        .ok_or_else(|| Error::msg("Channel not exists").set_status(StatusCode::NOT_FOUND))?;
    let owner_hex: String = row.try_get("owner_id")?;

    if owner_hex != auth.uid().to_hex() && !auth.match_authority("delete_channel_anyway").await? {
        return Err(
            Error::msg("You have no access to this channel").set_status(StatusCode::FORBIDDEN)
        );
    }

    sqlx::query("DELETE FROM channels WHERE id = ?1")
        .bind(id.to_hex())
        .execute(database.sqlx())
        .await?;

    Ok(ApiMessage::new("Delete channel successfully"))
}

pub async fn find(
    database: State<AppDatabase>,
    form: Form<FindForm>,
    session: AuthSession,
) -> skyzen::Result<Json<Vec<ChannelResponse>>> {
    session.into_auth().await?;
    let Form(form) = form;

    let mut builder =
        sqlx::QueryBuilder::new("SELECT id, name, owner_id, activity_id FROM channels WHERE 1=1");
    if let Some(owner) = form.owner {
        builder.push(" AND owner_id = ").push_bind(owner.to_hex());
    }
    if let Some(activity) = form.activity {
        builder
            .push(" AND activity_id = ")
            .push_bind(activity.to_hex());
    }
    if let Some(member) = form.include_member {
        builder.push(" AND id IN (SELECT channel_id FROM channel_members WHERE user_id = ");
        builder.push_bind(member.to_hex()).push(")");
    }

    let rows = builder.build().fetch_all(database.sqlx()).await?;
    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let id_hex: String = row.try_get("id")?;
        let owner_hex: String = row.try_get("owner_id")?;
        result.push(ChannelResponse {
            id: parse_db_oid(&id_hex)?,
            name: row.try_get("name")?,
            owner: parse_db_oid(&owner_hex)?,
            members: members_of(&database, &id_hex).await?,
            activity: row
                .try_get::<Option<String>, _>("activity_id")?
                .map(|hex| parse_db_oid(&hex))
                .transpose()?,
        });
    }

    Ok(Json(result))
}
