# Instrumental musical WFC runtime

[Home](../README.md) · [Goal](GOAL.md) · [Tasks](TODO/README.md) ·
[Named voices](INDEPENDENT-VOICES.md) · [Instruments](INSTRUMENTS.md)

## What this provides

The shared [instrumental adapter](../adapters/wfc/pythian.wfc.instrumental.pas)
connects actual named musical WFC passes to the primary note projector, instrument
planner, buses and scheduler. A successful plan has distinct parts, native notes
and source-free or explicitly bound instrument tones. It never selects recorded
training-mix grains or silently substitutes a different renderer.

This is the finite runtime foundation. Ordinary Studio generation has not yet
been wired to it; explicit drum semantics and Studio controls remain separate
tasks. No recording-derived style learning or musical-quality claim follows from
the authored starter.

## Public API and ownership

Call TryCreateInstrumentalPlan with an actual TWfcMusicVoicesGraphConfig, ordered
role/instrument/bus bindings, session options, explicit PPQ tempo changes and
material origin. Masks and preferences use harmony, rhythm, then declared role
order. They retain the named session's hard/soft distinction.

The function constructs a private named session, projects WFC attack/hold/rest
frames through the shared music adapter without whole-bar padding, and plans
each part using TInstrument and PlanNoteTones. A false solve returns its original
negotiation/proof report and failing pass. Bad inputs, resource rejection or
observer cancellation raise before replacing the previous plan. Success replaces
and frees the previous plan only after all planning/ready callbacks.

The plan owns cloned models/session state and detached notes. CopyGraph returns
actual pass dimensions, proof flags, model token/state counts and dependency
indices. CopyProvider, CopyModel, CopyMusic, CopyConstraints, CopyPreferences and
CopyNotes expose detached accepted data. Copies of part tones still borrow native
factory/automation/envelope resources; preserve those resources through player
creation, and preserve source factories for their own source lifetime.
RoleAt returns metadata with Instrument=nil after planning, not a dangling pointer.

CreatePlayer takes a healthy matching-rate bus graph and returns a new owned
TScheduledSynth. Every note is admitted before return; rejected construction
disposes its private scheduler without processing/resetting the bus graph.
The player exclusively borrows that graph. Role indices are scheduler groups;
explicit role bus indices let callers mute/solo and route through existing bus
controls. Use a fresh graph for replay or simultaneous playback.

The finite plan currently admits at most 4096 scheduled tones. Its PCM storage
does not grow with output duration: consume Process frames or bounded
RenderScheduledFrames blocks. This is not yet indefinite musical lookahead.
FrameCount includes the exact musical extent, the longest remaining native
note release, and the caller's explicit effect-tail frames. Effect decay cannot
be inferred automatically. Unexpected processing failure follows the existing
scheduler's Reset/new-epoch policy.

## Maintained source-free caller

The [public example](../examples/pythian.example.instrumental.lpr) writes stereo
PCM16 WAV through the primary streaming writer, plus a JSON graph/model/token
sidecar. It accepts output path, cells, seed, BPM and tonic pitch class.

The reusable [authored starter](../adapters/wfc/pythian.wfc.instrumental.starter.pas)
provides two symbolic training phrases, saw bass, triangle harmony and square
lead with native ADSR/filter/pan. Its harmony/rhythm guide is explicitly authored;
WFC selects compatible pitched parts through five provider passes. Exact harmony
adds seven coverage proof passes. Default execution is twelve 64 x 1 x 1 passes:
harmony, joint rhythm, three voices and seven witnesses. These are passes against
one time axis, not twelve musical dimensions.

The caller adds the primary filtered echo on the harmony bus and a three-second
effect tail. Changing tonic changes actual training/model pitches; changing BPM
changes the exact performance clock. A seed or supported constraint may produce
different valid voice paths, but a different seed is not a guarantee of variation.

Compile from the repository root with the existing FPC toolchain, choosing
explicit E-drive unit/executable output folders on this workstation:

~~~powershell
$build = 'E:/CodexWork/pythian/build/instrumental-example'
New-Item -ItemType Directory -Force "$build/units" | Out-Null
fpc -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src "-FU$build/units" "-FE$build" examples/pythian.example.instrumental.lpr
& "$build/pythian.example.instrumental.exe" "$build/music.wav" 64 731 120 0
~~~

No source recording, private catalog, playback device or service is needed.
Opening the WAV is explicit; running the example does not start audio.
Unsupported/unlucky graph requests return an actionable failure rather than
silently relaxing constraints. The maintained fixture checks real graph/note
controls, deterministic replay, exact changing-tempo timing, release tails,
borrowed callback cancellation and preservation of a previously accepted plan.
