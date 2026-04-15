#set document(title: "Criterion B: Design")
#set page(paper: "a4", margin: (x: 2.3cm, y: 2.3cm))
#set text(font: "New Computer Modern", size: 11.1pt)
#set heading(numbering: "1.1")
#set par(leading: 0.9em, spacing: 1.35em, justify: true)
#set table(
  stroke: 0.5pt + luma(180),
  inset: 6.5pt,
  fill: (_, y) => if y == 0 { rgb("#183153") } else if calc.rem(y, 2) == 0 { rgb("#f8fafc") } else { white },
)

#import "@preview/mmdr:0.2.1": mermaid, mermaid-svg
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#let mermaid-fitted(code, width: 100%, base-theme: "modern") = {
  let svg = mermaid-svg(code, base-theme: base-theme)
  // Strip intrinsic width/height/style attributes from the <svg> root so
  // Typst scales to our explicit width instead of clamping to the natural size.
  let cleaned = svg
    .replace(regex("\s+width=\"[^\"]*\""), "", count: 1)
    .replace(regex("\s+height=\"[^\"]*\""), "", count: 1)
    .replace(regex("\s+style=\"[^\"]*\""), "", count: 1)
  image(bytes(cleaned), format: "svg", width: width)
}

#let navy = rgb("#183153")
#let sky = rgb("#4d7ac7")
#let ink-soft = rgb("#5f6b7a")
#let ui-image(path, caption, width: 46%) = figure(
  image(path, width: width),
  caption: caption,
)

#show heading.where(level: 1): it => {
  v(1.0em)
  text(size: 17pt, weight: "bold", fill: navy, it)
  v(0.45em)
}

#show heading.where(level: 2): it => {
  v(0.9em)
  text(size: 13.2pt, weight: "bold", fill: navy, it)
  v(0.25em)
}

#show heading.where(level: 3): it => {
  v(0.6em)
  text(size: 11.4pt, weight: "bold", fill: sky, it)
  v(0.15em)
}

// Allow inline code (e.g. `snake_case_identifier`, `table.column`) to break
// at underscores and dots so long identifiers in data-dictionary tables never
// overflow their column. A leading ZWSP also lets the line break before the
// raw span when the preceding word fills the line.
#show raw.where(block: false): it => {
  show "_": "_" + "\u{200B}"
  show ".": "." + "\u{200B}"
  "\u{200B}" + it
}

#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Criterion B: Design]
]

= Overall Design

Four design principles frame the rest of this document: a single shared database as source of truth across all clients; authority-based role separation enforced on the server; a foreign-key-linked relational structure with denormalisation only in the export tables; and a short-session iPad interface optimised for between-lesson use.

== System Decomposition

#let mod-node(pos, label, name) = node(
  pos,
  text(weight: "bold", size: 11pt, fill: white, label),
  name: name,
  shape: rect,
  corner-radius: 5pt,
  fill: navy,
  stroke: 0.9pt + navy,
  inset: 8pt,
)

#let leaf-node(pos, label, name) = node(
  pos,
  text(size: 9pt, fill: navy, label),
  name: name,
  shape: rect,
  corner-radius: 4pt,
  fill: rgb("#f8fafc"),
  stroke: 0.7pt + navy,
  inset: 6pt,
)

#figure(
  diagram(
    spacing: (30pt, 26pt),
    edge-stroke: 0.7pt + luma(130),

    node(
      (2, 0),
      text(weight: "bold", size: 12pt, fill: white, [Together System]),
      shape: rect,
      corner-radius: 6pt,
      fill: navy,
      stroke: 1pt + navy,
      inset: 10pt,
      name: <root>,
    ),

    mod-node((0, 1), [Account], <acc>),
    mod-node((1, 1), [Activity], <act>),
    mod-node((2, 1), [Participation], <par>),
    mod-node((3, 1), [Communication], <com>),
    mod-node((4, 1), [Administration], <adm>),

    leaf-node((0, 2), [Register], <a1>),
    leaf-node((0, 3), [Login / Profile], <a2>),
    leaf-node((1, 2), [Publish], <b1>),
    leaf-node((1, 3), [Browse / Detail], <b2>),
    leaf-node((2, 2), [Apply], <c1>),
    leaf-node((2, 3), [Confirm Hours], <c2>),
    leaf-node((3, 2), [Comments], <d1>),
    leaf-node((3, 3), [Channel], <d2>),
    leaf-node((3, 4), [Notifications], <d3>),
    leaf-node((4, 2), [Manage Users], <e1>),
    leaf-node((4, 3), [Generate Exports], <e2>),

    edge(<root>, <acc>), edge(<root>, <act>), edge(<root>, <par>),
    edge(<root>, <com>), edge(<root>, <adm>),
    edge(<acc>, <a1>), edge(<a1>, <a2>),
    edge(<act>, <b1>), edge(<b1>, <b2>),
    edge(<par>, <c1>), edge(<c1>, <c2>),
    edge(<com>, <d1>), edge(<d1>, <d2>), edge(<d2>, <d3>),
    edge(<adm>, <e1>), edge(<e1>, <e2>),
  ),
  caption: [System decomposition diagram],
)

== System Architecture

#figure(
  mermaid-fitted(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '22px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 60, 'rankSpacing': 92, 'curve': 'basis'}}}%%
    flowchart TB
    Volunteer[\"Volunteer / Organiser\\nSwiftUI iPad App\"]
    Admin[\"Administrator\\nReact Admin Panel\"]
    Server[\"Rust Server\\nAuthentication, permissions, activity lifecycle, messaging, export\"]
    DB[(\"PostgreSQL\\nusers, activities, records, channels, messages, exports\")]
    Storage[\"File storage\\navatars and attachments\"]

    Volunteer -->|\"HTTPS / JSON API\"| Server
    Admin -->|\"HTTPS / JSON API\"| Server
    Server -->|\"SQL queries / transactions\"| DB
    Server -->|\"Read / write\"| Storage
",
    width: 82%,
  ),
  caption: [System architecture diagram],
)

== Data Flow --- Context Diagram

#figure(
  mermaid-fitted(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '22px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 60, 'rankSpacing': 80}}}%%
    flowchart LR
    Student((\"Student\"))
    Teacher((\"Teacher\"))
    Admin((\"Administrator\"))
    System[\"Together\\nVolunteer Management System\"]
    ISMAS[(\"ISMAS\\nschool reporting\")]

    Student -->|\"apply, withdraw, message\"| System
    System -->|\"feed, notifications, hours\"| Student
    Teacher -->|\"publish, approve, confirm hours\"| System
    System -->|\"applications, channel messages\"| Teacher
    Admin -->|\"manage users, run export\"| System
    System -->|\"dashboard, CSV file\"| Admin
    Admin -->|\"upload CSV\"| ISMAS
",
    width: 82%,
  ),
  caption: [DFD context diagram --- three actor classes and one downstream system],
)

== Data Flow --- Level 0

#figure(
  mermaid-fitted(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '20px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 44, 'rankSpacing': 64}}}%%
    flowchart TB
    subgraph Actors
      S((\"Student\"))
      T((\"Teacher\"))
      A((\"Admin\"))
    end
    P1[\"1. Account\\n(register / login / profile)\"]
    P2[\"2. Activity\\n(publish / state transitions)\"]
    P3[\"3. Participation\\n(apply / withdraw / approve / confirm)\"]
    P4[\"4. Communication\\n(channel messages + archive)\"]
    P5[\"5. Administration\\n(users / batch / export)\"]
    D1[(\"D1 users\")]
    D2[(\"D2 activities\")]
    D3[(\"D3 records\")]
    D4[(\"D4 channels + messages\")]

    S --> P1 --> D1
    T --> P1
    A --> P1
    T --> P2 --> D2
    P2 --> D4
    S --> P3
    T --> P3
    P3 --> D3
    P3 --> D2
    S --> P4
    T --> P4
    P4 --> D4
    A --> P5
    P5 --> D1
    P5 --> D3
    D1 --> P3
    D2 --> P3
    D3 --> P5
",
    width: 84%,
  ),
  caption: [DFD level 0 --- five processes, four data stores, three actor classes],
)

#pagebreak()

= Database Design

== Database Tables

#let db-table-header(name, desc) = [
  #v(0.6em)
  *TABLE NAME:* #h(1em) #name \
  *DESCRIPTION:* #h(1em) #desc
  #v(0.2em)
]

#let field-header = table.header(
  text(fill: white, weight: "bold", style: "italic")[FIELD NAME],
  text(fill: white, weight: "bold", style: "italic")[DATA TYPE],
  text(fill: white, weight: "bold", style: "italic")[DESCRIPTION],
  text(fill: white, weight: "bold", style: "italic")[VALIDATION RULES],
)

#db-table-header("users", "User accounts for volunteers, organisers, and administrators")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal user identifier.], [Primary key],
  [email], [VARCHAR(120)], [School email address used for login and search.], [Unique; email format; e.g. `name\@ulink.edu.cn`],
  [realname], [VARCHAR(40)], [Full name displayed in the feed, leaderboard, and chat.], [Required; 2--40 characters],
  [gender], [VARCHAR(10)], [Self-reported gender for record-keeping.], [Required; one of `male`, `female`, `other`],
  [description], [TEXT], [Optional short biography shown on the profile card.], [0--500 characters],
  [classname], [VARCHAR(20)], [Homeroom class identifier (e.g. `12A`).], [Required; 1--20 characters],
  [avatar_path], [VARCHAR(255)], [Server-relative path to the uploaded avatar image.], [Nullable],
  [password_hash], [VARCHAR(60)], [One-way hash of the account password.], [Required],
  [group_id], [UUID], [Authority group the user belongs to.], [Required; FK → groups.id],
)

#db-table-header("activities", "Volunteer opportunities published by organisers")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal activity identifier.], [Primary key],
  [promoter_id], [UUID], [The organiser who created this activity.], [Required; FK → users.id],
  [name], [VARCHAR(80)], [Title shown on the feed card and detail view.], [Required; 3--80 characters],
  [location], [VARCHAR(80)], [Location such as a building name or campus area.], [Required; 1--80 characters],
  [state], [VARCHAR(20)], [Current lifecycle state (see Section 3.2).], [Required; one of `need_volunteer`, `going`, `ended`, `canceled`],
  [volunteer_num], [INTEGER], [Current number of approved volunteers.], [Default 0; `>= 0`; `<= max_volunteer_num`],
  [max_volunteer_num], [INTEGER], [Maximum volunteers accepted. Null means unlimited.], [Nullable; `>= 1` when set],
  [date], [TIMESTAMP], [Scheduled start time.], [Nullable; ISO 8601],
  [brief_description], [VARCHAR(120)], [Short summary for the feed card.], [Required; 1--120 characters],
  [description], [TEXT], [Full description on the detail page.], [Required; 1--5000 characters],
  [duration_minutes], [INTEGER], [Expected duration in minutes.], [Required; `>= 1` and `<= 1440`],
)

#db-table-header("records", "Participation records tracking the apply → approve → confirm lifecycle")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal record identifier.], [Primary key],
  [activity_id], [UUID], [The activity this record belongs to.], [Required; FK → activities.id; unique with `user_id`],
  [user_id], [UUID], [The volunteer this record belongs to.], [Required; FK → users.id],
  [state], [VARCHAR(20)], [Current record state.], [Required; one of `pending_approval`, `approved`, `confirmed`, `canceled`],
  [confirmed_minutes], [INTEGER], [Minutes confirmed by the organiser.], [Default 0; `>= 1` when confirmed],
  [confirmed_at], [TIMESTAMP], [Time of organiser confirmation.], [Nullable; required when confirmed],
  [confirmed_by], [UUID], [Organiser who confirmed.], [Nullable; FK → users.id],
  [updated_at], [TIMESTAMP], [Time of the most recent state change.], [Required; ISO 8601],
)

#db-table-header("channels", "One chat room per activity")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal channel identifier.], [Primary key],
  [name], [VARCHAR(80)], [Display name shown above the chat timeline.], [Required; 1--80 characters],
  [owner_id], [UUID], [Creator of the channel (usually the organiser).], [Required; FK → users.id],
  [activity_id], [UUID], [Activity the channel is bound to.], [Nullable; FK → activities.id],
  [created_at], [TIMESTAMP], [Time the channel was created.], [Required; ISO 8601],
)

#db-table-header("messages", "Individual messages posted inside an activity channel")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal message identifier.], [Primary key],
  [channel_id], [UUID], [Channel the message belongs to.], [Required; FK → channels.id; indexed],
  [sender_id], [UUID], [User who sent the message.], [Required; FK → users.id],
  [content], [TEXT], [Message body (plain text).], [Required; 1--2000 characters],
  [sent_at], [TIMESTAMP], [Time the message was accepted by the server.], [Required; ISO 8601],
)

#db-table-header("export_batches", "Export batches generated by staff")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal batch identifier.], [Primary key],
  [creator_id], [UUID], [Staff member who triggered the export.], [Required; FK → users.id],
  [target_format], [VARCHAR(10)], [File format produced.], [Required; e.g. `csv`],
  [status], [VARCHAR(20)], [Processing status of the batch.], [Required; one of `ready`, `failed`],
  [created_at], [TIMESTAMP], [Time the export was generated.], [Required; ISO 8601],
)

#db-table-header("export_items", "Denormalised rows inside an export batch")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal item identifier.], [Primary key],
  [batch_id], [UUID], [Batch this row belongs to.], [Required; FK → export_batches.id; indexed],
  [user_id], [UUID], [Volunteer being reported.], [Required; FK → users.id],
  [activity_id], [UUID], [Activity being reported.], [Required; FK → activities.id],
  [activity_title], [VARCHAR(80)], [Activity title captured at export time.], [Required; 3--80 characters],
  [activity_date], [TIMESTAMP], [Activity date captured at export time.], [Nullable],
  [student_name], [VARCHAR(40)], [Student name captured at export time.], [Required],
  [class_name], [VARCHAR(20)], [Homeroom class captured at export time.], [Required],
  [confirmed_minutes], [INTEGER], [Confirmed minutes for this record. This is the actual value written to the CSV column `confirmed_minutes`.], [Required; `>= 1`],
  [confirmed_at], [TIMESTAMP], [Confirmation wall-clock time captured at export time.], [Nullable],
)

#db-table-header("groups", "Authority groups controlling user permissions")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Internal group identifier.], [Primary key],
  [code], [VARCHAR(20)], [Human-readable code (e.g. `admin`, `teacher`, `student`).], [Unique; required; 2--20 lowercase characters],
  [allow_all_authorities], [BOOLEAN], [When true, all authority checks pass for this group.], [Default false],
)

#db-table-header("group_authorities", "Maps specific permissions to groups")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [group_id], [UUID], [Group receiving the authority.], [PK (composite); FK → groups.id],
  [authority], [VARCHAR(40)], [Permission string (e.g. `manage_activity_anyway`).], [PK (composite); 3--40 lowercase characters],
)

#db-table-header("sessions", "Active login sessions")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Session identifier stored in the browser cookie.], [Primary key],
  [user_id], [UUID], [Owner of the session.], [Required; FK → users.id; indexed],
  [generated_at], [TIMESTAMP], [Time the session was created.], [Required; ISO 8601],
  [ip], [VARCHAR(45)], [IP address at login time.], [Required; valid IPv4/IPv6],
)

#db-table-header("channel_members", "Junction table for channel membership")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [channel_id], [UUID], [Channel the user is a member of.], [PK (composite); FK → channels.id],
  [user_id], [UUID], [Member. Exactly one row exists per (channel, user) pair.], [PK (composite); FK → users.id],
)

#db-table-header("activity_comments", "Public comments on activity detail pages")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Comment identifier.], [Primary key],
  [activity_id], [UUID], [Activity the comment is attached to.], [Required; FK → activities.id; indexed],
  [author_id], [UUID], [User who wrote the comment.], [Required; FK → users.id],
  [content], [TEXT], [Comment body (plain text).], [Required; 1--1000 characters],
  [created_at], [TIMESTAMP], [Time the comment was posted.], [Required; ISO 8601],
)

#db-table-header("notifications", "System notifications generated by state changes")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [id], [UUID], [Notification identifier.], [Primary key],
  [user_id], [UUID], [Recipient of the notification.], [Required; FK → users.id; indexed],
  [notification_type], [VARCHAR(30)], [Category of the event.], [Required; e.g. `new_channel_message`, `activity_state_change`],
  [payload], [JSON], [Structured event details.], [Required; valid JSON],
  [read_at], [TIMESTAMP], [Time the notification was marked as read.], [Nullable],
  [created_at], [TIMESTAMP], [Time the notification was generated.], [Required; ISO 8601; indexed],
)

#db-table-header("notification_preferences", "Per-user notification opt-out settings")

#table(
  columns: (1.2fr, 0.78fr, 1.62fr, 1.3fr),
  field-header,
  [user_id], [UUID], [User expressing the preference.], [PK (composite); FK → users.id],
  [notification_type], [VARCHAR(30)], [Category being enabled or disabled.], [PK (composite)],
  [enabled], [BOOLEAN], [Whether the user receives this category.], [Default true],
)

#pagebreak()

== Entity-Relationship Diagram

#figure(
  image("assets/er-diagram.jpg", width: 100%),
  caption: [Crow's foot entity-relationship diagram],
)

== Key Data Rules

#table(
  columns: (1.2fr, 2.3fr),
  table.header(
    text(fill: white, weight: "bold")[Rule],
    text(fill: white, weight: "bold")[How the design enforces it],
  ),
  [No duplicate application], [One record is allowed per `(activity_id, user_id)` pair, so the same volunteer cannot join the same activity twice.],
  [Capacity remains consistent], [Applying to an activity is treated as one transaction: create the record and update the count together.],
  [Only confirmed hours affect rankings], [The ranking view is derived from participation records that have reached the completed state.],
  [Chat access], [Only the organiser and relevant volunteers can use an activity chat.],
)

= Functional Module Design

== Activity Lifecycle

#figure(
  mermaid-fitted(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '26px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}}}%%
    stateDiagram-v2
    direction TB
    [*] --> Recruiting
    Recruiting --> Ongoing: start
    Recruiting --> Cancelled: cancel
    Ongoing --> Completed: end
    Ongoing --> Cancelled: cancel
    Completed --> [*]
    Cancelled --> [*]
",
    width: 62%,
  ),
  caption: [Activity lifecycle (wire names: recruiting = `need_volunteer`, ongoing = `going`, completed = `ended`, cancelled = `canceled`)],
)

== Login Verification Flowchart

#figure(
  mermaid-fitted("
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '20px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 28, 'rankSpacing': 42}}}%%
flowchart TB
    Start([Submit login form])
    Empty{Fields empty?}
    ErrEmpty[Missing fields]
    Lookup{Find user by email}
    ErrWrong[Wrong email or password]
    Bcrypt[Verify password against bcrypt hash]
    Match{Match?}
    Session[Create session and set cookie]
    Success([Return signed-in profile])

    Start --> Empty
    Empty -- Yes --> ErrEmpty
    Empty -- No --> Lookup
    Lookup -- Not found --> ErrWrong
    Lookup -- Found --> Bcrypt
    Bcrypt --> Match
    Match -- No --> ErrWrong
    Match -- Yes --> Session
    Session --> Success
", width: 70%),
  caption: [Login verification flowchart],
)

== Capacity-Safe Sign-Up (Pseudocode)

The sign-up algorithm must be safe against concurrent applications so that the final remaining place cannot be double-booked. It runs inside a single database transaction and acquires a row-level lock on the activity before reading the counter.

```
procedure apply_to_activity(user_id, activity_id):
    precondition:  user is authenticated; activity exists
    postcondition: a pending record exists iff the activity had capacity

    begin transaction
        row ← SELECT volunteer_num, max_volunteer_num
              FROM activities WHERE id = activity_id
              FOR UPDATE                             -- row lock
        if row.max_volunteer_num is not null and
           row.volunteer_num >= row.max_volunteer_num then
            rollback
            return error CapacityFull

        if record exists for (user_id, activity_id) then
            rollback
            return error DuplicateApplication

        INSERT INTO records(user_id, activity_id, state)
            VALUES (user_id, activity_id, 'pending_approval')
        UPDATE activities SET volunteer_num = volunteer_num + 1
            WHERE id = activity_id
    commit
    return ok
```

#align(center)[#emph[Pseudocode: capacity-safe sign-up under concurrent access]]

= Use Case Diagram

#table(
  columns: (1.1fr, 2.4fr, 1.3fr),
  table.header(
    text(fill: white, weight: "bold")[Use case],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Allowed actors],
  ),
  [UC1 --- Browse Activity Feed], [Scroll the list of published activities and filter by state.], [Volunteer, Organiser],
  [UC2 --- View Activity Detail], [Open a single activity to read the full description, location, date, and capacity.], [Volunteer, Organiser],
  [UC3 --- Apply to Activity], [Create a participation record in the pending_approval state.], [Volunteer],
  [UC4 --- View Personal Records], [Read the signed-in user's own application and confirmation history.], [Volunteer],
  [UC5 --- Use Activity Chat], [Send and read messages in an activity-bound channel as a member.], [Volunteer, Organiser],
  [UC6 --- View Leaderboard], [Read the confirmed-hours ranking of all volunteers.], [Volunteer, Organiser],
  [UC7 --- Create / Transition Activity], [Publish a new activity and move it through the lifecycle states (recruiting → ongoing → completed, or cancel).], [Organiser, Administrator],
  [UC8 --- Confirm Participation], [Approve applications and confirm attendance minutes after the activity ends.], [Organiser],
  [UC9 --- Manage Users / Groups], [Add or delete accounts and change authority-group permissions from the admin panel.], [Administrator],
  [UC10 --- Generate Export], [Produce the ISMAS-compatible CSV batch for the current reporting window.], [Organiser, Administrator],
  [UC11 --- Receive System Notifications], [Read automatic notifications triggered by new messages, state changes, or record updates, with per-type opt-out.], [Volunteer, Organiser],
)


= User Interface Design

== Student-side SwiftUI iPad Interface

#figure(
  image("assets/wireframe-student-annotated.svg", width: 100%),
  caption: [Student-side annotated wireframe --- landscape-only feed, detail, records, leaderboard, chat, account],
)

Design decisions not visible on the wireframe:

- Landscape-only is enforced at build time by omitting portrait from the supported interface orientations; iPadOS refuses to rotate rather than re-laying out.
- Each activity owns one chat for the lifetime of the activity, so messages stay pinned to the event they were written about.
- Notifications are opt-out per type (channel message, state change, record update) from a dedicated preferences page inside the account tab.

== Teacher/Admin Web Interface

#figure(
  image("assets/wireframe-admin-activity.svg", width: 100%),
  caption: [Activity management workspace --- list, detail, records, lifecycle controls in one wide 2-column view],
)

#figure(
  image("assets/wireframe-admin-students.svg", width: 100%),
  caption: [Student management workspace --- search, filters, batch import, class rename, delete],
)

Design decisions not visible on the wireframes:

- Roles are hardcoded server-side (administrator, teacher, student) and there is no in-app role editor: the set is small and school-wide, and a runtime editor would add confusion for no real benefit.
- Export preparation is behind a dialog because it is sensitive and infrequent, and the output lands as a file because ISMAS has no open API.
- Batch user operations and class rename are first-class because administrators work with whole cohorts at a time rather than individual profiles.

= Test Plan

#let sc-header(num, name) = table.cell(colspan: 4, fill: rgb("#e8eef5"), text(weight: "bold", size: 9pt)[Success Criterion #num: #name])

#table(
  columns: (0.7fr, 1.3fr, 1.6fr, 1.6fr),
  table.header(
    text(fill: white, weight: "bold")[Test type],
    text(fill: white, weight: "bold")[Aspect],
    text(fill: white, weight: "bold")[Test case],
    text(fill: white, weight: "bold")[Expected result],
  ),

  sc-header("1", "Account Registration"),
  [Valid], [Complete registration], [Submit new account with school email, password, name, class, avatar.], [Account created; login succeeds; `password_hash` is bcrypt.],
  [Invalid], [Duplicate email], [Register with an email already in `users`.], [Server rejects with duplicate error.],
  [Invalid], [Missing fields], [Submit with one or more required fields empty.], [Form rejects with per-field feedback.],

  sc-header("2", "Role Separation and Admin Scope"),
  [Valid], [Role distinction], [Log in as student, teacher, administrator in turn.], [Each sees only the screens permitted by its authority group.],
  [Valid], [Admin batch and rename], [Batch-import users from CSV; rename a class cohort.], [Users appear in `users` with the new class; cohort name updates across records.],
  [Invalid], [Privilege escalation], [Attempt organiser or admin actions from a student account.], [Server rejects; no state change.],

  sc-header("3", "Publish and Browse"),
  [Valid], [Create activity], [Create activity with name, date, location, duration, capacity.], [Appears in feed and detail view.],
  [Valid], [Search], [Search feed by keyword in name.], [Only matching activities returned.],
  [Invalid], [Missing values], [Submit create form with required fields empty.], [Submission blocked; fields highlighted.],
  [Boundary], [Max name length], [Enter name at the upper character limit.], [Stored and rendered without truncation.],

  sc-header("4", "Activity Lifecycle"),
  [Valid], [Forward transition], [Move activity recruiting → ongoing → completed.], [State updates; enrolled volunteers see the new state.],
  [Valid], [Cancel], [Cancel a recruiting or ongoing activity.], [Activity no longer accepts applications; chat archives.],
  [Invalid], [Illegal transition], [Attempt completed → recruiting.], [Request rejected with a clear error.],

  sc-header("5", "Apply, Withdraw, Capacity"),
  [Valid], [Apply], [Apply to an activity with places remaining.], [Record created pending approval; counter increments.],
  [Valid], [Withdraw], [Withdraw a pending application.], [Record removed; counter decrements.],
  [Valid], [Approve], [Organiser approves a pending application.], [Record moves to approved state.],
  [Invalid], [Duplicate application], [Apply twice to the same activity.], [Second request rejected.],
  [Invalid], [Full activity], [Apply when capacity is reached.], [Rejected with capacity-full error.],
  [Boundary], [Concurrent last place], [Two users apply simultaneously for the final place.], [Exactly one succeeds; capacity not exceeded.],

  sc-header("6", "Scoped Chat with Archive"),
  [Valid], [Send message], [Member posts a message in an active channel.], [Message persists; visible to all members in real time.],
  [Valid], [Auto-archive], [Mark the activity completed, then try to post.], [Post rejected; channel is read-only.],
  [Invalid], [Non-member access], [Non-member attempts to read or post.], [Request rejected; no message stored.],

  sc-header("7", "Hour Confirmation"),
  [Valid], [Confirm], [Organiser confirms minutes after activity ends.], [Record moves to confirmed; minutes stored; student record updates.],
  [Invalid], [Premature confirmation], [Confirm before state is completed.], [Blocked.],
  [Invalid], [Wrong role], [Student attempts to confirm another user's hours.], [Rejected.],

  sc-header("8", "Leaderboard"),
  [Valid], [Ranking], [Open leaderboard after confirmations exist.], [Ordered by sum of confirmed minutes, descending.],
  [Invalid], [Unconfirmed hours], [Check whether pending records affect totals.], [They do not.],
  [Boundary], [Tied totals], [Two volunteers with equal confirmed minutes.], [Tie ordering is stable.],

  sc-header("9", "ISMAS CSV Export"),
  [Valid], [Global export], [Admin exports cohort-wide.], [CSV matches ISMAS column order.],
  [Valid], [Per-activity export], [Export from activity workspace.], [CSV contains only that activity's confirmed records.],
  [Invalid], [Permission denied], [Attempt export without authority.], [Blocked.],

  sc-header("10", "Landscape-Only iPad"),
  [Valid], [Landscape launch], [Launch on iPad Pro 13-inch simulator.], [Opens in landscape; split view fills screen.],
  [Invalid], [Portrait rotation], [Rotate device to portrait.], [App stays in landscape; OS never redraws in portrait.],
  [Invalid], [Extreme content], [Very long titles or long message history.], [Scrolls or truncates safely.],
)

=== Testing Evidence Streams

#table(
  columns: (1fr, 2fr),
  table.header(
    text(fill: white, weight: "bold")[Evidence stream],
    text(fill: white, weight: "bold")[Coverage],
  ),
  [Backend unit tests], [Participation records, ranking logic, export generation, and server-side validation rules are checked automatically.],
  [SwiftUI XCUITest], [Login, feed navigation, activity detail, and records flows are verified through UI automation on iPad.],
  [Teacher/admin web verification], [Dashboard, activity management, student management, and export workflows are verified through browser-based checks.],
)
