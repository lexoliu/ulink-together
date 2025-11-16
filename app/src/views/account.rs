use waterui::prelude::*;

use crate::state::{AppContext, AppRoute};

pub fn account_view(ctx: AppContext) -> AnyView {
    AnyView::new(super::require_login(ctx.clone(), move |ctx, _uid| {
        AnyView::new(menu(ctx.clone()))
    }))
}

fn menu(ctx: AppContext) -> impl View {
    let ctx_manage = ctx.clone();
    let ctx_create = ctx.clone();
    let ctx_logout = ctx.clone();

    vstack((
        button("Manage my activities")
            .action(move || ctx_manage.set_route(AppRoute::ManageActivityList)),
        button("Create a new activity")
            .action(move || ctx_create.set_route(AppRoute::CreateActivity)),
        button("Logout").action(move || ctx_logout.clone().logout()),
    ))
}
