#set document(title: "Criterion C: Development")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.4em, justify: true)
#set enum(spacing: 2em)

#import "@preview/wordometer:0.1.5": word-count, total-words

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#show: word-count.with(exclude: (heading, figure, raw, <no-wc>))

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION C#text(weight: "regular")[: DEVELOPMENT]]
]

#outline()

#pagebreak()

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

#pagebreak()

= Areas of Complexity

+ Secure account registration and login verification
+ Authority checks for volunteer and organiser workflows
+ Activity lifecycle control through explicit state transitions
+ Capacity-safe sign-up logic under concurrent access
+ Activity-scoped messaging with live delivery
+ Leaderboard aggregation from confirmed participation records
+ Configurable export generation from relational data

NOTE: Please refer to _Appendix 3_ for the complete source code.

#pagebreak()

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

#figure(
  image("assets/manage-preview.png", width: 94%),
  caption: [The organiser workspace exposes management actions that are not available to ordinary volunteers],
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
  image("assets/admin-activities-viewport.png", width: 94%),
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

#figure(
  image("assets/ipad-feed-landscape-final.png", width: 94%),
  caption: [The native iPad client provides the shared communication and activity experience in one interface],
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
WHERE records.state = 'done'
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

#figure(
  image("assets/admin-operations-viewport.png", width: 94%),
  caption: [Administrative export workflow supporting school reporting requirements],
)

== _6. Use of third-party libraries_

The project also relies on several third-party libraries so that standard infrastructure does not need to be reimplemented manually. This keeps the codebase shorter, more reliable, and easier to maintain.

+ `bcrypt` is used for password hashing and verification rather than implementing a custom credential-storage algorithm.
+ `sqlx` is used for asynchronous database queries, transaction handling, and parameter binding across SQLite and PostgreSQL backends.
+ `csv` is used to generate the export spreadsheet format required for the ISMAS import workflow.
+ `utoipa` is used to derive OpenAPI schema information from Rust types and handlers instead of maintaining separate API documentation by hand.
+ `@tanstack/react-query` is used in the admin interface to manage server state and keep organiser/admin screens synchronized with backend data.

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
