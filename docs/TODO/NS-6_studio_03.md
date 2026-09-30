# NS-6_studio_03 — Compare musical auditions and guide the next batch

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Let the sole operator classify generated music, describe defects and preferences,
compare batches, and explicitly prepare the next experiment through an intuitive
web workflow. Reuse durable listening decisions rather than create a second
answer store. See the [studio scope](../OPERATOR-STUDIO.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 4 goal percentage points (0.40 overall points).
Basis: [2026-09-30 operator allocation](../OPERATOR-STUDIO.md#allocation-and-ownership).
This owns usable feedback/iteration, not the scientific validity of style limits;
[evaluation_01](NS-5_evaluation_01.md) and evaluation_04 retain that acceptance.

Execution status: follows studio_02. Next deliverable is one complete audition,
response, comparison and deliberately changed next-batch loop. Closing evidence:
real operator use, durable response readback, preserved history and reproducible
next-batch lineage. Stop at ambiguous question intent, missing playback/Save state,
unbound feedback or an unsupported control; do not request unexplained markers.

**Acceptance Criteria:**

- AC1: Review single/paired generated passages with a plain-language purpose and
  declared source/reference context. Offer caller-defined style-fit choices,
  separate continuity/repetition/technical-quality judgments, preference with
  neither/unsure options, and optional playhead-based comments. Explain 0–3
  anchors in words; no automatic/preselected answer or mandatory frame editing.
- AC2: Compare current and earlier batches, with relevant changed controls,
  actual learning coverage, failures and unknowns visible. Let the operator pin
  useful results, correct feedback and reopen history without changing original
  audio. Preserve revision-checked saved responses through reload/export/report.
- AC3: Prepare an explicit next batch from a reviewed one: retain its corpus/model
  or deliberately change source selection, supported controls or seeds. Explain
  the change before enqueueing and preserve parent lineage. A preference Save
  cannot silently retrain, admit generated audio as new independent source truth,
  or rewrite the previous model/evaluation policy.
- AC4: Separate guided development/calibration from a frozen evaluation mode.
  Where blind comparison is requested, mask variant/model identities in the
  operator-facing payload and presentation until the declared reveal point while
  preserving auditable assignment. Do not promote reviewed development families
  to untouched evaluation or use candidate outputs to choose their own limits.
- AC5: Independently test desktop/narrow keyboard/touch playback, comparison,
  timestamp comment, uncertainty, Save/retry/conflict/reload and next-batch
  preparation. Obtain the actual operator's understandable-purpose, audible-use
  and useful-feedback verdict. Mechanical test answers are not musical verdicts;
  physical-path evidence can be shared with authoring_02 without duplicate credit.

**Blockers**

- [NS-6_studio_02.md](NS-6_studio_02.md)
- [NS-5_evaluation_03.md](DONE/NS-5_evaluation_03.md)

**Dev Notes:**

- 2026-09-30, Big Boss: one operator can define a caller-specific preference card;
  this does not require a universal genre panel. Reliable calibration still needs
  supported controls and separate candidate evaluation. Existing listening queues
  already persist scores/comments; missing responsibilities are batch comparison,
  deliberate iteration and actual blind presentation. No QA submissions yet.
