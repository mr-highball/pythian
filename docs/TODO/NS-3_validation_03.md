# NS-3_validation_03 — Accept selective Pascal pitch observations

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver an independently usable, Pascal-owned observation backend for the
supported WAV pitch range. This task owns selection, measurement semantics,
controlled discrimination and source-bound recorded development evidence.
The [supervised execution task](NS-3_validation_02.md) owns WAV preparation,
long-source budgets, process supervision and artifact publication after this
backend is accepted. This split moves 2 of the original 5 unearned NS-3 goal
points here; the two tasks retain the original 5 points together.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [three stopped Pascal hypotheses](NS-3_validation_02.md) ·
[phrase evaluation](../PHRASE-EVALUATION.md) ·
[work record](../WORK.md#periodic-support-recorded-stop-point--2026-09-22).

**Acceptance Criteria:**

- Select and document a Pascal-only backend, exact estimator identity,
  observation range, window geometry, support semantics and limits. All
  executable inference and maintained probes use owned Pascal with FPC/RTL;
  no external inference runtime or foreign-language model is a fallback.
- Provide a native `TInferenceBackend` implementation with finite bounded raw
  support, deterministic replay, silence/DC behavior, invalid-input rejection
  and explicit ambiguity. Controlled low-register 55/110-Hz tones and their
  0.3/0.2-amplitude mixture must retain both supports above 0.3; 110/165-Hz
  missing-55 and 220-Hz lower-octave cases must retain ambiguity above 0.3.
  These are measurement controls, not claims of two independently identified
  sources from a harmonic collision.
- On the hash-bound first 30 seconds of both Spring development parts, attain
  at least 80% reference pitch recall among the top 12 separated candidates
  at scored note centers, and mean count of support >=0.5 no greater than
  36/360 bins at both scored note and rest centers. For this 2048-sample
  centered window, score notes only when the center is at least 1024
  source-clock samples inside both boundaries; score rests only when the
  center is at least 1024 samples outside every note interval. Convert each
  reference onset to `ceil(seconds*16000)` and offset to
  `floor(seconds*16000)` before applying this rule. The earlier 50-ms rule
  belongs to the 1024-sample rejected observation and is not carried over.
  keep reference labels out of the producer and preserve exact source,
  reference, policy and output identities. Report reference support and rest
  activation diagnostics; do not silently equate a ranked hit with calibrated
  presence or note admission. Do not use untouched evaluation material for
  tuning.
- Run a checked stable FPC 3.2.2 backend probe of 3000 windows at 100 Hz in
  no more than 30 seconds, with explicit memory and zero-owned-leak evidence.
  Record extrapolation limits; sustained WAV job cost remains the execution
  task's acceptance condition.
**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-22 split from the reopened execution task after three nonclosing
  Pascal producer hypotheses. Absolute autocorrelation failed recorded
  specificity; 1024-point harmonic energy and 2048-point local-peak probes
  failed the fixed 55+110-Hz mixture control before recorded scoring. Exact
  counts and ignored build-log locations remain in the [parent task](NS-3_validation_02.md).
  The user raised the unsuccessful-attempt cap to four; this task inherits
  the current 3/4 ledger, not a new counter.

- Before a fourth hypothesis on the same producer cause, document a distinct
  evidence-backed decision, fixed evaluation policy and stop/switch condition.
  After a fourth unsuccessful attempt, reassess rather than run another
  estimator variation under this task.

- Fourth hypothesis frozen 2026-09-22 before implementation or Spring scoring:
  detect actual spectral local maxima from a Hann-windowed 2048-sample frame,
  using a zero-padded 8192-point Pascal Fourier transform only to interpolate
  peak frequency. Use positive FFT bins 1..4095 for power totals; a local
  maximum satisfies `P[k] >= P[k-1]` and `P[k] > P[k+1]`, with edge bins
  handled by their one available neighbor. Retain the strongest 64 maxima,
  breaking power ties by lower bin index. Interpolate each retained peak by
  a three-bin log-power parabola with offset clamped to [-0.5, 0.5] bins.
  Let `q = min(1, (maximum peak power / total positive-bin power) / 0.03)`;
  if the denominator is zero, return all zero. For each retained peak, direct
  support at a candidate grid pitch is `q * (peak magnitude / strongest peak
  magnitude) * exp(-0.5*(cents/35)^2)`, where 35 cents is Gaussian sigma.
  Aggregate paths with `max` and clamp to 0..1. A harmonic-2/3 pair qualifies
  when its two derived fundamentals differ by at most 35 cents; project their
  geometric-mean fundamental with support `0.4*q*min(relative magnitudes)`
  and the same Gaussian. A single harmonic-2 peak may support its lower
  octave with `0.4*q*relative magnitude` and the same Gaussian. No other
  subharmonic path is used; these ambiguity paths stay below 0.5. Do not treat a harmonic
  collision as proof of two sound sources. This changes the evidence
  representation: the failed probes divided candidate **power** by total
  spectral power and spread a neighborhood maximum over every pitch bin.
  First run the exact controlled checks in acceptance criterion 2, with
  checked stable FPC Win64/Win32 and the 3000-window <=30-second backend
  screen. If any control or cost gate fails, stop before Spring. If they
  pass, apply the same source-bound Spring recall/density thresholds with
  the fully contained-window center rule in criterion 3. If that fails,
  stop before an hour run. No parameter may be
  retuned using Spring labels; failure exhausts the four-attempt cap on this
  producer cause and requires a new strategy reassessment.
