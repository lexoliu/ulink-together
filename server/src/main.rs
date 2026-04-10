mod activity;
mod auth;
mod channel;
mod comment;
mod database;
mod export;
mod leaderboard;
mod login;
mod message;
mod push;
mod record;
mod resource;
mod schema;
mod user;
mod utils;

#[cfg(test)]
mod api_tests;

use crate::auth::AuthError;
use database::AppDatabase;
use push::PushHub;
use skyzen::{
    middleware::ErrorHandlingMiddleware, routing::Router, utils::Json, utils::State,
    CreateRouteNode, Route,
};
use std::env;

pub fn api() -> Route {
    Route::new((
        "/health".at(health),
        "/channel"
            .at(channel::find)
            .post(channel::create)
            .route(("/{id}".post(message::post).delete(channel::delete),)),
        "/activity"
            .at(activity::list)
            .post(activity::create)
            .route(("/{id}"
                .at(activity::get)
                .put(activity::update)
                .delete(activity::delete)
                .route((
                    "/apply".post(activity::apply),
                    "/withdraw".post(activity::withdraw),
                    "/comment".at(comment::list).post(comment::post),
                    "/comment/{comment_id}".delete(comment::delete),
                    "/need_volunteer".post(activity::turn_need_volunteer),
                    "/go".post(activity::turn_going),
                    "/end".post(activity::turn_ended),
                    "/cancel".post(activity::turn_canceled),
                )),)),
        "/record"
            .at(record::find)
            .post(record::find)
            .route(("/{id}".route((
                "/confirm".post(record::confirm),
                "/confirm_custom".post(record::confirm_custom),
                "/approve".post(record::approve),
                "/cancel".post(record::cancel),
            )),)),
        "/message"
            .at(message::find)
            .route(("/{id}".at(message::get).delete(message::delete),)),
        "/leaderboard".at(leaderboard::list),
        "/export".post(export::generate),
        "/resource"
            .post(resource::create)
            .route(("/{filename}".at(resource::access).delete(resource::delete),)),
        "/push".at(push::handler),
        "/auth".route((
            "/check/{authority}".at(check_authority),
            "/groups"
                .at(auth::list_groups)
                .route(("/{code}".put(auth::update_group),)),
        )),
        "/login".post(login::handler),
        "/logout".post(login::logout),
        "/password".route((
            "/change".post(login::change_password),
            "/reset/request".post(login::request_password_reset),
            "/reset/confirm".post(login::confirm_password_reset),
        )),
        "/user".at(user::list).post(user::register).route((
            "/{id}".at(user::get).put(user::update).delete(user::delete),
            "/classes".at(user::list_classes),
            "/batch/import_csv".post(user::import_csv),
            "/batch/update_class".post(user::batch_update_class),
            "/batch/delete_class".post(user::batch_delete_class),
        )),
    ))
    .enable_api_doc()
}

pub(crate) fn build_router(database: AppDatabase, push_hub: PushHub) -> Router {
    let route = Route::new("/api/v1".route(api()));
    route
        .middleware(State(database))
        .middleware(State(push_hub))
        .middleware(ErrorHandlingMiddleware::new(|error| async move {
            crate::utils::ApiMessage::with_status(
                crate::utils::normalize_endpoint_error_message(&error.to_string()).into_owned(),
                error.status(),
            )
        }))
        .build()
}

#[skyzen::main]
async fn main() -> Router {
    let sqlx_database_url =
        parse_database_url().unwrap_or_else(|| "sqlite://together.db".to_string());
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
pub struct HealthResponse {
    status: &'static str,
}

#[skyzen::openapi]
pub async fn health() -> Json<HealthResponse> {
    Json(HealthResponse { status: "ok" })
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
