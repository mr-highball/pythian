# NS-3_tempo_02 — Reconstruct changing clocks and metrical structure

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Extend reliable beat evidence into changing tempo, phase, meter/downbeat and finite clock coverage, retaining ambiguity and gaps.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md) · [MUSIC-CONTEXT](../MUSIC-CONTEXT.md).

**Acceptance Criteria:**

- Resolve the existing doubling/acceleration and changing-pattern failures while retaining stable/polyrhythm/deception behavior from the preceding task.
- Evaluate supported meter/downbeat and tempo changes against independent annotations; distinguish a genuine musical change from a change of instrument or observation band.
- Account for observation-window support, overlapping evidence, missing pulses and endpoints; declare useful aligned coverage instead of silently extrapolating across rejected spans.
- Reconstruct finite clocks with explicit gaps/unknowns and correct source-to-musical-time mappings, including tempo changes inside sounding events.
- Meet the frozen development error/coverage limits and applicable work bounds with source-bound outputs suitable for independent evaluation.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)
- [NS-3_tempo_01.md](NS-3_tempo_01.md)

