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
        Design overview and record of development for an iPad-first volunteer management application
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

= Record of Tasks Form

#set text(size: 9pt)
#table(
  columns: (auto, 1.9fr, 1.8fr, auto, auto, auto),
  align: (center, left, left, center, center, center),
  table.header(
    [*Task No.*], [*Planned Action*], [*Planned Outcome*], [*Time Estimated*], [*Target Completion Date*], [*Criterion*]
  ),

  [1], [Meet the client and figure out what's actually going wrong with how they handle volunteering, communication, and hour logging.], [A clear problem definition backed by what the client told me, with priorities I can design around.], [4 hours], [Week 1], [A],
  [2], [Turn the consultation notes into success criteria that I can actually test later.], [A set of criteria I can observe and verify, not vague goals.], [3 hours], [Week 1], [A],
  [3], [Look at different development approaches and decide on a native iPad app with a server backend.], [A justified platform choice that fits the client's environment.], [4 hours], [Week 2], [B],
  [4], [Map out how volunteers and organisers would actually use the app, and build the navigation around that.], [A navigation structure that makes sense for both roles.], [5 hours], [Week 2], [B],
  [5], [Design the database for users, activities, participation, comments, channels, messages, and exports.], [A data model that handles history, permissions, ranking, and reporting without duplicating data.], [6 hours], [Week 3], [B],
  [6], [Define what states an activity can be in and how participation records change over time.], [Clear state transitions for publishing, joining, cancelling, confirming, and ranking.], [3 hours], [Week 3], [B],
  [7], [Work out the main request-response and push-update flows the app uses.], [Documentation of how the core user actions move through the system.], [4 hours], [Week 4], [B],
  [8], [Sketch low-fidelity wireframes for the feed, detail, organiser, leaderboard, and account screens.], [A layout foundation for the SwiftUI interface that works well on iPad.], [5 hours], [Week 4], [B],
  [9], [Build registration, login, avatar handling, and session continuity.], [A working account system that covers success criterion 1.], [8 hours], [Week 5], [C],
  [10], [Build activity publication, editing, cancellation, and the join flow with capacity protection.], [Core activity management with safe participant counting.], [10 hours], [Week 6], [C],
  [11], [Build activity-linked messaging with history and live updates.], [A channel system for sending, receiving, and keeping activity messages.], [8 hours], [Week 7], [C],
  [12], [Build confirmed-hour aggregation and leaderboard ranking.], [A ranking view driven by verified participation data, not manual totals.], [6 hours], [Week 8], [C],
  [13], [Research the school's import workflow and design a configurable export adapter for ISMAS reporting.], [An export design that can match the school template once it's available.], [4 hours], [Week 9], [B],
  [14], [Write criterion-linked tests covering normal use, edge cases, timing, and layout.], [A test plan mapped to the success criteria from Criterion A.], [5 hours], [Week 10], [B],
  [15], [Test on the target iPads in both orientations and collect user feedback.], [Evidence that the app works in the client's actual environment.], [6 hours], [Week 11], [D/E],
  [16], [Review pilot feedback and fix issues before final submission.], [A more reliable product that reflects what the client actually needs.], [4 hours], [Week 12], [E],
)
#set text(size: 10pt)

= Design Overview

== Architectural Rationale

After talking with the client, I decided on a *client-server structure*. The iPad app handles the UI, form entry, and local state. The server handles validation, permissions, persistence, ranking, and real-time updates. I went with this split mainly because volunteer data needs to be shared across users -- if two people join the same activity at the same time, a local-only approach would have no way to enforce the capacity limit. The server acts as the single authority on what the current state is.

I also considered a peer-to-peer approach where iPads sync directly, but that gets complicated fast with conflict resolution, and the school's WiFi setup doesn't guarantee devices can discover each other. A central server is simpler and more reliable here.

#grid(
  columns: (1fr, 1fr),
  gutter: 8pt,
  stat-box(
    [Volunteer Side],
    [Browse activities, join events, send messages, check personal records, view the leaderboard.],
    blue-soft,
    sky,
  ),
  stat-box(
    [Organiser Side],
    [Publish activities, edit or cancel them, confirm participation, supervise communication, trigger exports.],
    mint-soft,
    rgb("#2d8f66"),
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

I split the system into five components. Here's what each one does and why I put it there:

#table(
  columns: (1fr, 1.3fr, 1.8fr),
  table.header([*Component*], [*What it does*], [*Why it sits here*]),
  [*SwiftUI layer*], [Screens, navigation, forms, feedback, accessibility], [View logic shouldn't be mixed with data rules or permission checks. Keeping it separate also makes it easier to test the UI independently.],
  [*Client state*], [Session token, selected filters, pending request state, recently fetched content], [The app needs to feel fast, so I cache some things locally. But I don't duplicate business rules here.],
  [*Service layer*], [Validation, permissions, activity lifecycles, ranking logic, export prep], [These rules need to run in one place so all clients see the same result.],
  [*Database*], [Persistent storage for users, activities, messages, participation, and exports], [Volunteer hours and message history can't live in memory -- they need durable storage.],
  [*Export adapter*], [Converts confirmed participation data into the format the school needs], [If the school changes their import format, I only need to update this one layer.],
)

== Information Architecture

I organized the app around the tasks that came up most in my consultation. Volunteers spend most of their time browsing, joining, messaging, and reviewing what they've done. Organisers mostly publish, manage, confirm, and communicate. So the navigation puts the activity feed front and center, then branches into context screens and role-specific tools.

#figure(
  box(fill: white, stroke: 1pt + border, radius: 12pt, inset: 12pt)[
    #set text(size: 8.7pt)
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 8pt,

      box(fill: blue-soft, stroke: 1pt + sky, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: sky)[Launch / Session Check] \
        #text(size: 8pt, fill: ink-soft)[Open the app; restore the last valid session if one exists]
      ],
      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Authentication] \
        #text(size: 8pt, fill: ink-soft)[Login or register with school credentials]
      ],
      box(fill: mint-soft, stroke: 1pt + mint-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: mint-ink)[Activity Feed] \
        #text(size: 8pt, fill: ink-soft)[Default landing screen for browsing and filtering activities]
      ],
    )
    #v(8pt)
    #grid(
      columns: (1fr, 1fr),
      gutter: 8pt,

      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Activity Detail] \
        #text(size: 8pt, fill: ink-soft)[Join, comment, open the channel, see full event info]
      ],
      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[My Records] \
        #text(size: 8pt, fill: ink-soft)[Personal participation history and current status]
      ],
    )
    #v(8pt)
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 8pt,

      box(fill: white, stroke: 1pt + border, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: navy)[Leaderboard] \
        #text(size: 8pt, fill: ink-soft)[Ranked total hours from confirmed participation]
      ],
      box(fill: amber-soft, stroke: 1pt + amber-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: amber-ink)[Organiser Tools] \
        #text(size: 8pt, fill: ink-soft)[Create, edit, cancel activities; confirm completion]
      ],
      box(fill: rose-soft, stroke: 1pt + rose-ink, radius: 9pt, inset: 8pt)[
        #text(weight: "bold", fill: rose-ink)[Account] \
        #text(size: 8pt, fill: ink-soft)[Avatar, class info, logout, settings]
      ],
    )
    #v(6pt)
    #text(size: 8pt, fill: ink-soft)[_Activity Detail also links to the comment section and the activity's messaging channel._]
  ],
  caption: [Information architecture and main screen groups]
)

=== Navigation Summary

#table(
  columns: (0.8fr, 0.7fr, 2fr),
  table.header([*Area*], [*Primary user*], [*Purpose*]),
  [Activity Feed], [Volunteer], [Compare opportunities and tap into the detail screen.],
  [Activity Detail], [Both], [Full event info, join status, comments, and channel entry.],
  [My Records], [Volunteer], [See what I've joined, what's completed, and my history.],
  [Organiser Tools], [Organiser], [Create, revise, cancel activities and confirm who participated.],
  [Leaderboard], [Both], [See confirmed volunteering totals ranked.],
  [Account], [Both], [Identity details, avatar, session management.],
)

== Core User Flows

I mapped out the four most important user interactions as step-by-step flows. These cover registration, activity publication, joining with capacity protection, and messaging.

=== Flow 1: Registration

Registration needs to be quick. It collects school identity details and an avatar, validates the obvious stuff locally, and only hits the server once the form is ready.

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    table.header([*Step*], [*From*], [*To*], [*Action*]),
    [1], [User], [App], [Fill in school email, name, class, password, and pick an avatar.],
    [2], [App], [App], [Validate that required fields are filled and formats look right.],
    [3], [App], [Service], [Send the registration request.],
    [4], [Service], [Service], [Check that the email isn't already taken; hash the password.],
    [5], [Service], [DB], [Create the user record.],
    [6], [DB], [Service], [Confirm storage.],
    [7], [Service], [App], [Return success.],
    [8], [App], [User], [Show confirmation and redirect to login.],
  ),
  caption: [Registration flow]
)

=== Flow 2: Activity Publication

An organiser needs to publish activities without too much friction, but the activity also needs enough information for volunteers to decide if they want to join. I tried to find a middle ground -- the form asks for title, date, location, capacity, duration, and description. Nothing optional except description.

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    table.header([*Step*], [*From*], [*To*], [*Action*]),
    [1], [Organiser], [App], [Fill in title, date, location, capacity, duration, and description.],
    [2], [App], [Service], [Submit the new activity.],
    [3], [Service], [Service], [Verify the user has organiser permission.],
    [4], [Service], [DB], [Insert the activity in `recruiting` state.],
    [5], [DB], [Service], [Confirm storage.],
    [6], [Service], [App], [Return the created activity.],
    [7], [App], [Organiser], [Show the result in the feed.],
  ),
  caption: [Activity publication flow]
)

=== Flow 3: Joining with Capacity Protection

This is the flow I spent the most time thinking about, because it combines user feedback, data integrity, and concurrency. If two volunteers tap "Join" at the same time on an activity with one slot left, only one should succeed. The server uses a database transaction with row-level locking to handle this.

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    table.header([*Step*], [*From*], [*To*], [*Action*]),
    [1], [Volunteer], [App], [Tap the Join button.],
    [2], [App], [Service], [Send a join request.],
    [3], [Service], [DB], [Start a transaction and lock the activity row.],
    [4], [Service], [DB], [Read current participant count.],
    [5], [Service], [DB], [Check if this user already has a participation record.],
    [6a], [Service], [App], [_If full or duplicate:_ roll back and return a clear rejection reason.],
    [6b], [Service], [DB], [_If valid:_ create participation record and increment the count.],
    [7], [Service], [DB], [Commit the transaction.],
    [8], [Service], [App], [Confirm the join.],
    [9], [App], [Volunteer], [Refresh the local state to show the new status.],
  ),
  caption: [Protected join flow]
)

The critical logic in pseudocode:
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

I decided to tie messaging to activities rather than having a separate social space. This was a deliberate choice -- the client mentioned that past attempts at group chats got off-topic quickly. By scoping each channel to one activity, the conversation stays relevant to preparation and coordination.

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    table.header([*Step*], [*From*], [*To*], [*Action*]),
    [1], [Sender], [App], [Type and send a message in the activity channel.],
    [2], [App], [Service], [Post the message.],
    [3], [Service], [Service], [Verify the sender is a channel member.],
    [4], [Service], [DB], [Store the message.],
    [5], [Service], [Push], [Publish an update event to other channel members.],
    [6], [Push], [Receiver], [Deliver the new-message event in real time.],
    [7], [Service], [App], [Confirm storage to the sender.],
  ),
  caption: [Activity messaging flow]
)

== Data Design

I used a relational database because most of the data in this system is about relationships -- a user _joins_ an activity, an activity _has_ a channel, a channel _contains_ messages. A document database could work, but I'd lose the ability to enforce foreign keys and unique constraints at the database level, which matters for things like preventing duplicate joins.

=== Entity Definitions

The tables below show every entity in the system. I'll explain the less obvious design choices after the definitions.

#figure(
  table(
    columns: (1fr, 1fr, auto),
    table.header([*Field*], [*Type*], [*Notes*]),

    table.cell(colspan: 3, fill: blue-soft)[#text(weight: "bold", fill: sky)[users]],
    [id], [UUID], [Primary key],
    [school_email], [string], [Unique; used for login],
    [real_name], [string], [],
    [class_name], [string], [],
    [avatar_path], [string], [Path to uploaded image],
    [password_hash], [string], [bcrypt hash],
    [role], [string], [volunteer or organiser],

    table.cell(colspan: 3, fill: blue-soft)[#text(weight: "bold", fill: sky)[sessions]],
    [id], [UUID], [Primary key],
    [user_id], [UUID], [FK #sym.arrow.r users],
    [issued_at], [datetime], [],

    table.cell(colspan: 3, fill: mint-soft)[#text(weight: "bold", fill: mint-ink)[activities]],
    [id], [UUID], [Primary key],
    [organiser_id], [UUID], [FK #sym.arrow.r users],
    [title], [string], [],
    [start_at], [datetime], [],
    [location], [string], [],
    [max_participants], [int], [],
    [current_participants], [int], [Denormalized counter],
    [duration_minutes], [int], [],
    [state], [string], [See state machine below],

    table.cell(colspan: 3, fill: mint-soft)[#text(weight: "bold", fill: mint-ink)[records] _(participation)_],
    [id], [UUID], [Primary key],
    [activity_id], [UUID], [FK #sym.arrow.r activities],
    [user_id], [UUID], [FK #sym.arrow.r users],
    [state], [string], [joined, completed, cancelled],
    [updated_at], [datetime], [],

    table.cell(colspan: 3, fill: amber-soft)[#text(weight: "bold", fill: amber-ink)[comments]],
    [id], [UUID], [Primary key],
    [activity_id], [UUID], [FK #sym.arrow.r activities],
    [author_id], [UUID], [FK #sym.arrow.r users],
    [content], [string], [],
    [created_at], [datetime], [],

    table.cell(colspan: 3, fill: amber-soft)[#text(weight: "bold", fill: amber-ink)[channels]],
    [id], [UUID], [Primary key],
    [activity_id], [UUID], [FK #sym.arrow.r activities; one channel per activity],
    [name], [string], [],

    table.cell(colspan: 3, fill: amber-soft)[#text(weight: "bold", fill: amber-ink)[channel_members]],
    [channel_id], [UUID], [FK #sym.arrow.r channels],
    [user_id], [UUID], [FK #sym.arrow.r users],

    table.cell(colspan: 3, fill: rose-soft)[#text(weight: "bold", fill: rose-ink)[messages]],
    [id], [UUID], [Primary key],
    [channel_id], [UUID], [FK #sym.arrow.r channels],
    [sender_id], [UUID], [FK #sym.arrow.r users],
    [content], [string], [],
    [sent_at], [datetime], [],

    table.cell(colspan: 3, fill: rose-soft)[#text(weight: "bold", fill: rose-ink)[export_batches]],
    [id], [UUID], [Primary key],
    [generated_at], [datetime], [],
    [target_format], [string], [e.g. "ismas_csv"],
    [status], [string], [pending, completed, failed],

    table.cell(colspan: 3, fill: rose-soft)[#text(weight: "bold", fill: rose-ink)[export_items]],
    [id], [UUID], [Primary key],
    [batch_id], [UUID], [FK #sym.arrow.r export_batches],
    [user_id], [UUID], [FK #sym.arrow.r users],
    [activity_id], [UUID], [FK #sym.arrow.r activities],
    [confirmed_minutes], [int], [],
  ),
  caption: [Entity definitions]
)

=== Relationships

#figure(
  table(
    columns: (1.2fr, auto, 1.2fr, 1.8fr),
    table.header([*Entity A*], [*Relation*], [*Entity B*], [*Explanation*]),
    [users], [1 #sym.arrow.r #sym.ast], [sessions], [A user can have multiple sessions over time.],
    [users], [1 #sym.arrow.r #sym.ast], [activities], [An organiser publishes zero or more activities.],
    [users], [1 #sym.arrow.r #sym.ast], [records], [A volunteer accumulates participation records.],
    [users], [1 #sym.arrow.r #sym.ast], [comments], [A user writes comments on activities.],
    [users], [1 #sym.arrow.r #sym.ast], [messages], [A user sends messages in channels.],
    [activities], [1 #sym.arrow.r #sym.ast], [records], [Each activity tracks who joined and their status.],
    [activities], [1 #sym.arrow.r #sym.ast], [comments], [Activities can have discussion comments.],
    [activities], [1 #sym.arrow.r 0..1], [channels], [An activity may have one messaging channel.],
    [channels], [1 #sym.arrow.r #sym.ast], [channel_members], [Tracks who has access to the channel.],
    [channels], [1 #sym.arrow.r #sym.ast], [messages], [Messages belong to a specific channel.],
    [export_batches], [1 #sym.arrow.r #sym.ast], [export_items], [A batch contains individual export rows.],
  ),
  caption: [Entity relationships]
)

=== Key Data Rules

#table(
  columns: (1.2fr, 2fr),
  table.header([*Rule*], [*How I enforce it*]),
  [No duplicate joins], [Unique constraint on `(activity_id, user_id)` in the records table.],
  [Capacity count stays accurate], [The participant count update and record creation happen inside a single database transaction.],
  [Only confirmed hours count for rankings], [The leaderboard query filters on `records.state = 'completed'` before aggregating.],
  [Channel messages are private], [The service checks channel membership before allowing reads or writes.],
  [Export format is separate from core logic], [A dedicated adapter layer transforms confirmed records into whatever format the school needs.],
)

== Internal Structures and Algorithms

=== Activity State Machine

Activities go through a set of defined states. I chose to make these explicit rather than using boolean flags (like `is_active`, `is_cancelled`) because flags get confusing fast -- what does it mean if `is_active` is true but `is_cancelled` is also true? A single `state` field avoids that ambiguity.

#figure(
  table(
    columns: (1fr, 1fr, 1fr),
    table.header([*Current State*], [*Event*], [*Next State*]),
    [_(new)_], [Organiser creates activity], [Draft],
    [Draft], [Organiser publishes], [Recruiting],
    [Recruiting], [Organiser starts the activity], [InProgress],
    [Recruiting], [Organiser cancels], [Cancelled],
    [InProgress], [Organiser confirms finish], [Completed],
    [InProgress], [Organiser cancels], [Cancelled],
  ),
  caption: [Activity state transitions]
)

#table(
  columns: (0.7fr, 1.5fr, 0.8fr),
  table.header([*State*], [*What it means*], [*Volunteers see it?*]),
  [Draft], [The organiser is still preparing this. Not visible to volunteers yet.], [No],
  [Recruiting], [Published and open for sign-up.], [Yes],
  [InProgress], [The activity has started. No more joining.], [Yes],
  [Completed], [Finished. Hours are now eligible for confirmation.], [Yes (as history)],
  [Cancelled], [Called off. Existing records are marked cancelled too.], [Yes (as cancelled)],
)

=== Join Algorithm

The join process is the most algorithmically interesting part of the system because it mixes validation, concurrency control, and business rules in one transaction. Here's the pseudocode:

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

I want to call out `getActivityForUpdate` specifically -- this is a SELECT ... FOR UPDATE query that locks the activity row until the transaction finishes. Without it, two concurrent join requests could both read "4/5 participants" and both succeed, overfilling the activity.

=== Leaderboard Query Design

I considered storing running totals on each user's profile, but that creates a risk of the total drifting out of sync with the actual records. Instead, the leaderboard is computed fresh from confirmed participation data:

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

The secondary sort on `real_name` is there so that tied volunteers always appear in the same order, rather than shuffling randomly each time the page loads.

=== Export Strategy for School Reporting

I looked into the school's ISMAS system but couldn't find a published import specification. From what I could gather from publicly available documentation about similar school-information systems, they typically use template-based CSV or spreadsheet imports. My approach is to treat export as a separate adapter layer: the core system records and confirms volunteer hours, and the adapter converts that data into whatever format the school's import process actually requires. Once the school provides the official template, I just need to update the adapter.

The fields I plan to export:
- student identifier and name
- class name
- activity title and date
- confirmed duration in minutes
- organiser confirmation timestamp

This way, if the school changes their template, I don't have to touch the core activity or participation logic at all.

== UI / UX Design

I want the interface to feel calm and functional -- more like a school tool than a social media app. Students will probably use it in short bursts (checking what activities are available, sending a quick message), so the feed needs to be easy to scan and the main actions need to be obvious.

=== Interface Principles

These are the guidelines I set for myself when designing the screens:

- The activity feed should show title, time, location, capacity, and join state *without* forcing the user to tap into a detail page. Most of the time, the card alone should be enough to decide.
- Volunteer actions and organiser actions need to be visually separated. The client specifically mentioned that in a previous system, students accidentally triggered admin functions.
- Status indicators should combine text, color, and shape. I don't want to rely on color alone because that fails for colorblind users.
- Error messages should say what to do next, not just what went wrong.

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
  columns: (1fr, 1.4fr, 1.8fr),
  table.header([*Element*], [*What I planned*], [*Why*]),
  [Capacity indicator], [Progress bar plus exact count (e.g. "5 / 20")], [A bar alone looks nice but hides how many spots are actually left.],
  [Join button], [Changes to "Joined" and becomes disabled after tapping], [Stops accidental double taps and makes the current status clear.],
  [Organiser controls], [Grouped in a separate card on the detail screen], [Keeps volunteer UI clean. The client was worried about accidental admin actions.],
  [Leaderboard row], [Avatar, name, rank, and total hours in one line], [Ranking should be understandable at a glance.],
  [Record status chip], [Plain text labels like "Joined", "Completed", "Cancelled"], [Simple language is easier for everyone and easier to test.],
)

=== Validation and Feedback

#table(
  columns: (0.8fr, 1.3fr, 1.5fr),
  table.header([*Input*], [*Rule*], [*What the user sees*]),
  [School email], [Must match school format and not already exist], [Inline error under the field, shown before form submission],
  [Password], [Minimum length; confirmation must match], [Field-level hint rather than a generic alert popup],
  [Activity title], [Required; max length], [Keep focus on the field until corrected],
  [Capacity], [Positive whole number], [Show the allowed range],
  [Duration], [Positive number of minutes], [Prevents invalid scheduling],
  [Avatar], [Optional upload or placeholder], [Shouldn't block registration],
)

= Outline Test Plan

I wrote this test plan to map directly to the success criteria from Criterion A. Every major design promise should have at least one test that can verify it.

== Test Coverage Map

#table(
  columns: (1fr, 1.4fr, 1.6fr),
  table.header([*Success criterion*], [*Tests I plan to run*], [*What I'm looking for*]),
  [1. Account registration], [Valid registration, duplicate email, bad input, avatar upload], [Secure password storage, correct validation messages, account actually works after creation],
  [2. Task publication], [Publish with valid data, try publishing without organiser role, check feed timing], [Correct fields show up; new activity visible in the feed quickly],
  [3. Task management], [Edit an activity, cancel one, check what volunteers see before and after], [Changes propagate immediately; cancelled activities stop appearing as joinable],
  [4. Communication], [Send a message, check if another user receives it live, reopen the channel later], [Messages persist and show up in real time],
  [5. Leaderboard], [Check rank ordering, test ties, confirm that adding hours changes the ranking], [Accurate totals, stable ordering for ties],
  [6. Hour tracking and export], [Confirm participation, check accumulated hours, generate an export batch], [Correct confirmed minutes; export contains the expected fields],
  [7. Platform compatibility], [Run on iPad, rotate the device, test with long content and keyboard visible], [No crashes, no broken layout, usable touch targets on iPadOS 17.5+],
)

== Representative Test Cases

=== T1. Registration with Valid Data

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#1],
  [*Test data*], [A fresh school email, valid password, class name, and an avatar image],
  [*What should happen*], [Account gets created. Password is stored as a hash (not plaintext). Profile data is retrievable. Avatar shows up in the account view.],
)

=== T2. Activity Publication Visibility

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#2],
  [*How I'll test it*], [Create an activity from one account while a second account is already on the feed screen.],
  [*What should happen*], [The new activity shows up within a few seconds with the right date, capacity, description, and duration.],
)

=== T3. Edit and Cancel Propagation

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#3],
  [*How I'll test it*], [Change a published activity's details and cancel a different one. Then check the volunteer feed.],
  [*What should happen*], [Updated details appear without stale data. Cancelled activity no longer shows as joinable.],
)

=== T4. Messaging Persistence and Push

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#4],
  [*How I'll test it*], [Two users open the same activity channel. One sends a message. The other stays on the screen.],
  [*What should happen*], [The receiver sees the message without refreshing. The message is still there after closing and reopening the channel.],
)

=== T5. Leaderboard Recalculation

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#5],
  [*How I'll test it*], [Confirm participation for a volunteer who should move up in rank.],
  [*What should happen*], [Their total hours and rank position update correctly after the confirmation goes through.],
)

=== T6. Hour Tracking and Export

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#6],
  [*How I'll test it*], [Mark a participation as completed, then generate an export batch.],
  [*What should happen*], [The volunteer gains the correct number of minutes. The export contains all the planned fields.],
)

=== T7. iPad Compatibility and Layout

#table(
  columns: (1fr, 3fr),
  [*Success criterion*], [\#7],
  [*How I'll test it*], [Run the app on the target iPads in portrait and landscape with both short and very long content.],
  [*What should happen*], [No crashes, no blocked controls, no text overflow. Touch targets should be comfortable on a 10.9" screen.],
)

== Boundary and Risk-Focused Tests

#table(
  columns: (1fr, 1.2fr, 1.8fr),
  table.header([*Risk*], [*Why it matters*], [*How I'll test it*]),
  [Duplicate join attempts], [Could corrupt the participant count], [Send repeated join requests quickly and check that only one record exists.],
  [Full activity], [Must not overbook], [Try to join when exactly one place remains, and again when none remain.],
  [Network interruption], [Likely in the school WiFi environment], [Kill the network during a join or message send and see if the app recovers gracefully.],
  [Long titles and descriptions], [Can break the iPad layout], [Enter extreme but technically valid text lengths and check the feed and detail screens.],
  [Concurrent confirmation], [Affects leaderboard accuracy], [Confirm multiple records in quick succession and verify the totals add up.],
  [Export format unknown], [Depends on the school providing their template], [Test the adapter with a mock template and verify the output matches.],
)
