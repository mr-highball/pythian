# NS-3_tempo_02 — Reconstruct changing clocks and metrical structure

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Completion credit: 5 goal percentage points (1.25 overall points).
Current basis: [2026-09-29 outcome rebase](../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Execution status (2026-09-29): **Dependency-blocked**.
Next deliverable: Reconstruct finite changing tempo/meter/downbeat clocks and close the existing acceleration/doubling failures.
Closing evidence and stop condition: Frozen changing-clock reference comparisons, unknown coverage and exact source/music-time replay. Stop on lost stable cases or unsupported extrapolation.
Primary credit follows this task's north-star owner; downstream use earns no duplicate credit.
This reassessment closes no product criterion and preserves prior failures below.

Extend reliable beat evidence into changing tempo, phase, meter/downbeat and finite clock coverage, retaining ambiguity and gaps.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Historical allocation: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md) · [MUSIC-CONTEXT](../MUSIC-CONTEXT.md).

**Acceptance Criteria:**

- Resolve the existing doubling/acceleration and changing-pattern failures while retaining stable/polyrhythm/deception behavior from the preceding task.
- Evaluate supported meter/downbeat and tempo changes against independent annotations; distinguish a genuine musical change from a change of instrument or observation band.
- Account for observation-window support, overlapping evidence, missing pulses and endpoints; declare useful aligned coverage instead of silently extrapolating across rejected spans.
- Reconstruct finite clocks with explicit gaps/unknowns and correct source-to-musical-time mappings, including tempo changes inside sounding events.
- Meet the frozen development error/coverage limits and applicable work bounds with source-bound outputs suitable for independent evaluation.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
- [NS-3_tempo_01.md](NS-3_tempo_01.md)

**Dev Notes:**

- Follow-up from [tempo development](NS-3_tempo_01.md): source-accent improvements did not resolve changing-pattern/doubling acceptance. Preserve the previously passing stable, deception and polyrhythm controls when addressing changing clocks; see [beat tracking](../BEAT-TRACKING.md).
