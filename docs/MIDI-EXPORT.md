# Native note-to-MIDI export

[Home](../README.md) · [MIDI and timing](MIDI.md) ·
[Byte streaming](MIDI-STREAMS.md) · [Independent voices](INDEPENDENT-VOICES.md)

[pythian.midi.export](../src/pythian.midi.export.pas) turns a native
`TNoteSequence` into ordered MIDI note and tempo events. It distills the
reusable timeline ordering from WFC's complete-score exporter and uses
`pythian.midi.stream` for the file transport. Core compilation needs no
companion source paths.

## API and channel control

```pascal
LBytes := EncodeMidiNotes(LSequence, [0, 1, 2]);
```

This explicitly maps native voice indices 0, 1 and 2 to MIDI channels 0, 1
and 2. Channel numbers are zero-based. A nonempty dense table overrides
`TNoteGate.Channel` by `TNoteGate.Voice`, independently of its track.
Every note requires a binding. The table has at most 4096 entries; every entry,
including unused entries, must be 0..15.

An empty table preserves each gate's existing channel. An unspecified channel
(-1) then rejects. There is no automatic voice/channel fallback, channel-10
percussion avoidance or program/instrument assignment. More than 16 source
roles can share output channels only where their equal-pitch note gates do not
overlap. MIDI channels are an output routing choice, not a new learned role.

For a host consuming byte blocks, construct an owned `TNoteMidiExport`:

- `EventCount` counts logical tempo/note events, excluding transport bridges
  and the owned end-of-track event.
- `EventAt(index, absoluteTick, event)` returns events in replay order with
  `DeltaTicks=0` and a fresh payload.
- `CreateStream` returns an owned `TMidiFileStream`. Drain the header,
  admit each EventAt result and drain, then Finish at `LengthTicks` and drain.
- `Encode` returns a detached complete file; the convenience function above
  constructs and frees the plan around this operation.

The plan copies scalar event rows and clock information. The source sequence
and channel array are borrowed only during construction. Returned payloads
and a stream's copied transport plan survive destruction of the export object;
a host still needs its own event source to finish replay if it frees that object.
No sink or filesystem is owned by this core API.

## Ordering, bounds and deliberate differences

Output is one format-0 track with PPQ 1..32767. Events sort by absolute tick,
then tempo / note-off / note-on, then original source ordinal. Thus a repeated
pitch released and attacked at the same tick has an unambiguous gate boundary.
All tempo changes, including a supported terminal change, retain their positions.

Simultaneously sounding equal pitches on the same final channel reject before
publication. Different pitches may overlap and equal pitches on different
channels remain independent. No note is dropped, shortened, merged or rerouted
to resolve a collision. Constructor failure preserves a prior assigned plan.

The native sequence already limits input to 200000 gates and 65536 tempo
changes. The planner holds two scalar rows per gate plus one per tempo and
uses an equally sized temporary merge buffer. Construction is O(N log N) with
O(N) storage; subsequent event access is direct. The byte writer retains at
most one event plus bounded output blocks. Whole-file encoding additionally
allocates the result, with a 16 MiB limit. Native note import has its own smaller
262144-event cap, so successful export at the largest accepted input does not
promise admission by that importer.

Long delays use the byte stream's empty-text bridges; the WFC whole-score
exporter instead rejects deltas exceeding one VLQ. Native note gates have
Integer tick endpoints; this API does not widen their timeline to the byte
writer's larger Int64 envelope.

Only note pitch, attack velocity, gate positions, selected channel, PPQ, tempo
and timeline extent are represented. Note-offs use velocity zero. Track/voice
identities, names, meter, keys, performance controls, instrument programs,
synthesis envelopes and timbres are not reconstructed from native note data.
Use the original score or raw SMF model when those fields must be retained.
This is an explicit note projection, not a lossless score or performance export.

## Evidence

Focused checks pass on FPC 3.2.2 and 3.3.1, both i386-win32:

- Independent native canonical bytes cover unsorted input, two channels,
  simultaneous tempo/release/attack, chords and trailing silence. Strict import
  retains note gates, channels and exact tempo timing.
- Ownership and admission checks cover source destruction, returned payload
  mutation, preserved prior plans, unspecified/missing/invalid channel bindings,
  same-channel pitch collisions and silence exceeding one MIDI delta.
- The existing WFC music fixture compares complete bytes with the actual
  `BuildWfcMusicMidiFile` export after removing only meter events and carrying
  their delta forward. This proves parity for the shared note/tempo projection,
  not equality with the original full-score file.
- At this checkpoint the independent-voice demo wrote a 785-byte `OUTPUT.wav.mid` for 88 generated notes on
  three explicit channels. With `--verify`, strict decoding matches each note,
  assigned channel, PPQ, extent and both tempo changes. Existing actual-WFC
  preview PCM verification also passes.
- MIDI, JSON, stereo WAV and preview WAV match across compilers. Both WAVs also
  match the previous voice-demo output byte-for-byte.

MIDI SHA256:
`e2889da815aa8cf59a526be0440fa8273090fe0ff4623a17802060ccc04b2995`.

The demo's later [frame-stream MIDI path](CHORD-MIDI.md) adds the declared meter
and produces 793 bytes, while retaining the same notes and tempos. The finite
note API and packaged native notes example retain their documented projection.

Evidence logs are `build/midi-export-stable-checked.log`,
`build/midi-export-trunk-checked.log`,
`build/midi-export-stable-voices-final.log`,
`build/midi-export-trunk-voices-final.log` and
`build/midi-export-replay.log`. Compiler folders contain
`voices-midi.wav.mid` and the related audio/report outputs.
Reported compiler warnings belong to unchanged companion units; no new owned
warning was observed. A subsequent [package checkpoint](PACKAGING.md#current-fifty-unit-package-checkpoint)
now includes this unit and verifies the independent-voice consumer from extracted
sources. The packaged native notes example also preserves complete rendered WAV
bytes through MIDI export/import. Additional platforms and General MIDI playback
remain outside this evidence.
