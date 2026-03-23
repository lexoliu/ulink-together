#set document(title: "Criterion C: Development")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.4em, justify: true)
#set enum(spacing: 2em)

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION C#text(weight: "regular")[: DEVELOPMENT]]
]

#outline()

#pagebreak()

= Techniques Used

The development of the volunteer management system required a combination of backend, frontend, database, security, and integration techniques. These techniques were selected to solve the specific problems identified by the client in Criterion A: fragmented communication, manual hour confirmation, overbooking, lack of role separation, and the inefficient semester-end reporting process.

+ Rust programming language for the backend server with async runtime (Tokio)
+ SwiftUI for building the native iPad volunteer interface
+ React with TypeScript for the web-based organiser admin panel
+ PostgreSQL / SQLite relational databases via SQLx for data persistence
+ Salted SHA-256 password hashing for secure credential storage
+ Server-Sent Events (SSE) for real-time push notifications
+ Role-based access control via group authorities
+ Database transactions with serialised locking for concurrency control
+ Finite state machine pattern for activity lifecycle management
+ RESTful API design with JSON request/response payloads
+ CSV export adapter for school reporting system integration
+ ObservableObject pattern in SwiftUI for reactive state management

#pagebreak()

= Areas of Complexity

The following areas represent the most technically complex parts of the system. They correspond directly to the success criteria and to the client's operational problems described in Criterion A.

+ Salted password hashing during registration and login verification
+ Role-based access control distinguishing volunteers and organisers
+ Activity creation with state machine governing lifecycle transitions
+ Capacity-protected apply flow using database transactions to prevent overbooking
+ Activity-scoped messaging channels with membership enforcement
+ Real-time notification delivery via Server-Sent Events
+ Leaderboard ranking by aggregating confirmed participation hours
+ Configurable CSV export adapter for ISMAS-compatible hour reporting
+ Reactive SwiftUI session architecture with centralised state management
+ Web-based admin panel with activity and student management

NOTE: Please refer to _Appendix 3_ for the complete source code.

#pagebreak()

= Explanation of Use of Complex Techniques

== _1. Salted password hashing during registration and login verification_

The client required the system to handle student and organiser accounts securely because the application stores personal information such as names, class identifiers, and school email addresses. Storing passwords in plain text would create an unacceptable risk: if the database were ever exposed, every user's credentials would be immediately compromised. To prevent this, the server generates a unique random salt for each account during registration and combines it with the user's password before hashing it with SHA-256. Only the resulting hash and the salt are stored; the original password is never persisted.

This design is necessary because many students reuse passwords across services. By using a per-user salt, identical passwords do not produce identical hashes, which makes bulk attacks and precomputed rainbow-table attacks far less effective. During login, the system retrieves the stored salt, recomputes the hash from the submitted password, and compares it with the stored hash. This allows the server to verify identity without ever needing to recover the original password.

```rust
pub async fn register(
    database: State<AppDatabase>,
    form: Json<RegisterPayload>,
) -> Result<ApiMessage, RegisterError> {
    let Json(form) = form;
    let salt = rand_string(16);
    let password = sha256(form.password.clone() + &salt);
    // ... insert user with password_hash and salt
}
```

#align(center)[#emph[Code snippet: Hashing a password with a per-user salt during registration]]

```rust
let password_hash: String = row.get("password_hash");
let salt: String = row.get("salt");

if sha256(form.password + &salt) == password_hash {
    let session = generate_session(&database, &user_id, ip.0).await;
    Ok(Json(LoginResponse { session }))
} else {
    Err(LoginError::WrongPassword)
}
```

#align(center)[#emph[Code snippet: Recomputing the salted hash during login verification]]

#align(center)[#emph[Code snippets: Hashing with a per-user salt during registration (top) and verifying credentials during login (bottom)]]

== _2. Role-based access control distinguishing volunteers and organisers_

A core requirement from Criterion A is that volunteers and organisers must not have the same permissions. Volunteers should only be able to browse activities, apply, and read information relevant to them, while organisers and administrators must be able to create activities, manage applications, confirm attendance, and export reports. Without a role-based access control system, any authenticated user could potentially access privileged functions, making the application unsafe and unusable in a school environment.

To solve this, each user is assigned to a group, such as student, organiser, or administrator. Each group is associated with a set of named authorities stored in the database. Before a protected action is executed, the server checks whether the current user's group contains the required authority. This keeps permission logic centralised rather than scattering manual role checks throughout the codebase. The same mechanism also supports an `allow_all_authorities` flag, which gives administrators a superuser capability without duplicating each authority entry manually.

```rust
pub async fn ensure_authority(&self, authority: &str) -> Result<(), AuthError> {
    if self.match_authority(authority).await? {
        Ok(())
    } else {
        Err(AuthError::Forbidden)
    }
}
```

#align(center)[#emph[Code snippet: Rejecting a request if the current user lacks the required authority]]

```rust
let allow_all: i64 = row.get("allow_all_authorities");
if allow_all != 0 {
    return Ok(true);
}

let has_authority = sqlx::query(
    database.sql(
        "SELECT 1 FROM group_authorities WHERE group_id = ?1 AND authority = ?2 LIMIT 1"
    ).as_ref(),
)
.bind(&group_hex)
.bind(authority)
.fetch_optional(pool)
.await
.expect("Database error")
.is_some();
```

#align(center)[#emph[Code snippet: Looking up an authority in the `group_authorities` table]]

```rust
async fn ensure_manage_activity(
    database: &AppDatabase, auth: &Auth, activity_id: Id,
) -> Result<(), ManageActivityError> {
    let promoter_hex: String = row.try_get("promoter_id").expect("Database error");
    if promoter_hex == auth.uid().to_string()
        || auth.match_authority("manage_activity_anyway").await
            .map_err(|_| ManageActivityError::Forbidden)?
    {
        Ok(())
    } else {
        Err(ManageActivityError::Forbidden)
    }
}
```

#align(center)[#emph[Code snippet: Allowing activity management only to the owner or a privileged organiser]]

== _3. Activity lifecycle state machine_

The client needs activities to follow a controlled process rather than changing unpredictably. In the current spreadsheet-based workflow, an activity may be announced, filled, canceled, or completed without any formal constraint on what should happen next. This creates ambiguity for volunteers and organisers, especially when attendance confirmation or cancellation occurs after students have already signed up. To solve this, the server models each activity as a finite state machine.

The state machine restricts an activity to a small set of valid states: `NeedVolunteer`, `Going`, `Ended`, and `Canceled`. The `can_transition` function explicitly defines which transitions are legal. This prevents invalid actions such as moving an ended activity back to an active sign-up state. The server also applies cascading updates when an activity is canceled, ensuring that related participation records are marked canceled as well. This maintains consistency between the activity itself and the student participation records attached to it.

```rust
fn can_transition(current: ActivityState, target: ActivityState) -> bool {
    match current {
        ActivityState::NeedVolunteer => {
            matches!(target, ActivityState::Going | ActivityState::Canceled)
        }
        ActivityState::Going => {
            matches!(target, ActivityState::Ended | ActivityState::Canceled)
        }
        ActivityState::Ended | ActivityState::Canceled => false,
    }
}
```

#align(center)[#emph[Code snippet: Validating legal lifecycle transitions using pattern matching]]

```rust
if target_state == ActivityState::Canceled {
    sqlx::query(database.sql(
        "UPDATE records SET state = 'canceled', confirmed_minutes = 0, \
         confirmed_at = NULL, confirmed_by = NULL, updated_at = ?1 \
         WHERE activity_id = ?2 AND state != 'done'"
    ).as_ref())
    .bind(time::OffsetDateTime::now_utc().to_string())
    .bind(id.to_string())
    .execute(database.sqlx()).await.expect("Database error");
}
```

#align(center)[#emph[Code snippet: Cascading cancellation to participation records when an activity is canceled]]

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity state transition diagram showing NeedVolunteer → Going → Ended with Canceled branch]]
]

== _4. Capacity-protected apply flow using database transactions_

One of the client's clearest problems in Criterion A was overbooking. When sign-ups were tracked manually in a shared spreadsheet, several students could appear to claim the last place at the same time because there was no atomic server-side check. This is a concurrency problem: two users can submit requests almost simultaneously, and if the system checks capacity and updates the count in separate steps, both requests may succeed incorrectly.

To prevent this, the entire join flow is wrapped inside a database transaction. The transaction checks the activity state, verifies that places are still available, detects duplicate or previously canceled records, inserts or reactivates the participation record, increments the volunteer count, and commits only if every step succeeds. On SQLite, `BEGIN IMMEDIATE` acquires the write lock at the start so another writer cannot intervene mid-process. On PostgreSQL, the transactional sequence achieves the same consistency guarantee through serialised writes. This ensures the capacity value is always accurate even when many volunteers apply at once.

```rust
let begin_stmt = match database.kind() {
    DatabaseKind::Sqlite => "BEGIN IMMEDIATE",
    DatabaseKind::Postgres => "BEGIN",
};
sqlx::query(begin_stmt).execute(&mut *conn).await.expect("Database error");

// Fetch current capacity
let volunteer_num = row.try_get::<i64, _>("volunteer_num").expect("Database error");
if let Some(max) = row.try_get::<Option<i64>, _>("max_volunteer_num").expect("Database error") {
    if volunteer_num >= max {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(JoinActivityError::Full);
    }
}
```

#align(center)[#emph[Code snippet: Starting a transaction and rejecting the request if the activity is already full]]

```rust
// Check for existing record (re-join after cancellation)
match existing {
    Some(row) => {
        let existing_state = row.try_get::<String, _>("state").expect("Database error");
        if RecordState::from_db(&existing_state) != Some(RecordState::Canceled) {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
            return Err(JoinActivityError::AlreadyJoined);
        }
        // Re-activate the canceled record
        sqlx::query(database.sql(
            "UPDATE records SET state = ?1, updated_at = ?2 WHERE id = ?3"
        ).as_ref())
        .bind(RecordState::Todo.as_str())
        .execute(&mut *conn).await.expect("Database error");
    }
    None => {
        record::create_record(&database, &mut *conn, auth.uid(), activity_id).await?;
    }
}
// Increment count and commit
sqlx::query(database.sql(
    "UPDATE activities SET volunteer_num = volunteer_num + 1 WHERE id = ?1"
).as_ref())
.bind(activity_id.to_string())
.execute(&mut *conn).await.expect("Database error");
sqlx::query("COMMIT").execute(&mut *conn).await.expect("Database error");
```

#align(center)[#emph[Code snippet: Detecting duplicate applications, updating the record atomically, and committing the transaction]]

== _5. Activity-scoped messaging channels with membership enforcement_

The client explained in Criterion A that communication is currently fragmented across email, WeChat groups, and private chats. This makes it difficult to keep an authoritative record of logistics, schedule changes, or cancellations for each volunteer activity. To solve this, the system provides an activity-scoped messaging channel so that every activity has one shared communication space tied directly to the participants involved.

The server creates the channel automatically when it is first needed and adds the organiser together with all accepted volunteers as members. Before any message is posted, it verifies that the sender is a valid channel member or has an overriding administrative authority. This is important because activity discussions may contain private logistical information that should not be visible to unrelated students. Messages are stored in the database for persistence and are also pushed to live clients via SSE, giving the system both a permanent record and immediate delivery.

```rust
pub async fn ensure_activity_channel(
    database: &AppDatabase, owner_id: Id, activity_id: Id, activity_name: &str,
) -> Result<Id, sqlx::Error> {
    if let Some(existing) = activity_channel(database, activity_id).await
        .map_err(|_| sqlx::Error::Protocol("Corrupted activity channel id".into()))? {
        return Ok(existing);
    }
    let id = Id::new();
    sqlx::query(database.sql(
        "INSERT INTO channels (id, name, owner_id, activity_id, created_at) VALUES (?1, ?2, ?3, ?4, ?5)"
    ).as_ref())
    .bind(id.to_string())
    .bind(format!("{activity_name} Channel"))
    .bind(owner_id.to_string())
    .bind(activity_id.to_string())
    .execute(database.sqlx()).await?;
    // Add organiser and all volunteers as members
    ensure_channel_membership(database, id, owner_id).await?;
    for volunteer in record::get_volunteers(database, activity_id).await? {
        ensure_channel_membership(database, id, volunteer).await?;
    }
    Ok(id)
}
```

#align(center)[#emph[Code snippet: Creating an activity channel and populating it with the organiser and volunteers]]

```rust
let can_post = channel::ensure_channel_member(&database, &channel_id, &auth.uid()).await
    || auth.match_authority("send_message_anyway").await
        .map_err(|_| PostMessageError::Forbidden)?;
if !can_post {
    return Err(PostMessageError::Forbidden);
}
// Persist and push
sqlx::query(database.sql(
    "INSERT INTO messages (id, channel_id, sender_id, content, sent_at) VALUES (?1, ?2, ?3, ?4, ?5)"
).as_ref())
.bind(id.to_string()).bind(channel_id.to_string())
.bind(auth.uid().to_string()).bind(&content).bind(&now)
.execute(database.sqlx()).await.expect("Database error");
push_message_to_channel(&database, &hub, &channel_id, &push_payload).await;
```

#align(center)[#emph[Code snippet: Enforcing membership before persisting and broadcasting a message]]

== _6. Real-time notification delivery via Server-Sent Events_

The client needed students to receive updates quickly when an organiser changes an activity, sends a new message, or pushes a notification through the system. If the app relied only on periodic polling, students could see stale information and organisers would not be confident that important changes had reached volunteers in time. This is particularly problematic in a school setting where students may only check the app briefly between lessons.

To address this, the server uses Server-Sent Events (SSE), which keep a lightweight persistent connection open from the server to the client. When the user subscribes, the server stores a sender handle associated with that user's ID. Later, when a message or notification needs to be delivered, the server serialises the event and writes it to all active SSE streams for that user. If a stream fails, it is removed automatically. This provides real-time updates without the overhead of constant polling and keeps all connected devices synchronised with server-side changes.

```rust
pub async fn subscribe(&self, user: Id) -> Sse {
    let (sender, sse) = Sse::channel();
    let mut senders = self.inner.senders.write().await;
    senders.entry(user).or_default().push(sender);
    sse
}
```

#align(center)[#emph[Code snippet: Registering an SSE sender for a connected user]]

```rust
async fn send_data_to_user(&self, user: Id, event: &str, data: &str) {
    let mut senders = {
        let mut map = self.inner.senders.write().await;
        map.get_mut(&user).map(mem::take).unwrap_or_default()
    };
    let mut alive = Vec::with_capacity(senders.len());
    for sender in senders.drain(..) {
        let event = Event::data(data).event(event);
        if sender.send(event).await.is_ok() {
            alive.push(sender);
        }
    }
    if !alive.is_empty() {
        let mut map = self.inner.senders.write().await;
        map.entry(user).or_default().extend(alive);
    }
}
```

#align(center)[#emph[Code snippet: Broadcasting an event and pruning dead SSE connections]]

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Notification appearing in real time on the iPad app when an organiser approves a volunteer application]]
]

== _7. Leaderboard ranking by aggregating confirmed participation hours_

The volunteer leaderboard is intended to motivate students and provide organisers with a quick overview of participation. However, storing a separate "total hours" field for each student would create a risk of inconsistency: if a participation record were edited, canceled, or confirmed after the total had already been updated, the stored total could become stale. In a system where confirmed hours are also used for school reporting, this would be unacceptable.

The system therefore computes leaderboard totals directly from completed participation records. The SQL query retrieves every `done` record joined with the user's profile information, and Rust aggregates the `confirmed_minutes` values by user inside a hash map. After aggregation, the server sorts the result in descending order and assigns ranks. This approach is more reliable because it derives the ranking from the authoritative source of truth every time, ensuring the leaderboard and reporting outputs always match the confirmed attendance data.

```sql
SELECT
    users.id, users.realname, users.classname,
    COALESCE(users.avatar_path, '') AS avatar_path,
    records.confirmed_minutes
FROM records
JOIN users ON users.id = records.user_id
WHERE records.state = 'done'
ORDER BY users.realname ASC
```

#align(center)[#emph[Code snippet: Querying all completed participation records for leaderboard calculation]]

```rust
let mut totals: HashMap<Id, LeaderboardEntry> = HashMap::new();
for row in rows {
    let user: Id = row.try_get::<String, _>("id")?.parse()?;
    let entry = totals.entry(user).or_insert_with(|| LeaderboardEntry {
        rank: 0, user,
        realname: row.try_get("realname").expect("Database error"),
        classname: row.try_get("classname").expect("Database error"),
        avatar: /* ... */,
        total_minutes: 0,
    });
    entry.total_minutes += row.try_get::<i64, _>("confirmed_minutes")? as u32;
}
let mut result: Vec<_> = totals.into_values().collect();
result.sort_by(|a, b| b.total_minutes.cmp(&a.total_minutes));
```

#align(center)[#emph[Code snippet: Grouping completed minutes by user and sorting the leaderboard in descending order]]

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Leaderboard screen on iPad showing ranked volunteers with total hours]]
]

== _8. Configurable CSV export adapter for ISMAS-compatible reporting_

The semester-end reporting workflow was one of the client's biggest pain points in Criterion A. She currently has to copy confirmed volunteer hours manually into the school's ISMAS system, which is repetitive and error-prone. Because this reporting requirement comes from an external school system, the volunteer management application must be able to transform its internal data into a format that ISMAS can import directly.

The export adapter solves this by querying all completed records, joining the relevant user and activity fields, and generating CSV output with the exact column structure required by the target reporting workflow. The adapter approach is important because export formats may change over time, or the school may later require different schemas for different departments. By separating data collection from output formatting, the design remains extensible instead of hardwiring the reporting logic into unrelated parts of the application.

```sql
SELECT
    records.user_id, records.activity_id,
    users.realname, users.classname,
    activities.name AS activity_title,
    activities.date AS activity_date,
    records.confirmed_minutes, records.confirmed_at
FROM records
JOIN users ON users.id = records.user_id
JOIN activities ON activities.id = records.activity_id
WHERE records.state = 'done' AND records.confirmed_minutes > 0
ORDER BY users.classname ASC, users.realname ASC
```

#align(center)[#emph[Code snippet: Gathering the confirmed attendance data needed for the export]]

```rust
let mut csv = String::from(
    "student_identifier,student_name,class_name,activity_title,\
     activity_date,confirmed_minutes,organiser_confirmation_timestamp\n"
);
for item in &items {
    csv.push_str(&format!(
        "{},{},{},{},{},{},{}\n",
        csv_escape(&item.user.to_string()),
        csv_escape(&item.student_name),
        csv_escape(&item.class_name),
        csv_escape(&item.activity_title),
        csv_escape(item.activity_date.as_deref().unwrap_or("")),
        item.confirmed_minutes,
        csv_escape(item.confirmed_at.as_deref().unwrap_or("")),
    ));
}
```

#align(center)[#emph[Code snippet: Serialising the export rows into an ISMAS-compatible CSV file]]

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Export dialog and generated CSV file preview]]
]

== _9. Reactive SwiftUI session architecture_

The client required an iPad-based volunteer interface because students always carry school-managed iPads during the day. In a native app, authentication and user profile state must remain consistent across multiple screens such as sign-in, activity browsing, messaging, and profile pages. If each screen loaded and cached its own copy of session state independently, the app could easily become inconsistent after sign-in, sign-out, or authority changes.

To avoid this, the iPad app uses a central `SessionStore` implemented as an `ObservableObject`. It tracks the current application phase, the signed-in user's profile, and cached authority results. SwiftUI views observe this store and automatically redraw when any published property changes. This is essential for usability: when a user signs in, the interface can switch immediately from the launch or sign-out flow to the main activity feed, and when the user signs out the navigation stack can reset without manual refresh logic in each individual screen.

```swift
@MainActor
final class SessionStore: ObservableObject {
    enum Phase: Sendable {
        case launching
        case signedOut
        case signedIn
    }

    let apiClient = APIClient()
    let pushClient = PushClient()

    @Published var phase: Phase = .launching
    @Published var currentUser: UserProfile?
    @Published var authorityCache: [String: Bool] = [:]
}
```

#align(center)[#emph[Code snippet: Centralising authentication phase and user state in a single observable store]]

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: SwiftUI app showing the activity feed after sign-in with the session store driving the navigation]]
]

== _10. Web-based admin panel_

Although the volunteer-facing interface is a native iPad app, the client and other staff members also need a more capable management interface for tasks such as creating activities, reviewing students, managing records, inspecting communication, and performing batch operations. Staff use a range of devices, including school-managed Windows machines, so a native Apple-only interface would not satisfy this requirement. A web-based admin panel is therefore necessary to provide cross-platform access without installation.

The admin panel is built as a React single-page application with TypeScript, which is appropriate for interactive forms, filtered lists, and data-heavy management views. This architecture allows organisers and administrators to work efficiently on larger screens while sharing the same backend API and permission model as the iPad app. In practical terms, this separates the two major usage contexts of the system: quick volunteer interactions on iPad and more complex administrative workflows on desktop-class browsers.

#rect(width: 100%, height: 200pt, stroke: 0.5pt + luma(180))[
  #align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Admin panel showing the Activities management view]]
]

#pagebreak()

= Sources

+ Apple Inc. "SwiftUI." Apple Developer Documentation. https://developer.apple.com/documentation/swiftui
+ The Rust Programming Language. https://doc.rust-lang.org/book/
+ SQLx --- Async SQL toolkit for Rust. https://github.com/launchbadge/sqlx
+ React. https://react.dev
+ PostgreSQL Documentation. https://www.postgresql.org/docs/
+ Server-Sent Events. MDN Web Docs. https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
