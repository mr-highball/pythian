# Periodic pitch measurement and WAV-derived note learning

[Home](../README.md) · [Tonal profiles](TONAL.md) · [WAV styles](WAVE-STYLE.md) · [Work](WORK.md)

For multi-note recordings, reference timing and the predeclared evaluation
protocol, see [recorded phrases](PHRASE-EVALUATION.md).

Pythian now measures periodic fundamental-frequency candidates, admits supported
equal-tempered notes, and learns actual WFC pitch models from declared monophonic
WAV sources. A saved model can generate native audio without reopening its source.
This supplies measured note content alongside the existing timing/intensity work.
It does not separate voices from mixed music. Measured pitch can also participate
in the saved PYS style workflow described below.

## Native estimator

[pythian.pitch](../src/pythian.pitch.pas) uses the difference function, cumulative
normalization and parabolic interpolation described in the [YIN paper by de
Cheveigne and Kawahara](https://www.ee.columbia.edu/~dpwe/papers/deChevK02-yin.pdf).
It uses a fixed half-window integration interval, selects an early sufficiently
deep local minimum, and interpolates the raw difference for the period estimate.
Unlike the paper's fallback, a weak result stays unknown. The temporal best-local
estimate stage is not implemented; this is a bounded single-window derivative.

`EstimatePitch(Samples, SampleRate, Channels, Channel, Options)` reads one explicitly
selected channel of interleaved samples. It removes the window mean for AC RMS,
retains period/frequency, normalized difference, nearest MIDI note and tuning error,
and distinguishes estimated, silence, no-period and outside-range outcomes.
DC-only input is silence. Channels are not averaged, so opposite-phase stereo
does not cancel. A low normalized difference is not a confidence probability or
proof that a musical mixture contains only one source.

Defaults are 55..1200 Hz, difference threshold 0.1 and AC RMS silence threshold
0.00001. Windows are 16..8192 frames and must cover the minimum period plus an
interpolation neighbor within half their length. Samples, thresholds and ranges
are validated before publication. `PitchEstimateWork` reports squared-difference
terms; it does not promise a processing deadline. The operator caps a batch at
268435456 terms and 1024 cells. Extreme sample rates require an appropriate range
or explicit native rate conversion; the operator does not silently downsample.

`AdmitPitchNote(Estimate, MaximumCents)` applies an explicit 0..50-cent tolerance
around equal temperament with A4=440 Hz. Non-estimated, out-of-MIDI-range or
off-grid results return -1. This unknown value is not a musical rest. Frequency
range limits, harmonics and mixtures can cause octave/other pitch ambiguity;
the estimator does not establish instrument identity or recover note boundaries.

## Centered periodic measurement

`EstimatePitchCentered` is an explicit alternative for callers aligning pitch
measurements with another analysis window. It shares the estimator's range,
threshold, status and interpolation machinery, but centers each lag's sample-pair
support at `(FrameCount - 1) / 2`. Half-frame offsets average the two neighboring
difference sums without interpolating audio. `CenteredPitchEstimateWork` reports
a conservative squared-difference bound, twice `PitchEstimateWork`; callers must
budget that bound when processing batches. The existing prefix-integrated API,
default track/learner policy and saved evidence contracts remain unchanged.

The distinction matters for moving pitch. With `N` input frames and `W = N div 2`
integration samples, the existing prefix difference at lag `t` has support center
`(W - 1 + t) / 2`. A centered difference starts at `(N - W - t) / 2`, giving the
same combined center for every lag. For a 512-frame window and a roughly 40-frame
period, the prefix support lies about 108 frames before the window center.
Treating that measurement as centered can bias frequency and fitted spectral
shape on a glide. Symmetric support removes this geometric offset; it does not
guarantee the instantaneous center frequency under arbitrary modulation,
amplitude changes, transients or competing voices.

### Centered timbre measurement checkpoint — 2026-09-19

The existing pitch fixture now checks analytic constant, upward and downward
chirps with even/odd windows, time reversal, gain/DC, explicit stereo channels,
minimum valid geometry and unknown/rejected inputs. The maximum center-frequency
error in the six constant/chirp cases is 1.202411 cents against a predeclared
three-cent limit. The existing stationary frequency/harmonic matrix also passes
with centered integration within six cents. Checked stable Win32/Win64 and
development Win32 pass the fixture; the existing saved-style fixture additionally
passes on stable Win64. No new fixture or unit is added.

A separate native development probe compares fixed, prefix-measured and
centered-measured frequencies across 27 intervals: seven analytic conditions
and the two previously attributed bassoon recordings. Each condition uses three
272-frame harmonic fits starting at 907, 1179 and 1451 in 8-kHz mono audio;
512-frame pitch windows share each fit's center. Analytic spectra use three
harmonics; recorded C/A use 24/16. Range/periodicity defaults and the 0.25 fit
residual limit stay fixed. The analytic input is native floating-point audio;
the two recordings are decoded WAVs.

| Condition | Prefix-measured fit residuals | Centered-measured fit residuals | Observation |
| --- | --- | --- | --- |
| Linear 180→260-Hz glide over 0.512 s | 0.2028 / 0.1970 / 0.1912 | 0.0592 / 0.0616 / 0.0596 | Better temporal alignment reduces false spectral change. |
| 220-Hz vibrato, ±4.4 Hz at 5 Hz | 0.1291 / 0.0317 / 0.1682 | 0.0304 / 0.0234 / 0.0557 | Improvement on these three windows; not a general vibrato guarantee. |
| Dominant second harmonic of 220 Hz | About 0.0135 | About 0.0135 | Both confidently select roughly 440 Hz; a low fit residual does not identify the musical fundamental. |
| 220/233-Hz mixture | 0.5178 / 0.2893 / 0.7463 | 0.5360 / 0.2910 / 0.7384 | All fail the unchanged residual gate. |
| Recorded C | 0.0478 / 0.1148 / 0.1817 | 0.0477 / 0.1150 / 0.1816 | Similar evidence; no automatic note/role admission. |
| Recorded A | 0.1568 / 0.2256 / 0.2533 | 0.1509 / 0.2217 / **0.250556** | Third window still fails 0.25; no threshold relaxation. |

Constant-pitch controls remain near zero residual, silence remains silence, and
the window straddling an octave step remains unknown. The glide's relative
unit-RMS harmonic-shape errors against its independently authored constant
spectrum fall from 0.0141..0.0230 to 0.0015..0.0043. This is stronger evidence
than residual alone: the true spectrum did not evolve. Remaining residual also
includes pitch motion within the harmonic fit, which still uses one frequency.

All three targets complete the same probe. Evidence and logs are ignored under
`build/centered-pitch-{win64,stable,trunk}/`; its Pascal source is
`build/pitch-timbre-probe/probe.lpr`. Build the pitch fixture with
`-B -Sa -Cr -Co -Ci -gl -Fusrc`, adding `-Futools` for the probe and separate
target unit/executable directories. Run `probe PREPARED_RECORDING_DIRECTORY
OUTPUT.json`. The directory contains the previously prepared
`PSBassoon_C2_v1_rr1.wav` and `PSBassoon_A2_v1_rr1.wav`; reports retain their
source hashes and exact window coordinates. All runs are terminal.

This clears a timing prerequisite for [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre),
not changing-pitch style admission. Automatic use still needs register ambiguity
handling, declared event ownership and saved per-knot measurement policy; the
current saved trajectory learner continues to require a declared fixed frequency.
The failed A trajectory remains unadmitted. The probe neither reopens held-out
recordings nor establishes listening acceptance, genre learning or additional
percentage credit.

The subsequent [phrase candidate comparison](PHRASE-EVALUATION.md#centered-candidate-checkpoint)
retains centered support as a development condition. It reduces some flute
octave errors but still fails precision, and exposes repeated-note merging and
early release boundaries on violin. No default track or learner policy changes.

## Musical note hypotheses within regions

[pythian.pitch.regions](../src/pythian.pitch.regions.pas) adds a separate inference
step above raw periodic measurements. `SummarizePitchRegions` accepts an immutable
track and ordered nonoverlapping candidate-event intervals in source frames.
Intervals may leave gaps. Each measurement contributes to the interval containing
its window center. Measurements are not reassigned from neighboring intervals,
although an analysis window can overlap an interval boundary.

The result retains every supported MIDI-note vote, periodic-window coverage,
per-window admitted count, RMS-squared energy share, weighted mean tuning and
tuning deviation. RMS is normalized before squaring; weighted incremental
variance avoids cancellation for near-constant tuning. A note can be admitted
only with at least three periodic windows, at least 50% periodic coverage, at
least 75% of periodic energy on that note and mean tuning within 25 cents by
default. These four options are caller-controlled; support is not a calibrated
probability. At most 4096 regions share the track's bounded window count.

Each vote also retains the extent of its first and last supporting center-aligned
hop bins, clipped to the candidate region. That extent may enclose unknown gaps;
it does not establish continuous support or physical note boundaries.
`GatePitchRegion` retains an admitted region's attack and ends at its last
supporting bin plus caller-selected nonnegative padding, clipped to the region.
The default padding is zero. Unknown regions and malformed matching support
reject. This separate ending policy neither changes the summary nor joins events.

Per-window tuning rejects can contribute their measured frequency to regional
tuning inference. This lets alternating tuning excursions support a centered
musical note without changing the original estimates or their admission. Weak
subharmonic attacks can retain an explicit alternative vote while the note body
dominates. Competing registers remain ambiguous when neither meets the share
threshold. A sustained off-grid mean remains rejected. An unknown result is not
silence, and adjacent regions are never merged.

The caller must supply candidate-event boundaries and declare the source's voice
scope. A dominant pitch across several real notes is not proof of one note;
energy weighting alone cannot distinguish a quiet octave change from a weak
subharmonic attack. Explicit boundaries preserve both notes. The
[recorded region study](PHRASE-EVALUATION.md#musical-note-regions--2026-09-15)
compares known boundaries with existing detected onsets and records the remaining
segmentation/offset failures. Its separate gated condition evaluates the ending
policy against frame coverage, false admissions and note boundaries, and provides
an independent audition. Region hypotheses are not yet persisted or admitted
as another style dimension. Existing raw pitch learning keeps its contract.

## Boundary context

`SummarizePitchBoundary(track, frame, options)` exposes a reusable context query
in [pythian.pitch.regions](../src/pythian.pitch.regions.pas). The caller supplies a
candidate frame in the track's sample rate. `DefaultPitchBoundaryOptions(rate)`
uses 80 ms of context on either side, excluding the inner 20 ms, and the existing
region admission defaults. `ContextFrames`, `GapFrames` and `Regions` are explicit
caller controls; the query does not choose a waveform valley or edit a track.

The detached result retains both complete region summaries, including votes and
unknown decisions, plus central window/unresolved counts. `Qualified` requires
admitted pitches on both sides and either different notes or a central silence/
no-period estimate. Same periodic pitch with changing energy alone does not qualify.
This is contextual evidence, not proof of an attack, ending, rest or voice identity.
Pitch error, noise and genuine amplitude modulation can still confound it.

Side intervals are half-open; central window centers include both inner-gap
endpoints. Either clip endpoint is a valid query, but missing outer context returns
`CompleteContext=False`, unknown sides and no qualification. The function does not
silently shorten its context. Invalid frames, context/gap geometry and region
options reject even at an incomplete edge, preserving a previously assigned result.
Work uses the bounded track windows; the borrowed track remains unchanged and
returned vote arrays are detached.

The expanded existing pitch fixture passes checked stable Win32/Win64 and
development Win32 with zero reported leaks. It covers exact side/central endpoints,
zero gap, missing context, caller admission choices, detached votes, interruption
and invalid requests. Separate waveform controls reject smooth 3-Hz amplitude
modulation while retaining an interrupted same note and a pitch-change cue.
The [recorded qualified-event comparison](PHRASE-EVALUATION.md#qualified-event-cues-checkpoint)
reproduces every prior study candidate decision, state and note through this API,
excluding only measured elapsed time. This verifies extraction and reuse; recorded
phrase precision and independent held-out acceptance remain open.

## Learning and saved generation

[pythian.wfc.pitch](../adapters/wfc/pythian.wfc.pitch.pas) exposes canonical
`pythian.pitch.midi.v1.N` tokens for notes 0..127. `LearnPitchModel` accepts 1..32
admitted tracks, weights 0..64 and model order 1..4. Unknown cells split runs.
Every recording/run and every weighted repetition remains a separate actual WFC
sample. No transition crosses an unknown gap or source boundary. Weights repeat
runs rather than setting output quotas; the weighted cell budget is 65536 and
the existing companion sample-count bound applies. Unknown-only input rejects.

```text
pythian.pitch.wav inspect INPUT.wav REPORT.json TEMPO_US CHANNEL
pythian.pitch.wav learn INPUT.wav PREFIX TEMPO_US CHANNEL --monophonic
pythian.pitch.wav generate MODEL.txt OUTPUT.wav TEMPO_US [SEED]
```

The [native operator](../tools/pythian.pitch.wav.lpr) uses PPQ 480 and step 240 on
a caller-declared constant clock, with frame zero as its declared origin. It
centers one analysis window in each complete cell. A cell too short for the
window remains unknown. This samples pitch; it does not detect beats or note
starts. The window is twice `ceil(sample_rate / 55) + 1` frames and tuning
admission uses 25 cents. Reports retain source hash/geometry/channel, options,
window coordinates, candidate diagnostics and explicit monophonic declaration.

Inspection alone does not train. Learning requires the explicit `--monophonic`
source assumption and emits `.json` evidence plus canonical `.model.txt`. The
report binds the actual model text/hash. Generation reads only that model, checks
its complete pitch vocabulary, uses an actual WFC pass with validated latent
states, and synthesizes 32 generated notes. Cell spacing, 80-percent gates,
velocity 96 and timbre are authored realization choices, not measured articulation.
The output JSON binds the model, states, notes, output clock and actual WAV hash.

These model/evidence files remain a lightweight standalone path. Use
`pythian.style learn-pitch` for saved style ancestry and layered generation.

## Cells on a changing source clock

The mapped overloads of `MeasurePitchCells`, `AdmitPitchCells` and
`SummarizePitchCells` accept an immutable `TMusicGridFrames` plus the source
channel information. This is the same geometry used by rhythm admission.
Its explicit tempo map includes prior history, physical source offset, start
tick, step and finite cell count. Each centered window stays inside its actual
source cell; cells narrower than the pitch window remain unmeasured. Sub-frame
grids reject. Constant-clock overloads delegate to this implementation.

Saved styles now retain each source's map and use it when replaying pitch cells,
including after weighted blends. The independent harmonic fixture changes from
500000 to 600000 us/quarter after cell 15 and begins at source frame 97. All 30
known pitches and both silent cells survive measurement and current style
save/reload. A mismatched source tempo rejects without changing the accepted
style; returned clock arrays are detached.

Independent fragment generation from that style produces 16 attacks / 80 notes
in 846720 stereo frames. The fragment selects the 600000-us tempo region; it does
not demonstrate preservation of the complete source tempo progression. The
64-cell whole-scope requests, including the coupled-pitch request, fail for this
fixture and seed. Keep those scope limits separate from successful source
measurement. The changing-clock rhythm workflow separately demonstrates actual
tempo changes through the complete generated voice clock.

Dense style durations now normalize through each changing/offset source clock.
See [source-clock duration admission](WAVE-STYLE.md#dense-duration-normalization-on-source-clocks).

## Dense measurements and learned duration

`pythian.pitch.cells.SummarizePitchCells` validates and summarizes saved cell
evidence using its source geometry, clock and origin. It separates admitted
pitch, measured silence, uncertain pitch and unavailable measurements, and
counts known runs and their longest observed length. `pythian.style inspect`
includes these values in each source's `pitch_summary`. These are source
observations, not calibrated confidence or a maximum generatable length.

The measured-phase phrase demonstrates why the representations remain distinct:
its 15 centered cells contain 11 admitted notes and four uncertain decay windows,
with no measured silence. Its 64-cell coupled request fails; the existing dense
duration path preserves pitch/silence/unknown spans and successfully generates
32 spans after a weighted second blend. The maintained workflow also selects
an alternative measured tempo without changing that learned performance; see
[measured phrase control](WAVE-STYLE.md#measured-phrase-performance-and-tempo-control).

[pythian.pitch.track](../src/pythian.pitch.track.pas) measures overlapping complete
windows without requiring a musical clock. `TPitchTrack` owns immutable estimates,
raw admitted notes, stable pitch runs and a complete interval partition of its
analyzed timing bins. The source remains borrowed during construction. Default
hop is `sampleRate div 100` frames, minimum stable run is three windows, and
pitch range/tuning admission match the estimator defaults above. At 8000 Hz the
default window is 294 frames and the hop is 80 frames.

`TPitchTrack.Create(Clip, Channel, Options, WindowFrames = 0)` accepts an explicit
analysis width. Zero retains the shortest window covering the declared minimum
frequency and interpolation neighbor. A positive width must satisfy the same
16..8192-frame estimator bounds and cover that frequency range. Odd widths are
supported. Hop, minimum run, frequency limits and tuning/difference thresholds
remain independent. Larger windows integrate more evidence while reducing temporal
resolution and the source extent covered by complete windows; they do not establish
better pitch accuracy for arbitrary music. The existing total work budget still applies.

`CopyEvidence` returns detached settings and all window estimates.
`CreateFromEvidence` validates their source geometry, work bounds, pitch/tuning
relations and silence classification, then rebuilds the same spans without PCM.
`WindowFrames` retains the actual positive width, including an explicit selection;
saved evidence cannot request automatic geometry. The existing PYS duration field
already stores this value, so no new format, reader branch or estimator version
is needed. Centered pitch-cell analysis retains its separate existing geometry.
Cell and dense-track admission share `ValidatePitchEstimate`; forged status,
energy or tuning combinations reject before a replacement object is published.

A stable run contains consecutive windows admitting the same note. Its time bins
start at the first window center minus half a hop and extend one hop per window.
Unanalyzed clip edges are not extended to frame zero or the source end. These
boundaries estimate stable pitch extent; window width, transitions and admission
failures limit their relation to physical note-on/off times. The reported window
plus hop resolution is not a guaranteed error bound on arbitrary music.

`CopyRuns` returns the stable pitched runs. `CopySpans` also retains measured
silence and unresolved intervals, each with its source-window range and frame
extent. Short pitch runs become unknown spans. Silence requires the estimator's
AC-energy classification; unknown does not mean silence. No smoothing joins
separate stable runs. Pitch-only admission requires an intervening measured gap
to distinguish same-pitch repetitions. The explicit onset-assisted style policy
below can supply additional attack boundaries. Vibrato, glides and mixed
voices can fragment admission. The bounded contract allows at most 8192 windows
and the existing 268435456-term pitch work budget; long/high-rate excerpts can
require a larger explicit hop or shorter source. There is no implicit resampling.

`LearnPitchDurationModel` borrows 1..32 tracks and weights 0..64. Each independent
recording, including its explicit unknown intervals, is repeated as a separate
actual WFC sample. For the raw-track overload, sources must share exactly the same hop duration, checked as an
integer ratio; weighted observations are capped at 65536 and order at 1..4.
Canonical tokens contain span kind, admitted note or -1, and duration in hops.
Unknown tokens preserve an intervening observation instead of silently joining
pitch runs. This interval contract differs from the plain pitch learner, which
splits its samples at unknown cells. Both use the existing WFC learner/model
encoding; no historical file-format reader was added.

```text
pythian.pitch.wav inspect-runs INPUT.wav REPORT.json CHANNEL --monophonic
pythian.pitch.wav learn-runs INPUT.wav PREFIX CHANNEL --monophonic
pythian.pitch.wav generate-runs MODEL.txt OUTPUT.wav QUANTUM_MS [SEED] [--spans COUNT]
```

Learning saves complete window/span evidence, source identity, settings and the
canonical model. Generation uses only that model and defaults to eight solved
spans. `--spans` requests 1..1024 solved spans for a longer development preview;
the resulting audio remains bounded to 120 seconds.
The caller supplies its hop duration in milliseconds (10 for the checked 8000-Hz
source); deliberately changing it scales durations without transposing pitch.
The current operator accepts integer milliseconds only. Notes sound for their
generated duration, with authored velocity/timbre. Silent and unresolved spans
produce silence under an explicit output policy; their distinct kinds remain in
the report. In monophonic span auditions each synthesized voice now ends at its
span boundary; native articulation adds 44-frame interior fades. This prevents
previous-pitch release tails from entering the next pitched span as well as gaps.
The optional recorded-phrase workflow requests 256 spans for its development
preview by default; `-PreviewSpans` sets a bounded count without changing the
learned model or the recorded-note evaluation. Its preview output has a separate
name from the earlier eight-span diagnostic.
General polyphonic voice release behavior is unchanged. Output is capped at
120 seconds. See the [32-span diagnosis and rendering fix](WAV-STUDIES.md#duration-scope-checkpoint).

The checked five-second stereo performance has six notes with different lengths,
including repeated same-pitch notes and opposite channel polarity. All six pitch
labels match; maximum measured boundary error is 107 frames at 8000 Hz (13.375 ms).
The saved model retains 23 pitch/silence/unknown spans. Its eight-span output has
three notes of 400, 790 and 400 ms. A 20-ms quantum preserves the exact solved
states while doubling output from 77175 to 154350 stereo frames. Every audible
pitch and every silent/unknown frame passes independent output checks. Weighted
two-source model construction and incompatible timebase rejection also pass.

Both FPC 3.2.2 and 3.3.1 pass on i386-win32; sixteen source/evidence/model/audio
files match. Invalid channels and incompatible tokens preserve accepted outputs.
Evidence: `build/pitch-runs-{stable,trunk}/`, `build/pitch-runs-replay.log`.
This is a controlled monophonic result. Recorded-instrument accuracy and
note-onset ownership remain open; saved-style duration integration is described
below. The existing five-pass voice operator still uses its documented cell gates.

`inspect-runs` writes the same dense window/span evidence without requiring a
learnable model. A source with no admitted notes can therefore be inspected;
no model fields or model file are produced. `learn-runs` still rejects a source
without stable pitch. Both modes preserve explicit unknowns and measured silence.

## Recorded instrument evidence

The optional [recorded-pitch workflow](../tools/recorded-pitch.ps1) downloads six
isolated staccato samples from [VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE),
raw revision `440300901dfe9275fd84e0b7763af1f8443ae62e`. The upstream FluteStac,
ClarinetStac and BassoonStac SFZ mappings at revision
`6dd651d55dde97fd4028699be9d4481f26917891` supply `pitch_keycenter` reference notes;
filename octave conventions are not interpreted. These CC0 recordings are by
Sam Gossner and Simon Dalzell, with sample cutting by Elan Hickler/Soundemote.
The script pins each WAV SHA-256, caches sources/license/mappings under ignored
`build/recorded-instruments/`, and explicitly invokes native `pythian.convert`
to produce 8000-Hz PCM16 stereo input. Channel 0 and all default pitch thresholds
remain unchanged. Reference checks run on both original 44100-Hz and converted
files. Five samples retain the same bin counts. Flute A has 36 correct and 25
unknown bins at the original rate versus 33 correct and 28 unknown after conversion;
neither rate admits a wrong stable note. Conversion is not assumed to preserve
measurement decisions exactly. The table below describes the converted inputs.

```powershell
./tools/recorded-pitch.ps1 -Compiler /path/to/fpc
```

| Sample basename | Reference MIDI | Correct stable bins | Wrong stable bins | Unknown bins | Total bins |
| --- | --- | --- | --- | --- | --- |
| LDFlute_stac_A3_v1_rr1 | 69 | 33 | 0 | 28 | 61 |
| LDFlute_stac_C4_v1_rr1 | 72 | 41 | 0 | 35 | 76 |
| DCClar_stac_D3_v1_rr1_sum | 62 | 6 | 0 | 43 | 49 |
| DCClar_stac_A#3_v1_rr1_sum | 70 | 17 | 0 | 31 | 48 |
| PSBassoon_C2_v1_rr1 | 48 | 28 | 3 | 32 | 63 |
| PSBassoon_A2_v1_rr1 | 57 | 39 | 0 | 16 | 55 |

Each bin represents 10 ms of measured extent; all samples have zero bins classified
as silence. Five sources pass the independent check: at least one stable reference
run and no different stable admitted note. This does not imply full coverage:
the clarinet D sample supplies only 60 ms of stable pitch. Unknown bins include
attacks/decays and unresolved pitch, not established silence. These isolated-note
labels cannot validate exact physical note boundaries or song transcription.

The bassoon C sample fails: MIDI 67 is admitted for three channel-0 bins at
converted frames 3787..4027 despite reference MIDI 48. The same error exists in
the original audio. A separate channel-1 comparison admits twelve wrong bins in
both original and converted audio. This is a known pitch ambiguity, not a
resampling failure. It remains explicitly deferred and excluded from the checked
default-window blend; thresholds were not adjusted to pass it. The explicit
longer-window policy below admits channel 0, while robust harmonic/decay admission
remains required for broader recorded-instrument accuracy.

### Explicit analysis width on the recorded sources

The same six recordings now also run under one declared 110 ms dense-window
policy: 880 frames at 8000 Hz and 4851 at the original 44100 Hz. Channel 0,
10 ms hop, three-window minimum run and every estimator/admission threshold stay
unchanged. This policy was selected after inspecting the known bassoon failure;
these are regression/reference checks, not an unseen-corpus accuracy study.

| Sample | Correct stable bins at 8000 Hz | Unknown bins | Total bins |
| --- | --- | --- | --- |
| Flute A / MIDI 69 | 37 | 16 | 53 |
| Flute C / MIDI 72 | 43 | 25 | 68 |
| Clarinet D / MIDI 62 | 7 | 35 | 42 |
| Clarinet A-sharp / MIDI 70 | 18 | 22 | 40 |
| Bassoon C / MIDI 48 | 30 | 26 | 56 |
| Bassoon A / MIDI 57 | 38 | 10 | 48 |

All six have zero wrong stable bins and zero silence bins under this channel-0
policy. Original-rate checks also have zero wrong bins; flute A has 39 correct /
14 unknown and bassoon C has 31 / 25, with the other counts unchanged.
The smaller total bin counts reflect unanalyzed edges from longer complete windows.
This does not prove exact physical note boundaries. A separate bassoon channel-1
check still admits ten wrong bins at both rates and remains deferred.

Longer windows are not the new default. An independently authored sequence of
60 ms notes supplies 58 stable bins under the short default and none at 110 ms.
The caller needs this resolution/periodicity tradeoff as a modular control.

```text
pythian.pitch.wav inspect-runs INPUT.wav REPORT.json CHANNEL --monophonic --window-frames 880
pythian.pitch.wav learn-runs INPUT.wav PREFIX CHANNEL --monophonic --window-frames 880
pythian.style learn-duration CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic --window-frames 880 [PROVENANCE]
```

The bassoon C profile retains its 880-frame measurements through a blend with
the existing 294-frame flute profile and a second blend with bassoon. The saved
result has two sources, depth three, five ancestry nodes and weights 2:1. Actual
WFC performance/voice passes render note 48 with five arranged notes over 19845
stereo frames. Pinning duration `1:316` selects the flute performance, changes
pitch to 69 and renders 21452 frames while retaining key/tempo state. Different
recordings may have different analysis widths; conflicting measurements of the
same source hash remain rejected. Unknown evidence remains unknown.

Checked stable/development Win32 and stable Win64 pass core geometry/replay,
the twelve channel-0 recording checks and saved-style voice verification. The
baseline WAV/MIDI/preview/report and style inspection match across all three
targets. The complete maintained recorded workflow passes on stable Win32.
Logs: `build/pitch-window-{stable,trunk,win64}/`, including `replay.log`,
`recorded-workflow.log`, `workflow-status.log` and final `final-core/run.log`.
The ordinary full build retains its preceding checkpoint; it was not repeated
for this explicit-window addition.

### Preceding default-window saved blend

The admitted flute A and bassoon A sources pass saved learning, a 1:1 blend, then
a second blend with flute (final weights 2:1, depth 3, five ancestry nodes).
With explicit held context, three-span prefix generation now consumes one actual
key state, one tempo state and all three performance states, rendering MIDI 69.
Pinning `1:374` switches the observed performance to MIDI 57 and retains exact
accepted key/tempo states. Current normalization admits both sources through their
two-cell context boundary, producing 21452 baseline and edited stereo frames.
Pitch and gates differ; raw evidence retains the excluded tails. The native
output checker validates actual WFC paths with the selected extent, model/source
binding, every audible pitch, PPQ boundaries and every unknown-output frame.
Timbre/velocity are authored synthesis; the source instrument sound is not learned.

These short sources provide two context grid cells. Earlier verification used a
two-span prefix, but a subsequent comparison confirms the prior operator also
renders three prefix spans. The earlier failure was the interior-fragment boundary
rule, not a hard two-cell context limit. `--context hold` now explicitly
holds each single-valued context model across all generated performance spans.
This covers all measured spans of the selected sample, not its unmeasured clip
edges or original instrument timbre. Longer performance requests still cannot
invent transitions; changing context requires explicit temporal scope mapping.
Evidence is under `build/recorded-pitch-{compiler}-i386-win32/`; per-source
`*-reference.log`, `*-raw.log`, hashes and dense JSON retain both passes and failures.
The optional workflow is separate from the ordinary offline build.

FPC 3.2.2 and 3.3.1 i386-win32 reproduce these results. All 27 current converted
WAV/context/style/report/output artifacts match across compilers; see
`build/recorded-pitch-replay.log` and `build/recorded-pitch-{stable,trunk}.log`.

## Saved duration styles

```text
pythian.style learn-duration CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic [--articulate-onsets] [--window-frames N] [PROVENANCE]
pythian.pitch.wav generate-style-runs PROFILE.pys OUTPUT.wav [--spans COUNT] [--extent prefix|fragment] [--context hold|sequence] [--duration-lock CELL:TICKS]
```

Duration learning adds dense evidence to the existing source profile alongside
cell pitch, onset and intensity measurements. The current PYST format stores all
window diagnostics/settings and the optional canonical duration model. Decoding
replays native admission and bounded actual learning without reopening the WAV.
Superseded development archives must be regenerated; no historical reader is kept.

Duration follows the existing pitch-source weights, preserving observed
pitch/kind/duration relationships through repeated blends. `HasDuration` requires
dense evidence for every positive pitch contributor. Each source uses its own
clock to normalize admitted physical intervals to the profile's PPQ ticks.
Other capabilities remain usable if dense coverage is unavailable.
`CopyDurationTrack` returns detached per-source evidence, including inactive
dimensions retained in the active source table. Full ancestors remain embedded.

### Explicit onset-assisted duration

`--articulate-onsets` records `DurationArticulateOnsets` on that source. Its
already admitted physical source-onset locations map through the source's full
clock and offset to PPQ ticks, independently of nearest rhythm-grid cells.
Locations outside the finite source scope are excluded. Core
`RearticulatePitchSpans` splits only inside known pitched spans. It preserves
pitch, total extent and unknown/silent intervals; boundary cues do not create
zero-length notes. Distinct locations collapsing to the same PPQ tick reject.
The core accepts ordered non-overlapping canonical spans and strictly increasing
nonnegative attack ticks, with each input/output bounded to 65536 entries.
Returned spans are detached, and failure preserves the accepted result.

This is explicit ownership of source attacks by a declared monophonic pitch
track. It does not identify which instrument caused an onset in mixed audio.
Raw pitch windows remain unchanged. The resulting durations enter the existing
joint pitch/kind/duration model, using pitch-source weights; they are not
replaced by independently sampled onset durations. A source capability bit in
the current PYST format retains the policy through decoding and weighted
second blends. Absence selects ordinary pitch-only spans. No separate file
version or historical reader was added. Conflicting policies for the same
source identity still reject under the existing evidence-consistency rule.

The controlled four-second A4 source has recurring amplitude attacks but one
stable pitch run. Unchanged detectors find seven usable interior onsets, each
three frames after its authored 4000-frame boundary. The policy produces eight
pitched spans instead of one. A native sustained-versus-articulated comparison
uses one and eight performance positions, pinning the final observed 464-tick
duration in the latter. Both outputs contain 175113 stereo frames at 44100 Hz;
the melody has one versus eight attacks, and the authored stack has five versus
forty MIDI notes. Accepted key/tempo states and measured extent remain exact.
This supports a controlled articulation claim, not general note-onset accuracy.

A two-source second blend retains the source flag, 2:1 pitch weights and five
ancestry nodes, producing 16 performance spans / 80 notes / 352248 frames.
Native checks independently verify every new source-clock boundary, actual WFC
paths, MIDI gates and preview PCM. Additional checks exercise a changing clock
with physical offset 97, collapsed attack rejection and absent-duration rejection.
Seventeen focused artifacts match stable/development Win32; stable Win64
cross-loads and checks the saved output. Evidence:
`build/onset-duration-{stable,trunk,win64}/`, including `checks.log` and trunk
`replay.log`. The full stable Win32 workflow passes (`full-build.log`,
`full-status.log`); the final capability guard and valid replay additionally pass
on all three targets in `final-boundary-checks.log`. [Work](WORK.md) records scope.

### Duration generation

Generation uses three actual named WFC passes: key, tempo and performance. The
selected key is retained as context; measured pitches keep their absolute register.
The performance model defaults to eight pitch/silence/unknown spans. `--spans`
selects 1..1024 spans within existing state/work and 120-second output budgets.
`--extent fragment` starts inside a learned run, excluding WFC beginning-history
states; `--extent prefix` starts at an observed recording beginning. The latter
supports short source runs that have no admissible interior continuation. In default `--context sequence` mode these
choices apply to all three providers. Explicit `--context hold` instead solves
key and tempo in separate one-cell prefix passes, while performance retains its
requested count/extent. Each context model must contain exactly one canonical
public value; changing or alternative values reject, and an unknown key stays
unknown. The original saved models, observations and hashes remain unchanged.
The selected values hold to the generated endpoint as an explicit output policy,
not a claim of measured source scope. Reports retain each provider's actual path,
its extent, `context_mode` and `context_hold_end_tick`. Impossible extents still
reject. Normalized PPQ duration tokens accumulate directly into output tick
boundaries; the solved tempo pass controls physical output time. Source admission
rounds endpoints through each full source clock before model learning.

`--duration-lock 0:384` pins the first performance span to an observed 384-tick
alternative. Actual selective regeneration changes only the performance pass,
preserving accepted key/tempo states. Pitch or span kind can change with a
duration edit because their observed relationship is retained. Selecting a
different tempo through `blend-dimensions` preserves the performance model/states
and changes audible timing. Unknown spans remain explicitly distinct in reports
and render silently under the stated output policy, with strict native gates.

Two controlled sources pass a saved second derivation with pitch weights 2:1 and
five ancestry nodes. Independent tempo selection retains the duration source
timebase and adds a seventh ancestry node. The base output contains four notes in
44100 stereo frames; selecting 750000 rather than 500000 microseconds per quarter
preserves those notes/states and produces 66150 frames. The duration pin changes
the output to three notes in 93528 frames while retaining exact key/tempo states.
Native checks validate all three saved-model paths, cumulative PPQ rounding,
every audible pitch and every silent/unknown frame. Invalid pins and unavailable
duration capabilities preserve prior output files.

FPC 3.2.2 and 3.3.1 pass on i386-win32. Fifty-five current style/report/audio/MIDI
artifacts, including existing style regressions, match across compilers.
Evidence: `build/duration-style-verified-{stable,trunk}/`,
`build/duration-style-replay.log`. The subsequent duration-driven accompaniment
integration is described below. Recorded-instrument accuracy and broader musical
admission remain open. This is focused validation, not a fresh full-suite or delivery checkpoint.


Held context uses [independent layer scopes](LAYERS.md#per-layer-scopes), with
actual WFC layouts and no added learning samples. FPC 3.2.2 and 3.3.1 i386-win32
pass independent 1/3/6-cell prefix/whole/wrapped layouts, detached scope ownership,
per-layer masks and selective state preservation. The recorded three-span example
and controlled eight-span example pass every audible pitch, unknown/silence gate
and clock check; selecting 750000-us tempo preserves performance and scales time
by 3:2. Default sequence audio remains unchanged. Evidence and remaining temporal
mapping limits are recorded in [the current work record](WORK.md).

The [duration voice mode](INDEPENDENT-VOICES.md#measured-duration-driving-dependent-voices)
now feeds saved pitch/kind/duration spans into the actual five-pass accompaniment
planner. Measured pitch controls melody; measured spans control bass/chord/melody
gate endpoints in native MIDI and audio. Key holds; tempo can either hold or use
an [independent finite cell scope](INDEPENDENT-VOICES.md#independent-tempo-scope-for-measured-performance)
that advances through learned spans without reattacking held notes. A duration or pitch lock regenerates that
provider while retaining accepted context, then rebuilds dependent voice models.
Unknown/silence spans become exact output rests, not inferred missing notes.
Accompaniment pitches, intensity, timbre and meter remain authored. The logical
WFC score's required bar padding is excluded from training and realized output.

## Saved pitch styles and layer control

[pythian.pitch.cells](../src/pythian.pitch.cells.pas) shares bounded cell-centered
measurement between the standalone operator and style learning. It retains
window/channel/range/threshold/tuning settings and each periodic estimate. Admission
checks the complete declared source grid, measurement availability, finite values,
frequency/period agreement and equal-tempered note/cents consistency. Cells too
short for the window remain unknown. Limits are 1024 cells and 268435456 difference
terms per recording. It contains no WFC types.

```text
pythian.style learn-pitch CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic [PROVENANCE]
pythian.style blend LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_WEIGHT RIGHT_WEIGHT OUTPUT.pys
pythian.voices.demo OUTPUT.wav --style PROFILE.pys [--pitch-lock CELL:NOTE] [--coupled-pitch] --verify
```

Learning explicitly declares monophony and measures pitch plus onset intensity
from the same hashed WAV. The current PYS format retains the complete pitch evidence,
estimator/cell versions and canonical actual pitch model. Decoding replays
admission and bounded weighted WFC learning without reopening recordings.
Pitch and dynamics are optional capabilities within that one format. Positive
pitch contributors require measured pitch; positive rhythm contributors must
agree on intensity availability. Other dimensions can come from different sources.
A zero-weight parent stays in ancestry without making its capabilities active.
Earlier development encodings are retired; regenerate their files from source
evidence. The decoder has no historical version branches or migration adapter.

Repeated blending coalesces identical source evidence and reduces integer weights
independently for rhythm and pitch, with unknown gaps splitting pitch training runs.
This learns absolute pitch history separately from onset/intensity history.
Use `blend-dimensions` to select or weight pitch sources independently of rhythm
and its joint intensity history; both pitch weights zero explicitly omit pitch.
When both dimensions have identical normalized source weights, the profile also
retains observed pitch/onset pairs and optional intensity on those same cells.
Unknown pitch gaps split these paired runs. Different dimension source vectors
leave this joint capability unavailable. Source clocks are still declared, with
no inferred downbeat or duration.

The voice operator adds a named pitch pass after key, tempo, onsets and optional
intensity. Pitch-enabled provider sessions use fragment boundaries because unknown
cells split observed pitch runs. The solved pitch supplies the melody; onset and
intensity control attacks and velocity. Five dependent harmony/rhythm/voice passes
then generate native stereo audio, reference preview and MIDI. The melody retains
absolute source register and may cross chord voices; authored bass/chord spacing
and per-voice pitch-class contributions remain enforced. Compatible voicings stay
available. There is no implicit pitch transposition or claim that authored
accompaniment was learned from a recording.

`--pitch-lock 1:72` pins zero-based cell 1 to MIDI note 72 in the actual named
session, then rebuilds dependent voice realization. A pitch-only edit preserves
accepted key/tempo/onset/intensity models, tokens and latent states. Unsupported
notes or incompatible paths fail before writing outputs. The one-pin CLI is an
operator convenience; the library session accepts complete per-cell masks.

`--coupled-pitch` explicitly inserts a named `pitch-rhythm` provider after key and
tempo. Actual WFC projections constrain onset, optional intensity and pitch
consumers to the observed pairs. Editing any consumer regenerates the provider
and its dependent consumers while preserving accepted key/tempo states. Thus a
coupled pitch edit may change onset timing and intensity. Independent generation
remains the default. Requesting coupling without matched source weights rejects.
Consumer pins also restrict the provider's observed alternatives before search;
consumer projections remain enforced. This avoids searching unrelated paired
paths before reaching a downstream pin, within the unchanged search budget.

The paired model records cell co-occurrence and history within known-pitch runs.
It does not identify which note caused an onset, infer note lengths or separate
polyphonic voices. Its optional model field belongs to the current style format;
superseded development archives must be regenerated.

## Verification

The core fixture compiles without WFC. Sixteen periodic cases cover sine signals,
stronger second harmonics, missing fundamentals and DC offsets at four frequencies.
Maximum error among those cases is 5.146067 cents. Separate cases check noise/DC
unknowns, explicit tuning tolerance, opposite stereo phases and invalid window
preservation. This controlled result is not a general recorded-music accuracy rate.

An authored eight-second, 8000-Hz mono harmonic WAV contains 30 pitched cells and
two silent cells. The operator receives only WAV bytes and declared timing/channel,
not the fixture's note labels. All 30 measured notes match the independent reference;
both silent cells remain unknown. Weighted/run-boundary fixtures compare the actual
model with manually specified independent training samples. A separate process
loads the saved pitch model and renders 32 notes. The output checker validates
source/model hashes, the actual WFC path and every rendered pitch measured in audio.

Both checked FPC versions pass on i386-win32. Six source/model/report/audio files
match byte-for-byte. Invalid channel selection preserves both prior learning files.
Logs and listening files: `build/pitch-{stable,trunk}/`; replay: `build/pitch-replay.log`.

Pixel Sprinter inspection under the documented default range, threshold, channel 0
and declared 428571-us clock produces no admitted pitch candidates in its 160 cells:
all are no-period outcomes. That is evidence that this strict single-source path
does not recover its mixed music, not evidence that the recording has no pitches.
Its candidates are not used to manufacture a learned melody.

The saved-style extension uses two native harmonic WAVs, one an octave above the
other. Both measured tracks match 30 independent note labels and preserve two
unknown cells. The saved second blend retains weights 2:1, two sources and all five
ancestry nodes; its pitch model matches the explicitly specified weighted runs.
The full voice workflow renders 17 attacks / 85 notes, verifies each melody pitch
against its actual saved-model state path, and checks native preview/MIDI parity.
A pitch-only edit preserves all four independent provider passes and changes
audio. An unsupported pitch preserves all prior outputs.

Both FPC 3.2.2 and 3.3.1 pass the maintained extension workflow on i386-win32.
At that pre-consolidation checkpoint, nineteen new artifacts matched across
compilers, and sixteen earlier fixture, standalone pitch and render artifacts
retained their bytes. Those historical format comparisons are not ongoing
compatibility requirements; the current format supersedes those PYS encodings.
Logs: `build/pitch-style-verified-{stable,trunk}/`, `build/pitch-style-replay.log`.
The controlled fixtures establish this supported path, not general song
transcription or listener approval. No additional target/package claim is made.

The observed-pair extension passes on both checked compilers. Manually specified
weighted paired samples verify actual learning across unknown gaps and source
boundaries. Saved second derivation retains its paired model. Coupled baseline,
pitch edit and second-blend outputs each contain 24 attacks / 120 notes; every
generated pair, melody attack and actual audio/MIDI hash is checked. Base context
remains exact through the edit. Unavailable coupling preserves existing outputs.
Forty-six current profile/model/report/audio files match across compilers.
Evidence: `build/pitch-rhythm-verified-{stable,trunk}/` and
`build/pitch-rhythm-replay.log`. The coupled operator currently requires complete
consumer projection maps; tokens seen only where pitch is unknown can make that
mode unavailable even when a paired model exists.
