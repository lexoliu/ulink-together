use sqlx::{migrate::Migrator, sqlite::SqlitePoolOptions, Pool, Sqlite};

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

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
    let pool = SqlitePoolOptions::new()
        .max_connections(10)
        .connect(database_url)
        .await?;
    MIGRATOR.run(&pool).await?;
    Ok(pool)
}
