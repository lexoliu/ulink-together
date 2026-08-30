use crate::Id;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct CommentResponse {
    pub id: Id,
    pub author: Id,
    pub author_name: String,
    pub content: String,
    pub date: String,
}
