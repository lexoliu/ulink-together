#set document(title: "Criterion A: Planning")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: none)
#set par(leading: 0.65em, justify: true)

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.6em)
  text(size: 16pt, weight: "bold", fill: navy, it)
  v(0.3em)
}

#show heading.where(level: 2): it => {
  v(0.5em)
  text(size: 12pt, weight: "bold", fill: navy, it)
  v(0.2em)
}

#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Criterion A: Planning]
]

= Rationale

My client is the CAS (Creativity, Activity, Service) coordinator at my school, who is responsible for organising volunteer activities, verifying student participation, and reporting confirmed service hours to the school administration. She manages the programme for approximately 200 students across multiple year groups.

During our initial consultation, she described several problems with how volunteering is currently handled. Activity announcements are posted through a mix of email and WeChat group messages, which means students often miss sign-up deadlines or do not see relevant opportunities *(Q1 Appendix 1)*. When students do sign up, the coordinator tracks participation using a shared spreadsheet. She has experienced cases where more students signed up for an activity than there were available places, because the spreadsheet does not enforce any capacity limit *(Q4 Appendix 1)*.

Hour verification is another source of friction. After an activity finishes, the coordinator has to manually cross-reference attendance lists with the spreadsheet and update each student's total. She estimates this takes two to three hours per week during busy periods *(Q6 Appendix 1)*. She also mentioned that communication between volunteers and activity organisers is fragmented --- messages about logistics, schedule changes, or cancellations end up spread across personal chats with no shared record *(Q3 Appendix 1)*.

At the end of each semester, the coordinator is expected to submit a summary of each student's confirmed hours to the school's ISMAS system. She currently does this by copying values from the spreadsheet into a template, which she described as tedious and error-prone *(Q8 Appendix 1)*.

#align(right)[#text(size: 9pt, style: "italic", fill: luma(120))[word count: 237]]

= Proposed Solution

I will develop a native iPad application paired with a server backend to centralise the management of volunteer activities at the school. The iPad app will serve as the primary interface for both volunteers and organisers, while the server will handle authentication, data validation, concurrency control, and persistent storage.

I chose a native iPad app because the school provides every student with an iPad as their primary device, and the coordinator confirmed that most interactions would happen on these devices *(Q9 Appendix 1)*. A native SwiftUI application allows me to take advantage of the platform's built-in accessibility features, push notification support, and responsive layout system, all of which matter for a school environment where students use the app in short bursts between classes.

For the backend, I will use Rust with a PostgreSQL database. I chose Rust for its memory safety guarantees and performance characteristics, which are well suited to handling concurrent requests --- particularly important for the capacity-protected join operation, where multiple students may attempt to sign up for the same activity at the same time. PostgreSQL provides the transactional guarantees and row-level locking needed to prevent overbooking.

The system will cover activity publication, capacity-protected sign-up, activity-scoped messaging, a participation leaderboard computed from confirmed records, and a configurable export adapter for generating reports compatible with the school's administrative import workflow.

This architecture separates the user-facing presentation from the business logic and data layer, which means changes to the school's reporting format or additions to the organiser's workflow can be made on the server without requiring an app update.

#align(right)[#text(size: 9pt, style: "italic", fill: luma(120))[word count: 246]]

= Success Criteria

+ Volunteers and organisers can register accounts with their school email, name, class, and an avatar. Passwords are stored using bcrypt hashing.
+ Role-based access control distinguishes between volunteers (who browse and join activities) and organisers (who create, manage, and confirm activities).
+ Organisers can publish activities with a title, date, location, capacity, duration, and description. Published activities appear in the volunteer feed.
+ Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.
+ Volunteers can join activities with server-enforced capacity protection that prevents overbooking under concurrent access.
+ Each activity has a scoped messaging channel where participants and the organiser can coordinate.
+ A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.
+ Organisers can confirm volunteer participation after an activity completes, converting joined records to completed status.
+ The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.
+ The application runs on iPad with iPadOS 17+ in both portrait and landscape orientations, with no layout breakage or blocked controls.
