//! Activity card component for displaying activity summaries

use models::{ActivityState, ActivitySummary};
use waterui::navigation::NavigationLink;
use waterui::prelude::*;
use waterui::theme::color::*;
use waterui::widget::card;
use waterui_icon::SystemIcon;

use crate::state::AppState;
use crate::views::activity_detail;

/// Activity card component that displays an activity summary
pub struct ActivityCard {
    activity: ActivitySummary,
    state: AppState,
}

impl ActivityCard {
    /// Creates a new activity card
    pub fn new(activity: ActivitySummary, state: AppState) -> Self {
        Self { activity, state }
    }
}

impl View for ActivityCard {
    fn body(self, _env: &Environment) -> impl View {
        let activity_for_nav = self.activity.clone();
        let state = self.state.clone();

        NavigationLink::new(card_content(self.activity), move || {
            activity_detail::view(&activity_for_nav, &state)
        })
    }
}

/// Card content layout
pub fn card_content(activity: ActivitySummary) -> impl View {
    let name = activity.name;
    let location = activity.location;
    let duration = activity.duration;
    let promoter = activity.promoter_name;
    let description = activity.brief_description;
    let volunteer_num = activity.volunteer_num;
    let max_volunteer_num = activity.max_volunteer_num;
    let state = activity.state;
    let date = activity.date;

    card(vstack((
        // Title row
        hstack((
            text!("{name}").font(font::Headline),
            spacer(),
            state_badge(state),
        )),
        // Location
        hstack((
            SystemIcon::from_static("mappin"),
            text!("Location:"),
            text!("{location}"),
        )),
        // Date (if present)
        date.map(|date| {
            hstack((
                SystemIcon::from_static("calendar"),
                text!("Date:"),
                text!("{date}"),
            ))
        }),
        // Duration
        hstack((
            SystemIcon::from_static("clock"),
            text!("Duration:"),
            text!("{duration} hours"),
        )),
        // Volunteer count
        hstack((
            SystemIcon::PERSON,
            text!("Volunteers:"),
            volunteer_count_text(volunteer_num, max_volunteer_num),
        )),
        // Promoter
        hstack((text!("{promoter}")
            .font(font::Caption)
            .foreground(MutedForeground),)),
        // Brief description
        text!("{description}")
            .font(font::Body)
            .foreground(MutedForeground),
    )))
    .padding()
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
