use crate::{
    auth::{AuthError, AuthSession},
    database::AppDatabase,
    utils::Id,
};

use serde::Serialize;
use skyzen::utils::{Json, State};
use sqlx::Row;
use time::OffsetDateTime;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct ExportItem {
    id: Id,
    user: Id,
    activity: Id,
    student_name: String,
    class_name: String,
    activity_title: String,
    activity_date: Option<String>,
    confirmed_minutes: u32,
    confirmed_at: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ExportBatchResponse {
    batch_id: Id,
    target_format: &'static str,
    status: &'static str,
    created_at: String,
    file_name: String,
    content_type: &'static str,
    content: String,
    items: Vec<ExportItem>,
}

#[skyzen::error]
pub enum ExportError {
    #[error("Session expired", status = FORBIDDEN)]
    SessionExpired,

    #[error("Forbidden", status = FORBIDDEN)]
    Forbidden,

    #[error("Corrupted export data", status = INTERNAL_SERVER_ERROR)]
    CorruptedData,
}

#[skyzen::openapi]
pub async fn generate(
    database: State<AppDatabase>,
    session: AuthSession,
) -> Result<Json<ExportBatchResponse>, ExportError> {
    let auth = session.into_auth().await.map_err(|err| match err {
        AuthError::SessionExpired => ExportError::SessionExpired,
        _ => ExportError::Forbidden,
    })?;
    auth.ensure_authority("generate_export")
        .await
        .map_err(|_| ExportError::Forbidden)?;

    let batch_id = Id::new();
    let created_at = OffsetDateTime::now_utc().to_string();

    sqlx::query(
        database
            .sql(
                "INSERT INTO export_batches (id, creator_id, target_format, status, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(batch_id.to_string())
    .bind(auth.uid().to_string())
    .bind("csv")
    .bind("generated")
    .bind(&created_at)
    .execute(database.sqlx())
    .await
    .expect("Database error");

    let rows = sqlx::query(
        database
            .sql(
                r#"
                SELECT
                    records.user_id,
                    records.activity_id,
                    users.realname,
                    users.classname,
                    activities.name AS activity_title,
                    activities.date AS activity_date,
                    records.confirmed_minutes,
                    records.confirmed_at
                FROM records
                JOIN users ON users.id = records.user_id
                JOIN activities ON activities.id = records.activity_id
                WHERE records.state = 'done' AND records.confirmed_minutes > 0
                ORDER BY users.classname ASC, users.realname ASC, activities.date ASC, activities.name ASC
                "#,
            )
            .as_ref(),
    )
    .fetch_all(database.sqlx())
    .await
    .expect("Database error");

    let mut items = Vec::with_capacity(rows.len());
    for row in rows {
        let item_id = Id::new();
        let user: Id = row
            .try_get::<String, _>("user_id")
            .map_err(|_| ExportError::CorruptedData)?
            .parse()
            .map_err(|_| ExportError::CorruptedData)?;
        let activity: Id = row
            .try_get::<String, _>("activity_id")
            .map_err(|_| ExportError::CorruptedData)?
            .parse()
            .map_err(|_| ExportError::CorruptedData)?;
        let student_name: String = row
            .try_get("realname")
            .map_err(|_| ExportError::CorruptedData)?;
        let class_name: String = row
            .try_get("classname")
            .map_err(|_| ExportError::CorruptedData)?;
        let activity_title: String = row
            .try_get("activity_title")
            .map_err(|_| ExportError::CorruptedData)?;
        let activity_date: Option<String> = row
            .try_get("activity_date")
            .map_err(|_| ExportError::CorruptedData)?;
        let confirmed_minutes = row
            .try_get::<i64, _>("confirmed_minutes")
            .map_err(|_| ExportError::CorruptedData)? as u32;
        let confirmed_at: Option<String> = row
            .try_get("confirmed_at")
            .map_err(|_| ExportError::CorruptedData)?;

        sqlx::query(
            database
                .sql(
                    "INSERT INTO export_items (id, batch_id, user_id, activity_id, activity_title, activity_date, student_name, class_name, confirmed_minutes, confirmed_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
                )
                .as_ref(),
        )
        .bind(item_id.to_string())
        .bind(batch_id.to_string())
        .bind(user.to_string())
        .bind(activity.to_string())
        .bind(&activity_title)
        .bind(activity_date.as_deref())
        .bind(&student_name)
        .bind(&class_name)
        .bind(confirmed_minutes as i64)
        .bind(confirmed_at.as_deref())
        .execute(database.sqlx())
        .await
        .expect("Database error");

        items.push(ExportItem {
            id: item_id,
            user,
            activity,
            student_name,
            class_name,
            activity_title,
            activity_date,
            confirmed_minutes,
            confirmed_at,
        });
    }

    let mut csv = String::from(
        "student_identifier,student_name,class_name,activity_title,activity_date,confirmed_minutes,organiser_confirmation_timestamp\n",
    );
    for item in &items {
        csv.push_str(&format!(
            "{},{},{},{},{},{},{}\n",
            csv_escape(&item.user.to_string()),
            csv_escape(&item.student_name),
            csv_escape(&item.class_name),
            csv_escape(&item.activity_title),
            csv_escape(item.activity_date.as_deref().unwrap_or("")),
            item.confirmed_minutes,
            csv_escape(item.confirmed_at.as_deref().unwrap_or("")),
        ));
    }

    Ok(Json(ExportBatchResponse {
        batch_id,
        target_format: "csv",
        status: "generated",
        created_at: created_at.clone(),
        file_name: format!("volunteer-hours-{}.csv", batch_id),
        content_type: "text/csv",
        content: csv,
        items,
    }))
}

fn csv_escape(value: &str) -> String {
    let escaped = value.replace('"', "\"\"");
    format!("\"{escaped}\"")
}
