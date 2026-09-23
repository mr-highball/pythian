# NS-5_evaluation_01 — Define measurable style cards and comparator contracts

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Complete the executable acceptance specification for chillwave, stoner rock and lofi before their final training/evaluation runs.

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

**Acceptance Criteria:**

- Ground each style card in reference WAV observations across context, groove, harmony, bass/voice relationships, sound/envelope and phrase/section structure; mark required, optional and unsupported traits explicitly. Bind observations to verified recording/edition correspondence, exact intervals, annotation method and uncertainty. Missing required observations remain pending; catalogue tags and aggregate level statistics do not supply them.
- Define provider-specific quantitative trait/error/coverage criteria and uncertainty references, without deriving ground truth from the current unreliable inference.
- Specify the single-recording, unlearned and within-recording shuffled comparators and each provider's shuffle semantics, retaining song boundaries.
- Retain seeds 731/1731/2731, 120-second outputs, fixed listening positions, the existing 0..3 rubric and 15-second paired-edit protocol unless revised with a rationale before evaluation.
- Freeze the specification and demonstrate a controlled trait-preserving and trait-breaking comparison for each required provider dimension, with expected outcomes grounded independently of the learner. Reuse controls across cards where the measurement contract is identical; a loudness-only comparison does not qualify unrelated musical measures. Do not claim a listening verdict from this protocol work.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- Existing limitation: master-WAV level controls and generic guitar annotation comparisons validate measurements, not the requested genre traits. Candidate cards still lack verified recording/edition correspondence and complete musical annotations; B/C endpoint hits also require source-quality review. See [candidate cards](../STYLE-CARDS.md#candidate-reference-cards).

- Follow-up on resumption: resolve the source/reference packet using curator or reviewed musical observations, then demonstrate preserving/breaking controls for every required provider dimension. Automatic transcription is not a prerequisite for reference annotation. Do not turn another level-only report into specification acceptance.

- 2026-09-22 source correspondence batch: checked the retained, hash-bound chapter declarations against published track listings. The containing chapters are 508, 166 and 228 seconds; published tracks are 509, 165 and 235 seconds respectively. The last candidate comes from a compilation labelled a later remaster. This bounds the review question but does not verify acoustic edition correspondence, cut points or musical traits. See [the correspondence screen](../STYLE-CARDS.md#recording-correspondence-screen--2026-09-22). No acceptance criterion closed. The exact unblock is an independently checked source/edition match (or replacement) and curator-reviewed annotations for the required dimensions. Stop further catalogue-only or level-only studies under this approach while that input is absent.

- 2026-09-22 isolated-source screen: the directly published standalone [Pro Sensory WAV](../STYLE-CARDS.md#provisional-isolated-chillwave-source--2026-09-22) was acquired and completely decoded with native Pascal. Its exact bytes, geometry, CC0 page, requested attribution and signal levels are bound. This is a provisional new chillwave candidate, not an authenticated match to C-early; hybrid genre suitability and all six musical annotation dimensions remain unreviewed. No criterion or credit closes. Stop screening more sources and seek review of the exact candidate before another reference batch.
