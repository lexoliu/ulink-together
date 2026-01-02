use std::env;
use std::io::{self, Write};

use rand::{distributions::Uniform, prelude::Distribution};
use sqlx::{postgres::PgPoolOptions, sqlite::SqlitePoolOptions, PgPool, Row, SqlitePool};
use uuid::Uuid;

#[derive(Debug)]
struct Config {
    database_url: String,
    admin_email: String,
    admin_password: String,
    admin_realname: String,
    admin_gender: String,
    admin_classname: String,
    admin_description: String,
}

#[derive(Clone, Copy, Debug)]
enum DatabaseKind {
    Postgres,
    Sqlite,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut config = parse_config()?;
    if config.database_url.starts_with("d1://") {
        let converted = format!("sqlite://{}", config.database_url.trim_start_matches("d1://"));
        println!("Using SQLite URL for D1: {converted}");
        config.database_url = converted;
    }
    let db_kind = database_kind(&config.database_url);

    match db_kind {
        DatabaseKind::Postgres => {
            let pool = PgPoolOptions::new()
                .max_connections(5)
                .connect(&config.database_url)
                .await?;
            create_tables_postgres(&pool).await?;
            seed_groups_postgres(&pool).await?;
            seed_admin_postgres(&pool, &config).await?;
        }
        DatabaseKind::Sqlite => {
            let pool = SqlitePoolOptions::new()
                .max_connections(5)
                .connect(&config.database_url)
                .await?;
            create_tables_sqlite(&pool).await?;
            seed_groups_sqlite(&pool).await?;
            seed_admin_sqlite(&pool, &config).await?;
        }
    }

    println!("Database initialized.");
    Ok(())
}

fn parse_config() -> Result<Config, String> {
    let mut database_url = None;
    let mut admin_email = None;
    let mut admin_password = None;
    let mut admin_realname = None;
    let mut admin_gender = None;
    let mut admin_classname = None;
    let mut admin_description = None;
    let mut non_interactive = false;

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--database-url" | "--db" => database_url = args.next(),
            "--admin-email" => admin_email = args.next(),
            "--admin-password" => admin_password = args.next(),
            "--admin-realname" => admin_realname = args.next(),
            "--admin-gender" => admin_gender = args.next(),
            "--admin-classname" => admin_classname = args.next(),
            "--admin-description" => admin_description = args.next(),
            "--non-interactive" => non_interactive = true,
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            _ => return Err(format!("Unknown argument: {arg}")),
        }
    }

    if !non_interactive {
        if database_url.is_none() {
            database_url = Some(prompt("Database URL", None)?);
        }
        if admin_email.is_none() {
            admin_email = Some(prompt("Admin email", None)?);
        }
        if admin_password.is_none() {
            admin_password = Some(prompt("Admin password (input visible)", None)?);
        }
        if admin_realname.is_none() {
            admin_realname = Some(prompt("Admin real name", Some("Admin"))?);
        }
        if admin_gender.is_none() {
            admin_gender = Some(prompt("Admin gender", Some("unspecified"))?);
        }
        if admin_classname.is_none() {
            admin_classname = Some(prompt("Admin classname", Some("Admin"))?);
        }
        if admin_description.is_none() {
            admin_description = Some(prompt("Admin description", Some(""))?);
        }
    }

    let database_url =
        database_url.ok_or_else(|| "--database-url is required in non-interactive mode".to_string())?;
    let admin_email =
        admin_email.ok_or_else(|| "--admin-email is required in non-interactive mode".to_string())?;
    let admin_password = admin_password
        .ok_or_else(|| "--admin-password is required in non-interactive mode".to_string())?;

    Ok(Config {
        database_url,
        admin_email,
        admin_password,
        admin_realname: admin_realname.unwrap_or_else(|| "Admin".to_string()),
        admin_gender: admin_gender.unwrap_or_else(|| "unspecified".to_string()),
        admin_classname: admin_classname.unwrap_or_else(|| "Admin".to_string()),
        admin_description: admin_description.unwrap_or_default(),
    })
}

fn print_help() {
    println!(
        r#"together-server deploy

USAGE:
  cargo run -p together-server --bin deploy -- \
    --database-url <DATABASE_URL> \
    --admin-email <EMAIL> \
    --admin-password <PASSWORD> \
    [--admin-realname <NAME>] \
    [--admin-gender <GENDER>] \
    [--admin-classname <CLASSNAME>] \
    [--admin-description <DESC>] \
    [--non-interactive]

"#
    );
}

fn prompt(label: &str, default: Option<&str>) -> Result<String, String> {
    let mut stdout = io::stdout();
    if let Some(default) = default {
        print!("{label} [{default}]: ");
    } else {
        print!("{label}: ");
    }
    stdout.flush().map_err(|e| e.to_string())?;

    let mut input = String::new();
    io::stdin()
        .read_line(&mut input)
        .map_err(|e| e.to_string())?;
    let value = input.trim();

    if value.is_empty() {
        if let Some(default) = default {
            Ok(default.to_string())
        } else {
            Err(format!("{label} is required"))
        }
    } else {
        Ok(value.to_string())
    }
}

fn database_kind(database_url: &str) -> DatabaseKind {
    let lower = database_url.to_ascii_lowercase();
    if lower.starts_with("postgres://") || lower.starts_with("postgresql://") {
        DatabaseKind::Postgres
    } else {
        DatabaseKind::Sqlite
    }
}

async fn create_tables_sqlite(pool: &SqlitePool) -> Result<(), sqlx::Error> {
    for statement in schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

async fn create_tables_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    for statement in schema_statements() {
        sqlx::query(statement).execute(pool).await?;
    }
    Ok(())
}

fn schema_statements() -> &'static [&'static str] {
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
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
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
            updated_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS records_activity_idx ON records(activity_id)",
        "CREATE INDEX IF NOT EXISTS records_user_idx ON records(user_id)",
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
        CREATE TABLE IF NOT EXISTS check_mails (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            code TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
        "CREATE INDEX IF NOT EXISTS check_mails_email_idx ON check_mails(email)",
    ]
}

async fn seed_groups_sqlite(pool: &SqlitePool) -> Result<(), sqlx::Error> {
    seed_group_sqlite(pool, "admin", true).await?;
    seed_group_sqlite(pool, "student", false).await?;
    Ok(())
}

async fn seed_groups_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    seed_group_postgres(pool, "admin", true).await?;
    seed_group_postgres(pool, "student", false).await?;
    Ok(())
}

async fn seed_group_sqlite(
    pool: &SqlitePool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    let existing = sqlx::query("SELECT id FROM groups WHERE code = ?1")
        .bind(code)
        .fetch_optional(pool)
        .await?;
    if let Some(row) = existing {
        let id: String = row.try_get("id")?;
        return Ok(id);
    }

    let id = Uuid::new_v4().to_string();
    sqlx::query("INSERT OR IGNORE INTO groups (id, code, allow_all_authorities) VALUES (?1, ?2, ?3)")
        .bind(&id)
        .bind(code)
        .bind(if allow_all { 1 } else { 0 })
        .execute(pool)
        .await?;
    Ok(id)
}

async fn seed_group_postgres(
    pool: &PgPool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    let existing = sqlx::query("SELECT id FROM groups WHERE code = $1")
        .bind(code)
        .fetch_optional(pool)
        .await?;
    if let Some(row) = existing {
        let id: String = row.try_get("id")?;
        return Ok(id);
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

async fn seed_admin_sqlite(pool: &SqlitePool, config: &Config) -> Result<(), sqlx::Error> {
    let admin_group_id = seed_group_sqlite(pool, "admin", true).await?;
    let existing = sqlx::query("SELECT id FROM users WHERE email = ?1")
        .bind(&config.admin_email)
        .fetch_optional(pool)
        .await?;
    if existing.is_some() {
        println!("Admin user already exists. Skipping.");
        return Ok(());
    }

    let id = Uuid::new_v4().to_string();
    let salt = rand_string(16);
    let password_hash = sha256(config.admin_password.as_bytes(), salt.as_bytes());
    sqlx::query(
        r#"
        INSERT INTO users (
            id,
            email,
            realname,
            gender,
            description,
            classname,
            password_hash,
            salt,
            group_id
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
        "#,
    )
    .bind(&id)
    .bind(&config.admin_email)
    .bind(&config.admin_realname)
    .bind(&config.admin_gender)
    .bind(&config.admin_description)
    .bind(&config.admin_classname)
    .bind(password_hash)
    .bind(&salt)
    .bind(admin_group_id)
    .execute(pool)
    .await?;
    Ok(())
}

async fn seed_admin_postgres(pool: &PgPool, config: &Config) -> Result<(), sqlx::Error> {
    let admin_group_id = seed_group_postgres(pool, "admin", true).await?;
    let existing = sqlx::query("SELECT id FROM users WHERE email = $1")
        .bind(&config.admin_email)
        .fetch_optional(pool)
        .await?;
    if existing.is_some() {
        println!("Admin user already exists. Skipping.");
        return Ok(());
    }

    let id = Uuid::new_v4().to_string();
    let salt = rand_string(16);
    let password_hash = sha256(config.admin_password.as_bytes(), salt.as_bytes());
    sqlx::query(
        r#"
        INSERT INTO users (
            id,
            email,
            realname,
            gender,
            description,
            classname,
            password_hash,
            salt,
            group_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        "#,
    )
    .bind(&id)
    .bind(&config.admin_email)
    .bind(&config.admin_realname)
    .bind(&config.admin_gender)
    .bind(&config.admin_description)
    .bind(&config.admin_classname)
    .bind(password_hash)
    .bind(&salt)
    .bind(admin_group_id)
    .execute(pool)
    .await?;
    Ok(())
}

fn sha256(password: &[u8], salt: &[u8]) -> String {
    use ring::digest::{digest, SHA256};
    let mut combined = Vec::with_capacity(password.len() + salt.len());
    combined.extend_from_slice(password);
    combined.extend_from_slice(salt);
    hex::encode(digest(&SHA256, &combined))
}

static STRING_MAP: &[u8] = b"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

fn rand_string(len: usize) -> String {
    let mut rng = rand::thread_rng();
    let uniform = Uniform::from(0..STRING_MAP.len());
    let mut vec = Vec::with_capacity(len);
    for _ in 0..len {
        vec.push(STRING_MAP[uniform.sample(&mut rng)]);
    }
    unsafe { String::from_utf8_unchecked(vec) }
}
