# NS-5_evaluation_01 — Define measurable style cards and comparator contracts

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Complete the executable acceptance specification for chillwave, stoner rock and lofi before their final training/evaluation runs.

North star: NS-5. Outcome owner: CORPUS-SETUP / STYLE-EVAL.
Completion credit: 4 goal percentage points (0.80 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [LAYERED-STYLE](../LAYERED-STYLE.md).

**Acceptance Criteria:**

- Ground each style card in reference WAV observations across context, groove, harmony, bass/voice relationships, sound/envelope and phrase/section structure; mark required, optional and unsupported traits explicitly.
- Define provider-specific quantitative trait/error/coverage criteria and uncertainty references, without deriving ground truth from the current unreliable inference.
- Specify the single-recording, unlearned and within-recording shuffled comparators and each provider's shuffle semantics, retaining song boundaries.
- Retain seeds 731/1731/2731, 120-second outputs, fixed listening positions, the existing 0..3 rubric and 15-second paired-edit protocol unless revised with a rationale before evaluation.
- Freeze the specification and demonstrate that the references/measures distinguish at least one controlled trait-preserving case from a trait-breaking case. Do not claim a listening verdict from this protocol work.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)

