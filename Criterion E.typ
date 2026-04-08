#set document(title: "Criterion E: Evaluation")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.4em, justify: true)
#set enum(spacing: 2em)

#let navy = rgb("#183153")
#let success-green = rgb("#2e7d32")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

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
  [Accounts were registered with the required fields during testing, and profile pictures could be added without difficulty. When the database records were inspected, passwords appeared as hashed values rather than plaintext, which met the security expectation.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/auth-preview-compact.png", width: 100%)],
  [#image("design/assets/auth-preview-compact.png", width: 100%)],
  [#image("design/assets/auth-preview-compact.png", width: 100%)],

  [[2] Authority-based access control distinguishes volunteers from organisers and administrators, so volunteers browse and apply, organisers create, manage, approve, and confirm activities, and administrators manage users, groups, and permissions through the web panel.],
  [The three access levels produced distinct interfaces throughout the trial. Student accounts were limited to browsing and applying, organiser accounts could publish activities, review applications, and confirm attendance, and the administrator account could manage users and group permissions through the web panel. The separation of responsibilities was clear.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/manage-preview.png", width: 100%)],
  [#image("design/assets/manage-preview.png", width: 100%)],
  [#image("design/assets/manage-preview.png", width: 100%)],

  [[3] Organisers can publish activities with a title, date, location, capacity, duration, and description, and published activities appear in the volunteer feed.],
  [When I created a test activity, the form required all of the expected details, including date, venue, duration, and capacity. After publishing it, the activity appeared immediately in the volunteer feed with the same information visible to students.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],

  [[4] Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.],
  [I changed the location and start time of an existing activity and the updated details were reflected correctly for the students who had already applied. I also tested cancellation, and the activity status was updated consistently instead of leaving volunteers with outdated information.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/admin-activities-viewport.png", width: 100%)],
  [#image("design/assets/admin-activities-viewport.png", width: 100%)],
  [#image("design/assets/admin-activities-viewport.png", width: 100%)],

  [[5] Volunteers can apply to activities, organisers approve or reject applications, and server-enforced capacity protection prevents overbooking under concurrent access.],
  [The application and approval workflow behaved as expected: students could submit requests and organisers could approve or reject them individually. When I tried to apply for an activity that was already full, the system rejected the request immediately, and simultaneous test applications did not produce any overbooking.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/admin-activities-viewport.png", width: 100%)],
  [#image("design/assets/admin-activities-viewport.png", width: 100%)],
  [#image("design/assets/admin-activities-viewport.png", width: 100%)],

  [[6] Each activity has a scoped messaging channel where participants and the organiser can coordinate.],
  [Each activity included its own message thread, which kept logistics separate from other events. During testing, participants and the organiser were able to exchange updates in one place, making the communication record much easier to follow than scattered private chats.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],

  [[7] Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.],
  [After a test activity ended, I was able to mark the students who attended as confirmed participants. Their records changed to completed status, which matched the intended process for validating attendance before hours are counted.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/records-preview.png", width: 100%)],
  [#image("design/assets/records-preview.png", width: 100%)],
  [#image("design/assets/records-preview.png", width: 100%)],

  [[8] A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.],
  [The leaderboard updated in line with the hours confirmed through completed activities, and the ordering changed correctly after additional attendance was confirmed. This showed that the ranking reflects actual participation records instead of relying on a manually maintained total.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],
  [#image("design/assets/ipad-feed-landscape-final.png", width: 100%)],

  [[9] The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.],
  [I generated an export using the school's required column structure and the output matched the expected format closely enough to support the existing ISMAS workflow. This would save time compared with manually copying values from spreadsheets at the end of term.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/admin-operations-viewport.png", width: 100%)],
  [#image("design/assets/admin-operations-viewport.png", width: 100%)],
  [#image("design/assets/admin-operations-viewport.png", width: 100%)],

  [[10] The application runs on iPad with iPadOS 17+ in both portrait and landscape orientations, with no layout breakage or blocked controls.],
  [I tested the app on an iPad in both portrait and landscape orientation and the layout remained usable in each case. Buttons, forms, and activity details were all accessible without visual overlap or controls being hidden off-screen.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#image("design/assets/auth-preview-compact.png", width: 100%)],
  [#image("design/assets/auth-preview-compact.png", width: 100%)],
  [#image("design/assets/auth-preview-compact.png", width: 100%)],
)

= Recommendations for Future Improvements

#emph[NOTE: Please refer to Q6 of Appendix 2 (Feedback) for further information on the client's suggestions.]

1. #text(weight: "bold")[Automated activity reminders]

A practical next step would be to add reminder notifications for volunteers who have already been approved for an activity. This would address the remaining risk that students still forget events after joining, especially when the activity takes place several days later. Because the system already has activity dates, participant records, and push infrastructure, this extension is technically realistic and directly linked to the client's request.

2. #text(weight: "bold")[Volunteer hour targets and progress tracking]

At present, the system records confirmed hours accurately, but it does not yet show students how those hours compare with graduation or department expectations. Adding configurable targets for individuals or year groups would make the records screen more useful by turning it from a historical view into a progress-monitoring tool. This would also help staff identify students who are falling behind before the end of term.

3. #text(weight: "bold")[Multi-language support]

The current interface is usable, but it is still primarily written in one language. Since the school community includes both English-speaking and Chinese-speaking users, adding localisation support would improve accessibility and reduce the chance of misunderstanding important activity instructions. This extension is realistic because the interface is already organised into reusable SwiftUI and web components that can be connected to a string-localisation layer.

4. #text(weight: "bold")[School calendar integration]

The system currently centralises volunteer opportunities successfully, but it still depends on users opening the app to check schedules. A future integration with the school's calendar system would reduce timetable clashes and make activities more visible in students' normal planning workflow. This would build directly on the existing activity date model rather than requiring a redesign of the core system.

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: 463]
]
