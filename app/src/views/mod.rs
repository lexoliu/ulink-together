mod account;
mod activity;
mod auth;
mod message;
mod record;
mod square;

use waterui::prelude::*;

use crate::state::{AppContext, AppRoute, AuthScreen, AuthStatus, MainTab};

pub fn app_root(ctx: AppContext) -> impl View {
    let route_binding = ctx.route();
    let header = Dynamic::watch(route_binding.clone(), move |route| header_view(&route));
    let body_ctx = ctx.clone();
    let body = Dynamic::watch(route_binding.clone(), move |route| {
        route_view(route, body_ctx.clone())
    });
    let tabs = Dynamic::watch(route_binding, move |route| match route {
        AppRoute::Auth(_) => spacer().anyview(),
        _ => AnyView::new(render_tabs(ctx.clone())),
    });

    vstack((header, Divider, body, Divider, tabs)).padding_with(EdgeInsets::all(16.0))
}

fn header_view(route: &AppRoute) -> AnyView {
    match route {
        AppRoute::Auth(AuthScreen::Login) => {
            AnyView::new(vstack((text("Sign in"), "Access your volunteer account")))
        }
        AppRoute::Auth(AuthScreen::Register) => {
            AnyView::new(vstack((text("Create account"), "Join your classmates")))
        }
        _ => AnyView::new(text(title_for(route)).size(20.0)),
    }
}

fn title_for(route: &AppRoute) -> &'static str {
    match route {
        AppRoute::Auth(AuthScreen::Login) => "Login",
        AppRoute::Auth(AuthScreen::Register) => "Register",
        AppRoute::Square => "Square",
        AppRoute::Record => "Record",
        AppRoute::Message => "Messages",
        AppRoute::Account => "Account",
        AppRoute::ViewActivity { .. } => "Activity",
        AppRoute::ManageActivityList => "Manage Activities",
        AppRoute::ManageActivity { .. } => "Roster",
        AppRoute::CreateActivity => "Create Activity",
    }
}

fn route_view(route: AppRoute, ctx: AppContext) -> AnyView {
    match route {
        AppRoute::Auth(screen) => auth::auth_screen(ctx, screen),
        AppRoute::Square => square::square_view(ctx),
        AppRoute::Record => record::record_view(ctx),
        AppRoute::Message => message::message_view(ctx),
        AppRoute::Account => account::account_view(ctx),
        AppRoute::ViewActivity { id } => activity::activity_detail(ctx, id),
        AppRoute::ManageActivityList => activity::manage_list(ctx),
        AppRoute::ManageActivity { id } => activity::manage_activity(ctx, id),
        AppRoute::CreateActivity => activity::create_activity(ctx),
    }
}

fn render_tabs(ctx: AppContext) -> impl View {
    Dynamic::watch(ctx.tab(), move |current| {
        hstack((
            nav_button(ctx.clone(), MainTab::Square, current, "Square"),
            nav_button(ctx.clone(), MainTab::Record, current, "Record"),
            nav_button(ctx.clone(), MainTab::Message, current, "Message"),
            nav_button(ctx.clone(), MainTab::Account, current, "Account"),
        ))
    })
}

fn nav_button(ctx: AppContext, tab: MainTab, current: MainTab, label: &str) -> impl View {
    let text = if current == tab {
        format!("[{label}]")
    } else {
        label.to_string()
    };
    button(text).action(move || ctx.switch_tab(tab))
}

pub(super) fn require_login<F, V>(ctx: AppContext, builder: F) -> impl View
where
    F: 'static + Fn(AppContext, String) -> V,
    V: View + 'static,
{
    Dynamic::watch(ctx.session(), move |session| {
        match (session.status, session.uid.clone()) {
            (AuthStatus::Ready, Some(uid)) => AnyView::new(builder(ctx.clone(), uid)),
            (AuthStatus::Loading, _) => AnyView::new(text("Checking account...")),
            _ => {
                let ctx = ctx.clone();
                AnyView::new(
                    button("Login")
                        .action(move || ctx.set_route(AppRoute::Auth(AuthScreen::Login))),
                )
            }
        }
    })
}
