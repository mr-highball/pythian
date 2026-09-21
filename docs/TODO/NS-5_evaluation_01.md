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

**Acceptance Criteria:**

- Ground each style card in reference WAV observations across context, groove, harmony, bass/voice relationships, sound/envelope and phrase/section structure; mark required, optional and unsupported traits explicitly. Bind observations to verified recording/edition correspondence, exact intervals, annotation method and uncertainty. Missing required observations remain pending; catalogue tags and aggregate level statistics do not supply them.
- Define provider-specific quantitative trait/error/coverage criteria and uncertainty references, without deriving ground truth from the current unreliable inference.
- Specify the single-recording, unlearned and within-recording shuffled comparators and each provider's shuffle semantics, retaining song boundaries.
- Retain seeds 731/1731/2731, 120-second outputs, fixed listening positions, the existing 0..3 rubric and 15-second paired-edit protocol unless revised with a rationale before evaluation.
- Freeze the specification and demonstrate a controlled trait-preserving and trait-breaking comparison for each required provider dimension, with expected outcomes grounded independently of the learner. Reuse controls across cards where the measurement contract is identical; a loudness-only comparison does not qualify unrelated musical measures. Do not claim a listening verdict from this protocol work.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
