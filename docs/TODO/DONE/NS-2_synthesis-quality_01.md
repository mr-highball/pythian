# NS-2_synthesis-quality_01 — Accept source and articulation quality

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-2)

**Description:**

Accept the audible behavior of the supported oscillator, wavetable, sample and measured-instrument paths. Existing numerical checks are baseline evidence; use their auditions and the supplied listener preview to identify concrete source/articulation defects.

North star: NS-2. Outcome owner: FUND-QUALITY.
Completion credit: 8 goal percentage points (2.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SYNTHESIS-QUALITY](../../SYNTHESIS-QUALITY.md) · [FUNDAMENTALS](../../FUNDAMENTALS.md) · [SOURCES](../../SOURCES.md) · [INSTRUMENTS](../../INSTRUMENTS.md).

**Completed 2026-09-23:** The [finite source matrix and acceptance scope](../../SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01) bind the oscillator, additive/PM, wavetable, sampled percussion, authored loop, measured profile, glide, envelope and paired-performance audio to source settings and output hashes. The user heard the complete 0–5-second family demo and 0–6.3-second loop demo and said both sounded okay; the 0–30-second paired preview was coherent; the isolated 0–6.72-second measured profile was smooth. They then heard all four hash-bound 8/48-kHz measured stationary/glide and envelope packets (0–22 and 0–14.5 seconds at each rate) and said they all sounded good. The review prompt named clicks, rough pitch changes, unwanted noise and cut-off endings; no fault time was reported. These are broad full-interval judgments, not separate per-note findings. No source/articulation defect was demonstrated in these examples, so no source fix or before/after render was warranted.

The retained [measured-instrument reference checks](../../INSTRUMENTS.md#measured-instrument-quality-checkpoint--2026-09-19) cover 264 sampled static/glide conditions at 8/16/44.1/48 kHz, and the [envelope checkpoint](../../INSTRUMENTS.md#measured-envelope-and-layer-checkpoint--2026-09-19) covers 81 gate/zone/rate conditions at 8/22.05/48 kHz. The [sample-loop checks](../../SOURCES.md#sample-loop-and-automation-quality-checkpoint--2026-09-19) cover 18 linear/sinc motion paths at 8/16/48 kHz with exact 127/2048-frame replay; the isolated one-shot/sustain/pitched-loop demo matches stable/development Win32 bytes. The reviewed packets were made by an ignored Pascal packer compiled with stable FPC 3.2.2 Win32 using `-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools`; it preserved each native sample rate, used one documented 12-times listening gain and rejected clipping. Their current WAV hashes match the recorded identities. Audible acceptance is limited to the reviewed example settings and the 8/48-kHz measured endpoints. Intermediate-rate and interpolation variants retain numerical/replay evidence without separate audible approval. Arbitrary keys, velocities, rates, loop points and instrument realism are not accepted. This closes all five criteria and earns +8 NS-2 points / +2.00 overall; combined-path acceptance remains in task 03.

**Acceptance Criteria:**

- Define a finite listening matrix covering the supported source families, sampled pitch/velocity/rate ranges, short and long gates, attacks, releases and sample-loop exits; map it to existing artifacts before creating new renders.
- Record actual timestamped listening observations and a verdict for each covered family, including clicks, unwanted aliasing, pitch continuity and release behavior. A waveform metric or silence from the reviewer is not approval.
- Resolve demonstrated defects within this scope and attach before/after auditions plus the relevant signal, boundary and deterministic-replay evidence; if none are found, record that outcome.
- State the accepted operating ranges and remaining unsupported cases explicitly. Do not claim realistic instruments, arbitrary automation or universal alias freedom.
- Retain source/parameter/output identities and link the acceptance record from SYNTHESIS-QUALITY.md; all criteria and TASKFLOW completion requirements are satisfied.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

- 2026-09-23 measured-range packet: four [hash-bound review WAVs](../../SYNTHESIS-QUALITY.md#measured-profile-range-listening-packet--2026-09-23)
  now concatenate existing 8/48-kHz stationary/glide and envelope outputs for
  all three profiles at native rates. An ignored Pascal packer uses uniform
  12-times listening gain and 0.2-second separators, rejects clipping and
  records input hashes/times. This supplies a bounded low/high-rate review
  instead of more separate mobile prompts. The 16/44.1-kHz static/glide and
  22.05-kHz envelope cases retain numerical evidence but no distinct audible
  verdict. The subsequent full-packet review was favorable, with no fault time;
  no source repair or additional copy was needed.

- 2026-09-23 short source and loop verdict: the user heard the complete
  five-second `sources.wav` and 6.3-second `sample-loop.wav` identified in the
  [finite matrix](../../SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01)
  and said both sounded okay. The observations cover 0–5 and 0–6.3 seconds,
  with no fault times reported. They support the shown oscillator/additive/PM/
  wavetable/percussion and authored one-shot/loop examples at those settings,
  but do not approve arbitrary loop joins, measured profile/rate/gate extremes
  or a specific absence of aliasing or release artifacts. Criterion 2 and task
  credit remain open for the bounded measured and range review.

- 2026-09-23 source-family review packet: before requesting another review,
  checked the user's earlier brass/guitar/mallet descriptions against their
  files. Those are recorded NSynth notes in the [note-presence reference packet](../../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22),
  not Pythian synthesis output; they remain evidence for that separate task.
  Added two existing hash-bound native examples to the [source matrix](../../SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01):
  the five-second oscillator/additive/PM/wavetable/percussion sequence and the
  6.3-second one-shot/sustain/pitched-loop comparison. The earlier broad good
  spectral-pair verdict, improved control demo and smooth measured-profile-1
  response are retained at their actual scope. This bounded packet seeks
  family-specific observations and fault times; no criterion or credit closes
  until the remaining families and operating ranges are reviewed.

- 2026-09-23 first isolated-family verdict and reassessment: the user heard
  the exact [profile-1 48-kHz copy](../../SYNTHESIS-QUALITY.md#first-isolated-source-listening-copy--2026-09-23)
  and called it smooth. This supports that one complete seven-key,
  three-velocity stationary sequence; it does not label individual attacks,
  releases, aliasing, glide continuity, other profiles/rates or sample-loop
  exits. The earlier combined-passage review/copy and this first isolated
  verdict are two nonclosing listening batches: neither supplies the matrix's
  per-family timestamped verdicts, defect disposition or accepted ranges.
  Reassess by finishing the bounded existing matrix rather than generating
  more gain variants, starting with the already rendered 12-second
  oscillator/control comparison and retaining other family cases for their
  source-specific verdicts. No criterion or credit closes here.

- 2026-09-23 first isolated-source review aid: the existing profile-1 48-kHz
  stationary sample has a [hash-bound 6.72-second listening copy](../../SYNTHESIS-QUALITY.md#first-isolated-source-listening-copy--2026-09-23)
  at one uniform 12-times playback gain and 0.409424 peak. It sequences seven
  keys and three velocities; the unchanged family matrix retains other rates,
  profiles, glides, envelopes and sample loops. The later smooth impression
  above does not approve those remaining cases. Preparing the copy closed no
  further criterion or credit.

- 2026-09-23 combined-source review support: the [11-second listening copy](../../SYNTHESIS-QUALITY.md#combined-source-listener-copy--2026-09-23)
  is the existing native mix converted by maintained Pascal to 44.1-kHz WAV
  with uniform 3-times playback gain. Source/output hashes, duration, peak and
  note-entry times are recorded so a listener can localize a defect. The source
  families overlap in this mix; its later broad verdict cannot replace the separate
  matrix cases. No source/articulation criterion or credit closes from conversion.
- Follow-up: the existing source auditions and [paired preview](../../SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20) seeded the finite listening matrix. The later family, loop and measured-endpoint verdicts closed the bounded task; broader settings retain the explicit limits above.
- 2026-09-22 batch: completed acceptance criterion 1 by mapping existing generated WAVs and SHA-256 identities in [SYNTHESIS-QUALITY](../../SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01). No new render was necessary. Actual listening and defect disposition remained open at that checkpoint.
- 2026-09-23 listener checkpoint: the user confirmed hearing the complete, hash-identified [30-second paired preview](../../SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20) and called it coherent overall. This is a whole-piece observation for the two measured-performance excerpts; later isolated examples supply the family and range verdicts.
