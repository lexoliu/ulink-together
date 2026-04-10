# Criterion D Video Script

**Target length:** 6 minutes 30 seconds (hard cap: 7 minutes per IBDP rules)
**Environment:** see `RECORDING.md` at the repo root for the full pre-recording checklist. **Never** start recording from a blank database — every section below assumes the demo seed has already been applied and the listed accounts exist.

## IBDP Criterion D rules this script follows

1. The video must demonstrate the **finished product**, not partial builds or prototype shots.
2. Every success criterion from `Crit_A_Planning.typ` must be visibly exercised, not merely mentioned.
3. All interactions must run against real data: applying to an activity creates a real record, sending a message updates the real database, the export dialog writes a real CSV.
4. The narration explains **what the viewer is seeing and why it matters**, not just the name of the feature.
5. Nothing on screen is allowed to be a static mockup or an unreachable placeholder.

## Recording rules

- Record only the finished product against a server that is running against the seeded demo database.
- Start every take from a known clean state by re-running `scripts/init-demo.sh` (see `RECORDING.md`).
- Cut long loading spinners and typing pauses in post; keep cursor movements deliberate and unhurried.
- Use a single microphone take if possible; re-record only the clip where a misreading occurred.
- Before each take confirm the three fixed windows are visible: (a) iPad simulator, (b) Chrome with the admin panel, (c) Terminal/Finder showing the exported CSV when it is needed in Section 10.

---

## 0. Pre-roll checklist (not on camera, ~1 minute before recording)

Run through everything in `RECORDING.md` §1–§4:

- `scripts/init-demo.sh` has been executed against `/tmp/together-demo.db` (or your chosen path) since the last take.
- `cargo run --bin together-server -- --db sqlite:///tmp/together-demo.db --port 8080` is listening on `127.0.0.1:8080`.
- Admin dev server is running: `BACKEND_TARGET=http://127.0.0.1:8080 bun run dev` in `admin/`, served on `http://localhost:5173`.
- iPad simulator (iPad Pro 13-inch) is booted and `together.app` is installed.
- Chrome window is already signed **out** of the admin panel so the first recorded frame shows the login page.
- QuickTime / OBS is recording both the iPad simulator and the Chrome window (1440×900 minimum).

---

## Opening (0:00–0:20)

**Show:** iPad simulator home screen → tap `together.app` to launch. The app resolves its bundled server URL automatically (see `TOGETHER_API_BASE_URL` in `RECORDING.md` §3).

**Say:**
> This video demonstrates the finished volunteer management system for Ulink College of Shanghai. Every action shown runs against the real Rust server and SQLite database seeded with four teachers, seventy-two students, and twenty-four activities across the recruiting, in-progress, ended, and cancelled lifecycle states. I will walk through each success criterion from Criterion A in order, using three accounts: an administrator for god-view capabilities, a teacher for organiser workflows, and a student for volunteer workflows.

---

## 1. Registration and login — SC-1 (0:20–0:55)

**Show:**

1. From the iPad auth screen, tap **Create account**.
2. Fill the registration form with a brand-new email (`demo.recorder@demo.ulink.local`), real name, class 12A, gender, password `DemoRecorder123!`.
3. Submit. The app signs the new account in automatically.
4. Cut to the organiser Mac, open a terminal, and run `sqlite3 /tmp/together-demo.db "SELECT email, substr(password_hash,1,20) FROM users WHERE email='demo.recorder@demo.ulink.local';"` — the result shows a `$2b$12$` bcrypt prefix, never the plaintext password.
5. Sign back out from the new account.

**Say:**
> The system asks each user to register with their school email, real name, class, and a password. The password never reaches the database as plain text — as the terminal query shows, it is stored as a bcrypt hash starting with dollar-two-b, which was the first client requirement.

---

## 2. Authority-based access control — SC-2 (0:55–1:45)

**Show (fast cuts, ~15 s each):**

1. Sign into the iPad app as `student001@demo.ulink.local` / `DemoStudent123!`. Show the student tab bar: Explore, Records, Notifications, Leaderboard, Account. Note that there is no Manage tab.
2. Cut to Chrome, sign into the admin panel as `teacher01@demo.ulink.local` / `DemoTeacher123!`. Show the sidebar with only three items: Home, Activities, Chats. Confirm Users and Operations are hidden — teachers cannot manage users.
3. Sign out. Sign back in as `admin@demo.ulink.local` / `DemoAdmin123!`. The sidebar now has five items (Home, Activities, Chats, Users, Operations). Hover the home stats: 8 recruiting, 4 in progress, 8 completed — the admin sees every teacher's activities.
4. Click **Users**, then **Create User**, switch the group dropdown to **teacher**, and show the form so the evaluator sees the admin can provision new teachers and students at runtime.

**Say:**
> Authority-based access control is enforced on the server. Volunteers see only browsing and records tabs, teachers see activity management but no user administration, and only administrators can open the Users and Operations screens or create new accounts. Menu items the current user cannot actually use are never rendered, so the interface itself reflects their permissions.

---

## 3. Activity publication and state propagation — SC-3, SC-4 (1:45–2:30)

**Show:**

1. Back in Chrome as `teacher01@demo.ulink.local`, click **Activities → New activity**.
2. Fill: name `Book Fair Volunteer Support`, date two weeks in the future at 14:00, location `Learning Commons`, capacity 12, duration 120 minutes, brief description, full description.
3. Submit. The activity appears in the admin panel list.
4. Cut to the iPad — pull-to-refresh the Explore tab. The new activity appears in the feed with the `Recruiting` chip, correct date, location, and capacity.
5. Go back to the admin panel, open the new activity, edit the location to `Main Library Atrium`, save.
6. Switch to the iPad again — reopen the activity. The new location is reflected.

**Say:**
> Organisers publish activities through a structured form with all the fields the client listed in Appendix 1. As soon as the activity is created on the server, the iPad feed shows it on the next refresh, and edits made on the admin panel propagate in the same way. This replaces the scattered email and WeChat announcements the deputy head described before.

---

## 4. Apply → Approve → Capacity protection — SC-5 (2:30–3:30)

**Show:**

1. On the iPad, still signed in as `student001`, open the new `Book Fair Volunteer Support` activity and tap **Apply**. The state chip changes to `Pending Approval`.
2. Switch to the admin panel, open the same activity, Records tab, approve `student001`. The state chip updates live — no manual refresh.
3. Now demonstrate the capacity rule using the dedicated seeded activity. Sign into the iPad as a student who is **not** one of the twelve pre-enrolled students (the deterministic seed with `DEMO_SEED=20260317` leaves every `student0NN` outside the selection; `student072@demo.ulink.local` is a safe choice). Open `Library Reshelving Marathon (Capacity Demo)` from the Explore feed — the card displays 12/12.
4. Tap **Apply**. The app displays a clear "The activity needn't more people" error banner and no new record is created. Cut to a terminal tab and run `sqlite3 /tmp/together-demo.db "SELECT volunteer_num, max_volunteer_num FROM activities WHERE name LIKE '%Capacity Demo%';"` to prove the count remains exactly 12/12 — the server refused the request before any insert happened.

**Say:**
> Students apply to activities from the detail page, and the organiser either approves or rejects the application. The fifth success criterion also requires that a capacity limit cannot be exceeded. The server enforces this inside a transaction: the apply endpoint first opens a BEGIN IMMEDIATE transaction against SQLite, reads the current volunteer count and maximum together, and only then tries to insert the new record. Because the seeded activity is already at twelve of twelve, the comparison fails and the server returns a 403 with an "activity is full" message, as the terminal query confirms immediately afterwards.

---

## 5. Activity-scoped messaging and live delivery — SC-6 (3:30–4:15)

**Show:**

1. Keep the iPad signed in as an approved volunteer for a seeded `Going` activity (e.g. `Campus Sustainability Workshop Session 03`). Open the activity and tap **Team Chat**. The Discord-style channel opens with existing messages grouped by sender and teacher badges on organiser posts.
2. Type `Heading to the courtyard now, meet at the south gate.` and send.
3. Cut to the admin panel Chats tab signed in as the teacher who owns that activity. The new message appears at the bottom of the timeline without the teacher clicking refresh — SSE push delivered it.
4. The teacher replies `Great, see you all at 14:10`. Cut back to the iPad: the reply appears instantly, with a Teacher badge next to the name.

**Say:**
> Every activity has one shared chat channel that is created together with the activity and kept bound to it. Messages are delivered in real time through server-sent events, so both the volunteer on the iPad and the organiser on the admin panel see the same conversation as it happens, and messages from the activity's organiser are visually marked as teacher posts. This replaces the fragmented personal chats that used to scatter logistics information across multiple apps.

---

## 6. System notifications — bonus, extensibility (4:15–4:40)

**Show:**

1. On the iPad, switch to the Notifications tab. Two notifications are already waiting from the previous section: the teacher's reply and the activity state change. Each row shows an icon, a headline, a preview, and a timestamp.
2. Tap the teacher's reply notification. The app navigates into the activity detail for that activity.
3. Go back, swipe a notification to mark it read.
4. Open Account → Notifications. Toggle off `Teacher posts` to demonstrate the per-type opt-out.

**Say:**
> Beyond the ten success criteria, the system also raises automatic notifications whenever a channel message is posted, an activity changes state, or one of the volunteer's records is updated. Notifications are delivered through the same push stream as channel messages, can be tapped to navigate to the relevant activity, and can be turned off per type from the account screen.

---

## 7. Hour confirmation and records — SC-7 (4:40–5:10)

**Show:**

1. Admin panel as teacher. Open one of the seeded `Ended` activities that still has unconfirmed records.
2. Records tab. Click **Confirm** on one pending row — an inline number input appears preloaded with the activity's scheduled duration. Adjust it to 150 minutes to reflect a student who stayed longer, confirm.
3. Cut to the iPad. Sign in as that student. Open the Records tab. The activity row now shows the `Confirmed` chip and `2h 30m`.

**Say:**
> After an activity ends the teacher confirms each volunteer's actual hours from the Records tab. The confirmation UI defaults to the scheduled duration but can be adjusted — here we credit a student who stayed thirty minutes longer. The new minutes are immediately reflected on the volunteer's own records screen on the iPad, because both views read from the same database.

---

## 8. Leaderboard — SC-8 (5:10–5:30)

**Show:**

1. Switch the iPad to the Leaderboard tab. Top three appear on a podium with medal colours, and the remaining ranks flow beneath as a native list. Scroll down once. Your own row (if applicable) is highlighted with the accent tint.
2. Briefly pause on the top three and then scroll back to the top.

**Say:**
> The leaderboard ranks volunteers by confirmed hours only — applications that are still pending or approved but not yet confirmed do not contribute. The ranking is computed from the `records` table rather than stored manually, so it stays consistent with the data that the teacher just confirmed.

---

## 9. ISMAS-compatible export — SC-9 (5:30–6:00)

**Show:**

1. Admin panel, signed in as admin (god view). Click **Export Hours** from the home quick actions.
2. An export dialog appears with a preview of the generated rows and a **Download** button.
3. Click Download. The file saves to the Desktop as `volunteer-hours-<uuid>.csv`.
4. In Finder, open the CSV with Numbers (or a plain text viewer). Show the header row: `student_identifier, student_name, class_name, activity_title, activity_date, confirmed_minutes, organiser_confirmation_timestamp`. Scroll a couple of rows to show real student data from the seed.

**Say:**
> At the end of a reporting window the administrator triggers the export. The server reads every record in the confirmed state, denormalises student and activity details, and writes a CSV whose column order matches the school's existing ISMAS import template. The evaluator can see the downloaded file on screen, ready to be imported into ISMAS without any manual reformatting.

---

## 10. Platform compatibility — SC-10 (6:00–6:15)

**Show:**

1. Back on the iPad Explore tab. Rotate the simulator from landscape to portrait (Command+Right Arrow). The NavigationSplitView collapses to a single pane without cropping any buttons.
2. Open an activity detail, rotate back to landscape — the split view restores. Scroll the detail view to show no elements are cut off.

**Say:**
> The app supports both iPad orientations. The feed uses a split view in landscape and collapses to a single column in portrait, and every button remains fully visible and tappable when the device rotates mid-session.

---

## Closing (6:15–6:30)

**Show:** Return to the admin panel home with stats visible.

**Say:**
> The finished product centralises announcements, applications, messaging, hour tracking, and reporting onto one server with typed SwiftUI and React clients, directly addressing the fragmented workflow described by the client in Appendix 1.

---

## Post-production checklist

- [ ] Verify total length is ≤ 6 minutes 45 seconds after cuts (target 6:30; hard cap 7:00).
- [ ] Every visible account email ends in `@demo.ulink.local` — no real student names.
- [ ] Terminal SQL snippets are legible at 1080p.
- [ ] Narration audio is normalised, no clipping.
- [ ] Export CSV open-in-Numbers frame shows the ISMAS header row clearly for at least 2 seconds.
- [ ] Final file name: `Crit_D_Video.mp4`.
- [ ] Place the file in `doc/` alongside the other criterion PDFs.

---

## Optional editing notes

- If a section runs long, prefer cutting transitional loading frames before cutting demonstrated behaviour. The IBDP evaluator needs to *see* each success criterion exercised; they do not need to watch you navigate between tabs.
- If capacity protection (Section 4) cannot be recorded on the first take because the seed has changed, re-run `scripts/init-demo.sh` to reset the database. Do not hand-edit rows.
- Never hide an error dialog in post. If the server rejects a request, include the error so the evaluator sees the server-side validation working.
