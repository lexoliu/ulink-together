//! Application state management

use models::{ActivitySummary, RecordEntry, User};
use waterui::reactive::{Binding, Computed, SignalExt};
use crate::api::Api;

/// Global application state
#[derive(Clone)]
pub struct AppState {
    /// API client
    pub api: Binding<Api>,
    /// Current user (if logged in)
    pub current_user: Binding<Option<User>>,
    /// JWT token
    pub token: Binding<Option<String>>,
    /// Whether user is logged in
    pub is_logged_in: Computed<bool>,
    /// Loading state
    pub is_loading: Binding<bool>,
    /// Error message to display
    pub error_message: Binding<Option<String>>,
    /// Cached activity list
    pub activities: Binding<Vec<ActivitySummary>>,
    /// Cached user records
    pub records: Binding<Vec<RecordEntry>>,
}

impl AppState {
    /// Creates a new application state
    pub fn new() -> Self {
        let token: Binding<Option<String>> = Binding::container(None);
        let is_logged_in = token.clone().map(|t| t.is_some()).computed();

        Self {
            api: Binding::container(Api::new("http://127.0.0.1:8080/api/v1")),
            current_user: Binding::container(None),
            token,
            is_logged_in,
            is_loading: Binding::container(false),
            error_message: Binding::container(None),
            activities: Binding::container(Vec::new()),
            records: Binding::container(Vec::new()),
        }
    }

    /// Sets the authentication token and updates the API client
    pub fn set_token(&self, token: String) {
        let mut api = self.api.get();
        api.set_token(&token);
        self.api.set(api);
        self.token.set(Some(token));
    }

    /// Clears authentication state
    pub fn logout(&self) {
        let mut api = self.api.get();
        api.clear_token();
        self.api.set(api);
        self.token.set(None);
        self.current_user.set(None);
        self.activities.set(Vec::new());
        self.records.set(Vec::new());
    }

    /// Sets an error message to display
    pub fn set_error(&self, message: impl Into<String>) {
        self.error_message.set(Some(message.into()));
    }

    /// Clears the current error message
    pub fn clear_error(&self) {
        self.error_message.set(None);
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
