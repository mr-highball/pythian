# Pythian

Reusable audio synthesis and learning for Pascal. Pythian owns its audio data,
codecs, DSP, and analysis; WFC is a companion for learned constraints and
generation. The project is under active construction.

[Project profile](PROJECT.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Source packages and compiler evidence](docs/PACKAGING.md) ·
[Provenance](docs/PROVENANCE.md) · [Work and gates](docs/WORK.md) ·
[Outcome milestones](docs/MILESTONES.md) ·
[Task catalog](docs/TODO/README.md) · [Task flow](docs/TASKFLOW.MD) ·
[WAV learning and listening](docs/WAV-LEARNING.md) ·
[Harmonic/percussive separation](docs/SEPARATION.md) ·
[MIDI and exact timing](docs/MIDI.md) ·
[Persisted shared corpora](docs/CORPUS.md) ·
[Activity and continuity](docs/ACTIVITY.md) ·
[Source onset localization](docs/ONSETS.md) ·
[Beat-grid candidates](docs/BEAT-GRIDS.md) ·
[Local tempo tracking](docs/BEAT-TRACKING.md) ·
[Learning recorded events](docs/EVENT-LEARNING.md) ·
[Saved event learning](docs/EVENT-ARCHIVE.md) ·
[Learning pulse intervals](docs/PULSE-EVENTS.md) ·
[Joint acoustic/activity generation](docs/JOINT.md) ·
[Persisted joint models](docs/JOINT-ARCHIVE.md) ·
[Continuing learned sequences](docs/LEARNED-STREAMS.md) ·
[Recorded musical passages](docs/PASSAGES.md) ·
[Coupled learned layers](docs/LAYERS.md) ·
[Independent learned voices](docs/INDEPENDENT-VOICES.md) ·
[Bounded WFC harmony composition](docs/WFC-COMPOSITION.md) ·
[Reusable style performance API](docs/PERFORMANCE.md) ·
[Reusable style grid API](docs/GRID-STYLE.md) ·
[Layered style direction](docs/LAYERED-STYLE.md) ·
[Corpus evaluation](docs/CORPUS-EVALUATION.md) ·
[Shared musical evaluation](docs/MUSICAL-EVALUATION.md) ·
[File-bound evaluation](docs/EVALUATION-OPERATOR.md) ·
[Consumer contract](docs/CONSUMER-CONTRACT.md) ·
[Selective context profiles](docs/CONTEXT-PROFILES.md) ·
[Explicit WAV context admission](docs/WAVE-CONTEXT-ADMISSION.md) ·
[Reusable weighted WAV onset styles](docs/WAVE-STYLE.md) ·
[Measured onset dynamics](docs/ONSET-DYNAMICS.md) ·
[Periodic pitch and WAV note learning](docs/PITCH.md) ·
[Standalone source packages](docs/PACKAGING.md#current-source-packages) ·
[Musical timing in WAV generation](docs/TIMED-LEARNING.md) ·
[Pitch-class profiles and tonal fits](docs/TONAL.md) ·
[Output articulation on musical clocks](docs/ARTICULATION.md) ·
[Oscillators and resampling](docs/DSP.md) ·
[Automation and modulation](docs/MODULATION.md) ·
[Shared sources and sample voices](docs/SOURCES.md) ·
[Fundamental capability and evidence map](docs/FUNDAMENTALS.md) ·
[Filters, dynamics and effects](docs/EFFECTS.md) ·
[Stereo reverberation](docs/REVERB.md) ·
[Bus routing and filtered echo](docs/BUSES.md) ·
[Scheduled synthesis and future edits](docs/SCHEDULING.md) ·
[Streaming chords and delayed release](docs/CHORD-STREAMS.md) ·
[Learned ensemble planning and streaming](docs/ENSEMBLE-STREAMS.md) ·
[Contributor instructions](AGENTS.md) · [Athena standards](vendor/athena/README.md)

## Build and listen

With an existing native FPC compiler on PATH, run from PowerShell:

```powershell
./tools/build.ps1
```

This compiles checked fixtures, runs core and WFC integration checks, builds
the native tools, renders `synthesis.wav`, learns an acoustic WFC model,
and reconstructs `remix.wav` from WFC-selected source grains. Artifacts go under
`build/<version>-<cpu>-<os>/`.
Use `-Compiler <executable>` to select a compiler explicitly. Use `-CoreOnly`
to build the complete core unit set and renderer without any vendor source
search path. It does not run the WFC integration fixture or learning/remix tools.

The verified native target is i386 Windows with FPC 3.2.2 and the existing
3.3.1 development compiler. Extracted source packages also pass external core
and WFC consumer builds on 3.2.2; see [delivery evidence](docs/PACKAGING.md).
No installation or global configuration change is performed by the build.

Create a checked development source ZIP with `./tools/package.ps1`, or add
`-WithWfc` to include the companion sources and WAV-learning example. The script
compiles and runs consumers against the extracted ZIP. Outputs stay under `build/`.

The executables accept explicit output paths:

```text
pythian.render OUTPUT.wav
pythian.compose OUTPUT.wav [SEED]
pythian.compose OUTPUT.wav SEED "16 CHORD LABELS"
pythian.wfc.composition OUTPUT.wav SOURCES.txt [SEED]
pythian.dsp.demo OUTPUT.wav
pythian.modulation.demo OUTPUT.wav
pythian.control.curves.demo OUTPUT.wav
pythian.context.demo OUTPUT_PREFIX
pythian.context.wav inspect INPUT.wav REPORT.json
pythian.context.wav admit INPUT.wav EXPECTED_SHA256 TEMPO_US ROOT MODE OUTPUT_PREFIX
pythian.context.wav inspect-tempo INPUT.wav REPORT.json
pythian.context.wav admit-tempo INPUT.wav EXPECTED_SHA256 CANDIDATE_RANK ROOT MODE OUTPUT_PREFIX
pythian.context.track inspect INPUT.wav REPORT.json [--clock linear|step [--alignment-context]]
pythian.context.track admit INPUT.wav EXPECTED_SHA256 FIRST_PULSE LAST_PULSE ROOT MODE OUTPUT_PREFIX [--clock linear|step [--alignment-context]]
pythian.context.track audition PROFILE.pcp OUTPUT.wav
pythian.style learn CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys [PROVENANCE]
pythian.style learn-dynamics CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys [PROVENANCE]
pythian.style blend LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_WEIGHT RIGHT_WEIGHT OUTPUT.pys
pythian.style inspect INPUT.pys OUTPUT.json
pythian.pitch.wav inspect INPUT.wav REPORT.json TEMPO_US CHANNEL
pythian.pitch.wav learn INPUT.wav PREFIX TEMPO_US CHANNEL --monophonic
pythian.pitch.wav generate MODEL.txt OUTPUT.wav TEMPO_US [SEED]
pythian.pitch.wav inspect-runs INPUT.wav REPORT.json CHANNEL --monophonic
pythian.pitch.wav learn-runs INPUT.wav PREFIX CHANNEL --monophonic
pythian.pitch.wav generate-runs MODEL.txt OUTPUT.wav QUANTUM_MS [SEED]
pythian.pitch.wav generate-style-runs PROFILE.pys OUTPUT.wav [--spans COUNT] [--extent prefix|fragment] [--context hold|sequence] [--duration-lock CELL:TICKS]
pythian.style learn-pitch CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic [PROVENANCE]
pythian.style learn-duration CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic [--articulate-onsets] [--window-frames N] [PROVENANCE]
pythian.context.wav admit-key-regions INPUT.wav EXPECTED_SHA256 TEMPO_US FIRST_CELL:ROOT:MODE,... OUTPUT_PREFIX
pythian.separate INPUT.wav OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES HARMONIC_MEDIAN_FRAMES PERCUSSIVE_MEDIAN_BINS]
pythian.style blend-dimensions LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH OUTPUT.pys
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --pitch-lock CELL:NOTE --verify
pythian.voices.demo OUTPUT.wav --style PROFILE.pys [--style-extent whole|prefix|fragment] --verify
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --duration-spans COUNT [--duration-lock CELL:TICKS] [--pitch-lock CELL:NOTE] --verify
pythian.voices.demo OUTPUT.wav --style PROFILE.pys --duration-spans COUNT --duration-key-cells COUNT --duration-tempo-cells COUNT [--duration-key-lock CELL:ROOT:major|minor] [--duration-tempo-lock CELL:US] --verify
pythian.sources.demo OUTPUT.wav
pythian.sources.demo OUTPUT.wav --cycle INPUT.wav START_FRAME FRAME_COUNT CHANNEL HARMONICS [--midi NOTES.mid]
pythian.sources.demo OUTPUT.wav --morph-cycle FROM.wav START COUNT CHANNEL HARMONICS TO.wav START COUNT CHANNEL HARMONICS MORPH_FRAMES --midi NOTES.mid
pythian.sample.loop.demo OUTPUT.wav
pythian.effects.demo OUTPUT.wav
pythian.delay.modulated.demo OUTPUT.wav
pythian.reverb.demo OUTPUT.wav
pythian.bus.demo OUTPUT.wav
pythian.schedule.demo OUTPUT.wav [OUTPUT_RATE]
pythian.chord.demo OUTPUT.wav
pythian.ensemble.demo OUTPUT.wav [SEED [CELLS [SEGMENT_CELLS]]] [--verify]
pythian.voices.demo OUTPUT.wav [SEED [SEGMENT_CELLS]] [--context PROFILE.pcp] [--verify]
pythian.voices.demo OUTPUT.wav [SEED [SEGMENT_CELLS]] --style PROFILE.pys [--rhythm-locks PATTERN] [--intensity-locks PATTERN] [--verify]
pythian.convert INPUT.wav OUTPUT.wav SAMPLE_RATE [--gain VALUE | --peak CEILING] [--block-frames N]
pythian.wave.transcode INPUT.wav OUTPUT.wav [BLOCK_FRAMES]
pythian.articulate INPUT.wav OUTPUT.wav grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN [ATTACK_FRAMES RELEASE_FRAMES]
pythian.articulate INPUT.wav OUTPUT.wav midi INPUT.mid [ATTACK_FRAMES RELEASE_FRAMES]
pythian.learn INPUT.wav OUTPUT_PREFIX
pythian.learn cache INPUT.wav OUTPUT.pyaf [--batch-features N] [--max-batches N]
pythian.learn journals OUTPUT_PREFIX [--partition training|development] [OPTIONS] [--group ID SPLIT verified|unverified unused|used] INPUT.wav CACHE.pyaf [...]
pythian.learn fit PROFILE_PREFIX OUTPUT.json MAX_SQUARED_DISTANCE [--range FIRST_FEATURE COUNT] INPUT.wav CACHE.pyaf [...]
pythian.learn replay INPUT_PREFIX OUTPUT_PREFIX [OPTIONS] SOURCE.wav [...]
pythian.learn blend LEFT_PREFIX RIGHT_PREFIX OUTPUT_PREFIX LEFT_WEIGHT RIGHT_WEIGHT
pythian.remix INPUT.wav OUTPUT.wav [SEED] [ACOUSTIC_FRAMES]
pythian.passage.remix INPUT.pyac SOURCE.wav OUTPUT.wav SEED BARS [PALETTE_SIZE]
pythian.event.remix INPUT.pyac SOURCE.wav ONSETS.json OUTPUT.wav SEED EVENTS [PALETTE_SIZE] [--pulses]
pythian.event.merge INPUT.pyac OUTPUT.wav SEED EVENTS SOURCE.wav ONSETS.json [SOURCE.wav ONSETS.json ...] [--pulses]
pythian.event.merge --load INPUT.pyac OUTPUT.wav SEED EVENTS SOURCE.wav [SOURCE.wav ...]
pythian.layers.demo OUTPUT.wav [SEED]
pythian.inspect INPUT.wav
pythian.onsets INPUT.wav OUTPUT.json [WINDOW_FRAMES HOP_FRAMES] [--valleys] [--audition OUTPUT.wav]
pythian.onset.lab OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES]
pythian.beats INPUT.wav OUTPUT.json [MIN_BPM MAX_BPM] [--track [--clock linear|step [--alignment-context]]] [--audition OUTPUT.wav [RANK]]
pythian.beat.lab OUTPUT_PREFIX
pythian.archive learn OUTPUT.pyac [--provenance TEXT] INPUT.wav [INPUT.wav ...]
pythian.archive inspect INPUT.pyac
pythian.archive segments INPUT.pyac
pythian.archive remix INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES SOURCE.wav [SOURCE.wav ...]
pythian.archive remix-continuous INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES SOURCE.wav [SOURCE.wav ...]
pythian.archive remix-joint INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES ACTIVITY_PATTERN SOURCE.wav [SOURCE.wav ...]
pythian.archive prepare-joint INPUT.pyac OUTPUT.pyac [ORDER]
pythian.archive inspect-joint INPUT.pyac
pythian.archive remix-saved-joint INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES ACTIVITY_PATTERN SOURCE.wav [SOURCE.wav ...]
pythian.archive remix-stream-joint INPUT.pyac OUTPUT.wav SEED TOTAL_CELLS ACTIVITY_PATTERN CHUNK_CELLS SOURCE.wav...
pythian.timed.remix INPUT.pyac OUTPUT.wav SEED grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN MAX_ERROR_FRAMES SOURCE.wav...
pythian.timed.remix INPUT.pyac OUTPUT.wav SEED midi INPUT.mid MAX_ERROR_FRAMES SOURCE.wav...
pythian.tonal.inspect midi INPUT.mid [MAX_NOTE_TICKS]
pythian.tonal.inspect wav INPUT.wav [duration|energy]
pythian.tonal.inspect corpus INPUT.pyac [duration|energy]
pythian.midi.render INPUT.mid OUTPUT.wav [--ignore-performance] [--fifo] [--close-dangling] [--exclude-percussion]
```

`pythian.compose` renders a 16-bar bass-and-melody passage from the given seed
(default `1731`) and writes `OUTPUT.wav.report.txt` with structural and audio
evidence. It uses a source-free Pascal form and harmony scaffold; recorded
learning and WFC style generation are separate capabilities.

Open the rendered WAV in a local audio player. The demo plays a short original
phrase through sine, triangle, saw, and square voices with stereo placement.
The build also renders a six-second oscillator and granular anti-aliasing
comparison and converts it to 44100 Hz; see [DSP evidence and segment times](docs/DSP.md).
The separate modulation example combines pitch/cutoff ramps, moving pan,
additive vibrato and oversampled FM/phase modulation; see [its contracts and evidence](docs/MODULATION.md).
Reusable sine/triangle automation curves also drive independent vibrato, tremolo,
pan and cutoff routes, demonstrated by `pythian.control.curves.demo`.
The source demo renders oscillator, additive, FM, wavetable and stereo sample
voices through one shared tone path; see [source ownership and playback](docs/SOURCES.md).
The effects demo compares a resonant-biquad phrase before and after gain/EQ,
compression and limiting; see [processor contracts and evidence](docs/EFFECTS.md).
The reverb demo compares a dry native phrase with short and long decaying tails;
see [reverb controls and listening times](docs/REVERB.md).
The bus demo routes music, filtered echo and effects through a master chain,
with a music-return fade that preserves echo history; see [routing and listening](docs/BUSES.md).
The scheduler demo changes a future phrase during streamed synthesis and releases
music while retaining independent effects and tails; see [scheduling contracts](docs/SCHEDULING.md).
The learner writes a WFC `.wfcs` model and a `.json` sidecar containing the
acoustic palette, frame tokens, source filename/hash, and analysis parameters.
It uses [bounded WAV analysis](docs/ANALYSIS-WAVE.md) and stream hashing,
retaining the existing source and FFT-work limits.
Keep these files together: palette indices are local to that training run.
The remix tool performs learning, constrained generation and granular reconstruction
in one run, retaining source mappings and output hashes. For reusable training,
the archive tool stores a shared palette, measurements, source identities and the
actual WFC model in one validated `.pyac` file. It remixes multiple recordings
without relearning; see [persisted corpora](docs/CORPUS.md).
The optional continuity planner preserves WFC tokens while selecting recorded
passages using source adjacency, overlap-sample agreement and onset candidates.
See [activity and continuity](docs/ACTIVITY.md) for its measured comparison.
The earlier JSON sidecars remain inspection-only.
The joint command learns paired acoustic/activity observations from the stored
measurements and honors a prefix such as `a???h` during solving and grain
selection. See [joint controls and evidence](docs/JOINT.md); cells are analysis
hops, not inferred musical beats.
Save the derived model with `prepare-joint` and reuse it through
`remix-saved-joint` without learning. The saved activity policy is validated
against the measured corpus and reused in grain planning; see
[joint archive contracts](docs/JOINT-ARCHIVE.md).
The timed remix tool maps explicit PPQ/MIDI attacks to learned onset-candidate
constraints, reports frame errors and applies exact output gates. See
[timed generation and its precision limits](docs/TIMED-LEARNING.md).
Tonal inspection shares pitch-class profiles between MIDI notes and WAV chroma,
reporting all diatonic fits and their score gaps. It extracts Phanes's heuristic
without forcing notes into a scale; see [profiles and evidence](docs/TONAL.md).
The articulation tool applies explicit PPQ grid or MIDI note gates after
reconstruction, giving exact output rests and bounded fades. It preserves input
sample positions; see [output timing, metadata and listening](docs/ARTICULATION.md).
See [WAV learning](docs/WAV-LEARNING.md) for the operator workflow,
published-recording evidence, and current limits.

The MIDI tool renders a note preview through one native synth voice and reports
discarded MIDI information. It uses an exact PPQ tempo map and integer sample
placement. See [MIDI policies and examples](docs/MIDI.md); it does not implement
General MIDI instruments, controllers or pedal performance.

## Library units

| Unit | Responsibility |
| --- | --- |
| [pythian.schedule](src/pythian.schedule.pas) | Bounded streaming voices, exact starts/gates, group release and atomic future replacement |
| [pythian.synth.stream](src/pythian.synth.stream.pas) | Finite tone plans with exact overlap admission, lazy source creation and bounded sequential samples; [contract](docs/SCHEDULING.md#bounded-tone-streams) |
| [pythian.synth.resample](src/pythian.synth.resample.pas) | Bounded PCM reader over a borrowed tone stream, feeding continuous rate conversion; [quality evidence](docs/SYNTHESIS-QUALITY.md) |
| [pythian.articulation](src/pythian.articulation.pas) | Exact PPQ/MIDI output gates, fades and post-reconstruction silence |
| [pythian.alignment](src/pythian.alignment.pas) | Exact integer frame anchors to analysis cells, signed errors and explicit tolerance |
| [pythian.tonal](src/pythian.tonal.pas) | MIDI/WAV pitch-class profiles and inspectable Phanes-derived diatonic fit ranking |
| [pythian.bus](src/pythian.bus.pas) | Owning ordered stereo buses, pre/post-fader sends, smoothed gains and continuous processing |
| [pythian.echo](src/pythian.echo.pas) | Stereo filtered-feedback delay with explicit dry/wet gains and retained tails |
| [pythian.audio](src/pythian.audio.pas) | Owned immutable mono/stereo clips, PCM16 quantization, explicit mono downmix |
| [pythian.wave](src/pythian.wave.pas) | Bounded WAV decoding, optional ACID loop declarations and canonical PCM16 output |
| [pythian.wave.stream](src/pythian.wave.stream.pas) | Borrowed sinks and bounded sequential PCM16 RIFF/RF64 writing |
| [pythian.wave.read](src/pythian.wave.read.pas) | Bounded RIFF/RF64 PCM/float reads, extensible valid-bit formats and 64-bit seeks |
| [pythian.meter](src/pythian.meter.pas) | Per-channel peak, RMS and mean |
| [pythian.oscillator](src/pythian.oscillator.pas) | Extracted fixed-point triangle, MIDI tuning, seeded waveforms and polynomial anti-aliasing |
| [pythian.chord.stream](src/pythian.chord.stream.pas) | Incremental held chords, bounded delayed release and exact WFC preview PCM |
| [pythian.chord](src/pythian.chord.pas) | Shared rest/attack/hold frame data, independent of MIDI, renderer and clock |
| [pythian.resample](src/pythian.resample.pas) | Bounded sinc clip conversion and reusable fixed-rate sample interpolation |
| [pythian.resample.stream](src/pythian.resample.stream.pas) | Continuous pull conversion with bounded sinc history, exact rational positions and explicit EOF/failure |
| [pythian.wave.resample](src/pythian.wave.resample.pas) | Borrowed bounded WAVE input for continuous conversion, preserving floating peaks |
| [pythian.automation](src/pythian.automation.pas) | Immutable integer-frame hold/linear/exponential curves and cents conversion |
| [pythian.additive](src/pythian.additive.pas) | Owned harmonic/inharmonic sine partials, amplitude modulation and Nyquist omission |
| [pythian.modulation](src/pythian.modulation.pas) | Signed sine/LFO phase accumulation and explicit FM/PM operators |
| [pythian.source](src/pythian.source.pas) | Reusable factory and independent per-note playback/lifecycle contract |
| [pythian.source.oscillator](src/pythian.source.oscillator.pas) | Waveform, additive and FM/PM source factories |
| [pythian.source.wavetable](src/pythian.source.wavetable.pas) | PCM-cycle analysis, shared harmonic-fit admission and residual evidence, harmonic-limited tables and per-note morph controls |
| [pythian.source.sample](src/pythian.source.sample.pas) | Owned stereo/mono regions, pitched one-shots and explicit sample loops |
| [pythian.sample.sequence](src/pythian.sample.sequence.pas) | Shared intro/loop/tail addressing with bounded held trajectories and explicit release |
| [pythian.instrument](src/pythian.instrument.pas) | Reusable pitch/velocity zones and explicit layered voices feeding native rendering/scheduling; [contract and audition](docs/INSTRUMENTS.md) |
| [pythian.envelope](src/pythian.envelope.pas) | ADSR with early gate release |
| [pythian.filter](src/pythian.filter.pas) | Stateful one-pole low/high-pass filtering |
| [pythian.biquad](src/pythian.biquad.pas) | Eight biquad/EQ types with independent mono/stereo history and validated changes |
| [pythian.dynamics](src/pythian.dynamics.pas) | Linked compression/sidechain, sample-peak limiting and gain-target smoothing |
| [pythian.effects](src/pythian.effects.pas) | Owning stereo effect chains, persistent history and bounded clip/tail processing |
| [pythian.delay](src/pythian.delay.pas) | Shared fractional delay history and legacy fixed feedback delay |
| [pythian.delay.modulated](src/pythian.delay.modulated.pas) | Stereo moving delay with owned automation controls for chorus/flanging |
| [pythian.reverb](src/pythian.reverb.pas) | Stereo damped-comb/allpass reverb with explicit decay, diffusion, width and mix |
| [pythian.synth](src/pythian.synth.pas) | Shared stateful note playback, copied automation, stereo pan and polyphonic offline rendering |
| [pythian.time](src/pythian.time.pas) | Exact PPQ/streaming clocks, finite tempo partitions and explicit seconds-to-frame rounding |
| [pythian.music](src/pythian.music.pas) | Immutable note gates and source coordinates |
| [pythian.music.context](src/pythian.music.context.pas) | Owned key/tempo timelines and explicit scoped PPQ grids |
| [pythian.music.grid.frames](src/pythian.music.grid.frames.pas) | Immutable source-frame boundaries for finite PPQ grids, changing clocks and physical source offsets |
| [pythian.music.context.admission](src/pythian.music.context.admission.pas) | Explicit tonal/pulse selection, source phase quantization and exact complete-cell scopes |
| [pythian.tempo](src/pythian.tempo.pas) | Bounded global spectral-flux periodicity candidates, metrical alternatives and explicit missing evidence |
| [pythian.rhythm.admission](src/pythian.rhythm.admission.pas) | Explicit source-onset to PPQ admission with collision, tolerance and boundary decisions |
| [pythian.onset.dynamics](src/pythian.onset.dynamics.pas) | Native onset-window RMS, admitted relative intensity and explicit velocity mapping |
| [pythian.pitch](src/pythian.pitch.pas) | Bounded periodic frequency estimation, explicit unknowns and tuning admission |
| [pythian.evaluation](src/pythian.evaluation.pas) | Shared evidence/clock/exposure checks, event matching and categorical/scalar reference scoring |
| [pythian.pitch.cells](src/pythian.pitch.cells.pas) | Shared cell-centered measurement and source-grid/tuning admission for declared monophonic WAVs |
| [pythian.pitch.track](src/pythian.pitch.track.pas) | Dense pitch/silence/unknown spans and PPQ normalization through explicit source clocks |
| [pythian.midi.smf](src/pythian.midi.smf.pas) | Bounded format 0/1 PPQ MIDI event codec extracted from WFC |
| [pythian.midi.stream](src/pythian.midi.stream.pas) | Two-pass format-0 MIDI writer with bounded byte blocks and long-delay bridges; [contract/example](docs/MIDI-STREAMS.md) |
| [pythian.midi.chord](src/pythian.midi.chord.pas) | Bounded frame-to-MIDI cursor, counting and replay with exact holds and explicit timing/channels; [contract](docs/CHORD-MIDI.md) |
| [pythian.midi.notes](src/pythian.midi.notes.pas) | Explicit MIDI note projection and loss report |
| [pythian.midi.export](src/pythian.midi.export.pas) | Native note/tempo export with explicit voice channels, ordered attacks/releases and stream replay; [contract](docs/MIDI-EXPORT.md) |
| [pythian.music.render](src/pythian.music.render.pas) | Exact-frame note synthesis with voice or layered instrument bindings and separate note/tone counts |
| [pythian.music.compose](src/pythian.music.compose.pas) | Deterministic 16-bar source-free two-part form and harmony scaffold; returns an owned exact note sequence with seed and provenance report, without claiming learned WFC or recorded style |
| [pythian.analysis](src/pythian.analysis.pas) | Windowed spectral analysis, RMS, peak, centroid, flux, chroma and optional frequency bands |
| [pythian.fourier](src/pythian.fourier.pas) | Shared forward/inverse complex FFT with detached results and explicit scaling |
| [pythian.separation](src/pythian.separation.pas) | Bounded stereo harmonic/percussive decomposition, native component clips and reconstruction |
| [pythian.analysis.wave](src/pythian.analysis.wave.pas) | WAV windows and resumable feature/band batches with Int64 source coordinates and continuous flux |
| [pythian.analysis.journal](src/pythian.analysis.journal.pas) | Source-bound feature batches, committed progress and incomplete-tail recovery |
| [pythian.learning](src/pythian.learning.pas) | Deterministic acoustic palette learning and encoding |
| [pythian.learning.journal](src/pythian.learning.journal.pas) | Bounded journal training, checked partition selection, recording segments, weights, representative coordinates and frozen-palette fit diagnostics |
| [pythian.learning.selection](src/pythian.learning.selection.pas) | Bounded temporal candidate pools and independent generated-segment contribution controls |
| [pythian.learning.binding](src/pythian.learning.binding.pas) | Canonical ordered-palette/timebase fingerprints and exact serialized-model binding |
| [pythian.learning.continuity](src/pythian.learning.continuity.pas) | Bounded candidate and whole-context boundary planning with fixed tokens, contributions and locks |
| [pythian.learning.context](src/pythian.learning.context.pas) | Bounded source contexts, variable-length selection and quota-preserving repeat repair |
| [pythian.corpus](src/pythian.corpus.pas) | Immutable shared WAV corpora, source identities and multi-recording grain plans |
| [pythian.passage](src/pythian.passage.pas) | Declared loop bar grids, stored-feature aggregation and full-passage stereo reconstruction |
| [pythian.corpus.archive](src/pythian.corpus.archive.pas) | Bounded exact binary persistence with an integrity-bound companion attachment |
| [pythian.activity](src/pythian.activity.pas) | Bounded onset candidates, silence/sustain actions and complete temporal partitions |
| [pythian.onset](src/pythian.onset.pas) | Source energy-rise timing and bounded RMS-valley measurements with explicit context and admission limits |
| [pythian.onset.events](src/pythian.onset.events.pas) | Auditable source-event boundaries from admitted onset estimates |
| [pythian.beat](src/pythian.beat.pas) | Ranked constant-period pulse grids with phase, coherence, support and explicit ambiguity |
| [pythian.beat.wave](src/pythian.beat.wave.pas) | Shared native onset localization and beat evidence for inspection and context admission |
| [pythian.beat.track](src/pythian.beat.track.pas) | Bounded local tempo paths, reusable retained-candidate selection, gap/restart diagnostics and source-onset alignment |
| [pythian.beat.alignment](src/pythian.beat.alignment.pas) | Optional neighbour-supported onset choices with explicit unknown/unavailable decisions |
| [pythian.pulse.events](src/pythian.pulse.events.pas) | Source pulse interval admission with independent runs across gaps and uncertain timing |
| [pythian.continuity](src/pythian.continuity.pas) | Token-preserving beam planning with source continuity and measured seam costs |
| [pythian.hash](src/pythian.hash.pas) | Shared native SHA256 for bytes and bounded stream spans |
| [pythian.granular](src/pythian.granular.pas) | Explicit source grains, interpolation, windowed overlap and shared boundary probes |
| [pythian.reconstruction](src/pythian.reconstruction.pas) | Source-traceable acoustic exemplar reconstruction |
| [pythian.wfc.audio](adapters/wfc/pythian.wfc.audio.pas) | Explicit, detached conversion to/from WFC PCM clips |
| [pythian.wfc.instrument](adapters/wfc/pythian.wfc.instrument.pas) | Owned measured timbre/envelope bindings for native instrument zones; [consumer and ownership](docs/WAVE-STYLE.md#independent-measured-instruments) |
| [pythian.wfc.learning](adapters/wfc/pythian.wfc.learning.pas) | Acoustic token corpora to WFC sequence models |
| [pythian.wfc.learning.journal](adapters/wfc/pythian.wfc.learning.journal.pas) | Counted WFC learning from journals with history across storage batches |
| [pythian.wfc.learning.profile](adapters/wfc/pythian.wfc.learning.profile.pas) | Bound saved journal models, detached candidate restoration and compatibility checks |
| [pythian.wfc.learning.blend](adapters/wfc/pythian.wfc.learning.blend.pas) | Weighted saved acoustic model counts, coalesced source ranges and reusable derived blends |
| [pythian.wfc.events](adapters/wfc/pythian.wfc.events.pas) | Joint acoustic/duration/onset event symbols learned through actual WFC sequences |
| [pythian.wfc.event.corpus](adapters/wfc/pythian.wfc.event.corpus.pas) | Shared event vocabulary across recordings, independent training runs and exact reconstruction members; [workflow](docs/EVENT-CORPUS.md) |
| [pythian.wfc.event.archive](adapters/wfc/pythian.wfc.event.archive.pas) | Persisted recorded-event learning with exact centers, source/run definitions and independent model admission; [contract](docs/EVENT-ARCHIVE.md) |
| [pythian.wfc.generation](adapters/wfc/pythian.wfc.generation.pas) | Seeded, constrained generation with native WFC reports |
| [pythian.wfc.music](adapters/wfc/pythian.wfc.music.pas) | Native note/frame bridges, tempo-aware playback holds and voice capacity planning |
| [pythian.wfc.corpus](adapters/wfc/pythian.wfc.corpus.pas) | Actual WFC model persistence and independent corpus/model admission |
| [pythian.wfc.activity](adapters/wfc/pythian.wfc.activity.pas) | Measured acoustic actions to actual WFC rhythm cells and sequence models |
| [pythian.wfc.joint](adapters/wfc/pythian.wfc.joint.pas) | Paired acoustic/activity learning and simultaneous locks through actual WFC constraints |
| [pythian.wfc.joint.archive](adapters/wfc/pythian.wfc.joint.archive.pas) | Persisted paired models, exact activity policy and independent measured-corpus admission |
| [pythian.wfc.timing](adapters/wfc/pythian.wfc.timing.pas) | Musical gate attacks to actual WFC source-onset constraints, with collision rejection |
| [pythian.wfc.stream](adapters/wfc/pythian.wfc.stream.pas) | Bounded learned chunks with retained exact latent history, retry preservation and observed endpoints |
| [pythian.wfc.layers](adapters/wfc/pythian.wfc.layers.pas) | Negotiated learned layers, correlated projections and owned named sessions with selective regeneration |
| [pythian.wfc.context](adapters/wfc/pythian.wfc.context.pas) | Typed key/tempo provider tokens, separate-source learning and output clock reconstruction |
| [pythian.wfc.context.archive](adapters/wfc/pythian.wfc.context.archive.pas) | Owned context learning bundles with source admission, timing and validated model persistence |
| [pythian.wfc.style](adapters/wfc/pythian.wfc.style.pas) | Saved WAV musical evidence, independent rhythm/pitch/stationary-timbre weights and repeated derivation |
| [pythian.wfc.performance](adapters/wfc/pythian.wfc.performance.pas) | Owned saved-style providers, typed selective locks and detached musical-time plans |
| [pythian.wfc.pitch](adapters/wfc/pythian.wfc.pitch.pas) | Actual weighted pitch, paired onset/pitch and explicit duration-span learning with independent recording boundaries |
| [pythian.wfc.context.profile](adapters/wfc/pythian.wfc.context.profile.pas) | Saved per-dimension context selection with reusable derived profiles and complete parents |

Include `src` in the compiler unit search path for the core. WFC consumers also
include `adapters/wfc` and `vendor/wfc/src`. The temporary Phanes reference was
removed after its [extraction audit](docs/REFERENCE-REMOVAL.md), with provenance
and notices retained. Read [the contracts and current limits](docs/ARCHITECTURE.md)
before integrating this development API.
