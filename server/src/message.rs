use crate::{auth::AuthSession, database::AppDatabase, utils::ApiMessage};
use bytestr::ByteStr;
use skyzen::{
    extract::Query,
    routing::Params,
    utils::{Json, State},
    Error, StatusCode,
};

#[derive(Debug, serde::Deserialize)]
pub(crate) struct FindQuery {
    start_date: Option<String>,
    end_date: Option<String>,
    channel: String,
    sender: Option<String>,
}

#[derive(Debug, serde::Deserialize, serde::Serialize)]
pub struct Message {
    id: String,
    channel: String,
    content: String,
    datetime: String,
}

pub async fn find(
    _database: State<AppDatabase>,
    _query: Query<FindQuery>,
    session: AuthSession,
) -> skyzen::Result<Json<serde_json::Value>> {
    session.into_auth().await?;
    Err(Error::msg("Message API is being migrated to SQL").set_status(StatusCode::NOT_IMPLEMENTED))
}

pub async fn get(
    _database: State<AppDatabase>,
    _params: Params,
    session: AuthSession,
) -> skyzen::Result<Json<serde_json::Value>> {
    session.into_auth().await?;
    Err(Error::msg("Message API is being migrated to SQL").set_status(StatusCode::NOT_IMPLEMENTED))
}

pub async fn post(
    _database: State<AppDatabase>,
    _content: ByteStr,
    _params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    session.into_auth().await?;
    Err(Error::msg("Message API is being migrated to SQL").set_status(StatusCode::NOT_IMPLEMENTED))
}

pub async fn delete(
    _database: State<AppDatabase>,
    _params: Params,
    session: AuthSession,
) -> skyzen::Result<ApiMessage> {
    session.into_auth().await?;
    Err(Error::msg("Message API is being migrated to SQL").set_status(StatusCode::NOT_IMPLEMENTED))
}
