//! Account view - displays user profile and settings

use waterui::navigation::{NavigationLink, NavigationView};
use waterui::prelude::*;
use waterui::task::spawn_local;
use waterui::theme::color::*;
use waterui_icon::SystemIcon;

use crate::state::AppState;
use crate::views::{create_activity, manage_activity};

/// Account view
pub fn view(state: &AppState) -> NavigationView {
    NavigationView::new(
        text!("Account"),
        scroll(vstack((
            // Profile section
            watch(state.current_user.clone(), |user| match user {
                Some(user) => AnyView::new(profile_section(&user)),
                None => AnyView::new(loading_profile()),
            }),
            Divider,
            // Menu items
            menu_section(state),
            spacer(),
            // Logout button
            button(hstack((
                SystemIcon::from_static("rectangle.portrait.and.arrow.right"),
                text!("Logout").foreground(Accent),
            )))
            .action({
                let state = state.clone();
                move || state.logout()
            })
            .padding(),
            // Version info
            text!("Version")
                .font(font::Caption)
                .foreground(MutedForeground),
            text!("0.1.0")
                .font(font::Caption)
                .foreground(MutedForeground),
            spacer_min(32.0),
        )))
        .padding()
        .on_appear({
            let state = state.clone();
            move || refresh_profile(&state)
        }),
    )
}

/// Profile section showing user info
fn profile_section(user: &models::User) -> impl View {
    let realname = user.realname.clone();
    let email = user.email.clone();
    let classname = user.classname.clone();
    let description = user.description.clone();

    vstack((
        // Avatar placeholder
        SystemIcon::PERSON.foreground(Accent),
        spacer_min(16.0),
        // User name
        text!("{realname}").font(font::Title),
        // Email
        text!("{email}")
            .font(font::Caption)
            .foreground(MutedForeground),
        // Class
        text!("{classname}")
            .font(font::Caption)
            .foreground(MutedForeground),
        spacer_min(16.0),
        // Description
        text!("{description}")
            .font(font::Body)
            .foreground(MutedForeground),
    ))
    .padding()
}

/// Loading profile placeholder
fn loading_profile() -> impl View {
    vstack((
        SystemIcon::PERSON.foreground(MutedForeground),
        spacer_min(16.0),
        text!("Loading...").foreground(MutedForeground),
    ))
    .padding()
}

/// Menu section with navigation items
fn menu_section(state: &AppState) -> impl View {
    vstack((
        menu_button(
            SystemIcon::from_static("person.crop.circle"),
            text!("Edit Profile"),
        ),
        Divider,
        NavigationLink::new(
            menu_row(SystemIcon::from_static("doc.text"), text!("My Activities")),
            {
                let state = state.clone();
                move || manage_activity::view(&state)
            },
        ),
        Divider,
        NavigationLink::new(menu_row(SystemIcon::PLUS, text!("Host Activity")), {
            let state = state.clone();
            move || create_activity::view(&state)
        }),
        Divider,
        menu_button(SystemIcon::SETTINGS, text!("Settings")),
        Divider,
        menu_button(SystemIcon::from_static("info.circle"), text!("About")),
    ))
}

/// Single menu item (row layout)
fn menu_row(icon: SystemIcon, label: impl View) -> impl View {
    hstack((
        icon,
        label,
        spacer(),
        SystemIcon::CHEVRON_RIGHT.foreground(MutedForeground),
    ))
    .padding()
}

/// Menu button for actions without navigation
fn menu_button(icon: SystemIcon, label: impl View) -> impl View {
    button(menu_row(icon, label))
}

/// Refresh user profile from the server
fn refresh_profile(state: &AppState) {
    let state = state.clone();
    spawn_local(async move {
        let api = state.api.get();
        match api.get_current_user().await {
            Ok(user) => {
                state.current_user.set(Some(user));
            }
            Err(e) => {
                state.set_error(e.to_string());
            }
        }
    });
}
