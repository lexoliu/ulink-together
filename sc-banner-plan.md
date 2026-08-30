# SC Banner Plan for Criterion D Video

> **Purpose.** This document is fed to a separate AI that will generate
> on-screen banner overlays for the Criterion D video. Each banner labels
> the Success Criterion (SC) being demonstrated in that segment of the
> video, so the IB moderator can walk through all ten SCs without the
> narrator naming them aloud.
>
> **Status.** The video is **locked**. Do not edit the cuts, the audio,
> or the subtitles — only overlay banners. The subtitles quoted here
> are ground truth.

---

## 1. Video facts

| Field | Value |
|---|---|
| File | `doc/Crit_D_Functionality.mp4` (final) |
| Target length | ≈ 7 minutes |
| Subtitle track | Burned-in; see subtitle list in §5 |
| Language | English |
| UI captured | SwiftUI iPad client (student) + React admin panel (teacher / administrator) |
| Demo users in video | Lexi Liu (student), Jamie Wu (teacher), Rachel Ho (administrator) — all seeded demo data, not the candidate |

---

## 2. The ten Success Criteria (exact wording, locked)

This is the final wording from `doc/Crit_A_Planning.typ`. The banner
should show a **short tag** (column 2) that fits on one line, not the
full sentence; the full text is provided only so the banner generator
can choose a faithful abbreviation.

| # | Banner short tag (≤ 6 words) | Full SC wording |
|:-:|---|---|
| 1 | **SC1 · Account Registration + bcrypt** | Volunteers and organisers register with school email, name, class, and an avatar; passwords are stored using bcrypt hashing rather than plaintext. |
| 2 | **SC2 · Authority-based Role Separation** | Authority-based access control separates students, teachers, and administrators; administrators additionally manage users in batch and rename cohorts for year-end promotion, while teachers cannot manage users. |
| 3 | **SC3 · Publish & Browse Feed** | Organisers publish activities with name, date, location, duration, and capacity; volunteers browse and search the unified feed. |
| 4 | **SC4 · Activity Lifecycle States** | Organisers transition activities through the lifecycle states recruiting, ongoing, completed, and cancelled; state changes propagate to enrolled volunteers. |
| 5 | **SC5 · Apply, Withdraw, Capacity-safe** | Volunteers apply and may withdraw; organisers approve or reject applications; the server enforces capacity protection under concurrent access so an activity cannot be overbooked. |
| 6 | **SC6 · Scoped Chat + Auto-archive** | Each activity has a scoped chat channel; once the activity ends the channel auto-archives and rejects further messages. |
| 7 | **SC7 · Confirm Minutes on Record** | Organisers confirm participation minutes after an activity completes; confirmed hours are written back to the student record in real time. |
| 8 | **SC8 · Leaderboard from Confirmed Hours** | A leaderboard ranks volunteers by total confirmed hours, derived from participation records rather than an editable stored total. |
| 9 | **SC9 · ISMAS CSV Export** | Confirmed-hours data exports as an ISMAS-compatible CSV spreadsheet, available globally from the admin dashboard and per-activity from the activity workspace. |
| 10 | **SC10 · Landscape-only iPad** | The iPad client runs in landscape orientation only: portrait is refused so every screen is tuned for one wide aspect ratio. |

---

## 3. Banner style specification (recommended defaults)

| Property | Value |
|---|---|
| Position | Top-left, 24 px padding from edges |
| Size | Up to 30 % of video width; single line |
| Background | Solid navy `#183153`, 90 % opacity |
| Text colour | White `#ffffff`, bold, 22–28 px sans-serif |
| Corner radius | 8 px |
| Entrance | Fade-in over 250 ms |
| Exit | Fade-out over 250 ms |
| Minimum dwell | 2.5 s (so the moderator can read it) |
| Maximum dwell | 8 s per appearance (re-trigger if the SC returns later) |
| Overlap with subtitles | Subtitles are burned into the lower third; the banner stays in the upper region and must not collide |
| When multiple SCs co-occur | Show them stacked vertically (SCn on top, SCm below), same style |

A secondary banner style (smaller, `#e65100` amber) should be used for
the two "feature shown but not an SC" segments flagged in §5 — see the
rows tagged **BONUS** and **GAP**.

### 3.1 Opening technology-stack bumper (exactly one cue, at 00:00–00:05)

At the very start of the video, show a single overview banner that
names the tech stack. This is **not** an SC banner and must **not** be
repeated. Its purpose is purely to tell the moderator what they are
about to see. It must disappear before the first SC banner begins.

```
{
  "start": "00:00:00",
  "end":   "00:00:05",
  "banner_text": "Stack: SwiftUI iPad · React Admin · Rust · PostgreSQL",
  "style": "primary"
}
```

After 00:05 the SC banners take over. Do not reuse this text anywhere
else in the video — the technical details belong to Criterion C
(documentation), not Criterion D (functionality demonstration).

---

## 4. Subtitle → SC mapping cheat sheet

This is the primary input to the banner generator. Each row is one
subtitle cue from the locked video.

Legend for **SC-tags**:
- `SC1`–`SC10` = show the corresponding primary SC banner
- `BONUS: Comments` = non-SC feature (activity comments / public notes); show amber "Bonus feature" banner, no SC number
- `GAP: Login error banner` = UX defect intentionally visible on screen; show amber "Known issue — see Crit E Rec 6" banner
- `TRANSITION` = no banner (ambient narration, sign-in / sign-out, role switch, etc.)

| # | Start | End | Subtitle quoted (abridged) | SC-tags |
|:-:|:-----:|:---:|---|---|
| 1 | 00:00 | 00:24 | Create a brand new account ... enter own email ... | **SC1** |
| 2 | 00:24 | 00:34 | Use that real photo here but now ... random photo | **SC1** (avatar sub-feature) |
| 3 | 00:34 | 00:46 | Here is the explore sections ... search activity by the search bar ... sports day | **SC3** |
| 4 | 00:46 | 00:57 | Students have to apply for a particular activity by clicking the apply button | **SC5** (apply) |
| 5 | 00:57 | 01:08 | They can withdraw an application at any time ... my activities section | **SC5** (withdraw) |
| 6 | 01:08 | 01:23 | They can leave some public notes to ask a question | **BONUS: Public notes** |
| 7 | 01:23 | 01:39 | Leaderboard ... ranked by volunteer hours | **SC8** |
| 8 | 01:39 | 01:43 | Let's take a tab again with the proper password | **GAP: Login error banner** (demonstrates the defect noted in Crit E Recommendation 6) |
| 9 | 01:43 | 01:47 | Now yes we are in | TRANSITION |
| 10 | 01:47 | 01:56 | Dashboard ... activities which is ongoing will be highlighted | **SC2** (admin dashboard scope) |
| 11 | 01:56 | 02:07 | Preview the detail of each activity or export some data here | **SC9** (admin global export entry) |
| 12 | 02:07 | 02:12 | The data can be copied as a CSV format or be downloaded directly | **SC9** |
| 13 | 02:12 | 02:21 | Teacher and advisor can input it to the iSam (ISMAS) system later | **SC9** |
| 14 | 02:21 | 02:41 | Chat ... inactive activity will be archived ... cannot send any message | **SC6** (auto-archive) |
| 15 | 02:41 | 02:45 | For the active activity you can just say something here | **SC6** (scoped messaging) |
| 16 | 02:45 | 02:48 | Hi there, I just sent recently | **SC6** (scoped messaging, cont.) |
| 17 | 02:48 | 03:00 | As an advisor you have the permission to create students or teachers | **SC2** (admin-only user management) |
| 18 | 03:00 | 03:17 | Input user from a spreadsheet ... batch | **SC2** (batch import) |
| 19 | 03:17 | 03:34 | Rename a class ... students upgrade to a new grade | **SC2** (cohort rename) |
| 20 | 03:34 | 03:38 | Clicking this account, you can sign out | TRANSITION |
| 21 | 03:38 | 03:46 | Move on to the perspective of the normal teacher | TRANSITION |
| 22 | 03:46 | 03:59 | Teacher will have a different account ... system will automatically detect the role | **SC2** (role separation) |
| 23 | 03:59 | 04:09 | Sorry, I entered wrong again. Let me check it | **GAP: Login error banner** (second occurrence of the same defect) |
| 24 | 04:09 | 04:11 | Yeah, I'm in | TRANSITION |
| 25 | 04:11 | 04:20 | As a teacher, you just cannot add a new student or teachers | **SC2** (teacher scope limited) |
| 26 | 04:20 | 04:29 | Teacher can create a new activity in their own dashboard | **SC3** (publish) |
| 27 | 04:29 | 04:34 | Give the activity a unique name, for instance, go grass | **SC3** (publish fields) |
| 28 | 04:34 | 04:48 | It may be out of school, 120 minute duration ... happen on today | **SC3** (publish fields) |
| 29 | 04:48 | 04:58 | Let me give a random time | **SC3** (publish fields) |
| 30 | 04:58 | 05:05 | The activity is just created, and the student can see it here | **SC3** (feed propagation) |
| 31 | 05:05 | 05:22 | Teacher are also enabled to export each activity's detail to a spreadsheet | **SC9** (per-activity export) |
| 32 | 05:22 | 05:38 | Teacher can send some message here to notify their own students | **SC6** |
| 33 | 05:38 | 05:48 | Show the whole process that student apply ... state of this student will be changed | **SC4** + **SC5** + **SC7** (intro card) |
| 34 | 05:48 | 05:55 | My own activity Go grass, I created | TRANSITION |
| 35 | 05:55 | 05:58 | Just refresh | TRANSITION |
| 36 | 05:58 | 06:07 | Let me start this activity and approve the volunteer | **SC4** (recruiting → ongoing) + **SC5** (approve) |
| 37 | 06:07 | 06:12 | The record has been approved | **SC5** |
| 38 | 06:12 | 06:20 | Mark the whole activity as complete here | **SC4** (ongoing → completed) |
| 39 | 06:20 | 06:29 | Confirm how many minute he really finished | **SC7** |
| 40 | 06:29 | 06:34 | Back to the student site here | TRANSITION |
| 41 | 06:34 | 06:45 | Student will find that the whole activity have been finished ... activity time here | **SC7** (student record updated) |
| 42 | 06:45 | 06:52 | Completed part, the hour have been confirmed by the teacher | **SC7** + **SC8** (hours feed leaderboard) |
| 43 | 06:52 | 06:57 | Team chat will be unavailable since the activity have been finished | **SC6** (auto-archive, second demonstration) |

### SC-10 (Landscape-only iPad)

Never called out by the narrator, because the iPad captures are
themselves landscape. Show **SC10 · Landscape-only iPad** as a
one-shot banner at a moment when the iPad is on screen — recommended
around **01:25 (Leaderboard, full landscape split view)** or at video
open. Do not show it while the admin panel is on screen (that's
browser-based and orientation does not apply).

---

## 5. Coverage summary (sanity check for the banner AI)

| SC | At least one banner placement in video? | Primary segments |
|:--:|:---:|---|
| SC1 | ✓ | 1–2 |
| SC2 | ✓ | 10, 17, 18, 19, 22, 25 |
| SC3 | ✓ | 3, 26–30 |
| SC4 | ✓ | 33, 36, 38 |
| SC5 | ✓ | 4, 5, 33, 36, 37 |
| SC6 | ✓ | 14, 15, 16, 32, 43 |
| SC7 | ✓ | 33, 39, 41, 42 |
| SC8 | ✓ | 7, 42 |
| SC9 | ✓ | 11, 12, 13, 31 |
| SC10 | ✓ | one placement (recommended at the leaderboard or opening iPad shot) |

Every SC has at least one banner placement; the banner AI should
**not** invent placements not anchored to a subtitle row unless it is
the SC-10 landscape shot noted above.

---

## 6. What NOT to banner

- Do not put SC banners over the login-error-banner segments (rows 8
  and 23). Those demonstrate a known UX gap discussed in Crit E
  Recommendation 6 and should use the amber **GAP** banner only.
- Do not put an SC banner over the activity-comments / public-notes
  segment (row 6). That feature is not part of the ten SCs. Use the
  amber **BONUS: Public notes** banner only.
- Do not banner the transitional cues (rows 9, 20, 21, 24, 34, 35,
  40). These are sign-in / sign-out / switching-accounts moments with
  no SC content.

---

## 7. Output contract expected from the banner AI

The banner AI must emit, in order:

1. **One** opening technology-stack bumper cue at 00:00–00:05 (see §3.1).
2. **One or more** SC / BONUS / GAP cues mapped from §4, one cue per row
   that has a tag (not for TRANSITION rows).
3. A separate **SC10** cue around 01:25–01:33 while the iPad leaderboard
   is on screen (see §4, SC-10 section).

Each cue has the shape:

```
{
  "start": "00:00:00",
  "end":   "00:00:24",
  "banner_text": "SC1 · Account Registration + bcrypt",
  "style": "primary"   // or "bonus" or "gap"
}
```

A single subtitle row may produce more than one cue (e.g. row 33
emits three stacked cues for SC4+SC5+SC7). Stacked cues should share
the same `start` and `end` and render on separate rows.

**Do NOT invent extra banners for technical details (bcrypt,
transactions, SSE, etc.).** Those belong to Criterion C documentation,
not the Criterion D video. The IB handbook (p19) explicitly says the
video must stick to functionality and not document the development
process. The opening bumper in step 1 is the only exception.

---

## 8. Reference files

All in the submission package, for cross-reference:

- `doc/Crit_A_Planning.typ` — full SC wording, authoritative.
- `doc/Crit_B_Design.typ` — test plan with SC-indexed test cases.
- `doc/Crit_E_Evaluation.typ` — SC evaluation table, one row per SC.
- `doc/Appendix_2_Feedback.typ` — client's SC-by-SC confirmation (Q3, Q4, Q6).
- `doc/Crit_D_Functionality.mp4` — the locked video.
