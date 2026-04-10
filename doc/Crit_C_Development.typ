#set document(title: "Criterion C: Development")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.1em, justify: true)
#set raw(block: true, theme: auto)
#set enum(spacing: 0.9em)

#import "@preview/wordometer:0.1.5": word-count, total-words

#let navy = rgb("#183153")

// Two-up figure layout: pairs a product screenshot with a complementary
// piece of evidence (another screenshot, terminal output, or UI state) so
// each technique explanation has multiple visual anchors rather than a
// single screenshot.
#let evidence-pair(left, right, left-caption: none, right-caption: none) = {
  grid(
    columns: (1fr, 1fr),
    column-gutter: 10pt,
    figure(image(left, width: 100%), caption: left-caption),
    figure(image(right, width: 100%), caption: right-caption),
  )
}

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#show raw.where(block: true): it => block(
  breakable: false,
  width: 100%,
  inset: 12pt,
  fill: rgb("#05070a"),
  stroke: 0.5pt + rgb("#1a2433"),
  radius: 4pt,
)[
  #set text(fill: rgb("#f5f7fa"))
  #it
]

#show: word-count.with(exclude: (heading, figure, raw, <no-wc>))

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION C#text(weight: "regular")[: DEVELOPMENT]]
]

#outline()

= Techniques Used

+ Rust with async request handling for the backend API
+ SwiftUI for the native iPad client
+ React with TypeScript for browser-based staff workflows
+ SQLx with relational persistence in PostgreSQL
+ Bcrypt password hashing
+ Authority-based access control
+ Server-Sent Events for live updates
+ Transaction-based concurrency control
+ CSV export generation for ISMAS reporting

= Areas of Complexity

+ Secure account registration and login verification
+ Authority checks for volunteer and organiser workflows
+ Activity lifecycle control through explicit state transitions
+ Capacity-safe sign-up logic under concurrent access
+ Activity-scoped messaging with live delivery
+ Leaderboard aggregation from confirmed participation records
+ Configurable export generation from relational data

NOTE: Please refer to _Appendix 3_ for the complete source code.

= Explanation of Use of Complex Techniques

== _1. Secure password storage and verification_

The system stores personal data for students and organisers, so plain-text passwords would be unacceptable. During registration, the server passes the password through bcrypt, which internally generates a unique salt and produces a one-way hash. During login, the submitted password is verified against the stored hash using bcrypt's built-in comparison. This means the original password is never persisted, which reduces the damage if the database is exposed. Bcrypt is deliberately slow compared to general-purpose hash functions, making brute-force attacks impractical.

```rust
pub fn hash_password(password: &str) -> Result<String, BcryptError> {
    hash(password, DEFAULT_COST)
}
```

#align(center)[#emph[Code snippet: Creating a bcrypt password hash during registration]]

```rust
if verify_password(&form.password, &password_hash)
    .expect("bcrypt verify password")
{
    let session = generate_session(&database, &user_id, ip.0).await;
    Ok(Json(LoginResponse { session }))
} else {
    Err(LoginError::WrongPassword)
}
```

#align(center)[#emph[Code snippet: Verifying credentials without storing the original password]]

#figure(
  image("assets/auth-preview-compact.png", width: 100%),
  caption: [The registration and login interface on iPad, where user credentials are submitted over HTTPS],
)

The following database query output demonstrates that the stored value is a bcrypt hash, not the original password. The `$2b$` prefix, cost factor, and 60-character length are characteristic of bcrypt output:

```
SELECT id, email, password_hash FROM users WHERE email = 'demo@ulink.cn';

 id       | email            | password_hash
----------+------------------+--------------------------------------------------------------
 a1b2c3d4 | demo@ulink.cn   | $2b$12$LJ3m5Eqv8rW.kZ7xYpN2duGv0KQHf1jR9oVwXs6cT4bU8MnPqWe2i
```

#align(center)[#emph[Database query result: the password column contains only the irreversible bcrypt hash]]

== _2. Authority-based access control_

The client required a clear distinction between volunteers and organisers. Instead of hiding buttons only in the UI, the server checks whether the current user has the authority required for each protected action. This is more reliable because permission rules stay centralised on the backend, and privileged actions remain blocked even if a user tries to bypass the interface.

```rust
pub async fn ensure_authority(&self, authority: &str) -> Result<(), AuthError> {
    if self.match_authority(authority).await? {
        Ok(())
    } else {
        Err(AuthError::Forbidden)
    }
}
```

#align(center)[#emph[Code snippet: Rejecting protected actions when authority is missing]]

```rust
if promoter_hex == auth.uid().to_string()
    || auth.match_authority("manage_activity_anyway").await
        .map_err(|_| ManageActivityError::Forbidden)?
{
    Ok(())
} else {
    Err(ManageActivityError::Forbidden)
}
```

#align(center)[#emph[Code snippet: Allowing activity management only to the owner or a privileged organiser]]

Because every authority check runs on the server, the React admin panel can also build a permission-aware interface: menu items that the current user cannot actually invoke are never rendered, so teachers simply do not see the Users and Operations tabs that only administrators can open. The pair of screenshots below was captured on the same build of the admin dashboard using the demo seed. The first shows the System Administrator account, which has `allow_all_authorities` set and therefore sees all five navigation items, aggregate statistics, and the "Needs attention" queue across all organisers. The second shows a teacher account whose group has `create_activity`, `create_channel`, and `generate_export` but no user- or operations-level authorities; the teacher sidebar collapses to three items and the home page numbers reflect only activities that the teacher personally promoted.

#evidence-pair(
  "assets/admin-home-viewport.png",
  "assets/teacher-home-viewport.png",
  left-caption: [Admin view: all menu items and global statistics],
  right-caption: [Teacher view: scoped menu and own-activity statistics],
)

== _3. Activity lifecycle and capacity-safe application flow_

The spreadsheet-based process described in Criterion A could not prevent invalid state changes or overbooking. To solve this, the server models activities with explicit states and only allows legal transitions such as `NeedVolunteer -> Going -> Ended` or cancellation. Sign-up is handled inside a transaction, so checking capacity, creating the record, and incrementing the participant count happen atomically.

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

#align(center)[#emph[Code snippet: Enforcing valid activity state transitions]]

```rust
if let Some(max) = row.try_get::<Option<i64>, _>("max_volunteer_num").expect("Database error") {
    if volunteer_num >= max {
        let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        return Err(JoinActivityError::Full);
    }
}
```

#align(center)[#emph[Code snippet: Rejecting applications when capacity has been reached]]

#figure(
  image("assets/admin-activities-viewport.png", width: 100%),
  caption: [Organiser-facing workflow for managing published activities and their lifecycle],
)

== _4. Activity-scoped messaging with live delivery_

A major client problem was fragmented communication across email, WeChat, and private chats. The solution is one scoped channel per activity. The server creates the channel, keeps membership tied to the organiser and relevant volunteers, stores each message in the database, and broadcasts new messages through Server-Sent Events so connected clients update immediately.

```rust
let can_post = channel::ensure_channel_member(&database, &channel_id, &auth.uid()).await
    || auth.match_authority("send_message_anyway").await
        .map_err(|_| PostMessageError::Forbidden)?;
if !can_post {
    return Err(PostMessageError::Forbidden);
}
```

#align(center)[#emph[Code snippet: Checking membership before a message can be sent]]

```rust
pub async fn subscribe(&self, user: Id) -> Sse {
    let (sender, sse) = Sse::channel();
    let mut senders = self.inner.senders.write().await;
    senders.entry(user).or_default().push(sender);
    sse
}
```

#align(center)[#emph[Code snippet: Registering an SSE stream for real-time updates]]

The final rendering of the channel in the React admin panel is shown below. Consecutive messages from the same sender are grouped under one avatar and timestamp, teacher posts carry an explicit teacher badge so students can tell the organiser's announcements apart from peer replies, and the left rail lists the activity-bound channels the current user has access to. The timeline updates live through the SSE push stream, so the view below re-renders as new messages are written on either the iPad client or the web panel.

#figure(
  image("assets/admin-chats-viewport.png", width: 100%),
  caption: [Admin-side activity channel with grouped messages, teacher badges, and live SSE updates],
)

== _5. Derived leaderboard and export adapter_

The system avoids storing a manually edited total-hours field. Instead, leaderboard rankings are calculated from confirmed participation records, which keeps the displayed ranking consistent with the authoritative attendance data. The same confirmed records are then transformed into CSV output for ISMAS reporting. This separation between stored data and generated output makes the system more reliable and easier to extend.

```sql
SELECT
    users.id, users.realname, users.classname,
    COALESCE(users.avatar_path, '') AS avatar_path,
    records.confirmed_minutes
FROM records
JOIN users ON users.id = records.user_id
WHERE records.state = 'confirmed'
```

#align(center)[#emph[Code snippet: Reading confirmed participation records for leaderboard generation]]

```rust
let mut result: Vec<_> = totals.into_values().collect();
result.sort_by(|a, b| b.total_minutes.cmp(&a.total_minutes));
```

#align(center)[#emph[Code snippet: Sorting volunteers by confirmed total minutes]]

```rust
let mut csv = String::from(
    "student_identifier,student_name,class_name,activity_title,\
     activity_date,confirmed_minutes,organiser_confirmation_timestamp\n"
);
```

#align(center)[#emph[Code snippet: Building an ISMAS-compatible export file]]

Running the export endpoint against the demo database produces rows of the shape below. Each confirmed record in the database turns into exactly one CSV row, and the column order matches the ISMAS import template so that the file can be uploaded without further transformation.

```
student_identifier,student_name,class_name,activity_title,activity_date,confirmed_minutes,organiser_confirmation_timestamp
"6b2a…","Alex Zhang","11C","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:49:41Z"
"7a1e…","Harper Zhang","12A","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:50:41Z"
"9c88…","Morgan Lin","10C","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:51:41Z"
"d0f1…","Logan Xu","12B","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:52:41Z"
"e23c…","Jordan Wang","11B","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:53:41Z"
"f44d…","Avery Liu","12B","Primary School Reading Buddy Session 04","2026-04-06",150,"2026-04-05T21:54:41Z"
```

#align(center)[#emph[CSV output from the export endpoint run against the demo database]]

#figure(
  image("assets/admin-users-viewport.png", width: 100%),
  caption: [Admin-side user management with the Students/Teachers/All filter and the inline Create User form],
)

== _6. Use of third-party libraries_

The project also relies on several third-party libraries so that standard infrastructure does not need to be reimplemented manually. This keeps the codebase shorter, more reliable, and easier to maintain.

+ `bcrypt` is used for password hashing and verification rather than implementing a custom credential-storage algorithm.
+ `sqlx` is used for asynchronous database queries, transaction handling, and parameter binding across SQLite and PostgreSQL backends.
+ `csv` is used to generate the export spreadsheet format required for the ISMAS import workflow.
+ `utoipa` is used to derive OpenAPI schema information from Rust types and handlers instead of maintaining separate API documentation by hand.
+ `@tanstack/react-query` is used in the admin interface to manage server state and keep organiser/admin screens synchronized with backend data.

= Testing Strategy and Debugging Process

== _Testing approach_

The project used a layered testing strategy to verify correctness at different levels:

+ *Backend unit tests* validate individual business rules --- such as state-transition legality, capacity enforcement, and authority checks --- in isolation from the network layer.
+ *Integration tests* run HTTP requests against a live server instance with a test database, verifying that authentication, session management, and API contracts behave correctly end-to-end.
+ *SwiftUI XCUITest* automates key iPad user journeys (registration, browsing the feed, applying to an activity) to catch layout regressions and navigation bugs on device.
+ *Alpha testing* was conducted by the developer during implementation: each feature slice was tested manually on a real iPad before moving to the next slice.
+ *Beta testing* was conducted with a small group of student volunteers who used the system for one week before the final client meeting, providing feedback that surfaced the portrait-mode density issue documented in Appendix 2.

== _Debugging example: transaction deadlock in concurrent sign-up_

During integration testing of the capacity-protection logic (SC-5), two simultaneous sign-up requests to the same activity occasionally caused one request to hang indefinitely instead of returning a rejection. The server logs showed:

```
2025-12-04T14:22:08Z ERROR server::activity: transaction timeout
  after 30s for activity_id=8f3a...
  request_id=req-1702, user_id=c91b...
```

The initial hypothesis was a missing index on the `records` table, but adding the index did not resolve the issue. Closer inspection of the transaction logic revealed that the capacity check and the record insertion were acquiring row-level locks in inconsistent order: one code path locked the `activities` row first, while another locked the `records` row first, creating a classic deadlock scenario.

The fix was to ensure that every transaction acquires locks in a consistent order --- always locking the `activities` row (via `SELECT ... FOR UPDATE`) before inserting into `records`:

```rust
// Always lock the activity row first to prevent deadlock
let row = sqlx::query(
    "SELECT volunteer_num, max_volunteer_num
     FROM activities WHERE id = $1 FOR UPDATE"
)
.bind(&activity_id)
.fetch_one(&mut *conn)
.await?;
```

#align(center)[#emph[Code snippet: Acquiring a row-level lock on the activity before checking capacity]]

After this change, the deadlock was eliminated and all concurrent sign-up integration tests passed consistently.

= Sources

+ Apple Inc. "SwiftUI." Apple Developer Documentation. https://developer.apple.com/documentation/swiftui
+ The Rust Programming Language. https://doc.rust-lang.org/book/
+ SQLx --- Async SQL toolkit for Rust. https://github.com/launchbadge/sqlx
+ React. https://react.dev
+ PostgreSQL Documentation. https://www.postgresql.org/docs/
+ Server-Sent Events. MDN Web Docs. https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
