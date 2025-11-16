use futures::future::try_join_all;
use waterui::prelude::*;
use waterui::widget::suspense::Suspense;

use crate::api::ApiError;
use crate::models::{ActivityDetail, Record};
use crate::state::AppContext;

pub fn record_view(ctx: AppContext) -> AnyView {
    AnyView::new(super::require_login(ctx.clone(), move |ctx, uid| {
        AnyView::new(Suspense::new(load_records(ctx, uid)))
    }))
}

async fn load_records(ctx: AppContext, uid: String) -> AnyView {
    match ctx.api().list_records(&uid, None).await {
        Ok(records) if records.is_empty() => {
            AnyView::new(text("No records yet. Join an activity!"))
        }
        Ok(records) => match enrich_records(ctx.clone(), records).await {
            Ok(entries) => AnyView::new(render_entries(ctx, entries)),
            Err(err) => error_view(err),
        },
        Err(err) => error_view(err),
    }
}

async fn enrich_records(
    ctx: AppContext,
    records: Vec<Record>,
) -> Result<Vec<(Record, ActivityDetail)>, ApiError> {
    let tasks = records.into_iter().map(|record| {
        let api = ctx.api();
        let id = record.activity.clone();
        async move {
            let activity = api.get_activity(&id).await?;
            Ok::<_, ApiError>((record, activity))
        }
    });
    try_join_all(tasks).await
}

fn render_entries(ctx: AppContext, entries: Vec<(Record, ActivityDetail)>) -> AnyView {
    let cards: VStack<_> = entries
        .into_iter()
        .map(|(record, activity)| record_card(ctx.clone(), record, activity))
        .collect();
    AnyView::new(scroll(cards))
}

fn record_card(ctx: AppContext, record: Record, activity: ActivityDetail) -> AnyView {
    let record_state = format!("State: {:?}", record.state);
    AnyView::new(
        card(vstack((
            text(activity.name).size(18.0),
            text(activity.location),
            text(activity.description),
            text(record_state),
            button("Open activity").action(move || ctx.open_activity(record.activity.clone())),
        )))
        .padding_with(EdgeInsets::symmetric(6.0, 0.0)),
    )
}

fn error_view(error: impl ToString) -> AnyView {
    AnyView::new(card(text(error.to_string())).padding_with(EdgeInsets::all(12.0)))
}
