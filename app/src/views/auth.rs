use sha2::{Digest, Sha256};
use waterui::{prelude::*, task::spawn_local};

use crate::models::RegisterPayload;
use crate::state::{AppContext, AppRoute, AuthScreen};

pub fn auth_screen(ctx: AppContext, screen: AuthScreen) -> AnyView {
    match screen {
        AuthScreen::Login => AnyView::new(login_form(ctx)),
        AuthScreen::Register => AnyView::new(register_form(ctx)),
    }
}

fn login_form(ctx: AppContext) -> impl View {
    let email = Binding::container(Str::default());
    let password = Binding::container(Str::default());
    let feedback = Binding::container(String::new());
    let ctx_for_register = ctx.clone();

    vstack((
        field("Email", &email).prompt("name@example.com"),
        field("Password", &password),
        Dynamic::watch(feedback.clone(), |message| {
            if message.is_empty() {
                spacer().anyview()
            } else {
                AnyView::new(text(message))
            }
        }),
        button("Login").action_with(&feedback, move |status: Binding<String>| {
            let ctx = ctx.clone();
            let email_value = email.get().to_string();
            let password_value = password.get().to_string();
            spawn_local(async move {
                status.set(String::new());
                let hash = hash_password(&password_value);
                match ctx.api().login(&email_value, &hash).await {
                    Ok(_) => {
                        ctx.refresh_session().await;
                        ctx.set_route(AppRoute::Square);
                    }
                    Err(err) => status.set(err.to_string()),
                }
            });
        }),
        button("Need an account? Register")
            .action(move || ctx_for_register.set_route(AppRoute::Auth(AuthScreen::Register))),
    ))
}

fn register_form(ctx: AppContext) -> impl View {
    let email = Binding::container(Str::default());
    let realname = Binding::container(Str::default());
    let classname = Binding::container(Str::default());
    let gender = Binding::container(Str::default());
    let password = Binding::container(Str::default());
    let feedback = Binding::container(String::new());
    let ctx_for_login = ctx.clone();

    vstack((
        field("Email", &email),
        field("Real name", &realname),
        field("Class (e.g. G1-1)", &classname),
        field("Gender", &gender),
        field("Password", &password),
        Dynamic::watch(feedback.clone(), |message| {
            if message.is_empty() {
                spacer().anyview()
            } else {
                AnyView::new(text(message))
            }
        }),
        button("Register").action_with(&feedback, move |status: Binding<String>| {
            let ctx = ctx.clone();
            let payload = RegisterPayload {
                email: email.get().to_string(),
                realname: realname.get().to_string(),
                classname: classname.get().to_string(),
                gender: gender.get().to_string(),
                password: hash_password(&password.get().to_string()),
            };
            spawn_local(async move {
                status.set(String::new());
                match ctx.api().register(payload).await {
                    Ok(response) => {
                        status.set(response.message);
                        ctx.set_route(AppRoute::Auth(AuthScreen::Login));
                    }
                    Err(err) => status.set(err.to_string()),
                }
            });
        }),
        button("Back to login")
            .action(move || ctx_for_login.set_route(AppRoute::Auth(AuthScreen::Login))),
    ))
}

fn hash_password(password: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(password.as_bytes());
    let digest = hasher.finalize();
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}
