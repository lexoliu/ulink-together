#set document(title: "Criterion E: Evaluation")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.1em, justify: true)
#set enum(spacing: 1.1em)

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

#emph[NOTE: Please refer to Appendix 2 (Feedback) for the full transcript of the client's evaluation of the final product. Each success criterion below is assessed based on the client's remarks during that interview.]

= Evaluation Against Success Criteria

#let partial-amber = rgb("#e65100")

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
  [Registration worked with all required fields and avatar upload. Database inspection confirmed passwords were stored as bcrypt hashes, not plaintext.

  #emph[(Appendix 2, Q4: "The password is stored securely as a hash rather than as the original text.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[2] Authority-based access control distinguishes volunteers from organisers and administrators, so volunteers browse and apply, organisers create, manage, approve, and confirm activities, and administrators manage users, groups, and permissions through the web panel.],
  [Each access level showed distinct interfaces: students could only browse and apply, organisers could publish and confirm, and administrators could manage users and permissions through the web panel.

  #emph[(Appendix 2, Q4: "The account roles clearly separate what students can do from what organisers can do.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[3] Organisers can publish activities with a title, date, location, capacity, duration, and description, and published activities appear in the volunteer feed.],
  [A test activity published with all required fields appeared immediately in the volunteer feed with correct details.

  #emph[(Appendix 2, Q4: "When creating activities, all of the information I said I needed is present in the form.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[4] Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.],
  [Editing location and time propagated correctly to enrolled volunteers. Cancellation updated the activity status consistently.

  #emph[(Appendix 2, Q4: "When I edited an activity, the updated details were reflected correctly.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[5] Volunteers can apply to activities, organisers approve or reject applications, and server-enforced capacity protection prevents overbooking under concurrent access.],
  [Application and approval worked as expected; full-capacity activities rejected further requests. Concurrent testing was limited to a small number of simultaneous requests, so capacity safety under heavy load has not been fully stress-tested.

  #emph[(Appendix 2, Q2: "I like that I can set a capacity limit and the system enforces it automatically --- this solves the overbooking problem we had with the spreadsheet.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[6] Each activity has a scoped messaging channel where participants and the organiser can coordinate.],
  [Each activity had its own message thread, keeping logistics separate. However, there are no push notifications for new messages yet, so users must open the channel manually.

  #emph[(Appendix 2, Q2: "Having a dedicated channel for each activity is excellent. Previously, coordination messages were scattered across personal WeChat chats.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[7] Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.],
  [After an activity ended, the organiser confirmed attendees and their records moved to completed status with the correct duration stored.

  #emph[(Appendix 2, Q2: "I can confirm participation directly in the app after an activity ends, and the hours are immediately reflected in the leaderboard.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[8] A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.],
  [The leaderboard ranking updated correctly as new hours were confirmed, reflecting actual participation records rather than a manually maintained total.

  #emph[(Appendix 2, Q4: "Their hours were counted in the leaderboard.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[9] The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.],
  [The export produced a file matching the ISMAS column structure, replacing the manual copy-paste process.

  #emph[(Appendix 2, Q2: "The CSV export for ISMAS is exactly what I needed. No more copying values from a spreadsheet into a template.")]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[10] The application runs on iPad with iPadOS 17+ in landscape orientation, which is the device position students hold for group work and the only orientation the app accepts.],
  [The iPad app launches directly in landscape and refuses to rotate into portrait because portrait is not declared in the `UISupportedInterfaceOrientations` build setting. This is the direct response to the client's beta feedback (Appendix 2, Q3/Q4) that portrait required excessive scrolling and felt cramped for management tasks --- rather than optimising a second layout, the project scope was narrowed so every screen now targets one wide aspect ratio and the client's stated workflow (iPad on a desk or stand in landscape) is the only supported case.

  #emph[(Appendix 2, Q3: "Landscape is good but portrait mode needs more scrolling and feels less polished." --- addressed by restricting to landscape-only.)]],
  [#text(fill: success-green, weight: "bold")[✓]],
)

= Recommendations for Future Improvements

#emph[NOTE: The following recommendations are drawn from the client's suggestions during the final evaluation interview (Appendix 2, Q6).]

1. #text(weight: "bold")[Automated activity reminders]

Adding reminder notifications before an activity starts would reduce the risk of students forgetting events they have already joined. The system already stores activity dates and participant records, so this extension is technically straightforward.

#emph[(Appendix 2, Q6: "It would be helpful if the system could automatically remind students about upcoming activities ... some students forget even after being approved.")]

2. #text(weight: "bold")[Volunteer hour targets and progress tracking]

The system records confirmed hours but does not compare them against graduation or department targets. Configurable hour goals per student or year group would turn the records screen into a progress tracker and help staff identify students falling behind.

#emph[(Appendix 2, Q6: "If each student could see how many hours they still need to complete for the graduation requirement, that would be very motivating.")]

3. #text(weight: "bold")[Multi-language support]

The interface is currently in one language. Since the school includes English-speaking and Chinese-speaking users, adding localisation would improve accessibility. The existing component structure supports connecting a string-localisation layer without redesign.

#emph[(Appendix 2, Q6: "Our school has both Chinese and English speaking students. Having the interface available in both languages would help.")]

4. #text(weight: "bold")[School calendar integration]

Integrating with the school calendar would reduce timetable clashes and surface activities in students' normal planning workflow, building directly on the existing activity date model.

#emph[(Appendix 2, Q6: "If the activity dates could sync with the school calendar, it would help avoid scheduling conflicts with exams or school events.")]

5. #text(weight: "bold")[External keyboard shortcuts]

Because the iPad client is now landscape-only and many students attach a Smart Keyboard during class, a future iteration could expose keyboard shortcuts for common actions (apply, withdraw, send message, jump to records). SwiftUI's `keyboardShortcut` modifier would let each action be reachable without touching the screen, which is useful for teachers running the organiser workflow during a live activity.

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
