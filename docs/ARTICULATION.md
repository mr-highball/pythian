# Output articulation on explicit musical clocks

[Home](../README.md) · [MIDI timing](MIDI.md) · [Joint learning](JOINT.md) ·
[Architecture](ARCHITECTURE.md) · [Work](WORK.md)

## Scope and signal contract

[pythian.articulation](../src/pythian.articulation.pas) applies an explicit
musical envelope to a reconstructed or recorded clip. The native core uses
the same exact PPQ tempo map as MIDI synthesis. It requires no WFC or Phanes
source paths. This is new Pythian output control; measured source activity and
the joint learner retain their existing versions and meanings.

Output frame i reads input frame i and multiplies both channels by the same
envelope. A rest has zero gain after all grain overlaps have been mixed.
There is no implicit looping, padding, pitch change, time stretching or source
beat detection. The source must cover the complete plan; extra source frames
are trimmed. Applying effects afterward can introduce new tails into rests.

An attack means the start of an amplitude gate. It does not promise a recorded
transient at that sample. The [timing adapter](TIMED-LEARNING.md) now projects
these gate starts onto learned onset-candidate constraints with explicit frame
error and collision checks. True source-beat alignment, transient localization
and preserving pitch during tempo changes remain separate work.

## Plans and timing

`TArticulationPlan` owns a copied array of half-open
`TArticulationGate(StartFrame, EndFrame, Gain)` values and its sample rate,
output frame count and fade lengths. The clock, note sequence and audio are
borrowed only during each synchronous call. Returned plans and clips are
detached and caller-owned.

`PlanGridArticulation(clock, startTick, gridTicks, pattern, rate, attack, release)`
accepts one literal character per grid cell; it never repeats a pattern:

| Character | Output behavior |
| --- | --- |
| a | Start a new gate, closing any earlier gate at this boundary |
| h | Extend the active gate without retriggering its fades |
| r | End the active gate and leave the cell silent |

A leading hold or a hold after a rest rejects. Unknown characters, empty
patterns and cells shorter than one output frame reject. An all-rest pattern
is valid and produces the full duration of silence. The complete pattern must
fit the supplied clock.

Each boundary is floor-quantized independently through the exact absolute PPQ
clock. Subtract the floor-quantized start frame afterward. Tempo changes and
fractional phase at a nonzero starting tick are therefore preserved; rounding
a relative duration afresh would give different boundaries. Plan frame zero
always corresponds to input clip frame zero, even when the clock starts at
a nonzero tick. The caller supplies the corresponding source segment.

`PlanNoteArticulation(sequence, rate, attack, release, out subFrameNotes)`
projects all note-on/off intervals through the same clock. Velocity supplies
gain as velocity/127; pitch, track, voice and channel do not select audio.
Notes whose independently floored endpoints coincide are omitted and counted.
The output includes the whole sequence, including leading and trailing rests.
The returned count is zero on failure.

Overlapping gates use the maximum instantaneous envelope. They neither sum
nor merge their fade ramps. Thus a chord does not amplify the clip, but an
overlapping held note can cover a new note's attack fade. Callers needing
separate instruments should route separate clips and plans.

## Fades, bounds and failure

For a gate [s,e), fade lengths A and R in sample intervals, and gate gain v,
the gain at frame i is:

`v * min(1, (i-s)/A when A>0, (e-1-i)/R when R>0)`.

A zero fade omits its factor. Positive fades make the first/last sample zero;
their full duration remains inside the gate. Short gates retain the minimum
of overlapping ramps and may never reach full gain. A one-frame gate with
either positive fade is silent. Zero fades allow discontinuities.

Gate gains must be finite in [0,1]. The plan admits at most 65536 gates,
16000000 output frames, and 64000000 summed gate-frame visits. Rendering
also limits output to 16000000 scalar samples, so stereo admits half as many
frames. Fade lengths are integers from zero through 16000000.
Preflight validates all gates and reserves the complete visit count before
rendering allocation. Invalid input raises `EAudio`; borrowed state is unchanged.

## Native workflow and metadata

The [native tool](../tools/pythian.articulate.lpr) accepts:

```text
pythian.articulate INPUT.wav OUTPUT.wav grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN [ATTACK_FRAMES RELEASE_FRAMES]
pythian.articulate INPUT.wav OUTPUT.wav midi INPUT.mid [ATTACK_FRAMES RELEASE_FRAMES]
```

Grid mode uses PPQ 480; 500000 microseconds per quarter means 120 BPM,
and 240 ticks means an eighth note. MIDI mode uses the imported file's own
PPQ and tempo changes with the existing strict note-import defaults. It
rejects unsupported performance controls, ambiguous overlapping same-pitch
notes and dangling notes. This tool does not implicitly enable lossy import
options. Its sidecar records discarded metadata, release velocities,
zero-length notes, sub-frame notes and default-tempo use as applicable.

Default fades are ceiling(rate/200) attack and ceiling(rate/100) release,
approximately 5 and 10 ms. Explicit frame arguments override both together.

The output WAV has an inspection-only `.wav.json` sidecar containing version,
source/output SHA256, source/output lengths, format, fade policy, exact gates,
and either the explicit grid or MIDI SHA256. It declares identity input-frame
mapping. Retain the input remix and its original source-grain sidecar to
preserve the provenance chain. The new sidecar does not replace that mapping
or claim that the source's original beats were known.

All computation and encoding finish before publication. Rejected plans preserve
existing output files. The WAV and JSON writes are not an atomic transaction;
an I/O failure during publication can leave an incomplete pair. Input and
companion sidecar path collisions are rejected.

## Evidence and listening

On 2026-09-14, FPC 3.3.1-20634-gd7f522a561 for i386 Windows passed
`./tools/build.ps1`: 38 standalone core units, WFC integration, both new
tool modes and existing learning/reconstruction smokes.
Log: `build/articulation-validation.log`.

The [focused fixture](../tests/pythian.tests.articulation.lpr) checks independent
tempo-change boundaries, nonzero clock origin, hold/retrigger semantics,
per-sample fades and rests, MIDI overlap/velocity, sub-frame accounting,
ownership, short source rejection and bounded overlapping work.
Final log: `build/articulation-focused-validation.log`.
The final tool rebuild is in `build/articulation-tool-validation.log`.

The recorded-music input is the [joint remix](JOINT.md#verified-evidence)
of the two attributed CC0 corpus recordings. Generate eight seconds with:

```text
pythian.articulate build/corpus/shared-joint.wav build/corpus/shared-articulated.wav grid 500000 240 ahrrahrrahrrahrrahrrahrrahrrahrr
pythian.tests.articulation build/corpus/shared-joint.wav build/corpus/shared-articulated.wav
```

The second command independently checks every decoded stereo PCM sample
against a separately calculated eight-group envelope, without calling the
planner or renderer. It includes 176400 exact rest frames out of 352800
frames at 44100 Hz. Eight gates each sound for half a second followed by
half a second of silence, with 221-frame attack and 441-frame release ramps.
Left/right peak is 0.8571166992/0.7906799316; RMS is
0.1168769440/0.1103007588.

Output SHA256:

`a0f1f636896662e0cfdff8e58aad350a7d8b0ae5d70aa5a06f20dc9f4692e757`

Input SHA256:

`8776a742a772a5414c9b310ee1da5807002a9017314ad3ed3d43a40e9194a9e1`

Replay WAV and metadata bytes match. An invalid `arh` request preserves both.
Logs and metrics: `build/corpus/shared-articulation*.log` and
`build/corpus/shared-articulation-metrics.json`.
The initial external byte-comparison attempt used unsupported forward-slash
paths; repeating the comparison with native paths passed without regeneration.

Operator listening, annotated source beat/onset accuracy, stable FPC 3.2.2
and other platforms remain unverified. These checks establish output timing
and samples, not general musical quality.
