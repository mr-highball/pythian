# MIDI and exact timing

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[Provenance](PROVENANCE.md) · [Work and gates](WORK.md)

For two-pass forward file output, see [MIDI streams](MIDI-STREAMS.md):
the native writer accepts absolute-tick events, emits bounded blocks and bridges
delays beyond one MIDI delta. The existing whole-file codec remains available.
To export a native note sequence, use [note export](MIDI-EXPORT.md), which plans
ordered notes and tempos with explicit channels and feeds that stream.

## Clock and note contracts

`pythian.time` extracts WFC's fractional microsecond carry into an immutable
`TTempoMap`. PPQ is a positive Integer, ticks span 0..LengthTicks, and tempo is
1..16777215 microseconds per quarter. Changes start at zero, increase strictly,
and may include the terminal tick. There are at most 65536 changes. Both the
input array and returned copies are detached. Times retain an exact PPQ
remainder; frame conversion explicitly selects floor or ceiling. Int64 frame
coordinates avoid premature overflow for long timelines.

`NextGridTick` returns the first grid tick whose floor frame is at least the
requested frame, or fails if no grid remains. `WithTempoFrom` returns an owned
candidate, keeps the prefix and pivot time intact, and replaces future tempos.
It rejects pivots before the caller's frozen frame threshold. This generalizes
Phanes's future-bar tempo adjustment. The clock itself does not own voices.
The separate [native scheduler](SCHEDULING.md) accepts future frame-note
replacements while preserving committed instances and bus tails. Lookahead and
device clock mapping remain caller responsibilities.

`TNoteSequence` owns its tempo map and at most 200000 note gates. Each gate has
positive tick duration, MIDI pitch 0..127, velocity 1..127, track/voice indices,
and channel -1 (unspecified) or 0..15. Gate arrays retain source ordering.
`CopyClock` returns a caller-owned map. Rest spans become gaps; meter, track
names, stable score IDs and performance controls remain in the source model.

## Incremental streaming clock

`TIncrementalTempoClock` in [pythian.time](../src/pythian.time.pas) extracts
WFC's ensemble-audio clock decomposition for streamed musical intervals.
The immutable tempo map remains the choice for random tick lookup;
the incremental clock retains only its current exact position.

Construct it with fixed PPQ and sample rate. `Advance(lengthTicks, tempo)`
accepts a nonnegative Integer interval and an integer MIDI microsecond tempo,
returns that interval's output frame count, and carries the fractional frame
into the next interval. Tempo can change on every call. Zero ticks validates
the arguments and returns zero without changing state.

A `TTempoClockSnapshot` contains configuration plus Int64 `TickCount`,
`FrameCount` and `FractionNumerator`. The fraction's denominator is
`ticksPerQuarter * 1000000`; frames are floor of accumulated absolute time.
Splitting an interval does not independently round its pieces.
The returned snapshot is a value, with no references to mutable clock storage.

`Restore(snapshot)` requires matching PPQ/sample rate, nonnegative counters
and a normalized fraction. Zero ticks requires zero frames/fraction.
Validation is structural: it cannot prove which source intervals produced
a snapshot. Applications persisting state must bind it to their timeline and
record `IncrementalTimingVersion`, currently 1. This API adds no file format.
Invalid restore or advance preserves every previous field.
`Reset` clears counters/fraction while retaining configuration.

Native limits are PPQ 1..High(Integer), sample rate 1..384000 Hz, tempo
1..16777215 microseconds per quarter, per-call ticks 0..High(Integer), and
cumulative counters through High(Int64). The implementation splits whole
microseconds and seconds before frame multiplication; it never multiplies
the entire elapsed tick count by tempo and rate. Work and storage are constant
per call. Frame and tick overflow reject before state publication.

Within the shared domain, every field matches WFC's actual
`AdvanceWfcMusicEnsembleAudioClock`. WFC retains its 32000..48000 Hz,
1..4000000 microsecond tempo and 2^53-1 cross-target limits; Pythian's wider
native limits are deliberate. No browser parity is claimed beyond the shared
domain. Ensemble audio admission and delayed release now have a separate
[native extraction](CHORD-STREAMS.md), reusing this clock through the WFC bridge.

The [scheduled synthesis demo](SCHEDULING.md) now places its phrase notes using
this clock with explicit 500000/375000-microsecond intervals. Its audio remains
unchanged. Device clocks, playback-context lifecycle and host scheduling
callbacks are separate concerns; this class is sequential and not thread-safe.

The [clock fixture](../tests/pythian.tests.clock.lpr) compares against an
independent short rational oracle, covers tempo/rate/PPQ extremes, split/whole
identity, restored replay, exact counts above 2^53 and atomic rejection of
invalid units, ticks, fractions and reachable cumulative overflow.
The ordinary native build uses no vendor paths. The WFC build repeats it with
`WFC_CLOCK_CHECKS`, comparing each field against the actual ensemble clock,
including a High(Integer)-tick interval.

## Raw MIDI and note extraction

`pythian.midi.smf` is the native extraction of WFC's format 0/1 PPQ SMF codec.
It keeps channel events, opaque metadata and SysEx bytes. End-of-track delta
belongs to the track record. Decoding expands running status; canonical encoding
writes explicit statuses and minimal VLQs. Thus semantic event preservation
does not imply byte preservation of a noncanonical input representation.

Defaults bound files to 64 MiB, tracks to 16 MiB, track count to 256, total
events (including end markers) to one million, and individual payloads to
16 MiB. Caller-supplied decoder limits can narrow those bounds. Invalid chunk
lengths, missing/extra end markers, nonminimal or oversized VLQs and malformed
channel/tempo data reject. Format 2, SMPTE timing and extended headers are not
supported. Raw records contain managed arrays: callers must detach before editing
a copied candidate; constructors and decoders own their byte payloads.

`DecodeMidiNotes` is an explicitly lossy projection with a 262144-event limit.
It merges by (absolute tick, track index, event index), then pairs globally by
(channel, pitch). The note-on determines track ownership; voice is track*16+channel.
Distinct simultaneous tempo values reject. The initial tempo is 500000
microseconds per quarter unless an explicit tick-zero tempo replaces it.

Defaults reject overlapping same-key notes, unclosed notes, controllers,
program changes, pitch bends and SysEx. Options can admit FIFO overlap pairing,
closure at global sequence end, or ignored unsupported events. Every such
action is counted. Zero-duration notes are omitted and reported. Nonzero release
velocities and non-performance metadata are counted as discarded information.
Percussion-channel notes are included as pitched gates unless explicitly excluded.

Device-name, channel-prefix, port and SMPTE-offset metadata always reject in
this note projection: flattening those routes into a global channel map would
change note pairing. The raw codec retains them. Import failure clears the
report and returns no sequence. The original file remains the authoritative
record when the caller needs information absent from a note projection.

## Native preview

The normal build compiles and exercises this tool without a vendor search path:

```text
pythian.midi.render INPUT.mid OUTPUT.wav [--ignore-performance] [--fifo] [--close-dangling] [--exclude-percussion]
```

Options are independent and default off. `--ignore-performance` permits counted
discarding of unsupported channel, opaque metadata and system events; it does
not bypass unsafe routing rejection. The tool prints every projection counter.

`PlanNoteTones` floors each note endpoint independently through the tempo map.
`RenderFrameTones` keeps start/gate frames as integers; only release seconds
round upward. Sub-frame gates are skipped and reported, including their tails.
Full sequence silence is retained. Rendering accepts one caller-selected voice
for all notes or an explicit per-voice table, equal-tempered pitch and linear velocity. No General MIDI kit,
program, pitch-bend or sustain-pedal emulation is claimed. Unsupported
frequencies reject rather than clamp. The existing offline output, tone count
(65536) and visit budgets apply; very long or dense files can exceed them.

`ProjectWfcNotes` consumes the actual WFC score class in `adapters/wfc`.
It requires twelve-step pitch semantics, copies tempos and gates, and expands
chords while retaining track and voice indices. The original score continues
to own its meters, names, IDs and constraint semantics.

### Independent synthesis voices and ensemble frames

The `TNoteVoices` overloads of `PlanNoteTones` and `RenderNoteSequence` select
`AVoices[Gate.Voice]`. Track, channel and event order do not select the synthesis
voice. The dense table contains 1..4096 entries; every gate, including a sub-frame
gate, must have a binding. A missing binding rejects without publishing a partial
plan. Voice records are copied into the plan; referenced automation curves and
source factories retain their documented borrowed lifetimes. The single-voice
overloads and MIDI command retain their existing behavior.

The instrument overloads accept one `TInstrument` or a `TNoteInstruments` table
using the same voice indices and exact clock. Each gate expands into its matching
pitch/velocity zones. `TNoteRenderReport.RenderedNotes` counts sounding source
gates; `RenderedTones` counts expanded layers (equal for ordinary voice bindings).
The 65536-tone budget applies after expansion. See the
[instrument contract](INSTRUMENTS.md#using-the-existing-renderer-and-scheduler)
for admission, ownership and native MIDI audition evidence.

`ProjectWfcEnsembleNotes(Frames, QuantumTicks, Template)` uses the actual companion
`RebuildWfcMusicEnsembleScore` before native note projection. The template supplies
PPQ, meter, tempo and voice identities, and the frames must cover its exact length.
WFC validates attacks/rests and requires a held chord to retain its pitches and
velocities. Consecutive holds become one note gate per chord tone, so native
oscillators/envelopes are not retriggered at cell or tempo boundaries. The returned
sequence survives destruction or mutation of the input frames and template.

`ProjectRetimedWfcNotes(Score, QuantumTicks, CellLengths)` supplies an explicit
logical-cell to native-time mapping. Positive lengths define the realized
requested prefix; note/tempo events must align exactly to source cell boundaries.
Sounding notes beyond that prefix reject, while trailing source rests may complete
the logical WFC measure. The detached native sequence retains PPQ, tempo values,
pitch, velocity and track/voice identity and may end between bar boundaries.
This is used by [duration-driven voices](INDEPENDENT-VOICES.md#measured-duration-driving-dependent-voices).
Its MIDI round-trip checks realized timing independently of the padded source
score; meter remains an explicit authored choice.

Admission is bounded by 200000 frames and a combined 200000 voice-cell/tone visit
budget before WFC reconstruction. The existing note/tone/output budgets still
apply. This is a complete-timeline bridge. A separate
[incremental chord bridge](CHORD-STREAMS.md#wfc-bridge) now accepts individual
ensemble frames with held phase and delayed release.

WFC's ensemble PCM renderer uses a delayed mix ring to shape release inside the
already elapsed gate and appends no tail. Native voices use their declared ADSR,
including release after note-off, stereo placement and caller-selected sources.
These are explicit synthesis differences; this bridge does not claim identical
PCM or replace the retained companion's compatibility renderer.

`AdmitWfcEnsembleFrame` now connects that compatibility behavior to the native
`TChordStreamRenderer`, with actual companion PCM parity. It borrows a matching
incremental clock and restores fractional timing on rejected admission. See
[the streaming contract and example](CHORD-STREAMS.md).

The native [coupled-layer example](LAYERS.md#native-listening-example) now uses
the per-voice planner for pitch, clock and voice selection. Its original continuous
performance amplitude is applied after planning, preserving the existing audio.

## Verification

Optional [voice automation](MODULATION.md) and [source factories](SOURCES.md)
are borrowed by planned tone records. Keep them alive until rendering finishes.
Curve frame coordinates are relative to each note-on at the output sample rate.

Checked with FPC 3.3.1 on i386 Windows, with assertions, range, overflow and I/O
checks. Logs: `build/music-validation.log` and
`build/music-focused-validation.log`.
The final vendor-independent rebuild is in `build/music-core-validation.log`;
the precursor preview report is in `build/midi-mutopia-validation.log`.

- Independent fractional clock expectations, extreme integer inputs, grid
  boundaries, frozen-prefix preservation and detached tempo candidates.
- Complete hand-authored SMF golden, every truncation, invalid VLQ, running
  status, cross-track note pairing, FIFO policy, dangling closure, controller
  reporting, tempo conflicts, unsafe routing and owned opaque payloads.
- Exact first/last note frame, replay, tempo-crossing gates, end silence,
  rejected oversized frame coordinates and reported sub-frame notes.
- Actual WFC score projection, chord/rest semantics, source destruction,
  fractional frame-count agreement with WFC's renderer and complete canonical
  SMF byte agreement with WFC's codec.
- Per-voice sine/square planning with reversed source voice/track order and a
  tempo-crossing overlap agrees sample-for-sample with independently timed stereo
  tones. Missing bindings preserve the prior plan; caller table edits do not alter it.
- Actual WFC ensemble reconstruction retains a held chord and independent bass
  through a tempo change, rejects changed-velocity holds and preserves source
  identity and the detached clock. Evidence: `build/ensemble-focused.log`,
  `build/voice-bindings-focused.log`; complete caller rebuild in [Work](WORK.md).
- The existing seconds-based synthesis demo retains SHA256
  `07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.

An optional integration run used Phanes's pinned `mutopia-2247.mid`:
“Vocalise № 1” by F. Abt, recorded as Public Domain in that precursor's
`data/music/references.json`. Input SHA256:
`bd6524f98752dd9190376e29dd0bce82d5bd5e57dcdbd549687e7836629434ff`.
No source MIDI was copied into Pythian fixtures.

With `--ignore-performance`, 181 notes from six tracks/426 events rendered
1544781 stereo frames at 44100 Hz (35.029 seconds). The report counted eight
ignored performance events and 49 metadata events, with no FIFO overlaps,
dangling closures, zero-duration notes or sub-frame notes. PCM output peak
was 0.8779602 and RMS 0.1403444 in each channel. Artifact:
`build/3.3.1-i386-win32/midi-mutopia-2247.wav`; SHA256:
`a3e7cd4f25eb60212e6358e0ca4446abe2c09eeda78c18682f0332051779e7c9`.

A separate `chiptunes-01.mid` run rejected unsupported routing metadata,
including with `--ignore-performance`; no WAV was published. Both outcomes
are integration evidence, not a broad MIDI compatibility or listening-quality
claim. Operator listening, full performance rendering and device scheduling
remain open gates.
