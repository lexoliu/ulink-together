//! Manage activities view - for promoters to manage their activities

use models::{
    ActivityState, ActivitySummary, FindRecordForm, ListActivityQuery, RecordEntry, RecordState,
};
use waterui::navigation::{NavigationLink, NavigationView};
use waterui::prelude::*;
use waterui::reactive::binding;
use waterui::task::spawn_local;
use waterui::theme::color::*;

use crate::components::activity_card::card_content;
use crate::state::AppState;

/// Manage activities view
pub fn view(state: &AppState) -> NavigationView {
    let activities = binding(Vec::<ActivitySummary>::new());
    let is_loading = binding(false);

    NavigationView::new(
        text!("My Activities"),
        scroll(vstack((
            watch(is_loading.clone(), |loading| {
                if loading {
                    AnyView::new(hstack((spacer(), text!("Loading..."), spacer())).padding())
                } else {
                    AnyView::new(spacer_min(0.0))
                }
            }),
            watch(activities.clone(), {
                let state = state.clone();
                move |list: Vec<ActivitySummary>| {
                    if list.is_empty() {
                        AnyView::new(
                            vstack((
                                spacer_min(48.0),
                                text!("You haven't created any activities yet")
                                    .font(font::Body)
                                    .foreground(MutedForeground),
                            ))
                            .padding(),
                        )
                    } else {
                        AnyView::new(vstack(
                            list.into_iter()
                                .map(|activity: ActivitySummary| {
                                    NavigationLink::new(card_content(activity.clone()), {
                                        let state = state.clone();
                                        let activity = activity.clone();
                                        move || manage_detail_view(activity.clone(), &state)
                                    })
                                })
                                .collect::<Vec<_>>(),
                        ))
                    }
                }
            }),
        )))
        .on_appear({
            let state = state.clone();
            let activities = activities.clone();
            let is_loading = is_loading.clone();
            move || load_my_activities(&state, activities.clone(), is_loading.clone())
        }),
    )
}

fn load_my_activities(
    state: &AppState,
    activities: Binding<Vec<ActivitySummary>>,
    is_loading: Binding<bool>,
) {
    let state = state.clone();
    spawn_local(async move {
        let user_id = if let Some(user) = state.current_user.get() {
            user.id.clone()
        } else {
            return;
        };

        is_loading.set(true);
        let api = state.api.get();
        let query = ListActivityQuery {
            user: Some(user_id),
            display_all: Some("true".to_string()), // Show all states
        };
        match api.list_activities(&query).await {
            Ok(list) => activities.set(list),
            Err(e) => state.set_error(e.to_string()),
        }
        is_loading.set(false);
    });
}

/// Detail view for managing a specific activity
fn manage_detail_view(activity: ActivitySummary, state: &AppState) -> NavigationView {
    let records = binding(Vec::<RecordEntry>::new());
    let activity_binding = binding(activity.clone());

    NavigationView::new(
        text!("Manage Activity"),
        scroll(
            vstack((
                // Header
                watch(activity_binding.clone(), |act: ActivitySummary| {
                    vstack((
                        text(act.name.clone()).font(font::Headline),
                        state_badge(act.state),
                    ))
                }),
                Divider,
                // State Controls
                state_controls(&activity_binding, state),
                Divider,
                // Volunteers
                volunteer_list(&activity_binding, records.clone(), state),
                spacer_min(32.0),
            ))
            .padding(),
        )
        .on_appear({
            let state = state.clone();
            let activity_id = activity.id.clone();
            let records = records.clone();
            move || load_volunteers(&state, &activity_id, records.clone())
        }),
    )
}

fn load_volunteers(state: &AppState, activity_id: &models::Id, records: Binding<Vec<RecordEntry>>) {
    let state = state.clone();
    let activity_id = activity_id.clone();
    spawn_local(async move {
        let api = state.api.get();
        let form = FindRecordForm {
            activity: Some(activity_id),
            user: None,
        };
        match api.find_records(&form).await {
            Ok(list) => records.set(list),
            Err(e) => state.set_error(e.to_string()),
        }
    });
}

fn state_controls(activity: &Binding<ActivitySummary>, state: &AppState) -> impl View {
    let activity = activity.clone();
    let state = state.clone();

    watch(activity.clone(), move |act: ActivitySummary| {
        let state = state.clone();
        let activity = activity.clone();
        let current_state = act.state;
        let id = act.id.clone();

        vstack((
            text("Change State")
                .font(font::Subheadline)
                .foreground(MutedForeground),
            hstack((
                if current_state != ActivityState::NeedVolunteer {
                    AnyView::new(button(text!("Start Recruiting")).action({
                        let state = state.clone();
                        let activity = activity.clone();
                        let id = id.clone();
                        move || {
                            change_state(
                                &state,
                                &activity,
                                &id,
                                |api, id| async move { api.turn_need_volunteer(&id).await },
                                ActivityState::NeedVolunteer,
                            )
                        }
                    }))
                } else {
                    AnyView::new(spacer_min(0.0))
                },
                if current_state != ActivityState::Going {
                    AnyView::new(button(text!("Start Activity")).action({
                        let state = state.clone();
                        let activity = activity.clone();
                        let id = id.clone();
                        move || {
                            change_state(
                                &state,
                                &activity,
                                &id,
                                |api, id| async move { api.turn_going(&id).await },
                                ActivityState::Going,
                            )
                        }
                    }))
                } else {
                    AnyView::new(spacer_min(0.0))
                },
                if current_state != ActivityState::Ended {
                    AnyView::new(button(text!("End Activity")).action({
                        let state = state.clone();
                        let activity = activity.clone();
                        let id = id.clone();
                        move || {
                            change_state(
                                &state,
                                &activity,
                                &id,
                                |api, id| async move { api.turn_ended(&id).await },
                                ActivityState::Ended,
                            )
                        }
                    }))
                } else {
                    AnyView::new(spacer_min(0.0))
                },
                if current_state != ActivityState::Canceled {
                    AnyView::new(
                        button(text!("Cancel"))
                            .action({
                                let state = state.clone();
                                let activity = activity.clone();
                                let id = id.clone();
                                move || {
                                    change_state(
                                        &state,
                                        &activity,
                                        &id,
                                        |api, id| async move { api.turn_canceled(&id).await },
                                        ActivityState::Canceled,
                                    )
                                }
                            })
                            .foreground(Color::srgb(255, 100, 100)),
                    )
                } else {
                    AnyView::new(spacer_min(0.0))
                },
            )),
        ))
    })
}

fn change_state<F, Fut>(
    state: &AppState,
    activity: &Binding<ActivitySummary>,
    id: &models::Id,
    f: F,
    new_state: ActivityState,
) where
    F: FnOnce(crate::api::Api, String) -> Fut + Clone + 'static,
    Fut: std::future::Future<Output = Result<(), crate::api::ApiError>> + 'static,
{
    let state = state.clone();
    let activity = activity.clone();
    let id_str = id.to_string();

    spawn_local(async move {
        let api = state.api.get();
        match f(api, id_str).await {
            Ok(_) => {
                let mut act = activity.get();
                act.state = new_state;
                activity.set(act);
            }
            Err(e) => state.set_error(e.to_string()),
        }
    });
}

fn volunteer_list(
    activity: &Binding<ActivitySummary>,
    records: Binding<Vec<RecordEntry>>,
    state: &AppState,
) -> impl View {
    let state = state.clone();
    let activity_id = activity.get().id;
    let records_binding = records.clone(); // Clone to pass to closures

    vstack((
        text("Volunteers")
            .font(font::Subheadline)
            .foreground(MutedForeground),
        watch(records.clone(), {
            let state = state.clone();
            let records_binding = records_binding.clone();
            move |list: Vec<RecordEntry>| {
                if list.is_empty() {
                    AnyView::new(text!("No volunteers yet"))
                } else {
                    AnyView::new(vstack(
                        list.into_iter()
                            .map(|record| {
                                let record = record.clone();
                                let state = state.clone();
                                let records_binding = records_binding.clone();
                                let activity_id = activity_id.clone();
                                volunteer_row(record, state, activity_id, records_binding)
                            })
                            .collect::<Vec<_>>(),
                    ))
                }
            }
        }),
    ))
}

fn volunteer_row(
    record: RecordEntry,
    state: AppState,
    activity_id: models::Id,
    records_binding: Binding<Vec<RecordEntry>>,
) -> impl View {
    let user_id = record.user.to_string();
    let record_id = record.record_id.to_string();
    let status = record.state;
    // let state = state.clone(); // No longer needed as we took ownership
    // let activity_id = activity_id.clone(); // No longer needed as we took ownership

    hstack((
        text(format!(
            "User: {}",
            user_id.chars().take(8).collect::<String>()
        )), // Truncate ID
        spacer(),
        state_badge_record(status),
        if status == RecordState::Todo {
            AnyView::new(hstack((
                button(text!("Approve")).action({
                    let state = state.clone();
                    let record_id = record_id.clone();
                    let activity_id = activity_id.clone();
                    let records_binding = records_binding.clone();
                    move || {
                        update_record(
                            &state,
                            &record_id,
                            &activity_id,
                            records_binding.clone(),
                            true,
                        )
                    }
                }),
                button(text!("Reject"))
                    .action({
                        let state = state.clone();
                        let record_id = record_id.clone();
                        let activity_id = activity_id.clone();
                        let records_binding = records_binding.clone();
                        move || {
                            update_record(
                                &state,
                                &record_id,
                                &activity_id,
                                records_binding.clone(),
                                false,
                            )
                        }
                    })
                    .foreground(Color::srgb(255, 100, 100)),
            )))
        } else {
            AnyView::new(spacer_min(0.0))
        },
    ))
    .padding()
}

fn update_record(
    state: &AppState,
    record_id: &str,
    activity_id: &models::Id,
    records_binding: Binding<Vec<RecordEntry>>,
    approve: bool,
) {
    let state = state.clone();
    let record_id = record_id.to_string();
    let activity_id = activity_id.clone();

    spawn_local(async move {
        let api = state.api.get();
        let res = if approve {
            api.approve_apply(&record_id).await
        } else {
            api.disapprove_apply(&record_id).await
        };

        match res {
            Ok(_) => {
                // Refresh list
                load_volunteers(&state, &activity_id, records_binding);
            }
            Err(e) => state.set_error(e.to_string()),
        }
    });
}

fn state_badge(state: ActivityState) -> impl View {
    match state {
        ActivityState::Going => AnyView::new(text!("Going").foreground(Foreground)),
        ActivityState::NeedVolunteer => AnyView::new(text!("Recruiting").foreground(Accent)),
        ActivityState::Ended => AnyView::new(text!("Ended").foreground(MutedForeground)),
        ActivityState::Canceled => {
            AnyView::new(text!("Canceled").foreground(Color::srgb(255, 100, 100)))
        }
    }
}

fn state_badge_record(state: RecordState) -> impl View {
    match state {
        RecordState::Todo => AnyView::new(text!("Pending").foreground(Accent)),
        RecordState::Done => AnyView::new(text!("Approved").foreground(Foreground)),
        RecordState::Canceled => AnyView::new(text!("Rejected").foreground(MutedForeground)),
    }
}
