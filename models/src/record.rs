use crate::Id;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
#[serde(rename_all = "lowercase")]
pub enum RecordState {
    Todo,
    Done,
    Canceled,
}

impl RecordState {
    pub fn as_str(&self) -> &'static str {
        match self {
            RecordState::Todo => "todo",
            RecordState::Done => "done",
            RecordState::Canceled => "canceled",
        }
    }

    pub fn from_db(value: &str) -> Option<Self> {
        Some(match value {
            "todo" => RecordState::Todo,
            "done" => RecordState::Done,
            "canneled" | "canceled" | "cancelled" => RecordState::Canceled,
            _ => return None,
        })
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct RecordEntry {
    #[serde(rename = "id")]
    pub record_id: Id,
    pub user: Id,
    pub activity: Id,
    pub state: RecordState,
    pub activity_name: Option<String>,
    pub activity_date: Option<String>,
    pub activity_duration: Option<u16>,
    pub confirmed_minutes: u16,
    pub updated_at: String,
    pub confirmed_at: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct FindRecordForm {
    pub user: Option<Id>,
    pub activity: Option<Id>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[cfg_attr(feature = "openapi", derive(utoipa::ToSchema))]
pub struct MarkDoneCustomForm {
    pub confirmed_minutes: u16,
}
