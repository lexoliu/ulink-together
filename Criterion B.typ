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

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/chronos:0.3.0"

#let navy = rgb("#183153")
#let sky = rgb("#4d7ac7")
#let ink-soft = rgb("#5f6b7a")

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

// Placeholder for screenshots to be added later
#let screenshot-placeholder(caption, height: 180pt) = figure(
  box(
    width: 100%,
    height: height,
    fill: rgb("#f5f5f5"),
    stroke: 1pt + luma(200),
    radius: 4pt,
    align(center + horizon)[
      #text(fill: luma(140), size: 9pt, style: "italic")[Screenshot to be inserted: #caption]
    ],
  ),
  caption: caption,
)

#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Criterion B: Design]
]

= Overall Design

== System Decomposition

The system is decomposed into six functional modules. Each module groups a set of related operations that correspond to the user tasks identified during the client consultation.

#figure(
  diagram(
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 5pt,
    spacing: (14pt, 22pt),
    edge-stroke: 0.7pt + luma(120),

    // Root
    node((3, 0), text(weight: "bold", size: 8pt)[Together], corner-radius: 3pt, name: <root>),

    // Level 1 modules
    node((0, 1), text(size: 7.5pt)[Account], corner-radius: 3pt, name: <acct>),
    node((1.2, 1), text(size: 7.5pt)[Activity], corner-radius: 3pt, name: <act>),
    node((2.4, 1), text(size: 7.5pt)[Participation], corner-radius: 3pt, name: <part>),
    node((3.6, 1), text(size: 7.5pt)[Communication], corner-radius: 3pt, name: <comm>),
    node((4.8, 1), text(size: 7.5pt)[Ranking], corner-radius: 3pt, name: <rank>),
    node((6, 1), text(size: 7.5pt)[Administration], corner-radius: 3pt, name: <admin>),

    // Root to modules
    edge(<root>, <acct>, "->"),
    edge(<root>, <act>, "->"),
    edge(<root>, <part>, "->"),
    edge(<root>, <comm>, "->"),
    edge(<root>, <rank>, "->"),
    edge(<root>, <admin>, "->"),

    // Account sub-functions
    node((-0.4, 2), text(size: 6.5pt)[Register], corner-radius: 2pt),
    node((0, 2.7), text(size: 6.5pt)[Login], corner-radius: 2pt),
    node((0.4, 2), text(size: 6.5pt)[Edit Profile], corner-radius: 2pt),
    edge(<acct>, (-0.4, 2), "->"),
    edge(<acct>, (0, 2.7), "->"),
    edge(<acct>, (0.4, 2), "->"),

    // Activity sub-functions
    node((0.8, 2), text(size: 6.5pt)[Browse], corner-radius: 2pt),
    node((1.2, 2.7), text(size: 6.5pt)[Create], corner-radius: 2pt),
    node((1.6, 2), text(size: 6.5pt)[Edit / Cancel], corner-radius: 2pt),
    edge(<act>, (0.8, 2), "->"),
    edge(<act>, (1.2, 2.7), "->"),
    edge(<act>, (1.6, 2), "->"),

    // Participation sub-functions
    node((2, 2), text(size: 6.5pt)[Join], corner-radius: 2pt),
    node((2.4, 2.7), text(size: 6.5pt)[Confirm], corner-radius: 2pt),
    node((2.8, 2), text(size: 6.5pt)[View Records], corner-radius: 2pt),
    edge(<part>, (2, 2), "->"),
    edge(<part>, (2.4, 2.7), "->"),
    edge(<part>, (2.8, 2), "->"),

    // Communication sub-functions
    node((3.2, 2), text(size: 6.5pt)[Comment], corner-radius: 2pt),
    node((3.6, 2.7), text(size: 6.5pt)[Channel], corner-radius: 2pt),
    node((4, 2), text(size: 6.5pt)[Notify], corner-radius: 2pt),
    edge(<comm>, (3.2, 2), "->"),
    edge(<comm>, (3.6, 2.7), "->"),
    edge(<comm>, (4, 2), "->"),

    // Ranking sub-functions
    node((4.5, 2), text(size: 6.5pt)[Leaderboard], corner-radius: 2pt),
    node((5.1, 2), text(size: 6.5pt)[Statistics], corner-radius: 2pt),
    edge(<rank>, (4.5, 2), "->"),
    edge(<rank>, (5.1, 2), "->"),

    // Administration sub-functions
    node((5.5, 2), text(size: 6.5pt)[Manage Users], corner-radius: 2pt),
    node((6, 2.7), text(size: 6.5pt)[Export], corner-radius: 2pt),
    node((6.5, 2), text(size: 6.5pt)[Manage Groups], corner-radius: 2pt),
    edge(<admin>, (5.5, 2), "->"),
    edge(<admin>, (6, 2.7), "->"),
    edge(<admin>, (6.5, 2), "->"),
  ),
  caption: [System decomposition diagram],
)

== System Architecture

I chose a client-server architecture because volunteer data is shared across users. If two students join the same activity at the same time, a local-only approach would have no way to enforce the capacity limit. The server acts as the single authority on the current state.

The system has three client applications that communicate with a single backend:

- *SwiftUI iPad Application* -- the primary interface for volunteers and activity organisers
- *React Admin Panel* -- a web-based tool for system administrators to manage users, groups, and exports
- *Rust Server* -- handles authentication, validation, business logic, and database access

#figure(
  diagram(
    spacing: (30pt, 20pt),
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 8pt,
    edge-stroke: 0.7pt + luma(120),

    // Clients
    node((0, 0), align(center)[#text(size: 8pt, weight: "bold")[SwiftUI iPad App] \ #text(size: 7pt, fill: ink-soft)[Presentation, local state, \ forms, push subscription]], corner-radius: 5pt, name: <ios>),

    node((0, 2), align(center)[#text(size: 8pt, weight: "bold")[React Admin Panel] \ #text(size: 7pt, fill: ink-soft)[User management, groups, \ exports, monitoring]], corner-radius: 5pt, name: <admin>),

    // Server
    node((2, 1), align(center)[#text(size: 8pt, weight: "bold")[Rust Server (skyzen)] \ #text(size: 7pt, fill: ink-soft)[Auth, permissions, activity \ lifecycle, ranking, export]], corner-radius: 5pt, name: <server>),

    // Database
    node((4, 1), align(center)[#text(size: 8pt, weight: "bold")[SQLite / PostgreSQL] \ #text(size: 7pt, fill: ink-soft)[Users, activities, records, \ channels, messages, exports]], corner-radius: 5pt, shape: fletcher.shapes.hexagon, name: <db>),

    // File storage
    node((4, 2.5), align(center)[#text(size: 8pt, weight: "bold")[File Storage] \ #text(size: 7pt, fill: ink-soft)[Avatars, resources]], corner-radius: 5pt, name: <fs>),

    // Edges
    edge(<ios>, <server>, "->", label: text(size: 7pt)[HTTPS / JSON], label-side: left),
    edge(<admin>, <server>, "->", label: text(size: 7pt)[HTTPS / JSON], label-side: left),
    edge(<server>, <db>, "<->", label: text(size: 7pt)[SQL queries]),
    edge(<server>, <fs>, "->", label: text(size: 7pt)[read / write], label-side: left),
  ),
  caption: [System architecture diagram],
)

=== Component Responsibilities

#table(
  columns: (1fr, 1.3fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Component],
    text(fill: white, weight: "bold")[Responsibility],
    text(fill: white, weight: "bold")[Rationale],
  ),
  [SwiftUI layer], [Screens, navigation, forms, validation feedback, accessibility], [View logic is separated from data rules. This makes it possible to test the UI independently and to update the layout without changing the server.],
  [Client state], [Session token, selected filters, pending request state, cached content], [The app needs to feel responsive, so some data is cached locally. Business rules are not duplicated on the client.],
  [Rust server], [Authentication, permissions, activity state machine, ranking, export generation], [These rules run in one place so all clients see the same result. The server also handles concurrency control for the join operation.],
  [Database], [Persistent storage for all entities], [Volunteer hours and message history must survive restarts. Relational constraints enforce data integrity at the storage layer.],
  [Admin panel], [User batch import, group management, export triggers, system monitoring], [Administrative tasks are infrequent and require a wider screen, so a separate web interface is appropriate.],
)

== Development Timeline

#figure(
  box(
    width: 100%,
    fill: rgb("#f8fafc"),
    stroke: 0.5pt + luma(200),
    radius: 6pt,
    inset: 10pt,
  )[
    #set text(size: 8pt)
    #let bar(label, start, length, fill-color: sky) = {
      h(start)
      box(
        width: length,
        height: 12pt,
        fill: fill-color,
        radius: 3pt,
        inset: (x: 4pt, y: 2pt),
      )[#text(fill: white, weight: "bold", size: 7pt)[#label]]
    }

    #text(weight: "bold", size: 9pt, fill: navy)[Project Timeline]
    #v(4pt)

    #grid(
      columns: (60pt, 1fr),
      gutter: 4pt,
      text(fill: ink-soft)[Planning],
      bar([Criterion A], 0pt, 60pt, fill-color: rgb("#6b8ec9")),

      text(fill: ink-soft)[Design],
      bar([Criterion B], 20pt, 80pt, fill-color: rgb("#4d7ac7")),

      text(fill: ink-soft)[Server],
      bar([Auth + API], 40pt, 100pt, fill-color: rgb("#2d8f66")),

      text(fill: ink-soft)[iPad App],
      bar([SwiftUI], 60pt, 110pt, fill-color: rgb("#d65d7a")),

      text(fill: ink-soft)[Admin],
      bar([React Panel], 100pt, 60pt, fill-color: rgb("#b37a00")),

      text(fill: ink-soft)[Testing],
      bar([Criterion D], 130pt, 50pt, fill-color: rgb("#7b8798")),

      text(fill: ink-soft)[Evaluation],
      bar([Criterion E], 150pt, 40pt, fill-color: rgb("#94a3b8")),
    )
    #v(4pt)
    #grid(
      columns: (60pt, 1fr),
      [],
      {
        set text(size: 7pt, fill: ink-soft)
        grid(
          columns: (1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
          [Sep 2025], [Oct], [Nov], [Dec], [Jan 2026], [Feb--Mar],
        )
      },
    )
  ],
  caption: [Development timeline (approximate)],
)

= Database Design

== Rationale

I used a relational database because most of the data involves relationships: a user _joins_ an activity, an activity _has_ a channel, a channel _contains_ messages. A document database could work, but I would lose the ability to enforce foreign keys and unique constraints at the database level. The unique constraint on `(activity_id, user_id)` in the records table, for example, is what makes duplicate joins impossible even if the application code has a bug.

The server supports both SQLite (for development and testing) and PostgreSQL (for production deployment). The schema uses SQL that is compatible with both.

== Entity Definitions

#set text(size: 9pt)

=== groups

Defines permission groups. The system seeds two built-in groups: `admin` (with all authorities) and `student`.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT], [Primary key], [PK],
  [code], [TEXT], [Group identifier (e.g. "admin", "student")], [UNIQUE],
  [allow_all_authorities], [INTEGER], [If set, the group grants all permissions], [Default 0],
)

=== group_authorities

Maps specific permissions to groups. Each authority is a string such as `"manage_activity_anyway"` or `"manage_user"`.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [group_id], [TEXT], [References groups.id], [PK (composite)],
  [authority], [TEXT], [Permission string], [PK (composite)],
)

=== users

Stores all user accounts. Each user belongs to exactly one group.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [email], [TEXT], [School email address, used for login], [UNIQUE],
  [realname], [TEXT], [Student's full name], [],
  [gender], [TEXT], [Gender], [],
  [description], [TEXT], [Profile description], [],
  [classname], [TEXT], [Class identifier (e.g. "11A")], [],
  [avatar_path], [TEXT], [Path to uploaded avatar image], [Nullable],
  [password_hash], [TEXT], [bcrypt hash of the password], [],
  [salt], [TEXT], [Salt used for hashing], [],
  [group_id], [TEXT], [References groups.id], [FK],
)

=== sessions

Tracks active login sessions. Each session is tied to an IP address to support multi-device identification.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Session token], [PK],
  [user_id], [TEXT], [References users.id], [FK, indexed],
  [generated_at], [TEXT], [ISO timestamp of session creation], [],
  [ip], [TEXT], [IP address of the client device], [],
)

=== activities

Core table for volunteer activities. The `state` field tracks the activity's position in its lifecycle.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [promoter_id], [TEXT], [The organiser who created this activity], [FK → users],
  [name], [TEXT], [Activity title], [],
  [location], [TEXT], [Where the activity takes place], [],
  [state], [TEXT], [Current lifecycle state], [See state machine],
  [volunteer_num], [INTEGER], [Current number of joined volunteers], [Default 0],
  [max_volunteer_num], [INTEGER], [Capacity limit], [Nullable],
  [date], [TEXT], [Scheduled date], [Nullable],
  [brief_description], [TEXT], [Short summary shown in the feed], [],
  [description], [TEXT], [Full details shown on the detail screen], [],
  [duration_minutes], [INTEGER], [Expected duration in minutes], [],
)

=== records

Tracks each volunteer's relationship with an activity. This is the core business table: it records who joined, whether they completed the activity, and how many minutes were confirmed.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [activity_id], [TEXT], [References activities.id], [FK, indexed],
  [user_id], [TEXT], [References users.id], [FK, indexed],
  [state], [TEXT], [todo, done, or canceled], [],
  [confirmed_minutes], [INTEGER], [Verified participation duration], [Default 0],
  [confirmed_at], [TEXT], [When the hours were confirmed], [Nullable],
  [confirmed_by], [TEXT], [Who confirmed the hours], [Nullable],
  [updated_at], [TEXT], [Last modification timestamp], [],
)

A unique index on `(activity_id, user_id)` prevents duplicate participation records.

=== activity_comments

Public comments on activities, visible to all users.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [activity_id], [TEXT], [References activities.id], [FK, indexed],
  [author_id], [TEXT], [References users.id], [FK],
  [content], [TEXT], [Comment text], [],
  [created_at], [TEXT], [Timestamp], [],
)

=== channels

Messaging channels, scoped to activities. Each activity may have one channel for coordination.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [name], [TEXT], [Channel display name], [],
  [owner_id], [TEXT], [Channel creator], [FK → users],
  [activity_id], [TEXT], [Linked activity], [Nullable, FK → activities],
  [created_at], [TEXT], [Timestamp], [],
)

=== channel_members

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [channel_id], [TEXT], [References channels.id], [PK (composite)],
  [user_id], [TEXT], [References users.id], [PK (composite)],
)

=== messages

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [channel_id], [TEXT], [References channels.id], [FK, indexed],
  [sender_id], [TEXT], [References users.id], [FK, indexed],
  [content], [TEXT], [Message body], [],
  [sent_at], [TEXT], [Timestamp], [],
)

=== notifications

System notifications delivered to individual users.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [user_id], [TEXT], [References users.id], [FK, indexed],
  [title], [TEXT], [Notification title], [],
  [content], [TEXT], [Notification body], [],
  [created_at], [TEXT], [Timestamp], [],
)

=== resources

Uploaded files (avatars, attachments).

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [creator_id], [TEXT], [References users.id], [FK],
  [name], [TEXT], [Original file name], [],
  [extension], [TEXT], [File extension], [],
  [created_at], [TEXT], [Timestamp], [],
)

=== export_batches and export_items

Used to generate reports for the school's administrative import workflow.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  table.cell(colspan: 4, fill: rgb("#eef2f7"))[#text(weight: "bold")[export_batches]],
  [id], [TEXT (UUID)], [Primary key], [PK],
  [creator_id], [TEXT], [Admin who triggered the export], [FK → users],
  [target_format], [TEXT], [e.g. "csv"], [],
  [status], [TEXT], [pending, completed, or failed], [],
  [created_at], [TEXT], [Timestamp], [],
  table.cell(colspan: 4, fill: rgb("#eef2f7"))[#text(weight: "bold")[export_items]],
  [id], [TEXT (UUID)], [Primary key], [PK],
  [batch_id], [TEXT], [References export_batches.id], [FK, indexed],
  [user_id], [TEXT], [The volunteer], [FK → users],
  [activity_id], [TEXT], [The activity], [FK → activities],
  [activity_title], [TEXT], [Denormalized title for the export], [],
  [activity_date], [TEXT], [Denormalized date], [Nullable],
  [student_name], [TEXT], [Denormalized student name], [],
  [class_name], [TEXT], [Denormalized class], [],
  [confirmed_minutes], [INTEGER], [Verified duration], [],
  [confirmed_at], [TEXT], [Confirmation timestamp], [Nullable],
)

=== check_mails

Stores email verification codes for the registration process.

#table(
  columns: (1fr, 0.8fr, 2fr, 1.2fr),
  table.header(
    text(fill: white, weight: "bold")[Field],
    text(fill: white, weight: "bold")[Type],
    text(fill: white, weight: "bold")[Description],
    text(fill: white, weight: "bold")[Constraints],
  ),
  [id], [TEXT (UUID)], [Primary key], [PK],
  [email], [TEXT], [Email address to verify], [Indexed],
  [code], [TEXT], [Verification code], [],
  [created_at], [TEXT], [Timestamp], [],
)

#set text(size: 10pt)

== Entity-Relationship Diagram

The diagram below shows the primary and foreign key relationships between all entities. Crow's foot notation indicates cardinality.

#figure(
  diagram(
    spacing: (25pt, 18pt),
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 6pt,
    edge-stroke: 0.6pt + luma(100),

    // Core entities
    node((0, 0), align(center)[#text(size: 7.5pt, weight: "bold")[groups] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · code]], corner-radius: 3pt, name: <g>),
    node((2, 0), align(center)[#text(size: 7.5pt, weight: "bold")[group_authorities] \ #text(size: 6.5pt, fill: ink-soft)[group_id · authority]], corner-radius: 3pt, name: <ga>),
    node((0, 1.5), align(center)[#text(size: 7.5pt, weight: "bold")[users] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · email · realname \ classname · password_hash · group_id (FK)]], corner-radius: 3pt, name: <u>),
    node((2.5, 1.5), align(center)[#text(size: 7.5pt, weight: "bold")[sessions] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · user_id (FK)]], corner-radius: 3pt, name: <s>),
    node((0, 3.2), align(center)[#text(size: 7.5pt, weight: "bold")[activities] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · promoter_id (FK) \ name · state · volunteer_num]], corner-radius: 3pt, name: <a>),
    node((2.5, 3.2), align(center)[#text(size: 7.5pt, weight: "bold")[records] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · activity_id (FK) \ user_id (FK) · state · confirmed_minutes]], corner-radius: 3pt, name: <r>),
    node((-1.5, 4.5), align(center)[#text(size: 7.5pt, weight: "bold")[channels] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · activity_id (FK)]], corner-radius: 3pt, name: <ch>),
    node((0.5, 4.5), align(center)[#text(size: 7.5pt, weight: "bold")[messages] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · channel_id (FK) \ sender_id (FK)]], corner-radius: 3pt, name: <m>),
    node((2.5, 4.5), align(center)[#text(size: 7.5pt, weight: "bold")[activity_comments] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · activity_id (FK) \ author_id (FK)]], corner-radius: 3pt, name: <ac>),
    node((0.5, 6), align(center)[#text(size: 7.5pt, weight: "bold")[export_batches] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · creator_id (FK)]], corner-radius: 3pt, name: <eb>),
    node((2.5, 6), align(center)[#text(size: 7.5pt, weight: "bold")[export_items] \ #text(size: 6.5pt, fill: ink-soft)[id (PK) · batch_id (FK)]], corner-radius: 3pt, name: <ei>),

    // Relationships
    edge(<g>, <ga>, "->>", label: text(size: 6pt)[1..#sym.ast]),
    edge(<g>, <u>, "->>", label: text(size: 6pt)[1..#sym.ast], label-side: left),
    edge(<u>, <s>, "->>", label: text(size: 6pt)[1..#sym.ast]),
    edge(<u>, <a>, "->>", label: text(size: 6pt)[organises], label-side: left),
    edge(<u>, <r>, "->>", label: text(size: 6pt)[participates]),
    edge(<a>, <r>, "->>", label: text(size: 6pt)[1..#sym.ast], label-side: left),
    edge(<a>, <ch>, "->>", label: text(size: 6pt)[0..1], label-side: left),
    edge(<a>, <ac>, "->>", label: text(size: 6pt)[1..#sym.ast]),
    edge(<ch>, <m>, "->>", label: text(size: 6pt)[1..#sym.ast], label-side: left),
    edge(<u>, <eb>, "->>", label: text(size: 6pt)[creates], label-side: left),
    edge(<eb>, <ei>, "->>", label: text(size: 6pt)[1..#sym.ast]),
  ),
  caption: [Entity-relationship diagram],
)

== Key Data Rules

#table(
  columns: (1.2fr, 2.5fr),
  table.header(
    text(fill: white, weight: "bold")[Rule],
    text(fill: white, weight: "bold")[Enforcement mechanism],
  ),
  [No duplicate joins], [Unique index on `(activity_id, user_id)` in the records table],
  [Capacity count stays accurate], [The participant count update and record creation happen inside a single database transaction with `BEGIN IMMEDIATE`],
  [Only confirmed hours count for rankings], [The leaderboard aggregates `confirmed_minutes` from records where `state = 'done'`],
  [Channel messages are private], [The server checks channel membership before allowing reads or writes],
  [Cancellation cascades to records], [When an activity is canceled, all non-done records are atomically set to canceled],
  [Group permissions are additive], [A group with `allow_all_authorities = 1` bypasses all individual authority checks],
)

= Internal Structures and Algorithms

== Activity State Machine

Activities follow a defined lifecycle. I chose to represent state as a single `state` field rather than boolean flags because flags create ambiguous combinations (e.g. what does `is_active = true` and `is_cancelled = true` mean?).

#figure(
  diagram(
    spacing: (35pt, 25pt),
    node-stroke: 0.8pt + navy,
    node-fill: white,
    node-inset: 8pt,
    edge-stroke: 0.7pt + luma(100),

    node((0, 0), text(size: 8pt, weight: "bold")[NeedVolunteer], corner-radius: 20pt, name: <nv>),
    node((2, 0), text(size: 8pt, weight: "bold")[Going], corner-radius: 20pt, name: <go>),
    node((4, 0), text(size: 8pt, weight: "bold")[Ended], corner-radius: 20pt, name: <end>),
    node((2, 1.5), text(size: 8pt, weight: "bold")[Canceled], corner-radius: 20pt, fill: rgb("#fff0f2"), name: <can>),

    edge(<nv>, <go>, "->", label: text(size: 7pt)[start]),
    edge(<go>, <end>, "->", label: text(size: 7pt)[end]),
    edge(<nv>, <can>, "->", label: text(size: 7pt)[cancel], label-side: left),
    edge(<go>, <can>, "->", label: text(size: 7pt)[cancel]),
  ),
  caption: [Activity state machine],
)

#table(
  columns: (1fr, 2fr, 1fr),
  table.header(
    text(fill: white, weight: "bold")[State],
    text(fill: white, weight: "bold")[Meaning],
    text(fill: white, weight: "bold")[Visible to volunteers?],
  ),
  [NeedVolunteer], [Published and open for sign-up], [Yes],
  [Going], [The activity has started; no more joining], [Yes],
  [Ended], [Finished; hours eligible for confirmation], [Yes (as history)],
  [Canceled], [Called off; all non-done records cascaded to canceled], [Yes (as cancelled)],
)

When an activity transitions to `Canceled`, the server executes:
```sql
UPDATE records
SET state = 'canceled', confirmed_minutes = 0,
    confirmed_at = NULL, confirmed_by = NULL
WHERE activity_id = ? AND state != 'done'
```
This ensures that already-confirmed hours are preserved while all pending participations are cancelled atomically.

== Join Algorithm

The join operation is the most algorithmically interesting part of the system because it combines validation, concurrency control, and business rules in a single transaction.

#figure(
  diagram(
    spacing: (12pt, 14pt),
    node-stroke: 0.6pt + luma(100),
    node-fill: white,
    node-inset: 5pt,
    edge-stroke: 0.6pt + luma(100),

    // Start
    node((2, 0), text(size: 7pt)[BEGIN IMMEDIATE], shape: fletcher.shapes.pill, name: <start>),

    // Check exists
    node((2, 1), text(size: 7pt)[Activity exists?], shape: fletcher.shapes.diamond, name: <exists>),
    node((4, 1), text(size: 7pt, fill: red)[ROLLBACK: not found], shape: fletcher.shapes.pill, name: <e1>),

    // Check state
    node((2, 2), text(size: 7pt)[State = NeedVolunteer?], shape: fletcher.shapes.diamond, name: <state>),
    node((4, 2), text(size: 7pt, fill: red)[ROLLBACK: not recruiting], shape: fletcher.shapes.pill, name: <e2>),

    // Check capacity
    node((2, 3), text(size: 7pt)[volunteer_num < max?], shape: fletcher.shapes.diamond, name: <cap>),
    node((4, 3), text(size: 7pt, fill: red)[ROLLBACK: full], shape: fletcher.shapes.pill, name: <e3>),

    // Check duplicate
    node((2, 4), text(size: 7pt)[No existing record?], shape: fletcher.shapes.diamond, name: <dup>),
    node((4, 4), text(size: 7pt, fill: red)[ROLLBACK: already joined], shape: fletcher.shapes.pill, name: <e4>),

    // Success
    node((2, 5), text(size: 7pt)[Create record + increment count], corner-radius: 3pt, name: <create>),
    node((2, 6), text(size: 7pt)[COMMIT], shape: fletcher.shapes.pill, name: <commit>),
    node((2, 7), text(size: 7pt)[Sync channel membership], corner-radius: 3pt, name: <sync>),

    // Edges
    edge(<start>, <exists>, "->"),
    edge(<exists>, <e1>, "->", label: text(size: 6pt)[No]),
    edge(<exists>, <state>, "->", label: text(size: 6pt)[Yes], label-side: left),
    edge(<state>, <e2>, "->", label: text(size: 6pt)[No]),
    edge(<state>, <cap>, "->", label: text(size: 6pt)[Yes], label-side: left),
    edge(<cap>, <e3>, "->", label: text(size: 6pt)[No]),
    edge(<cap>, <dup>, "->", label: text(size: 6pt)[Yes], label-side: left),
    edge(<dup>, <e4>, "->", label: text(size: 6pt)[No]),
    edge(<dup>, <create>, "->", label: text(size: 6pt)[Yes], label-side: left),
    edge(<create>, <commit>, "->"),
    edge(<commit>, <sync>, "->"),
  ),
  caption: [Join algorithm flowchart],
)

The transaction uses `BEGIN IMMEDIATE` (SQLite) or `BEGIN` (PostgreSQL). The `IMMEDIATE` keyword is critical for SQLite because it acquires a write lock at the start of the transaction, preventing two concurrent join requests from both reading the same participant count before either writes.

== Join Sequence Diagram

#figure(
  chronos.diagram({
    import chronos: *
    _par("Volunteer", display-name: "Volunteer")
    _par("iPad App", display-name: "iPad App")
    _par("Server", display-name: "Server")
    _par("Database", display-name: "Database")

    _seq("Volunteer", "iPad App", comment: "Tap Join button")
    _seq("iPad App", "Server", comment: "POST /api/v1/activity/{id}/apply")
    _seq("Server", "Database", comment: "BEGIN IMMEDIATE")
    _seq("Server", "Database", comment: "SELECT state, volunteer_num, max")
    _seq("Database", "Server", comment: "row data", dashed: true)

    _alt(
      "state = need_volunteer AND not full AND not duplicate",
      {
        _seq("Server", "Database", comment: "INSERT INTO records")
        _seq("Server", "Database", comment: "UPDATE volunteer_num += 1")
        _seq("Server", "Database", comment: "COMMIT")
        _seq("Server", "iPad App", comment: "200 OK: joined", dashed: true)
        _seq("Server", "Database", comment: "Sync channel membership")
      },
      "otherwise",
      {
        _seq("Server", "Database", comment: "ROLLBACK")
        _seq("Server", "iPad App", comment: "403: rejection", dashed: true)
      },
    )
    _seq("iPad App", "Volunteer", comment: "Update UI state", dashed: true)
  }),
  caption: [Sequence diagram for the join operation],
)

== Leaderboard Computation

The leaderboard is computed fresh from confirmed participation data rather than from stored running totals. This avoids the risk of totals drifting out of sync with the actual records.

The server queries all records where `state = 'done'`, then aggregates `confirmed_minutes` per user in application code. The result is sorted by total minutes descending, with ties broken by name in ascending alphabetical order.

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

After the query, the server groups by user, sums `confirmed_minutes`, sorts by descending total, and assigns rank numbers. The secondary sort by `realname` ensures that tied volunteers always appear in the same order, preventing visual flickering when the leaderboard refreshes.

== Messaging Sequence Diagram

#figure(
  chronos.diagram({
    import chronos: *
    _par("Sender", display-name: "Sender")
    _par("App", display-name: "iPad App")
    _par("Server", display-name: "Server")
    _par("DB", display-name: "Database")

    _seq("Sender", "App", comment: "Type and send message")
    _seq("App", "Server", comment: "POST /api/v1/channel/{id}")
    _seq("Server", "Server", comment: "Verify channel membership")

    _alt(
      "member",
      {
        _seq("Server", "DB", comment: "INSERT INTO messages")
        _seq("DB", "Server", comment: "stored", dashed: true)
        _seq("Server", "App", comment: "200 OK", dashed: true)
      },
      "not a member",
      {
        _seq("Server", "App", comment: "403 Forbidden", dashed: true)
      },
    )
    _seq("App", "Sender", comment: "Display result", dashed: true)
  }),
  caption: [Sequence diagram for the messaging flow],
)

= User Interface Design

== Design Principles

The interface is designed to feel calm and functional. Students will use the app in short bursts between classes, so the feed needs to be easy to scan and the main actions need to be obvious. I followed these guidelines:

- The activity feed shows title, date, location, capacity, and join state without requiring the user to tap into a detail page.
- Volunteer actions and organiser actions are visually separated to prevent accidental use of administrative functions.
- Status indicators combine text and colour so that they remain understandable for colourblind users.
- Error messages say what to do next, not just what went wrong.

== Information Architecture

#figure(
  diagram(
    spacing: (15pt, 18pt),
    node-stroke: 0.6pt + luma(120),
    node-fill: white,
    node-inset: 6pt,
    edge-stroke: 0.6pt + luma(120),

    // Row 0: Entry
    node((1, 0), text(size: 7.5pt, weight: "bold")[Launch / Session Check], corner-radius: 5pt, fill: rgb("#eaf2ff"), name: <launch>),
    node((3, 0), text(size: 7.5pt, weight: "bold")[Authentication], corner-radius: 5pt, name: <auth>),

    // Row 1: Main screens
    node((0, 1.2), text(size: 7.5pt, weight: "bold")[Activity Feed], corner-radius: 5pt, fill: rgb("#ebf8f1"), name: <feed>),
    node((1.5, 1.2), text(size: 7.5pt, weight: "bold")[Activity Detail], corner-radius: 5pt, name: <detail>),
    node((3, 1.2), text(size: 7.5pt, weight: "bold")[My Records], corner-radius: 5pt, name: <records>),

    // Row 2: Secondary screens
    node((0, 2.4), text(size: 7.5pt, weight: "bold")[Comments], corner-radius: 5pt, name: <comments>),
    node((1.5, 2.4), text(size: 7.5pt, weight: "bold")[Channel], corner-radius: 5pt, name: <channel>),
    node((3, 2.4), text(size: 7.5pt, weight: "bold")[Leaderboard], corner-radius: 5pt, name: <lb>),
    node((4.5, 2.4), text(size: 7.5pt, weight: "bold")[Organiser Tools], corner-radius: 5pt, fill: rgb("#fff5df"), name: <org>),
    node((4.5, 1.2), text(size: 7.5pt, weight: "bold")[Account], corner-radius: 5pt, fill: rgb("#fff0f2"), name: <acct>),

    // Edges
    edge(<launch>, <auth>, "->"),
    edge(<auth>, <feed>, "->"),
    edge(<feed>, <detail>, "->"),
    edge(<feed>, <records>, "->"),
    edge(<detail>, <comments>, "->"),
    edge(<detail>, <channel>, "->"),
    edge(<feed>, <lb>, "->"),
    edge(<feed>, <org>, "->"),
    edge(<feed>, <acct>, "->"),
  ),
  caption: [Information architecture and screen navigation],
)

#table(
  columns: (0.8fr, 0.7fr, 2fr),
  table.header(
    text(fill: white, weight: "bold")[Screen],
    text(fill: white, weight: "bold")[Primary user],
    text(fill: white, weight: "bold")[Purpose],
  ),
  [Activity Feed], [Volunteer], [Browse, search, and filter activities; tap to see details or join],
  [Activity Detail], [Both], [Full event info, join status, comments, and channel entry],
  [My Records], [Volunteer], [Personal participation history with status indicators],
  [Organiser Tools], [Organiser], [Create, start, end, or cancel activities; confirm participation],
  [Leaderboard], [Both], [Ranked volunteer hours from confirmed records],
  [Channel], [Both], [Activity-scoped messaging for coordination],
  [Account], [Both], [Profile editing, avatar management, session logout],
)

== Application Screenshots

The following screenshots are taken from the implemented application running on an iPad. Each screenshot shows the actual interface that users interact with.

=== Authentication

#screenshot-placeholder([Login screen], height: 200pt)
#screenshot-placeholder([Registration screen], height: 200pt)

=== Activity Feed

#screenshot-placeholder([Activity feed -- list view with status filters], height: 220pt)
#screenshot-placeholder([Activity feed -- search and filtering], height: 200pt)

=== Activity Detail

#screenshot-placeholder([Activity detail screen -- volunteer view with join button], height: 220pt)
#screenshot-placeholder([Activity detail screen -- organiser view with management controls], height: 220pt)

=== Comments

#screenshot-placeholder([Activity comments section], height: 180pt)

=== Channel Messaging

#screenshot-placeholder([Channel messaging interface], height: 220pt)

=== My Records

#screenshot-placeholder([Personal participation records], height: 200pt)

=== Leaderboard

#screenshot-placeholder([Leaderboard ranking screen], height: 200pt)

=== Organiser Tools

#screenshot-placeholder([Activity creation form], height: 220pt)
#screenshot-placeholder([Participation confirmation interface], height: 200pt)

=== Account

#screenshot-placeholder([Account and profile management screen], height: 180pt)

=== Admin Panel (Web)

#screenshot-placeholder([Admin panel -- user management], height: 200pt)
#screenshot-placeholder([Admin panel -- export generation], height: 180pt)

== Registration Flow

#figure(
  diagram(
    spacing: (12pt, 14pt),
    node-stroke: 0.6pt + luma(100),
    node-fill: white,
    node-inset: 5pt,
    edge-stroke: 0.6pt + luma(100),

    node((2, 0), text(size: 7pt)[User opens registration], shape: fletcher.shapes.pill, name: <start>),

    node((2, 1), text(size: 7pt)[Fill email, name, class, \ gender, password], corner-radius: 3pt, name: <fill>),

    node((2, 2), text(size: 7pt)[Client-side validation], shape: fletcher.shapes.diamond, name: <val>),
    node((4, 2), text(size: 7pt, fill: red)[Show field errors], corner-radius: 3pt, name: <err1>),

    node((2, 3), text(size: 7pt)[POST /api/v1/user], corner-radius: 3pt, name: <send>),

    node((2, 4), text(size: 7pt)[Email taken?], shape: fletcher.shapes.diamond, name: <dup>),
    node((4, 4), text(size: 7pt, fill: red)[Show "email exists" error], corner-radius: 3pt, name: <err2>),

    node((2, 5), text(size: 7pt)[Hash password, create user, \ assign to student group], corner-radius: 3pt, name: <create>),
    node((2, 6), text(size: 7pt)[Redirect to login], shape: fletcher.shapes.pill, name: <done>),

    edge(<start>, <fill>, "->"),
    edge(<fill>, <val>, "->"),
    edge(<val>, <err1>, "->", label: text(size: 6pt)[Invalid]),
    edge(<val>, <send>, "->", label: text(size: 6pt)[Valid], label-side: left),
    edge(<send>, <dup>, "->"),
    edge(<dup>, <err2>, "->", label: text(size: 6pt)[Yes]),
    edge(<dup>, <create>, "->", label: text(size: 6pt)[No], label-side: left),
    edge(<create>, <done>, "->"),
  ),
  caption: [Registration flowchart],
)

= Test Plan

The test plan maps directly to the success criteria from Criterion A.

== Test Coverage Map

#table(
  columns: (1fr, 1.4fr, 1.6fr),
  table.header(
    text(fill: white, weight: "bold")[Success Criterion],
    text(fill: white, weight: "bold")[Planned Tests],
    text(fill: white, weight: "bold")[Expected Evidence],
  ),
  [1. Account registration], [Valid registration, duplicate email, missing fields, avatar upload], [Hashed password in database, correct validation messages, account usable after creation],
  [2. Role-based access], [Login as student vs. admin, attempt restricted operations], [Student cannot create activities without permission; admin can manage all activities],
  [3. Activity publication], [Publish with valid data, check feed visibility, verify all fields display correctly], [Activity appears in feed with correct date, capacity, and description],
  [4. Activity management], [Edit an activity, cancel one, verify volunteer sees changes], [Updated details propagate; cancelled activity stops appearing as joinable],
  [5. Capacity-protected join], [Join normally, attempt join when full, concurrent join attempts], [Only one record per user; volunteer count never exceeds capacity],
  [6. Activity messaging], [Send a message, verify channel membership check, reopen channel later], [Messages persist; non-members cannot read or write],
  [7. Leaderboard], [Check rank ordering, test ties, confirm that confirming hours changes the ranking], [Accurate totals, stable ordering for ties],
  [8. Hour confirmation], [Confirm a record, verify confirmed_minutes and confirmed_at are set], [Record state changes to done with correct minute count],
  [9. Export], [Generate an export batch, verify output contains expected fields], [CSV with student name, class, activity title, date, confirmed minutes],
  [10. iPad compatibility], [Run on iPad in both orientations, test with keyboard visible, long content], [No crashes, no layout breakage, usable touch targets],
)

== Representative Test Cases

=== T1. Registration with Valid Data

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#1],
  [*Test data*], [A valid school email, password, name, class, and gender],
  [*Expected outcome*], [Account created. Password stored as bcrypt hash. Profile retrievable via API. User assigned to the student group.],
)

=== T2. Capacity-Protected Join

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#5],
  [*Test data*], [An activity with `max_volunteer_num = 1`. Two users attempt to join simultaneously.],
  [*Expected outcome*], [Exactly one join succeeds. The other receives a 403 "full" response. `volunteer_num` equals 1, not 2.],
)

=== T3. Activity State Transition and Cancellation Cascade

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#4],
  [*Test data*], [An activity in `NeedVolunteer` state with three joined volunteers. Organiser cancels the activity.],
  [*Expected outcome*], [Activity state becomes `Canceled`. All three participation records change to `canceled` with `confirmed_minutes = 0`. Already-confirmed records (state `done`) are not affected.],
)

=== T4. Leaderboard Recalculation

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#7],
  [*Test data*], [Two volunteers: Alice with 120 confirmed minutes, Bob with 60. Confirm an additional 90 minutes for Bob.],
  [*Expected outcome*], [Bob's total becomes 150 minutes. Leaderboard order changes to Bob (rank 1), Alice (rank 2).],
)

=== T5. Messaging Channel Membership

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#6],
  [*Test data*], [A channel linked to an activity. User A is a member; User B is not.],
  [*Expected outcome*], [User A can post and read messages. User B receives a 403 Forbidden response.],
)

=== T6. Export Batch Generation

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#9],
  [*Test data*], [Three volunteers with confirmed participation across two activities.],
  [*Expected outcome*], [Export batch contains six fields per item: student name, class, activity title, date, confirmed minutes, and confirmation timestamp.],
)

=== T7. iPad Layout in Both Orientations

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#10],
  [*Test data*], [Run the app on a 10.9" iPad in portrait and landscape with long activity titles and full message history.],
  [*Expected outcome*], [No text overflow, no blocked controls, no crashes. Touch targets remain comfortable.],
)

== Boundary and Edge-Case Tests

#table(
  columns: (1fr, 1.2fr, 1.8fr),
  table.header(
    text(fill: white, weight: "bold")[Risk],
    text(fill: white, weight: "bold")[Why it matters],
    text(fill: white, weight: "bold")[Test method],
  ),
  [Duplicate join], [Could corrupt participant count], [Send two join requests in rapid succession; verify only one record exists],
  [Activity at capacity], [Must not overbook], [Join when exactly one place remains, then again when none remain],
  [Cancel with confirmed records], [Must not erase confirmed hours], [Cancel an activity that has both `todo` and `done` records; verify `done` records are preserved],
  [Concurrent state transitions], [Could skip a state], [Attempt `start` and `cancel` simultaneously on the same activity; verify only one succeeds],
  [Long text in fields], [Could break iPad layout], [Enter very long titles and descriptions; verify scrolling and truncation behave correctly],
  [Empty capacity (unlimited)], [`max_volunteer_num` is nullable], [Create an activity with no capacity limit; verify unlimited joins are accepted],
)
