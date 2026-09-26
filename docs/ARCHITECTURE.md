# Audio architecture and contracts

[Home](../README.md) · [Profile](../PROJECT.md) · [Provenance](PROVENANCE.md) ·
[Work](WORK.md)

For operator commands, recorded-grain semantics and real-recording evidence,
see [WAV learning and listening](WAV-LEARNING.md).
For PPQ clocks, raw MIDI events, note projection and preview policies, see
[MIDI and exact timing](MIDI.md).
For persisted shared vocabularies and bound companion models, see
[acoustic corpus contracts](CORPUS.md).
For derived onset/silence activity and token-preserving grain selection, see
[activity and continuity](ACTIVITY.md).

## Dependency boundary

`src/pythian.*` owns portable audio behavior and uses only the standard Pascal
libraries. WFC-specific types appear in `adapters/wfc/`; callers opt into that
path. Phanes contributes reviewed precursor ideas and implementation references,
not browser APIs, engine types, musical assets, or an application dependency.

No build references Phanes. Its temporary submodule was removed after the
[inventory, notice and independent-consumer audit](REFERENCE-REMOVAL.md).
WFC remains the actual learner/constraint companion.

## Musical layers and style direction

Use actual WFC passes to compose small, independently controllable musical
layers. Explicit key/tonal and tempo context should feed harmony/rhythm and
higher voice parts, with declared joint relationships, scopes and time mappings.
Keep synthesis sources, envelopes, modulation, effects and buses reusable below
those musical contracts.

The [measured instrument adapter](WAVE-STYLE.md#independent-measured-instruments)
owns saved timbre factories and cloned envelope/automation definitions for core
keyboard/velocity zones. It consumes independent sound choices after musical
planning, retaining separate profile identities without adding WFC types to the
core. Its native consumer explicitly maps MIDI channels to roles and preserves
accepted musical bytes while changing one role's sound.

[Bounded tone streams](SCHEDULING.md#bounded-tone-streams) admit finite plans by
their exact simultaneous voice/work requirements, then schedule sources at their
start frames and emit bounded blocks. Musical planning no longer requires an
offline-sized output clip. The offline renderer retains its original limits;
the instrument consumer stages sequential WAV output before replacing accepted
files. This supports sustained measured instruments below the WFC boundary.

[Named layer sessions](LAYERS.md#named-sessions-and-selective-regeneration) own
detached companion models and use actual WFC dependency closure for positional edits.
Compatible model replacement validates a candidate graph and retains independent
states; names, scopes and projection contracts remain fixed.
Explicit uniform tick grids and [fixed unequal partitions](LAYERS.md#fixed-time-partitions)
map provider start points or complete consumer spans through actual WFC mapped
requirements. Partition sessions own their timing and enforce aggregate expansion
bounds. Durations changing during a solve and automatic source-clock admission
remain separate contracts.
Accepted independent passes retain exact latent states. [Saved WAV onset styles](WAVE-STYLE.md)
use this mechanism before rebuilding dependent authored voice parts; measured
onset timing and authored pitches/voicings remain explicitly distinct.

The [layered style direction](LAYERED-STYLE.md) records the accepted requirement
for learning from one or multiple songs and reusing derived styles in later
selective merges/blends. It distinguishes existing pass/corpus primitives from
the remaining style-profile and weighting contracts. Typed context providers and
their saved learning bundles now use explicitly admitted key/tempo grids.
WAV key/tempo estimates remain evidence requiring admission. Core audio
fundamentals remain the implementation priority.

[Saved context profiles](CONTEXT-PROFILES.md) now select key and tempo providers
independently and retain complete parents through repeated derivation. The demo
rebuilds its dependent gate vocabulary and projection for a replaced tempo
provider. Current styles add weighted repeated blending and supported joint
measurements. General dependencies between changing musical scopes and automatic
WAV admission remain open.

[Explicit WAV admission](WAVE-CONTEXT-ADMISSION.md) now joins native tonal
measurements, caller-selected key/unknown and either a declared clock or an
explicitly selected measured pulse candidate to saved
context profiles. Selected beat hypotheses also retain their quantized phase
in the source grid start tick. Rhythm/pitch cells share that origin, and styles
retain each source origin through repeated blends. Source/report hashes retain
the measurement binding; exact scope endpoints preserve fractional sample boundaries. It does not infer a
downbeat or automatically accept a key/tempo estimate.
Selected local pulse ranges now admit changing tempo into these same context
models. Their relative clock retains a typed source frame offset and explicit
boundary errors; gaps and uncertain joins remain boundaries. `TMusicGridFrames`
shares an immutable mapping of the explicit tempo map and source offset between
rhythm and centered pitch measurement. Saved styles retain these source clocks
through repeated blending; the generated tempo can drive the full voice stack.
Dense source spans also normalize through those clocks into common PPQ durations.
An optional source articulation policy maps admitted physical onsets through
the same clock and splits known pitched intervals before joint duration learning.
Raw windows, unknown/silent intervals and source identity remain intact. This
uses the current style capability mask and the existing WFC performance pass.
Generated tempo has its own finite provider scope. Core tempo partitions and
detached WFC playback frames preserve whole note gates through internal tempo
changes; actual selective tempo edits retain key/performance and voice states.
Key also has an independent finite scope. The companion reconstructs typed key
changes; the core maps diatonic degrees between known keys. The voice operator
applies key at new accompaniment attacks, preserves sounding pitches and leaves
measured melody absolute. Selective key edits retain all tempo/performance
states before rebuilding dependent voices. This explicit authored arrangement
policy does not imply measured modulation or voice-role inference.

The shared analysis engine accepts bounded window sources. Its
[WAV adapter](ANALYSIS-WAVE.md) caches overlap and preserves feature semantics;
the standalone learner uses it alongside fixed-buffer source hashing. This
reduces sample storage without changing acoustic tokens into musical labels or
expanding the existing learning work budgets.

Explicit PCM-cycle analysis now returns detached sine/cosine waveform recipes
for the existing harmonic-limited wavetable factory. The native audition can
apply that measured waveform to generated MIDI through the same note renderer,
keeping note generation, waveform choice and envelope policy separate. Cycle
selection is caller-authored; automatic period detection and evolving timbre
inference remain open. This uses ordinary core source contracts and adds no
style archive or compatibility version.

## Audio data and WAV

`TAudioClip` copies input samples and returns detached copies. Coordinates are
zero-based frames/channels; storage is interleaved `Single`. One or two channels
and sample rates 1..384000 Hz are representable. Empty clips are valid. Values
must be finite; values outside unity preserve intermediate mixing headroom.
The in-memory budget is 64 million scalar samples. Methods return caller-owned
objects; callers use `try/finally`.

PCM16 conversion multiplies by 32768, rounds halves away from zero, and clamps
to -32768..32767. Every original PCM16 sample survives the WFC bridge exactly.
Encoding uses explicit little-endian fields. Downmix is the arithmetic mean of
stereo channels; analysis instead combines channel power to avoid cancellation.

The WAV decoder supports RIFF/RF64 little-endian PCM8/16/24/32 and IEEE float32,
including extensible formats with supported mono/stereo speaker assignments and
explicit valid-bit precision. It checks exact RIFF length, chunk bounds and padding, duplicate
format/data chunks, byte rate, block alignment, complete frames, sample rate,
and decoded allocation limits. Unknown chunks may appear anywhere and are
skipped. Non-finite float encodings fail before floating-point arithmetic.
PCM32 is converted to `Single`, so the least significant integer bits may be
rounded. IEEE float headroom is preserved.

Compression, additional speaker layouts,
metadata round-trip, non-seekable input and atomic file replacement remain
outstanding. The file writer validates the clip before opening the output,
then streams PCM16; an I/O failure may leave a partial file.

The [bounded frame reader](WAVE-READING.md) borrows a seekable stream, validates
the complete chunk layout and decodes requested blocks with a 4096-byte scratch
buffer. It supports 64-bit RF64 sizes and frame seeks. Nonfinite sample detection
occurs when those samples are read, rather than during header admission.
`DecodeWave` and `LoadWave` now reuse that parser/conversion path. File loading
avoids a second buffer containing the whole encoded file, while complete clips
retain the 64-million-sample cap. Existing corpus tools still have their own
analysis and source-byte budgets; this does not make WAV learning unbounded.

`pythian.wave.stream` generalizes WFC's sequential sink contract to mono/stereo
and Pythian's sample-rate range. It emits RIFF for small output and RF64 with an
80-byte header when the declared size exceeds the RIFF limit. Expected frames
are known before writing. At most 4096 encoded bytes are buffered. The writer
borrows its sink and never closes it. Each successful block advances the
confirmed frame count; a sink exception preserves its original exception,
poisons the writer, and prevents later writes. Input mistakes and a short Finish
are recoverable. Exact Finish is idempotent. Calls and callbacks are
non-reentrant. A physical partial sink write is not rolled back.

The memory encoder and file convenience functions now use that same writer.
RF64 size fields follow [EBU Tech 3306 v1.1, section 3.4 and Annex A.2](https://tech.ebu.ch/files/live/sites/tech/files/shared/tech/tech3306v1_1.pdf),
checked 2026-09-14. This implements the size extension, not broadcast metadata.
RF64 boundary headers and a reader seek beyond 4 GB have been exercised without
generating multi-gigabyte payloads; complete large-file playback remains untested.

Container rules follow Microsoft's
[RIFF chunk specification](https://learn.microsoft.com/en-us/windows/win32/xaudio2/resource-interchange-file-format--riff-)
and [WAVEFORMATEX documentation](https://learn.microsoft.com/en-us/windows/win32/api/mmreg/ns-mmreg-waveformatex),
checked 2026-09-14. The implementation deliberately supports the common legacy
PCM24/32 container convention as well as the documented PCM8/16 and float32.

## Synthesis

WFC's fixed oscillator path retains its Q12 tuning table, 24-bit phase,
triangle sample function, and integer attack/release ramps. Its compatibility
envelope is WFC's sample-rate range and MIDI pitch domain. Lower-rate callers
receive a phase increment reduced modulo the phase cycle.

[Streaming chords](CHORD-STREAMS.md) use these existing fixed helpers with
independent held voice state and a bounded delayed mix ring. Native sample-frame
admission separates synthesis from musical clocks; the WFC bridge supplies exact
incremental PPQ timing and restores its clock on rejected admission. Release is
shaped inside elapsed gates, so ending input adds no tail. This preserves the
precursor preview contract alongside the general native ADSR renderer.

The native synthesizer uses independent oscillator/filter state per note,
explicit seed, ADSR, linear velocity/gain, and equal-power stereo panning.
Start times floor to sample frames. Gate plus release lengths ceil to frames.
The seconds API retains that ADSR behavior. The frame API places starts and gates
using exact integers and rounds only the ADSR release length upward.
Optional [gated curves](MODULATION.md#gated-envelope-curves) replace ADSR with
independent held/release automation. Exact-frame tails and detached scheduled
playback use the same renderer, beneath instrument zones and generated notes.
Explicit-region [RMS traces](MODULATION.md#measured-amplitude-envelopes) can now
supply normalized curves with a declared gate and tail admission limit. Automatic
note-boundary inference and voice association remain open. Saved styles now retain
raw RMS evidence and independent envelope weights through repeated blends;
returned definitions can bind individual native voices without retaining profiles.
Release starts at the actual envelope level when note-off interrupts attack or
decay. Notes mix in supplied order and retain headroom until PCM output.
The output budget and 100-million weighted source-work budget are checked before
allocating the clip. This is offline rendering, not yet a device callback API.

Seeded noise uses the Phanes LCG with wide integer intermediates. Floating-point
transcendentals and accumulation are deterministic within the tested build;
cross-compiler bit identity is not promised for this path. Fixed-point functions
exist separately for precursor-compatible replay.

Sine, triangle, saw, square, and noise are available. Explicit polynomial
corrections reduce saw/square discontinuity and triangle-corner aliasing;
legacy defaults remain available for replay. Shared windowed-sinc conversion
supports offline clips and optional anti-aliased granular playback.
See [DSP contracts, bounds and measured evidence](DSP.md).
Immutable frame automation now drives tone frequency, cents, gain, pan and cutoff.
Additive partials and signed sine/FM/PM operators compose independently with
curves and sinc conversion; [modulation evidence](MODULATION.md) includes analytic
sidebands and an oversampled alias check. [Shared source factories](SOURCES.md)
now connect waveform/additive/FM, harmonic-limited wavetables and pitched
mono/stereo sample regions to the tone renderer with independent per-note state.
The wavetable factory can also morph between two measured cycle recipes through
an owned note-relative automation curve, preserving independent pitch, envelope
and musical-pass controls. This runtime waveform control is not yet measured
timbre evidence in persisted styles; declared cycle phase and amplitude remain explicit.
Eight biquad/EQ types, linked dynamics, gain smoothing and owning serial effect
chains are now available; see [effects contracts and evidence](EFFECTS.md).
Tone filtering explicitly selects one-pole or biquad, retaining legacy defaults.
Ordered stereo buses now compose serial effects, smoothed pre/post-fader sends,
and filtered-feedback echo with preserved history; see [bus routing](BUSES.md).
The shared playing-note implementation also feeds a
[bounded scheduler](SCHEDULING.md), with exact Int64 starts, copied automation,
group release and atomic future replacement preserving committed voices/tails.
Streaming conversion, richer sample instruments and broader modulation routing
remain follow-on work; hardware clocks and device callbacks stay at the host boundary.
The native processors do not claim Web Audio sample parity. Delay exists as a
standalone reusable primitive, and filtered echo now adapts to effect chains
and bus returns. The tone renderer does not route through them automatically.

## WAV learning

The [dense monophonic pitch track](PITCH.md#dense-measurements-and-learned-duration)
adds a separate native analysis path: overlapping periodic measurements become
stable pitch extents and explicit silence/unknown spans. A companion duration
learner retains explicit analysis width independently of hop and musical clocks;
different recording widths survive the current saved evidence and repeated blends.
The measured accuracy/resolution tradeoff is caller-controlled. The duration
adapter learns weighted recording samples through actual WFC. Its saved model
drives native gated note rendering; uncertainty remains in the interval tokens.
This does not establish polyphonic roles or exact physical note boundaries.

The [reference evaluator](PHRASE-EVALUATION.md) belongs to the native core and
consumes completed tracks separately from reference notes. References never enter
the estimator or WFC learner. Frame coverage, wrong admissions and one-to-one note
boundary scores keep musical accuracy separate from model/render execution.

[Pitch region summaries](PITCH.md#musical-note-hypotheses-within-regions) form a
separate musical-event inference step above those immutable raw measurements.
Boundary proposal, periodic evidence, energy/tuning consensus and note evaluation
are independent contracts. This allows improved onset/offset providers to feed
note inference without changing raw pitch or the WFC solver. Current detected
regions remain experimental; their hypotheses are not a saved-style provider yet.
Per-note support extents now permit a separate bounded ending policy. Inferred
intervals have their own frame evaluator using the raw track's geometry and
frequency range, without manufacturing measurements or treating gaps as silence.

The [public performance adapter](PERFORMANCE.md) owns saved key/tempo/duration
providers, creates actual named WFC sessions, constructs typed selective locks
and captures detached native spans and context after validating model paths and
time coverage. The voice demo consumes it while retaining authored accompaniment
and output policy. No file-format branch or solver is introduced.

Local tonal admission independently analyzes caller-selected regions on a native
source grid. Each region retains frame coordinates, weights, ranking and explicit
key/unknown selection, without borrowing samples across region boundaries. Those
decisions enter the existing context profiles and saved-style voice workflow;
the core API supports changing clocks and offsets, while the current region CLI
declares a constant clock. This does not infer modulation boundaries or key truth.

Version 1 analysis uses a periodic Hann window and radix-two FFT. Default window
and hop remain unchanged after extracting the butterfly engine into
`pythian.fourier`, which also supplies inverse transforms. The separate native
[harmonic/percussive processor](SEPARATION.md) uses linked stereo masks and inverse
STFT reconstruction to expose spectral components for listening and learning.
It does not establish isolated voice roles or monophonic harmonic content.

The existing wavetable source unit also fits a stationary harmonic recipe over
an explicitly selected interval at a supplied fundamental. Its detached result
retains AC/residual evidence and feeds the same synthesis factories. The operator
can supply a measured frequency from a separate analysis width, then audition
existing generated MIDI. [Harmonic fitting](SOURCES.md#harmonic-fitting-across-a-wav-interval)
does not infer a complete instrument envelope. The optional
[saved timbre dimension](WAVE-STYLE.md#stationary-timbre-and-rendering) now retains
fitted evidence and independent source weights through repeated derivation;
native rendering consumes a weighted magnitude recipe after musical solving.

For ordinary feature analysis, default window
and hop are 4096 and 1024 source frames. The last windows are zero-padded; the
reported valid-frame count and RMS exclude padding. Per-channel spectral powers
are averaged; this retains opposite-polarity stereo material. RMS and peak use
unwindowed samples. The centroid weights positive-frequency bins by magnitude.
Flux is the sum of positive magnitude increases divided by the larger current
or previous total magnitude. The first sounding frame can therefore have flux 1.
Silence uses an explicit RMS threshold and clears chroma, centroid, and flux.

Chroma folds bin powers from 27.5..5000 Hz to the nearest equal-tempered pitch
class, with A4=440 Hz, then normalizes their sum. This retains multiple spectral
pitch classes. It is not polyphonic note transcription: harmonics, percussion,
detuning, window resolution, and low-frequency bin spacing affect the estimate.
No automatic key, chord, tempo, beat-grid, source-separation, or instrument
identity claim follows from these measurements.

For window rationale, see Julius O. Smith's
[spectrum analysis windows](https://www.dsprelated.com/freebooks/sasp/spectrum_analysis_windows.html).
For established chroma feature work, see
[AudioLabs' Chroma Toolbox](https://www.audiolabs-erlangen.de/resources/MIR/chromatoolbox).
The current code is a small project-owned baseline, not an implementation of
all algorithms in those references.

The palette clusters 15-dimensional descriptors: square-root chroma (12),
RMS mapped from -60..0 dBFS to 0..1, centroid capped at 8000 Hz and scaled to
0..1, and flux. It uses deterministic farthest-first initialization and eight
Lloyd iterations with stable tie order. Default vocabulary is 16, maximum 32.
It does not claim an optimal clustering. Palettes are local; independently
trained index 3 values do not denote the same sound. Shared corpora train one
palette over multiple recordings and preserve it exactly for later loading.

WFC receives `pythian.acoustic.v1.<index>` tokens and ordinary sequence samples.
Each recording/excerpt stays a separate sample; all must share one palette.
The adapter permits orders 1..4 and at most 65536 observations, while the real
WFC state limits still apply. Exceeding a limit fails instead of silently
discarding data or weakening the model. State adjacency is WFC's learned
sequence contract, not a parallel solver. The integration fixture exercises
model text round-trip, graph solve, and independent solved-path capture.

The generation adapter applies native WFC token constraints and independently
validates the solved path before publishing output. Contradiction and exhausted
backtracking remain distinct. The granular reconstruction path keeps exact
source coordinates, and native tools retain SHA256 source/model/output hashes.
Two published CC0 recordings have passed the complete path; details are in
[WAV learning](WAV-LEARNING.md).

The archive workflow now admits multiple same-format recordings, preserves
measurements and palette centers, and loads the actual saved WFC model without
relearning. Internal feature/token consistency, source-file hashes and all WFC
state/boundary counts are checked. Core persistence retains opaque companion
bytes; WFC interpretation stays in its adapter.

Derived onset/silence/sustain actions now partition each source and project to
WFC's real rhythm alphabet. A bounded optional beam planner selects matching
grains using continuity and sampled-overlap costs, preserving every WFC token.

The [joint adapter](JOINT.md) now learns acoustic/activity pairs and solves
simultaneous locks; reconstruction requires matching recorded labels.
The [joint archive adapter](JOINT-ARCHIVE.md) persists the paired WFC model and
complete activity policy under a distinct opaque attachment. Loading recomputes
labels from stored features and independently checks every state/boundary count,
without FFT, palette training or WFC learning. Saved generation uses that policy
for grain planning; the core archive and acoustic-only paths are unchanged.
An independent [output articulation stage](ARTICULATION.md) now applies explicit
PPQ-grid or MIDI note gates after reconstruction, with bounded fades and exact
rests. It preserves input sample positions and the measured source-label contract.
The [timing adapter](TIMED-LEARNING.md) now maps positive-gain PPQ/MIDI gate
starts onto learned onset-candidate constraints with exact integer alignment,
signed errors and collision rejection. A native tool combines saved-model
generation, source selection and output articulation without retraining.
Remaining limitations include operator listening evaluation, general onset
accuracy, alignment of source beats with the output clock, long-form organization
and mixed-rate conversion.
Integration and signal-level
evidence do not establish general musical quality.

The [tonal profile unit](TONAL.md) extracts Phanes's duration histogram and
diatonic-fit heuristic, with actual precursor selection parity. MIDI note weights
and stored WAV chroma feed the same ranked-fit API. Explicit duration/energy
weighting, all candidates and score gaps expose uncertainty. No notes are
remapped and no inferred key is treated as verified ground truth.
