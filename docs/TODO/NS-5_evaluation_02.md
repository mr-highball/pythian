# NS-5_evaluation_02 — Implement the complete style comparison and listening packet

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Implement the declared style protocol as a reproducible native comparison workflow before opening each style's frozen evaluation set.

North star: NS-5. Outcome owner: STYLE-EVAL.
Completion credit: 4 goal percentage points (0.80 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

**Acceptance Criteria:**

- Produce multi-recording, preselected single-recording, unlearned and within-recording shuffled baselines with matched provider scope, renderer and output-level policy.
- Implement each required provider-specific trait measure and full-duration unknown, contribution, repetition, join and structural reports; validate them against independent controls.
- Generate all 120-second seed cases and prescribed listening positions, plus seed-731 paired 15-second key/BPM/rhythm/bass/voice/sound edits.
- Extend the Pascal workbench queue to present generated full-duration and
  paired audio, with continuous playback, the declared 0–3 trait rubric,
  timestamped comments and an explicit saved reviewer decision. Return those
  decisions to the Pascal producer before counting a listening packet. A
  30-second source annotation request alone does not complete a sustained
  music review.
- Verify saved reload, blend and further-blend comparisons with inherited/selected traits, ancestry-overlap accounting and unchanged independent states/audio.
- Bind complete outputs to corpus splits, source/model/policy/parameter hashes and frozen criteria; require actual reviewer scores rather than automatically inferred listening verdicts.

**Blockers**

- [NS-5_evaluation_01.md](NS-5_evaluation_01.md)
- [NS-4_integration_01.md](NS-4_integration_01.md)
- [NS-5_scale_02.md](NS-5_scale_02.md)
- [NS-5_continuity_01.md](NS-5_continuity_01.md)
- [NS-5_structure_02.md](NS-5_structure_02.md)

**Dev Notes:**

- 2026-09-28 the open-task annotation audit separated source-local labels
  from sustained generated-output listening. The source workbench currently
  fetches at most 30 seconds per audio region and has no structured 0–3
  trait response. This task owns the future continuous 120-second and paired
  operator feedback loop before any style listening acceptance. No generated
  listening packet or reviewer score was added by the annotation extension.
