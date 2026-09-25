# NS-5_scale_01 — Establish executable many-hour semantic workload budgets

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Turn the current long-file ingestion evidence into a measured multi-recording training workload with explicit operational limits.

North star: NS-5. Outcome owner: CORPUS-SCALE.
Completion credit: 3 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

The bounded multi-recording raw observation stream and its measured workload
now belong to [NS-5_scale_03](NS-5_scale_03.md), with 1 of this task's original
4 unearned NS-5 points. This task retains the semantic aggregation, capacity,
whole-pipeline budgets and reload outcome. All five original criteria remain
represented across the two tasks; accepting raw salience does not satisfy an
admitted-note or trained-style gate. The full scale outcome remains a blocker
for [NS-5_scale_02](NS-5_scale_02.md).

Starting evidence: [WAV-STUDIES](../WAV-STUDIES.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md).

Execution planning must account for the selected observation adapter's complete
source verification on every job, even when its processing scope is shorter
than the input WAV. Include that cost across recordings and jobs; an accepted
one-hour scope would not establish an arbitrary-length input or corpus budget.
If conversion or segmentation is needed to meet the existing setup limits,
include preparation/storage cost and retain original-source lineage and exact
coordinate mappings. This is part of the existing whole-pipeline criteria below,
not permission to skip identity checks or raise limits after measurement.

Review clarification 2026-09-21: each successful observation job hashes the full
input both at initialization and before sink completion. The proposed three-job
long recording incurs six full source hashes; the two pilot jobs add four.
Account separately for initial verification, final source verification, assets
and output-artifact checks within the unchanged whole-job/pipeline budgets.
The initial preparation's one-hash-per-job wording is corrected in its workload
record. This remains existing acceptance scope, with no new task or credit.

The former external-runtime execution passed its historical hour and supervision
checks, but the user's Pascal-only requirement reopens the producer prerequisite.
Retain those measurements for provenance; do not apply their costs to the new
producer or treat this scale task as unblocked.

Preparation 2026-09-21: [the prospective workload](../CORPUS-SCALE.md) binds
three development inputs and 2.3222053373 unique source-clock hours, with explicit
source verification, preparation, storage and capacity ceilings. No new benchmark
has run. The selected raw-observation path has no admitted-note-to-learner bridge;
that existing responsibility belongs to NS-3_notes_03. The task remains open with
zero completion credit. Genre quality and independent song coverage are not added
as prerequisites for operational measurement.

**Acceptance Criteria:**

- Use the accepted raw corpus packet, then declare admitted-event density and all remaining stages through semantic learning before the full benchmark.
- Freeze whole-pipeline wall-time, peak-memory, cache/storage, model-state and dependency-work budgets for the selected admission and training contracts; keep one-file conversion and raw observation costs separately visible.
- Exercise real multi-recording admitted-event aggregation and actual WFC semantic learning with verified identity/exposure, without counting a short excerpt or duplicate observation as many-hour training.
- Resolve or explicitly reject inputs exceeding whole-array, training or model capacities while retaining original-coordinate song, recording and unknown boundaries; do not simply raise private caps.
- Publish a reproducible complete native workload and measurements for recovery/scale work; raw observation qualification alone and current provider accuracy do not establish semantic acceptance.

**Blockers**

- [NS-5_corpus_01.md](DONE/NS-5_corpus_01.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)
- [NS-5_scale_03.md](NS-5_scale_03.md)
- [NS-3_notes_03.md](NS-3_notes_03.md)

**Dev Notes:**

- 2026-09-25 task-flow split after two nonclosing preparation/capacity batches:
  [NS-5_scale_03](NS-5_scale_03.md) now owns the independently usable
  source-bound raw corpus reader and actual five-job observation workload.
  This task still requires accepted note admission and actual semantic learning
  under the complete original pipeline budgets. Its remaining credit is
  +3 NS-5 / +0.60 overall; the raw task owns +1 / +0.20. No completion or
  scorecard change follows from splitting the task.

- Planning correction (2026-09-21): successful observation jobs hash the whole input at initialization and again before sink completion, even for a shorter requested scope. Include both passes plus preparation/storage in whole-pipeline budgets; see [workload](../CORPUS-SCALE.md).

- Follow-up: the prepared 2.3222053373-hour workload has not run as semantic training. [notes_03](NS-3_notes_03.md) owns the missing admitted-note-to-learner bridge. The formerly accepted external-runtime one-hour observation benchmark does not close this task.

- 2026-09-22: [native execution](DONE/NS-3_validation_02.md) was reopened for a Pascal-only producer and then accepted with fresh density, setup, memory and hour-cost evidence. This task must still measure the whole multi-recording semantic workload; the old TensorFlow C run is historical only.

- 2026-09-23: The checked Win32 whole-array `pythian.learn` rejected the full prepared WAV-C (527081868 bytes) at its 256000044-byte preflight, before frame decoding or output creation; see [capacity record](../CORPUS-SCALE.md#missing-admission-and-capacity-boundaries). The source also exceeds the 64000000-scalar sample limit, but that later guard was not exercised. This closes no scale criterion: training/model capacities and multi-recording semantic learning still require the [recorded-note bridge](NS-3_notes_03.md). Stop repeating whole-array rejection probes; follow that prerequisite.
