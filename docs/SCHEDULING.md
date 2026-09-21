# Scheduled synthesis and future edits

[Home](../README.md) · [Sources](SOURCES.md) · [Buses](BUSES.md) ·
[Exact MIDI timing](MIDI.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

## Shared note renderer

For finite instrument plans and sequential WAV output, see
[bounded tone streams](#bounded-tone-streams).

`pythian.synth.TPlayingTone` owns one note's playback, filter and envelope
state. Both offline rendering and scheduled synthesis now use this implementation.
Waveform, additive, FM/PM, wavetable and sample factories retain their existing
contracts; mono and stereo sources use the existing pan and filter behavior.

`Create(sampleRate, frameTone)` validates a nonnegative exact gate and a total
gate-plus-release duration of at most one day. Release duration rounds up through
`pythian.time.SampleFramesFromSeconds`: seconds times sample rate is stored at
Double precision before ceiling. This prevents x87 extended intermediates on
i386 from adding a frame that a 64-bit build does not. For example, 0.08 seconds
at 44100 Hz maps to 3528 frames on both targets. The helper also offers explicit
floor, rejects negative/nonfinite seconds and bounds results to 2^53-1; existing
voice/clip budgets are still enforced separately. Offline seconds starts use
floor, while gates, output extents and releases use ceiling. Scheduled admission
and early release use the same helper. Exact PPQ timing is unchanged.
Absolute StartFrame uses checked Int64 addition, while the
playing instance's Frame is relative to note-on. The scheduler interprets
StartFrame; direct use of a playing instance starts at relative frame zero.

The instance copies the five immutable automation curves. Callers may destroy
their original curves after successful construction/admission. SourceFactory
is **borrowed** and must outlive every admitted instance, including pending
notes. Playback/filter objects and curve copies are freed with the voice.
Built-in factories are immutable; custom factories must also report stable
channels/cost/range semantics and return independent playback instances.

`ReadFrame` advances one frame and returns stereo Double samples.
Envelope, pitch, cutoff and pan automation remain note-relative.
Source NoteOff is delivered once at the integer gate boundary, including a
zero-release gate. A zero gate delivers it before the first read.
An exhausted source supplies zeros through the remaining filter/envelope
interval; it does not silently shorten the declared note lifetime.

`Release` moves a still-held gate to the current relative frame, using that
note's existing ADSR release from its actual attack/decay/sustain level.
Repeated release does not extend an already-started tail. Failed processing
preserves caller outputs and makes the playing instance unusable; destroy it.
The scheduler supplies whole-session recovery.

The public `CreatePrepared` constructor preserves the offline seconds API's
fractional envelope gate and separate integer source gate/end. It validates
finite/nonnegative timing and the existing 32-million-frame offline bound.
It is intended for compatibility with prepared offline work, not absolute
device scheduling. Stored gate and duration quotients compare at the same
Double precision, avoiding a false rejection from x87 extended intermediates.

Offline mixing retains its previous expression order and rounds each addition
into Single clip storage. Scheduled bus accumulation uses Double.
Overlapping voices may therefore differ by Single rounding; the tested signal
comparison allows 3e-8. Legacy offline WAV hashes remain unchanged.

## Timeline and admission

`pythian.schedule.TScheduledSynth` borrows a healthy `TBusGraph` and owns
its admitted voices. Default capacity is 128; the supported range is 1..4096.
Default reserved-work limit is 1000000, configurable from 1 through 100000000.
A voice reserves `SynthFrameCost` plus 16 units of synthesis overhead.
`SynthFrameCost` includes the source (1 for the built-in oscillator), any custom
gate envelope and **16 times the depth of each non-nil automation curve**:
frequency, pitch cents, gain, pan and cutoff. A shared curve used in several
controls is charged for each evaluation. This follows the gate-envelope work
convention; weights bound declared work and are not measured CPU cycles.
Both pending and active voices reserve capacity/work, as Phanes's node-count
admission did. There is no implicit stealing or silent rejection.

`NextFrame` is the next unrendered absolute Int64 frame. Constructor
StartFrame defaults to zero and may initialize a later epoch without rendering
a long silent prefix. One successful Process increments it by exactly one.
Frame High(Int64) cannot be processed because the next cursor would overflow.

`TrySchedule(tone, bus, group, out id)` takes a nonempty note starting at or
after NextFrame. Bus indices must exist. Group is an application-defined
Integer; the core does not hardcode music/effects categories.
Admission returns srScheduled, srVoiceLimit or srWorkLimit. Capacity/work
rejection preserves the output ID and existing schedule and creates no source
instance. Invalid evaluated parameters or failed source construction raise
EAudio or the source exception. IDs are positive, monotonic and never reused,
including after Reset.

The queue mixes in successful admission order. Stable compaction after
cancellation/completion preserves retained order. Every frame traverses the
bounded queue and then the bus graph; silent frames continue processing bus
tails. Voice completion returns its count/work reservation and frees state.

ScheduledCount includes pending, held and releasing voices. ActiveCount counts
retained notes whose first frame was already processed; PendingCount counts
the remainder. A note starting exactly at NextFrame is still pending.
A note removed on its final frame no longer counts. These are playback lifecycle
counts, not measured-audibility or nonzero-amplitude counts.

## Cancellation, release and atomic replacement

`CancelFuture(group, fromFrame)` requires fromFrame >= NextFrame and removes
only matching notes whose start is at/after that pivot. It returns the number
removed. Earlier pending notes, committed voices, other groups and all bus
history remain untouched. Cancelling a pending note destroys its source without
reading it or starting an envelope.

`StopGroup(group)` cancels all pending notes in that group and requests early
ADSR release for its committed notes. It returns the number selected, including
already-releasing notes. `ReleaseVoice(id)` applies the same behavior to one
ID and returns False if that ID is absent. Neither operation resets the buses.
With zero release, cleanup completes on the next Process, delivering NoteOff.

`TryReplaceFuture(group, fromFrame, bus, tones, out firstId)` prepares a
complete replacement before publishing it:

1. Keep other groups and all notes starting before the pivot.
2. Validate replacement starts/durations and the resulting count/work budget.
3. Construct every new source, filter and copied automation curve separately.
4. Publish the new queue, preserving retained voice objects and their order.
5. Release removed pending sources; append replacements in supplied order.

Every replacement starts at/after the pivot. New IDs are consecutive.
An empty replacement removes matching future notes and returns firstId=0.
Capacity uses the **resulting** queue, so a full queue can replace its future
notes without first dropping them. Validation/admission/construction failure
preserves old notes, voice IDs, cursor, output ID and bus history; partially
constructed candidate voices are freed.

This is synchronous, with no concurrent revision race. Apply a detached tempo
map's converted future frame notes through this API; committed instances retain
their original timing. Calls belong between Process frames. UI coalescing,
lookahead windows and mapping a device clock into this frame epoch remain
host/application responsibilities.

## Ownership, failure and recovery

The scheduler borrows the graph, and exclusively drives its Process/Reset while
in use. Graph gain/effect configuration can be changed between scheduler
frames. Do not separately advance or reset the borrowed graph while notes are
scheduled. Destroy the scheduler before its factories or graph.

Admission and replacement allocate state before publication. Frame processing
performs bounded traversal and may destroy completed voices. These operations
are not claimed to meet hard real-time allocation or device-callback deadlines.
Custom sources/stages must obey their contracts; destructors must not raise.
A custom destructor failure after replacement publication poisons the scheduler;
it is outside the transaction's preparation-failure guarantee.

Source/factory/stage callbacks cannot reenter scheduler processing,
configuration, cancellation or reset. Read-only counters do not authorize
mutation. A source, mix or bus failure may leave earlier voices advanced:
the scheduler becomes Failed, preserves caller outputs and leaves NextFrame
at its previous value. Removing the cause alone does not permit reuse.

`Reset(startFrame=0)` explicitly discards voices and resets graph history and
gain targets, then sets the new cursor. It preserves the ID sequence. A failed
reset leaves the scheduler failed until a later reset succeeds. Reset is
destructive recovery, not a future-note cancellation primitive.

`RenderScheduledFrames(synth, count)` returns an owned stereo clip while
continuing scheduler and bus history. Preflight limits output to 64 million
scalar samples and 200 million weighted visits using reserved voice work,
queue capacity and graph cost. Invalid preflight preserves all state.
A later failure, including Single overflow or output construction, poisons the
scheduler and preserves the caller's previous clip assignment.

For long output, call Process and feed bounded blocks into the existing
`TWavePcm16Writer`. The demo synthesizes its voices directly this way; it does
not first allocate complete source/output audio clips.

### Automation work admission — 2026-09-20

The fundamentals review found that the shared cost calculation included custom
gate envelopes but omitted all five voice automation controls. Automation now
participates in offline visit limits, scheduler admission/replacement and tone
stream overlap/read budgets. Processing and sample values are unchanged. A
previously accepted heavily automated request may now exceed its declared budget;
use bounded rendering or an explicitly chosen supported reservation as appropriate.

The scheduler fixture first reproduced the missing charge. Its regression uses
five depth-eight controls sharing one immutable definition: source work is 1,
automation work is 640 and the scheduler reservation is 657. A 656-unit future
replacement rejects without source construction, preserves IDs/cursor/reservations
and renders the original pending notes against an independent offline reference.
The exact 657-unit reservation is accepted. Tone-stream preflight and whole-clip
work rejection exercise the same controls before constructing playback sources.

Checked stable/development Win32 and stable Win64 pass scheduler, modulation and
control-curve fixtures with zero unfreed blocks. Stable Win64 additionally passes
source, instrument, music-instrument and actual-WFC saved-style consumers. The
[combined 40-note workload](SYNTHESIS-QUALITY.md#automation-work-checkpoint)
retains its exact audio on all three targets. Logs are ignored under
`build/automation-work/`; this is focused workload evidence, not a new listening
verdict, package verification or device-performance guarantee.

## Precursor disposition

Phanes's active/scheduled counts, total-node admission bound, independent
music/effects groups, future cancellation and surviving echo tails inform these
native contracts. Browser node cleanup becomes Pascal ownership.

Pythian rejects late starts instead of silently clamping them to the device
clock, uses exact frame comparisons instead of a 10-microsecond cancellation
margin, and releases voices using their declared ADSR instead of Phanes's
fixed 15 ms gain target and 80 ms forced stop. Browser timing margins, audio
context resume and node disconnection stay at the host boundary. Atomic future
replacement, explicit work reservations and recovery semantics are new native
behavior. This does not claim Web Audio sample parity.

## Evidence and listening

Phrase placement in the native demo now uses the extracted
[incremental PPQ clock](MIDI.md#incremental-streaming-clock), with exact
fractional carry and explicit tempo intervals. Existing frame placements and
the seven-second WAV remain unchanged; clock extraction evidence is recorded
in [the work record](WORK.md).

Full checked build: `build/schedule-validation.log`, existing FPC 3.3.1
i386-win32. All 37 core units compile without vendor paths, followed by actual
WFC/MIDI/corpus learning and reconstruction checks. The shared-renderer
regression fix passes the existing oscillator fixture in
`build/schedule-refactor-regression.log`.

Final replacement/failure checks: `build/schedule-focused-validation.log`.
They cover start frames above 2^53, exact source gate notification, zero-release
cleanup, detached automation, stable IDs, count/work rejection, retained
committed voices and echo, group-scoped release during attack, construction
failure, source failure/recovery, callback reentrancy and split-block identity.
Failed replacement is rendered through the old future notes and compared
sample-for-sample with an unchanged reference; a successful replacement at full
capacity then matches the intended reference including retained tails.
An isolated `-gh` ownership run reports 416 allocated/freed blocks and zero
unfreed blocks: `build/schedule-ownership-validation.log`.

Final demo compile/render: `build/schedule-demo.log`.
`pythian.schedule.demo OUTPUT.wav [OUTPUT_RATE]` writes seven seconds of stereo,
defaulting to 48000 Hz,
in blocks of at most 1024 frames. At 2 s it atomically replaces music starting
at 2.5 s with a transposed phrase at different spacing. At 4 s it releases
music and cancels remaining future music; a separate effects burst still plays
at 4.25 s. Existing release and filtered-echo tails continue to decay.

Measured output: 336000 frames, left/right PCM peaks
0.1966552734/0.2375488281 and RMS 0.0354539598/0.0311177554.
Metrics: `build/schedule-metrics.json`. SHA256:

`e2aba881180f4e8e36e678f5a7c90e635a91c85c82432c7065c65d1f06c21798`

Legacy synthesis, source, effects and bus examples retain their previous hashes.
No authored compiler warnings; existing upstream WFC warnings remain.
The optional output rate uses [continuous sinc conversion](DSP.md#continuous-conversion)
directly from scheduled synthesis, preserving history across output blocks.
Input-frame edits retain their exact original timing. The 44100 Hz run uses
75 input frames of lookahead and a 151-frame ring, producing 308700 frames
without a full intermediate clip. The default output hash above is unchanged.

At this preceding checkpoint, operator listening, device deadlines, stable FPC
and other targets were unverified. The current stream evidence below records
the subsequently exercised targets; device deadlines remain unverified.

## Bounded tone streams

[`pythian.synth.stream`](../src/pythian.synth.stream.pas) exposes `TFrameToneStream`
for a finite `TFrameTones` plan. It owns detached tone records and an internal
unity-gain bus/scheduler. Source factories, automation and envelope definitions
are borrowed and must remain alive and unchanged until playback finishes.
Sources are constructed only at their exact start frames; scheduled playing
voices retain the existing cloned automation/envelope behavior. The measured
[instrument adapter](WAVE-STYLE.md#independent-measured-instruments) owns those
definitions independently of the original saved profiles.

Construction validates all tones and sorts start/end events by absolute Int64
frame. Ends precede starts at the same frame, so a slot can be reused immediately
after its complete release. Starts at the same frame retain caller order.
Preflight rejects overlaps beyond the selected voice or frame-work limits before
creating any playing sources. Defaults are 128 simultaneous voices and 65536
weighted voice-work units per frame; the existing event limit is 65536 tones.
The finite plan and event index consume memory proportional to note count, while
playback objects consume memory proportional to overlap, not total duration.

`ReadSamples(MaxFrames, Samples)` returns detached interleaved stereo Single
samples. Requests are 1..2048 frames; `ReadLimit` may reduce the returned block to
respect the shared 200-million-visit per-call budget, including conservative
dispatch/scheduler overhead. Sources, filters and envelopes retain their state
across every read. `FrameCount` includes exact natural tails and any requested
minimum extent. False/nil means the stream has ended. An invalid request is
retryable; a processing/source failure poisons the stream and publishes no partial
block. `EmittedFrames` counts only completely returned blocks.

Mixing follows the scheduler: stable start/input order, Double accumulation and
one final Single conversion per channel/frame. This differs from offline
per-tone Single accumulation. Read partitioning is exact; comparison to the
preceding short offline instrument output stays within one PCM16 step.

Musical `PlanNoteTones` now limits events rather than full-clip storage. Its
returned exact frame plan can feed this stream over longer time spans.
`RenderNoteSequence` and `RenderFrameTones` retain their offline sample/work caps.
This change neither raises those caps nor claims device deadlines.

The [instrument consumer](../tools/pythian.instrument.style.lpr) forwards blocks
to the existing sequential PCM16 RIFF/RF64 writer. It stages the complete mix and
three stems in temporary files, hashes them with bounded reads, then copies them
to requested outputs with bounded buffers. A late admission or synthesis failure
removes staging files and preserves all accepted outputs. Publication I/O across
the six outputs is not transactional. No duration-sized PCM array is retained.

Checked stable/development Win32 and stable Win64 pass the extended existing
scheduler fixture, musical planning/rendering fixtures, profile fixtures and
sustained instrument checks. Evidence is in
`build/instrument-stream-{stable,trunk,win64}/`. Irregular core read sizes and
127/2048-frame consumer reads replay exactly. The previously rejected authored
WFC passage now renders 88 notes / 791022 stereo frames at 44100 Hz, peaking at
12 voices and 624 weighted voice-work units per frame. Its measured mixed peak
is 0.0404041. A changed melody envelope preserves bass/chord stems and MIDI.
Forty-eight cross-target WAV/MIDI/JSON comparisons are byte-identical.

The full maintained recorded workflow also passes stable Win32. It regenerates
admitted key/tempo plus authored phrase training and yields a separate 88-note,
729281-frame sustained audition. This is measured sound applied to accepted
music; the isolated-note duration model still cannot generate a 32-span phrase.
Recorded phrase learning remains open. These current stream checks supersede
the earlier target limitation only for their explicitly exercised paths;
operator listening, device deadlines and current Linux delivery remain unverified.

## Tone streams as PCM input

[pythian.synth.resample](../src/pythian.synth.resample.pas) supplies
`TTonePcmReader.Create(Stream, BlockFrames = 2048)`. It borrows a
`TFrameToneStream` at its current emitted position and exposes the remaining
stereo samples through `TPcmFrameReader`, suitable for `TSincResampleStream`.
No whole high-rate clip is required. The adapter buffers at most the selected
1..2048 frames; the stream's work-based read limit may reduce actual blocks.
Samples retain native Single precision and floating headroom.

Keep the source definitions, tone stream, PCM reader and converter alive in that
order; destroy the converter first and source definitions last. Neither reader
nor converter owns its input. `FramesRead` counts frames handed to the converter,
while the tone stream may already have produced the rest of a buffered block.
Reading the stream elsewhere while attached is a contract violation. The adapter
checks its expected position and stream failure before serving buffered samples.
That violation or a processing failure poisons the reader; later reads reject.
EOF and failure preserve the caller's output arguments. There is no rewind,
concurrent access, channel conversion or automatic gain policy.

Oversampling still requires the caller to construct the tone plan, gates and
frame-based controls at the high render rate. This adapter performs no retiming
and does not make arbitrary modulation alias-free. The converter retains its
bounded lookahead/history and exact ceiling-duration contract.

The existing scheduler fixture now checks the bridge against offline conversion
at 16000 to 11025 Hz: 1234 input frames produce exactly 851 output frames, including
a partial final block. It also covers attachment after three consumed frames,
repeated EOF, borrowed lifetime and external-advance poisoning with output
preservation. Checked stable/development Win32 and stable Win64 pass under
`build/fm-stream-{study,stable,trunk}/schedule{,-build}.log`. The
[FM/PM checkpoint](MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19)
exercises the actual source/renderer/reader/converter chain and bounded storage.
