# NS-3_notes_03 — Accept independent phrases and feed saved learning

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Freeze combined pitch/presence/boundary inference, accept supported independent recordings and use their admitted events in the saved learner and actual WFC generation.

North star: NS-3. Outcome owner: WAV-03-PHRASES.
Completion credit: 5 goal percentage points (1.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [PITCH](../PITCH.md) · [WAVE-STYLE](../WAVE-STYLE.md).

**Acceptance Criteria:**

- Freeze the combined maintained inference and admission policy after both note-development tasks pass; protect held-out phrase material until then.
- Meet per-supported-recording coverage >=80%, precision >=98%, onset F1 >=0.80 and full-note F1 >=0.70 under the existing timing/edge protocol; report wrong, false-rest and unknown results separately.
- Run actual waveform controls and verify final native fidelity/cost; a score from an ignored diagnostic cannot substitute for the maintained path.
- Retain admitted pitch/kind/duration, source timing and excluded tracking gaps in saved evidence; unknowns split or explicitly mark learning rather than invent transitions.
- Reload the resulting style, solve actual WFC passes and reconstruct an audible native passage with traceable learned versus authored behavior. Polyphonic ownership remains a separate task.

**Blockers**

- [NS-3_notes_01.md](NS-3_notes_01.md)
- [NS-3_notes_02.md](NS-3_notes_02.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)

**Dev Notes:**

- 2026-09-23 development preview failure localization: the user's 30-second
  Pythian preview stumbled in both pitch and timing. A private, source-bound
  Pascal comparison uses published performed-note annotations for the same
  development Spring flute excerpt, rather than claiming WAV inference. Its
  first frozen monophonic packet stopped on a 1-ms annotation overlap before
  output. One revised policy preserved all published intervals in direct
  native synthesis and clipped four 1-ms overlaps only in the monophonic WFC
  training view. Checked Win32/Win64 produced identical direct and generated
  WAV hashes with zero leaks; the generated 256-span WAV/sidecar replay
  byte-identically. The paired listening packet and exact boundaries are in
  [WORK](../WORK.md#substantial-generated-development-preview--2026-09-23).
  These reference-conditioned outputs await a listener verdict and cannot
  satisfy automatic recorded-note or independent phrase acceptance. No task
  credit changes.
- Follow-up: use the combined maintained identity/presence path only after both prerequisite tasks pass. The preferred development flute precision remains 91.57% against 98%; violin's passing development result is not independent acceptance. Keep reserved phrase material untouched until the final policy freeze; see [phrase evidence](../PHRASE-EVALUATION.md).

- Integration follow-up: the [scale workload](NS-5_scale_01.md) still needs this task's admitted-note-to-saved-learner bridge. Raw salience and private diagnostic outputs cannot substitute for it.
