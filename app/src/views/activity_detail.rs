//! Activity detail view

use models::{ActivityState, ActivitySummary};
use waterui::navigation::NavigationView;
use waterui::prelude::*;
use waterui::reactive::binding;
use waterui::task::spawn_local;
use waterui::theme::color::*;
use waterui_icon::SystemIcon;

use crate::state::AppState;

/// Activity detail view
pub fn view(activity: &ActivitySummary, state: &AppState) -> NavigationView {
    let activity_id = activity.id.to_string();
    let is_joining = binding(false);
    let name = activity.name.clone();
    let description = activity.brief_description.clone();
    let volunteer_num = activity.volunteer_num;
    let max_volunteer_num = activity.max_volunteer_num;

    NavigationView::new(
        text!("{name}"),
        scroll(vstack((
            // Header with state badge
            hstack((
                text!("{name}").font(font::Headline),
                spacer(),
                state_badge(activity.state),
            )),
            Divider,
            // Info section
            info_section(activity),
            Divider,
            // Description
            vstack((
                text!("Description").font(font::Headline),
                text!("{description}").font(font::Body),
            )),
            Divider,
            // Volunteer info
            vstack((
                text!("Volunteer List").font(font::Headline),
                hstack((
                    text!("Volunteers:"),
                    spacer(),
                    volunteer_count_text(volunteer_num, max_volunteer_num),
                )),
            )),
            spacer_min(24.0),
            // Join button (only show if activity is open)
            watch(is_joining.clone(), {
                let activity_id = activity_id.clone();
                let state = state.clone();
                let activity_state = activity.state;
                let is_joining = is_joining.clone();
                move |joining| {
                    let can_join = activity_state == ActivityState::NeedVolunteer;

                    if !can_join {
                        match activity_state {
                            ActivityState::Ended => {
                                AnyView::new(text!("Ended").foreground(MutedForeground))
                            }
                            ActivityState::Canceled => {
                                AnyView::new(text!("Canceled").foreground(Accent))
                            }
                            _ => AnyView::new(text!("Full").foreground(MutedForeground)),
                        }
                    } else if joining {
                        AnyView::new(text!("Loading...").foreground(MutedForeground))
                    } else {
                        AnyView::new(button(text!("Join Activity")).action({
                            let activity_id = activity_id.clone();
                            let state = state.clone();
                            let is_joining = is_joining.clone();
                            move || {
                                let activity_id = activity_id.clone();
                                let state = state.clone();
                                let is_joining = is_joining.clone();

                                is_joining.set(true);
                                spawn_local(async move {
                                    let api = state.api.get();
                                    match api.join_activity(&activity_id).await {
                                        Ok(_) => {
                                            // Optionally show success message
                                        }
                                        Err(e) => {
                                            state.set_error(e.to_string());
                                        }
                                    }
                                    is_joining.set(false);
                                });
                            }
                        }))
                    }
                }
            }),
            spacer(),
        )))
        .padding(),
    )
}

/// Info section with location, date, duration
fn info_section(activity: &ActivitySummary) -> impl View {
    let location = activity.location.clone();
    let duration = activity.duration;
    let promoter = activity.promoter_name.clone();

    vstack((
        // Location
        hstack((
            SystemIcon::from_static("mappin"),
            text!("Location:"),
            spacer(),
            text!("{location}"),
        )),
        // Date
        activity.date.as_ref().map(|date| {
            let date = date.clone();
            hstack((
                SystemIcon::from_static("calendar"),
                text!("Date:"),
                spacer(),
                text!("{date}"),
            ))
        }),
        // Duration
        hstack((
            SystemIcon::from_static("clock"),
            text!("Duration:"),
            spacer(),
            text!("{duration} hours"),
        )),
        // Promoter
        hstack((
            SystemIcon::PERSON,
            text!("Promoter:"),
            spacer(),
            text!("{promoter}"),
        )),
    ))
}

/// Creates the volunteer count text
fn volunteer_count_text(current: u16, max: Option<u16>) -> impl View {
    match max {
        Some(max) => AnyView::new(text!("{current}/{max}")),
        None => AnyView::new(text!("{current}")),
    }
}

/// Creates a state badge for the activity
fn state_badge(state: ActivityState) -> impl View {
    match state {
        ActivityState::Going => text!("Going")
            .font(font::Caption)
            .foreground(Foreground)
            .padding(),
        ActivityState::NeedVolunteer => text!("Need Volunteer")
            .font(font::Caption)
            .foreground(Accent)
            .padding(),
        ActivityState::Ended => text!("Ended")
            .font(font::Caption)
            .foreground(MutedForeground)
            .padding(),
        ActivityState::Canceled => text!("Canceled")
            .font(font::Caption)
            .foreground(Accent)
            .padding(),
    }
}
