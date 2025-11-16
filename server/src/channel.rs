use crate::{auth::AuthSession, database::AppDatabase};
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Form, Json, State},
    Error, StatusCode,
};

#[derive(Debug, serde::Deserialize)]
pub(crate) struct CreateChannelForm {
    name: String,
}

#[derive(Debug, serde::Deserialize)]
pub struct FindForm {
    owner: Option<String>,
    include_member: Option<String>,
    activity: Option<String>,
}

pub async fn create(
    _database: State<AppDatabase>,
    session: AuthSession,
    _query: Query<CreateChannelForm>,
) -> skyzen::Result<Json<serde_json::Value>> {
    session.into_auth().await?;
    Err(Error::msg("Channel creation is being migrated to SQL")
        .set_status(StatusCode::NOT_IMPLEMENTED))
}

pub async fn delete(
    _database: State<AppDatabase>,
    _params: Params,
    session: AuthSession,
) -> skyzen::Result<crate::utils::ApiMessage> {
    session.into_auth().await?;
    Err(Error::msg("Channel deletion is being migrated to SQL")
        .set_status(StatusCode::NOT_IMPLEMENTED))
}

pub async fn find(
    _database: State<AppDatabase>,
    _form: Form<FindForm>,
    session: AuthSession,
) -> skyzen::Result<Json<serde_json::Value>> {
    session.into_auth().await?;
    Err(Error::msg("Channel search is being migrated to SQL")
        .set_status(StatusCode::NOT_IMPLEMENTED))
}
