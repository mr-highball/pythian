# NS-3_context_03 — Qualify local-key and unknown reference intervals

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver a reusable, source-bound recorded reference packet for local key,
changes, no-key and ambiguous intervals before evaluating automatic admission.
Researcher whole-loop labels and score-level gaps alone cannot supply all of
these acoustic interval labels. This task owns reference qualification; the
key decision and its measured accuracy remain in
[NS-3_context_01](NS-3_context_01.md).

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Completion credit: 1 goal percentage point (0.25 overall points), split from
the original 4 points of NS-3_context_01. Credit is earned only when every
acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [local-key reference study](../TONAL.md#local-key-reference-candidate) ·
[authored negative screen](../TONAL.md#authored-tonal-negative-screen--2026-09-23) ·
[recorded percussion screen](../TONAL.md#percussion-only-recording-screen--2026-09-23) ·
[stopped loop qualification](../TONAL.md#loop-level-reference-qualification-stop--2026-09-23).

**Acceptance Criteria:**

- Bind accessible recorded audio, source editions, authors/performers, notices,
  licenses, exact bytes and annotation methods for at least two distinct tonal
  recording groups and two distinct no-key or ambiguous recording groups.
  Verify that each selected annotation refers to the acquired recording; a
  title, uploader tag, automatic pre-analysis or unverified score transfer is
  insufficient.
- Publish reviewed source-clock intervals for stable supported keys, genuine
  key changes and no-key/ambiguous regions. Retain alternate annotators,
  disagreements, transitional spans, timing uncertainty and unsupported modes.
  Do not relabel annotation gaps, percussion-only descriptions or a loop-level
  key as an expert local-key verdict without interval evidence.
- Freeze development and independent evaluation roles by recording/composition
  group before any admission scoring. Preserve source exposures and prevent a
  repeated performance, derivative or adjacent excerpt from crossing groups.
- Supply a Pascal reader/checker that reproduces interval and label boundaries,
  source identities, coordinate mappings and group isolation from the acquired
  assets. Keep media and generated output under ignored `build/`; tracked
  provenance and policy must allow another checkout to reacquire them.
- Show that the packet can score supported key, unknown and change behavior
  separately with coverage denominators. The packet itself selects no key
  algorithm or confidence threshold and earns no inference-accuracy credit.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-23 split rationale: two nonclosing local-key batches exposed a
  distinct reference gap. One performed drum cadence has only source-level
  percussion description. A later frozen four-loop screen found multiple
  researcher labels and selectively extracted exact WAVs, but one intended
  positive's uploader filename claims a conflicting root; all loop labels are
  whole-clip, with automatic pre-analysis suggestions. The packet stopped
  before key scoring. See the [source record](../TONAL.md#loop-level-reference-qualification-stop--2026-09-23).
  This task owns the independently useful source/interval packet; context_01
  retains all decision, calibration, unknown-coverage and independent-accuracy
  obligations. Original unearned credit is redistributed 1+3, with no points
  earned by creating this task.
