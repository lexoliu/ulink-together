#set document(title: "Criterion B: Record of Tasks")
#set page(paper: "a4", margin: (x: 1.6cm, y: 2cm))
#set text(font: "New Computer Modern", size: 9pt)
#set heading(numbering: none)
#set par(leading: 0.68em, spacing: 0.9em, justify: true)
#set table(
  stroke: 0.45pt + luma(170),
  inset: 4pt,
  fill: (_, y) => if y == 0 { rgb("#174d8c") } else { white },
)

#let navy = rgb("#183153")

#align(center)[
  #text(size: 22pt, weight: "bold")[CRITERION B: #text(weight: "regular")[RECORD OF TASK]]
]

#v(0.8em)

#table(
  columns: (0.5fr, 1.7fr, 1.8fr, 1.2fr, 1.5fr, 0.5fr),
  align: (center, left, left, center, center, center),
  table.header(
    text(fill: white)[Task No.],
    text(fill: white)[Planned action],
    text(fill: white)[Planned outcome],
    text(fill: white)[Time estimate],
    text(fill: white)[Target completion date],
    text(fill: white)[Crit.],
  ),

  [1], [Discuss IA objectives with supervisor], [Clarify the product direction and align the project with the IA requirements before meeting the client.], [2 hours], [8 Sep 2025], [A],
  [2], [Investigate volunteer-management problems at school], [Gather practical evidence about announcements, overbooking, hour verification, and reporting problems.], [3 hours], [10 Sep 2025], [A],
  [3], [Prepare first client interview questions], [Create a focused question set covering workflow, pain points, and desired features.], [2 hours], [12 Sep 2025], [A],
  [4], [Conduct the first consultation with the client], [Understand the client’s current process and the improvements she expects from the system.], [40 minutes], [15 Sep 2025], [A],
  [5], [Transcribe the initial consultation into the appendix], [Produce a reference record of the client’s answers for later design and evaluation work.], [3 hours], [17 Sep 2025], [A],
  [6], [Outline success criteria], [Create observable and testable success criteria based on the client’s stated needs.], [1 hour], [18 Sep 2025], [A],
  [7], [Draft Criterion A], [Prepare the rationale, proposed solution, and success criteria for review.], [4 hours], [22 Sep 2025], [A],
  [8], [Revise Criterion A after feedback], [Refine the planning document so the project scope is fixed before design begins.], [1 hour], [25 Sep 2025], [A],

  [9], [Compare implementation platforms and deployment options], [Justify the split between the SwiftUI iPad app, the web admin interface, and the server backend.], [4 hours], [28 Sep 2025], [B],
  [10], [Design the overall system architecture and module decomposition], [Produce a clear structure showing student app, teacher/admin web interface, backend, and data storage.], [3 hours], [2 Oct 2025], [B],
  [11], [Design the relational database schema], [Define the main entities, important fields, keys, constraints, and data rules.], [5 hours], [6 Oct 2025], [B],
  [12], [Create a standard entity-relationship diagram], [Show the relationships between users, activities, records, channels, messages, and exports with standard notation.], [3 hours], [8 Oct 2025], [B],
  [13], [Design the student-side SwiftUI screens], [Prepare interface plans for authentication, feed, detail, records, leaderboard, notifications, account, and messaging.], [5 hours], [18 Oct 2025], [B],
  [14], [Design the teacher/admin web screens], [Prepare interface plans for dashboard, activity management, student management, chat, and export workflows.], [5 hours], [22 Oct 2025], [B],
  [15], [Create use case and flow diagrams], [Produce standard diagrams for actor access, module flows, and key design-level state/process behaviour.], [4 hours], [26 Oct 2025], [B],
  [16], [Develop the test plan mapped to success criteria], [Group valid, invalid, and boundary tests under each relevant success criterion.], [3 hours], [29 Oct 2025], [B],
  [17], [Conduct the second client consultation], [Present the database design, interface designs, and process diagrams before development.], [1 hour], [1 Nov 2025], [B],
  [18], [Transcribe the second consultation into the appendix], [Preserve client feedback as evidence for design revisions.], [3 hours], [3 Nov 2025], [B],
  [19], [Revise the design document after feedback], [Update wireframes, diagrams, and data design to match the client’s comments.], [4 hours], [6 Nov 2025], [B],
  [20], [Review the Criterion B design package with supervisor], [Confirm that the design overview and record of tasks are complete and examiner-friendly.], [2 hours], [10 Nov 2025], [B],

  [21], [Set up the server project and database], [Create the backend foundation with migrations, request handling, and persistent storage.], [3 hours], [15 Nov 2025], [C],
  [22], [Implement authentication and session management], [Deliver registration, login, password hashing, and session-token handling.], [6 hours], [22 Nov 2025], [C],
  [23], [Implement activity lifecycle management], [Deliver activity creation, editing, cancellation, and lifecycle transitions on the server.], [8 hours], [1 Dec 2025], [C],
  [24], [Implement capacity-protected application logic], [Ensure concurrent joins cannot overbook an activity.], [5 hours], [6 Dec 2025], [C],
  [25], [Implement activity-scoped messaging], [Create channels, membership checks, message sending, and retrieval.], [6 hours], [14 Dec 2025], [C],
  [26], [Implement leaderboard and participation confirmation], [Deliver ranking aggregation and organiser confirmation logic.], [4 hours], [20 Dec 2025], [C],
  [27], [Build the student-side SwiftUI activity feed and detail screens], [Provide the main browsing and application experience on iPad.], [8 hours], [5 Jan 2026], [C],
  [28], [Build the student-side SwiftUI records, notifications, messaging, leaderboard, and account screens], [Complete the main volunteer journey and personal-management workflows.], [7 hours], [15 Jan 2026], [C],
  [29], [Build the organiser tools in SwiftUI], [Deliver organiser creation, management, and export-related workflows on iPad.], [6 hours], [22 Jan 2026], [C],
  [30], [Build the teacher/admin web interface], [Deliver dashboard, activity management, student management, and export workflows in the browser.], [5 hours], [28 Jan 2026], [C],
  [31], [Develop testing strategy and expand test coverage], [Define the layered testing approach (unit, integration, XCUITest, alpha/beta user testing), automate business-rule verification and key iPad user journeys, and document the debugging process.], [4 hours], [6 Feb 2026], [C],
  [32], [Document technologies and notable techniques], [Prepare the Criterion C explanation of implementation choices and computational thinking.], [2 hours], [8 Feb 2026], [C],
  [33], [Complete the Criterion C document], [Show how the implemented product meets the success criteria through development evidence.], [5 hours], [12 Feb 2026], [C],

  [34], [Write the screencast script], [Plan the order and content of the functionality demonstration.], [3 hours], [16 Feb 2026], [D],
  [35], [Record and edit the screencast], [Produce a clear video showing the finished system working within the time limit.], [4 hours], [20 Feb 2026], [D],

  [36], [Conduct the final client meeting], [Demonstrate the finished product and gather final feedback.], [1 hour], [24 Feb 2026], [E],
  [37], [Transcribe the final consultation], [Preserve the client’s final feedback for the evaluation section.], [3 hours], [26 Feb 2026], [E],
  [38], [Complete the Criterion E document], [Evaluate how well the product meets the success criteria and identify future improvements.], [6 hours], [3 Mar 2026], [E],
)
