#set document(title: "Appendix 2: Feedback")
#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(font: "New Computer Modern", size: 12pt)
#set heading(numbering: none)
#set par(leading: 0.85em, spacing: 1.4em, justify: true)
#set enum(spacing: 1.2em)

#let navy = rgb("#183153")

#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 14pt, weight: "bold", fill: navy, upper(it.body))
  v(0.4em)
}

#align(center)[
  #text(size: 20pt, weight: "bold")[APPENDIX 2#text(weight: "regular")[: FEEDBACK]]
]

#v(1em)

#text(weight: "bold")[Date of Interview:] 24 February 2026
#text(weight: "bold")[Mode of interview:] face-to-face

#line(length: 100%)

The following transcript records the final meeting with the client, the deputy head of the A-level department, during which the completed volunteer management system was demonstrated. The system shown included both the native iPad application for student volunteers and the web-based admin panel for organisers.

#text(weight: "bold")[Developer:] Hi Ms. Chen, I have completed the volunteer management system and would like to get your comments about it.

#text(weight: "bold")[Client:] Sure, let's see it.

#emph([Runs the system and explains each feature.])

#text(style: "italic", weight: "bold")[Q1] - So what is your impression of the system?

#text(weight: "bold")[Client:] I am very impressed; it looks professional and polished. The iPad app is intuitive --- students will be able to use it easily between classes. The activity feed is clear and well-organised, and I like how students can see all available activities in one place instead of searching through WeChat messages and emails.

#text(style: "italic", weight: "bold")[Q2] - Based on what you have seen, what are your thoughts about the system?

#text(weight: "bold")[Client:] My feedback is positive across all of the main areas.

#text(weight: "bold")[Activity management:] The activity creation form is straightforward. I like that I can set a capacity limit and the system enforces it automatically --- this solves the overbooking problem we had with the spreadsheet. The apply-and-approve workflow is better than direct joining because it gives me control over who participates.

#text(weight: "bold")[Messaging:] Having a dedicated channel for each activity is excellent. Previously, coordination messages were scattered across personal WeChat chats and I could never find important updates. Now everything is in one place and visible to all participants.

#text(weight: "bold")[Hour verification:] The confirmation process is much faster than manually cross-referencing attendance lists. I can confirm participation directly in the app after an activity ends, and the hours are immediately reflected in the leaderboard.

#text(weight: "bold")[Export:] The CSV export for ISMAS is exactly what I needed. No more copying values from a spreadsheet into a template at the end of the semester.

#text(style: "italic", weight: "bold")[Q3] - I have a list of the success criteria that we agreed upon, can you confirm which ones have been successfully addressed in the system?

#text(weight: "bold")[Client:] Yes, I can confirm that all of the agreed success criteria have been met.

+ Registration with email, name, class, and avatar --- confirmed ☑
+ Role-based access control for volunteers and organisers --- confirmed ☑
+ Activity publishing with all required fields --- confirmed ☑
+ Editing and cancellation with changes propagated --- confirmed ☑
+ Apply-and-approve workflow with capacity protection --- confirmed ☑
+ Activity-scoped messaging --- confirmed ☑
+ Participation confirmation to completed status --- confirmed ☑
+ Leaderboard based on confirmed volunteer hours --- confirmed ☑
+ ISMAS-compatible export --- confirmed ☑
+ iPad support in both portrait and landscape orientations --- confirmed ☑

#text(style: "italic", weight: "bold")[Q4] - Can you explain the rationale behind your decisions?

#text(weight: "bold")[Client:] Yes. I can see evidence for each of the criteria in the system itself. The password is stored securely as a hash rather than as the original text. The account roles clearly separate what students can do from what organisers can do. When creating activities, all of the information I said I needed is present in the form. When I edited an activity, the updated details were reflected correctly. When I tried to approve more volunteers than the stated capacity, the system prevented it. The activity chat is separated by event, which keeps communication relevant. After confirming attendance, the volunteer's record changed appropriately and their hours were counted in the leaderboard. The export file also matches the structure I need for ISMAS. Finally, the interface worked properly when the iPad orientation changed, so it is practical for real use on school devices.

#text(style: "italic", weight: "bold")[Q5] - With this developed system, do you feel that it can aid and improve the efficiency of your work?

#text(weight: "bold")[Client:] Yes, absolutely. The time I spend on volunteer management will be significantly reduced. The automatic capacity enforcement alone saves me from dealing with overbooking issues every week. The export feature will save me several hours at the end of each semester. And having all communication in activity channels means I won't miss important updates anymore. It's not fully deployed yet, but I can see this becoming an essential tool for the department.

#text(style: "italic", weight: "bold")[Q6] - I'm glad you liked it. Aside from the success criteria, what other things do you think can be added to improve and refine this system?

#text(weight: "bold")[Client:] I have four suggestions that could make it even better in future development.

1. #text(weight: "bold")[Automated reminders] --- It would be helpful if the system could automatically remind students about upcoming activities they have been approved for, maybe a day before. Some students forget even after being approved.
2. #text(weight: "bold")[Hour targets and progress tracking] --- If each student could see how many hours they still need to complete for the graduation requirement, that would be very motivating. Right now I have to tell them individually.
3. #text(weight: "bold")[Multi-language interface] --- Our school has both Chinese and English speaking students. Having the interface available in both languages would help students who are less comfortable with English.
4. #text(weight: "bold")[Calendar integration] --- If the activity dates could sync with the school calendar, it would help avoid scheduling conflicts with exams or school events.

#text(weight: "bold")[Client:] But for the time you had, I am very impressed with this. It looks like a real system that can be used. Overall, I think you did an excellent job with the development.

#align(center)[∘ ∘ ∘]

#text(weight: "bold")[Developer:] Thank you, Ms. Chen. I really appreciate your feedback and your help throughout this project.

#text(weight: "bold")[Client:] You're welcome. Good luck with completing the project!
