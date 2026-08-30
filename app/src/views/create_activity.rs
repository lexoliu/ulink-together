//! Create activity view

use models::CreateActivityForm;
use waterui::component::TextField;
use waterui::graphics::{
    AnimatedMeshGradient, AnimatedMeshGradientConfig, Gradient, ResolvedColor,
};
use waterui::layout::padding::EdgeInsets;
use waterui::navigation::NavigationView;
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

/// Create activity view
pub fn view(state: &AppState) -> NavigationView {
    // Form fields
    let name: Binding<Str> = binding(Str::default());
    let location: Binding<Str> = binding(Str::default());
    let date: Binding<Str> = binding(Str::default());
    let brief_description: Binding<Str> = binding(Str::default());
    let description: Binding<Str> = binding(Str::default());
    let duration: Binding<Str> = binding(Str::from("60"));
    let max_volunteers: Binding<Str> = binding(Str::default());

    let is_submitting = binding(false);
    let error_message: Binding<Option<String>> = binding(None);

    // Colors
    let card_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.08);
    let white = Color::srgb(255, 255, 255);
    let muted = white.clone().with_opacity(0.6);
    let input_bg = Color::srgb_f32(1.0, 1.0, 1.0).with_opacity(0.1);
    let accent = Color::srgb_f32(0.4, 0.6, 1.0);
    let error_color = Color::srgb_f32(1.0, 0.4, 0.4);

    // Form field helper
    let make_field = |label: &'static str, binding: &Binding<Str>, placeholder: &'static str| {
        let muted = muted.clone();
        let input_bg = input_bg.clone();
        vstack((
            text(Str::from(label))
                .font(font::Caption)
                .bold()
                .foreground(muted),
            spacer_min(8.0),
            TextField::new(binding)
                .prompt(placeholder)
                .padding_with(EdgeInsets::symmetric(16.0, 14.0))
                .background(input_bg)
                .clip(RoundedRectangle::new(12.0)),
        ))
    };

    // Form content
    let form_content = vstack((
        make_field("Activity Name", &name, "Beach Cleanup"),
        spacer_min(16.0),
        make_field("Location", &location, "Santa Monica Beach"),
        spacer_min(16.0),
        make_field("Date", &date, "2024-03-15"),
        spacer_min(16.0),
        make_field("Brief Description", &brief_description, "Short summary..."),
        spacer_min(16.0),
        make_field("Full Description", &description, "Detailed description..."),
        spacer_min(16.0),
        hstack((
            make_field("Duration (min)", &duration, "60"),
            spacer_min(16.0),
            make_field("Max Volunteers", &max_volunteers, "30"),
        )),
    ));

    // Error display
    let error_display = watch(error_message.clone(), move |msg| {
        msg.map(|m| {
            text(Str::from(m))
                .font(font::Caption)
                .foreground(error_color.clone())
                .padding()
        })
    });

    // Submit button
    let submit_button = watch(is_submitting.clone(), {
        let state = state.clone();
        let name = name.clone();
        let location = location.clone();
        let date = date.clone();
        let brief_description = brief_description.clone();
        let description = description.clone();
        let duration = duration.clone();
        let max_volunteers = max_volunteers.clone();
        let is_submitting = is_submitting.clone();
        let error_message = error_message.clone();
        let white = white.clone();
        let accent = accent.clone();
        move |submitting| {
            let label_text = if submitting {
                "Creating..."
            } else {
                "Create Activity"
            };

            if submitting {
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
                let name = name.clone();
                let location = location.clone();
                let date = date.clone();
                let brief_description = brief_description.clone();
                let description = description.clone();
                let duration = duration.clone();
                let max_volunteers = max_volunteers.clone();
                let is_submitting = is_submitting.clone();
                let error_message = error_message.clone();
                let white = white.clone();
                let accent = accent.clone();
                let button_gradient = Gradient::linear(
                    vec![
                        (0.0, rc(0.3, 0.7, 0.5)), // green accent
                        (1.0, rc(0.4, 0.6, 0.7)),
                    ],
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
                    .on_tap(move || {
                        submit_activity(
                            state.clone(),
                            name.clone(),
                            location.clone(),
                            date.clone(),
                            brief_description.clone(),
                            description.clone(),
                            duration.clone(),
                            max_volunteers.clone(),
                            is_submitting.clone(),
                            error_message.clone(),
                        );
                    }),
                )
            }
        }
    });

    // Card content
    let card_content = vstack((
        text!("New Activity")
            .font(font::Title)
            .bold()
            .foreground(white.clone()),
        spacer_min(8.0),
        text!("Create a volunteer opportunity")
            .font(font::Subheadline)
            .foreground(muted.clone()),
        error_display,
        spacer_min(24.0),
        form_content,
        spacer_min(32.0),
        submit_button,
        spacer_min(24.0),
    ))
    .padding_with(EdgeInsets::all(28.0))
    .background(card_bg)
    .clip(RoundedRectangle::new(24.0));

    // Background
    let background = AnimatedMeshGradient::new(
        AnimatedMeshGradientConfig::deep_blue()
            .speed(0.25)
            .warp(0.18),
    );

    NavigationView::new(
        text!("Create Activity"),
        zstack((
            background,
            scroll(vstack((spacer_min(24.0), card_content, spacer_min(60.0))))
                .padding_with(EdgeInsets::symmetric(24.0, 0.0)),
        )),
    )
}

/// Submit activity creation
fn submit_activity(
    state: AppState,
    name: Binding<Str>,
    location: Binding<Str>,
    date: Binding<Str>,
    brief_description: Binding<Str>,
    description: Binding<Str>,
    duration: Binding<Str>,
    max_volunteers: Binding<Str>,
    is_submitting: Binding<bool>,
    error_message: Binding<Option<String>>,
) {
    spawn_local(async move {
        is_submitting.set(true);
        error_message.set(None);

        // Parse duration
        let duration_val: u16 = match duration.get().parse() {
            Ok(v) => v,
            Err(_) => {
                error_message.set(Some("Invalid duration".to_string()));
                is_submitting.set(false);
                return;
            }
        };

        // Parse max volunteers (optional)
        let max_vol: Option<u16> = {
            let val = max_volunteers.get();
            if val.is_empty() {
                None
            } else {
                match val.parse() {
                    Ok(v) => Some(v),
                    Err(_) => {
                        error_message.set(Some("Invalid max volunteers".to_string()));
                        is_submitting.set(false);
                        return;
                    }
                }
            }
        };

        // Parse date (optional)
        let date_val = {
            let val = date.get();
            if val.is_empty() {
                None
            } else {
                Some(val.to_string())
            }
        };

        let form = CreateActivityForm {
            name: name.get().to_string(),
            location: location.get().to_string(),
            date: date_val,
            brief_description: brief_description.get().to_string(),
            description: description.get().to_string(),
            duration: duration_val,
            max_volunteer_num: max_vol,
        };

        let api = state.api.get();
        match api.create_activity(&form).await {
            Ok(_) => {
                // Success - could navigate back or show success message
            }
            Err(e) => {
                error_message.set(Some(e.to_string()));
            }
        }

        is_submitting.set(false);
    });
}
