//! Together App - Volunteer activity management app built with WaterUI

mod api;
mod components;
mod state;
mod views;

use core::num::NonZeroI32;

use waterui::app::App;
use waterui::id::{Id, TaggedView};
use waterui::navigation::tab::{Tab, TabPosition, Tabs};
use waterui::prelude::*;
use waterui::preview;
use waterui::reactive::binding;
use waterui_icon::SystemIcon;

use state::AppState;
use views::{account, login, record, square};

/// Tab IDs
fn tab_id(n: i32) -> Id {
    NonZeroI32::new(n)
        .expect("tab id should be non-zero")
        .into()
}

/// Creates a tab label with icon and text
fn tab_label(id: Id, icon: SystemIcon, label_text: impl View) -> TaggedView<Id, AnyView> {
    TaggedView::new(id, AnyView::new(vstack((icon, label_text))))
}

/// Creates the main tab bar interface
fn main_tabs(state: &AppState) -> impl View {
    let selection = binding(tab_id(1));

    Tabs::new(
        selection,
        vec![
            Tab::new(
                tab_label(
                    tab_id(1),
                    SystemIcon::from_static("square.grid.2x2"),
                    text!("Square"),
                ),
                {
                    let state = state.clone();
                    move || square::view(&state)
                },
            ),
            Tab::new(
                tab_label(
                    tab_id(2),
                    SystemIcon::from_static("doc.text"),
                    text!("Records"),
                ),
                {
                    let state = state.clone();
                    move || record::view(&state)
                },
            ),
            Tab::new(
                tab_label(tab_id(3), SystemIcon::PERSON, text!("Account")),
                {
                    let state = state.clone();
                    move || account::view(&state)
                },
            ),
        ],
    )
    .position(TabPosition::Bottom)
}

/// Root view that handles authentication state
#[preview]
pub fn root_view() -> impl View {
    let state = AppState::new();

    watch(state.is_logged_in.clone(), {
        let state = state.clone();
        move |logged_in| {
            if logged_in {
                AnyView::new(main_tabs(&state))
            } else {
                AnyView::new(login::view(&state))
            }
        }
    })
}

/// Simple test preview for debugging
#[preview]
pub fn test_preview() -> impl View {
    vstack((
        text!("Hello Preview!").font(font::Title),
        text!("With background").font(font::Body),
    ))
    .padding()
    .background(Color::srgb(100, 150, 200))
}

/// Login view test - minimal
#[preview]
pub fn login_minimal() -> impl View {
    let state = AppState::new();
    // Use watch to ensure state lifetime is tied to the view (same pattern as root_view)
    watch(state.is_logged_in.clone(), {
        let state = state.clone();
        move |_| AnyView::new(login::view(&state))
    })
}

/// Modern login preview with beautiful UI
#[preview]
pub fn login_static() -> impl View {
    use waterui::graphics::{
        AnimatedMeshGradient, AnimatedMeshGradientConfig, Gradient, ResolvedColor,
    };
    use waterui::layout::padding::EdgeInsets;
    use waterui::shape::RoundedRectangle;
    use waterui::style::{Shadow, Vector};

    // Helper to create resolved colors
    fn rc(r: f32, g: f32, b: f32) -> ResolvedColor {
        ResolvedColor {
            red: r,
            green: g,
            blue: b,
            opacity: 1.0,
            headroom: 0.0,
        }
    }

    // Colors - dark theme palette
    let card_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.08);
    let white = Color::srgb(255, 255, 255);
    let muted = white.clone().with_opacity(0.6);
    let input_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.1);
    let accent = Color::srgb_f32(0.4, 0.6, 1.0);

    // App logo/branding
    let branding = vstack((
        text!("Together")
            .font(font::Headline)
            .foreground(white.clone()),
        spacer_min(8.0),
        text!("Volunteer Activity Platform")
            .font(font::Subheadline)
            .foreground(muted.clone()),
    ));

    // Input field placeholder (styled box since TextField crashes preview)
    let make_input = |placeholder: &'static str| {
        hstack((
            text!("{placeholder}")
                .font(font::Body)
                .foreground(muted.clone()),
            spacer(),
        ))
        .padding_with(EdgeInsets::symmetric(16.0, 14.0))
        .background(input_bg.clone())
        .clip(RoundedRectangle::new(12.0))
    };

    // Form section
    let form = vstack((
        text!("Email")
            .font(font::Caption)
            .bold()
            .foreground(muted.clone()),
        spacer_min(8.0),
        make_input("you@example.com"),
        spacer_min(20.0),
        text!("Password")
            .font(font::Caption)
            .bold()
            .foreground(muted.clone()),
        spacer_min(8.0),
        make_input("••••••••"),
    ));

    // Primary button with gradient
    let button_gradient = Gradient::linear(
        vec![
            (0.0, rc(0.4, 0.6, 1.0)), // accent
            (1.0, rc(0.6, 0.4, 1.0)), // accent_light
        ],
        [0.0, 0.5],
        [1.0, 0.5],
    );

    let primary_button = zstack((
        button_gradient.clip(RoundedRectangle::new(14.0)),
        hstack((
            spacer(),
            text!("Sign In")
                .font(font::Body)
                .bold()
                .foreground(white.clone()),
            spacer(),
        ))
        .padding_with(EdgeInsets::symmetric(24.0, 16.0)),
    ))
    .shadow(Shadow::new(
        accent.clone().with_opacity(0.4),
        Vector::new(0.0, 4.0),
        12.0,
    ));

    // Card content
    let card_content = vstack((
        text!("Welcome back")
            .font(font::Title)
            .bold()
            .foreground(white.clone()),
        spacer_min(8.0),
        text!("Sign in to continue your journey")
            .font(font::Subheadline)
            .foreground(muted.clone()),
        spacer_min(32.0),
        form,
        spacer_min(32.0),
        primary_button,
        spacer_min(24.0),
        hstack((
            spacer(),
            text!("Don't have an account? ")
                .font(font::Footnote)
                .foreground(muted.clone()),
            text!("Sign up")
                .font(font::Footnote)
                .bold()
                .foreground(accent.clone()),
            spacer(),
        )),
    ))
    .padding_with(EdgeInsets::all(28.0))
    .background(card_bg)
    .clip(RoundedRectangle::new(24.0));

    // Animated GPU mesh gradient background
    let background = AnimatedMeshGradient::new(
        AnimatedMeshGradientConfig::deep_blue()
            .speed(0.25)
            .warp(0.18),
    );

    // Main layout with gradient background
    zstack((
        background,
        vstack((
            spacer_min(80.0),
            branding,
            spacer_min(48.0),
            card_content,
            spacer(),
        ))
        .padding_with(EdgeInsets::symmetric(24.0, 0.0)),
    ))
}

/// Create activity view preview
#[preview]
pub fn create_activity_preview() -> impl View {
    use waterui::graphics::{AnimatedMeshGradient, AnimatedMeshGradientConfig};
    use waterui::layout::padding::EdgeInsets;
    use waterui::shape::RoundedRectangle;

    let card_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.08);
    let white = Color::srgb(255, 255, 255);
    let muted = white.clone().with_opacity(0.6);

    let background = AnimatedMeshGradient::new(
        AnimatedMeshGradientConfig::deep_blue()
            .speed(0.25)
            .warp(0.18),
    );

    zstack((
        background,
        scroll(vstack((
            spacer_min(24.0),
            vstack((
                text!("New Activity")
                    .font(font::Title)
                    .bold()
                    .foreground(white.clone()),
                spacer_min(8.0),
                text!("Create a volunteer opportunity")
                    .font(font::Subheadline)
                    .foreground(muted.clone()),
                spacer_min(24.0),
                text!("Activity Name")
                    .font(font::Caption)
                    .bold()
                    .foreground(muted.clone()),
                spacer_min(8.0),
                text!("Beach Cleanup")
                    .font(font::Body)
                    .foreground(white.clone()),
                spacer_min(16.0),
                text!("Location")
                    .font(font::Caption)
                    .bold()
                    .foreground(muted.clone()),
                spacer_min(8.0),
                text!("Santa Monica Beach")
                    .font(font::Body)
                    .foreground(white.clone()),
            ))
            .padding_with(EdgeInsets::all(28.0))
            .background(card_bg)
            .clip(RoundedRectangle::new(24.0)),
            spacer_min(60.0),
        )))
        .padding_with(EdgeInsets::symmetric(24.0, 0.0)),
    ))
}

/// Application entry point
pub fn app(env: Environment) -> App {
    App::new(root_view(), env)
}

waterui_ffi::export!();
