use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize)]
pub struct ActivitySummary {
    #[serde(rename(deserialize = "_id"))]
    pub id: String,
    pub name: String,
    pub location: String,
    pub volunteer_num: u16,
    pub max_volunteer_num: Option<u16>,
    pub promoter: String,
    #[serde(default)]
    pub promoter_name: String,
    #[serde(default)]
    pub date: Option<String>,
    pub brief_description: String,
    pub duration: u16,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ActivityDetail {
    pub state: ActivityState,
    pub name: String,
    pub location: String,
    pub volunteer_num: u16,
    pub max_volunteer_num: Option<u16>,
    pub promoter: String,
    #[serde(default)]
    pub promoter_name: String,
    #[serde(default)]
    pub date: Option<String>,
    pub description: String,
    #[serde(default)]
    pub volunteers: Vec<String>,
    pub duration: u16,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ActivityState {
    Going,
    NeedVolunteer,
    Ended,
    Canneled,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Comment {
    #[serde(rename(deserialize = "_id"))]
    pub id: String,
    pub author: String,
    #[serde(default)]
    pub author_name: String,
    pub content: String,
    pub date: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Record {
    #[serde(rename(deserialize = "_id"))]
    pub id: String,
    pub user: String,
    pub activity: String,
    pub state: RecordState,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum RecordState {
    Todo,
    Done,
    Canneled,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ApiMessage {
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LoginPayload {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RegisterPayload {
    pub email: String,
    pub realname: String,
    pub classname: String,
    pub gender: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateActivityPayload {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_volunteer_num: Option<u16>,
    pub description: String,
    pub location: String,
    pub brief_description: String,
    pub duration: u16,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ActivityCreatedResponse {
    pub message: String,
    #[serde(default)]
    pub activity_id: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UserProfile {
    pub email: String,
    pub realname: String,
    pub gender: String,
    pub description: String,
    pub classname: String,
    pub group: String,
}

#[derive(Debug, Clone)]
pub struct VolunteerRosterEntry {
    pub user: UserProfile,
    pub record: Record,
}

#[derive(Debug, Clone, Default)]
pub struct ActivityFilters {
    pub user: Option<String>,
    pub display_all: bool,
}
