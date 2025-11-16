use mongodb::bson::Document;
use mongodb::bson::{doc, oid::ObjectId};
use mongodb::{Collection, Database};
use serde::Deserialize;
use skyzen::extract::Extractor;
use skyzen::utils::{cookie::Cookie, State};
use skyzen::{
    header::{self, HeaderMap},
    Error, Request, ResultExt, StatusCode,
};

use crate::utils::{parse_oid, ProjectOption};

#[derive(Debug, Clone)]
pub struct Auth {
    uid: ObjectId,
    group: ObjectId,
    collection: Collection<Document>,
}

#[derive(Clone)]
pub struct AuthSession {
    database: State<Database>,
    headers: HeaderMap,
}

#[derive(Debug, Deserialize)]
struct Group {
    #[serde(rename(deserialize = "_id"))]
    id: ObjectId,
}

pub async fn get_group_id(
    database: &Database,
    name: &str,
) -> Result<Option<ObjectId>, mongodb::error::Error> {
    let collection = database.collection::<Group>("group");
    let result = collection.find_one(doc! {"code":name}, None).await?;
    Ok(result.map(|v| v.id))
}

impl Auth {
    pub fn uid(&self) -> ObjectId {
        self.uid.clone()
    }

    pub async fn match_authority(&self, authority: &str) -> skyzen::Result<bool> {
        let result = self
            .collection
            .find_one(
                doc! {"_id":self.group,"group":{"$or":[{"authority":"*"},{"authority":authority}]}},
                ProjectOption::new(None),
            )
            .await?;
        Ok(result.is_some())
    }

    pub async fn ensure_authority(&self, authority: &str) -> skyzen::Result<()> {
        if self.match_authority(authority).await? {
            Ok(())
        } else {
            Err(Error::msg("Auth failed").set_status(StatusCode::FORBIDDEN))
        }
    }
}

impl Extractor for AuthSession {
    async fn extract(request: &mut Request) -> skyzen::Result<Self> {
        let database = request.extensions().get::<State<Database>>().cloned();
        let headers = request.headers().clone();
        let database = database.ok_or_else(|| Error::msg("Database should be provided"))?;
        Ok(AuthSession { database, headers })
    }
}

impl AuthSession {
    pub async fn into_auth(self) -> skyzen::Result<Auth> {
        auth(&self.database, &self.headers).await
    }
}
#[derive(Debug, Deserialize)]
struct Session {
    uid: ObjectId,
}

#[derive(Debug, Deserialize)]
struct User {
    group: ObjectId,
}

fn expired_error() -> skyzen::Error {
    Error::msg("Session expired").set_status(StatusCode::FORBIDDEN)
}

async fn auth(database: &Database, headermap: &HeaderMap) -> skyzen::Result<Auth> {
    let cookies = headermap
        .get(header::COOKIE)
        .ok_or(expired_error())?
        .as_bytes();
    let cookie = Cookie::split_parse_encoded(core::str::from_utf8(cookies)?)
        .find_map(|cookie| {
            if let Ok(cookie) = cookie {
                if cookie.name() == "session" {
                    return Some(cookie);
                }
            }
            None
        })
        .ok_or(expired_error())?;
    let session = parse_oid(cookie.value())?;
    let session_collection = database.collection::<Session>("session");

    let uid: ObjectId = session_collection
        .find_one(doc! {"_id":session}, None)
        .await?
        .ok_or(expired_error())?
        .uid;
    let user_collection = database.collection::<User>("user");
    let group = user_collection
        .find_one(doc! {"_id":uid}, None)
        .await?
        .status(StatusCode::INTERNAL_SERVER_ERROR)?
        .group;

    Ok(Auth {
        uid,
        group,
        collection: database.collection("group"),
    })
}
