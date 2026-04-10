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
| `DEMO_ADMIN_PASSWORD` | `DemoAdmin123!` | Password for the administrator account (`rachel.ho@ulink.cn`) |
| `DEMO_TEACHER_PASSWORD` | `DemoTeacher123!` | Password for every seeded teacher (Jamie Wu, Daniel Chen, Sophie Lin, Marcus Zhang) |
| `DEMO_STUDENT_PASSWORD` | `DemoStudent123!` | Password for every seeded student (firstname.familyname@ulink.cn) |
| `DEMO_SEED` | `20260317` | RNG seed — keeps the data identical between runs |

The script always passes `--reset`, so it is safe to run as many times as you need between takes.

### What the seeder prints

At the end of the run the seeder logs credentials that the script expects to be in the database:

```
 INFO Demo database initialized
 INFO Teachers: 4, students: 72, activities: 25, records: 233, comments: 96, messages: 192
 INFO Activity states -> recruiting: 9, going: 4, ended: 8, canceled: 4
 INFO Admin login:   rachel.ho@ulink.cn / DemoAdmin123!
 INFO Teacher login: jamie.wu@ulink.cn / DemoTeacher123!
 INFO Student login: alex.chen@ulink.cn / DemoStudent123!
```

Keep this terminal output **off screen** during recording — the IBDP evaluator should see the app behaving like a deployed product, not a demo seed log. The three logins above are the only accounts the script uses on camera.

> The activity count is 25 rather than `teacher_count × activities_per_teacher` because the seeder adds one extra full-capacity activity called "Library Reshelving Day" filled to 12 of 12 slots. Section 4 of the video script relies on this exact state so that the very next apply is rejected by the server's `volunteer_num >= max_volunteer_num` guard. The activity name and description are intentionally plain so that the recording looks like a real library volunteering session.

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
- 25 activities (24 regular + 1 full-capacity activity)
- 233 records
- `Library Reshelving Day|12/12`

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
  -d '{"email":"rachel.ho@ulink.cn","password":"DemoAdmin123!"}' -i | head -20
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

Open `http://localhost:5173/` in Chrome. You should see the login page. Sign in as `rachel.ho@ulink.cn` / `DemoAdmin123!` and verify the dashboard shows 9 recruiting / 4 in progress / 8 completed. Sign out before you start recording so your first frame is the login screen.

---

## 5. Launch the SwiftUI iPad app as a pre-deployed product

IBDP requires a realistic demonstration — a real student at Ulink would never type a server URL. The app must look and feel as if it was already deployed to a school-managed iPad, even though the "school server" is actually your local `127.0.0.1:8080`.

To make this work, `AppEnvironment.bundledServerURL()` checks `ProcessInfo.processInfo.environment["TOGETHER_API_BASE_URL"]`. When Xcode launches the app with that variable set, the app reads it on launch, `hasBundledServerURL` returns `true`, and the auth screen skips the "Enter service address" step entirely — the first frame is the sign-in form, exactly as a deployed product would behave.

### Set the scheme environment variable (one-time)

1. Open the Xcode project:
   ```bash
   open ~/Coding/ulink-together/swiftui/together.xcodeproj
   ```
2. **Product → Scheme → Edit Scheme…** (⌘<).
3. Left sidebar: **Run**.
4. Top tabs: **Arguments**.
5. Under **Environment Variables**, click **+** and add:
   - Name: `TOGETHER_API_BASE_URL`
   - Value: `http://127.0.0.1:8080`
6. Make sure the checkbox next to the row is **ticked** — unchecked rows are ignored.
7. Click **Close**.

### Launch

Destination: **iPad Pro 13-inch** simulator (M5 or M4, either works). Press **Run** (⌘R).

The simulator boots, the app launches, and the first frame is the sign-in form — no "Enter service address" step.

### Smoke-test

Sign in as `alex.chen@ulink.cn` / `DemoStudent123!`. Pull-to-refresh the Explore tab — seeded activities should appear. Sign out so your first recorded frame is the auth screen.

If you still see the "Service address" field, the scheme env var did not stick. Stop the simulator (⌘.), re-open **Edit Scheme**, verify the checkbox is ticked, and press Run again — Xcode reads the scheme at launch time, not at edit time.

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
| iPad app opens with the "Enter service address" field | The scheme environment variable `TOGETHER_API_BASE_URL` was never set, or Xcode cached an older scheme where it was missing | Edit Scheme → Run → Arguments → Environment Variables, ensure `TOGETHER_API_BASE_URL` is set to `http://127.0.0.1:8080` **and the checkbox next to the row is ticked**. Stop the simulator (⌘.) and press Run again — Xcode re-reads the scheme at launch, not at edit time. |
| iPad app shows `Could not reach the service` | Server not running on the expected port or using IPv6 loopback | Verify with `curl http://127.0.0.1:8080/api/v1/health`; if the server is bound to `::1` use `http://[::1]:8080` instead |
| `student001` has no activities in Explore | Seed database used but server is pointing at a different SQLite file | Double-check `--db` argument matches `DEMO_DATABASE_URL` |
| Capacity protection demo fails — apply silently succeeds past 12/12 | You forgot to re-seed between rehearsals, so the seeded activity is already in a different state | Run `scripts/init-demo.sh` again |
| Teacher sees the Users tab in the sidebar | You logged in with the admin account by mistake | Sign out, sign back in with `jamie.wu@ulink.cn` |
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

Every seeded account uses the `@ulink.cn` domain so the demonstration looks like a deployed Ulink College product. Passwords are still the fixed `Demo*` strings because the seeder needs reproducible credentials — but the passwords should never be visible on camera during the video (the recorder types them into the password field).

### Administrator

| Email | Name | Password | Notes |
|---|---|---|---|
| `rachel.ho@ulink.cn` | Rachel Ho | `DemoAdmin123!` | Head of A-level Department. Seeded in the `admin` group with `allow_all_authorities=true`; sees every activity, every user, and every export. |

### Teachers

| Email | Name | Title / Classname | Notes |
|---|---|---|---|
| `jamie.wu@ulink.cn` | Jamie Wu | Head of Community Service | Used in the video as the principal organiser for Sections 3–5 |
| `daniel.chen@ulink.cn` | Daniel Chen | Science Faculty | Second teacher for multi-organiser shots |
| `sophie.lin@ulink.cn` | Sophie Lin | Performing Arts Faculty | |
| `marcus.zhang@ulink.cn` | Marcus Zhang | Sports Faculty & Duke of Edinburgh Lead | |

All four teachers share the password `DemoTeacher123!` and belong to the `teacher` group. They can create activities, manage their own activities' records, and post in their own channels; they cannot view the Users or Operations pages.

### Students

| Email pattern | Count | Notes |
|---|---|---|
| `firstname.familyname@ulink.cn` (with `firstname.familyname2@...` when names collide) | 72 | Cycle of 12 first names × 12 family names × 8 classrooms; `DemoStudent123!` password; belong to the `student` group. |

Example student emails produced by the deterministic seed (`DEMO_SEED=20260317`):

- `alex.chen@ulink.cn` (class 10A)
- `jamie.chen@ulink.cn` (class 10B)
- `taylor.chen@ulink.cn` (class 10C)
- `quinn.liu@ulink.cn` (class 12B)

To check which students are actually in the pre-filled capacity activity (and therefore unavailable for the "activity is full" demo in Section 4):

```bash
sqlite3 /tmp/together-demo.db \
  "SELECT u.email FROM records r JOIN users u ON u.id=r.user_id \
   JOIN activities a ON a.id=r.activity_id \
   WHERE a.name='Library Reshelving Day' ORDER BY u.email;"
```

Pick any student email **not** in that list to record the capacity rejection — `alex.chen@ulink.cn` is reliably available under the default seed.
