mod activity;
mod auth;
mod channel;
mod check_mail;
mod comment;
mod database;
mod login;
mod message;
mod record;
mod resource;
mod user;
mod utils;

use database::AppDatabase;
use skyzen::{
    middleware::ErrorHandlingMiddleware, routing::Router, utils::State, CreateRouteNode, Route,
};
use std::env;

#[skyzen::main]
async fn main() -> Router {
    let sqlx_database_url =
        env::var("DATABASE_URL").unwrap_or_else(|_| "sqlite://together.db".to_string());
    let sqlx_pool = database::build_database(&sqlx_database_url)
        .await
        .expect("connect sql database");
    let database = AppDatabase::new(sqlx_pool);

    Route::new(("/api/v1".route((
        "".route((
            "/user".route(("/{id}".at(user::get), "/{id}".delete(user::delete))),
            "/channel".route((
                "".at(channel::find),
                "".post(channel::create),
                "/{id}".post(message::post),
                "/{id}".delete(channel::delete),
            )),
            "/activity".route((
                "".at(activity::list),
                "".post(activity::create),
                "/{id}".at(activity::get),
                "/{id}".delete(activity::delete),
                "/{id}".route((
                    "/apply".post(activity::join),
                    "/comment".post(comment::post),
                    "/comment".at(comment::list),
                    "/need_volunteer".post(activity::turn_need_volunteer),
                    "/go".post(activity::turn_going),
                    "/end".post(activity::turn_ended),
                    "/cancel".post(activity::turn_canceled),
                )),
            )),
            "/record".route((
                "".at(record::find),
                "/{id}".route((
                    "/done".post(record::mark_done),
                    "/approve_apply".post(record::approve_apply),
                    "/disapprove_apply".post(record::disapprove_apply),
                )),
            )),
            "/mesaage".route((
                "".at(message::find),
                "/{id}".at(message::get),
                "/{id}".delete(message::delete),
            )),
            "/resource".route((
                "".post(resource::create),
                "/{filename}".at(resource::access),
            )),
            "/auth/check/{authority}".at(check_authority),
        )),
        "".route(("/login".post(login::handler), "/user".post(user::register))),
    )),))
    .middleware(State(database))
    .middleware(ErrorHandlingMiddleware::new(|error| async move {
        skyzen::utils::Json(skyzen::utils::json!({"message": error.to_string()}))
    }))
    .build()
}

#[derive(Debug, serde::Serialize)]
pub struct CheckAuthorityResult {
    result: bool,
}

pub async fn check_authority(
    session: auth::AuthSession,
    params: skyzen::routing::Params,
) -> skyzen::Result<skyzen::utils::Json<CheckAuthorityResult>> {
    let auth = session.into_auth().await?;
    let authority = params.get("authority")?;
    Ok(skyzen::utils::Json(CheckAuthorityResult {
        result: auth.match_authority(authority).await?,
    }))
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
