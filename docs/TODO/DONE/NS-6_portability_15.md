# NS-6_portability_15 — Preserve passage records during portable rendering

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Repair the primary multi-source passage renderer's record ownership on pas2js.
Its validation `for..in` borrows an array record; subsequent assignment to the
same loop variable overwrites the last caller passage on the generated target.
The final passage then plays the wrong source and coordinates. Native value
semantics hide this failure. Keep one primary Pascal implementation.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This is a required prerequisite discovered while qualifying
[observed cloning20](../NS-6_observability_20.md), not musical learning acceptance.

Completed2026-10-29 at exact384c6de8720120f6c148409157a56bde9f95e8b5 after
[CI495](https://github.com/mr-highball/pythian/actions/runs/40969357621/job/123781900528)
passes in20m53s, including maintained integration and extracted consumers.
All original criteria below are satisfied. This closes the portability defect;
the clone prerequisite's upstream and downstream gates remain separate.

Criterion: preserve caller records and exact selected audio on native and actual
pas2js. Deliverable: primary renderer repair and the unchanged independent PCM
oracle plus explicit input-preservation/replay assertions. Stop on another
distinct required gap; do not weaken sample equality or fork a browser renderer.

**Acceptance Criteria:**

- Retain the actual pas2js failure and identify its primary ownership cause.
  Preserve source and interval identity throughout validation and rendering;
  never mutate caller passage rows or source audio.
- Repair the existing portable renderer without a second target implementation
  or altered fade, source-selection, clock or bounds policy.
- Execute the existing multi-source PCM oracle, explicit unchanged-input and
  repeat-render checks on native32/64 and actual pas2js. Retain source-switch,
  contiguous same-source joins, fades and invalid-late-passage rejection.
- Pass exact downstream integration and clean extracted primary consumers.
  Update links and accounting together after all criteria pass. No musical
  completion credit follows from this zero-credit portability repair.

**Blockers**

- None for implementation. Exact downstream qualification remains required.

**Dev Notes:**

- 2026-10-29, Big Boss: exact CI495 is terminal SUCCESS. Clean exact Win64
  core/full ZIPs verify107/159 owned units and120/280 content hashes; actual
  consumers of each extracted primary source pass59 exact checks on native64
  and pas2js. Native32/64 and actual pas2js source fixtures pass, preserving
  the original measured multi-source PCM oracle and adding caller-input/replay
  assertions. A core-only negative control compiles the original renderer and
  rejects it at runtime for `Caller record changed`; no WFC is involved.
  Native heaps are clean. The other core record foreach sites do not reuse
  the borrowed row in this way; no unrelated implementation was changed.
  Original syntax/PCM failures, pre-repair source and all logs stay in the
  private sequence-model-clone-20261029-boss packet. Counts55/94→54/95,
  NS6 17→16 open;52.45/47.55 unchanged. Whole task closure resets delivery
  nonclosing1→0; scientific stops/exposures never reset. No live deployment,
  operator answer, inference or browser/phone acceptance is included.
- Big Boss: indexed validation repairs the borrowed-record alias in the primary
  renderer. The existing event consumer passes its original exact PCM oracle
  plus input-preservation/replay checks on native32/64 and actual pas2js. A
  core-only external fixture passes59 exact checks on all three targets, with
  native heaps clean. Its maintained integration entry is added beside the
  original passage suite. Exact downstream and extracted qualification remain
  open; no task move, credit or counter reset is earned yet.
- 2026-10-29, Big Boss SOLO: actual portable event-corpus execution reaches
  successful clone start/final cancellation and retry, then its original PCM
  oracle rejects frame8: actual approximately -0.176776695296637, expected0.25.
  Generated output shows validation assigning the `for..in` row by reference,
  followed by `$assign` into that same borrowed final row during rendering.
  Native32/64 pass the original oracle. Private E-drive
  sequence-model-clone-20261029-boss retains the unchanged failure logs and
  pre-repair primary source. This prerequisite is selected before changing the
  renderer; clone20 stays open. No inference, deployment or response changes.
