use sqlx::{Pool, Sqlite};

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
    todo!()
}
