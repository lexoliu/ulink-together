use models::{ActivityState, Id, RecordState};
use rand::{distributions::Uniform, prelude::Distribution, Rng};
use sqlx::{Any, Executor, Row};
use tracing_subscriber::EnvFilter;

use crate::{
    database::{build_database, database_kind_from_url, AppDatabase},
    schema::{
        apply_schema_any, ensure_group_any, ensure_group_authority_any, reset_schema_any,
        seed_builtin_groups_any,
    },
};

const STRING_MAP: &[u8] = b"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub struct ConnectedDatabase {
    pub database: AppDatabase,
    pub database_url: String,
}

pub struct SeedGroup<'a> {
    pub code: &'a str,
    pub allow_all_authorities: bool,
    pub authorities: &'a [&'a str],
}

pub struct SeedUser<'a> {
    pub email: &'a str,
    pub realname: &'a str,
    pub gender: &'a str,
    pub description: &'a str,
    pub classname: &'a str,
    pub avatar_path: Option<&'a str>,
    pub password: &'a str,
    pub group_id: Id,
}

pub struct SeedActivity<'a> {
    pub promoter_id: Id,
    pub name: &'a str,
    pub location: &'a str,
    pub state: ActivityState,
    pub volunteer_num: u16,
    pub max_volunteer_num: Option<u16>,
    pub date: Option<&'a str>,
    pub brief_description: &'a str,
    pub description: &'a str,
    pub duration_minutes: u16,
}

pub struct SeedRecord<'a> {
    pub activity_id: Id,
    pub user_id: Id,
    pub state: RecordState,
    pub confirmed_minutes: u16,
    pub confirmed_at: Option<&'a str>,
    pub confirmed_by: Option<Id>,
    pub updated_at: &'a str,
}

pub struct SeedComment<'a> {
    pub activity_id: Id,
    pub author_id: Id,
    pub content: &'a str,
    pub created_at: &'a str,
}

pub struct SeedChannel<'a> {
    pub name: &'a str,
    pub owner_id: Id,
    pub activity_id: Option<Id>,
    pub created_at: &'a str,
}

pub struct SeedMessage<'a> {
    pub channel_id: Id,
    pub sender_id: Id,
    pub content: &'a str,
    pub sent_at: &'a str,
}

pub fn init_cli_logging() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .without_time()
        .try_init();
}

pub fn normalize_database_url(database_url: &str) -> String {
    if database_url.starts_with("d1://") {
        format!("sqlite://{}", database_url.trim_start_matches("d1://"))
    } else {
        database_url.to_string()
    }
}

pub async fn connect_database(database_url: &str) -> Result<ConnectedDatabase, sqlx::Error> {
    let normalized = normalize_database_url(database_url);
    let pool = build_database(&normalized).await?;
    Ok(ConnectedDatabase {
        database: AppDatabase::new(pool, database_kind_from_url(&normalized)),
        database_url: normalized,
    })
}

pub async fn prepare_database(database: &AppDatabase, reset: bool) -> Result<(), sqlx::Error> {
    if reset {
        reset_schema_any(database.sqlx()).await?;
    }
    apply_schema_any(database.sqlx()).await?;
    seed_builtin_groups_any(database.sqlx()).await?;
    Ok(())
}

pub async fn user_count(database: &AppDatabase) -> Result<i64, sqlx::Error> {
    let row = sqlx::query("SELECT COUNT(*) AS count FROM users")
        .fetch_one(database.sqlx())
        .await?;
    row.try_get("count")
}

pub async fn user_exists(database: &AppDatabase, email: &str) -> Result<bool, sqlx::Error> {
    Ok(sqlx::query(
        database
            .sql("SELECT 1 FROM users WHERE email = ?1 LIMIT 1")
            .as_ref(),
    )
    .bind(email)
    .fetch_optional(database.sqlx())
    .await?
    .is_some())
}

pub async fn ensure_group(
    database: &AppDatabase,
    group: &SeedGroup<'_>,
) -> Result<Id, sqlx::Error> {
    let group_id =
        ensure_group_any(database.sqlx(), group.code, group.allow_all_authorities).await?;
    for authority in group.authorities {
        ensure_group_authority_any(database.sqlx(), &group_id, authority).await?;
    }
    group_id
        .parse()
        .map_err(|error| sqlx::Error::Decode(Box::new(error)))
}

pub fn hash_password(password: &str) -> String {
    bcrypt::hash(password, bcrypt::DEFAULT_COST).expect("bcrypt hash password")
}

pub fn rand_string<R: Rng + ?Sized>(rng: &mut R, len: usize) -> String {
    let uniform = Uniform::from(0..STRING_MAP.len());
    let mut bytes = Vec::with_capacity(len);
    for _ in 0..len {
        bytes.push(STRING_MAP[uniform.sample(rng)]);
    }
    unsafe { String::from_utf8_unchecked(bytes) }
}

pub async fn insert_user<'e, E, R>(
    database: &AppDatabase,
    executor: E,
    rng: &mut R,
    user: &SeedUser<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
    R: Rng + ?Sized,
{
    let id = Id::new();
    let password_hash = hash_password(user.password);

    sqlx::query(
        database
            .sql("INSERT INTO users (id, email, realname, gender, description, classname, avatar_path, password_hash, group_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(user.email)
    .bind(user.realname)
    .bind(user.gender)
    .bind(user.description)
    .bind(user.classname)
    .bind(user.avatar_path)
    .bind(password_hash)
    .bind(user.group_id.to_string())
    .execute(executor)
    .await?;

    Ok(id)
}

pub async fn insert_activity<'e, E>(
    database: &AppDatabase,
    executor: E,
    activity: &SeedActivity<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    let id = Id::new();

    sqlx::query(
        database
            .sql("INSERT INTO activities (id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, brief_description, description, duration_minutes) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(activity.promoter_id.to_string())
    .bind(activity.name)
    .bind(activity.location)
    .bind(activity.state.as_str())
    .bind(i64::from(activity.volunteer_num))
    .bind(activity.max_volunteer_num.map(i64::from))
    .bind(activity.date)
    .bind(activity.brief_description)
    .bind(activity.description)
    .bind(i64::from(activity.duration_minutes))
    .execute(executor)
    .await?;

    Ok(id)
}

pub async fn set_activity_volunteer_num<'e, E>(
    database: &AppDatabase,
    executor: E,
    activity_id: Id,
    volunteer_num: u16,
) -> Result<(), sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    sqlx::query(
        database
            .sql("UPDATE activities SET volunteer_num = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind(i64::from(volunteer_num))
    .bind(activity_id.to_string())
    .execute(executor)
    .await?;
    Ok(())
}

pub async fn insert_record<'e, E>(
    database: &AppDatabase,
    executor: E,
    record: &SeedRecord<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    let id = Id::new();
    let confirmed_by = record.confirmed_by.map(|value| value.to_string());

    sqlx::query(
        database
            .sql("INSERT INTO records (id, activity_id, user_id, state, confirmed_minutes, confirmed_at, confirmed_by, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(record.activity_id.to_string())
    .bind(record.user_id.to_string())
    .bind(record.state.as_str())
    .bind(i64::from(record.confirmed_minutes))
    .bind(record.confirmed_at)
    .bind(confirmed_by.as_deref())
    .bind(record.updated_at)
    .execute(executor)
    .await?;

    Ok(id)
}

pub async fn insert_comment<'e, E>(
    database: &AppDatabase,
    executor: E,
    comment: &SeedComment<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    let id = Id::new();

    sqlx::query(
        database
            .sql("INSERT INTO activity_comments (id, activity_id, author_id, content, created_at) VALUES (?1, ?2, ?3, ?4, ?5)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(comment.activity_id.to_string())
    .bind(comment.author_id.to_string())
    .bind(comment.content)
    .bind(comment.created_at)
    .execute(executor)
    .await?;

    Ok(id)
}

pub async fn insert_channel<'e, E>(
    database: &AppDatabase,
    executor: E,
    channel: &SeedChannel<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    let id = Id::new();

    sqlx::query(
        database
            .sql("INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(channel.name)
    .bind(channel.owner_id.to_string())
    .bind(channel.activity_id.map(|value| value.to_string()))
    .bind(channel.created_at)
    .execute(executor)
    .await?;

    Ok(id)
}

pub async fn insert_channel_member<'e, E>(
    database: &AppDatabase,
    executor: E,
    channel_id: Id,
    user_id: Id,
) -> Result<(), sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    sqlx::query(
        database
            .sql("INSERT INTO channel_members (channel_id, user_id) VALUES (?1, ?2)")
            .as_ref(),
    )
    .bind(channel_id.to_string())
    .bind(user_id.to_string())
    .execute(executor)
    .await?;
    Ok(())
}

pub async fn insert_message<'e, E>(
    database: &AppDatabase,
    executor: E,
    message: &SeedMessage<'_>,
) -> Result<Id, sqlx::Error>
where
    E: Executor<'e, Database = Any>,
{
    let id = Id::new();

    sqlx::query(
        database
            .sql("INSERT INTO messages (id, channel_id, sender_id, content, sent_at) VALUES (?1, ?2, ?3, ?4, ?5)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(message.channel_id.to_string())
    .bind(message.sender_id.to_string())
    .bind(message.content)
    .bind(message.sent_at)
    .execute(executor)
    .await?;

    Ok(id)
}
