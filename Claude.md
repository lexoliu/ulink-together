## Purpose

This repository is building a new iPad-first volunteer management application for Ulink College of Shanghai.

Future agents should treat this file as the fast orientation document. Before making significant changes, read:

1. `AGENT.md`
2. `SPECS.md`
3. `doc/Crit_A_Planning.typ`
4. `doc/Crit_B_Design.typ`

## Product Summary

The product is a client-server system for school volunteering.

Primary users:

- `Volunteer`: browse activities, join activities, comment, message, view records, view leaderboard.
- `Organiser`: publish activities, edit or cancel activities, manage participation, confirm completed hours, supervise communication.

Primary client environment:

- school-managed iPads
- iPadOS 17.5+
- native SwiftUI client in `swiftui/`

## Success Criteria

The implementation must stay aligned with `doc/Crit_A_Planning.typ`.

1. Account Registration
2. Task Publication
3. Task Management
4. Communication
5. Leaderboard
6. Hour Tracking and Export
7. Platform Compatibility

Do not casually reinterpret these criteria during implementation. If a criterion is ambiguous, surface the ambiguity explicitly.

## Repository Layout

- `swiftui/`: new SwiftUI app. This is the client implementation target.
- `app/`: frozen exploratory implementation. Do not use it as a product reference, implementation guide, or contract source.
- `server/`: Rust backend API, auth, persistence, and push logic.
- `models/`: shared Rust models and payload naming reference.
- `design/`: static visual references; useful for inspiration, not the final source of truth.
- `doc/Crit_A_Planning.typ`: client context and success criteria.
- `doc/Crit_B_Design.typ`: design overview, flows, data design, UI direction, and test mapping.
- `/Users/lexoliu/Coding/old-ulink-together`: historical reference implementation. If previous product behavior needs to be understood, inspect this path instead of `app/`.

## Current Engineering Reality

- `swiftui/` is still close to a skeleton and should be treated as a fresh client implementation.
- `app/` is incomplete and frozen. It must not be consulted for feature parity, UI decisions, or API expectations.
- `server/` and `models/` already define most of the current runtime contract.
- Authentication is cookie-based, not token-based.
- Real-time updates use SSE at `/api/v1/push`.
- Organiser capabilities are authority-driven, not determined by a simple hard-coded role enum from the client.

## Working Rules For Future Agents

- Build the client from `SPECS.md`, not from guesswork.
- Do not reference `app/` during implementation work. Treat it as dead exploratory code.
- If historical behavior or prior product flow needs to be understood, use `/Users/lexoliu/Coding/old-ulink-together` as the reference repository instead.
- Do not mention old products or exploratory client implementations in project-facing docs unless explicitly asked.
- Do not edit `doc/Crit_A_Planning.typ` or `doc/Crit_B_Design.typ` unless the user asks for document work.
- Keep the app iPad-first. Avoid phone-first compromises in navigation or density.
- Prefer feature slices over broad rewrites:
  - auth
  - feed
  - detail
  - records
  - organiser tools
  - leaderboard
  - account
- Fail fast on contract mismatches. Do not silently “work around” them in the UI.

## Known Contract Gaps

These are real gaps. Future agents should not pretend they do not exist.

### 1. Avatar support is required by Criterion A, but the current shared registration model does not expose it

- `doc/Crit_A_Planning.typ` expects avatar support.
- `models/src/user.rs` currently defines `RegisterForm` without an avatar field.
- If avatar is part of the requested feature slice, the contract gap must be resolved explicitly.

### 2. Client-facing state names and backend enum names are not identical

Design language in `doc/Crit_B_Design.typ` uses user-friendly labels such as:

- `Draft`
- `Recruiting`
- `In Progress`
- `Completed`
- `Cancelled`

Current backend/runtime enums use:

- activity: `need_volunteer`, `going`, `ended`, `canceled`
- record: `todo`, `done`, `canceled`

UI labels may be friendlier, but wire-level values must stay aligned with the actual contract unless the backend is intentionally changed.

### 3. Organiser permissions are authority-based

Do not hard-code organiser behavior from UI assumptions alone. Use the existing authority model where possible and expose the minimum necessary checks on the client.

## Practical Source Of Truth

When these sources disagree, prefer them in this order for implementation work:

1. user instructions in the current conversation
2. `SPECS.md`
3. runtime contract in `server/` and `models/`
4. `doc/Crit_A_Planning.typ`
5. `doc/Crit_B_Design.typ`

## Expected Outcome

The goal is not to produce isolated demo screens. The goal is to deliver a real SwiftUI client that can satisfy the success criteria and operate against the existing service contract with clear, maintainable structure.
