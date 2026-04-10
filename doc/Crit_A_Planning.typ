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

My client is the deputy head of the A-level department at my school, who is responsible for organising volunteer activities, verifying student participation, and reporting confirmed service hours to the school administration. Volunteering is both a graduation requirement and a component of the department's credit-based evaluation system, affecting approximately 200 students across multiple year groups.

During our initial consultation, she described several problems with how volunteering is currently handled. Activity announcements are posted through a mix of email and WeChat group messages, which means students often miss sign-up deadlines or do not see relevant opportunities *(Q1 Appendix 1)*. When students do sign up, the deputy head tracks participation using a shared spreadsheet. She has experienced cases where more students signed up for an activity than there were available places, because the spreadsheet does not enforce any capacity limit *(Q4 Appendix 1)*.

Hour verification is another source of friction. After an activity finishes, the deputy head has to manually cross-reference attendance lists with the spreadsheet and update each student's total. She estimates this takes two to three hours per week during busy periods *(Q6 Appendix 1)*. She also mentioned that communication between volunteers and activity organisers is fragmented --- messages about logistics, schedule changes, or cancellations end up spread across personal chats with no shared record *(Q3 Appendix 1)*.

At the end of each semester, the deputy head is expected to submit a summary of each student's confirmed hours to the school's ISMAS system. ISMAS does not provide an open API, so she cannot send the data directly from another system. Instead, she has to prepare a spreadsheet and then import it into ISMAS manually, which she described as tedious and error-prone *(Q8 Appendix 1)*.

= Proposed Solution

I will develop a native iPad application paired with a server backend to centralise the management of volunteer activities at the school. The app will serve as the main interface for volunteers and organisers, while the backend keeps activity information, participation records, and reporting data in one place.

Users will register with their school identity details so volunteering records stay attached to recognisable accounts, and different tools will be shown to volunteers, organisers, and administrators according to their responsibilities. Organisers will publish activities with details such as date, location, capacity, and duration to a unified feed, replacing the fragmented email and WeChat announcements that currently cause students to miss opportunities. When a volunteer applies to an activity, the organiser reviews and approves or rejects the application, and the system prevents activities from being overfilled. Each activity will include one shared chat space for the organiser and the participating volunteers. This chat is created for that activity and stays attached to it throughout the activity's lifetime, so reminders, schedule changes, and questions stay with the correct event instead of being scattered across personal messages.

After an activity finishes, the organiser confirms each participant's attendance through the app. Confirmed hours then update the volunteer leaderboard, and the system prepares a spreadsheet that staff can download and import into ISMAS manually. The spreadsheet will follow the same overall structure as the school reporting template the deputy head already uses, so the app reduces repeated copying without pretending to replace the final ISMAS import step *(Q8 Appendix 1)*.

The school operates a BYOD iPad policy: every student carries an iPad, and it is their only freely available device because personal phones are confiscated during school hours *(Q9 Appendix 1)*. The school also uses Apple School Manager to distribute apps directly to student devices. I therefore chose a native SwiftUI application for volunteers: it can be pushed to every iPad without manual installation, and provides push notifications, accessibility, and a layout suited to short sessions between classes. For organisers and administrators, I chose a web-based React application because staff use a variety of devices and a web app runs on any platform with a browser *(Q10 Appendix 1)*. The admin panel supports user management, permission management, and export preparation in a format that is easier for staff to use on a larger screen. The backend provides shared storage so multiple users can work with the same up-to-date activity and participation data.

= Success Criteria

+ Volunteers and organisers can register accounts with their school email, name, class, and an avatar. Passwords are stored using bcrypt hashing.
+ Authority-based access control distinguishes between volunteers (who browse and apply for activities), organisers (who create, manage, approve applications, and confirm activities), and administrators (who manage users, groups, and system-wide permissions through the web panel).
+ Organisers can publish activities with a title, date, location, capacity, duration, and description. Published activities appear in the volunteer feed.
+ Organisers can edit or cancel published activities, with changes propagated to all affected volunteers.
+ Volunteers can apply to activities, and organisers approve or reject applications, with the system preventing overbooking.
+ Each activity has a dedicated chat space that is created for that activity and remains tied to it throughout the activity's lifetime.
+ Organisers can confirm volunteer participation after an activity completes, converting participation records to completed status.
+ A leaderboard ranks volunteers by total confirmed hours.
+ The system generates a spreadsheet of confirmed hours in the same overall structure as the school's ISMAS import template, so staff can download it and import it manually.
+ The application runs on iPad with iPadOS 17+ in landscape orientation, which is the device position students hold for group work and the only orientation the app accepts, so layouts are tuned for a single aspect ratio rather than two.

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
