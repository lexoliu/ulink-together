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
  [[1] Registration with school email, name, class, and avatar; passwords stored using salted SHA-256 hashing.],
  [Accounts were registered with the required fields during testing, and profile pictures could be added without difficulty. When the database records were inspected, passwords appeared as hashed values rather than plaintext, which met the security expectation.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Registration form and hashed password record in database]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Registration form and hashed password record in database]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Registration form and hashed password record in database]]]],

  [[2] Role-based access control distinguishes volunteers from organisers, so volunteers browse and apply while organisers create, manage, approve, and confirm activities.],
  [The two account types saw different interfaces and permissions throughout the trial. Student accounts were limited to browsing and applying, while organiser accounts could publish activities, review applications, and confirm attendance, so the separation of responsibilities was clear.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Volunteer and organiser interfaces showing different permissions]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Volunteer and organiser interfaces showing different permissions]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Volunteer and organiser interfaces showing different permissions]]]],

  [[3] Organisers can publish activities with a title, date, location, capacity, duration, and description, and published activities appear in the volunteer feed.],
  [When I created a test activity, the form required all of the expected details, including date, venue, duration, and capacity. After publishing it, the activity appeared immediately in the volunteer feed with the same information visible to students.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity creation form and resulting volunteer feed entry]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity creation form and resulting volunteer feed entry]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity creation form and resulting volunteer feed entry]]]],

  [[4] Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.],
  [I changed the location and start time of an existing activity and the updated details were reflected correctly for the students who had already applied. I also tested cancellation, and the activity status was updated consistently instead of leaving volunteers with outdated information.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Edited activity details and cancelled activity state]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Edited activity details and cancelled activity state]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Edited activity details and cancelled activity state]]]],

  [[5] Volunteers can apply to activities, organisers approve or reject applications, and server-enforced capacity protection prevents overbooking under concurrent access.],
  [The application and approval workflow behaved as expected: students could submit requests and organisers could approve or reject them individually. When I tried to apply for an activity that was already full, the system rejected the request immediately, and simultaneous test applications did not produce any overbooking.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Application queue, approval actions, and full-capacity rejection]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Application queue, approval actions, and full-capacity rejection]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Application queue, approval actions, and full-capacity rejection]]]],

  [[6] Each activity has a scoped messaging channel where participants and the organiser can coordinate.],
  [Each activity included its own message thread, which kept logistics separate from other events. During testing, participants and the organiser were able to exchange updates in one place, making the communication record much easier to follow than scattered private chats.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity-specific messaging channel with organiser and volunteer messages]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity-specific messaging channel with organiser and volunteer messages]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Activity-specific messaging channel with organiser and volunteer messages]]]],

  [[7] Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.],
  [After a test activity ended, I was able to mark the students who attended as confirmed participants. Their records changed to completed status, which matched the intended process for validating attendance before hours are counted.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Attendance confirmation interface and completed participation records]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Attendance confirmation interface and completed participation records]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Attendance confirmation interface and completed participation records]]]],

  [[8] A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.],
  [The leaderboard updated in line with the hours confirmed through completed activities, and the ordering changed correctly after additional attendance was confirmed. This showed that the ranking reflects actual participation records instead of relying on a manually maintained total.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Leaderboard ordered by confirmed volunteer hours]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Leaderboard ordered by confirmed volunteer hours]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Leaderboard ordered by confirmed volunteer hours]]]],

  [[9] The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.],
  [I generated an export using the school's required column structure and the output matched the expected format closely enough to support the existing ISMAS workflow. This would save time compared with manually copying values from spreadsheets at the end of term.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Configurable export settings and generated ISMAS-compatible file]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Configurable export settings and generated ISMAS-compatible file]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: Configurable export settings and generated ISMAS-compatible file]]]],

  [[10] The application runs on iPad with iPadOS 17+ in both portrait and landscape orientations, with no layout breakage or blocked controls.],
  [I tested the app on an iPad in both portrait and landscape orientation and the layout remained usable in each case. Buttons, forms, and activity details were all accessible without visual overlap or controls being hidden off-screen.],
  [#text(fill: success-green, weight: "bold")[✓]],

  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: iPad portrait and landscape layouts with intact controls]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: iPad portrait and landscape layouts with intact controls]]]],
  [#rect(width: 100%, height: 180pt, stroke: 0.5pt + luma(180))[#align(center + horizon)[#text(fill: luma(120))[Screenshot placeholder: iPad portrait and landscape layouts with intact controls]]]],
)

= Recommendations for Future Improvements

#emph[NOTE: Please refer to Q6 of Appendix 2 (Feedback) for further information on the client's suggestions.]

#text(weight: "bold")[Automated activity reminders]

A useful next improvement would be to add push notifications that remind volunteers about activities they have already been approved for. This would help reduce no-shows by ensuring that students receive a clear reminder shortly before the activity begins, especially when they signed up several days in advance and may otherwise forget.

#text(weight: "bold")[Volunteer hour targets and progress tracking]

The deputy head suggested that it would be helpful to define target numbers of volunteer hours for individual students or year groups. If these targets were visible in the app, students could monitor their progress toward school or graduation expectations more easily, while staff could identify those who are falling behind and intervene earlier.

#text(weight: "bold")[Multi-language support]

Because the school community includes both local and international students, supporting both English and Chinese would improve accessibility. A bilingual interface would make the system easier to use for a wider range of students, parents, and staff, and would reduce the chance of misunderstandings when activity details are important.

#text(weight: "bold")[Integration with the school calendar]

Another improvement would be synchronising volunteer activities with the school's existing calendar system. If organisers could publish activities directly into the school calendar, students would be less likely to miss events or register for opportunities that clash with lessons, examinations, or other commitments.

Word Count: [placeholder]
