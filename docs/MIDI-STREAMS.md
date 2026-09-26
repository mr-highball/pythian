# Forward MIDI streaming

[Home](../README.md) · [MIDI and timing](MIDI.md) ·
[Provenance](PROVENANCE.md) · [Work](WORK.md)

For rest/attack/hold input with bounded active state, the
[chord-frame MIDI layer](CHORD-MIDI.md) supplies counting and replay over this
transport, sharing renderer-independent native frame data with audio.

## Contract

[pythian.midi.stream](../src/pythian.midi.stream.pas) extracts the complete
WFC MIDI stream transport into the portable core. It depends only on the
native SMF event types and runtime; WFC remains a comparison source and companion.

The writer produces format-0, single-track PPQ MIDI with explicit event status.
It needs a replayable event source because the MTrk length precedes its data:

1. Append events to a `TMidiTrackCounter` with nondecreasing absolute ticks.
   Incoming `DeltaTicks` must be zero. Equal-tick order is caller order.
2. Call `Finish(endTick)` to get a caller-owned immutable `TMidiTrackPlan`.
   The counter supplies end-of-track; callers cannot submit it themselves.
3. Construct `TMidiFileStream.Create(ppq, plan)`. It copies plan scalars;
   the plan can be freed immediately. Drain the pending header.
4. When `NeedsInput`, replay the same event at the same tick, then drain
   `ReadBytes(maximum, bytes)` before the next event.
5. Call `Finish(endTick)` when input is drained, then drain the final bytes.
   Only `Finished` means the entire file has been returned.

The counter retains no timeline or payload. Its plan contains end tick, track
byte count, logical event count, generated bridge count and versioned FNV32
signature. Logical counts include EOT and exclude bridges. Repeated counter
Finish at the same end returns a fresh plan; events or a different end then
reject. A default-constructed plan is invalid and rejected by the writer.
This explicit native guard replaces the precursor's private constructor.

PPQ is 1..32767; absolute ticks retain the precursor's 0..9007199254740991
envelope. Track data must fit its unsigned 32-bit length. Each payload fits
the four-byte MIDI VLQ limit and native Integer indexing. Channel, meta and
SysEx rules follow canonical SMF validation; this does not implement musical
interpretation or instrument rendering.

## Memory and long delays

Each output block is at most the requested positive Integer size and at most
4096 bytes. False returns nil. Returned bytes belong to the caller.

The writer retains fixed scalar/prefix state plus a detached copy of the
currently admitted payload. Thus output blocks are bounded, but total memory
still scales with the largest admitted event payload. Applications should impose
their own smaller payload limits where needed. The source must be replayable;
live input of unknown length needs a host spool or another framing protocol.

Gaps beyond `$0FFFFFFF` ticks insert empty text meta events `FF 01 00`
at that maximum delta. For a positive gap the bridge count is
`(gap - 1) div $0FFFFFFF`, leaving a final delta in 1..maximum.
Counting bridges is constant time; writing them is incremental and proportional
to the output. An exact maximum delta needs no bridge. This changes physical
event count while preserving logical event timing.

## Ownership and failure

Invalid arguments, ordinary event validation and staging allocation failures
leave admission retryable. A replay exceeding its plan or failing the final
counts/signature check sets `Failed`; unexpected processing failures do too.
FNV32 is accidental replay-change evidence, not collision-proof authentication.
The host must discard any already returned prefix after failure.

`Cancel` discards queued data without EOT and is terminal. It cannot heal a
failed writer. Successful Finish is idempotent at the same end, including while
EOT is still pending. Destruction does not drain, publish or close any host sink.
Instances are sequential and non-reentrant.

The example owns a file sink and writes directly to its requested path.
An I/O error may leave a partial file; atomic publication belongs to the host.
The stream API does not claim transactional filesystem replacement.

## Native example

For a native note sequence instead of a custom replay source, use the
[note export planner](MIDI-EXPORT.md) to obtain ordered events and a stream.

[pythian.example.midi.stream](../examples/pythian.example.midi.stream.lpr)
replays a tiny deterministic event source twice and writes blocks directly to
a host-owned file. It retains neither the full event list nor complete file bytes.
The notes and tempo are authored, with no learning or source recording.

After compiling the example with the core unit path:

```text
pythian.example.midi.stream OUTPUT.mid
pythian.midi.render OUTPUT.mid OUTPUT.wav
```

The normal build includes the fixture and example. The existing MIDI renderer
can audition the file through its single-voice preview policy.

## Verification

On installed FPC 3.2.2 and 3.3.1, both i386-win32:

- The focused native fixture matches complete canonical SMF bytes for tempo,
  meter, channel events, a 16384-byte SysEx payload, generated delay bridges,
  EOT bridges, exact maximum deltas and an empty file. Requested blocks of
  1, 137, 4096 and 65536 bytes respect the 4096-byte internal bound.
- The actual pinned WFC writer agrees on complete output, plan byte/event/bridge
  counts and signatures. The only reported parity-build warning is the existing
  upstream private-constructor warning.
- Ownership and lifecycle checks cover freed plans, payload mutation after
  admission, retryable invalid input, frozen counters, changed same-size replay,
  cancellation, invalid default plans and maximum-tick counting without emitting
  millions of bridges. No multi-gigabyte output or allocation-failure injection
  was exercised.
- Core-only compilation uses no vendor paths. Existing timing/MIDI/frame-render
  checks pass. The example emits 177 bytes for 16 notes; the existing renderer
  produces 180313 stereo frames at 44100 Hz. Both MIDI and WAV files are
  byte-identical across compilers.

Evidence is under ignored build output:
`midi-stream-stable-checked.log`, `midi-stream-trunk-checked.log`,
`midi-stream-stable-consumer.log`, `midi-stream-trunk-consumer.log`,
`midi-stream-replay.log` and the later final fixture logs.
Compiler folders contain `streamed.mid` and `streamed.wav`.
These initial checks were focused. A subsequent
[package checkpoint](PACKAGING.md#current-fifty-unit-package-checkpoint) now ships
the stream example and runs it from extracted sources on both compilers.
Score/import/export now have separate complete review dispositions in
the [precursor inventory](PRECURSOR-BOUNDARIES.md#score-model-and-midi-projection);
the remaining text/training/pass and ensemble support audit stays open.
