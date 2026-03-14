use crate::{
    build_router,
    database::{build_test_database, AppDatabase},
    push::PushHub,
    schema::ensure_group_authority_any,
    utils::Id,
};
use models::{CreateActivityForm, RecordEntry};
use serde_json::json;
use skyzen_test::TestContext;
use sqlx::Row;
use time::OffsetDateTime;

async fn group_id(database: &AppDatabase, code: &str) -> Id {
    let row = sqlx::query(
        database
            .sql("SELECT id FROM groups WHERE code = ?1")
            .as_ref(),
    )
    .bind(code)
    .fetch_one(database.sqlx())
    .await
    .expect("fetch group");
    row.get::<String, _>("id").parse().expect("group id")
}

async fn insert_user(database: &AppDatabase, group_code: &str, email: &str, realname: &str) -> Id {
    let group = group_id(database, group_code).await;
    let id = Id::new();
    sqlx::query(
        database
            .sql(
                "INSERT INTO users (id, email, realname, gender, description, classname, avatar_path, password_hash, salt, group_id) VALUES (?1, ?2, ?3, 'other', '', 'Class A', NULL, 'hash', 'salt', ?4)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(email)
    .bind(realname)
    .bind(group.to_string())
    .execute(database.sqlx())
    .await
    .expect("insert user");
    id
}

async fn insert_session(database: &AppDatabase, user: Id) -> String {
    let session_id = Id::new().to_string();
    sqlx::query(
        database
            .sql("INSERT INTO sessions (id, user_id, generated_at, ip) VALUES (?1, ?2, ?3, ?4)")
            .as_ref(),
    )
    .bind(&session_id)
    .bind(user.to_string())
    .bind(OffsetDateTime::now_utc().to_string())
    .bind("127.0.0.1")
    .execute(database.sqlx())
    .await
    .expect("insert session");
    format!("session={session_id}")
}

async fn insert_activity(
    database: &AppDatabase,
    promoter: Id,
    name: &str,
    state: &str,
    duration_minutes: i64,
) -> Id {
    let id = Id::new();
    sqlx::query(
        database
            .sql(
                "INSERT INTO activities (id, promoter_id, name, location, state, volunteer_num, max_volunteer_num, date, brief_description, description, duration_minutes) VALUES (?1, ?2, ?3, 'Room 101', ?4, 0, 20, '2026-03-20', 'brief', 'description', ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(promoter.to_string())
    .bind(name)
    .bind(state)
    .bind(duration_minutes)
    .execute(database.sqlx())
    .await
    .expect("insert activity");
    id
}

async fn insert_channel(database: &AppDatabase, owner: Id, activity: Id, name: &str) -> Id {
    let id = Id::new();
    sqlx::query(
        database
            .sql(
                "INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(name)
    .bind(owner.to_string())
    .bind(activity.to_string())
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("insert channel");

    sqlx::query(
        database
            .sql("INSERT INTO channel_members (channel_id, user_id) VALUES (?1, ?2)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(owner.to_string())
    .execute(database.sqlx())
    .await
    .expect("insert channel owner");
    id
}

async fn insert_record(
    database: &AppDatabase,
    user: Id,
    activity: Id,
    state: &str,
    confirmed_minutes: i64,
) -> Id {
    let id = Id::new();
    let confirmed_at = if state == "done" {
        Some(OffsetDateTime::now_utc().to_string())
    } else {
        None
    };
    sqlx::query(
        database
            .sql(
                "INSERT INTO records (id, activity_id, user_id, state, confirmed_minutes, confirmed_at, confirmed_by, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(activity.to_string())
    .bind(user.to_string())
    .bind(state)
    .bind(confirmed_minutes)
    .bind(confirmed_at.as_deref())
    .bind(if state == "done" { Some(user.to_string()) } else { None })
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("insert record");
    id
}

fn test_client(database: AppDatabase) -> skyzen_test::TestClient<skyzen::routing::Router> {
    let router = build_router(database, PushHub::new());
    TestContext::new().client(router)
}

#[tokio::test]
async fn non_owner_cannot_change_activity_state() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner@example.com", "Owner").await;
    let intruder = insert_user(&database, "student", "intruder@example.com", "Intruder").await;
    let activity = insert_activity(&database, owner, "Cleanup", "need_volunteer", 120).await;
    let cookie = insert_session(&database, intruder).await;
    let client = test_client(database.clone());

    let response = client
        .post(&format!("/api/v1/activity/{activity}/go"))
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status(403);

    let row = sqlx::query(
        database
            .sql("SELECT state FROM activities WHERE id = ?1")
            .as_ref(),
    )
    .bind(activity.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("fetch activity");
    assert_eq!(row.get::<String, _>("state"), "need_volunteer");
}

#[tokio::test]
async fn owner_can_update_activity() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner2@example.com", "Owner").await;
    let activity = insert_activity(&database, owner, "Cleanup", "need_volunteer", 120).await;
    let cookie = insert_session(&database, owner).await;
    let client = test_client(database);

    let response = client
        .put(&format!("/api/v1/activity/{activity}"))
        .header("Cookie", &cookie)
        .json(&CreateActivityForm {
            name: "Updated Cleanup".to_string(),
            date: Some("2026-03-21".to_string()),
            max_volunteer_num: Some(12),
            description: "Updated description".to_string(),
            location: "Room 202".to_string(),
            brief_description: "Updated brief".to_string(),
            duration: 90,
        })
        .send()
        .await;

    response.assert_status_success();
    response.assert_json_path("name", &json!("Updated Cleanup"));
    response.assert_json_path("location", &json!("Room 202"));
    response.assert_json_path("duration", &json!(90));
}

#[tokio::test]
async fn join_adds_channel_membership_and_allows_message_post() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner3@example.com", "Owner").await;
    ensure_group_authority_any(
        database.sqlx(),
        &group_id(&database, "student").await.to_string(),
        "create_channel",
    )
    .await
    .expect("grant create_channel");
    let volunteer = insert_user(&database, "student", "vol@example.com", "Volunteer").await;
    let activity = insert_activity(&database, owner, "Cleanup", "need_volunteer", 120).await;
    let channel = insert_channel(&database, owner, activity, "Cleanup Channel").await;
    let cookie = insert_session(&database, volunteer).await;
    let client = test_client(database.clone());

    let join_response = client
        .post(&format!("/api/v1/activity/{activity}/apply"))
        .header("Cookie", &cookie)
        .send()
        .await;
    join_response.assert_status_success();

    let membership = sqlx::query(
        database
            .sql("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2")
            .as_ref(),
    )
    .bind(channel.to_string())
    .bind(volunteer.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("check membership");
    assert!(membership.is_some());

    let post_response = client
        .post(&format!("/api/v1/channel/{channel}"))
        .header("Cookie", &cookie)
        .json(&json!({ "content": "hello" }))
        .send()
        .await;
    post_response.assert_status_success();
    post_response.assert_json_path("content", &json!("hello"));
}

#[tokio::test]
async fn activity_create_auto_creates_activity_channel() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner-auto@example.com", "Owner").await;
    ensure_group_authority_any(
        database.sqlx(),
        &group_id(&database, "student").await.to_string(),
        "create_activity",
    )
    .await
    .expect("grant create_activity");
    let cookie = insert_session(&database, owner).await;
    let client = test_client(database.clone());

    let response = client
        .post("/api/v1/activity")
        .header("Cookie", &cookie)
        .json(&json!({
            "name": "Auto Channel Activity",
            "date": "2026-03-20T09:00:00Z",
            "max_volunteer_num": 16,
            "description": "Detailed description",
            "location": "Library",
            "brief_description": "Brief description",
            "duration": 120
        }))
        .send()
        .await;
    response.assert_status_success();
    let created: serde_json::Value = response.assert_json();
    let activity_id = created["id"].as_str().expect("activity id").to_string();

    let channel = sqlx::query(
        database
            .sql("SELECT id, name FROM channels WHERE activity_id = ?1")
            .as_ref(),
    )
    .bind(activity_id)
    .fetch_optional(database.sqlx())
    .await
    .expect("load channel");

    let channel = channel.expect("activity channel exists");
    assert_eq!(
        channel.try_get::<String, _>("name").expect("channel name"),
        "Auto Channel Activity Channel"
    );
}

#[tokio::test]
async fn record_find_defaults_to_current_user() {
    let database = build_test_database().await;
    let user_one = insert_user(&database, "student", "u1@example.com", "User One").await;
    let user_two = insert_user(&database, "student", "u2@example.com", "User Two").await;
    let activity = insert_activity(&database, user_one, "Cleanup", "need_volunteer", 120).await;
    insert_record(&database, user_one, activity, "todo", 0).await;
    insert_record(&database, user_two, activity, "todo", 0).await;
    let cookie = insert_session(&database, user_one).await;
    let client = test_client(database);

    let response = client
        .get("/api/v1/record")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status_success();
    let records: Vec<RecordEntry> = response.assert_json();
    assert_eq!(records.len(), 1);
    assert_eq!(records[0].user, user_one);
}

#[tokio::test]
async fn message_reads_require_channel_membership() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner4@example.com", "Owner").await;
    let stranger = insert_user(&database, "student", "stranger@example.com", "Stranger").await;
    let activity = insert_activity(&database, owner, "Cleanup", "need_volunteer", 120).await;
    let channel = insert_channel(&database, owner, activity, "Cleanup Channel").await;
    let cookie = insert_session(&database, stranger).await;
    let client = test_client(database);

    let response = client
        .get(&format!("/api/v1/message?channel={channel}"))
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status(403);
}

#[tokio::test]
async fn ended_activity_channel_becomes_read_only() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "owner-readonly@example.com", "Owner").await;
    let volunteer = insert_user(
        &database,
        "student",
        "readonly-vol@example.com",
        "Volunteer",
    )
    .await;
    let activity = insert_activity(&database, owner, "Cleanup", "need_volunteer", 120).await;
    let channel = insert_channel(&database, owner, activity, "Cleanup Channel").await;
    let volunteer_cookie = insert_session(&database, volunteer).await;
    let owner_cookie = insert_session(&database, owner).await;
    let client = test_client(database.clone());

    client
        .post(&format!("/api/v1/activity/{activity}/apply"))
        .header("Cookie", &volunteer_cookie)
        .send()
        .await
        .assert_status_success();

    client
        .post(&format!("/api/v1/activity/{activity}/go"))
        .header("Cookie", &owner_cookie)
        .send()
        .await
        .assert_status_success();

    client
        .post(&format!("/api/v1/activity/{activity}/end"))
        .header("Cookie", &owner_cookie)
        .send()
        .await
        .assert_status_success();

    client
        .post(&format!("/api/v1/channel/{channel}"))
        .header("Cookie", &volunteer_cookie)
        .json(&json!({ "content": "can anyone still post?" }))
        .send()
        .await
        .assert_status(403);
}

#[tokio::test]
async fn leaderboard_returns_ranked_totals() {
    let database = build_test_database().await;
    let viewer = insert_user(&database, "student", "viewer@example.com", "Viewer").await;
    let user_a = insert_user(&database, "student", "a@example.com", "Alice").await;
    let user_b = insert_user(&database, "student", "b@example.com", "Bob").await;
    let activity_1 = insert_activity(&database, user_a, "A1", "ended", 120).await;
    let activity_2 = insert_activity(&database, user_b, "A2", "ended", 60).await;
    insert_record(&database, user_a, activity_1, "done", 120).await;
    insert_record(&database, user_b, activity_2, "done", 60).await;
    let cookie = insert_session(&database, viewer).await;
    let client = test_client(database);

    let response = client
        .get("/api/v1/leaderboard")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status_success();
    response.assert_json_path("0.realname", &json!("Alice"));
    response.assert_json_path("0.total_minutes", &json!(120));
    response.assert_json_path("1.realname", &json!("Bob"));
}

#[tokio::test]
async fn export_requires_authority_and_generates_csv() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "admin@example.com", "Admin").await;
    let volunteer = insert_user(&database, "student", "student@example.com", "Student").await;
    let activity = insert_activity(&database, admin, "Cleanup", "ended", 90).await;
    insert_record(&database, volunteer, activity, "done", 90).await;
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database);

    let response = client
        .post("/api/v1/export")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status_success();
    response.assert_json_path("target_format", &json!("csv"));
    response.assert_body_contains("student_identifier");
    response.assert_body_contains("Student");
}

#[tokio::test]
async fn mark_done_requires_completed_activity() {
    let database = build_test_database().await;
    let organizer = insert_user(&database, "admin", "organizer@example.com", "Organizer").await;
    let volunteer = insert_user(
        &database,
        "student",
        "student-pending@example.com",
        "Student",
    )
    .await;
    let activity = insert_activity(
        &database,
        organizer,
        "Pending Cleanup",
        "need_volunteer",
        90,
    )
    .await;
    let record = insert_record(&database, volunteer, activity, "todo", 0).await;
    let cookie = insert_session(&database, organizer).await;
    let client = test_client(database);

    let response = client
        .post(&format!("/api/v1/record/{record}/done"))
        .header("Cookie", &cookie)
        .send()
        .await;

    response.assert_status(409);
    response.assert_body_contains("Activity must be completed before hours can be confirmed");
}
