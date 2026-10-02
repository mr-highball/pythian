# NS-6_studio_03 — Compare musical auditions and guide the next batch

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Let the sole operator classify generated music, describe defects and preferences,
compare batches, and explicitly prepare the next experiment through an intuitive
web workflow. Reuse durable listening decisions rather than create a second
answer store. See the [studio scope](../OPERATOR-STUDIO.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: [2026-09-30 operator allocation](../OPERATOR-STUDIO.md#allocation-and-ownership).
This owns usable feedback/iteration, not the scientific validity of style limits;
[evaluation_01](NS-5_evaluation_01.md) and evaluation_04 retain that acceptance.

Execution status: orientation and existing-collection prerequisites are accepted
in [studio_08](DONE/NS-6_studio_08.md). The actual operator verdict remains open. Independent
native and desktop/narrow QA passes the single/paired audition, response,
comparison, blind presentation, history and deliberate next-batch loop. Next
deliverable: the operator's understandable-purpose, audible-use and useful-feedback
verdict under AC5. Closing evidence remains real operator use with durable response
readback and preserved history/lineage. Stop at ambiguous purpose, missing
playback/Save state, unbound feedback or an unsupported control. This task remains
open; mechanical answers earn no musical verdict or completion credit.

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

- [NS-6_studio_08.md](DONE/NS-6_studio_08.md)
- [NS-6_studio_02.md](DONE/NS-6_studio_02.md)
- [NS-5_evaluation_03.md](DONE/NS-5_evaluation_03.md)

**Dev Notes:**

- 2026-10-02, Big Boss: the solo usability batch fixes the generated-audition
  feedback link to select its exact listening request, simplifies displayed
  answer vocabulary, and gives new requests a plain style-fit question.
  Browser playback/unknown Save pass; unavailable deep links no longer open an
  unrelated request. Existing request text/hash and serialized answers remain
  unchanged. AC2 still owns a discovered usability gap: the two-second authored
  source's declared-seed WFC rejection appears as a generic worker failure in
  Studio, although its retained failure evidence gives the cause. Explain this
  actionable failure without inventing a source-quality diagnosis or retrying
  different seeds. The eight-second authored control generates successfully.
  Evidence: `build/solo-usability/`, linked
  [solo review](../WORK.md#solo-operator-usability-repair--2026-10-01).
  These mechanical checks do not replace the operator verdict or earn credit.

- 2026-10-01, Neo: Salty's frozen final browser engineering PASS is retained in
  `build/salty-studio-browser-20261001/VERDICT.txt` and its identity packet. It
  includes single/paired playback, timestamp comments, unknown choices, blind
  payload/media masking, one durable lost-response retry, pinning without lost
  drafts, conflict/history and explicit next-batch preparation with no enqueue.
  The actual operator's musical/usefulness verdict remains open under AC5; no
  task credit, calibrated musical limit or untouched source family is claimed.

- 2026-10-01, Neo: native review sessions bind one or two verified generated
  outputs to server-randomized neutral sample aliases. Ordinary review payloads
  and listening-queue projection withhold alias assignments until a submitted
  response; withdrawal cannot undo exposure after reveal. Local files are not a
  secrecy boundary. Answers reuse the existing listening journals, with
  revision conflicts, identical lost-response retry, unknown choices, 0–3 word
  anchors and exact playhead comments. Pins have separate revisioned metadata.
  Next-batch preparation returns retained controls/corpus revision and parent
  identity without enqueueing, retraining or admitting generated audio.
- 2026-10-01, Neo: independent Salty native QA passes 42 checks on each stable
  Win32/Win64 target with zero leaks, including actual generated audio, blind
  payload exclusion, correction/withdrawal history, sticky reveal, pin/retry,
  five-event export, fresh verified-asset replay and identical reexport.
  Frozen evidence is under `build/salty-studio-native-20261001/`. The new Pascal
  browser module uses human audition labels, preserves unsaved answers during
  pinning, retains pending Save identity and awaits successful next-batch project
  loading before reporting preparation. Root's development browser loop passes;
  independent complete desktop/narrow QA and the actual operator's audible,
  understandable-purpose/usefulness verdict remain pending. Native submitted
  failures are zero. Frozen presentation creates no untouched holdout, calibrated
  musical limit or task credit.
- 2026-10-01, Neo: Big Boss's development desktop/narrow review loop passes
  comparison playback, feedback Save, pinning and next-batch preparation. The
  narrow layout repair removes the old two-column placeholder and constrains
  audio, fieldsets and identity text to the available width. This is retained
  development evidence; independent final browser QA and the operator's musical
  verdict remain separate requirements.

- 2026-09-30, Big Boss: a second unearned point transfers to effects preparation
  [studio_05](DONE/NS-6_studio_05.md). Generated feedback and deliberate next-batch
  requirements remain unchanged; derived sources retain their original family.

- 2026-09-30, Big Boss: one unearned NS-6 point transfers to the distinct private
  source-library/classification outcome [studio_04](DONE/NS-6_studio_04.md). All
  generated-feedback and iteration criteria above remain required. Source
  classifications and generated-output preferences remain separate evidence.

- 2026-09-30, Big Boss: one operator can define a caller-specific preference card;
  this does not require a universal genre panel. Reliable calibration still needs
  supported controls and separate candidate evaluation. Existing listening queues
  already persist scores/comments; missing responsibilities are batch comparison,
  deliberate iteration and actual blind presentation. No QA submissions yet.
