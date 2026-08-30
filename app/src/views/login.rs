//! Login and registration view

use waterui::component::TextField;
use waterui::form::secure::{Secure, SecureField};
use waterui::graphics::{
    AnimatedMeshGradient, AnimatedMeshGradientConfig, Gradient, ResolvedColor,
};
use waterui::layout::padding::EdgeInsets;
use waterui::prelude::*;
use waterui::reactive::binding;
use waterui::shape::RoundedRectangle;
use waterui::style::{Shadow, Vector};
use waterui::task::spawn_local;

use crate::state::AppState;

/// Helper to create resolved colors for gradients
fn rc(r: f32, g: f32, b: f32) -> ResolvedColor {
    ResolvedColor {
        red: r,
        green: g,
        blue: b,
        opacity: 1.0,
        headroom: 0.0,
    }
}

/// Login/Register view with modern glassmorphism design
pub fn view(state: &AppState) -> impl View {
    let email: Binding<Str> = binding(Str::default());
    let password: Binding<Secure> = binding(Secure::default());
    let is_register_mode = binding(false);
    let is_loading = state.is_loading.clone();
    let error_message = state.error_message.clone();

    // Registration-only fields
    let realname: Binding<Str> = binding(Str::default());
    let gender: Binding<Str> = binding(Str::from("other"));
    let classname: Binding<Str> = binding(Str::default());

    // Colors - dark theme palette
    let card_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.08);
    let white = Color::srgb(255, 255, 255);
    let muted = white.clone().with_opacity(0.6);
    let input_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.1);
    let accent = Color::srgb_f32(0.4, 0.6, 1.0);
    let error_color = Color::srgb_f32(1.0, 0.4, 0.4);

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

    // Form fields with styled inputs
    let form_fields = vstack((
        text!("Email")
            .font(font::Caption)
            .bold()
            .foreground(muted.clone()),
        spacer_min(8.0),
        TextField::new(&email)
            .prompt("you@example.com")
            .padding_with(EdgeInsets::symmetric(16.0, 14.0))
            .background(input_bg.clone())
            .clip(RoundedRectangle::new(12.0)),
        spacer_min(20.0),
        text!("Password")
            .font(font::Caption)
            .bold()
            .foreground(muted.clone()),
        spacer_min(8.0),
        SecureField::new(text!(""), &password)
            .padding_with(EdgeInsets::symmetric(16.0, 14.0))
            .background(input_bg.clone())
            .clip(RoundedRectangle::new(12.0)),
    ));

    // Registration fields (shown only in register mode)
    let register_fields = watch(is_register_mode.clone(), {
        let realname = realname.clone();
        let gender = gender.clone();
        let classname = classname.clone();
        let muted = muted.clone();
        let input_bg = input_bg.clone();
        move |is_register| {
            if is_register {
                AnyView::new(vstack((
                    spacer_min(20.0),
                    text!("Real Name")
                        .font(font::Caption)
                        .bold()
                        .foreground(muted.clone()),
                    spacer_min(8.0),
                    TextField::new(&realname)
                        .padding_with(EdgeInsets::symmetric(16.0, 14.0))
                        .background(input_bg.clone())
                        .clip(RoundedRectangle::new(12.0)),
                    spacer_min(20.0),
                    text!("Gender")
                        .font(font::Caption)
                        .bold()
                        .foreground(muted.clone()),
                    spacer_min(8.0),
                    TextField::new(&gender)
                        .padding_with(EdgeInsets::symmetric(16.0, 14.0))
                        .background(input_bg.clone())
                        .clip(RoundedRectangle::new(12.0)),
                    spacer_min(20.0),
                    text!("Class")
                        .font(font::Caption)
                        .bold()
                        .foreground(muted.clone()),
                    spacer_min(8.0),
                    TextField::new(&classname)
                        .padding_with(EdgeInsets::symmetric(16.0, 14.0))
                        .background(input_bg.clone())
                        .clip(RoundedRectangle::new(12.0)),
                )))
            } else {
                AnyView::new(spacer_min(0.0))
            }
        }
    });

    let primary_button = watch(is_loading.clone(), {
        let is_register_mode = is_register_mode.clone();
        let state = state.clone();
        let email = email.clone();
        let password = password.clone();
        let realname = realname.clone();
        let gender = gender.clone();
        let classname = classname.clone();
        let white = white.clone();
        let accent = accent.clone();
        move |loading| {
            let is_register = is_register_mode.get();
            let label_text = if loading {
                if is_register {
                    "Creating account..."
                } else {
                    "Signing in..."
                }
            } else if is_register {
                "Create Account"
            } else {
                "Sign In"
            };

            if loading {
                AnyView::new(
                    hstack((
                        spacer(),
                        text(Str::from(label_text))
                            .font(font::Body)
                            .bold()
                            .foreground(white.clone().with_opacity(0.5)),
                        spacer(),
                    ))
                    .padding_with(EdgeInsets::symmetric(24.0, 16.0))
                    .background(accent.clone().with_opacity(0.3))
                    .clip(RoundedRectangle::new(14.0)),
                )
            } else {
                let state = state.clone();
                let email = email.clone();
                let password = password.clone();
                let realname = realname.clone();
                let gender = gender.clone();
                let classname = classname.clone();
                let white = white.clone();
                let accent = accent.clone();
                // Create gradient inline since it doesn't implement Clone
                let button_gradient = Gradient::linear(
                    vec![(0.0, rc(0.4, 0.6, 1.0)), (1.0, rc(0.6, 0.4, 1.0))],
                    [0.0, 0.5],
                    [1.0, 0.5],
                );
                AnyView::new(
                    zstack((
                        button_gradient.clip(RoundedRectangle::new(14.0)),
                        hstack((
                            spacer(),
                            text(Str::from(label_text))
                                .font(font::Body)
                                .bold()
                                .foreground(white.clone()),
                            spacer(),
                        ))
                        .padding_with(EdgeInsets::symmetric(24.0, 16.0)),
                    ))
                    .shadow(Shadow::new(
                        accent.with_opacity(0.4),
                        Vector::new(0.0, 4.0),
                        12.0,
                    ))
                    .on_tap({
                        let is_register_mode = is_register_mode.clone();
                        move || {
                            let register_fields = if is_register {
                                Some((realname.clone(), gender.clone(), classname.clone()))
                            } else {
                                None
                            };
                            submit_form(
                                state.clone(),
                                email.clone(),
                                password.clone(),
                                register_fields,
                                is_register_mode.clone(),
                            );
                        }
                    }),
                )
            }
        }
    });

    // Toggle link
    let toggle_link = watch(is_register_mode.clone(), {
        let is_register_mode = is_register_mode.clone();
        let muted = muted.clone();
        let accent = accent.clone();
        move |is_register| {
            let (prefix, action_text) = if is_register {
                ("Already have an account? ", "Sign in")
            } else {
                ("Don't have an account? ", "Sign up")
            };
            hstack((
                spacer(),
                text(Str::from(prefix))
                    .font(font::Footnote)
                    .foreground(muted.clone()),
                text(Str::from(action_text))
                    .font(font::Footnote)
                    .bold()
                    .foreground(accent.clone())
                    .on_tap({
                        let is_register_mode = is_register_mode.clone();
                        move || is_register_mode.set(!is_register)
                    }),
                spacer(),
            ))
        }
    });

    // Error message display
    let error_display = watch(error_message.clone(), move |msg| {
        msg.map(|m| {
            text(Str::from(m))
                .font(font::Caption)
                .foreground(error_color.clone())
                .padding()
        })
    });

    // Card header (changes based on mode)
    let card_header = watch(is_register_mode.clone(), {
        let white = white.clone();
        let muted = muted.clone();
        move |is_register| {
            let (title, subtitle) = if is_register {
                ("Create Account", "Join our volunteer community")
            } else {
                ("Welcome back", "Sign in to continue your journey")
            };
            AnyView::new(vstack((
                text(Str::from(title))
                    .font(font::Title)
                    .bold()
                    .foreground(white.clone()),
                spacer_min(8.0),
                text(Str::from(subtitle))
                    .font(font::Subheadline)
                    .foreground(muted.clone()),
            )))
        }
    });

    // Card content
    let card_content = vstack((
        card_header,
        error_display,
        spacer_min(32.0),
        form_fields,
        register_fields,
        spacer_min(32.0),
        primary_button,
        spacer_min(24.0),
        toggle_link,
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
        scroll(vstack((
            spacer_min(80.0),
            branding,
            spacer_min(48.0),
            card_content,
            spacer_min(60.0),
        )))
        .padding_with(EdgeInsets::symmetric(24.0, 0.0)),
    ))
}

/// Submit form helper function
fn submit_form(
    state: AppState,
    email: Binding<Str>,
    password: Binding<Secure>,
    register_fields: Option<(Binding<Str>, Binding<Str>, Binding<Str>)>,
    is_register_mode: Binding<bool>,
) {
    let email_val = email.get().to_string();
    let password_val = password.get().expose().to_string();
    let is_registration = register_fields.is_some();

    spawn_local(async move {
        state.is_loading.set(true);
        state.clear_error();

        let api = state.api.get();
        let result = if let Some((realname, gender, classname)) = register_fields {
            let form = models::RegisterForm {
                email: email_val,
                password: password_val,
                realname: realname.get().to_string(),
                gender: gender.get().to_string(),
                classname: classname.get().to_string(),
            };
            api.register(&form).await
        } else {
            match api.login(&email_val, &password_val).await {
                Ok(token) => {
                    state.set_token(token);
                    Ok(())
                }
                Err(e) => Err(e),
            }
        };

        state.is_loading.set(false);
        match result {
            Ok(_) => {
                if is_registration {
                    is_register_mode.set(false);
                }
            }
            Err(e) => {
                state.set_error(e.to_string());
            }
        }
    });
}
