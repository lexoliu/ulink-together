use bson::{oid::ObjectId, serde_helpers::serialize_bson_datetime_as_rfc3339_string, DateTime};
use serde::Serializer;

pub fn serialize_option_datetime<S: Serializer>(
    val: &Option<DateTime>,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    if let Some(datetime) = val {
        serialize_bson_datetime_as_rfc3339_string(datetime, serializer)
    } else {
        serializer.serialize_none()
    }
}

pub fn sha256(v: impl AsRef<[u8]>) -> String {
    use ring::digest::{digest, SHA256};
    hex::encode(digest(&SHA256, v.as_ref()))
}

#[derive(Debug, serde::Serialize)]
pub struct ApiMessage {
    message: std::borrow::Cow<'static, str>,
}

impl ApiMessage {
    pub fn new(message: impl Into<std::borrow::Cow<'static, str>>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl skyzen::responder::Responder for ApiMessage {
    fn respond_to(
        self,
        request: &skyzen::Request,
        response: &mut skyzen::Response,
    ) -> skyzen::Result<()> {
        skyzen::utils::Json(self).respond_to(request, response)
    }
}

pub fn oid_to_hex(oid: &ObjectId) -> String {
    oid.to_hex()
}

pub fn parse_oid(oid: &str) -> skyzen::Result<ObjectId> {
    oid.parse()
        .map_err(|error| skyzen::Error::new(error, skyzen::StatusCode::BAD_REQUEST))
}
