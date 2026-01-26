//! Activity square view - displays list of activities

use models::ListActivityQuery;
use waterui::navigation::NavigationView;
use waterui::prelude::*;
use waterui::reactive::binding;
use waterui::task::spawn_local;
use waterui::theme::color::*;

use crate::components::ActivityCard;
use crate::state::AppState;

/// Activity square view
pub fn view(state: &AppState) -> NavigationView {
    let is_refreshing = binding(false);

    NavigationView::new(
        text!("Activity Square"),
        scroll(vstack((
            // Pull to refresh header
            watch(is_refreshing.clone(), |refreshing| {
                if refreshing {
                    AnyView::new(hstack((spacer(), text!("Loading..."), spacer())).padding())
                } else {
                    AnyView::new(spacer_min(0.0))
                }
            }),

            // Activity list
            watch(state.activities.clone(), {
                let state = state.clone();
                move |activities| {
                    if activities.is_empty() {
                        AnyView::new(vstack((
                            spacer_min(48.0),
                            text!("No data")
                                .font(font::Title)
                                .foreground(MutedForeground),
                            spacer_min(16.0),
                            button(text!("Refresh")).action({
                                let state = state.clone();
                                move || refresh_activities(&state)
                            }),
                        )))
                    } else {
                        AnyView::new(vstack(
                            activities
                                .into_iter()
                                .map(|activity| ActivityCard::new(activity, state.clone()))
                                .collect::<Vec<_>>()
                        ))
                    }
                }
            }),
        )))
        .padding()
        .on_appear({
            let state = state.clone();
            move || refresh_activities(&state)
        }),
    )
}

/// Refresh the activity list from the server
fn refresh_activities(state: &AppState) {
    let state = state.clone();
    spawn_local(async move {
        state.is_loading.set(true);
        let api = state.api.get();
        let query = ListActivityQuery {
            user: None,
            display_all: None,
        };
        match api.list_activities(&query).await {
            Ok(activities) => {
                state.activities.set(activities);
            }
            Err(e) => {
                state.set_error(e.to_string());
            }
        }
        state.is_loading.set(false);
    });
}
