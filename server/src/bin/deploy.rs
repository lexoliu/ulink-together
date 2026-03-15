use std::env;
use std::io::{self, Write};

#[path = "../schema.rs"]
mod schema;

use rand::{distributions::Uniform, prelude::Distribution};
use sqlx::{postgres::PgPoolOptions, sqlite::SqlitePoolOptions, PgPool, SqlitePool};
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
        let converted = format!(
            "sqlite://{}",
            config.database_url.trim_start_matches("d1://")
        );
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

    let database_url = database_url
        .ok_or_else(|| "--database-url is required in non-interactive mode".to_string())?;
    let admin_email = admin_email
        .ok_or_else(|| "--admin-email is required in non-interactive mode".to_string())?;
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
    schema::apply_schema_sqlite(pool).await
}

async fn create_tables_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    schema::apply_schema_postgres(pool).await
}

async fn seed_groups_sqlite(pool: &SqlitePool) -> Result<(), sqlx::Error> {
    schema::seed_builtin_groups_sqlite(pool).await
}

async fn seed_groups_postgres(pool: &PgPool) -> Result<(), sqlx::Error> {
    schema::seed_builtin_groups_postgres(pool).await
}

async fn seed_group_sqlite(
    pool: &SqlitePool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    schema::ensure_group_sqlite(pool, code, allow_all).await
}

async fn seed_group_postgres(
    pool: &PgPool,
    code: &str,
    allow_all: bool,
) -> Result<String, sqlx::Error> {
    schema::ensure_group_postgres(pool, code, allow_all).await
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
