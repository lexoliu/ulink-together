use serde::{Deserialize, Serialize};

use crate::Id;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct Notification {
    pub id: Id,
    pub user: Id,
    pub title: String,
    pub content: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct CreateNotificationForm {
    pub user: Id,
    pub title: String,
    pub content: String,
}
