#set document(title: "Criterion B: Record of Tasks")
#set page(paper: "a4", margin: (x: 1.8cm, y: 2cm))
#set text(font: "New Computer Modern", size: 9pt)
#set heading(numbering: none)
#set par(leading: 0.55em, justify: true)
#set table(
  stroke: 0.5pt + luma(180),
  inset: 5pt,
  fill: (_, y) => if y == 0 { rgb("#183153") } else if calc.rem(y, 2) == 0 { rgb("#f8fafc") } else { white },
)

#let navy = rgb("#183153")

#align(center)[
  #text(size: 22pt, weight: "bold", fill: navy)[Criterion B: Record of Tasks]
]

#v(0.8em)

#table(
  columns: (auto, 1.8fr, 1.8fr, auto, auto, auto),
  align: (center, left, left, center, center, center),
  table.header(
    text(fill: white, weight: "bold")[Task No.],
    text(fill: white, weight: "bold")[Planned Action],
    text(fill: white, weight: "bold")[Planned Outcome],
    text(fill: white, weight: "bold")[Time Est.],
    text(fill: white, weight: "bold")[Target Date],
    text(fill: white, weight: "bold")[Crit.],
  ),

  // --- Criterion A: Planning ---
  [1],
  [Discuss IA objectives and scope with supervisor],
  [Clarify project direction and confirm alignment with IB requirements],
  [2 hours],
  [8 Sep 2025],
  [A],

  [2],
  [Research volunteer management problems at the school],
  [Identify specific pain points and gather background information for the consultation],
  [3 hours],
  [10 Sep 2025],
  [A],

  [3],
  [Prepare interview questions for the client],
  [A structured list of questions targeting current workflow, problems, and desired features],
  [2 hours],
  [12 Sep 2025],
  [A],

  [4],
  [Conduct the first consultation with the CAS coordinator],
  [Understand the client's situation and the improvements they need],
  [40 min],
  [15 Sep 2025],
  [A],

  [5],
  [Transcribe and analyse the initial consultation],
  [Documented client responses for reference during development],
  [3 hours],
  [17 Sep 2025],
  [A],

  [6],
  [Outline success criteria based on consultation findings],
  [A set of observable, testable criteria mapped to client needs],
  [1 hour],
  [18 Sep 2025],
  [A],

  [7],
  [Complete the first draft of the Criterion A document],
  [Rationale, proposed solution, and success criteria ready for review],
  [4 hours],
  [22 Sep 2025],
  [A],

  [8],
  [Review Criterion A with supervisor and revise],
  [Receive feedback and ensure the document meets criteria requirements],
  [1 hour],
  [25 Sep 2025],
  [A],

  // --- Criterion B: Design ---
  [9],
  [Research and compare development frameworks],
  [Justified technology choices: SwiftUI for the client, Rust + PostgreSQL for the server],
  [4 hours],
  [28 Sep 2025],
  [B],

  [10],
  [Design the system architecture and decomposition],
  [A decomposition diagram and architecture overview showing component responsibilities],
  [3 hours],
  [2 Oct 2025],
  [B],

  [11],
  [Design the database schema],
  [Entity definitions with field types, constraints, and relationships],
  [5 hours],
  [6 Oct 2025],
  [B],

  [12],
  [Create the entity-relationship diagram],
  [A visual ERD showing primary keys, foreign keys, and cardinality],
  [3 hours],
  [8 Oct 2025],
  [B],

  [13],
  [Design the API endpoints and request-response flows],
  [Documentation of how core user actions move through the system],
  [4 hours],
  [12 Oct 2025],
  [B],

  [14],
  [Create wireframes for the volunteer-facing screens],
  [Low-fidelity layouts for the feed, detail, records, leaderboard, and account screens],
  [5 hours],
  [18 Oct 2025],
  [B],

  [15],
  [Create wireframes for the organiser-facing screens],
  [Low-fidelity layouts for activity creation, management, and confirmation screens],
  [4 hours],
  [22 Oct 2025],
  [B],

  [16],
  [Design flowcharts for core processes],
  [Flowcharts for registration, joining, messaging, and confirmation flows],
  [4 hours],
  [26 Oct 2025],
  [B],

  [17],
  [Develop the test plan mapped to success criteria],
  [Test cases covering normal use, edge cases, and boundary conditions],
  [3 hours],
  [29 Oct 2025],
  [B],

  [18],
  [Conduct the second consultation with the client],
  [Show designs and wireframes to the client for feedback before development],
  [1 hour],
  [1 Nov 2025],
  [B],

  [19],
  [Transcribe the second consultation],
  [Document client statements for reference during adjustments],
  [3 hours],
  [3 Nov 2025],
  [B],

  [20],
  [Revise designs based on client feedback],
  [Updated wireframes, data model, and flows reflecting the client's input],
  [4 hours],
  [6 Nov 2025],
  [B],

  [21],
  [Present design document to supervisor and finalise],
  [Receive feedback and complete the Criterion B document],
  [2 hours],
  [10 Nov 2025],
  [B],

  // --- Criterion C: Development ---
  [22],
  [Set up the server project and database],
  [A running Rust server with PostgreSQL migrations and basic request handling],
  [3 hours],
  [15 Nov 2025],
  [C],

  [23],
  [Implement user authentication and session management],
  [Registration, login, bcrypt hashing, and session token issuance],
  [6 hours],
  [22 Nov 2025],
  [C],

  [24],
  [Implement activity CRUD and state machine],
  [Create, edit, cancel, and state-transition logic for activities],
  [8 hours],
  [1 Dec 2025],
  [C],

  [25],
  [Implement the capacity-protected join flow],
  [Transactional join with row-level locking to prevent overbooking],
  [5 hours],
  [6 Dec 2025],
  [C],

  [26],
  [Implement activity-scoped messaging],
  [Channel creation, membership checks, message sending, and retrieval],
  [6 hours],
  [14 Dec 2025],
  [C],

  [27],
  [Implement leaderboard and participation confirmation],
  [Aggregation query for ranking and organiser confirmation endpoint],
  [4 hours],
  [20 Dec 2025],
  [C],

  [28],
  [Build the SwiftUI activity feed and detail screens],
  [A working feed with filtering, search, and a detail view with join functionality],
  [8 hours],
  [5 Jan 2026],
  [C],

  [29],
  [Build the SwiftUI messaging, leaderboard, and account screens],
  [Chat interface, ranked leaderboard view, and account management],
  [7 hours],
  [15 Jan 2026],
  [C],

  [30],
  [Build the organiser tools in SwiftUI],
  [Activity creation form, management controls, and participation confirmation UI],
  [6 hours],
  [22 Jan 2026],
  [C],

  [31],
  [Build the admin panel (React)],
  [A web-based admin interface for system-level management and export],
  [5 hours],
  [28 Jan 2026],
  [C],

  [32],
  [Implement the export adapter],
  [Generate confirmed-hours data in a format compatible with school reporting],
  [3 hours],
  [1 Feb 2026],
  [C],

  [33],
  [Test the system against the design test plan],
  [Run all planned tests and document results],
  [4 hours],
  [6 Feb 2026],
  [C],

  [34],
  [Document technologies and techniques used],
  [Highlight programming concepts, libraries, and algorithmic approaches],
  [2 hours],
  [8 Feb 2026],
  [C],

  [35],
  [Complete the Criterion C document],
  [Justify the use of computational thinking and technical decisions],
  [5 hours],
  [12 Feb 2026],
  [C],

  // --- Criterion D: Functionality ---
  [36],
  [Write the screencast script],
  [A structured outline of what to demonstrate and in what order],
  [3 hours],
  [16 Feb 2026],
  [D],

  [37],
  [Record and edit the screencast],
  [A video demonstrating system functionality within the 7-minute limit],
  [4 hours],
  [20 Feb 2026],
  [D],

  // --- Criterion E: Evaluation ---
  [38],
  [Conduct the final meeting with the client],
  [Demonstrate the product and collect feedback on whether it meets their needs],
  [1 hour],
  [24 Feb 2026],
  [E],

  [39],
  [Transcribe the final consultation],
  [Document client feedback for use in the evaluation],
  [3 hours],
  [26 Feb 2026],
  [E],

  [40],
  [Complete the Criterion E document],
  [Evaluate success criteria against client feedback and identify areas for improvement],
  [6 hours],
  [3 Mar 2026],
  [E],
)
