#import "@preview/pintorita:0.1.4"

#set document(title: "Criterion B: Solution Overview")
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.45cm))
#set text(font: "New Computer Modern", size: 10pt, fill: rgb("#1b2430"))
#set heading(numbering: "1.1")
#set par(leading: 0.58em)
#set table(
  stroke: 0.6pt + rgb("#d6dce5"),
  inset: 5pt,
  fill: (_, y) => if calc.rem(y, 2) == 1 { rgb("#fbfcfe") } else { white },
)

#let navy = rgb("#183153")
#let sky = rgb("#4d7ac7")
#let blue-soft = rgb("#eaf2ff")
#let mint-soft = rgb("#ebf8f1")
#let amber-soft = rgb("#fff5df")
#let rose-soft = rgb("#fff0f2")
#let mint-ink = rgb("#2d8f66")
#let amber-ink = rgb("#b37a00")
#let rose-ink = rgb("#d65d7a")
#let slate = rgb("#94a3b8")
#let ink-soft = rgb("#5f6b7a")
#let panel = rgb("#f8fafc")
#let border = rgb("#d7dfeb")

#show heading.where(level: 1): it => {
  v(0.9em)
  text(size: 16pt, weight: "bold", fill: navy, it)
  v(0.35em)
}

#show heading.where(level: 2): it => {
  v(0.7em)
  text(size: 12pt, weight: "bold", fill: navy, it)
  v(0.18em)
}

#show heading.where(level: 3): it => {
  v(0.45em)
  text(size: 10.6pt, weight: "bold", fill: sky, it)
  v(0.12em)
}

#let pill(label, fill-color: blue-soft, stroke-color: sky) = box(
  fill: fill-color,
  stroke: 0.8pt + stroke-color,
  radius: 999pt,
  inset: (x: 8pt, y: 3pt),
)[#text(size: 8pt, weight: "semibold", fill: stroke-color)[#label]]

#let card(title, body, fill-color: white, stroke-color: border, width: 100%) = box(
  width: width,
  fill: fill-color,
  stroke: 1pt + stroke-color,
  radius: 10pt,
  inset: 10pt,
)[
  #text(weight: "bold", fill: navy)[#title]
  #v(4pt)
  #body
]

#let stat-box(title, body, fill-color, stroke-color) = box(
  fill: fill-color,
  stroke: 1.2pt + stroke-color,
  radius: 10pt,
  inset: 10pt,
  width: 100%,
)[
  #text(weight: "bold", fill: stroke-color)[#title]
  #v(3pt)
  #text(size: 8.7pt, fill: ink-soft)[#body]
]

#align(center)[
  #box(
    width: 100%,
    fill: rgb("#f6f8fc"),
    stroke: 1pt + border,
    radius: 14pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 20pt, weight: "bold", fill: navy)[Criterion B: Solution Overview]
      #v(5pt)
      #text(size: 9.2pt, fill: ink-soft)[
        Planned design guide for a new iPad-first volunteer management application
      ]
      #v(8pt)
      #pill([SwiftUI iPad App])
      #h(6pt)
      #pill([Client-Server Architecture], fill-color: mint-soft, stroke-color: mint-ink)
      #h(6pt)
      #pill([Criterion-A-Aligned Test Plan], fill-color: amber-soft, stroke-color: amber-ink)
    ]
  ]
]

= Record of Tasks

#set text(size: 9pt)
#table(
  columns: (auto, auto, auto, 1.25fr, 2fr, 1.1fr, 1.4fr),
  align: (center, center, center, left, left, left, left),
  table.header(
    [*No.*], [*Time*], [*Phase*], [*Task*], [*Process*], [*Deliverable*], [*Reflection / Next Step*]
  ),

  [1], [Week 1], [Plan],
  [Confirm client context and user roles],
  [Interview staff and student users to identify how volunteer opportunities are published, joined, supervised, and recorded.],
  [Requirements notes and role definitions],
  [The product should stay focused on school volunteering rather than expanding into a general-purpose social app.],

  [2], [Week 1], [Plan],
  [Turn requirements into measurable success criteria],
  [Rewrite user needs as criteria that can later be tested with concrete evidence rather than broad impressions.],
  [Success criteria set],
  [Each criterion needs an observable outcome, not just a desirable feature.],

  [3], [Week 2], [Plan],
  [Choose platform and architecture],
  [Compare implementation approaches and select a native iPad client with a client-server structure.],
  [Architecture decision note],
  [Native iPad interaction is more important than maximizing code sharing across unrelated platforms.],

  [4], [Week 2], [Design],
  [Design information architecture],
  [Separate volunteer and organiser journeys, then merge them into a single role-aware application structure.],
  [Navigation map and role matrix],
  [One app with role-based actions is cleaner than maintaining parallel products.],

  [5], [Week 3], [Design],
  [Model the data structure],
  [Define entities, ownership, and relational constraints for users, activities, records, channels, messages, and exports.],
  [ER diagram and data notes],
  [The model must prevent duplicate joins and keep leaderboard data derived rather than manually edited.],

  [6], [Week 3], [Design],
  [Define activity and participation lifecycles],
  [Specify valid transitions for activity publication, participation confirmation, cancellation, and completion.],
  [State diagrams and rules],
  [Lifecycle clarity will reduce ambiguity in both implementation and testing.],

  [7], [Week 4], [Design],
  [Design service interaction patterns],
  [List the app actions that require requests, push updates, or structured export generation.],
  [Request and flow diagrams],
  [The design section should explain behavior, not drown in endpoint detail.],

  [8], [Week 4], [Design],
  [Create UI wireframes],
  [Draft the feed, detail, organiser, leaderboard, and account screens with emphasis on iPad readability and scan speed.],
  [Low-fidelity screen set],
  [Students will often browse opportunities between classes, so the feed must support quick comparison.],

  [9], [Week 5-6], [Develop],
  [Build registration and account features],
  [Implement registration, login, avatar handling, session continuity, and editable profile data.],
  [Account module],
  [Validation should be visible where the error occurs rather than pushed into generic alerts.],

  [10], [Week 7-8], [Develop],
  [Build activity publication and joining],
  [Implement creation, editing, cancellation, joining, and safe participant counting.],
  [Activity and participation module],
  [Concurrency around joining is a critical risk area and must be solved early.],

  [11], [Week 9], [Develop],
  [Build activity communication],
  [Implement activity-linked channels, membership checks, history storage, and real-time message delivery.],
  [Channel and messaging module],
  [Messaging should stay focused on activities instead of becoming a detached chat feature.],

  [12], [Week 10], [Develop],
  [Build leaderboard and hour tracking],
  [Aggregate confirmed participation time, rank volunteers, and support organiser confirmation actions.],
  [Leaderboard and hour-tracking module],
  [Ranking must be derived from confirmed records rather than stored totals on user profiles.],

  [13], [Week 11], [Research],
  [Investigate ISMAS export requirements],
  [Review public information about school data imports and plan an export adapter that can match a school-provided ISMAS template.],
  [Export strategy note],
  [No public ISMAS import specification was identified, so the export layer needs to remain configurable.],

  [14], [Week 12], [Test],
  [Prepare criterion-linked tests],
  [Translate each success criterion into functional, boundary, timing, and usability tests.],
  [Outline test plan],
  [Test coverage should mirror Criterion A instead of turning into generic QA.],

  [15], [Week 13], [Test],
  [Run iPad compatibility and usability checks],
  [Test portrait and landscape layouts, long-content behavior, and touch interactions on target devices.],
  [Device and usability notes],
  [Interface quality matters because this product is intended for real school use, not just demonstration.],

  [16], [Week 14], [Implement],
  [Pilot and refine],
  [Conduct a limited trial, collect feedback, and revise the product before final evaluation.],
  [Pilot checklist and revision log],
  [The final version should demonstrate that the design works in the client’s real environment.],
)
#set text(size: 10pt)

= Design Overview

== Architectural Rationale

The proposed solution uses a *client-server structure*. The iPad client handles presentation, form entry, local view state, and user feedback. The service layer is responsible for validation, permissions, persistence, ranking logic, and real-time updates. This separation keeps the SwiftUI interface responsive while ensuring that shared data remains consistent for every user.

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 8pt,
  stat-box(
    [Volunteer View],
    [Browse activities, join events, send messages, review records, and check rankings.],
    blue-soft,
    sky,
  ),
  stat-box(
    [Organiser View],
    [Publish activities, edit or cancel them, confirm participation, and supervise communication.],
    mint-soft,
    rgb("#2d8f66"),
  ),
  stat-box(
    [Shared Data Core],
    [A single source of truth for users, activities, participation, messages, and export data.],
    amber-soft,
    rgb("#b37a00"),
  ),
)

#figure(
  box(fill: panel, stroke: 1pt + border, radius: 12pt, inset: 12pt)[
    #set text(size: 8.8pt)
    #grid(
      columns: (1.1fr, auto, 1.15fr, auto, 0.95fr),
      rows: (auto, 8pt, auto),
      gutter: 8pt,

      card(
        [SwiftUI iPad Application],
        [
          #text(size: 8pt, fill: ink-soft)[
            Presentation layer \
            Session and local state \
            Form validation and feedback \
            Push subscription and refresh
          ]
        ],
        fill-color: blue-soft,
        stroke-color: sky,
      ),
      align(center + horizon)[#text(fill: ink-soft, weight: "bold")[HTTPS / JSON #sym.arrow.r]],
      card(
        [Application Service],
        [
          #text(size: 8pt, fill: ink-soft)[
            Authentication and permissions \
            Activity and record rules \
            Channel messaging and ranking \
            Export adapter generation
          ]
        ],
        fill-color: mint-soft,
        stroke-color: mint-ink,
      ),
      align(center + horizon)[#text(fill: ink-soft, weight: "bold")[structured export #sym.arrow.r]],
      card(
        [School Import Workflow],
        [
          #text(size: 8pt, fill: ink-soft)[
            ISMAS-oriented template \
            Administrative import step
          ]
        ],
        fill-color: amber-soft,
        stroke-color: amber-ink,
      ),

      [], [], [], [], [],

      card(
        [Client Cache],
        [#text(size: 8pt, fill: ink-soft)[Filters, pending requests, recent lists, current session state]],
        fill-color: rose-soft,
        stroke-color: rgb("#d65d7a"),
      ),
      align(center)[#sym.arrow.r],
      card(
        [Relational Database],
        [#text(size: 8pt, fill: ink-soft)[Users, activities, records, comments, channels, messages, export batches]],
        fill-color: white,
        stroke-color: rgb("#7b8798"),
      ),
      [], [],
    )
  ],
  caption: [Overall system architecture]
)

=== Component Responsibilities

#table(
  columns: (1fr, 1.35fr, 1.85fr),
  table.header([*Component*], [*Main responsibility*], [*Why it belongs there*]),
  [*SwiftUI presentation layer*], [Screens, navigation, forms, feedback, accessibility], [View logic should remain separate from data rules and permission checks.],
  [*Client state layer*], [Session, selected filters, pending request state, recent cached content], [The app needs fast feedback without duplicating core business rules.],
  [*Service layer*], [Validation, permissions, activity lifecycles, ranking logic, export preparation], [Shared rules should execute once in a consistent place.],
  [*Database*], [Persistent storage for users, activities, messages, participation, and exports], [Volunteer hours and communication history require durable records.],
  [*Export adapter*], [Converts confirmed participation data into school-required import format], [External format changes should not force redesign of core activity logic.],
)

== Information Architecture

The product structure is organized around repeated tasks. Volunteers mostly browse, join, message, and review records. Organisers mostly publish, manage, confirm, and communicate. The navigation therefore places the activity feed first, then context screens, then role-specific management.

#figure(
  box(fill: white, stroke: 1pt + border, radius: 12pt, inset: 12pt)[
    #set text(size: 8.7pt)
    #grid(
      columns: (1fr, 1fr, 1fr),
      rows: (auto, auto, auto),
      gutter: 8pt,

      box(fill: blue-soft, stroke: 1pt + sky, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: sky)[Launch / Session Check] \
        #text(size: 8pt, fill: ink-soft)[Open app and restore last valid session]
      ],
      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Authentication] \
        #text(size: 8pt, fill: ink-soft)[Login and registration for school users]
      ],
      box(fill: mint-soft, stroke: 1pt + mint-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: mint-ink)[Activity Feed] \
        #text(size: 8pt, fill: ink-soft)[Default landing page for browsing and filtering]
      ],

      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Activity Detail] \
        #text(size: 8pt, fill: ink-soft)[Join, comment, enter channel, inspect event information]
      ],
      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[My Records] \
        #text(size: 8pt, fill: ink-soft)[Personal participation history and status]
      ],
      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Leaderboard] \
        #text(size: 8pt, fill: ink-soft)[Ranked total hours after confirmation]
      ],

      box(fill: amber-soft, stroke: 1pt + amber-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: amber-ink)[Organiser Tools] \
        #text(size: 8pt, fill: ink-soft)[Create activity, edit activity, cancel activity, confirm completion]
      ],
      box(fill: rose-soft, stroke: 1pt + rose-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: rose-ink)[Account] \
        #text(size: 8pt, fill: ink-soft)[Avatar, class data, logout, personal settings]
      ],
      box(fill: panel, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Linked context] \
        #text(size: 8pt, fill: ink-soft)[Activity Detail leads to comments and the activity channel.]
      ],
    )
  ],
  caption: [Information architecture and main screen groups]
)

=== Navigation Summary

#table(
  columns: (1fr, 1fr, 2fr),
  table.header([*Area*], [*Primary user*], [*Purpose*]),
  [Activity Feed], [Volunteer], [Compare opportunities quickly and enter the relevant detail screen.],
  [Activity Detail], [Both], [Show event information, join status, comments, and channel entry.],
  [My Records], [Volunteer], [Review joined activities, completion state, and accumulated history.],
  [Organiser Tools], [Organiser], [Create, revise, cancel, and confirm activity participation.],
  [Leaderboard], [Both], [Display confirmed volunteering totals in ranked order.],
  [Account], [Both], [Store identity details, avatar, and session settings.],
)

== Core User Flows

=== Flow 1: Registration

The registration flow should be short and predictable. It collects school identity details and an avatar, validates obvious problems locally, and only sends a request once the form is complete.

#figure(
  pintorita.render(
```
sequenceDiagram
  participant User
  participant App
  participant Service
  participant DB

  User ->> App: Enter school email, name, class, password, avatar
  App ->> App: Validate required fields
  App ->> Service: Submit registration request
  Service ->> Service: Check uniqueness and hash password
  Service ->> DB: Create user record
  DB -->> Service: Success
  Service -->> App: Registration confirmed
  App -->> User: Show success and route to login
```.text
  ),
  caption: [Registration flow]
)

=== Flow 2: Activity Publication

The publication flow must balance speed and completeness. An organiser should be able to create an activity without excessive friction, while volunteers must still receive enough information to decide whether to join.

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Organiser
  participant App
  participant Service
  participant DB

  Organiser ->> App: Enter title, date, location, capacity, duration, description
  App ->> Service: Create activity
  Service ->> Service: Verify organiser permission
  Service ->> DB: Insert activity in recruiting state
  DB -->> Service: Activity stored
  Service -->> App: Activity created
  App -->> Organiser: Show result
```.text
  ),
  caption: [Activity publication flow]
)

=== Flow 3: Joining with Capacity Protection

This flow combines user feedback, data integrity, and concurrency control. It therefore deserves explicit treatment in Criterion B.

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Volunteer
  participant App
  participant Service
  participant DB

  Volunteer ->> App: Tap Join
  App ->> Service: Request join
  Service ->> DB: Start transaction
  Service ->> DB: Read current capacity
  Service ->> DB: Check existing participation
  alt full or duplicate
    Service ->> DB: Roll back
    Service -->> App: Reject with clear reason
  else valid join
    Service ->> DB: Create participation record
    Service ->> DB: Increment participant count
    Service ->> DB: Commit
    Service -->> App: Join confirmed
  end
  App -->> Volunteer: Refresh local state
```.text
  ),
  caption: [Protected join flow]
)

*Critical logic*:
```text
BEGIN TRANSACTION
  lock current activity row
  if activity does not exist: reject
  if activity is not recruiting: reject
  if activity is full: reject
  if user already joined: reject
  create participation record
  increase current participant count
COMMIT
```

=== Flow 4: Messaging Inside an Activity

Messaging belongs to an activity context rather than existing as a separate social space. This keeps discussion relevant to preparation and coordination.

#figure(
  pintorita.render(
```
sequenceDiagram
  participant Sender
  participant App
  participant Service
  participant Push
  participant Receiver

  Sender ->> App: Send message
  App ->> Service: Post message
  Service ->> Service: Verify channel membership
  Service ->> Push: Publish update to members
  Push -->> Receiver: Deliver new-message event
  Service -->> App: Confirm storage
```.text
  ),
  caption: [Activity messaging flow]
)

== Data Design

The data model uses a relational structure because ownership, history, and ranking all depend on consistent links between records. A user joins many activities over time, each activity may have a related channel, and confirmed participation data may later be exported to a school-defined template.

#figure(
  scale(x: 80%, y: 80%, reflow: true,
    pintorita.render(
```
erDiagram

users {
  uuid id PK
  string school_email
  string real_name
  string class_name
  string avatar_path
  string password_hash
  string role
}

sessions {
  uuid id PK
  uuid user_id FK
  datetime issued_at
}

activities {
  uuid id PK
  uuid organiser_id FK
  string title
  datetime start_at
  string location
  int max_participants
  int current_participants
  int duration_minutes
  string state
}

records {
  uuid id PK
  uuid activity_id FK
  uuid user_id FK
  string state
  datetime updated_at
}

comments {
  uuid id PK
  uuid activity_id FK
  uuid author_id FK
  string content
  datetime created_at
}

channels {
  uuid id PK
  uuid activity_id FK
  string name
}

channel_members {
  uuid channel_id FK
  uuid user_id FK
}

messages {
  uuid id PK
  uuid channel_id FK
  uuid sender_id FK
  string content
  datetime sent_at
}

export_batches {
  uuid id PK
  datetime generated_at
  string target_format
  string status
}

export_items {
  uuid id PK
  uuid batch_id FK
  uuid user_id FK
  uuid activity_id FK
  int confirmed_minutes
}

users ||--o{ sessions : owns
users ||--o{ activities : publishes
users ||--o{ records : holds
users ||--o{ comments : writes
users ||--o{ messages : sends
activities ||--o{ records : includes
activities ||--o{ comments : includes
activities ||--o| channels : has
channels ||--o{ channel_members : contains
channels ||--o{ messages : stores
export_batches ||--o{ export_items : contains
users ||--o{ export_items : references
activities ||--o{ export_items : references
```.text
    )
  ),
  caption: [Entity-relationship diagram]
)

=== Key Data Rules

#table(
  columns: (1.1fr, 1.9fr),
  table.header([*Rule*], [*Design decision*]),
  [A user must not join the same activity twice.], [Enforce uniqueness on the participation pair of `activity_id` and `user_id`.],
  [Capacity must never drift away from participation records.], [Update participant count and create the record inside a single transaction.],
  [Only confirmed participation should affect rankings.], [Aggregate leaderboard totals from records marked as completed.],
  [Messages should remain private to activity members.], [Require channel membership for both reading and posting.],
  [Export should adapt to school requirements without rewriting core logic.], [Generate export batches from confirmed records through a dedicated adapter layer.],
)

== Internal Structures and Algorithms

=== Activity State Machine

The system uses explicit activity states so that visibility, joining, and hour confirmation all behave consistently.

#figure(
  pintorita.render(
```
activityDiagram
start
:Draft;
:Recruiting;
if (Start activity?) then (yes)
  :In Progress;
  if (Confirm finish?) then (yes)
    :Completed;
  else (cancel)
    :Cancelled;
  endif
else (cancel)
  :Cancelled;
endif
stop
```.text
  ),
  caption: [Activity state machine]
)

#table(
  columns: (1fr, 1.25fr, 1fr),
  table.header([*State*], [*Meaning*], [*Visible to volunteers*]),
  [Draft], [Prepared by the organiser but not yet published], [No],
  [Recruiting], [Published and open for sign-up], [Yes],
  [InProgress], [Activity has started], [Yes],
  [Completed], [Finished and eligible for confirmed hours], [Yes, as history],
  [Cancelled], [No longer taking place], [Yes, as cancelled history],
)

=== Join Algorithm

The join process is a good example of algorithmic thinking because it combines validation, locking, and business rules.

```text
FUNCTION joinActivity(userId, activityId):
    BEGIN TRANSACTION

    activity = getActivityForUpdate(activityId)
    IF activity does not exist:
        ROLLBACK
        RETURN "Activity not found"

    IF activity.state != Recruiting:
        ROLLBACK
        RETURN "Activity is not open for joining"

    IF activity.current_participants >= activity.max_participants:
        ROLLBACK
        RETURN "Activity is full"

    IF participationRecordExists(userId, activityId):
        ROLLBACK
        RETURN "You have already joined"

    createParticipationRecord(userId, activityId, state = "joined")
    incrementCurrentParticipants(activityId)

    COMMIT
    RETURN "Joined successfully"
```

=== Leaderboard Query Design

The leaderboard should not store static totals on the user profile. It should be derived from confirmed participation records to avoid contradictions.

```sql
SELECT
    u.id,
    u.real_name,
    u.avatar_path,
    SUM(a.duration_minutes) AS total_minutes
FROM users u
JOIN records r ON r.user_id = u.id
JOIN activities a ON a.id = r.activity_id
WHERE r.state = 'completed'
GROUP BY u.id, u.real_name, u.avatar_path
ORDER BY total_minutes DESC, u.real_name ASC
LIMIT :limit;
```

This ordering also keeps tied totals stable by falling back to the volunteer name rather than showing a different order each time.

=== Export Strategy for School Reporting

Public web research did not reveal a confirmed ISMAS import specification. However, publicly documented school-information workflows commonly rely on template-based CSV or spreadsheet imports. The safest design choice is therefore to treat export as a dedicated adapter layer. The core system records and confirms volunteer hours; the adapter transforms that confirmed data into the format required by the school’s ISMAS import process once the official template is available.

*Planned export fields*:
- student identifier
- student name
- class name
- activity title
- activity date
- confirmed duration
- organiser confirmation timestamp

This approach keeps Criterion A intact while avoiding a brittle assumption about an external format that is not publicly documented.

== UI / UX Design

The interface should feel calm, clear, and academic rather than playful. Students are likely to use the app in short sessions, so the feed must support rapid scanning and obvious actions.

=== Interface Principles

- The activity feed must expose title, time, location, capacity, and join state without forcing users into the detail page.
- Volunteer and organiser actions should be visually separated so that role-specific controls do not cause accidental taps.
- Status should use text, color, and shape together rather than relying on color alone.
- Error messages should tell the user what to do next, not just that something failed.
- Message history and participation records should always show which activity they belong to.

=== Activity Feed Wireframe

#figure(
  box(fill: rgb("#f4f8ff"), stroke: 1.4pt + sky, radius: 14pt, inset: 12pt, width: 88%)[
    #set text(size: 8.8pt, fill: navy)
    #align(center)[
      #text(weight: "bold")[Activity Feed]
      #v(3pt)
      #text(size: 7.8pt, fill: ink-soft)[iPad wireframe]
    ]
    #v(7pt)

    #box(fill: white, stroke: 1pt + sky, radius: 9pt, inset: 8pt)[
      #grid(columns: (1fr, 1fr, 1fr), align: center,
        [Home], [*Volunteer Activities*], align(right)[Search + Profile]
      )
    ]
    #v(6pt)

    #box(fill: white, stroke: 1pt + sky, radius: 9pt, inset: 7pt)[
      #grid(columns: (1fr,) * 4, gutter: 5pt,
        pill([All]),
        pill([Recruiting], fill-color: mint-soft, stroke-color: rgb("#2d8f66")),
        pill([Joined], fill-color: amber-soft, stroke-color: amber-ink),
        pill([Completed], fill-color: rose-soft, stroke-color: rose-ink),
      )
    ]
    #v(7pt)

    #for item in (
      (
        "Campus Cleanup",
        "Sat 16 Mar · Main Building",
        "2 hours · 5 / 20 volunteers",
        "A weekend activity focused on cleaning shared study spaces and outdoor paths.",
      ),
      (
        "Library Support",
        "Tue 19 Mar · Library",
        "1 hour · 3 / 5 volunteers",
        "Students help sort returned books and prepare the reading area for events.",
      ),
    ) [
      #box(fill: white, stroke: 1pt + sky, radius: 10pt, inset: 9pt)[
        #grid(columns: (auto, 1fr, auto), gutter: 8pt,
          box(width: 28pt, height: 28pt, radius: 6pt, fill: blue-soft, stroke: 0.8pt + sky)[],
          [
            #text(weight: "bold")[#item.at(0)] \
            #text(size: 8pt, fill: ink-soft)[#item.at(1)] \
            #text(size: 8pt, fill: ink-soft)[#item.at(2)] \
            #v(2pt)
            #box(width: 100%, height: 7pt, radius: 999pt, fill: rgb("#eef2f7"))[
              #box(width: if item.at(0) == "Campus Cleanup" { 26% } else { 58% }, height: 7pt, radius: 999pt, fill: sky)[]
            ]
            #v(3pt)
            #text(size: 8pt, fill: ink-soft)[#item.at(3)]
          ],
          box(fill: blue-soft, stroke: 0.9pt + sky, radius: 7pt, inset: (x: 8pt, y: 4pt))[#text(size: 8pt, weight: "semibold", fill: sky)[Join]],
        )
      ]
      #v(7pt)
    ]

    #box(fill: white, stroke: 1pt + sky, radius: 9pt, inset: 8pt)[
      #grid(columns: (1fr,) * 5, align: center,
        [Feed], [Records], [Create], [Leaderboard], [Account]
      )
    ]
  ],
  caption: [Low-fidelity wireframe for the activity feed]
)

=== Layout Decisions

#table(
  columns: (1.15fr, 1.35fr, 1.7fr),
  table.header([*Element*], [*Planned behavior*], [*Reason*]),
  [Capacity indicator], [Progress bar plus exact numeric count], [A bar alone looks elegant but hides actual availability.],
  [Join button], [Changes from `Join` to `Joined` and becomes disabled], [Prevents duplicate taps and makes status immediately obvious.],
  [Organiser action area], [Grouped in a separate card on the detail screen], [Reduces confusion between volunteer and organiser controls.],
  [Leaderboard row], [Avatar, name, rank, and total hours in one line], [The ranking should be understandable at a glance.],
  [Record status chip], [Plain labels such as `Joined`, `Completed`, and `Cancelled`], [Simple language is easier to test and easier for users to interpret.],
)

=== Validation and Feedback

#table(
  columns: (1fr, 1.4fr, 1.6fr),
  table.header([*Input*], [*Validation rule*], [*User-facing response*]),
  [School email], [Must match school format and be unique], [Inline error before submission where possible],
  [Password], [Minimum length and confirmation match], [Field-level guidance rather than a generic alert],
  [Activity title], [Required and limited to a sensible length], [Keep focus on the field until corrected],
  [Capacity], [Positive whole number], [Explain the allowed range clearly],
  [Duration], [Positive number of minutes], [Prevent invalid scheduling and ranking errors],
  [Avatar], [Optional upload or placeholder selection], [Should not interrupt registration unless the final criterion requires it],
)

= Outline Test Plan

The following test plan is mapped directly to the success criteria from Criterion A. The purpose is to show how each major design promise will later be verified.

== Test Coverage Map

#table(
  columns: (1.1fr, 1.4fr, 1.8fr),
  table.header([*Success criterion*], [*Main tests*], [*Evidence sought*]),
  [1. Account registration], [Valid registration, duplicate registration, invalid input, avatar upload], [Secure storage, correct validation, successful account creation],
  [2. Task publication], [Publish with valid data, publish without permission, visibility timing], [Correct fields and feed visibility within five seconds],
  [3. Task management], [Edit activity, cancel activity, compare volunteer view before and after], [Immediate and correct updates for volunteers],
  [4. Communication], [Send message, receive message, reopen history], [Stored messages and visible live updates],
  [5. Leaderboard], [Rank ordering, tie behavior, recalculation after confirmation], [Accurate totals and stable ranking order],
  [6. Hour tracking and export], [Confirm participation, accumulate hours, generate export batch], [Correct confirmed minutes and school-ready export structure],
  [7. Platform compatibility], [Run on iPad, rotate device, test keyboard and long content], [Stable layout and usable touch targets on iPadOS 17.5+],
)

== Representative Test Cases

=== T1. Registration with Valid Data

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#1],
  [*Test data*], [A new school email, valid password, class name, and avatar],
  [*Expected result*], [The account is created, the password is stored securely, profile data is retrievable, and the avatar appears in the account view.],
)

=== T2. Activity Publication Visibility

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#2],
  [*Test method*], [Create an activity from an organiser account while another account is already viewing the feed.],
  [*Expected result*], [The new activity appears within five seconds and displays the correct date, capacity, description, and duration.],
)

=== T3. Edit and Cancel Propagation

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#3],
  [*Test method*], [Change one published activity and cancel another, then refresh the volunteer view.],
  [*Expected result*], [Updated details appear without stale data, and cancelled activities no longer appear as recruitable.],
)

=== T4. Messaging Persistence and Push

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#4],
  [*Test method*], [Two users enter the same activity channel; one sends a message while the other remains on the screen.],
  [*Expected result*], [The receiver sees the message without manual refresh, and the message remains after reopening the screen.],
)

=== T5. Leaderboard Recalculation

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#5],
  [*Test method*], [Confirm participation for a volunteer whose rank should change after the update.],
  [*Expected result*], [The total hours and relative position change correctly after completion is recorded.],
)

=== T6. Hour Tracking and Export

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#6],
  [*Test method*], [Mark participation as completed, then generate an export batch from confirmed records.],
  [*Expected result*], [The user gains the correct number of minutes, the export batch contains the required fields, and the output matches the school-provided import template once available.],
)

=== T7. iPad Compatibility and Layout

#table(
  columns: (1fr, 3fr),
  [*Related success criterion*], [\#7],
  [*Test method*], [Run the app on target iPads in portrait and landscape with both short and long content.],
  [*Expected result*], [No crashes, no blocked controls, no severe overflow, and comfortable touch targets on the primary screens.],
)

== Boundary and Risk-Focused Tests

#table(
  columns: (1fr, 1.3fr, 1.7fr),
  table.header([*Risk area*], [*Why it matters*], [*Planned test*]),
  [Duplicate join attempts], [Can corrupt participation counts], [Submit repeated join requests and verify that only one record is created.],
  [Full activity], [Must not allow overbooking], [Attempt to join when one place remains and when no places remain.],
  [Network interruption], [Likely in a school environment], [Interrupt network during key actions and confirm useful recovery messaging.],
  [Long titles and descriptions], [Can break iPad layouts], [Use extreme but valid text lengths in feed and detail screens.],
  [Concurrent confirmation updates], [Affects leaderboard accuracy], [Confirm multiple records in quick succession and compare totals.],
  [Export format uncertainty], [Depends on an external requirement], [Validate export through a configurable schema and a school-approved sample file.],
)

== What This Test Plan Demonstrates

If the tests above pass, the application will have shown that it can:

- register users securely
- publish and manage volunteer opportunities quickly
- support activity-specific communication
- calculate confirmed volunteer hours correctly
- prepare structured data for school reporting
- run reliably on the school’s target iPads

That is the level of evidence this Criterion B document is designed to support.
