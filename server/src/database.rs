use std::{path::Path, str::FromStr};

use sqlx::{
    sqlite::{SqliteConnectOptions, SqlitePoolOptions},
    Pool, Sqlite,
};

/// Aggregates every persistence backend we currently depend on.
#[derive(Clone)]
pub struct AppDatabase {
    pool: Pool<Sqlite>,
}

impl AppDatabase {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub fn sqlx(&self) -> &Pool<Sqlite> {
        &self.pool
    }
}

pub async fn build_database(database_url: &str) -> sqlx::Result<Pool<Sqlite>> {
    if let Some(path) = database_url.strip_prefix("sqlite://") {
        if path != ":memory:" {
            if let Some(parent) = Path::new(path).parent() {
                if !parent.as_os_str().is_empty() {
                    // Best-effort create parent directories for on-disk sqlite files.
                    let _ = std::fs::create_dir_all(parent);
                }
            }
        }
    }

    let connect_options = SqliteConnectOptions::from_str(database_url)?
        .create_if_missing(true);

    SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(connect_options)
        .await
}
