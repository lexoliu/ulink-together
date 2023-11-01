mod activity;
mod auth;
mod channel;
mod check_mail;
mod comment;
mod login;
mod message;
mod record;
mod resource;
mod user;

use activity::ActivityState;
use auth::{AuthExt, AuthMiddleware};
use hyper::Server;
use levin::{utils::State, CreateRouteNode, Route};
use levin_hyper::use_hyper;
use mongodb::bson::Document;
use mongodb::{bson::oid::ObjectId, Client};

#[async_std::main]
async fn main() -> levin::Result<()> {
    femme::start();
    let database = Client::with_uri_str("mongodb://localhost:27017")
        .await
        .unwrap()
        .database("together");
    let route: Route = Route::from(["/api/v1".route([
        "".route([
            "/user".route([
                "/:id".at(user::get).guard("view_user"),
                "/:id".delete(user::delete).guard("delete_user"),
            ]),
            "/channel".route([
                "".at(channel::find),
                "".post(channel::create).guard("create_channel"),
                "/:id".post(message::post),
                "/:id".delete(channel::delete),
            ]),
            "/activity".route([
                "".at(activity::find),
                "".post(activity::create).guard("create_activity"),
                "/:id".at(activity::get),
                "/:id".delete(activity::delete),
                "/:id".route([
                    "/apply".post(activity::apply),
                    "/comment".post(comment::post).guard("send_comment"),
                    "/comment".at(comment::list),
                    "/need_volunteer".post(activity::turn(ActivityState::NeedVolunteer)),
                    "/go".post(activity::turn(ActivityState::Going)),
                    "/end".post(activity::turn(ActivityState::Ended)),
                    "/cancel".post(activity::turn(ActivityState::Canceled)),
                ]),
            ]),
            "/record".route([
                "".at(record::find),
                "/:id".route([
                    "/done".post(record::mark_done),
                    "/approve_apply".post(record::approve_apply),
                    "/disapprove_apply".post(record::disapprove_apply),
                ]),
            ]),
            "/mesaage".route([
                "".at(message::find),
                "/:id".at(message::get),
                "/:id".delete(message::delete),
            ]),
            "/resource".route([
                "".post(resource::create),
                "/:filename".at(resource::access)
            ]),
            "/auth/check/:authority".at(check_authority),
        ])
        .middleware(AuthMiddleware),
        "".route(["/login".post(login::handler), "/user".post(user::register)]),
    ])])
    .middleware(State(database))
    .error_handling(|error| async move {
        levin::utils::Json(levin::utils::json!({"message":error.to_string()}))
    });

    Server::bind(&([127, 0, 0, 1], 8080).into())
        .serve(use_hyper(route.build()))
        .await?;
    Ok(())
}

#[derive(Debug, serde::Serialize)]
pub struct CheckAuthorityResult {
    result: bool,
}

pub async fn check_authority(
    auth: auth::Auth,
    params: levin::routing::Params,
) -> levin::Result<levin::utils::Json<CheckAuthorityResult>> {
    let authority = params.get("authority").unwrap();
    Ok(levin::utils::Json(CheckAuthorityResult {
        result: auth.match_authority(authority).await?,
    }))
}

pub fn sha256(v: impl AsRef<[u8]>) -> String {
    use ring::digest::{digest, SHA256};
    hex::encode(digest(&SHA256, v.as_ref()))
}

#[derive(Debug, serde::Serialize)]
pub struct ApiMessage {
    message: std::borrow::Cow<'static, str>,
}

impl ApiMessage {
    pub fn new(message: impl Into<std::borrow::Cow<'static, str>>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl levin::responder::Responder for ApiMessage {
    fn respond_to(
        self,
        request: &levin::Request,
        response: &mut levin::Response,
    ) -> levin::Result<()> {
        levin::utils::Json(self).respond_to(request, response)
    }
}

pub fn oid_to_hex(oid: mongodb::bson::Bson) -> Option<String> {
    oid.as_object_id().map(|oid| oid.to_hex())
}

pub fn parse_oid(oid: &str) -> levin::Result<ObjectId> {
    oid.parse()
        .map_err(|error| levin::Error::new(error, levin::StatusCode::BAD_REQUEST))
}

#[macro_export]
macro_rules! impl_error {
    ($ty:ident,$message:expr) => {
        #[doc = concat!("The error type of `", stringify!($ty), "`.")]
        #[derive(Debug)]
        pub struct $ty {
            _priv: (),
        }

        impl $ty {
            pub(crate) fn new() -> Self {
                Self { _priv: () }
            }
        }

        impl std::fmt::Display for $ty {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                f.write_str($message)
            }
        }

        impl std::error::Error for $ty {}
    };
}

struct ProjectOption(Document);

impl ProjectOption {
    pub fn new(doc: impl Into<Option<Document>>) -> Self {
        Self(doc.into().unwrap_or(mongodb::bson::doc! {"_id":1}))
    }
}

impl From<ProjectOption> for Option<mongodb::options::FindOneOptions> {
    fn from(value: ProjectOption) -> Self {
        Some(
            mongodb::options::FindOneOptions::builder()
                .projection(value.0)
                .build(),
        )
    }
}

impl From<ProjectOption> for Option<mongodb::options::FindOptions> {
    fn from(value: ProjectOption) -> Self {
        Some(
            mongodb::options::FindOptions::builder()
                .projection(value.0)
                .build(),
        )
    }
}
