use bson::oid::ObjectId;

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

pub fn parse_oid(oid: &str) -> skyzen::Result<ObjectId> {
    oid.parse()
        .map_err(|error| skyzen::Error::new(error, skyzen::StatusCode::BAD_REQUEST))
}
