use std::borrow::Cow;

use bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use skyzen::{routing::Params, utils::State};
use sqlx::Row;
use time::OffsetDateTime;

use crate::database::AppDatabase;

const EMAIL_DOMAIN: &[&str] = &["ulink.cn"];

#[derive(Debug, Deserialize, Serialize)]
struct CheckMail<'a> {
    email: Cow<'a, str>,
}

pub async fn send_check_mail(database: &AppDatabase, email: &str) -> Result<ObjectId, sqlx::Error> {
    let id = ObjectId::new();
    sqlx::query("INSERT INTO check_mails (id, email, created_at) VALUES (?1, ?2, ?3)")
        .bind(id.to_hex())
        .bind(email)
        .bind(OffsetDateTime::now_utc().to_string())
        .execute(database.sqlx())
        .await?;
    Ok(id)
}

pub async fn check_mail(
    database: &AppDatabase,
    id: ObjectId,
) -> Result<Option<String>, sqlx::Error> {
    let row = sqlx::query("SELECT email FROM check_mails WHERE id = ?1")
        .bind(id.to_hex())
        .fetch_optional(database.sqlx())
        .await?;

    if row.is_some() {
        sqlx::query("DELETE FROM check_mails WHERE id = ?1")
            .bind(id.to_hex())
            .execute(database.sqlx())
            .await?;
    }

    Ok(row.and_then(|row| row.try_get("email").ok()))
}

// TODO:check params length (prevent CC attack)
pub async fn handler(state: State<AppDatabase>, params: Params) -> skyzen::Result<&'static str> {
    let email = params.get("email")?;
    let mut email_is_legal = false;
    for legal_domain in EMAIL_DOMAIN {
        if let Some((_, domain)) = email.split_once('@') {
            if *legal_domain == domain {
                email_is_legal = true;
                break;
            }
        }
    }

    if !email_is_legal {
        return Ok("Illegal email address");
    }

    send_check_mail(&state, email).await?;

    Ok("An email has been sent, please check the mailbox.")
}
