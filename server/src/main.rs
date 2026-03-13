mod activity;
mod auth;
mod channel;
mod comment;
mod database;
mod login;
mod leaderboard;
mod message;
mod notification;
mod push;
mod record;
mod resource;
mod export;
mod schema;
mod user;
mod utils;

#[cfg(test)]
mod api_tests;

use crate::auth::AuthError;
use database::AppDatabase;
use push::PushHub;
use skyzen::{
    middleware::ErrorHandlingMiddleware, routing::Router, utils::State, CreateRouteNode, Route,
};
use std::env;

pub fn api() -> Route {
    Route::new((
        "/user".route("/{id}".at(user::get).put(user::update).delete(user::delete)),
        "/channel"
            .at(channel::find)
            .post(channel::create)
            .route(("/{id}".post(message::post).delete(channel::delete),)),
        "/activity"
            .at(activity::list)
            .post(activity::create)
            .route(("/{id}".at(activity::get).put(activity::update).delete(activity::delete).route((
                "/apply".post(activity::join),
                "/comment".at(comment::list).post(comment::post),
                "/need_volunteer".post(activity::turn_need_volunteer),
                "/go".post(activity::turn_going),
                "/end".post(activity::turn_ended),
                "/cancel".post(activity::turn_canceled),
            )),)),
        "/record".at(record::find).post(record::find).route(("/{id}".route((
            "/done".post(record::mark_done),
            "/approve_apply".post(record::approve_apply),
            "/disapprove_apply".post(record::disapprove_apply),
        )),)),
        "/message"
            .at(message::find)
            .route(("/{id}".at(message::get).delete(message::delete),)),
        "/leaderboard".at(leaderboard::list),
        "/export".post(export::generate),
        "/resource"
            .post(resource::create)
            .route(("/{filename}".at(resource::access),)),
        "/notification"
            .at(notification::list)
            .post(notification::create),
        "/push".at(push::handler),
        "/auth/check/{authority}".at(check_authority),
        "/login".post(login::handler),
        "/logout".post(login::logout),
        "/user".post(user::register),
    ))
    .enable_api_doc()
}

pub(crate) fn build_router(database: AppDatabase, push_hub: PushHub) -> Router {
    let route = Route::new("/api/v1".route(api()));
    route
        .middleware(State(database))
        .middleware(State(push_hub))
        .middleware(ErrorHandlingMiddleware::new(|error| async move {
            crate::utils::ApiMessage::with_status(error.to_string(), error.status())
        }))
        .build()
}

#[skyzen::main]
async fn main() -> Router {
    let sqlx_database_url = parse_database_url().unwrap_or_else(|| "sqlite://together.db".to_string());
    let sqlx_pool = database::build_database(&sqlx_database_url)
        .await
        .expect("connect sql database");
    let database = AppDatabase::new(
        sqlx_pool,
        database::database_kind_from_url(&sqlx_database_url),
    );
    let push_hub = push::PushHub::new();
    build_router(database, push_hub)
}

fn parse_database_url() -> Option<String> {
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--database-url" | "--db" => return args.next(),
            _ => {}
        }
    }
    None
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
