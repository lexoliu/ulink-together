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

#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Criterion B: Design]
]

= Overall Design

The design is built around one shared server that every client talks to, so that the deputy head's volunteer records, the students' feed, and the organiser tools always see the same data. Three clients connect to that server: a native SwiftUI iPad application for volunteers and organisers, a React-based admin panel for school staff, and a real-time push channel used by the iPad client to stay in sync during a class period. The table below summarises the four design principles that guide the rest of this document, and the system decomposition diagram that follows breaks those principles down into concrete modules.

#table(
  columns: (1.1fr, 2fr),
  table.header(
    text(fill: white, weight: "bold")[Design focus],
    text(fill: white, weight: "bold")[How the design addresses the client context],
  ),
  [Shared source of truth], [The app is used by many students and organisers at the same time, so the design keeps activity state, participation records, and messaging on one central server. Every client --- SwiftUI, React, and the live push stream --- reads from and writes to the same authoritative database, which is the only way to prevent the spreadsheet-style inconsistencies that the client reported in Appendix 1.],
  [Role separation], [Volunteers mainly browse and apply, organisers manage activities and confirmations, and administrators manage users and exports. The interface never exposes controls that the current user cannot actually perform, and the server re-checks the authority on every protected call so that a UI bypass cannot leak privileged behaviour.],
  [Clear activity structure], [Activities, participation records, chat messages, comments, notifications, and export items are all linked through activity and user foreign keys so information stays organised and can be reused across the system. Denormalised copies are only kept in the export tables where historical accuracy matters more than storage efficiency.],
  [Short-session interface], [Students use the iPad app between lessons, so the feed, detail page, and records screens are designed for quick scanning and low-friction actions. The design avoids multi-step wizards for the volunteer journey and relies on typography and a native `List` layout rather than heavy cards so that students can act in seconds rather than minutes.],
)

== System Decomposition

The system is decomposed into five functional modules. Each module groups the server endpoints, database tables, and client screens that share a common purpose, so that any change to a single feature touches a bounded area of the codebase. The Account module handles identity and sign-in. The Activity module handles publication and browsing. Participation covers the apply → approve → confirm flow. Communication covers comments, activity channels, and the event-driven notification system. Administration covers user and export management through the React admin panel.

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

At deployment time the five modules from Section 1.1 collapse into three running components: the SwiftUI iPad application, the React admin panel, and the Rust server. All clients communicate with the server through the same JSON API over HTTPS, and the server in turn talks to the database through SQLx and to the local filesystem for avatars and other uploaded resources. Putting every business rule on the server rather than in the clients means a future additional client (for example a parent-facing web portal) can be added without re-implementing any permission or validation logic.

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

#table(
  columns: (1fr, 1.2fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Component],
    text(fill: white, weight: "bold")[Main responsibility],
    text(fill: white, weight: "bold")[Reason for inclusion in the design],
  ),
  [SwiftUI iPad app], [Volunteer and organiser interface], [Supports browsing, application, messaging, confirmation, and profile tasks on the school iPad platform.],
  [React admin panel], [Administrative management], [Provides wider-screen workflows for user management, groups, and export generation.],
  [Rust server], [Shared business rules], [Keeps authentication, permissions, activity lifecycle, and validation in one place for all clients.],
  [Database], [Persistent storage and constraints], [Stores the data permanently and enforces core relationships such as user-to-record and activity-to-record links.],
)

#pagebreak()

= Database Design

The table definitions below use logical database types for clarity. In the current portable implementation some UUID and timestamp values are serialized as strings internally, but the design treats them as `UUID`, `TIMESTAMP`, `BOOLEAN`, and bounded text fields where appropriate rather than describing everything as generic `TEXT`.

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

#db-table-header("users", "Stores every registered volunteer, organiser, and administrator account so that one user record can be referenced from activities, records, channels, and exports")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal identifier used as a stable foreign key by every other table. It is generated by the server instead of reusing school IDs so that account records can be created before a student is enrolled in ISMAS.], [Primary key; UUID v4 format],
  [email], [VARCHAR], [School email address of the user. This is the credential shown on the login screen and also serves as the human-readable identifier when the deputy head searches for a specific student.], [Unique; follow email format convention; e.g. `name\@ulink.edu.cn`],
  [realname], [VARCHAR], [Full Chinese/English name displayed in the feed, leaderboard, and chat so that organisers can recognise who applied to each activity.], [Required; 2--40 characters],
  [gender], [VARCHAR], [Self-reported gender kept for record-keeping purposes when activities have gender-balance targets.], [Required; one of `male`, `female`, `other`],
  [description], [TEXT], [Optional short biography that the student can edit from the account screen; shown when another user opens the profile card.], [0--500 characters],
  [classname], [VARCHAR], [Homeroom class identifier (e.g. `12A`). Used by the admin panel to batch-manage students by class and by the leaderboard to label entries.], [Required; 1--20 characters],
  [avatar_path], [VARCHAR], [Server-relative path to the uploaded avatar image inside the resource folder. Stored rather than embedded so that large binary data stays outside the primary table.], [Nullable; must resolve to an existing resource file],
  [password_hash], [VARCHAR], [Bcrypt hash of the account password. The original password is never persisted, which limits damage if the database is leaked.], [Required; 60-character bcrypt string starting with `\$2`],
  [group_id], [UUID], [Authority group the user belongs to. All permission checks resolve through this column rather than through a fixed enum so that administrators can adjust what each group can do at runtime.], [Required; FK → groups.id],
)

#db-table-header("activities", "Stores each volunteer opportunity published by an organiser. Central table that the feed, detail view, records, channels, and exports all reference")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal activity identifier referenced by records, channels, comments, and export items.], [Primary key; UUID v4 format],
  [promoter_id], [UUID], [The organiser who created and manages this activity. Permission checks compare this column against the current user when deciding whether lifecycle changes or record confirmations are allowed.], [Required; FK → users.id],
  [name], [VARCHAR], [Title shown on the feed card and at the top of the detail view. Must be long enough to describe the activity but short enough to fit the feed layout.], [Required; 3--80 characters],
  [location], [VARCHAR], [Human-readable location such as a building name or campus area. Displayed in the feed so students can judge whether the activity is convenient.], [Required; 1--80 characters],
  [state], [VARCHAR], [Current lifecycle state. The server rejects transitions that do not match the allowed state-diagram paths (see Section 3.2).], [Required; one of `need_volunteer`, `going`, `ended`, `canceled`],
  [volunteer_num], [INTEGER], [Current number of approved volunteers. Maintained by the sign-up transaction so the value stays consistent with the records table.], [Default 0; `>= 0`; `<= max_volunteer_num` when capacity set],
  [max_volunteer_num], [INTEGER], [Maximum number of volunteers the organiser will accept. Left null when the activity is open-ended.], [Nullable (unlimited if null); `>= 1` when set],
  [date], [TIMESTAMP], [Scheduled start time of the activity. Shown in the feed and used by the home page to highlight activities that need attention.], [Nullable ISO 8601 timestamp],
  [brief_description], [VARCHAR], [Short summary displayed on the feed card so students can scan opportunities quickly without opening every detail page.], [Required; 1--120 characters],
  [description], [TEXT], [Full description shown only on the activity detail page. Can contain multiple paragraphs describing tasks, expectations, and logistics.], [Required; 1--5000 characters],
  [duration_minutes], [INTEGER], [Expected duration in minutes. Used as the default value when an organiser confirms attendance, so the correct number of minutes lands in the leaderboard and the export.], [Required; `>= 1` and `<= 1440`],
)

#db-table-header("records", "Tracks one volunteer's participation in one activity across the apply → approve → confirm lifecycle. This table is the authoritative source for both the personal records screen and the leaderboard")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal record identifier used as the target of confirm/approve/cancel API calls.], [Primary key; UUID v4 format],
  [activity_id], [UUID], [The activity this record belongs to. Combined with `user_id` it forms a unique constraint that prevents the same volunteer from applying to the same activity twice.], [Required; FK → activities.id],
  [user_id], [UUID], [The volunteer the record belongs to. Used by the personal records screen to load the student's own history.], [Required; FK → users.id],
  [state], [VARCHAR], [Current record state, moving through apply → approve → confirm (or cancel). Only the `confirmed` state contributes minutes to the leaderboard and the export.], [Required; one of `pending_approval`, `approved`, `confirmed`, `canceled`],
  [confirmed_minutes], [INTEGER], [Minutes actually confirmed by the organiser, which may differ from the activity's scheduled duration if a volunteer arrived late or left early.], [Default 0; `>= 0`; `>= 1` when state is `confirmed`],
  [confirmed_at], [TIMESTAMP], [Wall-clock time at which the organiser confirmed attendance. Used in the export column `organiser_confirmation_timestamp` for audit trails.], [Nullable; required when state is `confirmed`],
  [confirmed_by], [UUID], [Organiser who performed the confirmation. Stored so that the school can audit who signed off on which record.], [Nullable; FK → users.id; required when state is `confirmed`],
  [updated_at], [TIMESTAMP], [Wall-clock time of the most recent state change. Used by the client to display "last updated" on the personal records screen.], [Required ISO 8601 timestamp],
)

#db-table-header("channels", "One chat room per activity. The system creates the channel together with the activity and binds them through `activity_id`, so messages stay attached to the correct event rather than drifting into a general-purpose room")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal channel identifier referenced by messages and channel_members.], [Primary key; UUID v4 format],
  [name], [VARCHAR], [Display name shown above the chat timeline. Usually derived from the activity title so students immediately recognise where they are.], [Required; 1--80 characters],
  [owner_id], [UUID], [Creator of the channel --- normally the organiser of the bound activity. Used as a fallback permission check when `activity_id` is null.], [Required; FK → users.id],
  [activity_id], [UUID], [Activity the channel is bound to. Null is allowed so that admin-only channels can exist, but the student app only surfaces channels where this column is set.], [Nullable; FK → activities.id],
  [created_at], [TIMESTAMP], [Wall-clock time at which the channel was created. Displayed only in the debug log; the client uses the first message timestamp for the visible "created" indicator.], [Required ISO 8601 timestamp],
)

#db-table-header("messages", "Individual messages posted inside an activity channel. The client loads this table in reverse chronological order when entering a chat and appends new rows as they arrive over the live push stream")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal message identifier used by the delete endpoint and by the SSE push payload so clients can deduplicate.], [Primary key; UUID v4 format],
  [channel_id], [UUID], [Channel the message belongs to. Indexed so that loading a channel's history remains fast even as the messages table grows.], [Required; FK → channels.id; indexed],
  [sender_id], [UUID], [User who sent the message. Compared against `channel_members` before the send is accepted, so non-members cannot post.], [Required; FK → users.id; indexed],
  [content], [TEXT], [Message body. Plain text only --- markdown and HTML are intentionally not parsed to avoid XSS risks.], [Required; 1--2000 characters],
  [sent_at], [TIMESTAMP], [Wall-clock time at which the server accepted the message. Used both to order the timeline and to drive the Discord-style "grouped by sender within five minutes" rendering.], [Required ISO 8601 timestamp],
)

#db-table-header("export_batches", "Each time staff press \"Export Hours\", one batch row is created together with the file that gets downloaded. Keeping a batch record allows the system to recreate the same file later if the original CSV is lost")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal batch identifier used by the download URL and by the `export_items` foreign key.], [Primary key; UUID v4 format],
  [creator_id], [UUID], [Member of staff who triggered the export. Useful for auditing who ran which report at the end of the semester.], [Required; FK → users.id],
  [target_format], [VARCHAR], [File format the batch produced. Currently fixed to `csv` because that is the only format ISMAS accepts.], [Required; currently always `csv`],
  [status], [VARCHAR], [Processing status of the batch. Immediate in the current implementation, but left as a column so a background-job version can populate `queued` / `processing` / `ready`.], [Required; one of `ready`, `failed`],
  [created_at], [TIMESTAMP], [Wall-clock time at which the export was generated. Shown next to the downloaded file so staff know which reporting window it belongs to.], [Required ISO 8601 timestamp],
)

#db-table-header("export_items", "Denormalised rows inside an export batch. The student name, class, and activity title are copied here at export time so that later edits to the source tables do not change historical reports")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal item identifier.], [Primary key; UUID v4 format],
  [batch_id], [UUID], [Batch this row belongs to. Composite logical key with `user_id`/`activity_id` for lookups.], [Required; FK → export_batches.id; indexed],
  [user_id], [UUID], [Volunteer being reported.], [Required; FK → users.id],
  [activity_id], [UUID], [Activity being reported.], [Required; FK → activities.id],
  [activity_title], [VARCHAR], [Activity title captured at export time. Denormalised so that renaming the activity later does not alter the historical export.], [Required; 3--80 characters],
  [activity_date], [TIMESTAMP], [Scheduled activity date captured at export time.], [Nullable],
  [student_name], [VARCHAR], [Student name captured at export time.], [Required],
  [class_name], [VARCHAR], [Homeroom class captured at export time.], [Required],
  [confirmed_minutes], [INTEGER], [Confirmed minutes for this record. This is the actual value written to the CSV column `confirmed_minutes`.], [Required; `>= 1`],
  [confirmed_at], [TIMESTAMP], [Confirmation wall-clock time captured at export time.], [Nullable],
)

#db-table-header("groups", "Defines authority groups that control what actions a user can perform. The admin, teacher, and student groups are seeded on first startup so that the permission system is immediately usable")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Internal group identifier referenced by `users.group_id`.], [Primary key; UUID v4 format],
  [code], [VARCHAR], [Short human-readable code such as `admin`, `teacher`, or `student`. This is the value the admin panel shows in the group selector.], [Unique; required; 2--20 lowercase characters],
  [allow_all_authorities], [BOOLEAN], [When true, every authority check for users in this group succeeds automatically. This is how the `admin` group gets its "god view" without having to list every authority string individually.], [Default false],
)

#db-table-header("group_authorities", "Maps specific permissions onto groups that do not have blanket access. A row in this table means \"users in this group can perform this action\"")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [group_id], [UUID], [Group receiving the authority.], [PK (composite); FK → groups.id],
  [authority], [VARCHAR], [Permission string such as `manage_activity_anyway` or `view_all_activities`. The server compares this value directly when it evaluates an `ensure_authority` call, so typos are caught at code-review time rather than at runtime.], [PK (composite); 3--40 lowercase characters],
)

#db-table-header("sessions", "Active login sessions for cookie-based authentication. Each successful login creates one row; logout deletes it")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Session identifier. This value is stored in the browser cookie so that subsequent requests can look up which user is authenticated.], [Primary key; UUID v4 format],
  [user_id], [UUID], [Owner of the session. The `Auth` extractor reads this column on every protected request.], [Required; FK → users.id; indexed],
  [generated_at], [TIMESTAMP], [Wall-clock time the session was created, stored so that very old sessions can be pruned offline.], [Required ISO 8601 timestamp],
  [ip], [VARCHAR], [IP address observed at login time. Recorded for basic audit logging.], [Required; valid IPv4/IPv6 string],
)

#db-table-header("channel_members", "Junction table recording which users can post in which channels. Membership is written when a record is approved and removed when the record is cancelled")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [channel_id], [UUID], [Channel the user is a member of.], [PK (composite); FK → channels.id],
  [user_id], [UUID], [Member. Exactly one row exists per (channel, user) pair.], [PK (composite); FK → users.id],
)

#db-table-header("activity_comments", "Open comments that sit underneath an activity's detail page. Unlike channel messages these are visible to anyone viewing the activity, not only the participants")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Comment identifier used by the delete endpoint.], [Primary key; UUID v4 format],
  [activity_id], [UUID], [Activity the comment is attached to. Indexed so that loading comments for one activity stays cheap.], [Required; FK → activities.id; indexed],
  [author_id], [UUID], [User who wrote the comment. Compared against the current user and `manage_comment_anyway` authority when deletions are requested.], [Required; FK → users.id],
  [content], [TEXT], [Comment body. Plain text only.], [Required; 1--1000 characters],
  [created_at], [TIMESTAMP], [Wall-clock time at which the comment was posted. Shown in the detail view.], [Required ISO 8601 timestamp],
)

#db-table-header("notifications", "Event-driven system notifications delivered to users when the server state changes. Unlike teacher-composed messages, every row in this table is generated automatically as a side effect of another action (new chat message, activity transition, or record state change)")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [id], [UUID], [Notification identifier used by the mark-as-read endpoint and by the SSE push payload.], [Primary key; UUID v4 format],
  [user_id], [UUID], [Recipient of the notification. The notifications list only loads rows where this matches the current user.], [Required; FK → users.id; indexed],
  [notification_type], [VARCHAR], [Category of the system event. Determines the icon shown in the notifications tab and the preview text rendered in the row.], [Required; one of `new_channel_message`, `teacher_channel_post`, `activity_state_change`, `record_state_change`],
  [payload], [JSON], [Structured event details serialised as JSON --- typed per notification category and always contains the `activity_id` and `activity_name` needed for the tap-through navigation.], [Required; valid JSON],
  [read_at], [TIMESTAMP], [Wall-clock time at which the recipient marked the notification as read. Left null while the row is still unread, which drives the Notifications tab badge count.], [Nullable],
  [created_at], [TIMESTAMP], [Wall-clock time at which the notification was generated.], [Required; indexed together with `user_id` for fast unread-count lookups],
)

#db-table-header("notification_preferences", "Per-user opt-out choices for each notification type, giving users Twitter-style control over which events they receive")

#table(
  columns: (1fr, 0.8fr, 1.9fr, 1.2fr),
  field-header,
  [user_id], [UUID], [User expressing the preference.], [PK (composite); FK → users.id],
  [notification_type], [VARCHAR], [Category the row is enabling or disabling.], [PK (composite); same values as `notifications.notification_type`],
  [enabled], [BOOLEAN], [Whether the user receives this category. Absent rows are treated as enabled by default so that new notification types reach everybody until they explicitly opt out.], [Default true],
)

#pagebreak()

== Entity-Relationship Diagram

The crow's-foot diagram below shows how the tables described in Section 2.1 are linked. Each crow's-foot symbol indicates the "many" side of a relationship and each single bar indicates "exactly one", so `users → records` is one-to-many (one student can have many participation records) and `activities → channels` is one-to-one-or-zero (each activity owns at most one channel). These relationships are enforced both by foreign-key declarations in the database and by transactional logic on the server.

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

== Volunteer Activity Module

#table(
  columns: (1fr, 1.7fr),
  table.header(
    text(fill: white, weight: "bold")[Design point],
    text(fill: white, weight: "bold")[Evidence in the module],
  ),
  [Feed view], [Shows title, date, location, capacity, and current state so students can decide without opening every activity.],
  [Detail view], [Combines full description, current participation state, comments, and the entry point to the activity chat.],
  [Application control], [The join action is separated from organiser-only controls so that role-based actions stay clear on the interface.],
)

== Activity Lifecycle

#table(
  columns: (1fr, 2fr, 0.8fr),
  table.header(
    text(fill: white, weight: "bold")[State],
    text(fill: white, weight: "bold")[Meaning in the system],
    text(fill: white, weight: "bold")[Visible to volunteers],
  ),
  [NeedVolunteer], [Published and open to new applications.], [Yes],
  [Going], [Already started; no new applications should be accepted.], [Yes],
  [Ended], [Finished and ready for organiser confirmation of participation.], [Yes],
  [Canceled], [Closed early; non-completed participation records should no longer remain active.], [Yes],
)

The state diagram below makes the allowed lifecycle transitions explicit. The server's `can_transition` function compares the current state to the proposed next state and rejects any pair that is not drawn on the diagram, so both the organiser interface and any direct API caller have to follow the same sequence.

#figure(
  mermaid-fitted(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '26px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}}}%%
    stateDiagram-v2
    direction TB
    [*] --> NeedVolunteer
    NeedVolunteer --> Going: start
    NeedVolunteer --> Canceled: cancel
    Going --> Ended: end
    Going --> Canceled: cancel
    Ended --> [*]
    Canceled --> [*]
",
    width: 62%,
  ),
  caption: [Activity lifecycle state diagram],
)

== Login Verification Flowchart

The login screen is the first protected entry point, so the verification flow has to catch invalid input early and avoid leaking information about which accounts exist. The flowchart below shows how the server processes a submitted login form. The email is normalised first, then the user row is looked up in the `users` table; if no row matches, the response is the same generic "wrong email or password" message used for incorrect passwords, so an attacker cannot distinguish between a missing account and a bad password. When the account exists, bcrypt compares the submitted password against the stored hash, a new session row is written to the `sessions` table, and the browser receives a cookie that identifies the session on every subsequent request.

#figure(
  mermaid-fitted("
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '20px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 28, 'rankSpacing': 42}}}%%
flowchart TB
    Start([User submits login form])
    Empty{Email or password empty?}
    ErrEmpty[Return 'Missing fields']
    Normalise[Normalise email to lowercase, trim whitespace]
    UsersDB[(users table)]
    Lookup{Lookup email in users}
    Bcrypt[Verify password with bcrypt]
    Match{Hash matches?}
    ErrWrong[Return 'Wrong email or password']
    GenSession[Generate new session id]
    SessionsDB[(sessions table)]
    InsertSession[Insert session row with user_id, ip, timestamp]
    Cookie[Set session cookie in response]
    Success([Return signed-in user profile])

    Start --> Empty
    Empty -- Yes --> ErrEmpty
    Empty -- No --> Normalise
    Normalise --> Lookup
    Lookup --> UsersDB
    Lookup -- Not found --> ErrWrong
    Lookup -- Found --> Bcrypt
    Bcrypt --> Match
    Match -- No --> ErrWrong
    Match -- Yes --> GenSession
    GenSession --> InsertSession
    InsertSession --> SessionsDB
    InsertSession --> Cookie
    Cookie --> Success
", width: 70%),
  caption: [Login verification flowchart],
)

= Use Case Diagram

The use case diagram below identifies the three actors that interact with the system --- volunteer, organiser, and administrator --- and connects each actor to the use cases they are allowed to invoke. Lines indicate that the actor can start that use case directly; where several actors connect to the same use case, every connected actor has independent access. The diagram corresponds to the authority checks that the server performs on every protected request, so it also serves as a map of which authority strings each role needs.

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
  [UC7 --- Create / Edit Activity], [Publish a new activity or modify an existing one, including cancellation.], [Organiser, Administrator],
  [UC8 --- Confirm Participation], [Approve applications and confirm attendance minutes after the activity ends.], [Organiser],
  [UC9 --- Manage Users / Groups], [Add or delete accounts and change authority-group permissions from the admin panel.], [Administrator],
  [UC10 --- Generate Export], [Produce the ISMAS-compatible CSV batch for the current reporting window.], [Organiser, Administrator],
  [UC11 --- Receive System Notifications], [Read automatic notifications triggered by new messages, state changes, or record updates, with per-type opt-out.], [Volunteer, Organiser],
)


= User Interface Design

== Student-side SwiftUI iPad Interface

#figure(
  image("assets/wireframe-student-annotated.svg", width: 100%),
  caption: [Student-side annotated wireframe showing the planned feed and activity-detail workspace],
)

#table(
  columns: (1fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Screen cluster],
    text(fill: white, weight: "bold")[Design decision],
  ),
  [Auth flow], [The sign-in and registration screens emphasise school identity, required-field validation, and a clear transition into the app shell.],
  [Feed and detail], [The student journey is built around quick scanning first and deeper detail second, so status, location, date, and capacity appear before long descriptions.],
  [Records and leaderboard], [Personal progress is separated from the browse flow so confirmed hours and ranking can be checked without cluttering the activity feed.],
  [Comments and messaging], [Each activity has one shared chat for the organiser and the participating volunteers. The chat is created with the activity and remains tied to it throughout that activity's lifetime, so reminders, schedule changes, and questions stay attached to the correct event instead of private chats.],
  [Account], [Profile management is separated from browsing and records, so the student-facing navigation stays clear and role-specific.],
)

== Communication and Export Boundaries

The chat feature is intentionally simple. Each activity has one shared chat used by the organiser and the relevant volunteers. The chat is created with the activity and remains bound to that activity for its full lifetime, so it is never treated as a separate general-purpose room. Its purpose is to keep logistics updates, reminders, and questions in one visible place; it is not meant to replace every other school messaging tool.

The export feature is also intentionally limited. Because ISMAS does not provide an open API, the system does not attempt a direct sync. Instead, staff generate a spreadsheet that follows the same overall structure as the school's existing ISMAS import template, download it, and then import it into ISMAS manually.

== Teacher/Admin Web Interface

#table(
  columns: (1fr, 1.7fr, 1.6fr),
  table.header(
    text(fill: white, weight: "bold")[Screen],
    text(fill: white, weight: "bold")[Primary user],
    text(fill: white, weight: "bold")[Purpose in the design],
  ),
  [Admin login], [Teacher / administrator], [Entry point for protected browser-based management workflows.],
  [Dashboard], [Teacher / administrator], [Shows activity totals, current state distribution, and recent activity information.],
  [Activities management], [Teacher / organiser], [Supports selecting an activity, reviewing details, changing lifecycle state, and opening related tools.],
  [Activity form dialog], [Teacher / organiser], [Collects title, date, location, duration, and capacity for creation or editing.],
  [Participant records table], [Teacher / organiser], [Supports approval, confirmation, and review of volunteer participation.],
  [Students management], [Administrator], [Supports search, edit, delete, batch import, and class-level management of users.],
  [Operations / permissions], [Administrator], [Supports authority-group configuration such as toggling blanket access and editing the per-group permission list.],
  [Export dialog], [Teacher / administrator], [Prepares and downloads a spreadsheet for manual ISMAS import.],
)

#table(
  columns: (1fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Web design area],
    text(fill: white, weight: "bold")[Key design decision],
  ),
  [Dashboard], [The dashboard is intentionally information-dense because teachers and administrators need an overview rather than a browse-first mobile experience.],
  [Activity management], [The activity workspace combines lifecycle actions, records, comments, and coordination so organisers can manage one activity without jumping between unrelated screens.],
  [Student management], [Batch operations and search are first-class because administrators work with large groups of students rather than one profile at a time.],
  [Operations and export], [Permission controls and export preparation are isolated from day-to-day student flows because they are sensitive, infrequent, and administrative. The export flow ends with a downloadable spreadsheet because ISMAS has no open API.],
)

#figure(
  image("assets/wireframe-admin-activity.svg", width: 100%),
  caption: [Teacher/admin annotated wireframe for the activity management workspace],
)

#figure(
  image("assets/wireframe-admin-students.svg", width: 100%),
  caption: [Teacher/admin annotated wireframe for the student management workspace],
)

#figure(
  image("assets/wireframe-admin-operations.svg", width: 100%),
  caption: [Teacher/admin annotated wireframe for the operations and permissions workspace],
)

= Test Plan

The test plan is organised by success criterion from Criterion A. Each criterion includes valid and invalid test cases grouped together, with boundary tests where the feature has a meaningful limit.

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
  [Valid], [Complete registration], [Submit a new account with school email, password, name, class, and avatar.], [Account is created and can log in successfully.],
  [Invalid], [Duplicate email], [Submit with a school email that is already registered.], [The server rejects the request and reports the duplicate.],
  [Invalid], [Missing fields], [Submit with one or more required fields left empty.], [The form rejects the request with field-specific validation feedback.],

  sc-header("2", "Authority-Based Access Control"),
  [Valid], [Authority distinction], [Log in as volunteer, organiser, and administrator in turn.], [Each user only sees the screens and actions allowed by their assigned authority group.],
  [Invalid], [Privilege escalation], [Attempt organiser or admin actions with a volunteer account.], [The restricted action is denied and does not change server data.],

  sc-header("3", "Task Publication"),
  [Valid], [Create activity], [Create an activity with complete title, date, location, duration, and capacity.], [The activity appears correctly in the feed and detail view.],
  [Invalid], [Missing required values], [Submit the create form with missing required fields.], [The form highlights missing values and prevents submission.],
  [Boundary], [Maximum title length], [Enter a title at the maximum allowed character length.], [The title is stored and displayed without truncation or error.],

  sc-header("4", "Task Management"),
  [Valid], [Edit and cancel], [Update an existing activity and cancel another one.], [Changes propagate to the interface and canceled activities no longer accept applications.],
  [Invalid], [Unauthorised management], [Attempt to edit or cancel an activity without organiser rights.], [The request is rejected and the activity remains unchanged.],

  sc-header("5", "Apply with Capacity Protection"),
  [Valid], [Normal application], [Apply to an open activity with places remaining.], [One participation record is created and the volunteer count increases by one.],
  [Invalid], [Duplicate application], [Apply twice to the same activity.], [The second request is rejected; no duplicate record is created.],
  [Invalid], [Full activity], [Apply to an activity that has already reached its capacity.], [The request is rejected with a capacity-full error.],
  [Boundary], [Concurrent last place], [Two users apply simultaneously for the final remaining place.], [Only one application succeeds; capacity is not exceeded.],

  sc-header("6", "Communication"),
  [Valid], [Send message], [A participant sends and reloads a message in the activity chat.], [The message persists and is visible to the organiser and other participants in that activity chat.],
  [Invalid], [Non-member access], [A non-member attempts to read or send messages in an activity chat.], [The request is rejected and no new message is stored.],

  sc-header("7", "Hour Tracking"),
  [Valid], [Confirm hours], [Organiser confirms participation minutes after an activity ends.], [The record moves to the completed state and stores the confirmed minutes.],
  [Invalid], [Premature confirmation], [Attempt to confirm participation before the activity has ended.], [The system blocks the confirmation.],
  [Invalid], [Wrong role], [A volunteer attempts to confirm hours for another user.], [The request is rejected.],

  sc-header("8", "Leaderboard"),
  [Valid], [Ranking display], [Open the leaderboard after several completed records exist.], [Users are ranked by confirmed participation minutes in descending order.],
  [Invalid], [Unconfirmed hours], [Check whether unconfirmed records affect ranking totals.], [Unconfirmed participation does not change rankings.],
  [Boundary], [Tied totals], [Give two volunteers equal confirmed totals.], [Tie ordering remains stable and predictable.],

  sc-header("9", "Export"),
  [Valid], [Generate export], [Generate an export spreadsheet for confirmed records.], [A spreadsheet is downloaded in the same overall structure as the school's ISMAS import template, ready for manual import.],
  [Invalid], [Permission denied], [Generate an export without the required authority.], [The request is blocked.],

  sc-header("10", "Platform Compatibility"),
  [Valid], [iPad orientations], [Run the app on iPad in portrait and landscape.], [Core screens remain usable with visible controls and readable content.],
  [Invalid], [Extreme content], [Open screens with very long titles or very long message history.], [The interface scrolls or truncates safely instead of breaking layout.],
  [Boundary], [Mid-action rotation], [Rotate the device during text input and navigation.], [The current screen remains stable and interactive.],
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
  [Teacher/admin web verification], [Dashboard, activity management, student management, operations, and export workflows are verified through browser-based checks.],
)
