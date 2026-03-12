# SPECS.md

## Goal

This document is the implementation spec for the new SwiftUI client in `swiftui/`.

It exists to turn `Criterion A.md` and `Criterion B.typ` into an actionable engineering plan for future agents.

## 1. Scope

### In Scope

- native SwiftUI iPad app
- volunteer and organiser workflows in one app
- cookie-based session auth
- activity browsing, detail, joining, comments, and messaging
- organiser publishing, editing, cancellation, and completion actions
- records/history view
- leaderboard
- hour-tracking UI
- school-report export flow

### Secondary / Later Scope

- notifications UI
- richer profile editing
- file/media attachments
- advanced search and filtering

These may be implemented later, but they should not block the primary success criteria.

## 2. Product Definition

The app solves a fragmented school volunteer workflow.

The client must support:

- fast browsing of volunteer opportunities
- low-friction activity publication
- reliable join state
- activity-scoped communication
- transparent records and hour totals
- school reporting through structured export

## 3. User Roles

### Volunteer

Can:

- register
- log in
- browse activities
- join activities
- read and post comments if permitted
- read and post messages in joined activity channels
- view own participation records
- view leaderboard
- manage own account information

### Organiser

Can additionally:

- create activities
- edit activity details
- cancel activities
- change activity state
- inspect participant records
- approve/disapprove participation if used by the workflow
- mark participation as done
- trigger export flow

## 4. Top-Level App Structure

The primary shell should be a `TabView` optimized for iPad.

Recommended tab order:

1. `Feed`
2. `Records`
3. `Create` or `Manage`
4. `Leaderboard`
5. `Account`

Notes:

- Non-organiser users should not see unusable organiser tabs.
- Organiser actions may also appear contextually inside detail screens.
- Use `NavigationStack` inside each tab.

## 5. Feature Modules

Recommended SwiftUI feature split:

- `AppShell`
- `Auth`
- `Feed`
- `ActivityDetail`
- `Comments`
- `Channel`
- `Records`
- `Organiser`
- `Leaderboard`
- `Account`
- `SharedUI`
- `Infrastructure`

Recommended filesystem direction inside `swiftui/together/`:

- `App/`
- `Features/Auth/`
- `Features/Feed/`
- `Features/ActivityDetail/`
- `Features/Records/`
- `Features/Organiser/`
- `Features/Leaderboard/`
- `Features/Account/`
- `Features/Channel/`
- `Shared/Components/`
- `Shared/Style/`
- `Infrastructure/API/`
- `Infrastructure/Session/`
- `Infrastructure/Push/`
- `Infrastructure/Routing/`

## 6. Screen Spec

### 6.1 Launch / Session Gate

Purpose:

- determine whether a valid session exists
- route to auth flow or main app shell

Inputs:

- stored cookies / session state

Outputs:

- show login/register
- or show main app shell

State owner:

- global app state

### 6.2 Login Screen

Purpose:

- authenticate existing users

Fields:

- email
- password

Actions:

- submit login
- navigate to registration

API:

- `POST /api/v1/login`

Expected response behavior:

- server sets `uid` and `session` cookies
- client persists cookie jar for subsequent requests

### 6.3 Registration Screen

Purpose:

- create new volunteer account

Fields:

- school email
- real name
- gender
- class name
- password
- confirm password
- avatar selector or placeholder

API:

- `POST /api/v1/user`

Important:

- current shared contract does not yet expose avatar on registration
- do not silently drop avatar support from the product spec
- if implementing this screen fully, resolve the avatar contract first

### 6.4 Activity Feed

Purpose:

- default landing screen for volunteers
- quick comparison of activities

Must show on each card:

- title
- date
- location
- capacity
- brief description
- duration
- state
- join state

Primary actions:

- open activity detail
- join if allowed
- filter by status

API:

- `GET /api/v1/activity`
- optional `user` and `display_all` query parameters

### 6.5 Activity Detail

Purpose:

- show full information for one activity

Must show:

- title
- organiser name
- date
- location
- duration
- full description
- participant count
- current state
- join button or joined state

Child actions:

- join activity
- open comments
- open channel

API:

- `GET /api/v1/activity/{id}`
- `POST /api/v1/activity/{id}/apply`
- `GET /api/v1/activity/{id}/comment`
- `POST /api/v1/activity/{id}/comment`

### 6.6 Comments Screen / Section

Purpose:

- activity-scoped asynchronous discussion

Must show:

- author name
- content
- date

API:

- `GET /api/v1/activity/{id}/comment`
- `POST /api/v1/activity/{id}/comment`

Contract note:

- comment body is plain text request content, not a structured JSON object

### 6.7 Channel Screen

Purpose:

- real-time activity-scoped messaging

Must show:

- message history
- sender identity
- message time
- composer

API:

- `GET /api/v1/channel`
- `POST /api/v1/channel`
- `GET /api/v1/message?channel={id}`
- `POST /api/v1/channel/{id}`
- `GET /api/v1/push`

Push events:

- `message`
- `notification`

Contract notes:

- posting a message uses raw text body
- channel creation currently expects query/form-style parameters, not JSON

### 6.8 Records Screen

Purpose:

- show the current user’s participation history

Must show:

- activity name
- date
- duration
- record state
- whether hours are confirmed

API:

- `GET /api/v1/record`

Typical usage:

- current user filter
- optional drill-in from organiser management

### 6.9 Organiser Activity List

Purpose:

- give organisers one place to see activities they own or manage

Must support:

- open create screen
- open manage/detail screen
- filter by state

Likely API:

- `GET /api/v1/activity?user={currentUserId}`

### 6.10 Create Activity Screen

Purpose:

- publish a new activity

Fields:

- name
- date
- location
- brief description
- full description
- max participants
- duration

API:

- `POST /api/v1/activity`

Request shape:

- `CreateActivityForm` from `models/src/activity.rs`

### 6.11 Manage Activity Screen

Purpose:

- let organisers revise activity details and manage participation lifecycle

Must support:

- view current participants
- change state to recruiting / going / ended / canceled where appropriate
- mark participant done
- optionally approve/disapprove applications if that workflow is still used

API:

- `POST /api/v1/activity/{id}/need_volunteer`
- `POST /api/v1/activity/{id}/go`
- `POST /api/v1/activity/{id}/end`
- `POST /api/v1/activity/{id}/cancel`
- `POST /api/v1/record/{id}/done`
- `POST /api/v1/record/{id}/approve_apply`
- `POST /api/v1/record/{id}/disapprove_apply`

### 6.12 Leaderboard Screen

Purpose:

- show volunteers ranked by confirmed time

Must show:

- rank
- avatar
- real name
- total hours

Data source:

- if no dedicated endpoint exists yet, this feature needs a backend contract addition or a derived fetch strategy

Important:

- do not fake leaderboard data in production code
- if the endpoint is missing, treat it as a real contract task

### 6.13 Account Screen

Purpose:

- show user identity and app session controls

Must show:

- avatar
- real name
- email
- class name
- logout

API:

- `GET /api/v1/user/me`

Contract note:

- `server/src/user.rs` supports `"me"` as a special user id

## 7. Global State Ownership

### Global App State

Should own:

- authentication status
- cookie/session storage
- current user summary
- known authorities
- push connection lifecycle

Should not own:

- per-screen form fields
- long-lived activity detail caches for every screen

### Feature State

Each major screen should own its own:

- loading state
- error state
- local filter/sort state
- screen-specific presentation state

## 8. API Client Rules

Create a dedicated API layer. Do not scatter raw `URLSession` requests through views.

Required responsibilities:

- base URL management
- cookie persistence
- request encoding
- response decoding
- consistent error mapping
- SSE connection management

Suggested infrastructure types:

- `APIClient`
- `SessionStore`
- `PushClient`
- `AuthorityStore`

## 9. Authority and Role Handling

Do not derive organiser access from UI assumptions.

Use:

- `GET /api/v1/auth/check/{authority}`

Known authorities from server code include:

- `create_activity`
- `create_channel`
- `send_comment`
- `send_notification`
- `send_message_anyway`
- `delete_activity_anyway`
- `delete_channel_anyway`
- `delete_message_anyway`
- `manage_record_anyway`
- `view_user`
- `delete_user`

Client rule:

- authority checks may be cached locally after first fetch
- destructive or privileged UI should remain hidden or disabled when authority is absent

## 10. UI System

### Design Direction

- calm, academic, readable
- iPad-first density
- clean card-based feed
- role separation without visual chaos

### Color Roles

Recommended semantic colors:

- primary blue: navigation, buttons, active progress
- green: recruiting / organiser-positive actions
- amber: joined / pending / caution
- rose or red: canceled / destructive actions
- neutral slate: metadata and secondary text

### Typography

- large section title
- strong card title
- compact metadata rows
- monospaced code only in debug or developer-only surfaces

### Spacing

- generous horizontal padding for iPad
- cards should be scannable, not edge-to-edge
- buttons should remain comfortably tappable

### Component Set

Create reusable components for:

- activity card
- state chip
- capacity bar
- avatar view
- empty state
- loading state
- inline form error
- ranking row

## 11. State Mapping Rules

UI labels should be user-friendly, but transport values must match server values.

### Activity state mapping

- `need_volunteer` -> `Recruiting`
- `going` -> `In Progress`
- `ended` -> `Completed`
- `canceled` -> `Cancelled`

### Record state mapping

- `todo` -> `Joined` or `Pending Completion`
- `done` -> `Completed`
- `canceled` -> `Cancelled`

If additional client-only display states are introduced, they must be derived, not invented as new transport values.

## 12. Export Strategy

The app should expose export as a reporting feature, not as a hard-coded assumption about a public ISMAS protocol.

Current safe assumption:

- export produces a structured batch matching the school-provided ISMAS import template

Required export fields:

- student identifier
- student name
- class name
- activity title
- activity date
- confirmed duration
- organiser confirmation timestamp

If the template format is missing, mark the feature as blocked by external requirements rather than guessing the schema.

## 13. Implementation Order

Recommended delivery order:

1. app shell + session gate
2. login
3. registration
4. feed
5. activity detail + join
6. comments
7. records
8. organiser create/manage
9. channel + SSE
10. leaderboard
11. export flow
12. account polish

## 14. Definition Of Done

A feature is not done when the screen exists.

A feature is done only when:

- UI is connected to the real contract
- loading and error states are present
- navigation is coherent
- iPad layout works in portrait and landscape where relevant
- success-criterion behavior is demonstrable

## 15. Open Contract Issues

These must stay visible during development.

### Avatar contract

- Product spec expects avatar support.
- Shared registration/user models do not currently expose it.

### Leaderboard endpoint

- Product requires a leaderboard.
- Current server route list does not expose a dedicated leaderboard endpoint.
- Either add one or define a real derived strategy. Do not fake it.

### Export trigger contract

- Product requires export generation.
- Current server route list does not show a dedicated export endpoint.
- Treat this as a real backend task if the feature slice reaches export.

## 16. Immediate Expectation For The Next Agent

The next implementation-focused agent should:

1. replace the SwiftUI skeleton with the app shell and navigation structure
2. build the authentication flow
3. implement the activity feed and detail flow against the real API
4. keep all known contract gaps explicit rather than hidden
