use std::sync::Arc;

use ::url::Url;
use waterui::{prelude::*, task::spawn_local};

use crate::api::ApiClient;

#[derive(Clone)]
pub struct AppContext {
    inner: Arc<AppStateInner>,
}

struct AppStateInner {
    api: ApiClient,
    route: Binding<AppRoute>,
    tab: Binding<MainTab>,
    session: Binding<SessionState>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MainTab {
    Square,
    Record,
    Message,
    Account,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppRoute {
    Auth(AuthScreen),
    Square,
    Record,
    Message,
    Account,
    ViewActivity { id: String },
    ManageActivityList,
    ManageActivity { id: String },
    CreateActivity,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthScreen {
    Login,
    Register,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthStatus {
    LoggedOut,
    Loading,
    Ready,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionState {
    pub status: AuthStatus,
    pub uid: Option<String>,
}

impl Default for SessionState {
    fn default() -> Self {
        Self {
            status: AuthStatus::LoggedOut,
            uid: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub base_url: Url,
}

impl AppConfig {
    pub fn from_env() -> Self {
        let raw = std::env::var("ULINK_API_BASE")
            .unwrap_or_else(|_| "http://localhost:8080/api/v1/".into());
        let mut base = Url::parse(&raw).expect("invalid ULINK_API_BASE url");
        if !base.path().ends_with('/') {
            let mut path = base.path().to_string();
            path.push('/');
            base.set_path(&path);
        }
        Self { base_url: base }
    }
}

impl AppContext {
    pub fn new(config: AppConfig) -> Self {
        let api = ApiClient::new(config.base_url);
        let inner = AppStateInner {
            api,
            route: Binding::container(AppRoute::Auth(AuthScreen::Login)),
            tab: Binding::container(MainTab::Square),
            session: Binding::container(SessionState::default()),
        };
        Self {
            inner: Arc::new(inner),
        }
    }

    pub fn api(&self) -> ApiClient {
        self.inner.api.clone()
    }

    pub fn route(&self) -> Binding<AppRoute> {
        self.inner.route.clone()
    }

    pub fn tab(&self) -> Binding<MainTab> {
        self.inner.tab.clone()
    }

    pub fn session(&self) -> Binding<SessionState> {
        self.inner.session.clone()
    }

    pub fn set_route(&self, route: AppRoute) {
        self.inner.route.set(route);
    }

    pub fn switch_tab(&self, tab: MainTab) {
        self.inner.tab.set(tab);
        let route = match tab {
            MainTab::Square => AppRoute::Square,
            MainTab::Record => AppRoute::Record,
            MainTab::Message => AppRoute::Message,
            MainTab::Account => AppRoute::Account,
        };
        self.set_route(route);
    }

    pub fn open_activity(&self, id: impl Into<String>) {
        self.set_route(AppRoute::ViewActivity { id: id.into() });
    }

    pub fn open_manage_activity(&self, id: impl Into<String>) {
        self.set_route(AppRoute::ManageActivity { id: id.into() });
    }

    pub async fn refresh_session(&self) {
        self.inner.session.set(SessionState {
            status: AuthStatus::Loading,
            uid: None,
        });
        let uid = self.inner.api.cookie_value("uid").await;
        let status = if uid.is_some() {
            AuthStatus::Ready
        } else {
            AuthStatus::LoggedOut
        };
        self.inner.session.set(SessionState { status, uid });
    }

    pub fn logout(&self) {
        let api = self.inner.api.clone();
        spawn_local(async move {
            api.clear_cookies().await;
        });
        self.inner.session.set(SessionState::default());
        self.set_route(AppRoute::Auth(AuthScreen::Login));
    }
}
