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

Passwords are never stored in plaintext. `bcrypt` generates a salted one-way hash at registration, and login verification uses its constant-time comparison. The deliberate slowness of bcrypt raises the cost of brute-force attacks.

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

A database query on a demo account shows the stored value is a bcrypt hash, not the plaintext (identifiable by the `$2b$` prefix and 60-character length):

```
SELECT id, email, password_hash FROM users WHERE email = 'demo@ulink.cn';

 id       | email            | password_hash
----------+------------------+--------------------------------------------------------------
 a1b2c3d4 | demo@ulink.cn   | $2b$12$LJ3m5Eqv8rW.kZ7xYpN2duGv0KQHf1jR9oVwXs6cT4bU8MnPqWe2i
```

#align(center)[#emph[Database query result: the password column contains only the irreversible bcrypt hash]]

== _2. Authority-based access control_

Every protected action is guarded on the server by an authority check, not only by UI hiding. This centralises permission rules and blocks privileged actions even if the UI is bypassed.

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

The React admin panel renders a permission-aware sidebar: menu items the current user cannot invoke are never shown. The admin sees every tab and cohort-wide statistics; the teacher sees a scoped sidebar and own-activity statistics only.

#evidence-pair(
  "assets/admin-home-viewport.png",
  "assets/teacher-home-viewport.png",
  left-caption: [Admin view: all menu items and global statistics],
  right-caption: [Teacher view: scoped menu and own-activity statistics],
)

== _3. Activity lifecycle and capacity-safe application flow_

Activities carry an explicit state and only legal transitions are accepted. Sign-up runs inside a transaction that locks the activity row, reads the counter, inserts the record, and increments the counter atomically, so the capacity check and counter update cannot race.

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

Both clients surface the same lifecycle. The admin panel uses a wide list+detail workspace; the SwiftUI client presents the detail as a native grouped list in landscape.

#evidence-pair(
  "assets/admin-activities-viewport.png",
  "assets/ipad-activity-detail.png",
  left-caption: [Admin-side: list + detail + records in one workspace],
  right-caption: [iPad student-side: native grouped-list activity detail in landscape],
)

The iPad client splits the student flow across two tabs so that "what can I sign up for?" and "what am I already part of?" never share a screen. Explore shows only recruiting activities; My Activities shows the student's own records with human-readable status capsules. Both feed into the same activity detail view.

#evidence-pair(
  "assets/ipad-feed-landscape-final.png",
  "assets/records-preview.png",
  left-caption: [Explore tab: public recruiting board fed by `display_all=false`],
  right-caption: [My Activities tab: per-record progress with human-readable status copy and tappable rows],
)

== _4. Activity-scoped messaging with live delivery_

One channel per activity replaces the client's previous scattering of WeChat and email. Membership is tied to the organiser and enrolled volunteers; messages are broadcast through Server-Sent Events for live delivery, and the channel auto-archives once the activity is completed.

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

Consecutive messages from the same sender are grouped, and teacher posts carry a badge so students can distinguish organiser announcements from peer replies. The timeline re-renders live through the SSE stream when either client posts.

#evidence-pair(
  "assets/admin-chats-viewport.png",
  "assets/ipad-channel.png",
  left-caption: [Admin-side: chat workspace with room list and teacher badges],
  right-caption: [iPad student-side: same channel, native message bubbles in landscape],
)

== _5. Derived leaderboard and export adapter_

There is no editable total-hours field. The leaderboard is summed from confirmed records at query time, which keeps the ranking consistent with the authoritative attendance data, and the same records are serialised into ISMAS-compatible CSV.

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

Running the export endpoint against the demo database produces one CSV row per confirmed record, with the column order matching the ISMAS import template:

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
  image("assets/ipad-leaderboard.png", width: 100%),
  caption: [Student-side leaderboard on iPad in landscape --- podium for the top three volunteers and a ranked list of the rest of the cohort],
)

#figure(
  image("assets/admin-users-viewport.png", width: 100%),
  caption: [Admin-side user management with the Students/Teachers/All segmented filter, total-count summary, and dialog-based Create User and batch-action flows],
)

== _6. Use of third-party libraries_

Standard infrastructure is delegated to well-maintained libraries rather than reimplemented:

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
+ *Beta testing* was conducted with a small group of student volunteers who used the system for one week before the final client meeting. The feedback from this round confirmed that the core apply-approve-confirm loop worked under real classroom conditions and did not surface any blocking issues before the evaluation interview.

== _Debugging example: transaction deadlock in concurrent sign-up_

During integration testing of SC-5, two simultaneous sign-ups to the same activity sometimes hung instead of returning a clean rejection. Server logs reported a transaction timeout after 30 seconds. Adding an index to `records` did not help. Tracing the transaction showed two code paths were acquiring row locks in inconsistent order --- one locked `activities` first, the other locked `records` first --- producing a classic deadlock. The fix was to enforce a single lock order: always `SELECT ... FOR UPDATE` on `activities` before inserting into `records`:

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
