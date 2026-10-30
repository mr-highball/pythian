> **Retired — 2026-10-29.** Historical unfinished ticket; no current effort or acceptance. See [disposition/replacement](README.md) and the [active goal](../../../GOAL.md). The original body below is historical, not an implementation instruction.

# NS-6_studio_03 — Compare musical auditions and guide the next batch

[Task index](legacy-catalog.md) · [Task flow](../../../history/TASKFLOW-2026-10-29.md) · [North star](../../../history/MILESTONES-2026-10-29.md#ns-6)

**Description:**

Let the sole operator classify generated music, describe defects and preferences,
compare batches, and explicitly prepare the next experiment through an intuitive
web workflow. Reuse durable listening decisions rather than create a second
answer store. See the [studio scope](../../../history/OPERATOR-STUDIO-2026-10-29.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: [2026-09-30 operator allocation](../../../history/OPERATOR-STUDIO-2026-10-29.md#allocation-and-ownership).
This owns usable feedback/iteration, not the scientific validity of style limits;
[evaluation_01](NS-5_evaluation_01.md) and evaluation_04 retain that acceptance.

Execution status (2026-10-29): the short comparison's saved After preference now
has a published two-minute follow-up through
[reviewed-feedback lineage — DONE](../../DONE/NS-6_studio_25.md). Original/Before/After
and one continuity question are ready without further segmentation or generation
setup. The older4:16 repetition review remains a distinct pending experiment.
Existing negative evidence and all saved answers remain intact. Big Boss owns
the purpose and subsequent explicit development decision.
Next deliverable: the operator's longer-comparison answer and durable readback,
plus the remaining actual browser/playback/iteration qualification. The old
single still declares missing Original context. Neither experiment inherits an
answer or supplies a broad style/continuity verdict.
The exact-source-successor core integration is tracked separately in
[continuity_04](NS-5_continuity_04.md). Existing queue/review mechanisms must be
reused. Closing evidence remains real operator use with durable response readback
and preserved output/source/task lineage. Stop at ambiguous purpose, missing
playback/Save state, unbound feedback or unsupported controls. This task remains
open; engineering checks earn no musical verdict or completion credit.

**Acceptance Criteria:**

- AC1: Review single/paired generated passages with a plain-language purpose and
  declared source/reference context. Offer caller-defined style-fit choices,
  separate continuity/repetition/technical-quality judgments, preference with
  neither/unsure options, and optional playhead-based comments. Explain 0–3
  anchors in words; no automatic/preselected answer or mandatory frame editing.
  Prepared experiments name the core task, what changed and the specific
  listening decision in plain language. Present original context with the
  before/after question in one review flow, rather than require an unrelated
  reference-playback answer first. Loading a prepared review must not require
  the operator to configure or generate another batch.
- AC2: Compare current and earlier batches, with relevant changed controls,
  actual learning coverage, failures and unknowns visible. Let the operator pin
  useful results, correct feedback and reopen history without changing original
  audio. Preserve revision-checked saved responses through reload/export/report.
  Use the existing queue for technical-ready generated experiments, one question
  at a time. Distinguish defects in joins/sustains, repetition and style fit;
  do not ask a broad style question when the experiment tests only continuity.
  Keep poor musical results as evidence and avoid padding the queue with seed
  variants or turning one comparison into several manual-review items.
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

- [Reviewed-feedback follow-up lineage — DONE](../../DONE/NS-6_studio_25.md) — native producer support for AC3; exact-Before comparisons retain their existing contract.
- [Failed response construction cleanup — DONE](../../DONE/NS-6_studio_23.md).
- [Publication-time replacement check — DONE](../../DONE/NS-6_studio_24.md).
- [Original/generated source comparison](NS-6_studio_22.md) — repairs AC1's missing audible source context.
- [NS-6_studio_08.md](../../DONE/NS-6_studio_08.md)
- [NS-6_studio_02.md](../../DONE/NS-6_studio_02.md)
- [NS-5_evaluation_03.md](../../DONE/NS-5_evaluation_03.md)

**Dev Notes:**

- 2026-10-29, Big Boss: [studio_25](../../DONE/NS-6_studio_25.md) supplies AC3's native
  explicit reviewed-feedback binding without weakening the existing exact-Before
  parent. One new two-minute comparison retains the reviewed short result's
  model, source selection and seed, with no training or tuning. Frozen mechanism
  and block replay pass; actual isolated preparation binds the submitted answer
  revision/hash and preserves every existing response. Both examples are new
  two-minute renders, not an assertion that the old20-second media simply loops.
  Compatible live delivery is verified at exact8ffc516/CI491; actual operator/
  browser and the full workflow criteria remain open. The pending
  older4:16 guard is a separate experiment; no answer or musical credit transfers.

- 2026-10-27, Big Boss: the retained 256.192-second guard experiment was absent
  from the current catalog, contrary to later handoffs based on historical
  packets. Its audio/model/report and ordered source lineage are verified; a
  copied isolated catalog now presents one question: does it get stuck repeating
  the same short loop? There is no bound Original, and no unrelated reference
  or saved short-comparison preference is substituted. The maintained factory
  now accepts generated singles as well as pairs, with optional exact Original
  context. Native Win32/Win64 checks and 29 authored pas2js DOM checks pass;
  actual browser qualification remains open. The fixes are deployed. Automatic
  approval review initially rejected the final live append without a specific
  reason. The user then explicitly approved publication. The normal native
  `listen-stage`/`listen-append` succeeded, with one projected pending item and
  three completed items. An identical append leaves the queue byte-identical;
  all earlier answers and six request identities are preserved. The new single
  remains revision0, with no inherited or agent-authored response. No alternative
  route or browser workaround was used. Source metadata/answer preservation is
  independently checked; root and Spiegel also read the live HTTP projection
  successfully.
  Evidence: E-drive `runs/feedback-readiness-20261027-boss`,
  `runs/feedback-readiness-20261027-spiegel-qa` and
  `runs/guard-lineage-20261027-spiegel`, plus final
  `runs/review-publication-20261027-*`. No new audio or operator answer was made.

- 2026-10-27, Big Boss: the operator completed the prepared review and its
  durable revision1 reads back with choice After. This demonstrates a useful
  answer through the assigned one-question bridge; it does not establish every
  desktop/narrow/control or full musical-iteration criterion. Spike independently
  inspected the native/queue implementation and prior evidence, without claiming
  a new execution or browser pass. No operator response was authored by an agent.

- 2026-10-26, Big Boss: prepared experiments now use the existing immutable
  listening queue and answer journals. One short question, Original/Before/After
  tabs, Before/After/Same/Neither/Unsure choices, optional timestamp note and
  Save/Next replace the separate original-reference answer plus verbose A/B
  setup. Existing audio, requests and responses stay intact. Completed prepared
  experiments continue to hide their superseded setup questions. The producer
  command is documented in [full-output listening](../../../FULL-OUTPUT-LISTENING.md#prepared-core-experiments).
  The actual listener passes 17 Pascal DOM checks, including a lost successful
  Save response, one-write reconciliation, restored answer and audio-source
  release. Native/API checks pass on copied operator data. Actual desktop/narrow
  browser qualification is blocked by desktop-control access failure; it is not
  a pass. The next operator action is one curated continuity comparison, without
  new segmentation or generation setup. This task and its credit remain open.

- 2026-10-26, Big Boss: the operator has supplied long recordings and is willing
  to classify/listen, but cannot reasonably hand-segment them into training truth
  and cannot find a useful generated-review queue. One existing successor A/B
  and its separate original reference are pending in the catalog; their presence
  does not establish discoverability or comprehensible intent. Reuse this real
  comparison to close the prepared-review flow before creating more variants.
  Whole-recording/coarse passage labels are valid source preferences; exact
  note/beat truth and supported semantic learning remain with NS-3/NS-5 owners.
  Current raw generation retains classifications as metadata and saved feedback
  does not automatically retrain a preference model. Explain that briefly and
  link each review to a deliberate core decision. No new review or render was
  produced in this assessment; the earlier scientific stops remain in force.

- 2026-10-05, Big Boss: the operator's first Studio comparison response is
  durably submitted at revision 1 and reads back through the live review API.
  The 20-second audition received style fit 0/3, continuity 1/3 and technical
  quality 1/3; style classification and repetition remain unknown. The comment
  reports abundant jittering and missing sustains, preventing a coherent track.
  Its marker is at the end of the audition, not a precisely localized defect.
  This is actual listening evidence and useful defect feedback, not musical
  acceptance or an explicit verdict on the complete iteration UI. The saved
  output predates the runtime repair; it used 156.171 seconds of selected audio,
  eight tokens and 32 retained candidates. Private response/output identities
  remain in the operator catalog and ignored `build/navigation-review/`.
  [continuity_01](NS-5_continuity_01.md) owns the musical defect; do not ask the
  operator to relabel this result or treat longer training as a demonstrated fix.

- 2026-10-02, Big Boss: [studio_18](../../DONE/NS-6_studio_18.md) repairs the operator's
  scrolling/help-placement feedback with tabs, contextual modals, paired-sample
  views and appropriate save bars. Isolated browser checks preserve feedback and
  next-batch routing. AC5 still needs actual operator musical/usefulness review;
  a UI repair does not supply that verdict or earn this task's completion credit.


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
  [solo review](../../../WORK.md#solo-operator-usability-repair--2026-10-01).
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
  [studio_05](../../DONE/NS-6_studio_05.md). Generated feedback and deliberate next-batch
  requirements remain unchanged; derived sources retain their original family.

- 2026-09-30, Big Boss: one unearned NS-6 point transfers to the distinct private
  source-library/classification outcome [studio_04](../../DONE/NS-6_studio_04.md). All
  generated-feedback and iteration criteria above remain required. Source
  classifications and generated-output preferences remain separate evidence.

- 2026-09-30, Big Boss: one operator can define a caller-specific preference card;
  this does not require a universal genre panel. Reliable calibration still needs
  supported controls and separate candidate evaluation. Existing listening queues
  already persist scores/comments; missing responsibilities are batch comparison,
  deliberate iteration and actual blind presentation. No QA submissions yet.
