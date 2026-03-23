#set document(title: "Criterion B: Design")
#set page(paper: "a4", margin: (x: 2cm, y: 2cm))
#set text(font: "New Computer Modern", size: 10pt)
#set heading(numbering: "1.1")
#set par(leading: 0.58em, justify: true)
#set table(
  stroke: 0.5pt + luma(180),
  inset: 5pt,
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
  v(0.8em)
  text(size: 16pt, weight: "bold", fill: navy, it)
  v(0.3em)
}

#show heading.where(level: 2): it => {
  v(0.6em)
  text(size: 12pt, weight: "bold", fill: navy, it)
  v(0.15em)
}

#show heading.where(level: 3): it => {
  v(0.4em)
  text(size: 10.5pt, weight: "bold", fill: sky, it)
  v(0.1em)
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
  [Relational data model], [The data structure relies on explicit relationships such as users--records--activities and activities--channels--messages, so relational constraints are part of the design.],
  [Short-session interface], [Students use the iPad app between lessons, so the feed, detail page, and records screens are designed for quick scanning and low-friction actions.],
)

== System Decomposition

#figure(
  diagram(
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 5pt,
    spacing: (16pt, 28pt),
    edge-stroke: 0.7pt + luma(120),

    node((3, 0), text(weight: "bold", size: 8pt)[Together], corner-radius: 3pt, name: <root>),

    node((0, 1.2), text(size: 7.5pt)[Account], corner-radius: 3pt, name: <acct>),
    node((1.5, 1.2), text(size: 7.5pt)[Activity], corner-radius: 3pt, name: <activity>),
    node((3, 1.2), text(size: 7.5pt)[Participation], corner-radius: 3pt, name: <participation>),
    node((4.5, 1.2), text(size: 7.5pt)[Communication], corner-radius: 3pt, name: <communication>),
    node((6, 1.2), text(size: 7.5pt)[Administration], corner-radius: 3pt, name: <admin>),

    edge(<root>, <acct>, "->"),
    edge(<root>, <activity>, "->"),
    edge(<root>, <participation>, "->"),
    edge(<root>, <communication>, "->"),
    edge(<root>, <admin>, "->"),

    node((-0.3, 2.4), text(size: 6.5pt)[Register], corner-radius: 2pt),
    node((0.5, 2.4), text(size: 6.5pt)[Login / Profile], corner-radius: 2pt),
    edge(<acct>, (-0.3, 2.4), "->"),
    edge(<acct>, (0.5, 2.4), "->"),

    node((1.1, 2.4), text(size: 6.5pt)[Publish], corner-radius: 2pt),
    node((1.9, 2.4), text(size: 6.5pt)[Browse / Detail], corner-radius: 2pt),
    edge(<activity>, (1.1, 2.4), "->"),
    edge(<activity>, (1.9, 2.4), "->"),

    node((2.6, 2.4), text(size: 6.5pt)[Apply], corner-radius: 2pt),
    node((3.4, 2.4), text(size: 6.5pt)[Confirm Hours], corner-radius: 2pt),
    edge(<participation>, (2.6, 2.4), "->"),
    edge(<participation>, (3.4, 2.4), "->"),

    node((4.1, 2.4), text(size: 6.5pt)[Comments], corner-radius: 2pt),
    node((4.9, 2.4), text(size: 6.5pt)[Channel], corner-radius: 2pt),
    edge(<communication>, (4.1, 2.4), "->"),
    edge(<communication>, (4.9, 2.4), "->"),

    node((5.6, 2.4), text(size: 6.5pt)[Manage Users], corner-radius: 2pt),
    node((6.4, 2.4), text(size: 6.5pt)[Exports], corner-radius: 2pt),
    edge(<admin>, (5.6, 2.4), "->"),
    edge(<admin>, (6.4, 2.4), "->"),
  ),
  caption: [System decomposition diagram],
)

== System Architecture

#figure(
  mermaid(
    "flowchart LR\n    Volunteer[\"Volunteer / Organiser\\nSwiftUI iPad App\"]\n    Admin[\"Administrator\\nReact Admin Panel\"]\n    Server[\"Rust Server\\nAuthentication, permissions, activity lifecycle, messaging, export\"]\n    DB[(\"PostgreSQL / SQLite\\nusers, activities, records, channels, messages, exports\")]\n    Storage[\"File storage\\navatars and attachments\"]\n\n    Volunteer -->|\"HTTPS / JSON API\"| Server\n    Admin -->|\"HTTPS / JSON API\"| Server\n    Server -->|\"SQL queries / transactions\"| DB\n    Server -->|\"Read / write\"| Storage\n"
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

= Database Design

== Core Entities

#table(
  columns: (1fr, 1.2fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Entity],
    text(fill: white, weight: "bold")[Important fields],
    text(fill: white, weight: "bold")[Purpose],
  ),
  [users], [`id`, `email`, `group_id`, `classname`], [Stores volunteer, organiser, and administrator identities.],
  [activities], [`id`, `promoter_id`, `state`, `max_volunteer_num`], [Stores each volunteer opportunity and its lifecycle state.],
  [records], [`activity_id`, `user_id`, `state`, `confirmed_minutes`], [Stores who applied, who completed the activity, and how many minutes were confirmed.],
  [channels], [`id`, `activity_id`, `owner_id`], [Creates one communication space per activity where needed.],
  [messages], [`channel_id`, `sender_id`, `content`], [Stores activity-scoped communication history.],
  [export_batches / export_items], [`creator_id`, `target_format`, `confirmed_minutes`], [Stores report generation data for the school reporting workflow.],
)

== Entity-Relationship Diagram

#figure(
  mermaid(
    "erDiagram\n    GROUPS ||--o{ USERS : assigns\n    GROUPS ||--o{ GROUP_AUTHORITIES : grants\n    USERS ||--o{ SESSIONS : owns\n    USERS ||--o{ ACTIVITIES : creates\n    USERS ||--o{ RECORDS : holds\n    ACTIVITIES ||--o{ RECORDS : contains\n    ACTIVITIES ||--o| CHANNELS : opens\n    CHANNELS ||--o{ CHANNEL_MEMBERS : includes\n    USERS ||--o{ CHANNEL_MEMBERS : joins\n    CHANNELS ||--o{ MESSAGES : stores\n    USERS ||--o{ MESSAGES : sends\n    ACTIVITIES ||--o{ ACTIVITY_COMMENTS : receives\n    USERS ||--o{ ACTIVITY_COMMENTS : writes\n    USERS ||--o{ EXPORT_BATCHES : triggers\n    EXPORT_BATCHES ||--o{ EXPORT_ITEMS : contains\n    USERS ||--o{ EXPORT_ITEMS : references\n    ACTIVITIES ||--o{ EXPORT_ITEMS : references\n\n    GROUPS {\n        string id PK\n        string code UK\n        bool allow_all_authorities\n    }\n    GROUP_AUTHORITIES {\n        string group_id FK\n        string authority PK\n    }\n    USERS {\n        uuid id PK\n        string email UK\n        string realname\n        string classname\n        string group_id FK\n    }\n    SESSIONS {\n        uuid id PK\n        uuid user_id FK\n        datetime generated_at\n        string ip\n    }\n    ACTIVITIES {\n        uuid id PK\n        uuid promoter_id FK\n        string name\n        string state\n        int volunteer_num\n        int max_volunteer_num\n    }\n    RECORDS {\n        uuid id PK\n        uuid activity_id FK\n        uuid user_id FK\n        string state\n        int confirmed_minutes\n        datetime confirmed_at\n    }\n    CHANNELS {\n        uuid id PK\n        uuid owner_id FK\n        uuid activity_id FK\n    }\n    CHANNEL_MEMBERS {\n        uuid channel_id PK\n        uuid user_id PK\n    }\n    MESSAGES {\n        uuid id PK\n        uuid channel_id FK\n        uuid sender_id FK\n        text content\n        datetime sent_at\n    }\n    ACTIVITY_COMMENTS {\n        uuid id PK\n        uuid activity_id FK\n        uuid author_id FK\n        text content\n    }\n    EXPORT_BATCHES {\n        uuid id PK\n        uuid creator_id FK\n        string target_format\n        string status\n    }\n    EXPORT_ITEMS {\n        uuid id PK\n        uuid batch_id FK\n        uuid user_id FK\n        uuid activity_id FK\n        int confirmed_minutes\n    }\n"
  ),
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
  [Channel privacy], [Messages belong to activity channels and access depends on membership rules.],
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
  [Detail view], [Combines full description, current participation state, comments, and the entry point to the channel.],
  [Application control], [The join action is separated from organiser-only controls so that role-based actions stay clear on the interface.],
)

#figure(
  mermaid(
    "flowchart TD\n    Start([Apply request received]) --> Begin[\"Begin transaction\"]\n    Begin --> Exists{\"Activity exists?\"}\n    Exists -- No --> Missing[\"Reject: not found\"]\n    Exists -- Yes --> State{\"State = NeedVolunteer?\"}\n    State -- No --> Closed[\"Reject: not recruiting\"]\n    State -- Yes --> Capacity{\"Capacity available?\"}\n    Capacity -- No --> Full[\"Reject: activity full\"]\n    Capacity -- Yes --> Duplicate{\"Existing record for user?\"}\n    Duplicate -- Yes --> Joined[\"Reject: duplicate application\"]\n    Duplicate -- No --> Create[\"Insert record and increment volunteer count\"]\n    Create --> Sync[\"Sync activity channel membership\"]\n    Sync --> Commit[\"Commit transaction\"]\n    Commit --> Success([Application recorded])\n"
  ),
  caption: [Apply flowchart for the volunteer activity module],
)

== Activity Lifecycle Module

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
    "stateDiagram-v2\n    [*] --> NeedVolunteer\n    NeedVolunteer --> Going: start\n    NeedVolunteer --> Canceled: cancel\n    Going --> Ended: end\n    Going --> Canceled: cancel\n    Ended --> [*]\n    Canceled --> [*]\n"
  ),
  caption: [Activity lifecycle state diagram],
)

== Access and Screen Navigation

#figure(
  diagram(
    spacing: (26pt, 16pt),
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 6pt,
    edge-stroke: 0.7pt + luma(120),

    node((0, 1.4), text(weight: "bold", size: 8pt)[Volunteer], name: <volunteer>),
    node((0, 3.2), text(weight: "bold", size: 8pt)[Organiser], name: <organiser>),
    node((0, 5), text(weight: "bold", size: 8pt)[Administrator], name: <adminactor>),

    node((3, 0.6), text(size: 7pt)[Browse Activity Feed], shape: fletcher.shapes.ellipse, name: <feed>),
    node((3, 1.8), text(size: 7pt)[View Activity Detail], shape: fletcher.shapes.ellipse, name: <detail>),
    node((3, 3), text(size: 7pt)[Apply to Activity], shape: fletcher.shapes.ellipse, name: <apply>),
    node((3, 4.2), text(size: 7pt)[View Personal Records], shape: fletcher.shapes.ellipse, name: <records>),
    node((3, 5.4), text(size: 7pt)[Use Activity Channel], shape: fletcher.shapes.ellipse, name: <channel>),
    node((6.2, 1.2), text(size: 7pt)[Create / Edit Activity], shape: fletcher.shapes.ellipse, name: <create>),
    node((6.2, 2.6), text(size: 7pt)[Confirm Participation], shape: fletcher.shapes.ellipse, name: <confirm>),
    node((6.2, 4), text(size: 7pt)[Manage Users / Groups], shape: fletcher.shapes.ellipse, name: <manage>),
    node((6.2, 5.4), text(size: 7pt)[Generate Export], shape: fletcher.shapes.ellipse, name: <export>),

    edge(<volunteer>, <feed>, "--"),
    edge(<volunteer>, <detail>, "--"),
    edge(<volunteer>, <apply>, "--"),
    edge(<volunteer>, <records>, "--"),
    edge(<volunteer>, <channel>, "--"),

    edge(<organiser>, <feed>, "--"),
    edge(<organiser>, <detail>, "--"),
    edge(<organiser>, <channel>, "--"),
    edge(<organiser>, <create>, "--"),
    edge(<organiser>, <confirm>, "--"),

    edge(<adminactor>, <manage>, "--"),
    edge(<adminactor>, <export>, "--"),
  ),
  caption: [UML use case diagram for main actors and screens],
)

= User Interface Design

== Student-side SwiftUI iPad Interface

#grid(
  columns: 2,
  gutter: 14pt,
  ui-image("design/assets/login-screen.png", [Student sign-in screen]),
  ui-image("design/assets/register-screen.png", [Student registration screen]),
  ui-image("design/assets/square-screen.png", [Student activity feed screen]),
  ui-image("design/assets/detail-screen.png", [Student activity detail screen]),
  ui-image("design/assets/records-screen.png", [Student participation records screen]),
  ui-image("design/assets/messages-screen.png", [Student activity messaging screen]),
  ui-image("design/assets/profile-screen.png", [Student account and profile screen]),
  ui-image("design/assets/create-screen.png", [Organiser activity editor on iPad]),
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
  [Comments and messaging], [Communication is scoped to an activity, which keeps collaboration tied to the correct volunteer task rather than a global chat.],
  [Account and organiser tools], [Profile management and organiser-only controls are separated from student browsing actions to avoid role confusion.],
)

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
  [Export dialog], [Teacher / administrator], [Prepares report data for school reporting workflows.],
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
  [Operations and export], [Permission controls and export preparation are isolated from day-to-day student flows because they are sensitive, infrequent, and administrative.],
)

= Test Plan

The test plan is organised by success criterion. Each criterion includes at least valid and invalid testing, and a boundary test where the feature has a meaningful limit.

#table(
  columns: (0.6fr, 1.4fr, 0.9fr, 1.3fr, 1.4fr),
  table.header(
    text(fill: white, weight: "bold")[SC],
    text(fill: white, weight: "bold")[Feature],
    text(fill: white, weight: "bold")[Test type],
    text(fill: white, weight: "bold")[Planned test case],
    text(fill: white, weight: "bold")[Expected result],
  ),
  [1], [Registration], [Valid], [Submit a new account with school email, password, name, class, and avatar.], [Account is created and can log in successfully.],
  [1], [Registration], [Invalid], [Submit with duplicate school email or missing required fields.], [The form rejects the request with field-specific validation feedback.],
  [2], [Role-based access], [Valid], [Log in as volunteer, organiser, and administrator.], [Each user only sees the screens and actions allowed by the assigned role.],
  [2], [Role-based access], [Invalid], [Attempt organiser/admin actions with a volunteer account.], [Restricted action is denied and does not change server data.],
  [3], [Publish activity], [Valid], [Create an activity with complete title, date, location, duration, and capacity.], [The activity appears correctly in the feed and detail view.],
  [3], [Publish activity], [Invalid], [Submit the create form with missing required values.], [The form highlights missing values and prevents submission.],
  [4], [Edit / cancel activity], [Valid], [Update an existing activity and cancel another one.], [Changes propagate to the interface and canceled activities no longer allow new applications.],
  [4], [Edit / cancel activity], [Invalid], [Attempt to manage an activity without organiser rights.], [The request is rejected and the activity remains unchanged.],
  [5], [Apply with capacity protection], [Valid], [Apply to an open activity with places remaining.], [One participation record is created and the volunteer count increases once.],
  [5], [Apply with capacity protection], [Invalid], [Apply to a full activity or apply twice to the same activity.], [The request is rejected with no duplicate participation record.],
  [5], [Apply with capacity protection], [Boundary], [Two users apply at the same time for the final remaining place.], [Only one application succeeds and capacity is not exceeded.],
  [6], [Activity channel], [Valid], [A member sends and reloads a message in the activity channel.], [The message persists and is visible to channel members.],
  [6], [Activity channel], [Invalid], [A non-member attempts to read or send messages.], [The request is rejected and no new message is stored.],
  [7], [Participation confirmation], [Valid], [Organiser confirms participation minutes after an activity ends.], [The record moves to the completed state and stores the confirmed minutes.],
  [7], [Participation confirmation], [Invalid], [Attempt to confirm participation before the activity is finished or with the wrong role.], [The system blocks the confirmation.],
  [8], [Leaderboard], [Valid], [Open the leaderboard after several completed records exist.], [Users are ranked by confirmed participation minutes.],
  [8], [Leaderboard], [Invalid], [Check whether unconfirmed records affect ranking totals.], [Unconfirmed participation does not change rankings.],
  [8], [Leaderboard], [Boundary], [Give two volunteers equal confirmed totals.], [Tie ordering remains stable and predictable.],
  [9], [Export], [Valid], [Generate a batch for confirmed records.], [The exported file contains the required fields for school reporting.],
  [9], [Export], [Invalid], [Generate an export when the user lacks permission or records are incomplete.], [The request is blocked or incomplete records are excluded.],
  [10], [iPad layout], [Valid], [Run the app on iPad in portrait and landscape.], [Core screens remain usable with visible controls and readable content.],
  [10], [iPad layout], [Invalid], [Open screens with very long titles or long message history.], [The interface scrolls or truncates safely instead of breaking the layout.],
  [10], [iPad layout], [Boundary], [Rotate the device during input and navigation.], [The current screen remains stable and interactive.],
  [Testing evidence], [Backend unit tests], [Ongoing], [Extend unit tests around participation records, ranking, export logic, and other server-side business rules.], [Server-side validation and rule enforcement are checked automatically.],
  [Testing evidence], [SwiftUI XCUITest], [Ongoing], [Extend UI automation for login, feed navigation, activity detail, and records flows on iPad.], [Main student-side iPad journeys are repeatedly verified through interface-level tests.],
  [Testing evidence], [Teacher/admin web verification], [Ongoing], [Use browser-based checks on dashboard, activity management, student management, operations, and export workflows.], [Teacher/admin web workflows are verified alongside the mobile app rather than omitted from the evidence set.],
)
