use waterui::prelude::*;

use crate::state::AppContext;

pub fn message_view(_ctx: AppContext) -> AnyView {
    AnyView::new(card(vstack((
        text("Messaging").size(18.0),
        text("Notifications and chat will arrive in a future milestone."),
    ))))
}
