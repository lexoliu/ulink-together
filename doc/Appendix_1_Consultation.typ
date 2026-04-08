#set document(title: "Appendix 1: Consultation")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.98em, spacing: 1.8em, justify: true)
#set enum(spacing: 2em)

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#align(center)[
  #text(size: 20pt, weight: "bold")[APPENDIX 1#text(weight: "regular")[: CONSULTATION]]
]

#v(1.2em)

*Table of Contents*

- MEETING 1: _First Client Interview_ ................................ 2
- MEETING 2: _Second Client Interview_ ............................... 6

= Meeting 1: First Client Interview

*Date of Interview:* 15 September 2025

*Mode of interview:* face-to-face

#line(length: 100%, stroke: 0.5pt + luma(180))

_*Q1* - Could you introduce your role in the school and explain your responsibilities for volunteer activities?_

*Client:* I am the deputy head of the A-level department. Part of my role is organising volunteer activities for students, checking whether they actually took part, and then reporting the confirmed service hours to the school administration.

_*Q2* - How are volunteer activities currently announced and managed?_

*Client:* At the moment, announcements are usually sent through email and WeChat group messages. For tracking who signs up and how many hours they complete, we use a shared spreadsheet.

_*Q3* - What communication challenges do you face with the current process?_

*Client:* A lot of practical details, like where students should meet or whether the schedule has changed, end up being discussed in personal chats. The information becomes fragmented, and there is no shared record that everyone can refer back to.

_*Q4* - Have there been any problems with sign-ups?_

*Client:* Yes. The spreadsheet does not enforce any capacity limit, so we have had cases where more students signed up for an activity than there were places available.

_*Q5* - Roughly how many students are affected by this system?_

*Client:* It involves around 200 students in total, across multiple year groups in the A-level department.

_*Q6* - How much time do you spend verifying whether students actually attended activities?_

*Client:* During busy periods, usually two to three hours a week. I have to compare attendance lists against the spreadsheet and then update the records manually.

_*Q7* - Once the hours are confirmed, how are they currently reported to the school?_

*Client:* I prepare a summary and submit the hours into the ISMAS system, which is the school's administrative platform.

_*Q8* - What is the end-of-semester reporting process like for you?_

*Client:* It is quite tedious. I normally copy the values from the spreadsheet into the reporting template, and it is easy to make mistakes when doing that repeatedly.

_*Q9* - What devices do students usually have access to during the school day?_

*Client:* Students all have BYOD iPads, and that is really the only freely available device they can rely on during the day because phones are confiscated. The school also uses Apple School Manager, so native apps can be distributed directly to their iPads.

_*Q10* - What about staff and teachers? What devices do they use?_

*Client:* Staff use a range of devices. Some use laptops, some use desktop computers, and many of the school-managed machines are Windows devices maintained by the IT department. They are definitely not all limited to Apple devices.

_*Q11* - If a new system were built, what would make the biggest difference for you?_

*Client:* The biggest improvement would be having everything in one place. I would want a centralised system where activities, applications, and communication are all together, with automatic capacity enforcement and an easier way to verify hours.

_*Q12* - Are there any other concerns or features you would like to see?_

*Client:* I would like each activity to have some kind of chat feature, so that coordination does not happen in personal messages. That would make communication much clearer and easier to manage.

= Meeting 2: Second Client Interview

*Date of Interview:* 1 November 2025

*Mode of interview:* face-to-face

#line(length: 100%, stroke: 0.5pt + luma(180))

*Developer:* Today I would like to show you the proposed design for the system. The volunteer-facing application will be a native SwiftUI app for iPad, so it fits the devices students already use every day. For organisers and administrators, I am planning a web interface so it can be accessed on different staff devices, including Windows machines.

_*Q1* - What do you think of the overall colour scheme and layout of the design?_

*Client:* I like it. It looks clean and modern, and the layout feels clear without being overwhelming.

*Developer:* I also want to show you the database structure behind the system. It stores users, activities, applications, participation records, and messages. Passwords will be stored securely using hashing, and permissions will be controlled through roles so that volunteers, organisers, and administrators can only access what they are supposed to.

*Client:* That sounds very reassuring. I am glad security has been considered properly, especially password protection and role-based access.

*Developer:* Next, here are the volunteer-facing screens. Students can browse the activity feed, open an activity to see its details, apply through the app, and use the built-in messaging area for coordination.

_*Q2* - What do you think of the volunteer interface?_

*Client:* I think it works very well. I like the activity feed, the application process is easy to understand, and the messaging feature would be very useful.

*Developer:* These are the organiser-facing screens. Organisers can create activities, review applications, approve or reject students, and confirm attendance after the activity has finished.

_*Q3* - What do you think of the organiser tools?_

*Client:* I like these tools as well. The activity creation form looks practical, and the confirmation workflow makes sense. I especially prefer the idea that students apply and then organisers approve them, instead of students joining directly.

*Developer:* Finally, this is the admin panel. It gives an overview of users, classes, activities, and reporting-related functions.

_*Q4* - What are your thoughts on the admin panel?_

*Client:* The overview is helpful. One thing I would suggest is adding batch operations for class management, because handling classes one student at a time could become inefficient.

_*Q5* - Do you have any other suggestions or changes before development continues?_

*Client:* It would be helpful if the system could send a notification when an activity is about to start. Apart from that, I approve the designs and I think they match what we discussed earlier.

*Developer:* Thank you very much for the feedback. Your suggestions are very helpful, and I will incorporate them into the development of the system.
