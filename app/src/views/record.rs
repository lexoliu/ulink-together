//! User records view - displays user's activity records

use models::{FindRecordForm, RecordState};
use waterui::navigation::NavigationView;
use waterui::prelude::*;
use waterui::reactive::binding;
use waterui::task::spawn_local;
use waterui::theme::color::*;

use crate::state::AppState;

/// Records view
pub fn view(state: &AppState) -> NavigationView {
    let filter = binding(RecordFilter::All);

    NavigationView::new(
        text!("My Records"),
        vstack((
            // Filter tabs
            hstack((
                filter_button(&filter, RecordFilter::All, text!("All")),
                filter_button(&filter, RecordFilter::Todo, text!("Todo")),
                filter_button(&filter, RecordFilter::Done, text!("Done")),
            ))
            .padding(),
            // Records list
            scroll(watch(state.records.clone(), {
                let filter = filter.clone();
                move |records| {
                    let filtered: Vec<_> = records
                        .into_iter()
                        .filter(|r| match filter.get() {
                            RecordFilter::All => true,
                            RecordFilter::Todo => r.state == RecordState::Todo,
                            RecordFilter::Done => r.state == RecordState::Done,
                        })
                        .collect();

                    if filtered.is_empty() {
                        AnyView::new(vstack((
                            spacer_min(48.0),
                            text!("No records yet")
                                .font(font::Title)
                                .foreground(MutedForeground),
                        )))
                    } else {
                        AnyView::new(vstack(
                            filtered.into_iter().map(record_row).collect::<Vec<_>>(),
                        ))
                    }
                }
            })),
        ))
        .on_appear({
            let state = state.clone();
            move || refresh_records(&state)
        }),
    )
}

/// Filter enum for records
#[derive(Clone, Copy, PartialEq, Eq)]
enum RecordFilter {
    All,
    Todo,
    Done,
}

/// Creates a filter button
fn filter_button(
    current_filter: &Binding<RecordFilter>,
    filter: RecordFilter,
    label: impl View,
) -> impl View {
    let is_selected = current_filter.get() == filter;
    let current_filter = current_filter.clone();

    if is_selected {
        AnyView::new(
            button(label)
                .action(move || current_filter.set(filter))
                .foreground(Accent),
        )
    } else {
        AnyView::new(
            button(label)
                .action(move || current_filter.set(filter))
                .foreground(Foreground),
        )
    }
}

/// Record row view
fn record_row(record: models::RecordEntry) -> impl View {
    let activity_id = record.activity.to_string();
    let state = record.state;

    hstack((
        vstack((text!("{activity_id}").font(font::Subheadline),)),
        spacer(),
        state_badge(state),
    ))
    .padding()
}

/// State badge with appropriate styling
fn state_badge(state: RecordState) -> AnyView {
    match state {
        RecordState::Todo => AnyView::new(text!("Todo").font(font::Caption).foreground(Accent)),
        RecordState::Done => AnyView::new(text!("Done").font(font::Caption).foreground(Foreground)),
        RecordState::Canceled => AnyView::new(
            text!("Canceled")
                .font(font::Caption)
                .foreground(MutedForeground),
        ),
    }
}

/// Refresh records from the server
fn refresh_records(state: &AppState) {
    let state = state.clone();
    spawn_local(async move {
        state.is_loading.set(true);
        let api = state.api.get();
        let form = FindRecordForm {
            user: None,
            activity: None,
        };
        match api.find_records(&form).await {
            Ok(records) => {
                state.records.set(records);
            }
            Err(e) => {
                state.set_error(e.to_string());
            }
        }
        state.is_loading.set(false);
    });
}
