# together-server

Backend API service for ULink Together.

## Requirements

- Rust (stable toolchain)
- SQLite or Postgres

## Quick start

Run with the default SQLite database:

```bash
cargo run -p together-server
```

If no database URL is provided, it defaults to:

```
sqlite://together.db
```

## Configuration

Pass a database URL via CLI:

```bash
cargo run -p together-server -- --database-url sqlite://./together.db
```

Postgres example:

```bash
cargo run -p together-server -- --database-url postgres://user:pass@host:5432/dbname
```

## Database bootstrap (schema + admin user)

Use the deploy CLI to create tables and seed the first admin user.

Interactive mode (prompts for missing values):

```bash
cargo run -p together-server --bin deploy
```

Non-interactive (use flags):

```bash
cargo run -p together-server --bin deploy -- \
  --database-url sqlite://./together.db \
  --admin-email admin@example.com \
  --admin-password changeme \
  --non-interactive
```

Supported flags:

- `--database-url`
- `--admin-email`
- `--admin-password`
- `--admin-realname` (default: `Admin`)
- `--admin-gender` (default: `unspecified`)
- `--admin-classname` (default: `Admin`)
- `--admin-description` (default: empty)

### Cloudflare D1 note

If you pass a `d1://` URL, the deploy CLI will translate it to a SQLite URL
and initialize the schema using SQLite-compatible SQL.

## Demo bootstrap

Use the demo seed CLI to create a clean showcase database with teachers,
students, activities, comments, channel traffic, completed hours, and exportable
records.

One-command flow from the repository root:

```bash
./scripts/init-demo.sh
```

Direct CLI usage:

```bash
cargo run -p together-server --bin demo_seed -- --reset
```

Default demo database:

```
sqlite://./together-demo.db
```

Default sample credentials:

- admin: `rachel.ho@ulink.cn` / `DemoAdmin123!`
- teacher: `jamie.wu@ulink.cn` / `DemoTeacher123!`
- student: `alex.chen@ulink.cn` / `DemoStudent123!`

The shell script accepts environment overrides such as:

- `DEMO_DATABASE_URL`
- `DEMO_TEACHER_COUNT`
- `DEMO_STUDENT_COUNT`
- `DEMO_ACTIVITIES_PER_TEACHER`
- `DEMO_ADMIN_PASSWORD`
- `DEMO_TEACHER_PASSWORD`
- `DEMO_STUDENT_PASSWORD`
- `DEMO_SEED`

## Push (SSE)

Clients can subscribe to server-sent events at:

```
GET /api/v1/push
```

Events are named and JSON encoded:

- `event: message` — emitted when a channel message is posted. Payload:
  - `id`, `channel`, `sender`, `content`, `datetime`
- `event: notification` — emitted when a notification is created. Payload:
  - `id`, `user`, `title`, `content`, `created_at`

### Notifications

List the current user's notifications:

```
GET /api/v1/notification
```

Create a notification (requires `send_notification` authority):

```
POST /api/v1/notification
Content-Type: application/json

{
  "user": "<user id>",
  "title": "Welcome",
  "content": "..."
}
```

## Tests

```bash
cargo test -p together-server
```
