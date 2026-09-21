# NS-2_synthesis-quality_02 — Accept modulation, processing and routing quality

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-2)

**Description:**

Accept the audible behavior of supported modulation, filtering, dynamics, delay, reverb and bus combinations. Reuse the existing contract review and workload evidence instead of reopening every primitive.

North star: NS-2. Outcome owner: FUND-QUALITY.
Completion credit: 6 goal percentage points (1.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md) · [MODULATION](../MODULATION.md) · [EFFECTS](../EFFECTS.md) · [BUSES](../BUSES.md).

**Acceptance Criteria:**

- Cover the supported FM/PM, spectral motion, gain/pan/cutoff automation, filters, dynamics and effect/routing paths in a declared audition matrix with fixed levels and meaningful reference comparisons.
- Record actual listening verdicts for spectral motion, control changes, effect tails, stereo behavior and routing transitions; retain audible faults and timestamps.
- Resolve demonstrated defects without hiding them through arbitrary gain reduction or changed acceptance scope; verify relevant bandwidth, stability, headroom and state/replay boundaries.
- Verify accepted audible behavior survives the supported block-size/rate transitions affected by any fix, including continued effect history; reuse unchanged evidence where applicable.
- Document supported settings and limitations, and close this portion of FUND-QUALITY with reviewable audio and evidence.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

- Follow-up: existing processing auditions can seed the finite review matrix described in [synthesis quality](../SYNTHESIS-QUALITY.md). Obtain actual effect/routing listening observations before deciding which fixes are necessary; additional renders alone do not close acceptance.
