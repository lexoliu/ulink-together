//! API module for communicating with the Together server

use models::{
    ActivityDetail, ActivitySummary, CreateActivityForm, FindRecordForm, ListActivityQuery,
    RecordEntry, RegisterForm, User,
};
use zenwave::Client;

/// API client for the Together server
#[derive(Clone)]
pub struct Api {
    base_url: String,
    _token: Option<String>,
}

#[allow(dead_code)]
impl Api {
    /// Creates a new API client
    pub fn new(base_url: impl Into<String>) -> Self {
        Self {
            base_url: base_url.into(),
            _token: None,
        }
    }

    /// Sets the authentication token (cookie) for subsequent requests
    pub fn set_token(&mut self, token: &str) {
        self._token = Some(token.to_string());
    }

    /// Clears the authentication token
    pub fn clear_token(&mut self) {
        self._token = None;
    }

    // Authentication endpoints

    /// Login with email and password
    pub async fn login(&self, email: &str, password: &str) -> Result<String, ApiError> {
        let url = format!("{}/login", self.base_url);
        let form = LoginForm { email, password };

        let mut client = zenwave::client();
        let req = client.post(&url).json_body(&form);

        let response = req.await.map_err(ApiError::Network)?;

        if !response.status().is_success() {
            let status = response.status();
            let msg: ApiMessage = response
                .into_body()
                .into_json()
                .await
                .unwrap_or(ApiMessage {
                    message: "Unknown error".to_string(),
                });
            return Err(ApiError::Server {
                status: status.as_u16(),
                message: msg.message,
            });
        }

        // Extract cookies
        let cookies: Vec<String> = response
            .headers()
            .get_all("set-cookie")
            .iter()
            .filter_map(|v| v.to_str().ok().map(|s| s.to_string()))
            .collect();

        if cookies.is_empty() {
            return Err(ApiError::Parse("No session cookie received".to_string()));
        }

        // Join all cookies
        let cookie_str = cookies.join("; ");
        Ok(cookie_str)
    }

    /// Register a new user
    pub async fn register(&self, form: &RegisterForm) -> Result<(), ApiError> {
        let url = format!("{}/user", self.base_url);
        let mut client = zenwave::client();
        let req = client.post(&url);
        // No auth needed for register usually?
        // Code didn't add it.

        let response = req.json_body(form).await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    // Activity endpoints

    /// List activities with optional filters
    pub async fn list_activities(
        &self,
        query: &ListActivityQuery,
    ) -> Result<Vec<ActivitySummary>, ApiError> {
        let mut path = "/activity".to_string();

        // Add query parameters
        let mut params = Vec::new();
        if let Some(ref user) = query.user {
            params.push(format!("user={}", user));
        }
        if let Some(ref display_all) = query.display_all {
            params.push(format!("display_all={}", display_all));
        }
        if !params.is_empty() {
            path = format!("{}?{}", path, params.join("&"));
        }

        let url = format!("{}{}", self.base_url, path);
        let mut client = zenwave::client();
        let mut req = client.get(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req.await.map_err(ApiError::Network)?;
        parse_response(response).await
    }

    /// Get activity details by ID
    pub async fn get_activity(&self, id: &str) -> Result<ActivityDetail, ApiError> {
        let url = format!("{}/activity/{}", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.get(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req.await.map_err(ApiError::Network)?;
        parse_response(response).await
    }

    /// Create a new activity
    pub async fn create_activity(&self, form: &CreateActivityForm) -> Result<(), ApiError> {
        let url = format!("{}/activity", self.base_url);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req.json_body(form).await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Join an activity
    pub async fn join_activity(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}/apply", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Delete an activity
    pub async fn delete_activity(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.delete(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Change activity state to NeedVolunteer
    pub async fn turn_need_volunteer(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}/need_volunteer", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Change activity state to Going
    pub async fn turn_going(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}/go", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Change activity state to Ended
    pub async fn turn_ended(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}/end", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Change activity state to Canceled
    pub async fn turn_canceled(&self, id: &str) -> Result<(), ApiError> {
        let url = format!("{}/activity/{}/cancel", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    // Record endpoints

    /// Find records with filters
    pub async fn find_records(&self, form: &FindRecordForm) -> Result<Vec<RecordEntry>, ApiError> {
        let mut params = Vec::new();
        if let Some(ref user) = form.user {
            params.push(format!("user={}", user));
        }
        if let Some(ref activity) = form.activity {
            params.push(format!("activity={}", activity));
        }
        let body = params.join("&");

        let url = format!("{}/record", self.base_url);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }

        let response = req
            .header("Content-Type", "application/x-www-form-urlencoded")
            .bytes_body(body.into_bytes())
            .await
            .map_err(ApiError::Network)?;
        parse_response(response).await
    }

    /// Confirm a record
    pub async fn confirm_record(&self, record_id: &str) -> Result<(), ApiError> {
        let url = format!("{}/record/{}/confirm", self.base_url, record_id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Approve a volunteer application
    pub async fn approve_record(&self, record_id: &str) -> Result<(), ApiError> {
        let url = format!("{}/record/{}/approve", self.base_url, record_id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Cancel a volunteer application or participation
    pub async fn cancel_record(&self, record_id: &str) -> Result<(), ApiError> {
        let url = format!("{}/record/{}/cancel", self.base_url, record_id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    /// Cancel a record (volunteer leaves activity)
    pub async fn cancel_record(&self, record_id: &str) -> Result<(), ApiError> {
        // Endpoint doesn't exist on server, returning error for now
        let url = format!("{}/record/{}/cancel", self.base_url, record_id);
        let mut client = zenwave::client();
        let mut req = client.post(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_empty_response(response).await
    }

    // User endpoints

    /// Get user by ID
    pub async fn get_user(&self, id: &str) -> Result<User, ApiError> {
        let url = format!("{}/user/{}", self.base_url, id);
        let mut client = zenwave::client();
        let mut req = client.get(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_response(response).await
    }

    /// Get current user
    pub async fn get_current_user(&self) -> Result<User, ApiError> {
        let url = format!("{}/user/me", self.base_url);
        let mut client = zenwave::client();
        let mut req = client.get(&url);
        if let Some(token) = &self._token {
            req = req.header("Cookie", token);
        }
        let response = req.await.map_err(ApiError::Network)?;
        parse_response(response).await
    }
}

#[derive(serde::Serialize)]
struct LoginForm<'a> {
    email: &'a str,
    password: &'a str,
}

/// API error types
#[derive(Debug)]
pub enum ApiError {
    /// Network or HTTP error
    Network(zenwave::Error),
    /// Server returned an error response
    Server { status: u16, message: String },
    /// Failed to parse response
    Parse(String),
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ApiError::Network(e) => write!(f, "Network error: {}", e),
            ApiError::Server { status, message } => {
                write!(f, "Server error {}: {}", status, message)
            }
            ApiError::Parse(msg) => write!(f, "Parse error: {}", msg),
        }
    }
}

/// API message response from server
#[derive(serde::Deserialize)]
struct ApiMessage {
    message: String,
}

/// Parse JSON response
async fn parse_response<T: serde::de::DeserializeOwned>(
    response: zenwave::Response,
) -> Result<T, ApiError> {
    let status = response.status();
    if status.is_success() {
        response
            .into_body()
            .into_json()
            .await
            .map_err(|e| ApiError::Parse(e.to_string()))
    } else {
        let msg: ApiMessage = response
            .into_body()
            .into_json()
            .await
            .unwrap_or(ApiMessage {
                message: "Unknown error".to_string(),
            });
        Err(ApiError::Server {
            status: status.as_u16(),
            message: msg.message,
        })
    }
}

/// Parse response that returns no body on success
async fn parse_empty_response(response: zenwave::Response) -> Result<(), ApiError> {
    let status = response.status();
    if status.is_success() {
        Ok(())
    } else {
        let msg: ApiMessage = response
            .into_body()
            .into_json()
            .await
            .unwrap_or(ApiMessage {
                message: "Unknown error".to_string(),
            });
        Err(ApiError::Server {
            status: status.as_u16(),
            message: msg.message,
        })
    }
}
