#set document(title: "Criterion A: Planning")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.4em, justify: true)
#set enum(spacing: 2em)

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#align(center)[
  #text(size: 20pt, weight: "bold")[CRITERION A#text(weight: "regular")[: PLANNING]]
]

= Rationale

My client is the deputy head of the A-level department at my school, who is responsible for organising volunteer activities, verifying student participation, and reporting confirmed service hours to the school administration. Volunteering is both a graduation requirement and a component of the department's credit-based evaluation system, affecting approximately 200 students across multiple year groups.

During our initial consultation, she described several problems with how volunteering is currently handled. Activity announcements are posted through a mix of email and WeChat group messages, which means students often miss sign-up deadlines or do not see relevant opportunities *(Q1 Appendix 1)*. When students do sign up, the deputy head tracks participation using a shared spreadsheet. She has experienced cases where more students signed up for an activity than there were available places, because the spreadsheet does not enforce any capacity limit *(Q4 Appendix 1)*.

Hour verification is another source of friction. After an activity finishes, the deputy head has to manually cross-reference attendance lists with the spreadsheet and update each student's total. She estimates this takes two to three hours per week during busy periods *(Q6 Appendix 1)*. She also mentioned that communication between volunteers and activity organisers is fragmented --- messages about logistics, schedule changes, or cancellations end up spread across personal chats with no shared record *(Q3 Appendix 1)*.

At the end of each semester, the deputy head is expected to submit a summary of each student's confirmed hours to the school's ISMAS system. She currently does this by copying values from the spreadsheet into a template, which she described as tedious and error-prone *(Q8 Appendix 1)*.

= Proposed Solution

I will develop a native iPad application paired with a server backend to centralise the management of volunteer activities at the school. The app will serve as the primary interface for both volunteers and organisers, while the server will handle data validation, concurrency control, and persistent storage.

Organisers will publish activities with details such as date, location, capacity, and duration to a unified feed, replacing the fragmented email and WeChat announcements that currently cause students to miss opportunities. When a volunteer applies to an activity, the organiser reviews and approves or rejects the application; the server enforces a capacity check at the database level, preventing the overbooking that occurs with the current spreadsheet. Each activity will include a scoped messaging channel, keeping coordination in a shared record rather than scattered across personal chats with no history.

After an activity finishes, the organiser confirms each participant's attendance through the app, and confirmed hours feed automatically into both a volunteer leaderboard and a configurable export adapter that generates files compatible with the school's ISMAS import workflow --- eliminating the semester-end copy-paste process the deputy head described as tedious and error-prone *(Q8 Appendix 1)*.

The school operates a BYOD iPad policy: every student is required to carry an iPad, and it is their only freely available device throughout the day because personal phones are confiscated during school hours *(Q9 Appendix 1)*. The school also uses Apple School Manager, which gives the IT department the ability to distribute native applications directly to student devices. I therefore chose a native SwiftUI application for the volunteer-facing interface: it can be pushed to every student's iPad without requiring them to install anything manually, and a native app provides platform push notifications, built-in accessibility features, and a responsive layout suited to short sessions between classes. For the organiser and administrative interface, I chose a web-based React application because staff members use a variety of devices --- including Windows machines maintained by the IT department --- and a web application runs on any platform with a browser without additional installation *(Q10 Appendix 1)*. The admin panel supports user management, group-based authority assignments, and batch operations that are impractical on a mobile interface. For the backend, I will use Rust with a PostgreSQL database: Rust's memory safety guarantees and async runtime handle concurrent sign-up requests safely, while PostgreSQL's transactional guarantees provide the consistency needed for capacity protection.

= Success Criteria

+ Volunteers and organisers can register accounts with their school email, name, class, and an avatar. Passwords are stored using bcrypt hashing.
+ Authority-based access control distinguishes between volunteers (who browse and apply for activities), organisers (who create, manage, approve applications, and confirm activities), and administrators (who manage users, groups, and system-wide permissions through the web panel).
+ Organisers can publish activities with a title, date, location, capacity, duration, and description. Published activities appear in the volunteer feed.
+ Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.
+ Volunteers can apply to activities, and organisers approve or reject applications, with server-enforced capacity protection that prevents overbooking under concurrent access.
+ Each activity has a scoped messaging channel where participants and the organiser can coordinate.
+ Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.
+ A leaderboard ranks volunteers by total confirmed hours, computed from participation records rather than stored totals.
+ The system provides a configurable export that generates confirmed-hours data in a format compatible with the school's ISMAS import workflow.
+ The application runs on iPad with iPadOS 17+ in both portrait and landscape orientations, with no layout breakage or blocked controls.
