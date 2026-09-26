# NS-5_evaluation_01 — Define measurable style cards and comparator contracts

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Complete the executable acceptance specification for chillwave, stoner rock and lofi before their final training/evaluation runs.

For this user-directed test, the three names designate personal style
preferences anchored by user-selected full mixes. The user confirmed holistic
fit on 2026-09-23. This is a positive development-source judgment, not a claim
about universal genre membership, verified song cuts, timed provider traits or
held-out evaluation recordings. Source-specific details remain in ignored local
records; the [working specification](../STYLE-CARDS.md) retains the common
measurement contract.

North star: NS-5. Outcome owner: CORPUS-SETUP / STYLE-EVAL.
Completion credit: 4 goal percentage points (0.80 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [LAYERED-STYLE](../LAYERED-STYLE.md).

In progress 2026-09-21: the [working specification](../STYLE-CARDS.md) defines
provider-specific comparator semantics and preserves the fixed listening packet.
A native distribution measure distinguishes generated-style fit from aligned
transcription scoring, retaining recording balance and missing-data coverage.
The original master-WAV level study supplies a controlled acoustic example.
Final checked Win32/Win64 numeric controls and native master-WAV studies pass;
evidence is retained in `build/qa-batch-03/`. Required genre reference assignments, musical annotations
and calibrated per-provider numerical criteria remain missing; this task stays
open with no partial credit. Those gaps are already within the criteria below.

Reference preparation 2026-09-21: two original acoustic-guitar WAV/JAMS pairs are
hash-bound for musical distribution controls, retaining external annotation
methods and uncertainties. Final checked Win32/Win64 QA accepts the private native
audit: 403/547 supplied notes, identical derived counts/frame rows and controlled
pitch/register distances within 1e-12 across targets. The nine-excerpt declared
boundary audit also passes, retaining the B-early crossing warning. These generic
development examples do not assign the requested
genres or calibrate their acceptance thresholds. See the
[reference screen](../STYLE-CARDS.md#reference-screening-and-musical-controls--2026-09-21).

The [candidate cards](../STYLE-CARDS.md#candidate-reference-cards) now bind one
existing WAV excerpt per intended style to exact bytes, declared work/catalogue
associations, acoustic observations and explicit missing musical fields. They
preserve development exposure and unresolved edition/recording correspondence;
no accepted genre label, independent group or calibrated threshold is inferred.
Those excerpt cards are historical screens. The current reference assignments
are the three user-selected complete mixes kept under ignored `build/`, with
holistic preference fit and exact WAV identities established but no verified
song cuts or timed musical annotations. Do not treat the old excerpts as the
user's preference references or publish the private mix identities here.

Retro 2026-09-21: this is the first ready NS-5 deliverable on resumption.
Reference annotations can be curator supplied or explicitly reviewed; they do
not depend on completing automatic transcription. First resolve recording/edition
correspondence and the missing musical observations in the existing candidate
cards, replacing unsuitable references if necessary. Record a concrete source or
reviewer blocker if those observations cannot be supplied. More aggregate level
reports alone cannot close the specification. This remains existing scope and
retains its original credit; no new diagnostic task is created.

Protocol criterion review 2026-09-22: the [comparator contracts](../STYLE-CARDS.md#required-measures-and-comparator-transformations)
specify single-recording and unlearned baselines and within-recording shuffle
semantics for each of the six required provider dimensions, retaining song and
compatible-context boundaries. The [fixed execution and listening packet](../STYLE-CARDS.md#fixed-execution-and-listening-packet)
retains seeds 731/1731/2731, full 120-second outputs, fixed listening positions,
the 0..3 rubric and seed-731 paired 15-second edits. Acceptance criteria 3 and 4
are ready for focused QA review. The exact shuffle permutation/seed derivation,
genre reference values, per-provider gates and controlled preserving/breaking
demonstrations remain with criteria 1, 2 and 5; this is not a frozen complete
genre specification or partial completion credit.

Permutation specification 2026-09-22: [RNG-free replay](../STYLE-CARDS.md#replayable-within-recording-permutation--specification-v1)
now fixes canonical unit order, SHA-256 seed-record bytes, digest ordering,
identity handling and within-song compatibility scopes for all six shuffled
comparators. It records every output-position-to-original-unit permutation;
one-unit scopes are unsupported. This advances criterion 3's reproducibility
contract without implementing the later evaluator or supplying missing genre
references. Focused protocol review is still required before claiming this
criterion closed; task credit remains zero.

Focused protocol QA 2026-09-22 closed the remaining specification ambiguities:
cross-bar held events merge touched same-scope bars transitively, while
cross-scope holds make the scope unsupported; a non-identity permutation that
changes no declared relationship is a reported no-effect/unsupported comparator,
never a passing shuffle. The source/seed byte record, seven distinct dimension
tags covering six rows and the separate bass/voice ablation, identity handling
and complete-unit scopes are now specified. **Criterion 3 is specified and
reviewed**; implementing the packet belongs to evaluation_02. Criteria 1, 2
and 5 still lack genre reference evidence and controls, so this task remains
open with zero credit.

Focused packet QA 2026-09-23: the [fixed execution and listening
packet](../STYLE-CARDS.md#fixed-execution-and-listening-packet) matches the
original [corpus protocol](../CORPUS-EVALUATION.md#generation-controls-and-listening-packet)
on seeds 731/1731/2731, retained 120-second outputs and full-duration scores,
complete seed-731 multi-recording listening, first-30-second positions for the
other seeds and matched baselines, the 0..3 rubric with reviewer timestamps,
and six seed-731 paired 15-second edits. No policy change was needed.
**Criterion 4's specification is met.** The generated packet and reviewer
verdicts belong to [evaluation_02](NS-5_evaluation_02.md); criteria 1, 2 and 5
remain open here, with no task credit.

**Acceptance Criteria:**

- Ground each style card in reference WAV observations across context, groove, harmony, bass/voice relationships, sound/envelope and phrase/section structure; mark required, optional and unsupported traits explicitly. Bind observations to verified recording/edition correspondence, exact intervals, annotation method and uncertainty. Missing required observations remain pending; catalogue tags and aggregate level statistics do not supply them.
- Define provider-specific quantitative trait/error/coverage criteria and uncertainty references, without deriving ground truth from the current unreliable inference.
- Specify the single-recording, unlearned and within-recording shuffled comparators and each provider's shuffle semantics, retaining song boundaries.
- Retain seeds 731/1731/2731, 120-second outputs, fixed listening positions, the existing 0..3 rubric and 15-second paired-edit protocol unless revised with a rationale before evaluation.
- Freeze the specification and demonstrate a controlled trait-preserving and trait-breaking comparison for each required provider dimension, with expected outcomes grounded independently of the learner. Reuse controls across cards where the measurement contract is identical; a loudness-only comparison does not qualify unrelated musical measures. Do not claim a listening verdict from this protocol work.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-25 distinct global-offset correspondence check resolved the first
  lofi candidate's repeated-passage ambiguity at three previously unused
  four-second interior positions. Checked Pascal signed-waveform correlation
  was 0.997953, 0.997374 and 0.997929 with the same -44-ms offset; self and
  one-second-shift controls, source hashes, byte limits and zero-leak checks
  passed Salty Boi's focused QA. The earlier local-best envelope check remains
  a failed method under its own frozen policy. Exact source identity, policy,
  controls and logs remain only in ignored
  `build/style-untracked-source/lofi-global-alignment/`. The new evidence
  supports interior audio-content correspondence for one development-exposed
  chapter, not its exact cut, whole-edition identity, an independent group or
  timed musical traits. Criteria 1, 2 and 5 and all task credit remain open;
  further source matching alone will not supply the missing musical traits.

- 2026-09-25 first lofi chapter correspondence attempt stopped under a
  pre-scored private policy. The separately published candidate has the same
  declared title and minute-rounded duration as the mix's first chapter.
  An independently acquired publisher stream and the mix were compared by
  checked Pascal at three fixed interior anchors plus a second-chapter
  control. Coarse RMS-envelope scores were 0.930659, 0.935263 and 0.920374,
  but the middle anchor's best isolated placement was 24.9 s later than its
  mix position; the other two had zero offset. This fails the frozen 0.5-s
  consistency gate. Waveform confirmation did not run. Exact media hashes,
  policy and zero-leak log are in ignored
  `build/style-untracked-source/lofi-first-match/`. Stop this candidate without
  retuning or asserting exact edition/cut identity. The style card's timed
  musical traits and criteria 1, 2 and 5 remain open; no credit is earned.

- 2026-09-23 progress checkpoint: since focused packet QA closed criterion 4,
  the private three-anchor recording-correspondence screen (the Dev Note below)
  and the source-independent groove control are two consecutive style-card
  batches without closing criteria 1, 2 or 5. The groove fixture is valid within its stated
  onset-occupancy scope, but more ungrounded controls cannot freeze provider
  gates or complete the six-dimension criterion while verified musical
  observations are missing. Stop this style-card investigation sequence. The
  next action follows the ready reusable-core reference prerequisite
  [NS-3_context_03](DONE/NS-3_context_03.md), whose reviewed no-key intervals feed
  automatic context admission and later style vocabulary. Return to the three
  personal style cards when independently bound source intervals and curator
  musical annotations can support criteria 1 and 2; then finish complete
  preserving/breaking controls under the grounded contract. No credit changes.

- 2026-09-23 source-independent groove control slice: the [native rhythm-admission
  fixture](../STYLE-CARDS.md#native-rhythm-admission-control-slice--2026-09-23)
  proves that existing onset-grid occupancy survives bounded timing jitter and
  changes when one event moves by a cell, with exact replay. This is one
  controlled subtrait only. Attributed roles, accents, microtiming, held events
  and inter-bar relationships are not measured by this fixture; criterion 5
  still requires complete preserving/breaking controls for each provider.
  No private genre source, task credit or acceptance changes.

- Existing limitation: master-WAV level controls and generic guitar annotation comparisons validate measurements, not the requested genre traits. Candidate cards still lack verified recording/edition correspondence and complete musical annotations; B/C endpoint hits also require source-quality review. See [candidate cards](../STYLE-CARDS.md#candidate-reference-cards).

- Follow-up on resumption: resolve the source/reference packet using curator or reviewed musical observations, then demonstrate preserving/breaking controls for every required provider dimension. Automatic transcription is not a prerequisite for reference annotation. Do not turn another level-only report into specification acceptance.

- 2026-09-22 source correspondence batch: checked the retained, hash-bound chapter declarations against published track listings. The containing chapters are 508, 166 and 228 seconds; published tracks are 509, 165 and 235 seconds respectively. The last candidate comes from a compilation labelled a later remaster. This bounds the review question but does not verify acoustic edition correspondence, cut points or musical traits. See [the correspondence screen](../STYLE-CARDS.md#recording-correspondence-screen--2026-09-22). No acceptance criterion closed. The exact unblock is an independently checked source/edition match (or replacement) and curator-reviewed annotations for the required dimensions. Stop further catalogue-only or level-only studies under this approach while that input is absent.

- 2026-09-22 isolated-source screen: the directly published standalone [Pro Sensory WAV](../STYLE-CARDS.md#pro-sensory-isolated-source-rejected--2026-09-22) was acquired and completely decoded with native Pascal. Its exact bytes, geometry, CC0 page, requested attribution and signal levels are bound. This was a new source family, never an authenticated match to C-early. Stop catalogue-only screening and seek listener review before assigning a genre.

- 2026-09-22 full-recording listener verdict: the user heard the entire
  standalone [Pro Sensory file](../STYLE-CARDS.md#pro-sensory-isolated-source-rejected--2026-09-22)
  and rejected it as a holistic chillwave reference, citing an off-style tempo
  feel and spooky/ominous sound. No clear beat, bass, lead or section-change
  times were identified. The first review batch established mood only; this
  second one decides the candidate is unsuitable. Neither closes a style-card
  criterion, so at the task-flow checkpoint stop the Pro Sensory route. Next
  finish the existing C-early candidate's recording/cut correspondence and
  seek a full-work style verdict on the [original three-video source set](../STYLE-CARDS.md#candidate-reference-cards),
  using any user-named exemplars to calibrate suitability before new
  acquisitions. The prior 30-second probes never established holistic genre
  suitability. Retain exact unknowns; do not lower the six required trait
  dimensions or award credit.

- 2026-09-23 preference scope: the user personally selected three complete
  private mixes and confirmed each meets their intended test style. These
  labels are personal preferences, not universal genre definitions. Pascal
  verified full-WAV identities and prepared private chapter review maps, but
  metadata cuts, timed musical traits and independent evaluation groups remain
  unverified. The acquisition/cache and review-packet batches close no criterion.
  Stop further source-metadata preparation at the task-flow checkpoint. The
  user's [core-first direction](../WORK.md#core-first-re-alignment--2026-09-23)
  defers detailed style-card review while general core work proceeds; seek their
  input for substantial playable or design checkpoints, not routine labels.

- Follow-up after focused packet QA: implement and review the generated packet
  under [evaluation_02](NS-5_evaluation_02.md) only after this style-card task's
  reference-grounded criteria 1, 2 and 5 close. Specification QA is not a
  listener verdict or style acceptance.

- 2026-09-23 private recording-correspondence screen: one declared chapter of a
  user-selected full mix was tested against a separately artist-published audio
  recording under a frozen three-anchor plus negative-control policy. Native
  Pascal envelope matching gave 0.825857, 0.887276 and 0.826554 at the three
  interior anchors, with inconsistent placements and nonunique matches; the
  second-chapter control scored 0.118660. The predeclared gate failed before
  waveform confirmation. Exact media, source identities, code and policy remain
  in ignored `build/`. Stop this source/edition match without retuning or
  counting a verified song group. This is one nonclosing batch after criterion
  4; reference-grounding criteria 1 and 2 and controlled criterion 5 stay open.
