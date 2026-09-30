# NS-3_tempo_03 — Accept automatic timing on independent recordings

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Completion credit: 4 goal percentage points (1.00 overall points).
Current basis: [2026-09-29 outcome rebase](../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Execution status (2026-09-29): **Dependency-blocked**.
Next deliverable: Close independent timing acceptance through the maintained native consumer.
Closing evidence and stop condition: Frozen per-recording accuracy/coverage, native time/memory and saved clock replay. Stop on any required held-out failure; tuning requires fresh groups.
Primary credit follows this task's north-star owner; downstream use earns no duplicate credit.
This reassessment closes no product criterion and preserves prior failures below.

Freeze the supported automatic timing path and obtain a separate-recording verdict through the maintained native consumer.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Historical allocation: 3 goal percentage points (0.75 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md) · [WAVE-CONTEXT-ADMISSION](../WAVE-CONTEXT-ADMISSION.md).

**Acceptance Criteria:**

- Freeze estimator, preprocessing, metrical-selection, reconstruction and admission policy before opening the untouched timing evaluation set.
- Pass the predeclared per-recording timing/coverage limits, including supported stable/changing cases and ambiguity controls; report every failure and unknown without oracle rate/band selection.
- Verify the final maintained path's throughput, memory and candidate work on the actual evaluation geometry.
- Persist measured/admitted timing and policy/source identities through the existing context interfaces; replay selected output clocks deterministically.
- Record independent acceptance or leave this task open. Any tuning from evaluation requires fresh untouched evaluation material and an explicit new freeze.

**Blockers**

- [NS-3_tempo_02.md](NS-3_tempo_02.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)

**Dev Notes:**

No failed approaches or follow-ups recorded yet.
