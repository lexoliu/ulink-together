use std::{borrow::Cow, path::Path, str::FromStr};

use crate::schema::{apply_schema_any, seed_builtin_groups_any};
use sqlx::{
    any::{install_default_drivers, AnyPoolOptions},
    sqlite::SqliteConnectOptions,
    Any, ConnectOptions, Pool,
};

/// Aggregates every persistence backend we currently depend on.
#[derive(Clone)]
pub struct AppDatabase {
    pool: Pool<Any>,
    kind: DatabaseKind,
}

impl AppDatabase {
    pub fn new(pool: Pool<Any>, kind: DatabaseKind) -> Self {
        Self { pool, kind }
    }

    pub fn sqlx(&self) -> &Pool<Any> {
        &self.pool
    }

    pub fn kind(&self) -> DatabaseKind {
        self.kind
    }

    pub fn sql<'a>(&self, sql: &'a str) -> Cow<'a, str> {
        if self.kind == DatabaseKind::Postgres {
            return Cow::Owned(postgres_sql(sql));
        }
        Cow::Borrowed(sql)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DatabaseKind {
    Postgres,
    Sqlite,
}

pub fn database_kind_from_url(database_url: &str) -> DatabaseKind {
    let lower = database_url.to_ascii_lowercase();
    if lower.starts_with("postgres://") || lower.starts_with("postgresql://") {
        DatabaseKind::Postgres
    } else {
        DatabaseKind::Sqlite
    }
}

fn postgres_sql(sql: &str) -> String {
    if !sql.contains('?') {
        return sql.to_string();
    }
    let mut out = String::with_capacity(sql.len());
    let mut chars = sql.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch == '?' {
            if matches!(chars.peek(), Some(next) if next.is_ascii_digit()) {
                out.push('$');
                continue;
            }
        }
        out.push(ch);
    }
    out
}

pub async fn build_database(database_url: &str) -> sqlx::Result<Pool<Any>> {
    install_default_drivers();
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

    let url = if database_url.starts_with("sqlite://") || database_url.starts_with("sqlite::") {
        SqliteConnectOptions::from_str(database_url)?
            .create_if_missing(true)
            .to_url_lossy()
            .to_string()
    } else {
        database_url.to_string()
    };

    AnyPoolOptions::new().max_connections(5).connect(&url).await
}

#[cfg(test)]
pub(crate) async fn build_test_database() -> AppDatabase {
    install_default_drivers();
    let pool = AnyPoolOptions::new()
        .max_connections(1)
        .connect("sqlite::memory:")
        .await
        .expect("connect test database");
    let database = AppDatabase::new(pool, DatabaseKind::Sqlite);
    apply_schema_any(database.sqlx())
        .await
        .expect("create test schema");
    seed_builtin_groups_any(database.sqlx())
        .await
        .expect("seed built-in groups");

    database
}
