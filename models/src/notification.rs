use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotificationType {
    NewChannelMessage,
    TeacherChannelPost,
    ActivityStateChange,
    RecordStateChange,
}

/// Typed payload for channel message notifications.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelMessagePayload {
    pub channel_id: String,
    pub activity_id: String,
    pub activity_name: String,
    pub sender_name: String,
    pub message_preview: String,
}

/// Typed payload for activity state change notifications.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivityStatePayload {
    pub activity_id: String,
    pub activity_name: String,
    pub new_state: String,
}

/// Typed payload for record state change notifications.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordStatePayload {
    pub activity_id: String,
    pub activity_name: String,
    pub record_id: String,
    pub new_state: String,
}

impl NotificationType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::NewChannelMessage => "new_channel_message",
            Self::TeacherChannelPost => "teacher_channel_post",
            Self::ActivityStateChange => "activity_state_change",
            Self::RecordStateChange => "record_state_change",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "new_channel_message" => Some(Self::NewChannelMessage),
            "teacher_channel_post" => Some(Self::TeacherChannelPost),
            "activity_state_change" => Some(Self::ActivityStateChange),
            "record_state_change" => Some(Self::RecordStateChange),
            _ => None,
        }
    }

    pub const ALL: &'static [NotificationType] = &[
        Self::NewChannelMessage,
        Self::TeacherChannelPost,
        Self::ActivityStateChange,
        Self::RecordStateChange,
    ];
}
