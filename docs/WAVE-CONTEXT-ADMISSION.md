# Explicit WAV context admission

[Home](../README.md) · [Typed context](MUSIC-CONTEXT.md) ·
[Reusable profiles](CONTEXT-PROFILES.md) · [Style direction](LAYERED-STYLE.md)

## Changing-tempo pulse ranges

`AdmitBeatTrackRange` in `pythian.music.context.admission` admits an explicitly
selected inclusive range of local tracker pulse indices. The caller declares
each consecutive pulse interval one quarter note; this does not establish meter,
downbeats or the correct metrical level. The selected range must remain within
one supported path. Gaps, restarts, uncertain joins, unordered positions and
invalid source/clock extents reject without replacing the caller's result.

The returned `TBeatTrackAdmission` includes the original first/last source frames,
a typed context grid, integer tempo changes and signed boundary errors. Tick zero
is the first selected pulse. Each tempo comes from the difference of rounded
cumulative microsecond positions, avoiding accumulated interval-rounding drift.
The step must divide PPQ. No leading or trailing time is extrapolated. Key is a
separate caller declaration, with the canonical unknown preserved.

The native operator uses the existing WAV measurement frontend and local tracker:

```text
pythian.context.track inspect INPUT.wav REPORT.json [--clock linear|step [--alignment-context]]
pythian.context.track admit INPUT.wav EXPECTED_SHA256 FIRST_PULSE LAST_PULSE ROOT MODE PREFIX [--clock linear|step [--alignment-context]]
pythian.context.track audition PROFILE.pcp OUTPUT.wav
```

Inspection exposes all candidate windows, selected path, raw/adjusted pulse
positions, source observations and policies. Admission adds the chosen range,
clock, source offset and boundary errors; the saved profile binds the exact
report hash and original WAV hash. `TContextEvidence.SourceFrameOffset` carries
the clock origin as typed data through archive copies and profile selection.
The current development context layout includes this field; regenerate earlier
context bundles/profiles and containing styles rather than retaining old readers.

Audition reloads the saved key and tempo models and uses actual WFC passes pinned
to the selected evidence. Authored short tones mark complete quarter intervals
on that changing clock. It is a generated timing audition, with no original
source audio or learned voice pitches. Different provider extents and incomplete
quarter scopes reject. Output begins at the selected pulse, excluding the source
prefix. Report/profile writes are individually checked, not a multi-file transaction.

The controlled 120-to-100 BPM WAV supplies 24 tracked pulses, 23 complete quarter
intervals and 46 half-quarter context cells. Saved-model audition contains 23
verified pulse gates in 555660 stereo frames at 44100 Hz. The native verifier
replays source measurements, track alternatives and admission, verifies exact
report/source bindings, and checks every cue interval and intervening silent frame.
Core admission also checks exact authored positions, fractional-rate rounding
and gap rejection. This does not establish general recorded beat accuracy.
The complete stable Win32 build and focused development Win32 workflow pass;
their controlled report/profile/WAV bytes match. Both compilers also pass the
core admission fixture on Win64. Logs: `build/track-full-stable.log`,
`build/track-admission-trunk/`, `build/track-admission-replay.log` and
`build/track-core-{stable,trunk}-win64/`.

The previously attributed Pixel Sprinter recording also passes on FPC 3.3.1
Win32: selected pulses 0..79 span source frames 18855..1507404 with no flagged
grid joins, producing 158 context cells. Saved-model audition has 79 cues in
1488549 stereo frames, with unknown key preserved. All source/report/profile
bindings and cue/silence gates pass (`build/track-admission-trunk/pixel-workflow.log`).
The report retains candidate uncertainty; the selected path is not annotated
beat/downbeat ground truth. The source recording is not included in the audition.

The [WAV style learner](WAVE-STYLE.md#native-rhythm-admission) now consumes these
relative changing clocks for rhythm, intensity and centered pitch cells. Saved
styles retain their full source maps through repeated blends, and actual voice
generation can use the changing tempo provider. Dense duration styles also normalize measured intervals through their own source
clocks to PPQ tick durations before weighted model learning.

<a id="reconstructed-clock-ranges"></a>
## Reconstructed clock ranges — 2026-09-20

`AdmitBeatClockRange(windows, observations, clockOptions, sampleRate, sourceFrames,
firstPulse, lastPulse, PPQ, stepTicks, key)` connects the maintained
[selected-clock representation](BEAT-TRACKING.md#selected-clock-api) to the same
context grid and saved WFC providers. It returns the existing
`TBeatTrackAdmission` result. The library reconstructs from the supplied selected
windows and observations rather than trusting an edited derived frame array.
Use `SelectedBeatClockWindows(track.Windows)` for the current tracker selection.

As with track admission, the caller explicitly declares consecutive quarter-note
intervals and a separate key decision. Cumulative microsecond rounding, source
offset, grid limits and boundary errors use the shared native conversion. A range
cannot cross missing windows, explicit restarts or an unavailable/numerically
ambiguous phase segment. The barrier check covers both raw and aligned range
extents. Selecting a separate supported range after a gap remains valid. These
checks do not establish musical confidence or resolve the wrong beat level.

Append `--clock linear` or `--clock step` to inspection and admission to select
the reconstruction used for pulse indices. Inspection retains the original track
and adds the complete clock report. Admission recomputes from the reviewed WAV
hash, saves `explicit_reconstructed_pulse_range`, and binds the report—including
shape, tolerances, segments and positions—into the existing profile evidence.
Audition needs no new flag: it reloads the saved key/tempo models and runs actual
WFC passes using their saved evidence. The PCP layout and admission contract
remain current; no format version or historical reader is added.

Optional `--alignment-context`, immediately after the clock shape, enables
[neighbour-supported alignment](BEAT-TRACKING.md#alignment-api). Reports preserve
original/selected observation indices, witness envelopes and unknown/unavailable
decisions. Admission still requires the caller's explicit quarter-note range:
raw fallback is a reviewed clock position, **not an admitted observed beat**.
The profile records this distinction and binds the complete report hash. Saved
generation uses the caller-admitted timing and does not reinterpret unknown
onsets as measured confidence. Core callers select `bcaNeighbourSupported` in
the same existing admission options; no additional profile layout is needed.

The optional path passes source/report/profile replay and actual WFC generation
on the authored tempo change (23 pulse tones, 555660 frames) and the recorded
acceleration development source (37 pulse tones, 701108 frames). All are stereo
44100-Hz outputs. Default authored report/profile/audio remain byte-exact against
the earlier checkpoint. Evidence is under `build/beat-alignment-adoption/`;
this is explicit caller admission, with no additional automatic musical claim.

Both shapes pass the authored 120→100 source through saved profiles and actual
WFC, producing 46 cells and 23 pulse tones in 555660 stereo frames. The existing
recorded acceleration development source, using the maintained selection with
linear reconstruction, admits pulses 0..37 into 74 cells. Reloaded WFC models
produce 37 authored pulse tones in 701080 frames at 44100 Hz. Unknown key remains
unknown. The source is ARTBeaT by Rico Rosenbusch, CC BY 4.0, with the previously
retained notices. No reference annotations enter admission; this explicit range
does not constitute automatic quarter-note acceptance or learned voice pitches.

The native verifier replays source measurements, tracker alternatives, every
clock field, admission boundaries, saved provider evidence and cue/silence gates.
The new authored report/profile/WAV replay byte-for-byte. The default workflow
also matches all three artifacts from its earlier checkpoint exactly. Focused
core clock/admission and existing track tests pass checked stable Win32/Win64
and trunk Win32, including rejection across gaps, restarts, ambiguous and rejected
phase spans, plus result preservation and separately admitted ranges after gaps.
The maintained build includes the new saved-profile/audition workflow.

Current source packages include this API. An external core-package admission
fixture and an external WFC context consumer verify the new path using extracted
library units; its report/profile/WAV match the workspace artifacts exactly.
Evidence is under `build/clock-context-adoption/`. This closes the explicit
reconstruction-to-context connection, while automatic arrangement/rate decisions,
change timing, endpoint coverage, local-key calibration and independent musical
acceptance remain in [PULSE/CONTEXT](MILESTONES.md#wav-02-context).

## Global context admission

Measured WAV tonal evidence can now accompany an explicit key decision and a
caller-declared constant tempo into saved, reusable WFC context profiles. An
optional measured-tempo path now ranks global pulse candidates and admits an
explicitly selected candidate through the same profile contract.
Unknown key remains a supported decision. The tool never automatically promotes
the highest-ranked fit to a key or automatically selects a musical pulse level.

## Selected beat phase and source scope

```text
pythian.context.wav inspect-beats INPUT.wav REPORT.json
pythian.context.wav admit-beats INPUT.wav EXPECTED_SHA256 CANDIDATE_RANK ROOT MODE OUTPUT_PREFIX
```

The native `pythian.beat.wave.MeasureWaveBeats` function shares the existing
onset-localization, event admission and weighted pulse fit with `pythian.beats`.
Inspection retains the analysis/admission/grid settings, admitted observations
and ranked tempo/phase candidates. The original beat operator retains identical
report bytes on the controlled comparison after this extraction.

`AdmitBeatContext` accepts an explicitly selected hypothesis. Its measured period
is rounded to integer microseconds per quarter, then phase is rounded to the
nearest source PPQ tick, with half ties later. The report records signed period
error per beat and the admitted floor-frame origin minus measured phase. These
are quantization errors, not estimates of musical accuracy. The existing PCP
grid's `StartTick` retains the source origin; generation has its own output clock.

`WaveContextScope`, `AdmitWaveRhythm`, `MeasurePitchCells` and `AdmitPitchCells`
now take an optional source start tick, default zero. Complete cells start there;
leading observations remain outside the admitted scope, and the end must still
fit the exact source clock. Scope reports expose floor/ceiling start and end
frames. `UnassignedWholeFrames` continues describing the tail; the reported start
boundary separately identifies the excluded prefix. No source samples are moved.

Saved style evidence binds `SourceStartTick` to its actual tempo provider and
uses it for rhythm quantization and centered pitch measurement. Each source keeps
its own origin through repeated weighted blends. Dense pitch-duration evidence
retains the original whole-source hop measurements. Separate musical admission
intersects those intervals with the selected scope and normalizes them to PPQ ticks. The current PYST schema now
includes this source origin; earlier development PYS fixtures must be regenerated.
The PCP schema is unchanged, and no historical style reader is retained.

On the authored 8000-Hz phrase shifted by 1000 frames, selected rank zero is
120 BPM. Its fitted phase is approximately 1025.487 frames; tick 123 maps to
frame 1025, an error of -0.487 frames. Fifteen complete cells retain seven onsets
at an 80-frame tolerance. A frame-zero control admits none from the same onset
evidence. Aligned pitch windows recover the known C/E/G/high-C notes. Two source
origins survive a weighted second derivation, and onset/intensity passes drive
31 attacks / 155 authored-pitch notes in 710892 stereo frames.

The recorded Pixel Sprinter example explicitly selects rank one: 139.75 BPM,
429338 us/quarter and source tick 411. The admitted origin is floor frame 16212 /
ceiling 16213; phase error is -1.735 frames, period error -0.004576 frames per beat.
Its 158 cells admit 89 onsets. A recorded/controlled second blend produces
39 attacks / 195 notes, 605881 preview frames and 611173 stereo frames. The
70-BPM alternative remains visible. These are selected pulse hypotheses, with
uncalibrated support; the source has no independently verified beat/downbeat labels.

Controlled core/profile/style checks and the exact maintained workflow pass on
FPC 3.2.2/3.3.1 i386-win32. Eighteen source/profile/style/audio/MIDI/report files
match byte-for-byte (`build/phase-replay.log`). The recorded workflow has
stable Win32 evidence under `build/phase-admission-stable/`; development evidence
is under `build/phase-admission-trunk/`. Source/report hashes, full beat replay,
actual WFC paths, native audio and MIDI are checked. A 64-cell coupled-pitch
request from the short gapped phrase fails; the successful rendering uses learned
onset/intensity and authored pitches. The full maintained stable Win32 build also
passes with current style fixtures regenerated (`build/phase-full-stable-status.log`).
Local tempo changes, downbeat/meter, broader
beat accuracy and mixed-song voice inference remain open.

## Measured tempo candidates

[pythian.tempo](../src/pythian.tempo.pas) is a standalone native analysis primitive.
`RankTempoCandidates` consumes existing spectral-flux features with their exact
source geometry and analysis settings. It uses complete windows, excludes the
first spectrum's startup flux and silent windows, subtracts a centered one-second
local mean and retains positive onset strength. Normalized autocorrelation ranks
local lag peaks; quadratic interpolation estimates a sub-hop period. Integer
microseconds per quarter are rounded from that measured sample period.

The default search is 40..240 BPM, flux threshold 0.05, minimum correlation 0.2,
at least four periods of source coverage and four positive feature pairs, and
eight retained candidates. These are explicit measurement heuristics, not
calibrated confidence or a count of independently confirmed beats. There is no
preferred-rate prior or half/double-time folding. Silence, a lone onset, too-short
excerpts and no qualifying peaks produce explicit absent-evidence statuses.
Correlation work is bounded at 32 million feature pairs, in addition to existing
analysis budgets. Nonfinite values, mismatched geometry and invalid settings
reject before replacing a previously assigned result. Flux up to 1 + 1e-6 is
clamped to accommodate existing spectral accumulation rounding; larger values reject.

Autocorrelation of onset strength is informed by
[Ellis's tempo/beat-tracking work](https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf).
This implementation reuses Pythian's spectral features and implements its own
bounded ranking. It does not implement that paper's dynamic-programming beat
tracker, Mel onset frontend or tempo prior, and does not claim its evaluation results.

```text
pythian.context.wav inspect-tempo INPUT.wav REPORT.json
pythian.context.wav admit-tempo INPUT.wav EXPECTED_SHA256 CANDIDATE_RANK ROOT MODE OUTPUT_PREFIX
```

Inspection records all candidates, lag/sample periods, integer tempos, correlations,
support counts, status and settings. Admission recomputes measurements from the
reviewed source, requires an available zero-based rank and stores the selected
tempo in the normal PCP profile. Unknown key remains available. The exact report
hash stays in profile evidence and is retained through saved styles and repeated
blends. No archive revision or historical reader is added. Preserve the report;
generic profile decoding still does not reopen external measurement evidence.

These are global pulse-rate candidates, with no beat phase, downbeat, meter or
tempo-change map. Frame zero remains an explicit origin. A slightly different
measured tempo can change the number of complete source cells; fractional final
cells are excluded by the existing exact scope policy. A 64-cell whole-sequence
request need not fit a learned 15-cell onset pattern. The voice operator accepts
`--style-extent whole|prefix|fragment` to state the intended provider boundaries;
this does not add observations or silently relax the default extent.

## Native boundary

[pythian.music.context.admission](../src/pythian.music.context.admission.pas)
has no WFC dependency. `AdmitTonalContext(Weights, SelectedKey)` retains the
requested key, its zero-based candidate rank and the complete native tonal
report. Known keys require nonzero evidence; an explicit non-top candidate is
allowed. Unknown is root -1 with major mode and selected rank -1, including when
nonzero evidence exists. Major here is the canonical encoding of unknown, not
a tonal claim. Scores and score gaps are not calibrated probabilities.

`WaveContextScope(Rate, SourceFrames, TempoUs, PPQ, StepTicks, Key)` builds a
constant key/tempo grid starting at tick zero. Exact native clock arithmetic
finds complete cells whose ceiling sample boundary is within the source. It
returns the endpoint's floor and ceiling frame indices and remaining whole
frames. It admits 1..65536 cells and rejects excessive timeline/context budgets
instead of clipping them. Invalid calls preserve a previously assigned result.

For example, at 1000 Hz, 500001 microseconds per quarter, PPQ 480 and step 240,
a 1000-frame source admits three cells: endpoint floor 750, ceiling 751, with
249 whole frames unassigned. At 1001 frames it admits four cells, ending at
floor 1000 / ceiling 1001. Frame zero is a clock origin, not a verified downbeat.

## Operator workflow

The normal build includes [pythian.context.wav](../tools/pythian.context.wav.lpr):

```text
pythian.context.wav inspect INPUT.wav REPORT.json
pythian.context.wav admit INPUT.wav EXPECTED_SHA256 TEMPO_US ROOT MODE OUTPUT_PREFIX
```

Inspect first to obtain source identity, analysis settings, twelve duration-
weighted pitch-class weights and all 24 major/natural-minor fits when evidence
is nonzero. Admission recomputes those measurements and requires the reviewed
WAV SHA256. Select root 0..11 and `major` or `minor`, or `-1 major` for unknown.
Tempo is an exact integer microseconds-per-quarter value; 500000 means 120 BPM.
The command uses PPQ 480 and step 240. The core API allows other explicit grids.

Admission writes `OUTPUT_PREFIX.json` and `OUTPUT_PREFIX.pcp`. The report records
measurement versions/settings, source geometry/hash, selection/rank, declared
tempo, grid and endpoint boundaries. The profile contains the admitted grid,
source hash and actual separately learned key/tempo WFC models. Its admission
policy includes `report_sha256=` followed by the hash of the exact JSON bytes.
The measured weights remain in the external report. General profile decoding
does not open that report or execute its descriptive policy; consumers must
verify the binding when they need the measurement evidence.

Both artifacts are constructed and validated before individual, non-atomic
writes. A reviewed-source mismatch rejects before either output is written.
A later filesystem failure can leave only one updated artifact. Preserve the
report together with its profile. The existing bounded WAV analysis and source
hash checks apply; see [analysis limits](ANALYSIS-WAVE.md).

The result is a normal source context profile. It can supply either dimension
to [the existing selector](CONTEXT-PROFILES.md), and derived selections can be
used again. Selection does not pool measurements, infer joint observations or
transpose/retime the source recording.

The [independent-voice operator](INDEPENDENT-VOICES.md#saved-context-feeding-the-voice-stack)
now renders selected context through authored bass, chord and melody models.
Its demonstrated derived input combines this native WAV fixture's key with
Pixel's declared tempo; the resulting voice material is synthesized.

## Measured-tempo evidence

Checked native FPC 3.2.2 and 3.3.1 i386-win32 runs find 119.8352 BPM in the
authored 120-BPM phrase and 139.9098 BPM in Pixel Sprinter, whose source declares
140 BPM. Pixel's highest-ranked candidate is 69.9786 BPM; the documented-rate
candidate is rank 1. Both remain in the report. This demonstrates a usable
measured candidate and metrical ambiguity, not automatic correct-rank selection.

Selected clocks are 500688 and 428848 microseconds per quarter. Exact source
admission retains 15 and 159 complete half-quarter cells respectively. The
profile checker hashes the source/report, recomputes every tempo candidate,
checks the selected clock and runs the saved key/tempo models through actual WFC
passes. Pixel's key remains unknown. A blend selects the controlled key and Pixel
tempo, combines onset evidence and survives a second blend at 2:1 source weights,
depth 3 and five parent nodes. Native generation renders 53 attacks / 265 notes,
with 605190 preview frames and 610482 stereo frames including authored release.
Preview PCM and MIDI match the actual companion renderer/encoder.

The maintained offline block uses the controlled measured profile directly with
explicit prefix semantics, then checks saved-style binding and audible output.
Logs live under `build/tempo-admission-{stable,trunk}/`; this is focused validation,
not a full build, package, CI or additional-platform checkpoint. Existing declared
context commands keep their previous report/profile bytes. Invalid candidate
selections and source hashes preserve accepted outputs. Global pulse ranking does
not establish local tempo changes, phase alignment, downbeats or meter, and these
two sources do not constitute broad tempo-accuracy validation.

## Preceding declared-clock evidence

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs cover the native admission fixture,
tool and saved-profile checker. The controlled source is a newly authored
four-second stereo C-major sine phrase rendered by native synthesis. The other
input is the previously attributed [Pixel Sprinter recording](WAV-LEARNING.md#published-recording-evidence).

| Source | Explicit decision | Complete cells | Endpoint floor / ceiling | Unassigned whole frames |
| --- | --- | --- | --- | --- |
| Native C-major fixture, 8000 Hz / 32000 frames | C major, measured rank 0; tempo 500000 | 16 | 32000 / 32000 | 0 |
| Pixel Sprinter, 44100 Hz / 1512000 frames | Unknown key; tempo 428571 | 160 | 1511998 / 1511999 | 1 |

Pixel's tempo is an integer-microsecond approximation of its source-declared
140 BPM, not a measured tempo result. The checker hashes the actual WAV and
report, reloads the profile, rebuilds its scope and checks every admitted cell.
It then frees the original containers and generates eight cells through two
actual WFC passes using copied key/tempo models. Unknown remains unknown.

The inspection report, both admission reports/profiles and controlled WAV match
byte-for-byte across compilers. Supplying an incorrect reviewed-source hash
preserves both existing output files. An additional stable-compiler selector
run successfully combines the controlled profile's key with Pixel's tempo.
Logs: `build/context-admission-{stable,trunk}/` and
`build/context-admission-replay.log`.

This is focused evidence for the 59-core / 17-adapter tree. The earlier full
build and extracted packages covered 58 core units; neither was rerun for
that addition. Subsequent measured pulse admission is described above. Remaining
work includes calibrated/local key admission, beat/downbeat admission, local tempo
changes, meter, independent voice extraction, joint musical
profiles and weighted blends. A constant admitted context is only the base
layer of the intended style architecture.

## Explicit local key regions

`AdmitWaveKeyRegions` in `pythian.music.context.admission` accepts a borrowed
clip, a `TMusicGridFrames` source mapping, ordered `TTonalKeyRegion` selections
and normal analysis options. The regions must partition the complete grid;
unknown key is a normal explicit selection. Each result owns the selected
region, absolute half-open frame range, twelve pitch-class weights and the full
tonal admission/ranking report. The core supports finite changing clocks,
nonzero start ticks, source offsets and native PPQ through the supplied mapping.

Each region starts an independent FFT analysis and zero-pads only at its own
endpoint. No window reads neighboring regions. Floor grid boundaries define
the measured frame partition; exact grid coverage still requires the source to
cover its ceiling endpoint. Total feature count and FFT work are preflighted
across all regions using the existing analysis budgets. Invalid partitions,
source geometry and known labels without local evidence reject without replacing
a previously assigned result. Input clip/grid and returned reports have separate
lifetimes; no WFC or file dependency enters this core API.

The native operator exposes constant-clock regional admission:

```text
pythian.context.wav admit-key-regions INPUT.wav EXPECTED_SHA256 TEMPO_US FIRST_CELL:ROOT:MODE,... OUTPUT_PREFIX
```

For an eight-second source at 120 BPM, `500000 0:0:major,16:2:minor` selects
C major for the first four seconds and D minor for the second four. This tool
uses 480 PPQ and 240-tick cells. Starts must begin at zero and increase strictly;
each region ends at the next start or the complete grid endpoint. `-1:major`
keeps a region unknown. The caller chooses boundaries and labels; the tool
does not detect modulations, select a winning key or infer a downbeat.

The existing JSON admission report contains local weights, all ranked fits,
selected ranks, exact regions and analysis policy. The current PCP stores the
admitted changing grid and binds the report hash in its existing policy field.
Current PYS learning/blending consumes that context directly. No native format
or historical reader was added. Reports remain external evidence; loading a
profile validates its models but does not independently remeasure the WAV.

Checked stable/development Win32 and stable Win64 pass the maintained local-key
build block: a native C-major/D-minor phrase learns a duration style, combines
with the existing changing-clock style, survives a second blend and generates
32 performance spans / 45 notes / 197163 stereo frames at 44100 Hz. A selective
key edit changes four new accompaniment tones while preserving measured melody,
tempo, gate timing and held notes. This is controlled evidence for admission and
integration, not an accuracy benchmark on annotated music.

The additional recorded/control blend uses the previously admitted flute/bassoon
style and produces the same note/frame counts. Pixel Sprinter also supplies two
local reports on its original WAV (80 cells per region at the declared 428571
microsecond clock); both key selections remain unknown. No independent local-key
annotations were available in this check. The source and license are the same
as the earlier attributed Pixel admission above.

Stable/development Win32 match 17 source/context/style/audio/report artifacts.
Win64 matches the seven source/WAV/MIDI/preview artifacts. Full-precision tonal
weights differ by at most `6.60e-16` relative on the controlled source and
`3.33e-16` on Pixel; every candidate's rank/identity and selected key agree.
These numeric differences change report hashes and bound profile/style identities.
No serialization rounding is introduced to conceal them. The native saved-profile
checker remeasures both sources, verifies exact report/source binding and checks
every admitted key/tempo cell with a `1e-12` relative numeric comparison.

Evidence: `build/local-key-{stable,trunk,win64}/`, including `maintained-run.log`,
`pixel-run.log`, and stable `replay.log`, `*-binding.log`, `rejection-status.log`.
Malformed regions and incorrect source hashes preserve existing profile/report
bytes. No new fixture program was added. Broader annotated key accuracy,
automatic region/key admission, meter and learned mixed-song roles remain open.
