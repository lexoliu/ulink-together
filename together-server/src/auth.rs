use async_trait::async_trait;
use levin::extract::Extractor;
use levin::header::HeaderMap;
use levin::routing::RouteNode;
use levin::utils::cookie::Cookie;
use levin::{header, ResultExt, StatusCode};
use levin::{middleware::Next, utils::State, Error, Middleware, Request, Response};
use mongodb::bson::Document;
use mongodb::bson::{doc, oid::ObjectId};
use mongodb::{Collection, Database};
use serde::Deserialize;

use crate::{parse_oid, ProjectOption};

#[derive(Debug, Clone)]
pub struct Auth {
    uid: ObjectId,
    group: ObjectId,
    collection: Collection<Document>,
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

    pub async fn match_authority(&self, authority: &str) -> levin::Result<bool> {
        let result = self
            .collection
            .find_one(
                doc! {"_id":self.group,"group":{"$or":[{"authority":"*"},{"authority":authority}]}},
                ProjectOption::new(None),
            )
            .await?;
        Ok(result.is_some())
    }
}

#[async_trait]
impl Extractor for Auth {
    async fn extract(request: &mut Request) -> levin::Result<Self> {
        request
            .get_extension()
            .map(|v: &Auth| v.clone())
            .ok_or(Error::msg("Auth failed").set_status(StatusCode::FORBIDDEN))
    }
}
pub struct AuthMiddleware;

#[derive(Debug, Deserialize)]
struct Session {
    uid: ObjectId,
}

#[derive(Debug, Deserialize)]
struct User {
    group: ObjectId,
}

#[async_trait]
impl Middleware for AuthMiddleware {
    async fn call_middleware(
        &self,
        request: &mut Request,
        next: Next<'_>,
    ) -> levin::Result<Response> {
        let database: &State<Database> = request
            .get_extension()
            .ok_or(Error::msg("Database should be provided"))?;

        let auth = auth(database, request.headers()).await?;
        request.insert_extension(auth);

        next.run(request).await
    }
}

fn expired_error() -> levin::Error {
    Error::msg("Session expired").set_status(StatusCode::FORBIDDEN)
}

async fn auth(database: &Database, headermap: &HeaderMap) -> levin::Result<Auth> {
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

pub trait AuthExt {
    fn guard(self, authority: &'static str) -> Self;
}

impl AuthExt for RouteNode {
    fn guard(self, authority: &'static str) -> Self {
        self.middleware(GuardMiddleware {
            required_authority: authority,
        })
    }
}

struct GuardMiddleware {
    required_authority: &'static str,
}

#[async_trait]
impl Middleware for GuardMiddleware {
    async fn call_middleware(
        &self,
        request: &mut Request,
        next: Next<'_>,
    ) -> levin::Result<Response> {
        let auth = Auth::extract(request).await?;
        if auth.match_authority(self.required_authority).await? {
            next.run(request).await
        } else {
            Err(Error::msg("Auth failed").set_status(StatusCode::FORBIDDEN))
        }
    }
}
