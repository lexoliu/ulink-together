#set document(title: "Criterion B: Design")
#set page(paper: "a4", margin: (x: 2.3cm, y: 2.3cm))
#set text(font: "New Computer Modern", size: 10.8pt)
#set heading(numbering: "1.1")
#set par(leading: 0.74em, spacing: 0.9em, justify: true)
#set table(
  stroke: 0.5pt + luma(180),
  inset: 6.5pt,
  fill: (_, y) => if y == 0 { rgb("#183153") } else if calc.rem(y, 2) == 0 { rgb("#f8fafc") } else { white },
)

#import "@preview/mmdr:0.2.1": mermaid
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

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

#table(
  columns: (1.1fr, 2fr),
  table.header(
    text(fill: white, weight: "bold")[Design focus],
    text(fill: white, weight: "bold")[How the design addresses the client context],
  ),
  [Shared source of truth], [The app is used by many students and organisers at the same time, so the design keeps activity state, participation records, and messaging on one central server.],
  [Role separation], [Volunteers mainly browse and apply, organisers manage activities and confirmations, and administrators manage users and exports.],
  [Clear activity structure], [Activities, participation records, chat messages, and exports are linked so information stays organised and can be reused across the system.],
  [Short-session interface], [Students use the iPad app between lessons, so the feed, detail page, and records screens are designed for quick scanning and low-friction actions.],
)

#pagebreak()

== System Decomposition

#figure(
  mermaid(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '18px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 38, 'rankSpacing': 62, 'curve': 'basis'}}}%%
    graph TD
    Together --> Account
    Together --> Activity
    Together --> Participation
    Together --> Communication
    Together --> Administration

    Account --> Register
    Account --> Login_Profile[\"Login / Profile\"]

    Activity --> Publish
    Activity --> Browse_Detail[\"Browse / Detail\"]

    Participation --> Apply
    Participation --> Confirm_Hours[\"Confirm Hours\"]

    Communication --> Comments
    Communication --> Channel

    Administration --> Manage_Users[\"Manage Users\"]
    Administration --> Exports
"
  ),
  caption: [System decomposition diagram],
)

== System Architecture

#figure(
  mermaid(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '18px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 48, 'rankSpacing': 72, 'curve': 'basis'}}}%%
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
"
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

#db-table-header("users", "Stores all registered volunteer, organiser, and administrator accounts")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the user], [Primary key],
  [email], [VARCHAR], [The user's school email address], [Unique; required],
  [realname], [VARCHAR], [Full display name], [Required],
  [gender], [VARCHAR], [Gender of the user], [Required],
  [description], [TEXT], [Short biography or personal statement], [-],
  [classname], [VARCHAR], [Class or homeroom identifier], [Required],
  [avatar_path], [VARCHAR], [File path to uploaded avatar image], [Nullable],
  [password_hash], [VARCHAR], [Bcrypt hash of the account password], [Required],
  [group_id], [UUID], [Foreign key to the groups table], [Required; FK → groups.id],
)

#db-table-header("activities", "Stores each volunteer opportunity published by an organiser")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the activity], [Primary key],
  [promoter_id], [UUID], [The organiser who created this activity], [FK → users.id],
  [name], [VARCHAR], [Title of the activity], [Required],
  [location], [VARCHAR], [Where the activity takes place], [Required],
  [state], [VARCHAR], [Current lifecycle state], [One of: need_volunteer, going, ended, canceled],
  [volunteer_num], [INTEGER], [Number of volunteers currently signed up], [Default 0],
  [max_volunteer_num], [INTEGER], [Maximum capacity for volunteers], [Nullable (unlimited if null)],
  [date], [TIMESTAMP], [Scheduled date of the activity], [Nullable],
  [brief_description], [VARCHAR], [Short summary shown in the feed], [Required],
  [description], [TEXT], [Full details shown in the detail view], [Required],
  [duration_minutes], [INTEGER], [Expected duration in minutes], [Required],
)

#db-table-header("records", "Tracks each volunteer's participation in an activity and confirmed hours")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the record], [Primary key],
  [activity_id], [UUID], [The activity this record belongs to], [FK → activities.id],
  [user_id], [UUID], [The volunteer who applied], [FK → users.id],
  [state], [VARCHAR], [Current record state], [One of: todo, done, canceled],
  [confirmed_minutes], [INTEGER], [Minutes confirmed by the organiser], [Default 0],
  [confirmed_at], [TIMESTAMP], [Timestamp of confirmation], [Nullable],
  [confirmed_by], [UUID], [User who confirmed the hours], [Nullable; FK → users.id],
  [updated_at], [TIMESTAMP], [Last modification timestamp], [Required],
)

#db-table-header("channels", "Communication rooms, each linked to one activity")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the channel], [Primary key],
  [name], [VARCHAR], [Display name of the channel], [Required],
  [owner_id], [UUID], [The organiser who owns the channel], [FK → users.id],
  [activity_id], [UUID], [The activity this channel is linked to], [Nullable; FK → activities.id],
  [created_at], [TIMESTAMP], [Creation timestamp], [Required],
)

#db-table-header("messages", "Individual messages sent within activity channels")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the message], [Primary key],
  [channel_id], [UUID], [The channel this message belongs to], [FK → channels.id],
  [sender_id], [UUID], [The user who sent this message], [FK → users.id],
  [content], [TEXT], [Message body text], [Required],
  [sent_at], [TIMESTAMP], [Timestamp when the message was sent], [Required],
)

#db-table-header("export_batches", "Tracks each batch export request for school reporting")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the batch], [Primary key],
  [creator_id], [UUID], [User who initiated the export], [FK → users.id],
  [target_format], [VARCHAR], [Output format (e.g. CSV)], [Required],
  [status], [VARCHAR], [Processing status], [Required],
  [created_at], [TIMESTAMP], [Creation timestamp], [Required],
)

#db-table-header("export_items", "Individual rows within an export batch")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the item], [Primary key],
  [batch_id], [UUID], [The batch this item belongs to], [FK → export_batches.id],
  [user_id], [UUID], [The volunteer being reported], [FK → users.id],
  [activity_id], [UUID], [The activity being reported], [FK → activities.id],
  [confirmed_minutes], [INTEGER], [Confirmed hours for this record], [Required],
)

#db-table-header("groups", "Defines authority groups that control what actions a user can perform")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the group], [Primary key],
  [code], [VARCHAR], [Short code such as "admin" or "student"], [Unique; required],
  [allow_all_authorities], [BOOLEAN], [Whether this group bypasses individual authority checks], [Default false],
)

#db-table-header("group_authorities", "Maps specific permissions to groups that do not have blanket access")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [group_id], [UUID], [The group receiving this authority], [PK (composite); FK → groups.id],
  [authority], [VARCHAR], [The permission string such as "manage_activity_anyway"], [PK (composite)],
)

#db-table-header("sessions", "Tracks active login sessions for cookie-based authentication")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique session identifier], [Primary key],
  [user_id], [UUID], [The user who owns this session], [FK → users.id],
  [generated_at], [TIMESTAMP], [When the session was created], [Required],
  [ip], [VARCHAR], [IP address at login time], [Required],
)

#db-table-header("channel_members", "Junction table linking users to the channels they have joined")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [channel_id], [UUID], [The channel], [PK (composite); FK → channels.id],
  [user_id], [UUID], [The member], [PK (composite); FK → users.id],
)

#db-table-header("activity_comments", "Public comments attached to an activity for open discussion")

#table(
  columns: (1fr, 0.8fr, 1.8fr, 1.2fr),
  field-header,
  [id], [UUID], [Unique identifier for the comment], [Primary key],
  [activity_id], [UUID], [The activity this comment belongs to], [FK → activities.id],
  [author_id], [UUID], [The user who wrote the comment], [FK → users.id],
  [content], [TEXT], [Comment body text], [Required],
  [created_at], [TIMESTAMP], [Timestamp when the comment was posted], [Required],
)

== Entity-Relationship Diagram

#figure(
  mermaid(
    read("assets/generated-schema-relations.mmd")
  ),
  caption: [Automatically generated schema relationship diagram],
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

#figure(
  mermaid(
    "%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '20px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}}}%%
    stateDiagram-v2
    direction LR
    [*] --> NeedVolunteer
    NeedVolunteer --> Going: start
    NeedVolunteer --> Canceled: cancel
    Going --> Ended: end
    Going --> Canceled: cancel
    Ended --> [*]
    Canceled --> [*]
"
  ),
  caption: [Activity lifecycle state diagram],
)

#pagebreak()

= Use Case Diagram

The following UML use case diagram shows the three main actors and the functions each actor can access within the system.

#figure(
  diagram(
    spacing: (44pt, 28pt),
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 10pt,
    edge-stroke: 0.6pt + luma(140),

    // Actors (stick-figure placeholders on the left)
    node((0, 1), text(weight: "bold", size: 9pt)[Volunteer], name: <volunteer>, shape: rect, corner-radius: 3pt),
    node((0, 3.8), text(weight: "bold", size: 9pt)[Organiser], name: <organiser>, shape: rect, corner-radius: 3pt),
    node((0, 6.6), text(weight: "bold", size: 9pt)[Administrator], name: <admin>, shape: rect, corner-radius: 3pt),

    // Use cases (ellipses in the centre)
    node((4.1, 0), text(size: 8pt)[Browse Activity Feed], shape: fletcher.shapes.ellipse, name: <feed>),
    node((4.1, 1.4), text(size: 8pt)[View Activity Detail], shape: fletcher.shapes.ellipse, name: <detail>),
    node((4.1, 2.8), text(size: 8pt)[Apply to Activity], shape: fletcher.shapes.ellipse, name: <apply>),
    node((4.1, 4.2), text(size: 8pt)[View Personal Records], shape: fletcher.shapes.ellipse, name: <records>),
    node((4.1, 5.6), text(size: 8pt)[Use Activity Chat], shape: fletcher.shapes.ellipse, name: <channel>),
    node((4.1, 7.0), text(size: 8pt)[View Leaderboard], shape: fletcher.shapes.ellipse, name: <leaderboard>),

    node((8.6, 1.4), text(size: 8pt)[Create / Edit Activity], shape: fletcher.shapes.ellipse, name: <create>),
    node((8.6, 3.8), text(size: 8pt)[Confirm Participation], shape: fletcher.shapes.ellipse, name: <confirm>),

    node((8.6, 6.2), text(size: 8pt)[Manage Users / Groups], shape: fletcher.shapes.ellipse, name: <manage>),
    node((8.6, 7.8), text(size: 8pt)[Generate Export], shape: fletcher.shapes.ellipse, name: <export>),

    // Volunteer associations
    edge(<volunteer>, <feed>, "--"),
    edge(<volunteer>, <detail>, "--"),
    edge(<volunteer>, <apply>, "--"),
    edge(<volunteer>, <records>, "--"),
    edge(<volunteer>, <channel>, "--"),
    edge(<volunteer>, <leaderboard>, "--"),

    // Organiser associations
    edge(<organiser>, <feed>, "--"),
    edge(<organiser>, <detail>, "--"),
    edge(<organiser>, <channel>, "--"),
    edge(<organiser>, <create>, "--"),
    edge(<organiser>, <confirm>, "--"),
    edge(<organiser>, <leaderboard>, "--"),

    // Administrator associations
    edge(<admin>, <manage>, "--"),
    edge(<admin>, <export>, "--"),
    edge(<admin>, <create>, "--"),
  ),
  caption: [UML use case diagram mapping actors to system functions],
)

= User Interface Design

== Student-side SwiftUI iPad Interface

#figure(
  image("assets/wireframe-student-annotated.svg", width: 94%),
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
  [Operations / permissions], [Administrator], [Supports authority changes and notification-related administrative actions.],
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
  image("assets/wireframe-admin-activity.svg", width: 94%),
  caption: [Teacher/admin annotated wireframe for the activity management workspace],
)

#pagebreak()

#figure(
  image("assets/wireframe-admin-students.svg", width: 94%),
  caption: [Teacher/admin annotated wireframe for the student management workspace],
)

#pagebreak()

#figure(
  image("assets/wireframe-admin-operations.svg", width: 94%),
  caption: [Teacher/admin annotated wireframe for the operations and permissions workspace],
)

#pagebreak()

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
