use std::{fmt::Display, str::FromStr};

use skyzen::{
    openapi::ResponderOpenApiSchema,
    utils::{json::JsonEncodingError, Json},
};
use utoipa::ToSchema;
use uuid::Uuid;

pub fn sha256(v: impl AsRef<[u8]>) -> String {
    use ring::digest::{digest, SHA256};
    hex::encode(digest(&SHA256, v.as_ref()))
}

#[derive(Debug, serde::Serialize, ToSchema)]
pub struct ApiMessage {
    message: std::borrow::Cow<'static, str>,
}

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize, utoipa::ToSchema,
)]
#[schema(value_type = String)]
#[serde(transparent)]
pub struct Id(Uuid);

impl Id {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl ResponderOpenApiSchema for ApiMessage {
    fn register_schemas(defs: &mut std::collections::BTreeMap<String, skyzen::openapi::SchemaRef>) {
        Json::<ApiMessage>::register_schemas(defs);
    }

    fn responder_schemas() -> Option<Vec<skyzen::openapi::ResponseSchema>> {
        Json::<ApiMessage>::responder_schemas()
    }
}

impl Display for Id {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl FromStr for Id {
    type Err = uuid::Error;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(Uuid::from_str(s)?))
    }
}

impl ApiMessage {
    pub fn new(message: impl Into<std::borrow::Cow<'static, str>>) -> Self {
        Self {
            message: message.into(),
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
        Json(self).respond_to(request, response)
    }
}

pub fn parse_oid(value: &str) -> skyzen::Result<Id> {
    value.parse().map_err(|_| {
        skyzen::Error::msg("Invalid identifier").set_status(skyzen::StatusCode::BAD_REQUEST)
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn debug_id_schema() {
        let schema = <super::Id as utoipa::PartialSchema>::schema();
        match schema {
            utoipa::openapi::RefOr::T(_) => println!("inline schema"),
            utoipa::openapi::RefOr::Ref(r) => println!("ref schema: {}", r.ref_location),
        }
    }
}
