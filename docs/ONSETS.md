# Locating source energy rises

[Home](../README.md) · [Activity](ACTIVITY.md) ·
[Musical timing](TIMED-LEARNING.md) · [Beat-grid candidates](BEAT-GRIDS.md) · [Work](WORK.md)

`pythian.onset` adds optional PCM timing estimates to existing acoustic onset
candidates. A candidate describes a forward FFT window; its left edge can precede
the attack inside that window. The localizer searches the source samples for an
energy rise and returns its frame alongside the original feature/window identity.
It does not change activity labels, source samples, archives or WFC model tokens.

`DefaultOnsetAnalysisOptions(sampleRate)` supplies a separate timing grid: the
smallest power-of-two window spanning at least 20 ms, with a minimum of 64 frames
and a quarter-window hop. This is 1024/256 frames at 44100 or 48000 Hz and
8192/2048 at the supported maximum 384000 Hz. The original acoustic-learning
default stays 4096/1024. Shorter windows trade frequency resolution for temporal
coverage; this preset does not replace chroma/learning measurements in archives.
The existing activity options still count history, peak radius and separation in
features, so their duration in seconds changes with the chosen hop.

## Native contract

[LocateOnsetWindow](../src/pythian.onset.pas) searches the half-open source interval
`[StartFrame, StartFrame + FrameCount)`. For every point, it compares mean power
in adjacent windows of `EnergyWindowFrames` samples before and after that point.
Each channel contributes its own squared samples before channel averaging, so
opposite-phase stereo does not cancel the measurement.

The selected point has the greatest positive `after - before` power difference;
equal maxima choose the earliest point. Resolution requires both
`MinimumEnergyRise` and `MinimumContrast`, where contrast is
`(after - before) / (after + before)`. These are measured strengths, not confidence
probabilities. Defaults are approximately 5 ms per energy window, a minimum rise
of 0.000001 and minimum contrast of 0.2. At 44100 Hz the energy window is 220 frames.

`TOnsetLocation` retains the searched interval, feature index, before/after RMS,
power rise and contrast. `Resolved = False` returns `Frame = -1`; positive-rise
measurements remain available even if thresholds reject them. With no positive
rise, measurements are zero. `ContextClipped` marks a selected maximum whose
energy context extends outside the clip and uses zero padding. `SearchBoundary`
marks a selected maximum at either edge of the searched interval. Both flags
describe the selected maximum even when it fails the resolution thresholds.

`LocalizeAcousticOnsets` runs the existing activity policy and returns one detached
row for each original onset candidate, including unresolved rows. It does not
merge duplicate locations from overlapping windows. Feature/source byte identity
remains the caller's responsibility; grid validation alone cannot establish that
the supplied feature values came from those samples.

Options, clip and source-window bounds are checked before scanning. The energy
window is bounded to 1..4096 frames. A conservative PCM work count of
`(3 * searchFrames + 2 * energyWindowFrames) * channels` must fit 100000000, both
for a direct search and summed across a candidate batch. Sliding power sums use
constant working storage; result storage scales with the candidate count. Rejected
calls do not publish a replacement result. Version: `OnsetLocationVersion = 1`.

## Energy-fall evidence

`LocateEnergyFallWindow(Clip, StartFrame, FrameCount, Options)` measures the
opposite directed edge: the greatest positive `before - after` mean power.
It shares the bounded sliding calculation with onset localization; existing
onset behavior and APIs remain unchanged. `TEnergyFallLocation` retains the
search interval, frame, before/after RMS, positive `EnergyFall`, contrast,
resolution and clipped/search-boundary flags. Equal maxima select the earliest
frame. Rejected positive candidates retain their measured levels with `Frame=-1`.
Channels contribute power independently, and RMS includes DC.

`DefaultEnergyFallOptions` uses approximately 20-ms adjacent windows, capped at
4096 frames, a minimum fall of 0.000001 and contrast 0.2. The cap keeps defaults
valid through 384000 Hz; at that maximum rate the window is about 10.67 ms.
Callers can select other bounded windows and thresholds. Work and failure
semantics match the onset contract above; the result is a detached value and the
clip remains borrowed. No separate source format is introduced.

This is a local energy measurement, not a physical note-off, silence, instrument
ownership or synthesis-gate decision. Tremolo, a transient followed by sustain,
or an amplitude dip can produce a strong fall while a note continues. Clip-end
zero padding can also produce a fall and is explicitly marked. A release policy
must retain these distinctions and its own sustained-tail/context evidence.

The existing onset fixture adds exact anti-phase stereo falls, before/after
levels, equal-maximum tie order, a rising-edge counterexample, retained rejected
measurements, invalid-search preservation, clip/search edges, maximum-rate
defaults and an independent full-window power-sum reference. Checked stable
Win32/Win64 and development Win32 pass, including the previous onset/valley
checks. Logs are ignored under `build/release-evidence-{win64,stable,trunk}/`.

The [recorded release probe](PHRASE-EVALUATION.md#energy-fall-release-checkpoint)
rejects using the strongest local fall as an automatic note ending: it severely
reduces complete-note matches on both development parts. That finding belongs to
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries); it does not invalidate the
scoped energy measurement or admit a replacement gate policy.

The subsequent [sustained-tail condition](PHRASE-EVALUATION.md#sustained-tail-checkpoint)
combines existing RMS traces with independent periodicity confirmation. It avoids
the large maximum-fall regression but does not improve complete-note matches.
Release admission still requires event ownership and uncertainty handling; low
activity and the absence of a stable period do not establish a musical gate.

## Envelope valley evidence

`MeasureEnvelopeValleys` measures local RMS minima with peaks on both sides.
This supplies additional source evidence for attacks missed by spectral candidates;
modulation, tremolo and noise can also qualify. A valley is not an admitted note
attack, beat, rest or part assignment. Callers decide whether to use it as a
boundary proposal; the existing localizer and event planner remain unchanged.

`DefaultEnvelopeValleyOptions(sampleRate)` uses a 10-ms power window, 2-ms hop,
20-ms minimum-search radius and 80-ms peak-search radius, rounded onto the sample
and envelope grids. The public radii are in envelope points. At 8 kHz these are
80 frames, 16 frames, ten points and forty points. `MinimumPeakRms` is 0.0001 and
`MinimumDepth` is 0.35. These measurement filters are not calibrated note thresholds.

Window starts are `k * HopFrames`, with center at start plus
`EnergyWindowFrames div 2`. Channels contribute independent power before
averaging, preserving opposite-phase stereo. Only complete windows and complete
left/right peak neighborhoods are considered. Equal minima and peaks choose the
earliest point. Both peaks must exceed the RMS floor. Depth is
`1 - valley_rms / min(left_peak_rms, right_peak_rms)` and must meet the caller's
minimum. Results retain the valley/peak frames, RMS values and depth; callers
receive detached records while the source clip remains borrowed.

Energy window and hop are bounded to 1..4096 frames, minimum radius to 1..128
points, and peak radius to the minimum radius through 1024 points. Depth must be
finite and in `(0, 1]`; the RMS floor must be finite and nonnegative. Requests
preflight at 65536 envelope points and 100 million work units, counting sample
channel visits plus neighborhood point visits. Work is bounded before allocation
or sample reads. Insufficient complete context returns no candidates; invalid
options or excessive work raise without replacing a caller's accepted result.
Long recordings need bounded analysis regions; this routine does not establish
multi-hour streaming or cross-region context handling.

The expanded native onset fixture checks exact constant-power oracles, stereo
phase, tied minima/peaks, inclusion thresholds, incomplete context, ownership and
both budgets on stable/development Win32 and stable Win64. Optional inspection
retains exact discrete evidence across these targets; the measured floating values
are compared independently within 1e-9. See the
[recorded attack study](PHRASE-EVALUATION.md#envelope-attack-checkpoint) for the
separate musical-quality limits. Evidence is under ignored
`build/envelope-valleys-{stable,trunk,win64}/` and `build/phrase-attacks-study/`.

## Operator tools

The normal build includes a native inspection tool and a controlled laboratory:

```text
pythian.onsets INPUT.wav OUTPUT.json [WINDOW_FRAMES HOP_FRAMES] [--valleys] [--audition OUTPUT.wav]
pythian.onset.lab OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES]
```

Inspection defaults to the sample-rate-aware timing preset above. Pass
`4096 1024` explicitly to reproduce earlier inspection reports. The laboratory
retains the wider acoustic-analysis default as its baseline; pass `1024 256` to
evaluate the fine grid on its 44100 Hz signals. Both use the same activity and
PCM localization algorithms. Invalid laboratory window/hop options reject before
any output is written.

`--valleys` adds the complete envelope policy and measurements to the current
inspection report. It does not add a format version or automatically merge
valleys into admitted onset locations. An optional audition still cues the
existing energy-rise locations. The development inspection verifies identical
cue WAV bytes with/without valley measurement, and the report without the option
remains identical to the preceding maintained tool on stable Win32.

The inspection report includes exact source SHA256, format, analysis settings,
activity policy, energy thresholds and every candidate/location row. Source frame
positions are zero-based; divide by the reported sample rate for seconds. The
tool rejects equal expanded source/report/audition filenames and writes the report
after analysis succeeds. File publication is not atomic; an optional audition WAV
is written before the JSON, so a later report-write failure can leave the WAV.

`--audition` preserves source duration, channel count and sample rate while adding
an approximately 8 ms decaying sine cue at each resolved location. The cue is
2000 Hz, reduced to sample rate / 8 for low-rate inputs. Both stereo channels
receive the same cue; original channel differences remain. Unresolved candidates
receive no cue. Overlapping cues add before peak scaling. Source gain is
`0.7 / max(1, sourcePeak)` and cue gain is `0.25 / max(1, cuePeak)`, bounding their
combined peak to 0.95 before PCM16 quantization. The report retains those gains,
cue length/frequency and exact audition WAV SHA256. This is a listening aid for
timing review, not a beat track or a new ground-truth annotation. It is a bounded
in-memory render under the clip contract.

The laboratory writes five two-second stereo PCM16 WAVs and one JSON report.
Analysis runs on the decoded bytes of those saved WAVs. Reference positions come
from the authored signal event starts, not from the detector or inferred beats.
Each report retains the WAV hash, reference frames, candidate windows, resolution
flags and signed matched errors. Examples from the repository root:

```powershell
./build/3.2.2-i386-win32/pythian.onset.lab.exe build/3.2.2-i386-win32/onset-lab
./build/3.2.2-i386-win32/pythian.onset.lab.exe build/3.2.2-i386-win32/onset-fine 1024 256
./build/3.2.2-i386-win32/pythian.onsets.exe build/corpus/pixel-sprinter.wav build/corpus/pixel-onsets-fine.json --audition build/corpus/pixel-onsets-listen.wav
```

## Controlled timing evidence: wider baseline

Matching tolerance is 1102 frames, approximately 25 ms at 44100 Hz. Reference
tolerance intervals are disjoint and checked before matching; the nearest
prediction in each interval is counted once, and extra predictions count as false
positives. Timing error is calculated only for matched references, so it must be
read together with misses. The coarse baseline treats feature-window left edges
as point estimates; it does not score whether a candidate window covers an event.

| Source | References | Coarse point matches / predictions | Localized matches / predictions | Unresolved candidates | Localized mean absolute error, frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| Isolated square bursts | 4 | 0 / 6 | 4 / 4 | 2 | 0 |
| Sine bursts with 20 ms attack | 4 | 0 / 7 | 4 / 4 | 3 | 394.25 |
| Percussion over a continuous sine | 5 | 1 / 5 | 4 / 4 | 1 | 9.5 |
| Constant-power square pitch changes | 5 | 1 / 5 | 1 / 1 | 4 | 0 |
| Percussion pairs spaced 60 ms apart | 8 | 1 / 5 | 5 / 5 | 0 | 2.2 |

The isolated square attacks localize exactly. Slow-attack errors are +26, +318,
+716 and +517 frames; their steepest energy rise need not equal the authored
envelope start. The first slow attack selects the search boundary, explicitly
flagging that the FFT candidate truncates the available search interval.

The percussion-over-sine reference includes the background's start at frame zero;
that event matches at frame 37 with clipped context. Three percussion attacks
match; the first attack at frame 5093 has no candidate window. The unresolved
candidate is near the clip's end. Reports list missed reference frames explicitly. The
constant-power case resolves only the clip start; all four pitch changes retain
their spectral candidates without an energy-rise location. The close-percussion
case misses three of eight events because only five candidates are available.
Refining those windows cannot repair missing candidate coverage. No resolved
false positives occur in these five controlled cases; this is not a general
music accuracy claim.

The focused [fixture](../tests/pythian.tests.onset.lpr) checks an analytic
opposite-phase power step, search-edge and clip-context flags, silence, constant
energy, invalid-window preservation, actual FFT candidate localization and
detached results. Checked builds and execution pass on FPC 3.2.2 and 3.3.1,
i386-win32. All five laboratory WAVs, the laboratory JSON and the inspection smoke
JSON are byte-identical across those compilers. No owned-source warnings were
reported. Evidence:

- `build/onset-focused.log`, `build/onset-development.log`
- `build/onset-lab-build.log`, `build/onset-lab.log`, `build/onset-lab-development.log`
- `build/onsets-tool-build.log`, `build/onsets-smoke.log`, `build/onsets-development.log`
- `build/onset-replay.log`, `build/3.2.2-i386-win32/onset-lab.json`

The existing attributed [recordings](../tests/fixtures/wav-corpus.json) also run
through inspection with the original 4096/1024 grid. Pixel Sprinter yields 189 candidates and
189 resolved locations; Opening Theme yields 376 and 376. Neither run uses clipped
context for a resolved location. Reports retain search-boundary flags per row.
Files: `build/corpus/pixel-onsets.json`, `build/corpus/opening-onsets.json`; logs:
`build/pixel-onsets.log`, `build/opening-onsets.log`. These recordings have no
reviewed onset annotations here, so these counts establish execution, not accuracy.

## Finer timing grid and audition evidence

The same saved signal bytes, reference events, matching tolerance, activity policy
and energy window were evaluated at 1024/256. This recovers the three missing
60 ms percussion events and the first percussion attack over the continuous bed.

| Source | References | Localized matches / predictions | Unresolved candidates | Localized mean absolute error, frames |
| --- | ---: | ---: | ---: | ---: |
| Isolated square bursts | 4 | 4 / 4 | 1 | 0 |
| Sine bursts with 20 ms attack | 4 | 4 / 4 | 4 | 72.25 |
| Percussion over a continuous sine | 5 | 5 / 5 | 1 | 7.8 |
| Constant-power square pitch changes | 5 | 1 / 1 | 5 | 0 |
| Percussion pairs spaced 60 ms apart | 8 | 8 / 8 | 0 | 1.5 |

All eight close-percussion attacks now resolve, with signed errors of
1, 0, 1, 0, 1, 7, 1 and 1 frames. That is a mean error of about 0.034 ms for this
controlled signal. The four energy-neutral pitch changes still lack energy-rise
locations even though their spectral candidates are present. Three of the four
resolved soft attacks reach a search boundary; their smaller absolute errors do
not remove that uncertainty. Other event spacing, timbres, levels and sample rates
need their own evidence; these five signals do not establish universal coverage.

An additional analytic fixture checks eight opposite-phase power steps spaced
60 ms apart: every authored start localizes exactly once, with no extra resolved
events. Preset checks cover 44100 Hz, maximum sample rate and unchanged learning
defaults. Current checked fixture and tool builds pass on both compiler versions:

- `build/onset-grid-fixture-stable.log`, `build/onset-grid-fixture-development.log`
- `build/onset-grid-stable.log`, `build/onset-grid-development.log`
- `build/onset-grid-lab-stable.log`, `build/onset-grid-fine.log`

Fine-grid laboratory WAVs/report and the close-percussion audition WAV/report
are byte-identical across compilers (`build/onset-grid-replay.log`). The wider
laboratory report and explicit 4096/1024 inspection remain byte-identical to their
previous versions (`build/onset-grid-regression.log`). Source-overwrite and invalid
FFT-window requests reject while preserving prior artifacts
(`build/onset-grid-rejection.log`). The normal build now includes both grids and
the close-percussion audition smoke. No full-suite rerun is claimed for this change.

On real recordings, the finer grid yields 374 candidates / 368 resolved locations
for Pixel Sprinter and 939 / 930 for Opening Theme. One resolved Pixel location
uses clipped context; none do in Opening Theme. These higher counts are not a
measured accuracy gain. The reports retain unresolved rows and search-edge flags:
`build/corpus/pixel-onsets-fine.json`, `build/corpus/opening-onsets-fine.json`;
logs: `build/pixel-onsets-fine.log`, `build/opening-onsets-fine.log`.

The Pixel audition `build/corpus/pixel-onsets-listen.wav` has 1512000 stereo frames
at 44100 Hz (34.286 seconds), matching the source extent. PCM peaks are
0.837189 / 0.650543 and its SHA256 is
`7e9c9fee8eed98fc8555d03f9ca8a38594b657137f7eb68ec2d4a5038bf7dbd4`.
Inspection: `build/pixel-onsets-listen-inspect.json`. Operator timing review has
not been completed; the cues and source attribution are available for that review.

Beat/downbeat inference, annotated recorded-music accuracy, broader candidate
coverage, and use of these estimates in source-grain/WFC timing remain open.
The current timed remix continues to use its documented feature-grid contract.

The separate [event-learning path](EVENT-LEARNING.md) now binds an onset report
to its exact recorded WAV and builds full source intervals from admitted locations.
It uses source frames to aggregate archived acoustic features, learns joint
acoustic/duration symbols through WFC, and renders complete selected intervals.
Default event planning excludes clipped-context and search-boundary estimates,
with an explicit decision for every candidate. It does not change the existing
timed-remix anchors or infer beats.
