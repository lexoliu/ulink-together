#![allow(dead_code)]

use sqlx::{Any, PgPool, Pool, Row, SqlitePool};
use uuid::Uuid;

pub fn schema_statements() -> &'static [&'static str] {
    &[
        r#"
        CREATE TABLE IF NOT EXISTS groups (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL,
            allow_all_authorities INTEGER NOT NULL DEFAULT 0
        )
        "#,
        "CREATE UNIQUE INDEX IF NOT EXISTS groups_code_unique ON groups(code)",
        r#"
        CREATE TABLE IF NOT EXISTS group_authorities (
            group_id TEXT NOT NULL,
            authority TEXT NOT NULL,
            PRIMARY KEY (group_id, authority)
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            realname TEXT NOT NULL,
            gender TEXT NOT NULL,
            description TEXT NOT NULL,
            classname TEXT NOT NULL,
            avatar_path TEXT,
            password_hash TEXT NOT NULL,
            group_id TEXT NOT NULL
        )
        "#,
        "CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users(email)",
        r#"
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            generated_at TEXT NOT NULL,
            ip TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id)",
        r#"
        CREATE TABLE IF NOT EXISTS activities (
            id TEXT PRIMARY KEY,
            promoter_id TEXT NOT NULL,
            name TEXT NOT NULL,
            location TEXT NOT NULL,
            state TEXT NOT NULL,
            volunteer_num INTEGER NOT NULL DEFAULT 0,
            max_volunteer_num INTEGER,
            date TEXT,
            brief_description TEXT NOT NULL,
            description TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS activity_comments (
            id TEXT PRIMARY KEY,
            activity_id TEXT NOT NULL,
            author_id TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS activity_comments_activity_idx ON activity_comments(activity_id)",
        r#"
        CREATE TABLE IF NOT EXISTS channels (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            activity_id TEXT,
            created_at TEXT NOT NULL
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS channel_members (
            channel_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            PRIMARY KEY (channel_id, user_id)
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            channel_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            content TEXT NOT NULL,
            sent_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS messages_channel_idx ON messages(channel_id)",
        "CREATE INDEX IF NOT EXISTS messages_sender_idx ON messages(sender_id)",
        r#"
        CREATE TABLE IF NOT EXISTS records (
            id TEXT PRIMARY KEY,
            activity_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            state TEXT NOT NULL,
            confirmed_minutes INTEGER NOT NULL DEFAULT 0,
            confirmed_at TEXT,
            confirmed_by TEXT,
            updated_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS records_activity_idx ON records(activity_id)",
        "CREATE INDEX IF NOT EXISTS records_user_idx ON records(user_id)",
        "CREATE UNIQUE INDEX IF NOT EXISTS records_activity_user_unique ON records(activity_id, user_id)",
        r#"
        CREATE TABLE IF NOT EXISTS resources (
            id TEXT PRIMARY KEY,
            creator_id TEXT NOT NULL,
            name TEXT NOT NULL,
            extension TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS export_batches (
            id TEXT PRIMARY KEY,
            creator_id TEXT NOT NULL,
            target_format TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
        r#"
        CREATE TABLE IF NOT EXISTS export_items (
            id TEXT PRIMARY KEY,
            batch_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            activity_id TEXT NOT NULL,
            activity_title TEXT NOT NULL,
            activity_date TEXT,
            student_name TEXT NOT NULL,
            class_name TEXT NOT NULL,
            confirmed_minutes INTEGER NOT NULL,
            confirmed_at TEXT
        )
        "#,
        "CREATE INDEX IF NOT EXISTS export_items_batch_idx ON export_items(batch_id)",
        r#"
        CREATE TABLE IF NOT EXISTS check_mails (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            code TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS check_mails_email_idx ON check_mails(email)",
        r#"
        CREATE TABLE IF NOT EXISTS notifications (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            notification_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            read_at TEXT,
            created_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS notifications_user_idx ON notifications(user_id)",
        "CREATE INDEX IF NOT EXISTS notifications_user_read_idx ON notifications(user_id, read_at)",
        r#"
        CREATE TABLE IF NOT EXISTS notification_preferences (
            user_id TEXT NOT NULL,
            notification_type TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (user_id, notification_type)
        )
        "#,
    ]
}

pub fn reset_schema_statements() -> &'static [&'static str] {
    &[
        "DROP TABLE IF EXISTS notification_preferences",
        "DROP TABLE IF EXISTS notifications",
        "DROP TABLE IF EXISTS export_items",
        "DROP TABLE IF EXISTS export_batches",
        "DROP TABLE IF EXISTS resources",
        "DROP TABLE IF EXISTS records",
        "DROP TABLE IF EXISTS messages",
        "DROP TABLE IF EXISTS channel_members",
        "DROP TABLE IF EXISTS channels",
        "DROP TABLE IF EXISTS activity_comments",
        "DROP TABLE IF EXISTS activities",
        "DROP TABLE IF EXISTS sessions",
        "DROP TABLE IF EXISTS users",
        "DROP TABLE IF EXISTS check_mails",
        "DROP TABLE IF EXISTS group_authorities",
        "DROP TABLE IF EXISTS groups",
    ]
}

pub async fn apply_schema_sqlite(pool: &SqlitePool) -> Result<(), sqlx::Error> {
    for statement in schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

pub async fn apply_schema_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    for statement in schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

pub async fn apply_schema_any(pool: &Pool<Any>) -> Result<(), sqlx::Error> {
    for statement in schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

pub async fn reset_schema_any(pool: &Pool<Any>) -> Result<(), sqlx::Error> {
    for statement in reset_schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

/// Built-in role catalogue.
///
/// This is the single source of truth for which authorities each role
/// carries. The catalogue is applied at startup by [`seed_builtin_groups_any`]
/// and is never mutated at runtime: the platform recognises exactly three
/// roles, and changing what they can do is a code change, not a database
/// edit.
///
/// * `admin` carries `allow_all_authorities = true` and bypasses individual
///   checks. Its `authorities` slice is therefore intentionally empty.
/// * `teacher` is the activity organiser role: it can publish activities,
///   open team chats, approve/confirm volunteer hours, view records, and
///   generate ISMAS exports.
/// * `student` is the volunteer role and gets no special authorities;
///   day-to-day actions like applying to an activity rely on per-record
///   permission rules in the relevant handlers, not on a group-level flag.
const BUILTIN_ROLES: &[BuiltinRole] = &[
    BuiltinRole {
        code: "admin",
        allow_all_authorities: true,
        authorities: &[],
    },
    BuiltinRole {
        code: "teacher",
        allow_all_authorities: false,
        authorities: &[
            "create_activity",
            "manage_activity_anyway",
            "view_all_activities",
            "create_channel",
            "view_channel_anyway",
            "send_message_anyway",
            "view_record_anyway",
            "manage_record_anyway",
            "manage_comment_anyway",
            "generate_export",
            "view_user",
        ],
    },
    BuiltinRole {
        code: "student",
        allow_all_authorities: false,
        authorities: &[],
    },
];

struct BuiltinRole {
    code: &'static str,
    allow_all_authorities: bool,
    authorities: &'static [&'static str],
}

pub async fn seed_builtin_groups_sqlite(pool: &SqlitePool) -> Result<(), sqlx::Error> {
    for role in BUILTIN_ROLES {
        let group_id = ensure_group_sqlite(pool, role.code, role.allow_all_authorities).await?;
        replace_group_authorities_sqlite(pool, &group_id, role.authorities).await?;
    }
    Ok(())
}

pub async fn seed_builtin_groups_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    for role in BUILTIN_ROLES {
        let group_id = ensure_group_postgres(pool, role.code, role.allow_all_authorities).await?;
        replace_group_authorities_postgres(pool, &group_id, role.authorities).await?;
    }
    Ok(())
}

pub async fn seed_builtin_groups_any(pool: &Pool<Any>) -> Result<(), sqlx::Error> {
    for role in BUILTIN_ROLES {
        let group_id = ensure_group_any(pool, role.code, role.allow_all_authorities).await?;
        replace_group_authorities_any(pool, &group_id, role.authorities).await?;
    }
    Ok(())
}

async fn replace_group_authorities_sqlite(
    pool: &SqlitePool,
    group_id: &str,
    authorities: &[&str],
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM group_authorities WHERE group_id = ?1")
        .bind(group_id)
        .execute(pool)
        .await?;
    for authority in authorities {
        sqlx::query("INSERT INTO group_authorities (group_id, authority) VALUES (?1, ?2)")
            .bind(group_id)
            .bind(*authority)
            .execute(pool)
            .await?;
    }
    Ok(())
}

async fn replace_group_authorities_postgres(
    pool: &PgPool,
    group_id: &str,
    authorities: &[&str],
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM group_authorities WHERE group_id = $1")
        .bind(group_id)
        .execute(pool)
        .await?;
    for authority in authorities {
        sqlx::query("INSERT INTO group_authorities (group_id, authority) VALUES ($1, $2)")
            .bind(group_id)
            .bind(*authority)
            .execute(pool)
            .await?;
    }
    Ok(())
}

async fn replace_group_authorities_any(
    pool: &Pool<Any>,
    group_id: &str,
    authorities: &[&str],
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM group_authorities WHERE group_id = ?1")
        .bind(group_id)
        .execute(pool)
        .await?;
    for authority in authorities {
        sqlx::query("INSERT INTO group_authorities (group_id, authority) VALUES (?1, ?2)")
            .bind(group_id)
            .bind(*authority)
            .execute(pool)
            .await?;
    }
    Ok(())
}

pub async fn ensure_group_sqlite(
    pool: &SqlitePool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    let existing = sqlx::query("SELECT id FROM groups WHERE code = ?1")
        .bind(code)
        .fetch_optional(pool)
        .await?;
    if let Some(row) = existing {
        return row.try_get("id");
    }

    let id = Uuid::new_v4().to_string();
    sqlx::query(
        "INSERT OR IGNORE INTO groups (id, code, allow_all_authorities) VALUES (?1, ?2, ?3)",
    )
    .bind(&id)
    .bind(code)
    .bind(if allow_all { 1 } else { 0 })
    .execute(pool)
    .await?;
    Ok(id)
}

pub async fn ensure_group_postgres(
    pool: &PgPool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    let existing = sqlx::query("SELECT id FROM groups WHERE code = $1")
        .bind(code)
        .fetch_optional(pool)
        .await?;
    if let Some(row) = existing {
        return row.try_get("id");
    }

    let id = Uuid::new_v4().to_string();
    sqlx::query(
        "INSERT INTO groups (id, code, allow_all_authorities) VALUES ($1, $2, $3) ON CONFLICT (code) DO NOTHING",
    )
    .bind(&id)
    .bind(code)
    .bind(if allow_all { 1 } else { 0 })
    .execute(pool)
    .await?;
    Ok(id)
}

pub async fn ensure_group_any(
    pool: &Pool<Any>,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    let existing = sqlx::query("SELECT id FROM groups WHERE code = ?1")
        .bind(code)
        .fetch_optional(pool)
        .await?;
    if let Some(row) = existing {
        return row.try_get("id");
    }

    let id = Uuid::new_v4().to_string();
    sqlx::query("INSERT INTO groups (id, code, allow_all_authorities) VALUES (?1, ?2, ?3)")
        .bind(&id)
        .bind(code)
        .bind(if allow_all { 1 } else { 0 })
        .execute(pool)
        .await?;
    Ok(id)
}

