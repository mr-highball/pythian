# NS-2_synthesis-quality_02 — Accept modulation, processing and routing quality

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-2)

**Description:**

Accept the audible behavior of supported modulation, filtering, dynamics, delay, reverb and bus combinations. Reuse the existing contract review and workload evidence instead of reopening every primitive.

North star: NS-2. Outcome owner: FUND-QUALITY.
Completion credit: 6 goal percentage points (1.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SYNTHESIS-QUALITY](../../SYNTHESIS-QUALITY.md) · [MODULATION](../../MODULATION.md) · [EFFECTS](../../EFFECTS.md) · [BUSES](../../BUSES.md).

**Completed 2026-09-23:** The [fixed processing/routing matrix](../../SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix) binds the current WAV identities, settings, native levels and comparison windows. The user heard the complete effects, control, spectral, modulated-delay, reverb and bus examples; they called the processing packet good overall and confirmed stereo-speaker playback. This accepts those declared tail, stereo-output and routing examples as heard, without inventing a distinct spatial-motion observation or fault timestamps. The lower-pitched 7.5-second modulation demo sounded good to the user. The high-carrier FM/PM file remains a numerical bandwidth stress case without a perceptual folded-band verdict. The only reported processing fault was the 3–6-second control-demo vibrato width; the maintained Pascal demo now uses +/-15 instead of +/-30 cents, and the user preferred the revised clip. Stable FPC 3.2.2 and development 3.3.1 Win32 renders are byte-identical; a Pascal PCM comparison found no sample changes outside that window and measured revised peak 0.124268. Existing focused [FM/PM bandwidth and stream checks](../../MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19), [effect history checks](../../EFFECTS.md), [modulated-delay replay](../../MODULATED-DELAY.md#verification-and-listening), [reverb partition checks](../../REVERB.md) and [bus replay](../../BUSES.md) verify the unchanged processing boundaries, explicit tails and headroom at the documented rates. The authored vibrato change does not alter a core block/rate contract or effect state. Acceptance is limited to the declared rendered settings and listening setup; source-family and combined-path quality remain in tasks 01 and 03. This earns +6 NS-2 points / +1.50 overall.

**Acceptance Criteria:**

- Cover the supported FM/PM, spectral motion, gain/pan/cutoff automation, filters, dynamics and effect/routing paths in a declared audition matrix with fixed levels and meaningful reference comparisons.
- Record actual listening verdicts for spectral motion, control changes, effect tails, stereo behavior and routing transitions; retain audible faults and timestamps.
- Resolve demonstrated defects without hiding them through arbitrary gain reduction or changed acceptance scope; verify relevant bandwidth, stability, headroom and state/replay boundaries.
- Verify accepted audible behavior survives the supported block-size/rate transitions affected by any fix, including continued effect history; reuse unchanged evidence where applicable.
- Document supported settings and limitations, and close this portion of FUND-QUALITY with reviewable audio and evidence.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

- 2026-09-23 lower-pitched modulation verdict: the user heard the existing
  hash-bound 7.5-second [modulation demo](../../MODULATION.md#earlier-additivefm-checkpoint)
  and said it was much better than the high-pitch stress example and believed
  it sounded good. Its 4.5–6-second FM and 6–7.5-second PM sections supply a
  favorable musical-range impression; the separate high-carrier folded-band
  measurement remains numerical and perceptually uncertain. No new render or
  core fix follows. The later stereo-speaker answer and evidence audit completed
  this declared processing task.

- 2026-09-23 finite-packet listener response: the user said the presented
  spectral, delay, reverb and bus examples sounded good overall, but found
  `measured-comparison.wav` a high-pitched sound with no clear listening target.
  Record the broad positive verdict without inventing per-case fault times or
  stereo-channel approval. The [high-carrier FM/PM clip](../../MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19)
  is a numerical bandwidth stress case; its audible comparison remains uncertain.
  The existing lower-pitched modulation demo's FM/PM sections are now offered
  for a meaningful sound-quality verdict. This follows the bounded packet
  reassessment without another comparison render. The later user response and
  stereo-speaker clarification closed the declared listening scope.

- 2026-09-23 effects listener checkpoint: the user heard the entire hash-bound
  six-second [dry/processed effects comparison](../../SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
  and said "effects sounds good." This supports that fixed filtering/dynamics
  setting but gives no separate tail, stereo or routing verdict. With the
  narrower-vibrato preference, two bounded processing-listening batches have
  closed no additional criterion. Reassess by finishing one finite review of
  the already rendered FM/PM, spectral, delay, reverb and bus cases, asking for
  broad verdicts and fault times only where something sounds wrong. Stop new
  comparison renders or isolated prompt variants; criterion 2 and credit stay open.

- 2026-09-23 control-curve listener follow-up: the user heard the original
  12-second oscillator/control comparison as good overall but found its
  3–6-second pitch wobble too wide. The [bound before/after render](../../MODULATION.md#listener-directed-vibrato-narrowing--2026-09-23)
  narrows only the demo's authored vibrato range from +/-30 to +/-15 cents.
  Checked stable/development Win32 outputs match exactly; a Pascal PCM check
  finds zero changes outside that three-second section and retains headroom.
  The core LFO and voice automation contracts are unchanged. The user then said
  the revised vibrato seems better. The standard demo WAV was regenerated with
  the revised hash, while the original remains available for comparison. This
  selects the preferred setting for this audition; other processing/routing
  verdicts and task credit remain open.

- Follow-up: existing processing auditions seeded the finite review matrix described in [synthesis quality](../../SYNTHESIS-QUALITY.md). The listener response and vibrato preference now close this bounded scope; broader settings are future consumer-specific checks.
- 2026-09-22 batch: completed acceptance criterion 1 by mapping existing FM/PM, spectral-motion, automation, filter/dynamics, modulated-delay, reverb, bus and integrated WAVs to fixed comparison levels, exact listening windows/settings and available SHA-256 identities in [the finite processing/routing matrix](../../SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix). The closing evidence is this matrix and the checked local artifact identities; no new render was necessary. Actual listening/verdicts and defect repair remained open at that checkpoint.
