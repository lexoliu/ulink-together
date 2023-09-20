use std::{borrow::Cow, ops::Deref};

use mongodb::{bson::oid::ObjectId, Client, Database, Collection,bson::doc};
use levin::{utils::State, routing::Params,Error};
use serde::{Deserialize,Serialize};

const EMAIL_DOMAIN:&[&str]=&["ulink.cn"];

#[derive(Debug,Deserialize,Serialize)]
struct CheckMail<'a>{
    email:Cow<'a,str>,
}

pub async fn send_check_mail(database:&Database,email:&str) -> Result<ObjectId,mongodb::error::Error>{
    let check_mail:Collection<CheckMail>=database.collection("checkmail");
    let result=check_mail.insert_one(CheckMail{email:email.into()},None).await?;
    Ok(result.inserted_id.as_object_id().unwrap().to_owned())

}

pub async fn check_mail(database:&Database,id:ObjectId) -> Result<Option<String>,mongodb::error::Error>{
    let check_mail:Collection<CheckMail>=database.collection("checkmail");
    check_mail.find_one_and_delete(doc!{"_id":id}, None).await.map(|mail| mail.map(|mail| mail.email.to_string()))
}


// TODO:check params length (prevent CC attack)
pub async fn handler(state:State<Database>,params:Params) -> levin::Result<&'static str>{
    let email=params.get("email").ok_or(Error::msg(""))?;
    let mut email_is_legal=false;
    for legal_domain in EMAIL_DOMAIN{
        if let Some((_,domain)) = email.split_once('@'){
            if *legal_domain == domain{
                email_is_legal=true;
                break;
            }
        }
    }

    if !email_is_legal{
        return Ok("Illegal email address");
    }

    send_check_mail(state.deref(),email).await?;

    Ok("An email has been sent, please check the mailbox.")
}