# NS-5_scale_01 — Establish executable many-hour workload budgets

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Turn the current long-file ingestion evidence into a measured multi-recording training workload with explicit operational limits.

North star: NS-5. Outcome owner: CORPUS-SCALE.
Completion credit: 4 goal percentage points (0.80 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAV-STUDIES](../WAV-STUDIES.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md).

Execution planning must account for the selected observation adapter's complete
source verification on every job, even when its processing scope is shorter
than the input WAV. Include that cost across recordings and jobs; an accepted
one-hour scope would not establish an arbitrary-length input or corpus budget.
If conversion or segmentation is needed to meet the existing setup limits,
include preparation/storage cost and retain original-source lineage and exact
coordinate mappings. This is part of the existing whole-pipeline criteria below,
not permission to skip identity checks or raise limits after measurement.

**Acceptance Criteria:**

- Declare representative source counts, unique hours, rates/channels, event/feature density and all stages from decoding through semantic learning before benchmark runs.
- Set practical wall-time, peak-memory, cache/storage, model-state and dependency-work budgets for the selected native inference path; separate one-file conversion from whole-pipeline cost.
- Exercise real multi-recording data with verified identity/exposure and bound the feature/event aggregation path; do not claim many-hour training from a short excerpt or duplicated observations.
- Identify and resolve or explicitly reject inputs exceeding whole-array, training or model capacities without simply raising private caps.
- Publish a reproducible native workload and measurements that the recovery/scale task can use; provider accuracy remains governed by NS-3.

**Blockers**

- [NS-5_corpus_01.md](DONE/NS-5_corpus_01.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)
