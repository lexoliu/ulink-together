use crate::{oid_to_hex, sha256, ApiMessage};
use bytestr::ByteStr;
use levin::utils::cookie::{Cookie, CookieJar};
use levin::utils::Json;
use levin::Result;
use levin::{extract::ClientIp, utils::State, Error, StatusCode};
use mongodb::bson::oid::ObjectId;
use mongodb::bson::DateTime;
use mongodb::{bson::doc, Database};
use serde::{Deserialize, Serialize};
use std::borrow::Cow;
use std::net::IpAddr;
use time::{Duration, OffsetDateTime};

#[derive(Debug, Deserialize)]
struct Form<'a> {
    email: Cow<'a, str>,
    password: String,
}

pub async fn handler(
    database: State<Database>,
    ip: ClientIp,
    mut cookies: CookieJar,
    form: ByteStr,
) -> Result<(ApiMessage, CookieJar)> {
    #[derive(Deserialize)]
    struct User<'a> {
        #[serde(rename(deserialize = "_id"))]
        id: ObjectId,
        password: Cow<'a, str>,
        salt: Cow<'a, str>,
    }
    let Json(form) = Json::<Form>::from_str(form.as_str())?;

    let users = database.collection::<User>("user");

    // TODO: send email to check if user logins from a new ip address

    let user = users
        .find_one(doc! {"email":form.email.as_ref()}, None)
        .await?
        .ok_or(Error::msg("User not exists").set_status(StatusCode::NOT_FOUND))?;

    if sha256(form.password + user.salt.as_ref()) == user.password {
        let session = generate_session(&database, user.id, ip.0).await?;
        cookies.add(
            Cookie::build("uid", user.id.to_hex())
                .expires(OffsetDateTime::now_utc() + Duration::weeks(2))
                .path("/")
                .finish(),
        );
        cookies.add(
            Cookie::build("session", session)
                .expires(OffsetDateTime::now_utc() + Duration::weeks(2))
                .http_only(true)
                .path("/")
                .finish(),
        );
    } else {
        return Err(Error::msg("Wrong email or password").set_status(StatusCode::FORBIDDEN));
    }

    //check_mail(&database, id)

    Ok(((ApiMessage::new("Login successfully")), cookies))
}

#[derive(Debug, Serialize)]
struct Session {
    uid: ObjectId,
    generated_date: DateTime,
    ip: String,
}

async fn generate_session(database: &Database, uid: ObjectId, ip: IpAddr) -> levin::Result<String> {
    let session = database.collection::<Session>("session");

    let result = session
        .insert_one(
            Session {
                uid,
                generated_date: DateTime::now(),
                ip: ip.to_string(),
            },
            None,
        )
        .await?;

    Ok(oid_to_hex(result.inserted_id).unwrap())
}
