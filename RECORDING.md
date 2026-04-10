# Recording Guide for Criterion D

This document is the step-by-step playbook for standing up a **real-data demo environment** so that the Criterion D video (`doc/Crit_D_Video_Script.md`) can be recorded without any mocks, stubs, or placeholder screens.

IBDP requires the Criterion D demonstration to run against a working product, not a rehearsed mockup. Every click in the video must hit a real running server and produce real database changes, which is why the steps below exist.

---

## TL;DR (for the impatient)

Open four terminal tabs and run, in order:

```bash
# Tab 1 — seed the demo database
cd ~/Coding/ulink-together
DEMO_DATABASE_URL="sqlite:///tmp/together-demo.db" ./scripts/init-demo.sh

# Tab 2 — run the server on a fixed port
cargo run --bin together-server -- \
  --db sqlite:///tmp/together-demo.db \
  --port 8080

# Tab 3 — run the admin panel, proxying to the server
cd admin
BACKEND_TARGET=http://127.0.0.1:8080 bun run dev

# Tab 4 — launch the iPad simulator with the SwiftUI app pointed at the same server
open -a Simulator
xcodebuild \
  -project swiftui/together.xcodeproj \
  -scheme together \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  TOGETHER_API_BASE_URL="http://127.0.0.1:8080" \
  run
```

Everything else in this document is the long form of that checklist.

---

## 1. Prerequisites

Before recording you must have installed:

| Tool | Minimum version | Used for |
|---|---|---|
| Rust toolchain (via `rustup`) | 1.80+ | Compiling the server and running `demo_seed` |
| Bun | 1.2+ | Running the React admin panel |
| Xcode | 16.0+ with an iPad simulator installed | Running the SwiftUI app |
| SQLite CLI | 3.40+ (built into macOS) | Inspecting the database during Section 1 of the video |
| QuickTime or OBS | — | Screen capture |

Optional but recommended:

- **iTerm2** with split panes, so Tabs 1–3 are visible at once during recording preparation.
- **Rectangle** or another window-snapping tool, so the iPad simulator and Chrome window are placed at exactly the same position between takes.

> **Do not** use `brew install postgresql` or any other database — the seeded environment is SQLite only. All file paths below assume SQLite.

---

## 2. Seed the demo database

The demo seeder produces a deterministic, realistic data set: one admin, four teachers, seventy-two students, twenty-four activities across all four lifecycle states, plus records, comments, and channel messages. This is the state every video section assumes.

### Why this matters

If you start the server against an empty database, every screen the recorder opens will be blank, the capacity-protection demonstration in Section 4 of the script will be impossible, and the Leaderboard will show no ranks. Seeding is not optional.

### Run the seeder

```bash
# From the repo root
DEMO_DATABASE_URL="sqlite:///tmp/together-demo.db" ./scripts/init-demo.sh
```

You can override any of the defaults with environment variables:

| Env var | Default | What it does |
|---|---|---|
| `DEMO_DATABASE_URL` | `sqlite://./together-demo.db` | Destination database URL |
| `DEMO_TEACHER_COUNT` | `4` | Number of teacher accounts |
| `DEMO_STUDENT_COUNT` | `72` | Number of student accounts |
| `DEMO_ACTIVITIES_PER_TEACHER` | `6` | Seed activities per teacher |
| `DEMO_COMMENTS_PER_ACTIVITY` | `4` | Comments per activity |
| `DEMO_MESSAGES_PER_ACTIVITY` | `8` | Channel messages per activity |
| `DEMO_ADMIN_PASSWORD` | `DemoAdmin123!` | Password for `admin@demo.ulink.local` |
| `DEMO_TEACHER_PASSWORD` | `DemoTeacher123!` | Password for every `teacherNN@demo.ulink.local` |
| `DEMO_STUDENT_PASSWORD` | `DemoStudent123!` | Password for every `studentNNN@demo.ulink.local` |
| `DEMO_SEED` | `20260317` | RNG seed — keeps the data identical between runs |

The script always passes `--reset`, so it is safe to run as many times as you need between takes.

### What the seeder prints

At the end of the run the seeder logs credentials that the script expects to be in the database:

```
 INFO Demo database initialized
 INFO Teachers: 4, students: 72, activities: 25, records: 233, comments: 96, messages: 192
 INFO Activity states -> recruiting: 9, going: 4, ended: 8, canceled: 4
 INFO Admin login:   admin@demo.ulink.local / DemoAdmin123!
 INFO Teacher login: teacher01@demo.ulink.local / DemoTeacher123!
 INFO Student login: student001@demo.ulink.local / DemoStudent123!
```

Keep this terminal output visible while rehearsing — the three logins are the only accounts the script uses.

> The activity count is 25 rather than `teacher_count × activities_per_teacher` because the seeder adds one extra **capacity-demo activity** called "Library Reshelving Marathon (Capacity Demo)" filled to 12 of 12 slots. Section 4 of the video script relies on this exact state so that the very next apply is rejected by the server's `volunteer_num >= max_volunteer_num` guard.

### Confirm the seed worked

```bash
sqlite3 /tmp/together-demo.db \
  "SELECT COUNT(*) FROM users;
   SELECT COUNT(*) FROM activities;
   SELECT COUNT(*) FROM records;
   SELECT name, volunteer_num || '/' || max_volunteer_num
     FROM activities WHERE name LIKE '%Capacity Demo%';"
```

Expected:

- 77 users (1 admin + 4 teachers + 72 students)
- 25 activities (24 regular + 1 capacity-demo)
- 233 records
- `Library Reshelving Marathon (Capacity Demo)|12/12`

---

## 3. Start the Rust server on a fixed port

The server is built on skyzen, which defaults to a random free port if none is specified. That is fine for development but **breaks the recording setup**, because both the admin panel proxy and the iPad simulator need a fixed URL.

### Run with `--port`

```bash
cargo run --bin together-server -- \
  --db sqlite:///tmp/together-demo.db \
  --port 8080
```

`--port 8080` tells skyzen to listen on `127.0.0.1:8080`. Alternatives:

```bash
# Bind to a different interface (only if you need an off-host client)
cargo run --bin together-server -- --db sqlite:///tmp/together-demo.db --listen 0.0.0.0:8080

# Set via env var instead of CLI
SKYZEN_ADDRESS=127.0.0.1:8080 cargo run --bin together-server -- --db sqlite:///tmp/together-demo.db
```

### Expected log

```
 INFO skyzen::runtime::native: Skyzen application starting up
 INFO skyzen::runtime::native: Skyzen listening on http://127.0.0.1:8080
```

If you see a different port in the log, either the `--port` flag was swallowed by cargo (use `--`-separation as shown above) or port 8080 is already in use. Free it with `lsof -ti :8080 | xargs kill` and retry.

### Smoke-test the server

```bash
curl -s http://127.0.0.1:8080/api/v1/health
# → {"status":"ok"}

curl -s -X POST http://127.0.0.1:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@demo.ulink.local","password":"DemoAdmin123!"}' -i | head -20
# → HTTP/1.1 200 OK plus Set-Cookie: session=...
```

If both of these succeed you have a working server bound to a stable address.

---

## 4. Start the admin panel

The React admin panel runs a Vite dev server that proxies `/api/*` to the Rust server. It needs one environment variable, `BACKEND_TARGET`, to know where to proxy.

### Run

```bash
cd admin
BACKEND_TARGET=http://127.0.0.1:8080 bun run dev
```

Vite will start on `http://localhost:5173` (or 5174 if 5173 is taken). **Write the port down** — the video script assumes 5173.

### Why `BACKEND_TARGET` and not `VITE_BACKEND_ORIGIN`?

`VITE_BACKEND_ORIGIN` is exposed to the browser bundle and causes the admin panel to hit the server directly, which leads to CORS errors. `BACKEND_TARGET` is read only by the Vite proxy config and is **not** embedded in the shipped JavaScript. Using `BACKEND_TARGET` keeps the browser talking to `http://localhost:5173/api/*`, which the proxy forwards to the server.

### Smoke-test the admin panel

Open `http://localhost:5173/` in Chrome. You should see the login page. Sign in as `admin@demo.ulink.local` / `DemoAdmin123!` and verify the dashboard shows 8 recruiting / 4 in progress / 8 completed. Sign out before you start recording so your first frame is the login screen.

---

## 5. Build and launch the SwiftUI iPad app

The SwiftUI app reads its server URL from the `TOGETHER_API_BASE_URL` Info.plist entry. In the xcodeproj this key is declared as `INFOPLIST_KEY_TOGETHER_API_BASE_URL = ""` — empty by default, so the user enters an address at runtime. For recording you want a fixed URL baked in, so the simulator never shows the "Enter service address" step unless the script asks for it.

### Option A — build-time override (recommended for recording)

```bash
cd swiftui
xcodebuild \
  -project together.xcodeproj \
  -scheme together \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  INFOPLIST_KEY_TOGETHER_API_BASE_URL="http://127.0.0.1:8080" \
  build
```

Then launch:

```bash
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/together-*/Build/Products/Debug-iphonesimulator/together.app
xcrun simctl launch booted cool.lexo.together
```

### Option B — Xcode GUI

1. Open `swiftui/together.xcodeproj` in Xcode.
2. Select the `together` scheme and the **iPad Pro 13-inch (M4)** simulator.
3. Open **Edit Scheme → Run → Arguments → Environment Variables** and add `TOGETHER_API_BASE_URL = http://127.0.0.1:8080`.
4. Press Run (`⌘R`).

### Option C — runtime entry (if you deliberately want to record Section 1 of the script showing the server-address field)

Leave `TOGETHER_API_BASE_URL` empty. On first launch the app will prompt for a service address. Enter `http://127.0.0.1:8080` and tap Next.

> **Warning**: the Xcode simulator's `localhost` is the host Mac, so `http://127.0.0.1:8080` does resolve to your running server. You do **not** need to replace it with your LAN IP unless you are running the server on a different machine.

### Smoke-test the iPad app

On the first launch, the auth screen should appear within one second. Sign in as `student001@demo.ulink.local` / `DemoStudent123!`, then pull-to-refresh the Explore tab — you should see activities populated from the seed (not an empty list). Sign out before recording.

---

## 6. Prepare the stage

Once all four processes (seed, server, admin, iPad) are ready, arrange the capture area:

1. **iPad simulator**: place on the left half of the screen, use the **Window → Physical Size** option so the frame matches a real iPad's pixel density. Keep orientation in landscape by default.
2. **Chrome with the admin panel**: place on the right half, resized to 1440×900 so the screenshots committed to `doc/assets/` match the recorded footage.
3. **Terminal window**: hidden off-screen except for Section 1 (where the recorder briefly cuts to it to show the bcrypt hash) and Section 4 (where the recorder cuts to the `SELECT COUNT(*)` query). Pre-type the two `sqlite3` commands into a script so the recorder only has to press Return.

### Recording software settings

- **QuickTime screen recording** is fine for the simulator-only shots. For scenes that need both windows, use **OBS** with two sources (macOS Screen Capture for Chrome, Display Capture for the iPad simulator) arranged in a split layout.
- Record at 1920×1080 or higher. The final video must be legible at 1080p on a projector.
- Disable system notifications (`System Settings → Notifications → Do Not Disturb`) before pressing Record. IBDP evaluators notice stray banner pop-ups.
- Disable `Reduce Motion` only if the cursor trail is otherwise invisible.

---

## 7. Reset between takes

Every take that moves the database forward — applying to an activity, confirming hours, sending a message, creating a user — has to be undone before the next rehearsal or re-take, or the script will fall out of sync with the data.

The simplest reset is to stop the server and re-run the seeder:

```bash
# Stop the server (Ctrl+C in its terminal)
# Re-seed
DEMO_DATABASE_URL="sqlite:///tmp/together-demo.db" ./scripts/init-demo.sh
# Restart the server
cargo run --bin together-server -- --db sqlite:///tmp/together-demo.db --port 8080
```

The seeder uses a fixed RNG seed (`DEMO_SEED=20260317`) so every reset produces the **same** emails, classrooms, and capacity fills. The activity that the script uses for the capacity-protection demonstration in Section 4 is always one of the seeded `Going` activities with 11/12 capacity after re-seeding.

> **Never** hand-edit the database between takes. If you need to force a particular state (e.g. a specific activity to be full), change the seeder in `server/src/bin/demo_seed.rs` and re-run it — the edit belongs in version control, not in an ad-hoc `sqlite3 UPDATE`.

---

## 8. Fault-finding checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| `Skyzen listening on http://127.0.0.1:<random>` | `--port` arg was eaten by cargo | Use `cargo run --bin together-server -- --port 8080` with an explicit `--` separator |
| Admin panel shows `Network error` immediately after login | Dev server started without `BACKEND_TARGET` | Stop Vite (`Ctrl+C`), re-export `BACKEND_TARGET=http://127.0.0.1:8080` and restart |
| Admin panel shows `CORS error` | You set `VITE_BACKEND_ORIGIN` by mistake, which exposes the backend URL to the browser | Unset `VITE_BACKEND_ORIGIN`, set `BACKEND_TARGET` instead |
| iPad app opens with the "Enter service address" field | `TOGETHER_API_BASE_URL` not baked into the build | Use Option A or B in §5 |
| iPad app shows `Could not reach the service` | Server not running on the expected port or using IPv6 loopback | Verify with `curl http://127.0.0.1:8080/api/v1/health`; if the server is bound to `::1` use `http://[::1]:8080` instead |
| `student001` has no activities in Explore | Seed database used but server is pointing at a different SQLite file | Double-check `--db` argument matches `DEMO_DATABASE_URL` |
| Capacity protection demo fails — apply silently succeeds past 12/12 | You forgot to re-seed between rehearsals, so the seeded activity is already in a different state | Run `scripts/init-demo.sh` again |
| Teacher sees the Users tab in the sidebar | You logged in with the admin account by mistake | Sign out, sign back in with `teacher01@demo.ulink.local` |
| Notifications tab shows "You're all caught up" during Section 6 | The previous take ran long enough for the SSE push to already arrive and you dismissed the notifications by mistake | Re-seed; the seed does not create notifications, so you must re-trigger them by posting a message before recording Section 6 |

---

## 9. Clean shutdown

After the final recorded take:

```bash
# Stop the admin dev server (Ctrl+C in tab 3)
# Stop the server             (Ctrl+C in tab 2)
# Optional — remove the demo database
rm -f /tmp/together-demo.db
```

The recorded file should be exported to `doc/Crit_D_Video.mp4` (same folder as the other criterion PDFs), matching the layout used by the official sample.

---

## Appendix — Accounts produced by the seeder

| Role | Email | Password | Group | Notes |
|---|---|---|---|---|
| Administrator | `admin@demo.ulink.local` | `DemoAdmin123!` | `admin` (god view) | Seeded with `allow_all_authorities=true`; sees every activity, every user, every export |
| Teacher 1–4 | `teacher01..teacher04@demo.ulink.local` | `DemoTeacher123!` | `teacher` | Can create activities, manage own activities' records, post in own channels; cannot view Users or Operations |
| Student 1–72 | `student001..student072@demo.ulink.local` | `DemoStudent123!` | `student` | Can browse, apply, chat in channels they belong to, view own records |

All emails, names, and classes are deterministic — the same seed value produces the same data, so the recorder can reference any student email between `student001` and `student072` with confidence that the account exists.
