mod activity;
mod auth;
mod channel;
mod comment;
mod database;
mod login;
mod message;
mod record;
mod resource;
mod user;
mod utils;

use crate::auth::AuthError;
use database::AppDatabase;
use skyzen::{
    middleware::ErrorHandlingMiddleware, routing::Router, utils::State, CreateRouteNode, Route,
};
use std::env;

pub fn api() -> Route {
    Route::new((
        "/user".route("/{id}".at(user::get).delete(user::delete)),
        "/channel"
            .at(channel::find)
            .post(channel::create)
            .route(("/{id}".post(message::post).delete(channel::delete),)),
        "/activity"
            .at(activity::list)
            .post(activity::create)
            .route(("/{id}".at(activity::get).delete(activity::delete).route((
                "/apply".post(activity::join),
                "/comment".at(comment::list).post(comment::post),
                "/need_volunteer".post(activity::turn_need_volunteer),
                "/go".post(activity::turn_going),
                "/end".post(activity::turn_ended),
                "/cancel".post(activity::turn_canceled),
            )),)),
        "/record".at(record::find).route(("/{id}".route((
            "/done".post(record::mark_done),
            "/approve_apply".post(record::approve_apply),
            "/disapprove_apply".post(record::disapprove_apply),
        )),)),
        "/message"
            .at(message::find)
            .route(("/{id}".at(message::get).delete(message::delete),)),
        "/resource"
            .post(resource::create)
            .route(("/{filename}".at(resource::access),)),
        "/auth/check/{authority}".at(check_authority),
        "/login".post(login::handler),
        "/user".post(user::register),
    ))
    .enable_api_doc()
}

#[skyzen::main]
async fn main() -> Router {
    let sqlx_database_url =
        env::var("DATABASE_URL").unwrap_or_else(|_| "sqlite://together.db".to_string());
    let sqlx_pool = database::build_database(&sqlx_database_url)
        .await
        .expect("connect sql database");
    let database = AppDatabase::new(sqlx_pool);

    let route = Route::new("/api/v1".route(api()));

    route
        .middleware(State(database))
        .middleware(ErrorHandlingMiddleware::new(|error| async move {
            skyzen::utils::Json(skyzen::utils::json!({"message": error.to_string()}))
        }))
        .build()
}

#[derive(Debug, serde::Serialize, utoipa::ToSchema)]
pub struct CheckAuthorityResult {
    result: bool,
}

/// Check if the current user has the specified authority
#[skyzen::openapi]
pub async fn check_authority(
    session: auth::AuthSession,
    params: skyzen::routing::Params,
) -> Result<skyzen::utils::Json<CheckAuthorityResult>, AuthError> {
    let auth = session.into_auth().await?;
    let authority = params.get("authority").expect("Param not found");
    Ok(skyzen::utils::Json(CheckAuthorityResult {
        result: auth.match_authority(authority).await?,
    }))
}
