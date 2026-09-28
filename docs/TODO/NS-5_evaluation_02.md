# NS-5_evaluation_02 — Implement the complete style comparison protocol

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Implement the declared style protocol as a reproducible native comparison
workflow before opening each style's frozen evaluation set. Consume the
reusable full-output listening packet from
[NS-5_evaluation_03](NS-5_evaluation_03.md); this task owns the actual style
outputs, matched controls, trait measures and reviewer-grounded verdicts.

North star: NS-5. Outcome owner: STYLE-EVAL.
Completion credit: 2 goal percentage points (0.40 overall points), after
assigning 2 of the original 4 unearned NS-5 points to the reusable
[listening packet](NS-5_evaluation_03.md). The combined allocation remains
4 NS-5 points (0.80 overall points), with no duplicate credit.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

**Acceptance Criteria:**

- Produce multi-recording, preselected single-recording, unlearned and within-recording shuffled baselines with matched provider scope, renderer and output-level policy.
- Implement each required provider-specific trait measure and full-duration unknown, contribution, repetition, join and structural reports; validate them against independent controls.
- Generate all 120-second seed cases and prescribed listening positions, plus seed-731 paired 15-second key/BPM/rhythm/bass/voice/sound edits.
- Publish the generated full-duration and paired cases through the accepted
  reusable listening packet. Apply the declared 0–3 trait rubric and fixed
  positions, then consume actual saved, timestamped reviewer decisions through
  its Pascal report before counting a style listening packet. A source-local
  annotation or an authored packet-QA answer is not that verdict.
- Verify saved reload, blend and further-blend comparisons with inherited/selected traits, ancestry-overlap accounting and unchanged independent states/audio.
- Bind complete outputs to corpus splits, source/model/policy/parameter hashes and frozen criteria; require actual reviewer scores rather than automatically inferred listening verdicts.

**Blockers**

- [NS-5_evaluation_01.md](NS-5_evaluation_01.md)
- [NS-5_evaluation_03.md](NS-5_evaluation_03.md)
- [NS-4_integration_01.md](NS-4_integration_01.md)
- [NS-5_scale_02.md](NS-5_scale_02.md)
- [NS-5_continuity_01.md](NS-5_continuity_01.md)
- [NS-5_structure_02.md](NS-5_structure_02.md)

**Dev Notes:**

- 2026-09-28 the open-task annotation audit separated source-local labels
  from sustained generated-output listening. The source workbench currently
  fetches at most 30 seconds per audio region and has no structured 0–3
  trait response. The reusable single/paired packet, streaming and saved
  response moved to NS-5_evaluation_03; this task retains the style-specific
  execution and actual reviewer-scored result. No generated listening packet
  or reviewer score was added by the annotation extension or this split.
