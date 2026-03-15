use std::{collections::HashMap, mem, sync::Arc};

use async_std::sync::RwLock;
use serde::Serialize;
use skyzen::{
    responder::{sse::Event, sse::Sender, Sse},
    utils::State,
};
use tracing::error;

use crate::{
    auth::{AuthError, AuthSession},
    utils::Id,
};

#[derive(Debug, Clone)]
pub struct PushHub {
    inner: Arc<PushHubInner>,
}

#[derive(Debug)]
struct PushHubInner {
    senders: RwLock<HashMap<Id, Vec<Sender>>>,
}

impl PushHub {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(PushHubInner {
                senders: RwLock::new(HashMap::new()),
            }),
        }
    }

    pub async fn subscribe(&self, user: Id) -> Sse {
        let (sender, sse) = Sse::channel();
        let mut senders = self.inner.senders.write().await;
        senders.entry(user).or_default().push(sender);
        sse
    }

    pub async fn send_json_to_user<T: Serialize>(&self, user: Id, event: &str, payload: &T) {
        let data = match serde_json::to_string(payload) {
            Ok(data) => data,
            Err(err) => {
                error!(error = %err, "Failed to serialize push payload");
                return;
            }
        };
        self.send_data_to_user(user, event, &data).await;
    }

    pub async fn send_json_to_users<T: Serialize>(
        &self,
        users: impl IntoIterator<Item = Id>,
        event: &str,
        payload: &T,
    ) {
        let data = match serde_json::to_string(payload) {
            Ok(data) => data,
            Err(err) => {
                error!(error = %err, "Failed to serialize push payload");
                return;
            }
        };
        for user in users {
            self.send_data_to_user(user, event, &data).await;
        }
    }

    async fn send_data_to_user(&self, user: Id, event: &str, data: &str) {
        let mut senders = {
            let mut map = self.inner.senders.write().await;
            map.get_mut(&user).map(mem::take).unwrap_or_default()
        };

        if senders.is_empty() {
            return;
        }

        let mut alive = Vec::with_capacity(senders.len());
        for sender in senders.drain(..) {
            let event = Event::data(data).event(event);
            if sender.send(event).await.is_ok() {
                alive.push(sender);
            }
        }

        if !alive.is_empty() {
            let mut map = self.inner.senders.write().await;
            map.entry(user).or_default().extend(alive);
        }
    }
}

#[derive(Debug, serde::Serialize)]
pub struct MessagePush {
    pub id: Id,
    pub channel: Id,
    pub sender: Id,
    pub content: String,
    pub datetime: String,
}

pub async fn handler(session: AuthSession, hub: State<PushHub>) -> Result<Sse, AuthError> {
    let auth = session.into_auth().await?;
    Ok(hub.subscribe(auth.uid()).await)
}
