# NS-5_continuity_01 — Accept sustained continuity and useful variation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Completion credit: 6 goal percentage points (1.20 overall points).
Current basis: [2026-09-29 outcome rebase](../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Execution status (2026-09-29): **Dependency-blocked**.
Next deliverable: Accept sustained multi-seed continuity and useful variation through actual complete outputs.
Closing evidence and stop condition: Full-duration join/repetition/source-use gates, timestamped listening and restart/block-size checks. Stop nearby repetition-guard variants after the recorded frozen failure; preserve poor passages.
Primary credit follows this task's north-star owner; downstream use earns no duplicate credit.
This reassessment closes no product criterion and preserves prior failures below.

Demonstrate sustained generated audio with acceptable joins and repetition across source recordings, independent of a genre verdict.

North star: NS-5. Outcome owner: WAV-04-CONTINUITY.
Historical allocation: 4 goal percentage points (0.80 overall points). One of the
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

- 2026-10-05, Big Boss: actual Studio feedback supplies a negative development
  listening result: abundant jittering and missing sustains, with continuity
  1/3, technical quality 1/3 and style fit 0/3. Repetition is unknown. The comment
  was placed at the 20-second audition's end; do not interpret it as a precisely
  timed defect. [studio_03](NS-6_studio_03.md) retains the response/readback scope.
  Its saved raw-acoustic policy uses 4,096-frame windows and 1,024-frame hops at
  48 kHz (about 85 ms / 21 ms), eight tokens and 32 retained source candidates
  from a 156.171-second selection. These settings identify a concrete path to
  assess; they do not prove a particular cause or a remedy. Preserve the exact
  failed output for a future fixed comparison of source continuity, candidate
  coverage and rendering. No new tuning batch is selected, no generic WFC defect
  is established, and the stopped sequence and prerequisite gates below remain.

- 2026-09-28 a distinct global repetition guard passed the predeclared frozen
  4,000-grain three-source gate after the failed chunk-local trial. The bounded
  Pascal renderer/guard/CLI now replay the full saved model with 1,899 source
  switches, 1,657 contiguous links, two immediate repeats and 610 repeated
  four-window sequences, against 3,969/0/4/636 without context. All tokens and
  exact per-source counts remain unchanged. Independent Win32/Win64 QA checked
  prefix decisions and original-PCM seam costs; PCM/model/report replay and a
  second output block size passed. The complete 256.192-second render is one
  pending manual listening item. The [guarded continuation checkpoint](../WAV-STUDIES.md#guarded-acoustic-continuation-checkpoint)
  and [work record](../WORK-HISTORY.md#global-repetition-guard-feasibility--2026-09-28)
  retain the frozen policy, hashes and limits. This is the second nonclosing
  batch: stop tuning this profile/seed and follow the actual vocabulary and
  context/evaluation blockers. Multi-seed/gap/level checks, sustained listener
  judgment and defect repair remain open; no continuity credit is earned.

- 2026-09-28 a prospective 4,000-grain three-source long-context trial stopped
  at its frozen repetition gate. The exact saved model and source counts stayed
  fixed; switches improved 3,969→1,373 and contiguous links 0→2,094, but
  repeated four-window sequences worsened 636→782 against a no-increase gate.
  An independent Pascal comparator checked original PCM seams, all 15 chunk
  joins, hashes and counts on Win32/Win64. The temporary opt-in implementation
  was reverted after failure; see the [work record](../WORK-HISTORY.md#bounded-long-context-continuity-trial--2026-09-28)
  and ignored `build/journal-long-context-20260928/`. Stop chunk-local context
  cap/length variants on this profile. This is one nonclosing quality batch,
  not a musical or listening verdict; all criteria and credit remain open.

- 2026-09-28 the bounded Pascal stream and replay prerequisite was split into
  [NS-5_continuity_02](DONE/NS-5_continuity_02.md) after the current 1,024-grain
  whole-render ceiling was confirmed. This task retains the full sustained
  quality and listening gates. No credit is earned by the split.

- 2026-09-28 independent QA accepted the bounded continuous 256.192-second
  backend and its two-target/block-size replay. The fixed development output
  has 3,969 source switches across 3,999 joins, so it supplies no positive
  musical-continuity verdict. This task still needs fixed-policy multi-seed
  quality, repetition/transition checks, real sustained listening and repairs.
