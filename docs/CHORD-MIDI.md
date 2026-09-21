# Incremental chord-frame MIDI

[Home](../README.md) · [MIDI byte streams](MIDI-STREAMS.md) ·
[Finite note export](MIDI-EXPORT.md) · [Independent voices](INDEPENDENT-VOICES.md)

[pythian.midi.chord](../src/pythian.midi.chord.pas) extracts WFC's complete
ensemble MIDI transport. It accepts native rest/attack/hold frames, counts
their logical MIDI events and replays them through `pythian.midi.stream`.
Storage depends on the active and pending frames, not elapsed ticks or events.

## Shared frame data and companion bridge

The renderer-independent [pythian.chord](../src/pythian.chord.pas) owns
`TChordAction`, `TChordTone`, `TChordTones`, `TChordVoice` and
`TChordFrame`. These are data records, without a clock or synthesis backend.
The existing `pythian.chord.stream` re-exports type aliases and action constants
so existing renderer callers retain their public names.

`ProjectWfcChordFrame` in `pythian.wfc.music` returns a detached native frame
from an actual WFC ensemble frame. It bounds voices and aggregate tones and
maps actions. Audio and MIDI then apply their own capacity, pitch and held-state
validation. The existing audio admission helper now uses that same conversion;
its clock rollback and renderer behavior are unchanged.

## Counting and replay

`DefaultChordMidiOptions(channels)` supplies PPQ 480, tempo 500000 microseconds
per quarter and meter 4/4. Override these explicitly before construction.

1. Create a `TChordMidiCounter` and call `AdmitFrame(frame, tickLength, timing)`.
   The overload without timing means no frame-start change.
2. `Finish` closes remaining notes at the accepted end and returns a caller-owned
   `TChordMidiPlan`. It contains detached options and the MIDI track plan.
3. Create `TChordMidiStream` from that plan; it copies all required data, so the
   plan and counter can be freed. Drain initial header/tempo/meter bytes.
4. While `NeedsInput`, replay each trusted source frame and drain
   `ReadBytes(maximum, bytes)` before the next admission.
5. Call `EndInput` and drain final releases and EOT. Publish only after `Finished`.

The public `TChordMidiEvents` cursor exposes the logical absolute-tick events
without a file sink. It owns initial timing and final note releases but does not
emit EOT itself. Its counter/stream wrappers provide the file planning and replay
failure lifecycle. None of these objects retains a score or full event timeline.

Plans can only be used after a completed counter constructs them. Native default
plan objects reject use explicitly instead of relying on the precursor's private
constructor convention. `CopyOptions` and event/output payloads are detached.

## Musical and wire rules

Channels explicitly map 1..16 voices uniquely onto MIDI channels 0..15. Channel 9
is neither skipped nor silently selected. No program, bank, instrument or tuning
messages are invented. Each sounding voice holds 1..128 strictly increasing
pitches in 0..127, with velocity 1..127; a rest has no tones.

An attack closes the prior voice then starts its new tones, even for identical
pitches. A hold requires identical active pitches and velocities and emits no
note seam. Across voices, every release precedes every attack, ordered by voice
then pitch rather than numeric channel. EndInput releases remaining tones at the
exact accepted end.

A timing record's zero tempo or zero meter numerator means no change; absent
meter also requires denominator power zero. Supplied timing emits at the frame
start: tempo, then meter, then note events. Repeated values are intentionally
emitted. PPQ is 1..32767, positive tempo fits three bytes, numerator is 1..255
and denominator power is 0..255. These are wire-field limits, not a score measure
validator or inferred meter.

Frame lengths are positive Int64 ticks and their sum must fit
0..9007199254740991. This differs from the audio renderer's sample-frame lengths,
which can be zero after exact clock conversion. The byte transport bridges gaps
beyond one MIDI VLQ; a held note does not need to be split into extra attacks.
Empty frame input is valid: initial tempo/meter plus EOT at tick zero.

## Ownership, limits and failure

Only bounded active/pending frames and copied options are retained, at most
16 voices × 128 tones per frame. Counting delay bridges is constant time;
serialization is proportional to actual output. ReadBytes returns at most the
requested positive size and at most 4096 bytes; False returns nil.

Malformed admission preserves state and is retryable. Unexpected processing,
capacity or replay failure sets Failed. A failed coalesced read returns nil and
does not add its discarded bytes to the wrapper's EmittedBytes. Discard any
earlier returned prefix on terminal failure. Cancel is terminal and emits no EOT.
No file, callback or publication operation belongs to the core.

The plan's FNV32 signature detects ordinary logical-event replay changes; it is
not cryptographic authentication and not a saved generation checkpoint. Frame
boundaries are not independently authenticated. Replaying trusted immutable
source remains the host's responsibility. The API is sequential and non-reentrant.

## Verified native and WFC consumers

On FPC 3.2.2 and 3.3.1 i386-win32, the focused fixture checks:

- Canonical native SMF bytes for held chords, rests, reattacks, nonnumeric channel
  order, tempo/meter changes, repeated timing and empty input.
- Complete actual WFC bytes, plan counts/signature and detached frame projection.
- Source/plan ownership, retryable invalid holds, changed replay rejection,
  discarded failed-read accounting and cancellation.
- A held duration beyond one VLQ, maximum exact tick counting without expanding
  millions of bridges, and all 16 channels with 128 pitches each. The full-capacity
  output exercises the 4096-byte block bound.

Core-only MIDI compilation uses the shared data and native MIDI units without an
audio renderer or companion source path. Existing chord-renderer fixtures,
including every-sample actual WFC PCM checks, pass after the shared-type and
frame-conversion extraction. No owned compiler warning remains; upstream
warnings are unchanged.

The independent-voice tool now produces its MIDI from the generated frames.
It retains initial declared 4/4 meter, both tempos and all 88 notes on three
channels. With `--verify`, strict note import matches every gate/channel/tempo
and complete bytes match the actual WFC full-score exporter. The file is
793 bytes; its earlier finite-note export was 785 bytes and omitted the eight-byte
meter event. This change adds declared metadata and preserves note timing.
The tool's fixed 64-cell plan and output buffers still make it a finite example;
the reusable MIDI cursor/wrappers have the bounded memory contract above.

Current MIDI SHA256:
`88a5c0ef90959e7da60a48c301da3a4a65992cf92c29bfe17a9052df3fba863d`.

Stereo and preview WAVs remain byte-identical to the preceding voice example.
All four current artifacts also match across compilers. Logs:
`build/chord-midi-stable-capacity.log`, `build/chord-midi-trunk-capacity.log`,
`build/chord-midi-stable-final.log`, `build/chord-midi-trunk-final.log` and
`build/chord-midi-replay.log`. Compiler folders contain `voices-chord-midi.wav`,
its preview WAV, MIDI and JSON.

These focused checks follow the fifty-unit checkpoint. The subsequent
[52-unit packages](PACKAGING.md#earlier-fifty-two-unit-package-checkpoint) compile all units at that checkpoint
and verify the external chord-MIDI and voice consumers from extracted sources.
Older fifty-unit ZIPs retain their historical scope. Other platforms are unverified.
