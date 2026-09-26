# Beat-grid candidates from WAV onsets

[Home](../README.md) · [Onsets](ONSETS.md) · [Recorded events](EVENT-LEARNING.md) ·
[Explicit timing](TIMED-LEARNING.md) · [Work](WORK.md)

For changing tempo, the separate [local tracker](BEAT-TRACKING.md) now combines
window candidates and retains explicit source-onset adjustments.

The native [beat library](../src/pythian.beat.pas) retains constant-period pulse
hypotheses from weighted source positions. Candidates have tempo, phase,
periodicity and timing-support measurements. They do not assign meter, identify
a downbeat, follow tempo changes or report calibrated confidence.

## Method

For each trial period `p`, normalize positive weights by their maximum and deposit
them with linear interpolation into a 64-bin circular phase histogram. Smooth
with a triangular kernel whose radius is the smaller of a quarter period and
the timing tolerance. Retain up to two peaks separated by at least a quarter
cycle, then refine each phase by the weighted offset of nearby observations.
Phases are canonical in `[0,p)`. Common weight scaling leaves the fit intact;
normalization avoids underflow for tiny input weights. This replaces the earlier
single circular-resultant fitter, which could cancel competing subdivision phases.

Count observations near their nearest grid point, using the smaller of one
quarter period and the timing tolerance. Count each supported point once.
Coverage divides supported grid points by grid points in the observed span
expanded by the tolerance. Weighted mean absolute error uses matching observations
only. These measurements describe admitted onsets, not annotated musical beats.

`MatchedWeightFraction` is the weight inside the tolerance divided by total
weight. `PhaseConcentration` measures triangularly weighted support above its
uniform-phase expectation: `max(0, (K/W - T/p) / (1 - T/p))`, where `K` sums
`weight * (1 - distance/T)` inside tolerance `T`, and `W` is total weight.
The score is `PhaseConcentration * sqrt(Coverage)`. These are distinct measurements,
not circular coherence or confidence. The current policy identifier is
`phase-concentration-64-two-phase`; old and current scores are not interchangeable.

After local-peak filtering, select the strongest tempo/phase anchor, followed by
its strongest eligible distinct-phase companion within the BPM separation
neighborhood. Distinctness is measured at the observed span midpoint with a
quarter-cycle threshold. Remove that tempo neighborhood and repeat within the
candidate limit. An unpaired anchor consumes one slot; a final odd slot holds
only its anchor. Ties within `1e-12` prefer earlier trial order. Candidate order
is selection order, not globally descending score. The local-peak filter compares
phase ranks across adjacent trial tempos; it does not establish stable phase
identity across tempos. Strong offbeats and subdivisions can alter ranking.

## Core contract

`EstimateBeatGrids(observations, sampleRate, sourceFrames, options)` accepts
strictly increasing unique frames and finite weights in `(0,1]`. Source identity,
admission and weight meaning belong to the caller. It returns detached candidates
and the observed span. Fewer than four observations, too few cycles or unsupported
periodicity yield no candidates. Invalid admission preserves an assigned result.

| Policy | Default / bound |
| --- | --- |
| Tempo search | 40..240 BPM in 0.25 BPM steps; configurable within 20..400 |
| Step | 0.01..20 BPM; at most 4096 trial tempos |
| Observations/work | At most 8192; conservative fit visits at most 16 million |
| Evidence span | Three trial periods by default; configurable 2..32 |
| Admission | At least four matching observations; `MinimumMatchedWeight` defaults to 0.15 |
| Timing tolerance | 30 ms by default, capped at one quarter period |
| Candidate separation | 3 BPM by default; at least the step, at most 40 BPM |
| Candidate count | Eight by default; configurable 1..32 |
| Source | 1..64 million frames, supported sample rate, shortest trial period at least two frames |

`BeatGridFitWork(observationCount, trialCount)` supplies the shared estimator/tracker
bound: zero below four observations; otherwise `trials * (5 * observations + 2368)`.
This allows five observation walks plus bounded histogram/phase work per trial.
Selection adds at most three scans of the two-proposal trial array per anchor,
with at most the configured candidate count of anchors. The existing work ceilings
remain unchanged; a previously admitted dense/wide search may now require smaller
windows or a narrower search. This does not establish many-hour tracking capacity.

Storage scales with twice the trial count. There is no source-audio allocation, WFC solver,
random state or wall clock. The reported trial count is the configured count even
when there are too few observations to fit.

`BeatGridFrames(candidate, startFrame, endFrame)` returns rounded positions in
the half-open interval, with half-frame ties later and at most 65536 positions.
Period/phase must be finite and canonical; an empty interval is valid. The caller
selects the hypothesis and interval. Extrapolation does not prove musical beats
continue, and the first returned point is not necessarily a bar boundary. No
estimated floating period is silently converted into an exact PPQ tempo.

## Native workflow

`pythian.beat.wave.MeasureWaveBeats` now provides this operator's native
analysis/localization/admission frontend for reuse by context admission. The
[selected pulse workflow](WAVE-CONTEXT-ADMISSION.md#selected-beat-phase-and-source-scope)
can retain an explicitly chosen period/phase in a saved context and style.
Quantization errors remain reported separately from measurement accuracy.

```text
pythian.beats INPUT.wav OUTPUT.json [MIN_BPM MAX_BPM] [--track] [--audition OUTPUT.wav [RANK]]
pythian.beat.lab OUTPUT_PREFIX
```

The [inspection tool](../tools/pythian.beats.lpr) hashes/decodes the WAV, uses
the finer onset preset and localizer, and admits points through `PlanOnsetEvents`
with default edge/spacing policy. Synthetic source endpoints are excluded.
Weights are square roots of measured energy rises divided by their maximum.
Original candidate identities and decisions remain in the report. ACID tempo
and external beat labels do not enter this fit.

JSON retains source identity/format, measurement policy, all analysis/admission/grid options, weighted
observations, candidate metrics and grids within the observed span. Audition
rank defaults to zero. An unavailable requested rank rejects before publication;
a report without an audition may validly have no candidates. Source/report/audio
paths must differ. WAV and JSON writes are separate, not atomic.

The audition retains the recording and adds short sine cues at selected grid
points. The [shared helper](../tools/pythian.tools.cues.pas) also serves onset
auditions with unchanged bytes. It preserves format/duration, separately scales
source/cue peaks, bounds cue count/work and records gains plus output SHA256.
This is a listening overlay, not newly synthesized music or beat annotation.

## Current adoption evidence — 2026-09-19

The [phase-family adoption](BEAT-TRACKING.md#maintained-phase-family-measurement--2026-09-19)
reproduces the prototype's candidate metrics, local paths and auditions on three
development WAVs. Existing beat/tracker/admission checks and seven controlled
subdivision/accent/mixture cases pass on three Windows targets. Matched-weight
semantics, one/odd candidate capacity and evidence-free work accounting are checked.
The saved changing-tempo profile still drives the actual WFC key/tempo passes.

There is a material fixed-grid ranking tradeoff: the authored polyphonic lab's
first candidate is now 192 BPM, yielding 19 extra pulses, where the earlier
fitter led with 96.25 BPM and no extras. A 96-BPM candidate remains at index 1,
matching all 20 authored beats without extras; the local path also matches all
20 without extras. The lab now checks that this alternative remains available.
Adoption is scoped to improved pulse alternatives and the verified local path,
not a claim that rank zero identifies quarter-note tempo. Explicit caller
selection remains required for admission. Do not tune a preferred BPM or silently
substitute the annotated candidate to hide this regression.

The current report fields are `phase_concentration`, `matched_weight_fraction`
and `minimum_matched_weight`. No historical reader or algorithm-selection branch
is retained. Earlier checkpoint reports below describe the previous fitter.

## Evidence — 2026-09-14

The [core fixture](../tests/pythian.tests.beat.lpr) checks known tempo/phase,
double-tempo support, shifted/jittered events, tiny weight scaling, silence,
short bursts, duplicate/nonfinite admission, work limits and grid rounding.
It needs no vendor source.

The [native laboratory](../tools/pythian.beat.lab.lpr) creates three 14-second
stereo PCM16 sources and analyzes their decoded saved bytes. Quarter-note clocks
are authored independently of detector output. Percussion is antiphase between
channels; the polyphonic source adds changing three-tone harmony and quiet
offbeat percussion. Evaluation uses an authored interval, one-to-one matching
and a 1323-frame (30 ms) tolerance.

| Source | Highest-ranked BPM | Matched reference beats | Extra grid points | Mean matched error |
| --- | ---: | ---: | ---: | ---: |
| Regular 120 BPM percussion | 120 | 24 / 24 | 0 | 1 frame |
| Polyphonic 96 BPM source | 96.25 | 20 / 20 | 0 | 357.95 frames (8.12 ms) |
| 120 to 100 BPM change | 119.75 | 15 / 24 | 11 | See report |

Files are `beat-lab-{regular,polyphonic,tempo-change}.wav` and `.json` in each
compiler build directory. Reports retain all reference/predicted frames,
candidates and source hashes. The tempo-change failure remains visible.
The polyphonic source yields 397 admitted onsets, including many spurious ones;
recovering its authored clock does not establish accurate onset detection or
general polyphonic beat tracking.

Pixel Sprinter admits 348 observations. Candidates: 70 BPM (score 0.3065,
39/39 supported grid points) and 139.75 BPM (score 0.2668, 53/79 supported points).
The source declares 140 BPM, but this was not used and does not annotate phase
or downbeats. Opening Theme admits 901 observations and yields a weak 47.75 BPM
hypothesis (score 0.1417, 38/68 supported points). Neither has an annotated beat
accuracy result. Reports: `build/corpus/pixel-beats.json` and `opening-beats.json`.

FPC 3.2.2 and 3.3.1 i386-win32 compile/run the fixture, laboratory and inspection
smoke. Final logs: `build/beat-3.2.2-checked.log` and
`build/beat-3.3.1-checked.log`. Replay, rejection and inspection evidence is in
the work record. The normal build includes these focused checks. No fresh full
suite or source package is claimed; preceding ZIPs contain the earlier 45-core-unit
event checkpoint.

Local windows and tempo-change paths are now available in the separate tracker;
`RANK` applies only to fixed-grid auditions. Annotated recorded-music evaluation,
metrical-level selection and verified phrase/downbeat controls remain open.
Selected positions can feed existing alignment/passage APIs; this tool does not
alter stored event models, source timing or WFC generation constraints.
