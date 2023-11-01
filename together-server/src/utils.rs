use mongodb::bson::{
    oid::ObjectId, serde_helpers::serialize_bson_datetime_as_rfc3339_string, DateTime, Document,
};
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

impl levin::responder::Responder for ApiMessage {
    fn respond_to(
        self,
        request: &levin::Request,
        response: &mut levin::Response,
    ) -> levin::Result<()> {
        levin::utils::Json(self).respond_to(request, response)
    }
}

pub fn oid_to_hex(oid: mongodb::bson::Bson) -> Option<String> {
    oid.as_object_id().map(|oid| oid.to_hex())
}

pub fn parse_oid(oid: &str) -> levin::Result<ObjectId> {
    oid.parse()
        .map_err(|error| levin::Error::new(error, levin::StatusCode::BAD_REQUEST))
}

pub struct ProjectOption(Document);

impl ProjectOption {
    pub fn new(doc: impl Into<Option<Document>>) -> Self {
        Self(doc.into().unwrap_or(mongodb::bson::doc! {"_id":1}))
    }
}

impl From<ProjectOption> for Option<mongodb::options::FindOneOptions> {
    fn from(value: ProjectOption) -> Self {
        Some(
            mongodb::options::FindOneOptions::builder()
                .projection(value.0)
                .build(),
        )
    }
}

impl From<ProjectOption> for Option<mongodb::options::FindOptions> {
    fn from(value: ProjectOption) -> Self {
        Some(
            mongodb::options::FindOptions::builder()
                .projection(value.0)
                .build(),
        )
    }
}
