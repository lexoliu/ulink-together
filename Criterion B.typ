#import "@preview/pintorita:0.1.4"
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#set document(title: "Criterion B: Solution Overview")
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.5cm))
#set text(font: "New Computer Modern", size: 10pt)
#set heading(numbering: "1.1")
#set table(stroke: 0.5pt + gray, inset: 5pt)
#set par(leading: 0.55em)

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 16pt, weight: "bold", it)
  v(0.4em)
}

#show heading.where(level: 2): it => {
  v(0.6em)
  text(size: 12pt, weight: "bold", it)
  v(0.2em)
}

#show heading.where(level: 3): it => {
  v(0.4em)
  text(size: 11pt, weight: "bold", it)
  v(0.15em)
}

#align(center)[
  #text(size: 20pt, weight: "bold")[Criterion B: Solution Overview]
  #v(1em)
]

= Record of Tasks

#set text(size: 9pt)
#table(
  columns: (auto, auto, auto, 1.2fr, 2fr, 1fr, 1.2fr),
  align: (center, center, center, left, left, left, left),
  inset: 5pt,
  table.header(
    [*No.*], [*Date*], [*Phase*], [*Task*], [*Process*], [*Deliverable*], [*Reflection*]
  ),
  [1], [Week 1], [Plan],
  [Initial client meeting and requirements gathering],
  [Met with school administrator and student council to discuss current pain points. Documented fragmented workflows across DingTalk, forums, and physical posters. Identified key user roles: volunteers and organizers.],
  [Requirements document, user personas, initial success criteria draft],
  [Need to prioritize features. The ISMAS export requirement is critical for adoption.],

  [2], [Week 2], [Plan],
  [Technology stack research and selection],
  [Evaluated frameworks: compared SwiftUI vs Flutter for iOS client, Rust vs Node.js for backend, PostgreSQL vs MongoDB for database. Prioritized type safety, performance, and native iPad experience.],
  [Technology decision document],
  [Chose SwiftUI for native performance, Rust for memory safety, PostgreSQL for relational integrity. Need to design database schema.],

  [3], [Week 3], [Design],
  [Database schema design],
  [Designed entity-relationship model covering users, activities, records, channels, and messages. Identified primary/foreign key relationships. Planned for state machines in activities and records.],
  [ERD diagram, SQL schema draft],
  [Schema needs review for normalization. Will implement group-based permissions system.],

  [4], [Week 4], [Design],
  [API endpoint architecture],
  [Designed RESTful API structure with authentication middleware. Planned session-based auth with secure cookie handling. Documented all endpoints with OpenAPI specification.],
  [API specification document, route structure],
  [Need to implement real-time push for messages. Will use SSE instead of WebSocket for simplicity.],

  [5], [Week 5-6], [Develop],
  [Core authentication system],
  [Implemented user registration with SHA256 password hashing and random salt. Created session management with cookie-based authentication. Built group-authority permission system.],
  [`auth.rs`, `login.rs`, `user.rs` modules],
  [Testing revealed need for better error messages. Refactored error types with clear HTTP status codes.],

  [6], [Week 7-8], [Develop],
  [Activity management module],
  [Implemented CRUD operations for activities. Built state machine: NeedVolunteer -> Going -> Ended / Canceled. Added promoter authorization checks.],
  [`activity.rs` module with full API],
  [Activity listing was slow. Optimized with SQL indexing and selective field queries.],

  [7], [Week 9], [Develop],
  [Volunteer record system],
  [Implemented join activity logic with transaction-based capacity checking. Created record state management: Todo -> Done / Canceled.],
  [`record.rs` module],
  [Found race condition in concurrent joins. Fixed with database transactions (BEGIN IMMEDIATE for SQLite).],

  [8], [Week 10], [Develop],
  [Communication channels and messaging],
  [Built channel creation linked to activities. Implemented message posting with membership validation. Added real-time push via Server-Sent Events.],
  [`channel.rs`, `message.rs`, `push.rs` modules],
  [Real-time push working but needs cleanup on disconnect. Added dead sender detection.],

  [9], [Week 11], [Develop],
  [Comments and notifications],
  [Implemented activity comment system. Built notification storage and delivery. Integrated push notifications for new messages.],
  [`comment.rs`, `notification.rs` modules],
  [Comments need pagination for large threads. Added ORDER BY created_at DESC.],

  [10], [Week 12], [Test],
  [Unit testing implementation],
  [Wrote unit tests for authentication, registration, record creation, and volunteer filtering. Used in-memory SQLite for isolated tests.],
  [Test suite with 6 test functions],
  [Tests uncovered bug in canceled state spelling variants. Added backwards compatibility parsing.],

  [11], [Week 13], [Test],
  [Integration testing with client],
  [Conducted end-to-end testing with SwiftUI client prototype. Verified activity creation visibility timing (under 5 seconds). Tested on iPadOS 17.5.],
  [Test results document, bug reports],
  [Found session cookie path issue. Fixed by setting explicit path="/" on cookies.],

  [12], [Week 14], [Develop],
  [Bug fixes and iteration],
  [Fixed identified issues: cookie path, state spelling variants, error message clarity. Improved database connection pooling.],
  [Updated codebase with fixes],
  [All critical bugs resolved. Ready for user acceptance testing.],

  [13], [Week 15], [Test],
  [User acceptance testing],
  [Conducted testing with 5 volunteer students and 2 organizers. Measured task completion rates, collected feedback on UI.],
  [UAT feedback document],
  [Users found activity joining intuitive. Suggested adding leaderboard feature.],

  [14], [Week 16], [Develop],
  [Leaderboard implementation],
  [Designed hours aggregation query. Implemented leaderboard endpoint with ranking by total completed hours.],
  [Leaderboard API endpoint],
  [Query optimized with proper indexing on records table.],

  [15], [Week 17], [Implement],
  [Production deployment preparation],
  [Configured PostgreSQL for production. Set up database migrations. Documented deployment process.],
  [Deployment guide, production config],
  [Ready for pilot deployment.],
)
#set text(size: 10pt)

= Design Overview

== Solution Architecture

The system follows a *client-server architecture* with clear separation between the presentation layer (SwiftUI client) and business logic layer (Rust server).

#figure(
  box(fill: rgb("#fafafa"), inset: 12pt, radius: 8pt, stroke: 1pt + rgb("#e5e5e5"))[
    #set text(size: 9pt)
    #grid(columns: (1fr, auto, 1fr, auto, 1fr), rows: (auto, 8pt, auto), gutter: 8pt,
      // Row 1: Client - arrows - Server - arrow - External
      box(fill: rgb("#dbeafe"), stroke: 1.5pt + rgb("#3b82f6"), radius: 8pt, inset: 10pt)[
        #align(center)[
          #text(size: 14pt)[#box(width: 20pt, height: 28pt, stroke: 1pt + rgb("#3b82f6"), radius: 3pt, fill: white)[]]
          \ *iPad Client* \ #text(size: 7pt, fill: rgb("#6b7280"))[SwiftUI]
        ]
      ],
      align(horizon)[#text(size: 8pt)[REST #sym.arrow.r \ #sym.arrow.l SSE]],
      box(fill: rgb("#ede9fe"), stroke: 1.5pt + rgb("#8b5cf6"), radius: 8pt, inset: 10pt)[
        #align(center)[
          #stack(dir: ttb, spacing: 2pt,
            box(width: 24pt, height: 8pt, fill: rgb("#8b5cf6"), radius: 2pt),
            box(width: 24pt, height: 8pt, fill: rgb("#8b5cf6"), radius: 2pt),
          )
          \ *Rust Server* \ #text(size: 7pt, fill: rgb("#6b7280"))[Skyzen]
        ]
      ],
      align(horizon)[#text(size: 8pt)[Export #sym.arrow.r.dashed]],
      box(fill: rgb("#fef3c7"), stroke: (dash: "dashed", paint: rgb("#f59e0b"), thickness: 1.5pt), radius: 8pt, inset: 10pt)[
        #align(center)[
          #text(size: 14pt, fill: rgb("#f59e0b"))[#sym.compose.o]
          \ *ISMAS* \ #text(size: 7pt, fill: rgb("#6b7280"))[External]
        ]
      ],
      // Row 2: spacer
      [], [], [], [], [],
      // Row 3: Cache - empty - Database
      box(fill: rgb("#fce7f3"), stroke: 1.5pt + rgb("#ec4899"), radius: 8pt, inset: 8pt)[
        #align(center)[#text(size: 12pt)[#sym.square.stroked.dotted] \ *Local Cache*]
      ],
      align(horizon + center)[#sym.arrow.t],
      box(fill: rgb("#fee2e2"), stroke: 1.5pt + rgb("#ef4444"), radius: 8pt, inset: 8pt)[
        #align(center)[
          #stack(dir: ttb, spacing: 1pt,
            box(width: 20pt, height: 4pt, fill: rgb("#ef4444"), radius: (top: 4pt)),
            box(width: 20pt, height: 10pt, fill: rgb("#fecaca")),
          )
          \ *PostgreSQL*
        ]
      ],
      [], [],
    )
  ],
  caption: [System Architecture Diagram]
)

=== Component Description

#table(
  columns: (1fr, 1.2fr, 2fr),
  table.header([*Component*], [*Technology*], [*Responsibility*]),
  [*SwiftUI Client*], [Swift/SwiftUI, iPadOS 17.5+], [User interface, local state management, API communication],
  [*Rust Server*], [Rust, Skyzen framework], [Business logic, authentication, API endpoints, real-time push],
  [*Database*], [PostgreSQL (prod) / SQLite (dev)], [Persistent data storage, referential integrity],
  [*Push Hub*], [Server-Sent Events (SSE)], [Real-time message delivery to connected clients],
)

=== Module Structure (Server)

#let mod-box(name, desc, color) = box(
  fill: color.lighten(85%),
  stroke: 1pt + color,
  radius: 4pt,
  inset: 5pt,
  width: 100%,
)[#text(weight: "bold", size: 8pt)[#name] #h(1fr) #text(size: 7pt, fill: rgb("#666"))[#desc]]

#figure(
  box(inset: 10pt, radius: 8pt, fill: rgb("#f9fafb"), stroke: 1pt + rgb("#e5e7eb"))[
    #set text(size: 8pt)
    #grid(columns: (1fr, 1fr, 1fr), gutter: 6pt,
      // Entry Point
      box(stroke: 2pt + rgb("#6366f1"), fill: rgb("#eef2ff"), radius: 6pt, inset: 8pt)[
        #align(center)[#text(weight: "bold")[main.rs] \ #text(size: 7pt, fill: rgb("#666"))[Entry + Routes]]
      ],
      grid.cell(colspan: 2)[],

      // Core Layer
      grid.cell(colspan: 3)[
        #v(4pt)
        #text(size: 7pt, fill: rgb("#9ca3af"))[CORE SERVICES]
        #line(length: 100%, stroke: 0.5pt + rgb("#e5e7eb"))
      ],
      mod-box("auth", "Middleware", rgb("#f59e0b")),
      mod-box("login", "Sessions", rgb("#f59e0b")),
      mod-box("database", "SQL Dialect", rgb("#f59e0b")),

      // Business Layer
      grid.cell(colspan: 3)[
        #v(4pt)
        #text(size: 7pt, fill: rgb("#9ca3af"))[BUSINESS LOGIC]
        #line(length: 100%, stroke: 0.5pt + rgb("#e5e7eb"))
      ],
      mod-box("user", "CRUD", rgb("#10b981")),
      mod-box("activity", "State Machine", rgb("#10b981")),
      mod-box("record", "Volunteer Tracking", rgb("#10b981")),

      // Communication Layer
      grid.cell(colspan: 3)[
        #v(4pt)
        #text(size: 7pt, fill: rgb("#9ca3af"))[COMMUNICATION]
        #line(length: 100%, stroke: 0.5pt + rgb("#e5e7eb"))
      ],
      mod-box("channel", "Channels", rgb("#3b82f6")),
      mod-box("message", "Messages", rgb("#3b82f6")),
      mod-box("push", "SSE Hub", rgb("#3b82f6")),

      // Support Layer
      grid.cell(colspan: 3)[
        #v(4pt)
        #text(size: 7pt, fill: rgb("#9ca3af"))[SUPPORT]
        #line(length: 100%, stroke: 0.5pt + rgb("#e5e7eb"))
      ],
      mod-box("comment", "Comments", rgb("#8b5cf6")),
      mod-box("notification", "Notifications", rgb("#8b5cf6")),
      mod-box("resource", "Files", rgb("#8b5cf6")),
    )
  ],
  caption: [Server Module Architecture]
)

== Key User Flows

=== Flow 1: User Registration (Success Criterion \#1)

*Trigger*: User opens app and selects "Register"

#figure(
  pintorita.render(
```
sequenceDiagram
  participant User
  participant Client
  participant Server
  participant DB

  User ->> Client: Enter form data
  Client ->> Server: POST /api/v1/user
  Server ->> Server: Generate 16-char salt
  Server ->> Server: Hash password (SHA256)
  Server ->> DB: INSERT user record
  DB -->> Server: Success
  Server -->> Client: 200 OK + message
  Client -->> User: Show success
```.text
  ),
  caption: [User Registration Sequence Diagram]
)

*Steps*:
+ User enters email, realname, password, gender, classname
+ Client validates input format locally
+ Client sends POST request to `/api/v1/user`
+ Server generates 16-character random salt
+ Server computes `password_hash = SHA256(password + salt)`
+ Server assigns default "student" group
+ Server inserts user record into database
+ Server returns success message
+ Client navigates to login screen

*Boundary Conditions*:
- Email must be unique (returns "User already exists" if duplicate)
- Student group must exist in database (returns 500 if missing)

=== Flow 2: Activity Publication (Success Criterion \#2)

*Trigger*: Organizer creates new activity

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Organizer
  participant Client
  participant Server
  participant DB

  Organizer ->> Client: Fill activity form
  Client ->> Server: POST /api/v1/activity
  Server ->> DB: Validate session
  DB -->> Server: User ID + Group ID
  Server ->> DB: Check authority
  DB -->> Server: Authority granted
  Server ->> DB: INSERT activity
  DB -->> Server: Activity created
  Server -->> Client: 200 OK + Activity detail
  Client -->> Organizer: Show success
```.text
  ),
  caption: [Activity Publication Sequence Diagram]
)

*Steps*:
+ Organizer enters name, date, location, description, max volunteers, duration
+ Client sends POST with session cookie
+ Server validates session, extracts user ID
+ Server checks `create_activity` authority for user's group
+ Server inserts activity with state = "need_volunteer"
+ Server returns created activity detail with ID
+ Activity immediately visible in volunteer listing

*Data Written*:
- `id`: New UUID
- `promoter_id`: Authenticated user's ID
- `state`: "need_volunteer"
- `volunteer_num`: 0

=== Flow 3: Volunteer Joining Activity (Success Criterion \#3)

*Trigger*: Volunteer clicks "Join" on activity

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Volunteer
  participant Client
  participant Server
  participant DB

  Volunteer ->> Client: Click Join button
  Client ->> Server: POST /activity/{id}/apply
  Server ->> DB: BEGIN TRANSACTION
  Server ->> DB: SELECT capacity
  DB -->> Server: volunteer_num, max

  alt Activity is full
    Server -->> Client: 403 Activity is full
  else Already joined
    Server ->> DB: Check existing record
    Server -->> Client: 403 Already joined
  else Success
    Server ->> DB: INSERT record
    Server ->> DB: UPDATE volunteer_num
    Server ->> DB: COMMIT
    Server -->> Client: 200 OK Joined
  end

  Client -->> Volunteer: Show result
```.text
  ),
  caption: [Volunteer Joining Sequence Diagram]
)

*Critical Logic* (Transaction-based):
```
BEGIN IMMEDIATE TRANSACTION
  1. SELECT volunteer_num, max_volunteer_num FROM activities WHERE id = ?
  2. IF volunteer_num >= max_volunteer_num: ROLLBACK, return "Full"
  3. SELECT 1 FROM records WHERE activity_id = ? AND user_id = ?
  4. IF exists: ROLLBACK, return "Already joined"
  5. INSERT INTO records (id, activity_id, user_id, state) VALUES (?, ?, ?, 'todo')
  6. UPDATE activities SET volunteer_num = volunteer_num + 1 WHERE id = ?
COMMIT
```

*Boundary Conditions*:
- Activity must exist (404 if not found)
- Activity must not be full (403 if at capacity)
- User must not have already joined (403 if duplicate)

=== Flow 4: Real-time Messaging (Success Criterion \#4)

*Trigger*: Participant sends message in activity channel

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Sender
  participant Server
  participant DB
  participant PushHub
  participant Others

  Sender ->> Server: POST /channel/{id}
  Server ->> DB: Verify membership
  DB -->> Server: Confirmed
  Server ->> DB: INSERT message
  DB -->> Server: Stored
  Server ->> DB: SELECT members
  DB -->> Server: Member IDs
  Server ->> PushHub: Send to all
  PushHub -->> Others: SSE event
  Server -->> Sender: 200 OK
```.text
  ),
  caption: [Real-time Messaging Sequence Diagram]
)

*Push Mechanism*:
- Clients connect to `/api/v1/push` endpoint (SSE)
- Server maintains HashMap of user ID -> active SSE senders
- On message post, server looks up all channel members
- Sends JSON payload to each connected member via SSE

== Data Design

=== Entity-Relationship Diagram

#figure(
  scale(x: 75%, y: 75%, reflow: true,
    pintorita.render(
```
erDiagram

groups {
  id TEXT PK
  code TEXT
  allow_all_authorities INT
}

users {
  id TEXT PK
  email TEXT UK
  realname TEXT
  gender TEXT
  password_hash TEXT
  salt TEXT
  group_id TEXT FK
}

sessions {
  id TEXT PK
  user_id TEXT FK
  generated_at TEXT
  ip TEXT
}

activities {
  id TEXT PK
  promoter_id TEXT FK
  name TEXT
  state TEXT
  volunteer_num INT
  max_volunteer_num INT
  duration_minutes INT
}

records {
  id TEXT PK
  activity_id TEXT FK
  user_id TEXT FK
  state TEXT
  updated_at TEXT
}

channels {
  id TEXT PK
  activity_id TEXT FK
  owner_id TEXT FK
  name TEXT
}

messages {
  id TEXT PK
  channel_id TEXT FK
  sender_id TEXT FK
  content TEXT
  sent_at TEXT
}

groups ||--o{ users : contains
users ||--o{ sessions : has
users ||--o{ activities : promotes
users ||--o{ records : participates
activities ||--o{ records : has
activities ||--o| channels : has
channels ||--o{ messages : contains
users ||--o{ messages : sends
```.text
    )
  ),
  caption: [Entity-Relationship Diagram]
)

=== Table Specifications

#table(
  columns: (auto, auto, auto, 1.2fr, 1.5fr),
  table.header([*Table*], [*Field*], [*Type*], [*Constraints*], [*Description*]),
  table.cell(rowspan: 9)[*users*],
    [id], [TEXT], [PRIMARY KEY], [UUID v4 as hex string],
    [email], [TEXT], [NOT NULL, UNIQUE], [Login credential],
    [realname], [TEXT], [NOT NULL], [Display name],
    [gender], [TEXT], [NOT NULL], ["male"/"female"/"other"],
    [description], [TEXT], [NOT NULL], [User bio],
    [classname], [TEXT], [NOT NULL], [School class],
    [password_hash], [TEXT], [NOT NULL], [SHA256(password + salt)],
    [salt], [TEXT], [NOT NULL], [16-char random string],
    [group_id], [TEXT], [NOT NULL, FK], [References groups.id],
  table.cell(rowspan: 11)[*activities*],
    [id], [TEXT], [PRIMARY KEY], [UUID v4],
    [promoter_id], [TEXT], [NOT NULL, FK], [References users.id],
    [name], [TEXT], [NOT NULL], [Activity title],
    [location], [TEXT], [NOT NULL], [Venue],
    [state], [TEXT], [NOT NULL], ["need_volunteer"/"going"/"ended"/"canceled"],
    [volunteer_num], [INTEGER], [NOT NULL, DEFAULT 0], [Current volunteer count],
    [max_volunteer_num], [INTEGER], [NULLABLE], [Capacity limit (NULL = unlimited)],
    [date], [TEXT], [NULLABLE], [Scheduled date],
    [description], [TEXT], [NOT NULL], [Full description],
    [brief_description], [TEXT], [NOT NULL], [Summary for listing],
    [duration_minutes], [INTEGER], [NOT NULL], [Duration in minutes],
  table.cell(rowspan: 5)[*records*],
    [id], [TEXT], [PRIMARY KEY], [UUID v4],
    [activity_id], [TEXT], [NOT NULL, FK], [References activities.id],
    [user_id], [TEXT], [NOT NULL, FK], [References users.id],
    [state], [TEXT], [NOT NULL], ["todo"/"done"/"canceled"],
    [updated_at], [TEXT], [NOT NULL], [ISO 8601 timestamp],
)

=== Data Constraints

+ *Email Uniqueness*: Enforced at database level with UNIQUE constraint
+ *Password Security*: Never stored in plaintext; salt is per-user random
+ *Volunteer Capacity*: Enforced via transaction with check before insert
+ *State Validity*: Enum-like validation in application layer with `from_db()` parser

== Algorithmic / Logic Design

=== Algorithm 1: Password Hashing

*Purpose*: Secure storage of user credentials

*Input*: `password: String`, `salt: String` \
*Output*: `hash: String` (64-character hex)

```
FUNCTION hash_password(password, salt):
    combined = password + salt
    hash_bytes = SHA256(combined)
    RETURN hex_encode(hash_bytes)

FUNCTION verify_password(input_password, stored_hash, stored_salt):
    computed_hash = hash_password(input_password, stored_salt)
    RETURN computed_hash == stored_hash
```

*Security Consideration*: Each user has unique random salt, preventing rainbow table attacks.

=== Algorithm 2: Activity State Machine

*Purpose*: Control valid state transitions for activities

*States*: `NeedVolunteer`, `Going`, `Ended`, `Canceled`

#figure(
  pintorita.render(
```
activityDiagram
start
:Activity Created;
:NeedVolunteer;
if (Start?) then (yes)
  :Going;
  if (Complete?) then (yes)
    :Ended;
    note right: Hours recorded
  else (cancel)
    :Canceled;
    note right: No hours
  endif
else (cancel)
  :Canceled;
endif
end
```.text
  ),
  caption: [Activity State Machine]
)

*Transition Rules*:
```
FUNCTION can_transition(current_state, target_state):
    IF current_state == NeedVolunteer:
        RETURN target_state IN {Going, Canceled}
    ELSE IF current_state == Going:
        RETURN target_state IN {Ended, Canceled}
    ELSE:
        RETURN FALSE  // Terminal states cannot transition
```

=== Algorithm 3: Concurrent Join Protection

*Purpose*: Prevent race conditions when multiple volunteers join simultaneously

*Problem*: Without protection, two users might both pass the capacity check and both join, exceeding the limit.

*Solution*: Database transaction with exclusive lock

```
FUNCTION join_activity(user_id, activity_id):
    BEGIN IMMEDIATE TRANSACTION  // Acquires exclusive lock on SQLite

    activity = SELECT volunteer_num, max_volunteer_num
               FROM activities WHERE id = activity_id

    IF activity IS NULL:
        ROLLBACK
        RETURN Error("Activity not found")

    IF max_volunteer_num IS NOT NULL AND volunteer_num >= max_volunteer_num:
        ROLLBACK
        RETURN Error("Activity is full")

    existing = SELECT 1 FROM records
               WHERE activity_id = activity_id AND user_id = user_id

    IF existing IS NOT NULL:
        ROLLBACK
        RETURN Error("Already joined")

    INSERT INTO records (id, activity_id, user_id, state, updated_at)
        VALUES (new_uuid(), activity_id, user_id, 'todo', now())

    UPDATE activities SET volunteer_num = volunteer_num + 1
        WHERE id = activity_id

    COMMIT
    RETURN Success("Joined successfully")
```

*Time Complexity*: O(1) for all database operations (assuming indexed lookups)

=== Algorithm 4: Real-time Push Distribution

*Purpose*: Deliver messages to all channel members in real-time

*Data Structure*: `HashMap<UserId, Vec<SSE_Sender>>`

```
CLASS PushHub:
    senders: RwLock<HashMap<UserId, Vec<Sender>>>

    FUNCTION subscribe(user_id):
        (sender, sse_stream) = create_sse_channel()
        WITH senders.write_lock():
            senders[user_id].append(sender)
        RETURN sse_stream

    FUNCTION send_to_user(user_id, event_type, payload):
        json_data = serialize_json(payload)

        WITH senders.write_lock():
            user_senders = senders[user_id]
            senders[user_id] = []

        alive_senders = []
        FOR sender IN user_senders:
            event = SSE_Event(data=json_data, event=event_type)
            IF sender.send(event).is_ok():
                alive_senders.append(sender)

        WITH senders.write_lock():
            senders[user_id].extend(alive_senders)
```

*Key Design Choice*: Dead sender detection via send failure, automatic cleanup.

=== Algorithm 5: Leaderboard Ranking (Success Criterion \#5)

*Purpose*: Rank volunteers by total completed volunteer hours

```
FUNCTION get_leaderboard(limit):
    RETURN SQL:
        SELECT
            users.id,
            users.realname,
            SUM(activities.duration_minutes) as total_minutes
        FROM records
        JOIN activities ON records.activity_id = activities.id
        JOIN users ON records.user_id = users.id
        WHERE records.state = 'done'
        GROUP BY users.id
        ORDER BY total_minutes DESC
        LIMIT limit
```

*Index Recommendation*:
- `records(state)` for filtering done records
- `records(user_id)` for grouping

== UI/UX Design

=== Screen Overview

#table(
  columns: (1fr, 1fr, 2fr),
  table.header([*Screen*], [*Primary User*], [*Key Actions*]),
  [Login], [All], [Enter credentials, navigate to register],
  [Register], [New users], [Enter profile information],
  [Activity Square], [Volunteers], [Browse activities, filter, join],
  [Activity Detail], [All], [View details, join, comment],
  [My Records], [Volunteers], [View joined activities, status],
  [Create Activity], [Organizers], [Enter activity details, publish],
  [Manage Activity], [Organizers], [Edit, change state, view volunteers],
  [Channel], [Participants], [Send/receive messages],
  [Leaderboard], [All], [View rankings],
)

=== Wireframe: Activity Square

// Hand-drawn style wireframe with annotations
#let sketch-stroke = 1.5pt + rgb("#4a5568")
#let sketch-fill = rgb("#f7fafc")
#let accent = rgb("#3182ce")
#let annotation = rgb("#718096")

#figure(
  grid(columns: (3fr, 1fr), gutter: 15pt,
    // Main wireframe - iPad frame
    box(stroke: 3pt + rgb("#2d3748"), radius: 20pt, inset: 8pt, fill: rgb("#1a202c"))[
      #box(stroke: sketch-stroke, radius: 12pt, fill: sketch-fill, inset: 0pt, width: 100%)[
        // Status bar
        #box(width: 100%, fill: rgb("#edf2f7"), inset: 6pt)[
          #text(size: 7pt, fill: annotation)[9:41 AM #h(1fr) 100%]
        ]

        // Navigation bar
        #box(width: 100%, fill: white, inset: 8pt)[
          #grid(columns: (auto, 1fr, auto),
            text(size: 9pt, fill: accent)[< Back],
            align(center)[#text(weight: "bold", size: 11pt)[Activity Square]],
            text(size: 9pt, fill: accent)[Search]
          )
        ]
        #line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))

        // Content area
        #box(inset: 10pt)[
          // Activity Card 1
          #box(width: 100%, stroke: sketch-stroke, radius: 10pt, fill: white, inset: 10pt)[
            #box(width: 40pt, height: 40pt, fill: rgb("#bee3f8"), radius: 8pt, stroke: 1pt + accent)[
              #align(center + horizon)[
                // Photo icon: mountains + sun
                #box(width: 24pt, height: 18pt, stroke: 0.8pt + accent, radius: 2pt, fill: white, clip: true)[
                  #place(bottom + left, dy: 2pt)[#polygon(fill: rgb("#90cdf4"), (0pt, 10pt), (8pt, 3pt), (16pt, 10pt))]
                  #place(bottom + right, dy: 2pt, dx: -2pt)[#polygon(fill: accent, (0pt, 8pt), (5pt, 2pt), (10pt, 8pt))]
                  #place(top + right, dx: -4pt, dy: 3pt)[#circle(radius: 2.5pt, fill: rgb("#faf089"))]
                ]
              ]
            ]
            #h(8pt)
            #box(width: 100% - 55pt)[
              #text(weight: "bold", size: 10pt)[Campus Cleanup] \
              #text(size: 8pt, fill: annotation)[Main Building | Mar 15 | 2h] \
              #v(3pt)
              #box(width: 100%, height: 6pt, fill: rgb("#e2e8f0"), radius: 3pt)[
                #box(width: 25%, height: 6pt, fill: rgb("#48bb78"), radius: 3pt)[]
              ]
              #text(size: 7pt, fill: annotation)[5/20 volunteers]
            ]
            #v(6pt)
            #align(right)[#box(fill: accent, radius: 6pt, inset: (x: 12pt, y: 5pt))[
              #text(fill: white, size: 8pt, weight: "bold")[Join]
            ]]
          ]
          #v(8pt)

          // Activity Card 2
          #box(width: 100%, stroke: sketch-stroke, radius: 10pt, fill: white, inset: 10pt)[
            #box(width: 40pt, height: 40pt, fill: rgb("#feebc8"), radius: 8pt, stroke: 1pt + rgb("#ed8936"))[
              #align(center + horizon)[
                // Photo icon: mountains + sun (orange variant)
                #box(width: 24pt, height: 18pt, stroke: 0.8pt + rgb("#ed8936"), radius: 2pt, fill: white, clip: true)[
                  #place(bottom + left, dy: 2pt)[#polygon(fill: rgb("#fbd38d"), (0pt, 10pt), (8pt, 3pt), (16pt, 10pt))]
                  #place(bottom + right, dy: 2pt, dx: -2pt)[#polygon(fill: rgb("#ed8936"), (0pt, 8pt), (5pt, 2pt), (10pt, 8pt))]
                  #place(top + right, dx: -4pt, dy: 3pt)[#circle(radius: 2.5pt, fill: rgb("#faf089"))]
                ]
              ]
            ]
            #h(8pt)
            #box(width: 100% - 55pt)[
              #text(weight: "bold", size: 10pt)[Library Helper] \
              #text(size: 8pt, fill: annotation)[Library | Ongoing | 1h] \
              #v(3pt)
              #box(width: 100%, height: 6pt, fill: rgb("#e2e8f0"), radius: 3pt)[
                #box(width: 60%, height: 6pt, fill: rgb("#ed8936"), radius: 3pt)[]
              ]
              #text(size: 7pt, fill: annotation)[3/5 volunteers]
            ]
            #v(6pt)
            #align(right)[#box(fill: accent, radius: 6pt, inset: (x: 12pt, y: 5pt))[
              #text(fill: white, size: 8pt, weight: "bold")[Join]
            ]]
          ]
          #v(8pt)

          // Placeholder card
          #box(width: 100%, stroke: (dash: "dashed", paint: annotation, thickness: 1pt), radius: 10pt, inset: 15pt)[
            #align(center)[#text(fill: annotation, size: 9pt)[More activities...]]
          ]
        ]

        // Tab bar
        #line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))
        #box(width: 100%, fill: rgb("#f7fafc"), inset: 8pt)[
          #grid(columns: (1fr,) * 5, align: center,
            text(size: 8pt, fill: annotation)[Home],
            text(size: 8pt, fill: annotation)[Records],
            text(size: 8pt, fill: accent, weight: "bold")[Square],
            text(size: 8pt, fill: annotation)[Board],
            text(size: 8pt, fill: annotation)[Profile]
          )
        ]
      ]
    ],

    // Annotations
    align(left)[
      #set text(size: 8pt, fill: annotation)
      #v(20pt)
      *Navigation* \
      Title + back/search
      #v(25pt)
      *Activity Card* \
      - Thumbnail \
      - Title + meta \
      - Progress bar \
      - CTA button
      #v(40pt)
      *Tab Bar* \
      5 main sections
    ]
  ),
  caption: [Activity Square Screen - iPad Wireframe]
)

=== Input Validation

#table(
  columns: (auto, 1.5fr, 1.5fr),
  table.header([*Field*], [*Validation Rule*], [*Error Message*]),
  [Email], [Valid email format, unique], ["Invalid email format" / "Email already registered"],
  [Password], [Minimum 6 characters], ["Password must be at least 6 characters"],
  [Activity Name], [1-100 characters, required], ["Activity name is required"],
  [Max Volunteers], [Positive integer or empty], ["Must be a positive number"],
  [Duration], [Positive integer, required], ["Duration is required"],
)

=== Error Handling UX

- *Network Errors*: Show retry button with "Unable to connect. Tap to retry."
- *Session Expired*: Redirect to login with "Your session has expired. Please log in again."
- *Validation Errors*: Highlight field with red border, show message below field
- *Server Errors*: Show generic "Something went wrong. Please try again later."

= Outline Test Plan

== Test Case Mapping to Success Criteria

#table(
  columns: (auto, 1.5fr, 2fr),
  table.header([*Test ID*], [*Success Criterion*], [*Test Purpose*]),
  [T1.1-T1.3], [\#1 Account Registration], [Verify user creation and data storage],
  [T2.1-T2.3], [\#2 Task Publication], [Verify activity creation and visibility timing],
  [T3.1-T3.3], [\#3 Task Management], [Verify edit and cancel functionality],
  [T4.1-T4.3], [\#4 Communication], [Verify channel messaging and storage],
  [T5.1-T5.2], [\#5 Leaderboard], [Verify ranking accuracy and updates],
  [T6.1-T6.3], [\#6 Hour Tracking], [Verify automatic recording and export],
  [T7.1-T7.2], [\#7 Platform Compatibility], [Verify iPadOS 17.5+ operation],
)

== Detailed Test Cases

=== T1.1: Successful User Registration

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#1: A volunteer can create an account using their student information and avatar, and this data is stored securely in the database.],
  [*Test Purpose*], [Verify that a new user can register with valid information and the data is correctly stored.],
  [*Preconditions*], [- App is installed on iPadOS device \ - "student" group exists in database \ - Email "newuser\@ulink.edu.cn" is not registered],
  [*Test Data*], [email: "newuser\@ulink.edu.cn" \ realname: "Zhang Wei" \ password: "Test123!" \ gender: "male" \ classname: "G11-A"],
  [*Steps*], [1. Open app, tap "Register" \ 2. Enter all test data fields \ 3. Tap "Submit" \ 4. Query database for new user record],
  [*Expected Result*], [- Success message displayed \ - User record exists in `users` table \ - Password is hashed (not plaintext) \ - Salt is 16 characters \ - group_id matches "student" group],
  [*Actual Result*], [(To be completed during testing)],
  [*Pass/Fail Criteria*], [PASS if all expected results are met],
)

=== T1.2: Registration with Duplicate Email

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#1],
  [*Test Purpose*], [Verify that duplicate email registration is rejected.],
  [*Preconditions*], [User "existing\@ulink.edu.cn" already exists in database],
  [*Test Data*], [email: "existing\@ulink.edu.cn" \ realname: "Li Ming" \ password: "Test456!" \ gender: "female" \ classname: "G10-B"],
  [*Steps*], [1. Open app, tap "Register" \ 2. Enter test data with existing email \ 3. Tap "Submit"],
  [*Expected Result*], [- Error message "User already exists" displayed \ - No new record created in database],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if registration is rejected with appropriate error],
)

=== T1.3: Registration Input Validation

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#1],
  [*Test Purpose*], [Verify client-side validation of registration form.],
  [*Preconditions*], [App is at registration screen],
  [*Test Data*], [email: "invalid-email" \ password: "123" (too short)],
  [*Steps*], [1. Enter invalid email format \ 2. Enter password shorter than 6 characters \ 3. Attempt to submit],
  [*Expected Result*], [- Email field shows "Invalid email format" error \ - Password field shows "Password must be at least 6 characters" \ - Submit button disabled or submission prevented],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if validation errors are shown before submission],
)

=== T2.1: Successful Activity Publication

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#2: An organiser can publish a volunteer activity including attributes such as time, maximum participants, description, and duration, and it becomes visible to volunteers within five seconds.],
  [*Test Purpose*], [Verify activity creation and immediate visibility.],
  [*Preconditions*], [- User logged in as organizer (has "create_activity" authority) \ - Volunteer device logged in with different account],
  [*Test Data*], [name: "Test Activity" \ date: "2024-04-01" \ location: "Room 101" \ max_volunteer_num: 10 \ description: "Test description" \ duration: 60],
  [*Steps*], [1. Organizer: Create activity with test data \ 2. Start timer when "Submit" tapped \ 3. Volunteer: Refresh activity list \ 4. Stop timer when activity appears \ 5. Verify all data matches],
  [*Expected Result*], [- Activity created successfully \ - Visibility time < 5 seconds \ - All attributes displayed correctly \ - State is "need_volunteer" \ - Volunteer count is 0],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if activity visible within 5 seconds with correct data],
)

=== T2.2: Activity Publication without Authority

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#2],
  [*Test Purpose*], [Verify that users without organizer authority cannot create activities.],
  [*Preconditions*], [User logged in as regular volunteer (student group without "create_activity" authority)],
  [*Test Data*], [Any valid activity data],
  [*Steps*], [1. Attempt to access "Create Activity" screen or API],
  [*Expected Result*], [- "Forbidden" error returned \ - No activity created],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if creation is blocked],
)

=== T3.1: Activity State Change

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#3: An organiser can edit or cancel an existing activity, and the changes are reflected immediately to all volunteers.],
  [*Test Purpose*], [Verify activity state can be changed and updates propagate.],
  [*Preconditions*], [- Activity exists in "need_volunteer" state \ - Organizer is logged in as promoter of the activity],
  [*Test Data*], [Activity ID from precondition],
  [*Steps*], [1. Organizer: Change state to "going" \ 2. Volunteer: Refresh activity detail \ 3. Verify state changed],
  [*Expected Result*], [- State updated to "going" \ - Volunteer sees updated state immediately \ - Activity no longer appears in "recruiting" filter],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if state change is immediate and visible],
)

=== T3.2: Activity Cancellation

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#3],
  [*Test Purpose*], [Verify activity cancellation updates records.],
  [*Preconditions*], [- Activity exists with 3 joined volunteers \ - Organizer logged in],
  [*Steps*], [1. Organizer: Change activity state to "canceled" \ 2. Verify activity state in database \ 3. Volunteer: Check "My Records"],
  [*Expected Result*], [- Activity state is "canceled" \ - Activity hidden from active listings \ - Volunteer records remain for history],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if cancellation completes and records preserved],
)

=== T4.1: Message Posting and Storage

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#4: Participants can exchange messages within a channel associated with each activity, and these messages are stored in the system for future reference.],
  [*Test Purpose*], [Verify message posting and persistence.],
  [*Preconditions*], [- Channel exists for activity \ - User is member of channel],
  [*Test Data*], [content: "Hello, this is a test message!"],
  [*Steps*], [1. Post message to channel \ 2. Query database for message \ 3. Close app and reopen \ 4. Navigate to channel],
  [*Expected Result*], [- Message appears in channel immediately \ - Message exists in `messages` table \ - Message persists after app restart],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if message stored and retrievable],
)

=== T4.2: Real-time Message Push

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#4],
  [*Test Purpose*], [Verify real-time message delivery via SSE.],
  [*Preconditions*], [- Two users in same channel \ - Both connected to SSE push endpoint],
  [*Test Data*], [content: "Real-time test message"],
  [*Steps*], [1. User A: Post message \ 2. User B: Observe message arrival (without refresh)],
  [*Expected Result*], [- User B receives message without manual refresh \ - Message arrives within 2 seconds],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if message received in real-time],
)

=== T5.1: Leaderboard Accuracy

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#5: A leaderboard displays volunteers ranked by total recorded hours, updating automatically after each activity is completed.],
  [*Test Purpose*], [Verify leaderboard calculates and ranks correctly.],
  [*Preconditions*], [- User A has 5 hours (300 min) of completed activities \ - User B has 3 hours (180 min) \ - User C has 7 hours (420 min)],
  [*Steps*], [1. View leaderboard \ 2. Verify ranking order],
  [*Expected Result*], [- Order: User C (7h), User A (5h), User B (3h) \ - Hours displayed correctly],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if ranking order and hours are correct],
)

=== T5.2: Leaderboard Auto-Update

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#5],
  [*Test Purpose*], [Verify leaderboard updates after activity completion.],
  [*Preconditions*], [- User has 2 hours on leaderboard \ - User has record in "todo" state for 3-hour activity],
  [*Steps*], [1. View leaderboard, note user's hours (2h) \ 2. Organizer marks user's record as "done" \ 3. Refresh leaderboard],
  [*Expected Result*], [- User's hours update to 5 hours \ - Ranking position may change accordingly],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if hours updated after marking done],
)

=== T6.1: Automatic Hour Recording

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#6: The system records volunteer hours automatically after an activity is confirmed by the organiser, and it generates an export file in a format directly compatible with ISMAS.],
  [*Test Purpose*], [Verify hours are recorded when activity confirmed.],
  [*Preconditions*], [- Activity with 2-hour duration exists \ - Volunteer has joined (record in "todo" state)],
  [*Steps*], [1. Organizer marks volunteer's record as "done" \ 2. Query database for record state and timestamp],
  [*Expected Result*], [- Record state changed to "done" \ - updated_at timestamp recorded \ - Activity duration (2 hours) associated with user],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if state changed and hours tracked],
)

=== T6.2: ISMAS Export Format

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#6],
  [*Test Purpose*], [Verify export file is compatible with ISMAS.],
  [*Preconditions*], [- Multiple completed records exist in database],
  [*Steps*], [1. Generate export file \ 2. Verify file format matches ISMAS specification \ 3. Attempt import into ISMAS test environment],
  [*Expected Result*], [- Export file generated successfully \ - Format matches required specification \ - ISMAS accepts the import],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if ISMAS accepts the exported file],
)

=== T7.1: iPadOS Compatibility

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#7: The client application runs without error on iPadOS 17.5 or later, and all primary features function as intended.],
  [*Test Purpose*], [Verify app runs on target platform.],
  [*Preconditions*], [- iPad with iPadOS 17.5+ installed \ - App installed from TestFlight or development build],
  [*Steps*], [1. Launch app \ 2. Complete registration flow \ 3. Browse activities \ 4. Join an activity \ 5. Send a message \ 6. View leaderboard],
  [*Expected Result*], [- App launches without crash \ - All screens render correctly \ - All features functional],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if all features work on iPadOS 17.5+],
)

=== T7.2: UI Responsiveness

#table(
  columns: (1fr, 3fr),
  [*Success Criterion*], [\#7],
  [*Test Purpose*], [Verify UI responds appropriately to iPad form factor.],
  [*Preconditions*], [App installed on iPad],
  [*Steps*], [1. Test in portrait orientation \ 2. Test in landscape orientation \ 3. Test with keyboard visible],
  [*Expected Result*], [- UI adapts to both orientations \ - No text truncation or overflow \ - Keyboard does not obscure input fields],
  [*Actual Result*], [],
  [*Pass/Fail Criteria*], [PASS if UI adapts correctly],
)

== Test Coverage Summary

#table(
  columns: (1fr, 1.5fr, 2fr),
  table.header([*Category*], [*Test IDs*], [*Coverage*]),
  [Functional - Core], [T1.1, T2.1, T3.1, T4.1, T5.1, T6.1], [All success criteria],
  [Boundary/Error], [T1.2, T1.3, T2.2], [Input validation, authorization],
  [Data Integrity], [T4.1, T6.1], [Persistence verification],
  [Real-time], [T4.2, T5.2], [Push notifications, auto-updates],
  [Compatibility], [T7.1, T7.2], [Platform and UI testing],
)

= Appendix: API Reference

#table(
  columns: (1.5fr, auto, 1.2fr, 1fr),
  table.header([*Endpoint*], [*Method*], [*Purpose*], [*Auth Required*]),
  [`/api/v1/user`], [POST], [Register new user], [No],
  [`/api/v1/user/{id}`], [GET], [Get user info], [Yes],
  [`/api/v1/user/{id}`], [DELETE], [Delete user], [Yes (authority)],
  [`/api/v1/login`], [POST], [Login, create session], [No],
  [`/api/v1/activity`], [GET], [List activities], [Yes],
  [`/api/v1/activity`], [POST], [Create activity], [Yes (authority)],
  [`/api/v1/activity/{id}`], [GET], [Get activity detail], [Yes],
  [`/api/v1/activity/{id}`], [DELETE], [Delete activity], [Yes (owner/authority)],
  [`/api/v1/activity/{id}/apply`], [POST], [Join activity], [Yes],
  [`/api/v1/activity/{id}/go`], [POST], [Set state to Going], [Yes],
  [`/api/v1/activity/{id}/end`], [POST], [Set state to Ended], [Yes],
  [`/api/v1/activity/{id}/cancel`], [POST], [Cancel activity], [Yes],
  [`/api/v1/activity/{id}/comment`], [GET], [List comments], [Yes],
  [`/api/v1/activity/{id}/comment`], [POST], [Post comment], [Yes (authority)],
  [`/api/v1/record`], [GET], [Find records], [Yes],
  [`/api/v1/record/{id}/done`], [POST], [Mark record done], [Yes (owner)],
  [`/api/v1/channel`], [GET], [Find channels], [Yes],
  [`/api/v1/channel`], [POST], [Create channel], [Yes (authority)],
  [`/api/v1/channel/{id}`], [DELETE], [Delete channel], [Yes (owner/authority)],
  [`/api/v1/channel/{id}`], [POST], [Post message], [Yes (member)],
  [`/api/v1/message`], [GET], [Find messages], [Yes],
  [`/api/v1/push`], [GET], [SSE push subscription], [Yes],
)
