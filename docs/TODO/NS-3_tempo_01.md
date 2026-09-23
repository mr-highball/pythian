# NS-3_tempo_01 — Resolve beat level and phase from WAV observations

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Resolve stable and ambiguous beat-level/phase choices using source evidence rather than reference-selected bands, supplied BPM hints or agreement alone.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 5 goal percentage points (1.25 overall points).
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

- Use automatic candidate observations through the maintained candidate-path and selected-clock contracts, retaining plausible half/double-time and phase alternatives.
- Meet predeclared development accuracy and useful coverage limits on stable, deceptive, syncopated and polyrhythmic recordings, including current passing and failing cases.
- Distinguish absent pulses, distractor onsets and model omission; keep explicit uncertainty when evidence cannot resolve meter/beat level.
- Preserve true fast beats, stable instrumentation and the existing role-change control; a wrong candidate with perfect provider agreement must not be admitted merely for agreeing.
- Bind the reproducible policy/results to the shared validation contract and remain within bounded candidate/observation work.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- Stopped candidate (2026-09-21): source-accent structure improved acceleration and missing regular pulses but still failed authored polyphonic/changing-clock acceptance. Passing deception/polyrhythm cases did not justify adoption or tuning. See [comparison evidence](../BEAT-TRACKING.md#metrical-source-structure).

- Follow-up: distinguish metrical evidence from instrument/band changes and candidate omission. Provider agreement alone can favor the wrong beat level; retain half/double-time and phase alternatives.

- Stopped candidate (2026-09-23): even/odd per-band accent consistency did not
  expose the wrong fast polyphonic pulse; selected wrong candidates remained
  strongly parity-consistent, while the same factor damaged polyrhythm and
  doubling. The fixed nine-case comparison and source-bound reports are in
  [beat tracking](../BEAT-TRACKING.md#accent-parity-stopped). No tuning follows.
  At the two-batch checkpoint, require genuinely different evidence for metrical
  identity and explicit uncertainty before another task experiment.
