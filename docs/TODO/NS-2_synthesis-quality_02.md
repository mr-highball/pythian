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

- 2026-09-23 effects listener checkpoint: the user heard the entire hash-bound
  six-second [dry/processed effects comparison](../SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
  and said "effects sounds good." This supports that fixed filtering/dynamics
  setting but gives no separate tail, stereo or routing verdict. With the
  narrower-vibrato preference, two bounded processing-listening batches have
  closed no additional criterion. Reassess by finishing one finite review of
  the already rendered FM/PM, spectral, delay, reverb and bus cases, asking for
  broad verdicts and fault times only where something sounds wrong. Stop new
  comparison renders or isolated prompt variants; criterion 2 and credit stay open.

- 2026-09-23 control-curve listener follow-up: the user heard the original
  12-second oscillator/control comparison as good overall but found its
  3–6-second pitch wobble too wide. The [bound before/after render](../MODULATION.md#listener-directed-vibrato-narrowing--2026-09-23)
  narrows only the demo's authored vibrato range from +/-30 to +/-15 cents.
  Checked stable/development Win32 outputs match exactly; a Pascal PCM check
  finds zero changes outside that three-second section and retains headroom.
  The core LFO and voice automation contracts are unchanged. The user then said
  the revised vibrato seems better. The standard demo WAV was regenerated with
  the revised hash, while the original remains available for comparison. This
  selects the preferred setting for this audition; other processing/routing
  verdicts and task credit remain open.

- Follow-up: existing processing auditions can seed the finite review matrix described in [synthesis quality](../SYNTHESIS-QUALITY.md). Obtain actual effect/routing listening observations before deciding which fixes are necessary; additional renders alone do not close acceptance.
- 2026-09-22 batch: completed acceptance criterion 1 by mapping existing FM/PM, spectral-motion, automation, filter/dynamics, modulated-delay, reverb, bus and integrated WAVs to fixed comparison levels, exact listening windows/settings and available SHA-256 identities in [the finite processing/routing matrix](../SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix). The closing evidence is this matrix and the checked local artifact identities; no new render was necessary. Stop after this criterion: actual listening/verdicts and any defect repairs remain open because listening is unavailable in this handoff.
