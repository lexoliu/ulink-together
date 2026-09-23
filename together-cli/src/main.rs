use std::time::Duration;

use clap::{Parser, Subcommand};
use mongodb::{bson::doc, options::IndexOptions, Client, IndexModel};
use tokio::runtime::Runtime;

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Parser)]
struct InitArgs {
    /// Database address,including port.
    address: String,
    /// Database name, `together` by default.
    name: String,
}

#[derive(Subcommand)]
enum Command {
    /// Init database for together server.
    Init(InitArgs),
}

fn main() {
    let runtime = Runtime::new().unwrap();
    runtime.block_on(async {
        if let Err(error) = lanuch().await {
            println!("{}", error);
        }
    });
}

type BoxError = Box<dyn std::error::Error>;

async fn lanuch() -> Result<(), BoxError> {
    let cli = Cli::parse();
    match cli.command {
        Command::Init(args) => {
            let client = Client::with_uri_str("mongodb://".to_string() + &args.address).await?;
            let database = client.database(&args.name);
            database.create_collection("session", None).await?;
            let session = database.collection::<()>("session");
            session
                .create_index(
                    IndexModel::builder()
                        .keys(doc! {"generated_date":1})
                        .options(
                            IndexOptions::builder()
                                .expire_after(Duration::from_secs(60 * 60 * 24 * 7 * 2))
                                .build(),
                        )
                        .build(),
                    None,
                )
                .await?;
            println!("created `session`");

            database.create_collection("user", None).await?;
            let user = database.collection::<()>("user");
            user.create_index(
                IndexModel::builder()
                    .keys(doc! {"email":1})
                    .options(IndexOptions::builder().unique(true).build())
                    .build(),
                None,
            )
            .await?;
            println!("created `user`");

            database.create_collection("group", None).await?;
            println!("created `group`");

            let group=database.collection("group");
            group.insert_one(doc!{"code":"lexooo","name":"Super Admin","authority":"*"}, None).await?;

            group.insert_one(doc!{"code":"student","name":"Student","authority":["send_comment",]}, None).await?;

            group.insert_one(doc!{"code":"banned","name":"Banned","authority":[]}, None).await?;

            group.insert_one(doc!{"code":"teacher","name":"Teacher","authority":["view_user",]}, None).await?;

            group.create_index(
                IndexModel::builder()
                    .keys(doc! {"code":1})
                    .options(IndexOptions::builder().unique(true).build())
                    .build(),
                None,
            )
            .await?;

            database.create_collection("message", None).await?;
            println!("created `message`");

            database.create_collection("channel", None).await?;
            println!("created `channel`");

            database.create_collection("activity", None).await?;
            println!("created `activity`");

            database.create_collection("comment", None).await?;
            println!("created `comment`");

            println!("done.")
        }
    }
    Ok(())
}
