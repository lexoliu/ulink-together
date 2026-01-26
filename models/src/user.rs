use serde::{Deserialize, Serialize};
use crate::Id;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct User {
    pub id: Id,
    pub email: String,
    pub realname: String,
    pub gender: String,
    pub description: String,
    pub classname: String,
    pub group: Id,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct RegisterForm {
    pub email: String,
    pub realname: String,
    pub password: String,
    pub gender: String,
    pub classname: String,
}
