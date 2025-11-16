use std::sync::Arc;

use ::url::Url;
use http_kit::cookie::{Cookie, CookieJar};
use serde::de::DeserializeOwned;
use thiserror::Error;
use tokio::sync::Mutex;
use zenwave::{
    self, Client, Request, Response, ResponseExt, Result as HttpResult, endpoint::WithMiddleware,
    header, middleware::Middleware,
};

use crate::models::*;

type BaseClient = zenwave::redirect::FollowRedirect<zenwave::backend::DefaultBackend>;
pub type HttpClient = WithMiddleware<BaseClient, SharedCookieStore>;

#[derive(Clone)]
pub struct ApiClient {
    base_url: Url,
    client: Arc<Mutex<HttpClient>>,
    cookies: SharedCookieStore,
}

impl ApiClient {
    pub fn new(base_url: Url) -> Self {
        let backend =
            zenwave::redirect::FollowRedirect::new(zenwave::backend::DefaultBackend::default());
        let cookies = SharedCookieStore::default();
        let client = WithMiddleware::new(backend, cookies.clone());
        Self {
            base_url,
            client: Arc::new(Mutex::new(client)),
            cookies,
        }
    }
}

#[derive(Clone, Default)]
pub struct SharedCookieStore {
    jar: Arc<Mutex<CookieJar>>,
}

impl SharedCookieStore {
    pub async fn get(&self, name: &str) -> Option<String> {
        let jar = self.jar.lock().await;
        jar.get(name).map(|cookie| cookie.value().to_string())
    }

    pub async fn clear(&self) {
        let mut jar = self.jar.lock().await;
        *jar = CookieJar::new();
    }
}

impl Middleware for SharedCookieStore {
    async fn handle(
        &mut self,
        request: &mut Request,
        mut next: impl zenwave::Endpoint,
    ) -> HttpResult<Response> {
        let cookie_header = {
            let jar = self.jar.lock().await;
            jar.iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(";")
        };

        if cookie_header.is_empty() {
            request.headers_mut().remove(header::COOKIE);
        } else {
            request.headers_mut().insert(
                header::COOKIE,
                header::HeaderValue::from_maybe_shared(cookie_header).map_err(|error| {
                    zenwave::Error::new(error, zenwave::StatusCode::BAD_REQUEST)
                })?,
            );
        }

        let response = next.respond(request).await?;

        {
            let mut jar = self.jar.lock().await;
            for set_cookie in response.headers().get_all(header::SET_COOKIE) {
                if let Ok(text) = set_cookie.to_str() {
                    if let Ok(cookie) = text.parse::<Cookie>() {
                        jar.add(cookie);
                    }
                }
            }
        }

        Ok(response)
    }
}

#[derive(Debug, Error)]
pub enum ApiError {
    #[error("request failed: {0}")]
    Transport(#[from] zenwave::Error),
    #[error("invalid api endpoint: {0}")]
    InvalidUrl(#[from] url::ParseError),
    #[error("failed to decode server response: {0}")]
    Body(String),
    #[error("server responded with an error: {0}")]
    Server(String),
}

impl ApiClient {
    pub fn base_url(&self) -> &Url {
        &self.base_url
    }

    pub async fn cookie_value(&self, name: &str) -> Option<String> {
        self.cookies.get(name).await
    }

    pub async fn clear_cookies(&self) {
        self.cookies.clear().await;
    }

    fn url(&self, path: &str) -> Result<Url, ApiError> {
        if path.starts_with("http://") || path.starts_with("https://") {
            Ok(Url::parse(path)?)
        } else {
            let normalized = path.trim_start_matches('/');
            Ok(self.base_url.join(normalized)?)
        }
    }

    fn url_with_query<'a, I>(&self, path: &str, params: I) -> Result<Url, ApiError>
    where
        I: IntoIterator<Item = (&'a str, String)>,
    {
        let mut url = self.url(path)?;
        {
            let mut serializer = url.query_pairs_mut();
            for (key, value) in params {
                serializer.append_pair(key, &value);
            }
        }
        Ok(url)
    }

    async fn parse_json<T: DeserializeOwned>(response: Response) -> Result<T, ApiError> {
        let status = response.status();
        if status.is_success() {
            response
                .into_json()
                .await
                .map_err(|error| ApiError::Body(error.to_string()))
        } else {
            let fallback = response
                .into_string()
                .await
                .map(|text| text.to_string())
                .unwrap_or_else(|error| format!("failed to decode error body: {error}"));
            Err(ApiError::Server(format!("{}: {}", status, fallback)))
        }
    }

    pub async fn login(&self, email: &str, password_hash: &str) -> Result<ApiMessage, ApiError> {
        let payload = LoginPayload {
            email: email.to_string(),
            password: password_hash.to_string(),
        };
        let url = self.url("login")?;
        let mut client = self.client.lock().await;
        let builder = client.post(url.as_str());
        let builder = builder
            .json_body(&payload)
            .map_err(|error| ApiError::Body(error.to_string()))?;
        let response = builder.await?;
        Self::parse_json(response).await
    }

    pub async fn register(&self, payload: RegisterPayload) -> Result<ApiMessage, ApiError> {
        let url = self.url("user")?;
        let mut client = self.client.lock().await;
        let builder = client.post(url.as_str());
        let builder = builder
            .json_body(&payload)
            .map_err(|error| ApiError::Body(error.to_string()))?;
        let response = builder.await?;
        Self::parse_json(response).await
    }

    pub async fn list_activities(
        &self,
        filters: &ActivityFilters,
    ) -> Result<Vec<ActivitySummary>, ApiError> {
        let mut params: Vec<(&str, String)> = Vec::new();
        if let Some(user) = &filters.user {
            params.push(("user", user.clone()));
        }
        if filters.display_all {
            params.push(("display_all", "true".into()));
        }
        let url = if params.is_empty() {
            self.url("activity")?
        } else {
            self.url_with_query("activity", params)?
        };
        let mut client = self.client.lock().await;
        let response = client.get(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn get_activity(&self, id: &str) -> Result<ActivityDetail, ApiError> {
        let url = self.url(&format!("activity/{id}"))?;
        let mut client = self.client.lock().await;
        let response = client.get(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn join_activity(&self, id: &str) -> Result<ApiMessage, ApiError> {
        let url = self.url(&format!("activity/{id}/apply"))?;
        let mut client = self.client.lock().await;
        let response = client.post(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn list_comments(&self, activity_id: &str) -> Result<Vec<Comment>, ApiError> {
        let url = self.url(&format!("activity/{activity_id}/comment"))?;
        let mut client = self.client.lock().await;
        let response = client.get(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn post_comment(
        &self,
        activity_id: &str,
        content: &str,
    ) -> Result<ApiMessage, ApiError> {
        let url = self.url(&format!("activity/{activity_id}/comment"))?;
        let mut client = self.client.lock().await;
        let builder = client.post(url.as_str());
        let builder = builder.bytes_body(content.as_bytes().to_vec());
        let response = builder.await?;
        Self::parse_json(response).await
    }

    pub async fn list_records(
        &self,
        user: &str,
        activity: Option<&str>,
    ) -> Result<Vec<Record>, ApiError> {
        let mut params = vec![("user", user.to_string())];
        if let Some(activity) = activity {
            params.push(("activity", activity.to_string()));
        }
        let url = self.url_with_query("record", params)?;
        let mut client = self.client.lock().await;
        let response = client.get(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn mark_record_done(&self, record_id: &str) -> Result<ApiMessage, ApiError> {
        let url = self.url(&format!("record/{record_id}/done"))?;
        let mut client = self.client.lock().await;
        let response = client.post(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn create_activity(
        &self,
        payload: CreateActivityPayload,
    ) -> Result<ActivityCreatedResponse, ApiError> {
        let url = self.url("activity")?;
        let mut client = self.client.lock().await;
        let builder = client.post(url.as_str());
        let builder = builder
            .json_body(&payload)
            .map_err(|error| ApiError::Body(error.to_string()))?;
        let response = builder.await?;
        Self::parse_json(response).await
    }

    pub async fn get_user(&self, id: &str) -> Result<UserProfile, ApiError> {
        let url = self.url(&format!("user/{id}"))?;
        let mut client = self.client.lock().await;
        let response = client.get(url.as_str()).await?;
        Self::parse_json(response).await
    }

    pub async fn fetch_volunteer_roster(
        &self,
        activity_id: &str,
        volunteers: &[String],
    ) -> Result<Vec<VolunteerRosterEntry>, ApiError> {
        use futures::future::try_join_all;

        let futures = volunteers.iter().map(|uid| {
            let api = self.clone();
            let uid = uid.clone();
            let activity_id = activity_id.to_string();
            async move {
                let user = api.get_user(&uid).await?;
                let records = api.list_records(&uid, Some(&activity_id)).await?;
                let record = records.into_iter().next().ok_or_else(|| {
                    ApiError::Server(format!("no record found for volunteer {uid}"))
                })?;
                Ok(VolunteerRosterEntry { user, record })
            }
        });

        try_join_all(futures).await
    }
}
