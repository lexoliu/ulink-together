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
  [[1] Registration with school email, name, class, avatar; bcrypt hashing.],
  [All fields accepted; database inspection confirmed hashed passwords. #emph[(Appendix 2, Q4.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[2] Role separation (student / teacher / admin); admin-only batch import and cohort rename.],
  [Each role saw the expected scope; admin tools were hidden from teachers. #emph[(Appendix 2, Q4.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[3] Publish activities with full detail; browse and search the feed.],
  [New activities reached the feed in seconds and were reachable via keyword search. #emph[(Appendix 2, Q4.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[4] Activity lifecycle state transitions.],
  [Forward transitions worked and propagated to volunteers, but illegal backward transitions are silently no-op'd instead of rejected with an error. Direction right, guard rails incomplete. #emph[(Appendix 2, Q4.)]],
  [#text(fill: partial-amber, weight: "bold")[◐]],

  [[5] Apply, withdraw, approve; capacity protection under concurrency.],
  [All three actions worked; full activities refused further applications. Concurrent stress testing was limited to a handful of simultaneous requests. #emph[(Appendix 2, Q2.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[6] Scoped chat with auto-archive on completion.],
  [Each activity had its own channel; completion locked the channel against further posts. #emph[(Appendix 2, Q2.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[7] Confirm minutes; hours updated on the student record.],
  [Confirmation wrote minutes onto the record and the student side refreshed without manual reload. #emph[(Appendix 2, Q2.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[8] Leaderboard derived from confirmed records.],
  [Ranking updated as confirmations were entered because totals are summed, not stored. #emph[(Appendix 2, Q4.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[9] ISMAS CSV export, global and per-activity.],
  [Both export paths produced files matching the ISMAS column order. #emph[(Appendix 2, Q2.)]],
  [#text(fill: success-green, weight: "bold")[✓]],

  [[10] Landscape-only iPad client.],
  [Portrait is not declared in the build settings, so iPadOS refuses to rotate. #emph[(Appendix 2, Q4.)]],
  [#text(fill: success-green, weight: "bold")[✓]],
)

= Recommendations for Future Improvements

#emph[NOTE: Recommendations 1--4 are drawn from client suggestions in Appendix 2, Q6. Recommendation 5 addresses the SC-4 gap identified above.]

1. #text(weight: "bold")[Scheduled pre-activity reminders.] The notification pipeline has no scheduler; a time-based reminder a day before each approved activity would close the "I forgot" gap. #emph[(Appendix 2, Q6.)]

2. #text(weight: "bold")[Hour targets and progress tracking.] Configurable per-student goals against the graduation requirement would turn the records screen into a progress tracker. #emph[(Appendix 2, Q6.)]

3. #text(weight: "bold")[Multi-language support.] An English/Chinese localisation layer would help students less comfortable with English. #emph[(Appendix 2, Q6.)]

4. #text(weight: "bold")[School calendar integration.] Syncing activity dates with the school calendar would avoid clashes with exams. #emph[(Appendix 2, Q6.)]

5. #text(weight: "bold")[Explicit illegal-transition errors (SC-4 gap).] Return a typed error when a backward state transition is attempted and surface it in the UI, so the behaviour is auditable instead of a silent no-op.

6. #text(weight: "bold")[Reset the login error banner on edit.] The sign-in banner persists while the user is already typing the correct password; dismissing it on the first keystroke would make the form feel responsive. #emph[(Appendix 2, Q6.)]

#block(fill: rgb("#1d5d99"), inset: 8pt, width: 32%)[
  #text(fill: white)[Word Count: #total-words]
] <no-wc>
