use waterui::prelude::*;
use waterui::widget::suspense::Suspense;

use crate::models::{ActivityFilters, ActivitySummary};
use crate::state::AppContext;

pub fn square_view(ctx: AppContext) -> AnyView {
    AnyView::new(Suspense::new(load_feed(ctx.clone())))
}

async fn load_feed(ctx: AppContext) -> AnyView {
    let filters = ActivityFilters {
        user: None,
        display_all: false,
    };
    match ctx.api().list_activities(&filters).await {
        Ok(data) => render_list(ctx, data),
        Err(err) => error_view(err.to_string()),
    }
}

fn render_list(ctx: AppContext, activities: Vec<ActivitySummary>) -> AnyView {
    if activities.is_empty() {
        AnyView::new(text("No activities available. Try creating one!"))
    } else {
        let cards: VStack<_> = activities
            .into_iter()
            .map(|activity| activity_card(ctx.clone(), activity))
            .collect();
        AnyView::new(scroll(cards))
    }
}

fn error_view(message: String) -> AnyView {
    AnyView::new(card(text(message)).padding_with(EdgeInsets::all(12.0)))
}

fn activity_card(ctx: AppContext, activity: ActivitySummary) -> impl View {
    let id = activity.id.clone();
    card(vstack((
        text(activity.name).size(18.0),
        text(activity.location),
        text(activity.brief_description),
        hstack((
            text(format!("{} volunteers", activity.volunteer_num)),
            text(
                activity
                    .max_volunteer_num
                    .map(|max| format!(" / {max}"))
                    .unwrap_or_else(|| " / open".into()),
            ),
        ))
        .spacing(8.0),
        button("View").action(move || ctx.open_activity(id.clone())),
    )))
    .padding_with(EdgeInsets::symmetric(8.0, 0.0))
}
