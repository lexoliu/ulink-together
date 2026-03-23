use crate::{
    build_router,
    database::{build_test_database, AppDatabase},
    push::PushHub,
    schema::ensure_group_authority_any,
    utils::{hash_password, verify_password, Id},
};
use async_std::fs;
use models::{CreateActivityForm, RecordEntry, User};
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
                "INSERT INTO users (id, email, realname, gender, description, classname, avatar_path, password_hash, group_id) VALUES (?1, ?2, ?3, 'other', '', 'Class A', NULL, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(email)
    .bind(realname)
    .bind(hash_password("test-password").expect("bcrypt hash password"))
    .bind(group.to_string())
    .execute(database.sqlx())
    .await
    .expect("insert user");
    id
}

async fn insert_login_user(
    database: &AppDatabase,
    group_code: &str,
    email: &str,
    realname: &str,
    password: &str,
) -> Id {
    let group = group_id(database, group_code).await;
    let id = Id::new();
    let password_hash = hash_password(password).expect("bcrypt hash password");
    sqlx::query(
        database
            .sql(
                "INSERT INTO users (id, email, realname, gender, description, classname, avatar_path, password_hash, group_id) VALUES (?1, ?2, ?3, 'other', '', 'Class A', NULL, ?4, ?5)",
            )
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(email)
    .bind(realname)
    .bind(password_hash)
    .bind(group.to_string())
    .execute(database.sqlx())
    .await
    .expect("insert login user");
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
    let confirmed_at = if state == "confirmed" {
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
    .bind(if state == "confirmed" { Some(user.to_string()) } else { None })
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("insert record");
    id
}

async fn insert_comment(database: &AppDatabase, activity: Id, author: Id, content: &str) -> Id {
    let id = Id::new();
    sqlx::query(
        database
            .sql("INSERT INTO activity_comments (id, activity_id, author_id, content, created_at) VALUES (?1, ?2, ?3, ?4, ?5)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(activity.to_string())
    .bind(author.to_string())
    .bind(content)
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("insert comment");
    id
}

async fn insert_resource(database: &AppDatabase, creator: Id, name: &str) -> (Id, String) {
    let id = Id::new();
    let filename = format!("{id}.png");
    fs::create_dir_all("./resource")
        .await
        .expect("create resource dir");
    fs::write(format!("./resource/{filename}"), b"avatar")
        .await
        .expect("write resource file");
    sqlx::query(
        database
            .sql("INSERT INTO resources (id, creator_id, name, extension, created_at) VALUES (?1, ?2, ?3, ?4, ?5)")
            .as_ref(),
    )
    .bind(id.to_string())
    .bind(creator.to_string())
    .bind(name)
    .bind("png")
    .bind(OffsetDateTime::now_utc().to_string())
    .execute(database.sqlx())
    .await
    .expect("insert resource");
    (id, filename)
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
async fn apply_does_not_add_channel_membership_or_allow_message_post_before_approval() {
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
    assert!(membership.is_none());

    let post_response = client
        .post(&format!("/api/v1/channel/{channel}"))
        .header("Cookie", &cookie)
        .json(&json!({ "content": "hello" }))
        .send()
        .await;
    post_response.assert_status(403);
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
    insert_record(&database, user_one, activity, "approved", 0).await;
    insert_record(&database, user_two, activity, "approved", 0).await;
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
    insert_record(&database, user_a, activity_1, "confirmed", 120).await;
    insert_record(&database, user_b, activity_2, "confirmed", 60).await;
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
async fn user_list_requires_view_user_authority() {
    let database = build_test_database().await;
    let viewer = insert_user(&database, "student", "viewer-noauth@example.com", "Viewer").await;
    let cookie = insert_session(&database, viewer).await;
    let client = test_client(database);

    let response = client
        .get("/api/v1/user")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status(403);
}

#[tokio::test]
async fn user_list_defaults_to_students_and_supports_search() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "admin-users@example.com", "Admin").await;
    insert_user(
        &database,
        "student",
        "alice-student@example.com",
        "Alice Student",
    )
    .await;
    let bob = insert_user(
        &database,
        "student",
        "bob-student@example.com",
        "Bob Student",
    )
    .await;
    insert_user(
        &database,
        "admin",
        "teacher-admin@example.com",
        "Teacher Admin",
    )
    .await;
    sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind("Class B2")
    .bind(bob.to_string())
    .execute(database.sqlx())
    .await
    .expect("update classname");
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database);

    let response = client
        .get("/api/v1/user")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status_success();
    let students: Vec<User> = response.assert_json();
    let student_emails: Vec<_> = students.iter().map(|user| user.email.as_str()).collect();
    assert!(student_emails.contains(&"alice-student@example.com"));
    assert!(student_emails.contains(&"bob-student@example.com"));
    assert!(!student_emails.contains(&"teacher-admin@example.com"));

    let search_response = client
        .get("/api/v1/user?search=class%20b2")
        .header("Cookie", &cookie)
        .send()
        .await;
    search_response.assert_status_success();
    let searched: Vec<User> = search_response.assert_json();
    assert_eq!(searched.len(), 1);
    assert_eq!(searched[0].email, "bob-student@example.com");

    let admin_group_response = client
        .get("/api/v1/user?group=admin")
        .header("Cookie", &cookie)
        .send()
        .await;
    admin_group_response.assert_status_success();
    let admins: Vec<User> = admin_group_response.assert_json();
    let admin_emails: Vec<_> = admins.iter().map(|user| user.email.as_str()).collect();
    assert!(admin_emails.contains(&"teacher-admin@example.com"));
    assert!(!admin_emails.contains(&"alice-student@example.com"));
}

#[tokio::test]
async fn user_classes_returns_student_counts_by_default() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "admin-classes@example.com", "Admin").await;
    let class_a = insert_user(
        &database,
        "student",
        "class-a@example.com",
        "Class A Student",
    )
    .await;
    let class_b = insert_user(
        &database,
        "student",
        "class-b@example.com",
        "Class B Student",
    )
    .await;
    insert_user(&database, "admin", "teacher@example.com", "Teacher").await;
    sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind("Class A")
    .bind(class_a.to_string())
    .execute(database.sqlx())
    .await
    .expect("update class a");
    sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind("Class B")
    .bind(class_b.to_string())
    .execute(database.sqlx())
    .await
    .expect("update class b");
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database);

    let response = client
        .get("/api/v1/user/classes")
        .header("Cookie", &cookie)
        .send()
        .await;
    response.assert_status_success();
    response.assert_json_path("0.classname", &json!("Class A"));
    response.assert_json_path("0.count", &json!(1));
}

#[tokio::test]
async fn batch_import_csv_requires_update_user_anyway_authority() {
    let database = build_test_database().await;
    let actor = insert_user(&database, "student", "actor-import@example.com", "Actor").await;
    let cookie = insert_session(&database, actor).await;
    let client = test_client(database);

    let response = client
        .post("/api/v1/user/batch/import_csv")
        .header("Cookie", &cookie)
        .json(&json!({
            "csv_text": "email,realname,gender,classname\nimported@example.com,Imported Student,other,Class X",
            "default_password": "change-me"
        }))
        .send()
        .await;

    response.assert_status(403);
}

#[tokio::test]
async fn batch_import_csv_creates_students_with_default_and_row_password() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "admin-import@example.com", "Admin").await;
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database.clone());

    let response = client
        .post("/api/v1/user/batch/import_csv")
        .header("Cookie", &cookie)
        .json(&json!({
            "csv_text": "email,realname,gender,classname,description,avatar,password\nstudent-one@example.com,Student One,female,Class 10A,First student,,\nstudent-two@example.com,Student Two,male,Class 10B,,/api/v1/resource/a.png,custom-pass",
            "default_password": "default-pass"
        }))
        .send()
        .await;

    response.assert_status_success();
    response.assert_json_path("affected", &json!(2));

    let one = sqlx::query(
        database
            .sql("SELECT password_hash, classname FROM users WHERE email = ?1")
            .as_ref(),
    )
    .bind("student-one@example.com")
    .fetch_one(database.sqlx())
    .await
    .expect("query student one");
    assert!(verify_password("default-pass", &one.get::<String, _>("password_hash")).expect("bcrypt verify password"));
    assert_eq!(one.get::<String, _>("classname"), "Class 10A");

    let two = sqlx::query(
        database
            .sql("SELECT password_hash, avatar_path FROM users WHERE email = ?1")
            .as_ref(),
    )
    .bind("student-two@example.com")
    .fetch_one(database.sqlx())
    .await
    .expect("query student two");
    assert!(verify_password("custom-pass", &two.get::<String, _>("password_hash")).expect("bcrypt verify password"));
    assert_eq!(
        two.get::<Option<String>, _>("avatar_path"),
        Some("/api/v1/resource/a.png".to_string())
    );
}

#[tokio::test]
async fn batch_update_class_renames_student_class_in_bulk() {
    let database = build_test_database().await;
    let admin = insert_user(
        &database,
        "admin",
        "admin-class-update@example.com",
        "Admin",
    )
    .await;
    let s1 = insert_user(&database, "student", "c1@example.com", "Class One").await;
    let s2 = insert_user(&database, "student", "c2@example.com", "Class Two").await;
    let s3 = insert_user(&database, "student", "c3@example.com", "Class Three").await;
    for student_id in [s1, s2] {
        sqlx::query(
            database
                .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
                .as_ref(),
        )
        .bind("Class 11A")
        .bind(student_id.to_string())
        .execute(database.sqlx())
        .await
        .expect("assign class 11a");
    }
    sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind("Class 11B")
    .bind(s3.to_string())
    .execute(database.sqlx())
    .await
    .expect("assign class 11b");
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database.clone());

    let response = client
        .post("/api/v1/user/batch/update_class")
        .header("Cookie", &cookie)
        .json(&json!({
            "from_classname": "Class 11A",
            "to_classname": "Class 12A"
        }))
        .send()
        .await;

    response.assert_status_success();
    response.assert_json_path("affected", &json!(2));

    let renamed_count = sqlx::query(
        database
            .sql("SELECT COUNT(*) AS c FROM users WHERE classname = ?1")
            .as_ref(),
    )
    .bind("Class 12A")
    .fetch_one(database.sqlx())
    .await
    .expect("count class 12a");
    assert_eq!(renamed_count.get::<i64, _>("c"), 2);
}

#[tokio::test]
async fn batch_delete_class_removes_only_target_student_class() {
    let database = build_test_database().await;
    let admin = insert_user(
        &database,
        "admin",
        "admin-class-delete@example.com",
        "Admin",
    )
    .await;
    let keep = insert_user(&database, "student", "keep@example.com", "Keep Student").await;
    let drop_one = insert_user(&database, "student", "drop1@example.com", "Drop One").await;
    let drop_two = insert_user(&database, "student", "drop2@example.com", "Drop Two").await;
    sqlx::query(
        database
            .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
            .as_ref(),
    )
    .bind("Class Keep")
    .bind(keep.to_string())
    .execute(database.sqlx())
    .await
    .expect("assign class keep");
    for student_id in [drop_one, drop_two] {
        sqlx::query(
            database
                .sql("UPDATE users SET classname = ?1 WHERE id = ?2")
                .as_ref(),
        )
        .bind("Class Drop")
        .bind(student_id.to_string())
        .execute(database.sqlx())
        .await
        .expect("assign class drop");
    }
    let cookie = insert_session(&database, admin).await;
    let client = test_client(database.clone());

    let response = client
        .post("/api/v1/user/batch/delete_class")
        .header("Cookie", &cookie)
        .json(&json!({
            "classname": "Class Drop"
        }))
        .send()
        .await;

    response.assert_status_success();
    response.assert_json_path("affected", &json!(2));

    let remaining_drop = sqlx::query(
        database
            .sql("SELECT COUNT(*) AS c FROM users WHERE classname = ?1")
            .as_ref(),
    )
    .bind("Class Drop")
    .fetch_one(database.sqlx())
    .await
    .expect("count class drop");
    assert_eq!(remaining_drop.get::<i64, _>("c"), 0);
}

#[tokio::test]
async fn export_requires_authority_and_generates_csv() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "admin@example.com", "Admin").await;
    let volunteer = insert_user(&database, "student", "student@example.com", "Student").await;
    let activity = insert_activity(&database, admin, "Cleanup", "ended", 90).await;
    insert_record(&database, volunteer, activity, "confirmed", 90).await;
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
    let record = insert_record(&database, volunteer, activity, "approved", 0).await;
    let cookie = insert_session(&database, organizer).await;
    let client = test_client(database);

    let response = client
        .post(&format!("/api/v1/record/{record}/confirm"))
        .header("Cookie", &cookie)
        .send()
        .await;

    response.assert_status(409);
    response.assert_body_contains("Invalid record state transition");
}

#[tokio::test]
async fn login_errors_do_not_duplicate_endpoint_prefix() {
    let database = build_test_database().await;
    insert_login_user(
        &database,
        "student",
        "login-review@example.com",
        "Login Review",
        "correct-password",
    )
    .await;
    let client = test_client(database);

    let response = client
        .post("/api/v1/login")
        .header("x-forwarded-for", "127.0.0.1")
        .json(&json!({
            "email": "login-review@example.com",
            "password": "wrong-password"
        }))
        .send()
        .await;

    response.assert_status(403);
    response.assert_json_path("message", &json!("Wrong email or password"));
}

#[tokio::test]
async fn resource_delete_removes_owned_file_and_row() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "resource-owner@example.com", "Owner").await;
    let cookie = insert_session(&database, owner).await;
    let (resource_id, filename) = insert_resource(&database, owner, "avatar").await;
    let client = test_client(database.clone());

    let response = client
        .delete(&format!("/api/v1/resource/{filename}"))
        .header("Cookie", &cookie)
        .send()
        .await;

    response.assert_status_success();

    let resource = sqlx::query(
        database
            .sql("SELECT 1 FROM resources WHERE id = ?1")
            .as_ref(),
    )
    .bind(resource_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("fetch resource");
    assert!(resource.is_none());
    assert!(!std::path::Path::new(&format!("./resource/{filename}")).exists());
}

#[tokio::test]
async fn leave_then_rejoin_restores_membership_and_count() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "leave-owner@example.com", "Owner").await;
    let volunteer = insert_user(&database, "student", "leave-vol@example.com", "Volunteer").await;
    let activity = insert_activity(&database, owner, "Leave Test", "need_volunteer", 90).await;
    let channel = insert_channel(&database, owner, activity, "Leave Test Channel").await;
    let cookie = insert_session(&database, volunteer).await;
    let client = test_client(database.clone());

    client
        .post(&format!("/api/v1/activity/{activity}/apply"))
        .header("Cookie", &cookie)
        .send()
        .await
        .assert_status_success();

    client
        .post(&format!("/api/v1/activity/{activity}/withdraw"))
        .header("Cookie", &cookie)
        .send()
        .await
        .assert_status_success();

    let left_record = sqlx::query(
        database
            .sql("SELECT state FROM records WHERE activity_id = ?1 AND user_id = ?2")
            .as_ref(),
    )
    .bind(activity.to_string())
    .bind(volunteer.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("fetch record after leave");
    assert_eq!(left_record.get::<String, _>("state"), "canceled");
    let member_after_leave = sqlx::query(
        database
            .sql("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2")
            .as_ref(),
    )
    .bind(channel.to_string())
    .bind(volunteer.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("fetch membership after leave");
    assert!(member_after_leave.is_none());

    client
        .post(&format!("/api/v1/activity/{activity}/apply"))
        .header("Cookie", &cookie)
        .send()
        .await
        .assert_status_success();

    let row = sqlx::query(
        database
            .sql("SELECT state FROM records WHERE activity_id = ?1 AND user_id = ?2")
            .as_ref(),
    )
    .bind(activity.to_string())
    .bind(volunteer.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("fetch rejoined record");
    assert_eq!(row.get::<String, _>("state"), "pending_approval");

    let member_after_rejoin = sqlx::query(
        database
            .sql("SELECT 1 FROM channel_members WHERE channel_id = ?1 AND user_id = ?2")
            .as_ref(),
    )
    .bind(channel.to_string())
    .bind(volunteer.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("fetch membership after rejoin");
    assert!(member_after_rejoin.is_none());
}

#[tokio::test]
async fn mark_done_custom_overrides_activity_duration() {
    let database = build_test_database().await;
    let organizer = insert_user(
        &database,
        "admin",
        "custom-organizer@example.com",
        "Organizer",
    )
    .await;
    let volunteer = insert_user(&database, "student", "custom-vol@example.com", "Volunteer").await;
    let activity = insert_activity(&database, organizer, "Custom Done", "ended", 90).await;
    let record = insert_record(&database, volunteer, activity, "approved", 0).await;
    let cookie = insert_session(&database, organizer).await;
    let client = test_client(database.clone());

    client
        .post(&format!("/api/v1/record/{record}/confirm_custom"))
        .header("Cookie", &cookie)
        .json(&json!({ "confirmed_minutes": 37 }))
        .send()
        .await
        .assert_status_success();

    let row = sqlx::query(
        database
            .sql("SELECT state, confirmed_minutes FROM records WHERE id = ?1")
            .as_ref(),
    )
    .bind(record.to_string())
    .fetch_one(database.sqlx())
    .await
    .expect("fetch customized record");
    assert_eq!(row.get::<String, _>("state"), "confirmed");
    assert_eq!(row.get::<i64, _>("confirmed_minutes"), 37);
}

#[tokio::test]
async fn password_change_and_reset_flow_work() {
    let database = build_test_database().await;
    let user = insert_login_user(
        &database,
        "student",
        "password-flow@example.com",
        "Password Flow",
        "old-pass",
    )
    .await;
    let cookie = insert_session(&database, user).await;
    let client = test_client(database.clone());

    client
        .post("/api/v1/password/change")
        .header("Cookie", &cookie)
        .json(&json!({
            "current_password": "old-pass",
            "new_password": "new-pass"
        }))
        .send()
        .await
        .assert_status_success();

    client
        .post("/api/v1/login")
        .header("x-forwarded-for", "127.0.0.1")
        .json(&json!({
            "email": "password-flow@example.com",
            "password": "new-pass"
        }))
        .send()
        .await
        .assert_status_success();

    let reset_request = client
        .post("/api/v1/password/reset/request")
        .json(&json!({
            "email": "password-flow@example.com"
        }))
        .send()
        .await;
    reset_request.assert_status_success();
    let reset_payload: serde_json::Value = reset_request.assert_json();
    let reset_code = reset_payload["code"]
        .as_str()
        .expect("reset code")
        .to_string();

    client
        .post("/api/v1/password/reset/confirm")
        .json(&json!({
            "email": "password-flow@example.com",
            "code": reset_code,
            "new_password": "final-pass"
        }))
        .send()
        .await
        .assert_status_success();

    client
        .post("/api/v1/login")
        .header("x-forwarded-for", "127.0.0.1")
        .json(&json!({
            "email": "password-flow@example.com",
            "password": "final-pass"
        }))
        .send()
        .await
        .assert_status_success();
}

#[tokio::test]
async fn notification_read_and_read_all_update_read_at() {
    let database = build_test_database().await;
    let admin = insert_user(&database, "admin", "notify-admin@example.com", "Admin").await;
    let student = insert_user(
        &database,
        "student",
        "notify-student@example.com",
        "Student",
    )
    .await;
    let admin_cookie = insert_session(&database, admin).await;
    let student_cookie = insert_session(&database, student).await;
    let client = test_client(database);

    let first = client
        .post("/api/v1/notification")
        .header("Cookie", &admin_cookie)
        .json(&json!({
            "user": student.to_string(),
            "title": "First",
            "content": "Hello 1"
        }))
        .send()
        .await;
    first.assert_status_success();
    let first_json: serde_json::Value = first.assert_json();
    let first_id = first_json["id"].as_str().expect("first id").to_string();

    client
        .post("/api/v1/notification")
        .header("Cookie", &admin_cookie)
        .json(&json!({
            "user": student.to_string(),
            "title": "Second",
            "content": "Hello 2"
        }))
        .send()
        .await
        .assert_status_success();

    let list_before = client
        .get("/api/v1/notification")
        .header("Cookie", &student_cookie)
        .send()
        .await;
    list_before.assert_status_success();
    let before_json: serde_json::Value = list_before.assert_json();
    assert!(before_json
        .as_array()
        .expect("notification array")
        .iter()
        .all(|item| item["read_at"].is_null()));

    client
        .post(&format!("/api/v1/notification/{first_id}/read"))
        .header("Cookie", &student_cookie)
        .send()
        .await
        .assert_status_success();

    let list_after_one = client
        .get("/api/v1/notification")
        .header("Cookie", &student_cookie)
        .send()
        .await;
    list_after_one.assert_status_success();
    let after_one: serde_json::Value = list_after_one.assert_json();
    assert!(after_one
        .as_array()
        .expect("notification array")
        .iter()
        .any(|item| item["id"].as_str() == Some(first_id.as_str()) && item["read_at"].is_string()));

    client
        .post("/api/v1/notification/read_all")
        .header("Cookie", &student_cookie)
        .send()
        .await
        .assert_status_success();
    let list_after_all = client
        .get("/api/v1/notification")
        .header("Cookie", &student_cookie)
        .send()
        .await;
    list_after_all.assert_status_success();
    let after_all: serde_json::Value = list_after_all.assert_json();
    assert!(after_all
        .as_array()
        .expect("notification array")
        .iter()
        .all(|item| item["read_at"].is_string()));
}

#[tokio::test]
async fn admin_can_delete_activity_comment() {
    let database = build_test_database().await;
    let owner = insert_user(&database, "student", "comment-owner@example.com", "Owner").await;
    let author = insert_user(&database, "student", "comment-author@example.com", "Author").await;
    let admin = insert_user(&database, "admin", "comment-admin@example.com", "Admin").await;
    let activity = insert_activity(&database, owner, "Comment Govern", "need_volunteer", 60).await;
    let comment_id = insert_comment(&database, activity, author, "to be removed").await;
    let admin_cookie = insert_session(&database, admin).await;
    let client = test_client(database.clone());

    client
        .delete(&format!("/api/v1/activity/{activity}/comment/{comment_id}"))
        .header("Cookie", &admin_cookie)
        .send()
        .await
        .assert_status_success();

    let row = sqlx::query(
        database
            .sql("SELECT 1 FROM activity_comments WHERE id = ?1")
            .as_ref(),
    )
    .bind(comment_id.to_string())
    .fetch_optional(database.sqlx())
    .await
    .expect("fetch deleted comment");
    assert!(row.is_none());
}

#[tokio::test]
async fn authority_group_update_changes_auth_check_result() {
    let database = build_test_database().await;
    let admin = insert_user(
        &database,
        "admin",
        "authority-admin@example.com",
        "Authority Admin",
    )
    .await;
    let student = insert_user(
        &database,
        "student",
        "authority-student@example.com",
        "Authority Student",
    )
    .await;
    let admin_cookie = insert_session(&database, admin).await;
    let student_cookie = insert_session(&database, student).await;
    let client = test_client(database);

    client
        .put("/api/v1/auth/groups/student")
        .header("Cookie", &admin_cookie)
        .json(&json!({
            "allow_all_authorities": false,
            "authorities": ["view_user", "send_notification"]
        }))
        .send()
        .await
        .assert_status_success();

    let check_view_user = client
        .get("/api/v1/auth/check/view_user")
        .header("Cookie", &student_cookie)
        .send()
        .await;
    check_view_user.assert_status_success();
    check_view_user.assert_json_path("result", &json!(true));

    let check_create_activity = client
        .get("/api/v1/auth/check/create_activity")
        .header("Cookie", &student_cookie)
        .send()
        .await;
    check_create_activity.assert_status_success();
    check_create_activity.assert_json_path("result", &json!(false));
}
