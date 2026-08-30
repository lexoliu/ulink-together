#set document(title: "Criterion A: Planning")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.98em, spacing: 1.8em, justify: true)
#set enum(spacing: 2em)

#import "@preview/wordometer:0.1.5": word-count, total-words

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#show: word-count.with(exclude: (heading, figure, raw, <no-wc>))

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION A#text(weight: "regular")[: PLANNING]]
]

= Rationale

My client is the deputy head of the A-level department at my school, responsible for organising volunteer activities, verifying student participation, and reporting confirmed service hours. Volunteering is a graduation requirement affecting approximately 200 students.

She described four main problems. Activity announcements go through email and WeChat, so students miss sign-up deadlines *(Q1 Appendix 1)*. Participation is tracked in a shared spreadsheet that cannot enforce capacity limits, causing overbooking *(Q4 Appendix 1)*. Hour verification requires manually cross-referencing attendance lists, taking two to three hours per week *(Q6 Appendix 1)*. Communication is fragmented across personal chats with no shared record *(Q3 Appendix 1)*. At semester end, confirmed hours must be submitted to the school's ISMAS system via a manually prepared spreadsheet, which she described as tedious and error-prone *(Q8 Appendix 1)*.

= Proposed Solution

I will develop a native iPad application paired with a server backend to centralise volunteer management. Users register with school identity details, and the system shows different tools to volunteers, organisers, and administrators according to their responsibilities. Organisers publish activities to a unified feed; volunteers apply and organisers approve, with server-enforced capacity limits. Each activity includes a scoped chat for coordination. After an activity ends, the organiser confirms hours, which feed a leaderboard and an ISMAS-compatible export spreadsheet *(Q8 Appendix 1)*.

The school operates a BYOD iPad policy --- the iPad is students' only freely available device *(Q9 Appendix 1)* --- so I chose a native SwiftUI application distributed through Apple School Manager. For staff, I chose a web-based React admin panel that runs on any device with a browser *(Q10 Appendix 1)*. Both clients share a single server backend.

= Success Criteria

+ Volunteers and organisers register with school email, name, class, and an avatar; passwords are stored using bcrypt hashing rather than plaintext.
+ Authority-based access control separates students, teachers, and administrators; administrators additionally manage users in batch and rename cohorts for year-end promotion, while teachers cannot manage users.
+ Organisers publish activities with name, date, location, duration, and capacity; volunteers browse and search the unified feed.
+ Organisers transition activities through the lifecycle states recruiting, ongoing, completed, and cancelled; state changes propagate to enrolled volunteers.
+ Volunteers apply and may withdraw; organisers approve or reject applications; the server enforces capacity protection under concurrent access so an activity cannot be overbooked.
+ Each activity has a scoped chat channel; once the activity ends the channel auto-archives and rejects further messages, keeping the record tied to the event that produced it.
+ Organisers confirm participation minutes after an activity completes; confirmed hours are written back to the student record in real time.
+ A leaderboard ranks volunteers by total confirmed hours, derived from participation records rather than an editable stored total.
+ Confirmed-hours data exports as an ISMAS-compatible CSV spreadsheet, available globally from the admin dashboard and per-activity from the activity workspace.
+ The iPad client runs in landscape orientation only: portrait is not declared in the supported interface orientations, so iPadOS refuses to rotate, and every screen is tuned for the single wide aspect ratio that matches the classroom posture students actually use.

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
