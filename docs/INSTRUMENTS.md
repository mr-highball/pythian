# Pitch and velocity instruments

[Home](../README.md) · [Sources](SOURCES.md) · [Scheduling](SCHEDULING.md) · [Work](WORK.md)

`pythian.instrument` maps a key and velocity to one or more existing synthesis
voices. It adds reusable instrument selection through the existing frame renderer
and exact PPQ note path. Sample zones can use different
recordings/root frequencies; oscillator, FM and wavetable voices work as well.

## Zone and ownership contract

`TInstrument.Create(Zones)` copies 1..256 ordered zone records. Each zone has
inclusive key bounds in 0..127, inclusive velocity bounds in 1..127 and a
`TSynthVoice`. Overlapping zones deliberately layer every match in input order,
with at most 16 layers for any key/velocity pair. Construction checks all range
and overlap limits before retaining the table. Gaps are permitted; requesting an
unmapped note raises `EAudio`. Velocity zero is not a note-on request.

`CopyZones` returns detached records; modifying them does not edit the instrument.
Source factories and automation curves remain borrowed immutable definitions,
following the existing voice contract. Keep those definitions alive through all
planning/rendering/playback. The instrument itself may be freed after planning;
returned frame tones retain copied voice records and the borrowed definitions.

`SelectZones(Key, Velocity)` returns the matching zone indices. `PlanNote(Key,
Velocity, SampleRate, StartFrame, GateFrames, Seed)` returns ordinary `TFrameTones`.
Key maps through the existing 12-tone `MidiFrequency` helper; amplitude velocity
remains `Velocity / 127`. Every layer receives the same exact frame coordinates
and seed, but creates an independent playing source when rendered or scheduled.
Pitch/velocity automation does not reselect zones after admission. A sample's
root frequency and loop policy remain properties of its factory, not its zone.

Before publishing a plan, every selected voice passes the existing frame-tone,
Nyquist, source-step and source-cost admission. Invalid later layers preserve a
previously assigned plan. Rate-dependent voice validity is checked at planning,
not instrument construction. `PlanNote` allocates no source instances or audio
clip. It scans at most 256 zones and returns at most 16 tones. Whole-render and
scheduler capacity/work budgets still apply when the returned batch is consumed.

No automatic normalization, crossfade, voice stealing or random zone selection
is applied. Overlaps sum, so choose per-zone gain deliberately. Continuous
crossfades, round robin groups, serialized instrument banks and sample file-format
import remain separate extensions. This is a modular synthesis building block,
not learned song style or mixed-WAV instrument separation.

## Using the existing renderer and scheduler

Initialize each zone's voice with `DefaultSynthVoice`, assign its source factory,
and set ranges. Plan notes using exact frames from the native PPQ clock or a host
timeline, then render the resulting tones with `RenderFrameTones`.

For an immutable `TNoteSequence`, `pythian.music.render` also accepts a single
`TInstrument` or a dense `TNoteInstruments` table indexed by `TNoteGate.Voice`.
Both `PlanNoteTones` and `RenderNoteSequence` use these overloads. MIDI-imported
and WFC-projected sequences use the same path; track, channel and MIDI program
do not implicitly select instruments. Bind the intended voices explicitly.

Gate endpoints floor independently through the sequence's exact tempo map,
including notes crossing a tempo change. Layers are emitted in source-note order,
then zone order, with the source note index plus one as their shared seed. The
report distinguishes `RenderedNotes` (source gates) from `RenderedTones` (all
expanded layers). Ordinary voice bindings have equal values for these fields.
`SourceNotes` and `SubFrameNotes` retain their existing meanings.

The table accepts 1..4096 entries. Every note must resolve to a non-nil instrument
and a matching zone, even when its gate is omitted as sub-frame. Rate-dependent
voice admission applies to sounding gates. Expansion is capped at 65536 tones;
all layers count toward the limit. Failure preserves a previously assigned plan
and resets the report. Instruments are borrowed during planning only; their
source/automation definitions retain the longer lifetime described above.
Rendering still enforces its whole-clip sample and synthesis-work budgets.

For streaming, `TScheduledSynth.TryReplaceFuture` admits a group-scoped batch
atomically. Use a group whose pending content is intended to be replaced; an
insufficient voice/work allowance rejects all layers. Scheduling layers one by
one instead requires the caller to handle partial admission. The instrument map
does not own scheduler groups, playback state or routing.

## Native audition and evidence

```text
pythian.instrument.demo OUTPUT.wav
```

The demo creates four authored, detached sample regions: soft and brighter
harmonic samples, each with low/high keyboard coverage. It plays the same
eight-note phrase at velocities 48, 72 and 112. The middle pass falls into the
overlap and layers both timbres. Output is 24 notes, 32 playing layers and
180000 stereo frames at 24000 Hz (7.5 seconds). The authored note sequence now
round-trips through the native MIDI writer/reader before instrument rendering.
No external assets are used.

The focused fixture checks inclusive boundaries, velocity splits, gaps, detached
zone records/plans, maximum overlap and failed later-layer admission. Layered
offline PCM exactly matches an independently authored two-tone plan. Scheduler
capacity rejection leaves no partial layer; admitted streaming PCM16 matches
offline PCM16 for the fixture. Float samples differ by at most
`7.4505805969238281E-9`: offline accumulates into Single per voice, while the bus
accumulates Double before conversion. This is not a general float-bit-parity claim.

Checked builds and the audition pass on FPC 3.2.2 and 3.3.1 i386-win32, using
`-B -Sa -Cr -Co -Ci -gl -Fusrc` and separate output directories. Logs are
`build/instrument-{stable,trunk}/checked-{build,test,demo}.log`; demo compilation
is also recorded in each `final-build.log`. Both audition WAVs are compared in
`build/instrument-replay.log`. The standard build now includes the fixture and
audition. No additional platform, listener approval or refreshed package/full-suite
claim follows from this focused change.

The sequence integration additionally checks an independently timed layered PCM
reference across a fractional-microsecond tempo map, omitted sub-frame gates,
missing later bindings/zones, report reset and preserved plans. Exactly 65536
expanded tones are accepted; a further 16-layer note rejects. Existing native
note/MIDI fixtures and the public note example retain their previous output.
Focused checked builds run on both compilers under
`build/instrument-sequence-{stable,trunk}/`; the upgraded audition retains the
same WAV bytes as the earlier direct-frame audition. The extended report is a
source-level API change: rebuild consumers using `TNoteRenderReport`. All current
callers rebuild on both compilers; actual WFC projection/clock/codec fixtures and
the four-pass layer audition also pass. Replay is recorded in
`build/instrument-sequence-replay.log`. This remains focused integration evidence,
not a refreshed source package or full-suite run.

The subsequent [source-package refresh](PACKAGING.md#current-source-packages)
includes the instrument APIs and a small standalone keyboard/velocity consumer,
verified from extracted sources on both compilers.

## Measured-instrument quality checkpoint — 2026-09-19

The native study exercises saved stationary timbre through the actual companion
`TStyleInstrument`, `PlanNote` and core `TFrameToneStream`. Three profiles supply
24, 16 and 24 harmonics: two measured notes and a derived blend. Only their timbre
is bound; the envelope is authored so its reference can be calculated independently.
This supplies scoped evidence to [FUND-QUALITY](MILESTONES.md#fund-quality).

The fixed workload contains 252 static conditions: three profiles, rates 8000,
16000, 44100 and 48000 Hz, sampled MIDI keys 36, 48, 60, 69, 72, 84 and 96, and
velocities 32, 80 and 127. Twelve additional conditions sweep 440 to 1760 Hz
linearly over an eighth of a second, then hold. All use quarter-second gates,
5-ms attack, unity sustain, 30-ms release, gain 0.2, pan -0.35 and a one-pole
cutoff of 0.4 times the sample rate. This samples a declared range; it does not
establish quality at every intermediate key or automatically infer an instrument's
supported range.

The independent reference evaluates the public harmonic recipe directly, without
reading the renderer's tables. Each harmonic uses the documented attenuation
`clamp(rate / (2 * frequency * cap) - 1, 0, 1)`, where `cap` is the smallest
power of two containing it. Separate phase, filter, envelope, gain and pan
calculations cover static notes and glides across harmonic-bank transitions.
Acceptance requires finite output, exact gate/release frame count, peak below 1,
relative RMS residual at most 0.001, and pointwise error within the analytic
2048-sample linear-interpolation bound plus 2e-7 float allowance. A deliberately
added high-frequency sinusoid must exceed that same bound. This negative control
checks sensitivity; it is not a general spectral-aliasing acceptance test.

All **264 conditions pass** on checked FPC 3.2.2 Win64, 3.2.2 Win32 and 3.3.1
Win32. Worst absolute reference error is 6.218e-7; worst relative RMS residual
is 1.303e-5 (about 0.001303%). Maximum output magnitude is 0.034132 at the declared
gain, with one active voice and peak logical frame work 20. For key 69/velocity 80
at each profile/rate, reads of 127 and 2048 frames give identical Single samples.
That read-size comparison covers twelve selected static cases.

Each target saves twelve 6.72-second static auditions and twelve glide auditions.
The native summary recomputes every WAV hash and confirms all 24 files are
byte-identical across targets. Profile identities, individual measurements and
audition hashes are in `measured.json`; reports and logs remain ignored under
`build/instrument-quality-{study,stable,trunk}/`. The checked compiler flags are
`-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools -Fuadapters/wfc -Fuvendor/wfc/src`, with
separate executable/unit directories. Existing WFC/FPC generics warnings remain;
these were not warning-free builds.

The experimental Pascal source is `build/instrument-quality-study/quality.lpr`.
Its command is `quality OUTPUT_PREFIX STYLE.pys [STYLE.pys ...]`; this workload
uses `timbre-bassoon-c.pys`, `timbre-bassoon-a.pys` and `envelope-reblend.pys` from
`build/recorded-pitch-3.2.2-i386-win32/`, in that order. The separate native
`summary.lpr` takes the three output prefixes, with the Win64 prefix first,
checks saved report counts/source identities and verifies audio hashes/replay.
These are local experimental artifacts, not a maintained public consumer.

Remaining acceptance includes measured-envelope retiming and note-length changes,
overlapping layers and headroom, sample-loop transitions, broader modulation
bandwidth, declared workload limits and listening. No listener approval, timbral
realism, general genre learning, Linux run or current-package acceptance follows.
The following checkpoint supplies measured-envelope and overlapping-layer evidence
on this same instrument path; the [backlog](MILESTONES.md#fund-quality) retains the
larger quality gate and its downstream integration link.

## Measured-envelope and layer checkpoint — 2026-09-19

Three saved profiles (two measured notes and a further blend) now bind both timbre
and envelope through `TStyleInstrument`. The study covers rates 8000, 22050 and
48000 Hz; gates of one frame, floor(rate/40) frames and two seconds; and 1, 2 or
16 overlapping zones per note. Each case plays MIDI 60/velocity 80 followed by
MIDI 67/velocity 127 at floor(gate/2)+1 frames, with natural release overlap.
Zone gain is 0.15, pans span -0.6 to +0.6 (the single zone uses -0.6), and cutoff
is 0.4 times rate. This is **81 conditions per target**, reaching 32 simultaneous
voices; the harness limits each case to six seconds.

The reference reads each profile's retained RMS points, source rate and envelope
weights. It independently interpolates the source gate level, floors absolute
coordinates, normalizes held and release levels, and evaluates their weighted
means separately. After note-off, the weighted held value at the actual gate
multiplies the weighted release value. No renderer envelope or automation
evaluation supplies the expected curve. Thus short gates, held extension, source
rate conversion, different tail lengths and derived blends are exercised without
stretching the source's attack to fit each note.

Every rendered envelope sample agrees within 3.34e-16 across the tested targets
(limit 1e-12). Direct harmonic/filter references independently supply both note
signals; authored velocity, pan and gain then sum their overlapping contributions.
Worst audio reference error is 9.007e-6, within the declared interpolation bound;
worst relative RMS residual is 1.287e-5 (limit 0.001). Normal-workload peak is
0.511408, with maximum logical frame work 1664. Gate/tail extents and simultaneous
voice counts match the independently expected geometry. Reducing the voice or
work reservation below the measured requirement rejects every case. Reads of
127 and 2048 frames replay identical Single samples for all 27 cases using
16 zones; this is selected read-size coverage, not every possible workload.

All 81 conditions pass on checked FPC 3.2.2 Win64, 3.2.2 Win32 and 3.3.1 Win32.
Each target saves nine auditions of the two-zone cases. A native audit checks
report counts/profile identities and recomputes their hashes: all nine WAVs are
byte-identical across targets. The source is
`build/instrument-envelope-study/envelope.lpr`, invoked as
`envelope OUTPUT_PREFIX PROFILE1.pys PROFILE2.pys PROFILE3.pys`. Inputs, in order,
are `envelope-bassoon-c.pys`, `envelope-bassoon-a.pys` and `envelope-reblend.pys`
under `build/recorded-pitch-3.2.2-i386-win32/`. Reports, hashes, auditions and
checked build/run logs are under `build/instrument-envelope-{study,stable,trunk}/`;
the separate `summary.lpr` takes their three `measured` prefixes. Compiler flags
match the preceding checkpoint; existing dependency warnings remain.

A deliberate overload raises zone gain to 1 in the first profile's 48-kHz,
two-second, 16-zone case. Float peak reaches 3.409381 and retains the expected
gain scaling. Encoding that clip saturates 57590 scalar samples above unity,
as the low-level PCM16 contract specifies. This exposed a missing operator guard:
the maintained instrument consumer previously exported a valid 64-note input
with peak 1.277590 and no rejection. A second, 128-note probe has individually
safe bass/chord peaks 0.804781/0.458915 but a mixed peak 1.263696.

The [instrument consumer](WAVE-STYLE.md#independent-measured-instruments) now
rejects overload before replacing accepted outputs and accepts a common explicit
`--output-gain 0..1`. Gain 0.5 admits the latter probe at peak 0.631848, preserving
MIDI and role balance. Native operator checks on all three targets verify early
stem and late mix rejection, preservation of all six existing outputs, staging
cleanup, invalid/repeated option rejection and 127/2048-frame replay in either
option order. Default safe output retains its prior PCM. The four attenuated
WAV hashes also match across targets. Evidence and native input/check programs
are under `build/instrument-headroom-{study,stable,trunk}/`.

The changed consumer additionally renders the existing 88-note, 791022-frame
measured performance on stable Win64. The existing replay verifier finds zero
PCM difference across mix and stems, retaining notes and instrument bindings.
This verifies the changed measured listening path; it is not listener approval.

These results clear scoped envelope/layer and operator headroom checks in
[FUND-QUALITY](MILESTONES.md#fund-quality). They do not close sample-loop joins,
arbitrary modulation bandwidth, general instrument realism or listening acceptance.
Next exercise loop and modulation transitions through the same integrated path,
with explicit input/range limits and audible evidence. No separate percentage
credit, Linux result, refreshed package or general style-quality claim follows.

## Later bounded listener acceptance — 2026-09-23

The user heard the complete [8/48-kHz measured-profile and envelope packet](SYNTHESIS-QUALITY.md#measured-profile-range-listening-packet--2026-09-23)
and said all four clips sounded good. Its three profile windows at each rate
cover the sampled seven-key/three-velocity sequences, short pitch glides and
the authored short/long-gate envelope examples. No fault time was reported in
response to a prompt naming clicks, rough pitch changes, unwanted noise and
cut-off endings. The [source-quality acceptance](TODO/DONE/NS-2_synthesis-quality_01.md)
is bounded to those audible examples and the separate numerical/replay ranges
above; the 16/44.1-kHz static/glide and 22.05-kHz envelope files have no
distinct listener verdict. Instrument realism and arbitrary settings remain
unsupported.
