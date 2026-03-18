use std::borrow::Cow;

use skyzen::{
    utils::{json::JsonEncodingError, Json},
    StatusCode,
};
use utoipa::ToSchema;

// Re-export Id from models crate
pub use models::Id;

pub fn sha256(v: impl AsRef<[u8]>) -> String {
    use ring::digest::{digest, SHA256};
    hex::encode(digest(&SHA256, v.as_ref()))
}

pub fn normalize_endpoint_error_message(message: &str) -> Cow<'_, str> {
    const PREFIX: &str = "Endpoint error: ";

    let mut normalized = message.trim();
    while let Some(stripped) = normalized.strip_prefix(PREFIX) {
        normalized = stripped.trim_start();
    }

    if normalized == message {
        Cow::Borrowed(message)
    } else {
        Cow::Owned(normalized.to_string())
    }
}

#[derive(Debug, serde::Serialize, ToSchema)]
pub struct ApiMessage {
    message: std::borrow::Cow<'static, str>,
    #[serde(skip)]
    status: Option<StatusCode>,
}

impl ApiMessage {
    pub fn new(message: impl Into<std::borrow::Cow<'static, str>>) -> Self {
        Self {
            message: message.into(),
            status: None,
        }
    }

    pub fn with_status(
        message: impl Into<std::borrow::Cow<'static, str>>,
        status: StatusCode,
    ) -> Self {
        Self {
            message: message.into(),
            status: Some(status),
        }
    }
}

impl skyzen::responder::Responder for ApiMessage {
    type Error = JsonEncodingError;
    fn respond_to(
        self,
        request: &skyzen::Request,
        response: &mut skyzen::Response,
    ) -> Result<(), Self::Error> {
        if let Some(status) = self.status {
            *response.status_mut() = status;
        }
        Json(self).respond_to(request, response)
    }

    fn openapi() -> Option<Vec<skyzen::openapi::ResponseSchema>> {
        <Json<ApiMessage> as skyzen::Responder>::openapi()
    }

    fn register_openapi_schemas(
        defs: &mut std::collections::BTreeMap<String, skyzen::openapi::SchemaRef>,
    ) {
        <Json<ApiMessage> as skyzen::Responder>::register_openapi_schemas(defs);
    }
}

#[skyzen::error]
pub enum ParseIdError {
    #[error("Invalid identifier", status = BAD_REQUEST)]
    InvalidIdentifier,
}

pub type ParseIdResult<T> = Result<T, ParseIdError>;

pub fn parse_oid(value: &str) -> ParseIdResult<Id> {
    value.parse().map_err(|_| ParseIdError::InvalidIdentifier)
}

#[cfg(test)]
mod tests {
    #[test]
    fn normalize_endpoint_error_message_strips_nested_prefixes() {
        assert_eq!(
            super::normalize_endpoint_error_message(
                "Endpoint error: Endpoint error: Wrong email or password"
            ),
            "Wrong email or password"
        );
    }

    #[test]
    fn debug_id_schema() {
        let schema = <super::Id as utoipa::PartialSchema>::schema();
        match schema {
            utoipa::openapi::RefOr::T(_) => println!("inline schema"),
            utoipa::openapi::RefOr::Ref(r) => println!("ref schema: {}", r.ref_location),
        }
    }
}
