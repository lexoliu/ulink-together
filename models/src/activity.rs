use serde::{Deserialize, Serialize};

use crate::{Id, record::RecordState};

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
#[serde(rename_all = "snake_case")]
pub enum ActivityState {
    Going,
    NeedVolunteer,
    Ended,
    Canceled,
}

impl ActivityState {
    pub fn as_str(self) -> &'static str {
        match self {
            ActivityState::Going => "going",
            ActivityState::NeedVolunteer => "need_volunteer",
            ActivityState::Ended => "ended",
            ActivityState::Canceled => "canceled",
        }
    }

    pub fn from_db(value: &str) -> Option<Self> {
        Some(match value {
            "going" => ActivityState::Going,
            "need_volunteer" => ActivityState::NeedVolunteer,
            "ended" => ActivityState::Ended,
            "canneled" | "canceled" | "cancelled" => ActivityState::Canceled,
            _ => return None,
        })
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct ActivitySummary {
    #[cfg_attr(feature = "openapi", schema(value_type = String))]
    pub id: Id,
    pub name: String,
    pub location: String,
    pub volunteer_num: u16,
    pub max_volunteer_num: Option<u16>,
    #[cfg_attr(feature = "openapi", schema(value_type = String))]
    pub promoter: Id,
    pub promoter_name: String,
    pub date: Option<String>,
    pub brief_description: String,
    pub duration: u16,
    pub state: ActivityState,
    pub viewer_participating: bool,
    pub viewer_record_state: Option<RecordState>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct ActivityDetail {
    pub id: Id,
    pub name: String,
    pub location: String,
    pub volunteer_num: u16,
    pub max_volunteer_num: Option<u16>,
    pub promoter: Id,
    pub promoter_name: String,
    pub date: Option<String>,
    pub description: String,
    pub volunteers: Vec<Id>,
    pub duration: u16,
    pub state: ActivityState,
    pub viewer_participating: bool,
    pub viewer_record_state: Option<RecordState>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct CreateActivityForm {
    pub name: String,
    pub date: Option<String>,
    pub max_volunteer_num: Option<u16>,
    pub description: String,
    pub location: String,
    pub brief_description: String,
    pub duration: u16,
}

#[derive(Debug, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct ListActivityQuery {
    #[cfg_attr(feature = "openapi", schema(value_type = String, nullable))]
    pub user: Option<Id>,
    pub display_all: Option<String>,
}
