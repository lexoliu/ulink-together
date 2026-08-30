use std::env;
use std::io::{self, Write};

#[path = "../bootstrap.rs"]
mod bootstrap;
#[path = "../database.rs"]
mod database;
#[path = "../schema.rs"]
mod schema;

use bootstrap::SeedUser;
use tracing::info;

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

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    bootstrap::init_cli_logging();
    let config = parse_config()?;
    let connected = bootstrap::connect_database(&config.database_url).await?;

    if connected.database_url != config.database_url {
        info!("Using normalized database URL {}", connected.database_url);
    }

    bootstrap::prepare_database(&connected.database, false).await?;

    if bootstrap::user_exists(&connected.database, &config.admin_email).await? {
        info!(
            "Admin user {} already exists, skipping creation",
            config.admin_email
        );
        info!("Database initialized");
        return Ok(());
    }

    // Built-in roles are seeded by `prepare_database` above; the deploy
    // helper only needs the admin group id to bind the new admin user to it.
    let admin_group = bootstrap::lookup_group(&connected.database, "admin").await?;

    let mut rng = rand::thread_rng();
    bootstrap::insert_user(
        &connected.database,
        connected.database.sqlx(),
        &mut rng,
        &SeedUser {
            email: &config.admin_email,
            realname: &config.admin_realname,
            gender: &config.admin_gender,
            description: &config.admin_description,
            classname: &config.admin_classname,
            avatar_path: None,
            password: &config.admin_password,
            group_id: admin_group,
        },
    )
    .await?;

    info!("Created admin user {}", config.admin_email);
    info!("Database initialized");
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
    let mut stdout = io::stdout();
    stdout
        .write_all(include_str!("../../docs/deploy-help.txt").as_bytes())
        .expect("write deploy help");
}

fn prompt(label: &str, default: Option<&str>) -> Result<String, String> {
    let mut stdout = io::stdout();
    let prompt = match default {
        Some(default_value) => format!("{label} [{default_value}]: "),
        None => format!("{label}: "),
    };
    stdout
        .write_all(prompt.as_bytes())
        .map_err(|error| error.to_string())?;
    stdout.flush().map_err(|error| error.to_string())?;

    let mut input = String::new();
    io::stdin()
        .read_line(&mut input)
        .map_err(|error| error.to_string())?;
    let value = input.trim();

    if value.is_empty() {
        if let Some(default_value) = default {
            Ok(default_value.to_string())
        } else {
            Err(format!("{label} is required"))
        }
    } else {
        Ok(value.to_string())
    }
}
