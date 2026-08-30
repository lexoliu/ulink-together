# Database Design

This document describes how the new SQL backend is structured and how it coexists with the legacy MongoDB data while we refactor the server.

## Goals

1. Provide a relational schema that mirrors the current domain model.
2. Allow the Rust services to access the SQL database via `sqlx` while we still read from MongoDB.
3. Keep the code portable so we can swap the SQL implementation with [`sqlx-d1`](https://github.com/cloudflare/sqlx-d1) when targeting Cloudflare Workers.

## Schema Overview

The initial migration lives in `migrations/20240220100000_init.sql`. It introduces the following tables:

- `groups`, `group_authorities`: represent user groups and the authorities they grant. Both tables are seeded once at startup from the hardcoded role catalogue in `schema::seed_builtin_groups_*` and are not exposed to any runtime mutation API; changing what a role can do is a code change, not a database edit.
- `users`: mirrors the existing `user` collection. We reuse the Mongo `_id` (hex string) as the SQL primary key so both backends stay consistent.
- `sessions`: mirrors login sessions (`session` collection).
- `activities`, `activity_volunteers`, `activity_comments`: cover organizers, state, volunteers, and comments.
- `channels`, `channel_members`, `messages`: hold chat rooms, memberships, and messages.
- `records`: mirrors volunteer application / approval state.
- `resources`: stores metadata for uploaded files.
- `check_mails`: tracks verification emails.

The schema intentionally stores identifiers as `TEXT` because Mongo `Id`s are serialized as hex strings. This keeps the two persistence layers interoperable and simplifies later migrations.

## Application Layer

- `AppDatabase` (`src/database.rs`) now holds both the Mongo database handle and the `sqlx::Pool<Sqlite>`. Every handler receives `State<AppDatabase>` so we can slowly move read paths over to SQL without losing access to the legacy data.
- `build_database` establishes the SQL connection, runs the embedded migrations, and returns the shared pool. The pool URL is controlled via `DATABASE_URL` (default: `sqlite://together.db`).
- `user::register` is the first endpoint that persists data into SQL. After inserting into Mongo (so we keep the existing source of truth) we mirror the row into the `users` table. If the SQL write fails we roll back the Mongo document and return a 500 to keep both stores in sync.

As we migrate more modules we can move read operations to SQL by swapping calls from `database.mongo()` to helper functions backed by `sqlx`. The `AppDatabase` wrapper means call sites will not change their extractor signatures again.

## Cloudflare Workers / `sqlx-d1`

When building for Workers the plan is:

1. Add a cargo feature (e.g. `d1`) that replaces the `sqlx::Pool<Sqlite>` field inside `AppDatabase` with a `sqlx_d1::Connection` (or a wrapper that implements the same methods we need).
2. Gate the migration runner and connection builder behind `cfg(not(feature = "d1"))`. Cloudflare handles migrations separately, so the Worker build would skip the embedded migrator.
3. Keep repository functions async and trait-friendly so each backend (Postgres/MySQL/D1) can implement the same interface.

Because the Mongo client is already abstracted behind `AppDatabase`, flipping the SQL implementation based on the target will be limited to the constructor and helper methods.

## Next Steps

1. Mirror other write-heavy endpoints (activities, records, messages) into SQL while still reading from Mongo.
2. Once data has been fully copied, switch read paths to SQL with feature flags for fallbacks.
3. Introduce repository traits (e.g., `UserRepo`, `ActivityRepo`) and provide `sqlx` + `sqlx-d1` implementations so the runtime selection becomes a compile-time feature toggle.
