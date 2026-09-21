# NS-3_parts_04 — Deliver simultaneous-role scoring and reproducible controls

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Deliver the maintained measurement and authored-control foundation for mixture
learning: source-bound per-role scoring, overlapping intervals, reviewed-reference
construction and an executable native control packet. External musical annotation
and recording-family qualification remain in [parts_01](../NS-3_parts_01.md).

North star: NS-3. Outcome owner: WAV-03-PARTS.
Completion credit: 1 goal percentage points (0.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [role measures and packet](../../PART-EVALUATION.md),
[interval measures](../../OVERLAPPING-NOTES.md), [reviewed-reference API](../../PART-REFERENCE.md),
[file consumer](../../EVALUATION-OPERATOR.md) and [frozen policy](../../PART-MIXTURE-POLICY.md).

This task was split from the original parts_01 on 2026-09-21 in response to the
task-size reassessment. One of its two unearned NS-3 points is assigned here;
one remains with the external packet. The
[criterion reconciliation](../../MILESTONES.md#mixture-preparation-task-split) retains
all former requirements and downstream prerequisites. This deliverable was
implemented after the accepted baseline and has earned no previous task credit.

Completed 2026-09-21: final QA verifies all five criteria against current maintained
source at checkpoint `711ab4cbcdc06c54a35341dc978f7dcbb62983e5`; twelve current
identities match their tested hashes. Stable checked Win32/Win64 evidence covers
the 4096-case per-role oracle, overlapping assignment/boundary cases and file
integration. Native authored construction, exact replay and overwrite preservation
pass; the reference builder passes both targets and the actual external draft
consumer. Commands, toolchain flags, identities and zero-leak results remain in
`build/qa-batch-14/` through `build/qa-batch-18/`; the final criterion/identity audit
and new draft replay are in `build/qa-batch-22/`. Applicable evidence was reused
without redundant runtime suites. Portable boundaries, notices, documented gates
and diagnostic-only independent eligibility are preserved.

This accepts maintained measurement/control capability only. External reference
qualification, inference accuracy, listening and genre acceptance remain open.
Credit is the redistributed **1 NS-3 / 0.25 overall point**, with no duplicate
credit: NS-3 37% → 38%, overall 62.65% → 62.90%.

**Acceptance Criteria:**

- Deliver portable maintained per-role simultaneous-pitch, coverage, precision, leakage and crossing measures with explicit uncertain/unassigned states, bounded work and preserved caller inputs; validate independently specified expected results and rejection boundaries.
- Deliver overlapping-note onset/full timing measures and source-bound file integration, retaining repeated same-pitch event identities, half-open clocks, uncertainty and edge exclusions, deterministic assignment and declared resource limits; validate both supported native targets.
- Deliver maintained interval-to-center reference construction and its native file consumer, verifying draft/source identities, complete grids, exact known/rest/uncertain semantics and rejection preservation without inferring annotations or publishing self-scores as accuracy.
- Publish a reproducible native authored stem/mix packet covering bass/chordal/lead/other, simultaneous chords, crossings, overlap/unison, quiet-source contrast, rests and uncertainty. Verify stored-sample construction, scripted error cases, event timing, exact replay and overwrite preservation with full identities and notices.
- Document the supported measurement contract, existing per-role gates, reproduction commands and boundaries between authored controls, external references and learner acceptance. Keep generated assets ignored, the core independent of WFC/inference/playback, and part diagnostics unable to grant independent mixture acceptance.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)
