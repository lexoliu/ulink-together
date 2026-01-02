use serde::{Deserialize, Serialize};
use crate::Id;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct CommentResponse {
    pub id: Id,
    pub author: Id,
    pub author_name: String,
    pub content: String,
    pub date: String,
}
