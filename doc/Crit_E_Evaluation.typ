#set document(title: "Criterion E: Evaluation")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.98em, spacing: 1.8em, justify: true)
#set enum(spacing: 2em)

#import "@preview/wordometer:0.1.5": word-count, total-words

#let navy = rgb("#183153")
#let success-green = rgb("#2e7d32")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#show: word-count.with(exclude: (heading, figure, raw, <no-wc>))

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION E#text(weight: "regular")[: EVALUATION]]
]

#v(1em)

#emph[NOTE: Please refer to Appendix 2 (Feedback) for the transcript of the client's full impression --- comments, evaluations, and remarks --- of the final product.]

= Evaluation Against Success Criteria

#table(
  columns: (2.6fr, 2.8fr, 0.8fr),
  stroke: 0.5pt + luma(180),
  inset: 10pt,
  align: (x, y) => {
    if x == 2 { center + horizon } else { left + top }
  },
  fill: (x, y) => {
    if y == 0 { navy } else { white }
  },
  table.header(
    [#text(weight: "bold", fill: white)[SUCCESS CRITERIA]],
    [#text(weight: "bold", fill: white)[CLIENT REMARKS]],
    [#text(weight: "bold", fill: white)[STATUS]],
  ),
  [[1] Registration with school email, name, class, and avatar; passwords stored using bcrypt hashing.],
  [Registration worked with all required fields and avatar upload. Database inspection confirmed passwords were stored as bcrypt hashes, not plaintext.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/auth-preview-compact.png", width: 100%)],
  [#image("assets/auth-preview-compact.png", width: 100%)],
  [#image("assets/auth-preview-compact.png", width: 100%)],

  [[2] Authority-based access control distinguishes volunteers from organisers and administrators, so volunteers browse and apply, organisers create, manage, approve, and confirm activities, and administrators manage users, groups, and permissions through the web panel.],
  [Each access level showed distinct interfaces: students could only browse and apply, organisers could publish and confirm, and administrators could manage users and permissions through the web panel.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/manage-preview.png", width: 100%)],
  [#image("assets/manage-preview.png", width: 100%)],
  [#image("assets/manage-preview.png", width: 100%)],

  [[3] Organisers can publish activities with a title, date, location, capacity, duration, and description, and published activities appear in the volunteer feed.],
  [A test activity published with all required fields appeared immediately in the volunteer feed with correct details.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],

  [[4] Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.],
  [Editing location and time propagated correctly to enrolled volunteers. Cancellation updated the activity status consistently.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/admin-activities-viewport.png", width: 100%)],
  [#image("assets/admin-activities-viewport.png", width: 100%)],
  [#image("assets/admin-activities-viewport.png", width: 100%)],

  [[5] Volunteers can apply to activities, organisers approve or reject applications, and server-enforced capacity protection prevents overbooking under concurrent access.],
  [Application and approval worked as expected; full-capacity activities rejected further requests. Concurrent testing was limited to a small number of simultaneous requests, so capacity safety under heavy load has not been fully stress-tested.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/admin-activities-viewport.png", width: 100%)],
  [#image("assets/admin-activities-viewport.png", width: 100%)],
  [#image("assets/admin-activities-viewport.png", width: 100%)],

  [[6] Each activity has a scoped messaging channel where participants and the organiser can coordinate.],
  [Each activity had its own message thread, keeping logistics separate. However, there are no push notifications for new messages yet, so users must open the channel manually.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],

  [[7] Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.],
  [After an activity ended, the organiser confirmed attendees and their records moved to completed status with the correct duration stored.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/records-preview.png", width: 100%)],
  [#image("assets/records-preview.png", width: 100%)],
  [#image("assets/records-preview.png", width: 100%)],

  [[8] A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.],
  [The leaderboard ranking updated correctly as new hours were confirmed, reflecting actual participation records rather than a manually maintained total.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("assets/ipad-feed-landscape-final.png", width: 100%)],

  [[9] The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.],
  [The export produced a file matching the ISMAS column structure, replacing the manual copy-paste process.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/admin-operations-viewport.png", width: 100%)],
  [#image("assets/admin-operations-viewport.png", width: 100%)],
  [#image("assets/admin-operations-viewport.png", width: 100%)],

  [[10] The application runs on iPad with iPadOS 17+ in both portrait and landscape orientations, with no layout breakage or blocked controls.],
  [Both orientations were usable with no hidden controls. Portrait mode required more scrolling due to lower information density; the app is clearly optimised for landscape.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("assets/auth-preview-compact.png", width: 100%)],
  [#image("assets/auth-preview-compact.png", width: 100%)],
  [#image("assets/auth-preview-compact.png", width: 100%)],
)

= Recommendations for Future Improvements

#emph[NOTE: Please refer to Q6 of Appendix 2 (Feedback) for further information on the client's suggestions.]

1. #text(weight: "bold")[Automated activity reminders]

Adding reminder notifications before an activity starts would reduce the risk of students forgetting events they have already joined. The system already stores activity dates and participant records, so this extension is technically straightforward.

2. #text(weight: "bold")[Volunteer hour targets and progress tracking]

The system records confirmed hours but does not compare them against graduation or department targets. Configurable hour goals per student or year group would turn the records screen into a progress tracker and help staff identify students falling behind.

3. #text(weight: "bold")[Multi-language support]

The interface is currently in one language. Since the school includes English-speaking and Chinese-speaking users, adding localisation would improve accessibility. The existing component structure supports connecting a string-localisation layer without redesign.

4. #text(weight: "bold")[School calendar integration]

Integrating with the school calendar would reduce timetable clashes and surface activities in students' normal planning workflow, building directly on the existing activity date model.

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
