mod api;
mod models;
mod state;
mod views;

use state::{AppConfig, AppContext};
use waterui::{prelude::*, task::spawn_local};

pub fn init() -> Environment {
    Environment::new()
}

pub fn main() -> impl View {
    let ctx = AppContext::new(AppConfig::from_env());
    let refresh_ctx = ctx.clone();
    spawn_local(async move {
        refresh_ctx.refresh_session().await;
    });
    views::app_root(ctx)
}

waterui_ffi::export!();
