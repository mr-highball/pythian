# NS-3_tempo_01 — Resolve beat level and phase from WAV observations

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Resolve stable and ambiguous beat-level/phase choices from qualified candidate
evidence, using source support rather than reference-selected bands, supplied
BPM hints or agreement alone. [NS-3_tempo_04](NS-3_tempo_04.md) owns bounded
candidate availability before this task selects the musical pulse.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 3 goal percentage points (0.75 overall points), after
splitting 2 of the original 5 points to [NS-3_tempo_04](NS-3_tempo_04.md).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md) · [BEAT-GRIDS](../BEAT-GRIDS.md).

Progress 2026-09-21: a fixed metrical source-structure comparison is declared
under the [experiment budget](../MUSICAL-EVALUATION.md#fixed-next-experiment-budgets).
The [source-accent comparison](../BEAT-TRACKING.md#metrical-source-structure)
improves acceleration and restores missing regular pulses, preserving deception
and polyrhythm. It still fails authored polyphonic/changing-clock acceptance;
reject general adoption without tuning. Controls and final source/recurrence,
ablation-parity and resource audits passed QA. An audit-only precision correction
retained the original 1e-9 tolerance and all saved predictions. This task remains
open with no credit.

The subsequent [accent-parity experiment](../BEAT-TRACKING.md#accent-parity-stopped)
also failed its frozen gate: the authored polyphonic source reached zero matches,
polyrhythm fell from .986301 to .395604 F1, and doubling regressed. Its uniform
fast/alternating controls passed and every prior ablation path replayed. This is
the second nonclosing metrical batch; stop parity/recurrence variants and
reassess the evidence model before another experiment.

**Acceptance Criteria:**

- Consume the accepted, source-bound [candidate pool](NS-3_tempo_04.md)
  through the maintained candidate-path and selected-clock contracts; select
  a musical beat level and phase without dropping the other plausible
  half/double-time or competing-phase explanations from the saved evidence.
- Meet predeclared development accuracy and useful coverage limits on stable, deceptive, syncopated and polyrhythmic recordings, including current passing and failing cases.
- Distinguish absent pulses, distractor onsets and model omission; keep explicit uncertainty when evidence cannot resolve meter/beat level.
- Preserve true fast beats, stable instrumentation and the existing role-change control; a wrong candidate with perfect provider agreement must not be admitted merely for agreeing.
- Bind the reproducible policy/results to the shared validation contract and remain within bounded candidate/observation work.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
- [NS-3_tempo_04.md](NS-3_tempo_04.md)

**Dev Notes:**

- Stopped candidate (2026-09-21): source-accent structure improved acceleration and missing regular pulses but still failed authored polyphonic/changing-clock acceptance. Passing deception/polyrhythm cases did not justify adoption or tuning. See [comparison evidence](../BEAT-TRACKING.md#metrical-source-structure).

- Follow-up: distinguish metrical evidence from instrument/band changes and candidate omission. Provider agreement alone can favor the wrong beat level; retain half/double-time and phase alternatives.

- Stopped candidate (2026-09-23): even/odd per-band accent consistency did not
  expose the wrong fast polyphonic pulse; selected wrong candidates remained
  strongly parity-consistent, while the same factor damaged polyrhythm and
  doubling. The fixed nine-case comparison and source-bound reports are in
  [beat tracking](../BEAT-TRACKING.md#accent-parity-stopped). Frozen historical
  model outputs were diagnostic inputs to Pascal code, not a native model
  provider; future adopted evidence must be Pascal-owned end to end. No tuning follows.
  At the two-batch checkpoint, require genuinely different evidence for metrical
  identity and explicit uncertainty before another task experiment.

- 2026-09-23 split: candidate availability, omission accounting and bounded
  native pool delivery now belong to [tempo_04](NS-3_tempo_04.md), an actual
  prerequisite to choosing beat level/phase here. The source-accent and parity
  failures remain stopped. This task retains the selection, uncertainty,
  development accuracy and shared-validation criteria and 3 of its original
  5 goal points. The two tasks together retain the original 5 points; no
  criterion, capability or milestone credit closes from the split.
