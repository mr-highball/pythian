# NS-5_continuity_01 — Accept sustained continuity and useful variation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Demonstrate sustained generated audio with acceptable joins and repetition across source recordings, independent of a genre verdict.

North star: NS-5. Outcome owner: WAV-04-CONTINUITY.
Completion credit: 4 goal percentage points (0.80 overall points). One of the
original 5 unearned NS-5 points belongs to the independently useful
[bounded continuation backend](DONE/NS-5_continuity_02.md). Both tasks retain the
original 5 NS-5 points / 1.00 overall point; this task still owns the full
multi-source/seed quality, listening and repair outcome below.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAV-STUDIES](../WAV-STUDIES.md) · [ACTIVITY](../ACTIVITY.md) · [LEARNED-STREAMS](../LEARNED-STREAMS.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

**Acceptance Criteria:**

- Run fixed-policy multi-recording and multi-seed generation with full-duration continuity, source-use and repetition measurements, including repetition spanning segment boundaries.
- Compare joins, repeated grains/events, gaps, level transitions and long-term reuse against predeclared criteria; bounded continuation alone is insufficient.
- Record actual sustained listening observations and timestamps, retaining poor passages rather than selecting only favorable excerpts.
- Resolve demonstrated continuity/diversity defects while preserving admitted events, source boundaries and required timing/role relationships; route DSP defects to their synthesis owner.
- Verify restart/continuation and block-size behavior for the changed path within declared budgets. Final style tasks must repeat the verdict on their own style outputs.

**Blockers**

- [NS-5_continuity_02.md — DONE](DONE/NS-5_continuity_02.md)
- [NS-5_corpus_01.md](DONE/NS-5_corpus_01.md)
- [NS-5_vocabulary_01.md](NS-5_vocabulary_01.md)
- [NS-2_synthesis-quality_03.md — DONE](DONE/NS-2_synthesis-quality_03.md)

**Dev Notes:**

- 2026-09-28 the bounded Pascal stream and replay prerequisite was split into
  [NS-5_continuity_02](DONE/NS-5_continuity_02.md) after the current 1,024-grain
  whole-render ceiling was confirmed. This task retains the full sustained
  quality and listening gates. No credit is earned by the split.

- 2026-09-28 independent QA accepted the bounded continuous 256.192-second
  backend and its two-target/block-size replay. The fixed development output
  has 3,969 source switches across 3,999 joins, so it supplies no positive
  musical-continuity verdict. This task still needs fixed-policy multi-seed
  quality, repetition/transition checks, real sustained listening and repairs.
