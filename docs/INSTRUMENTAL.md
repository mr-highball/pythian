# Instrumental musical WFC runtime

[Home](../README.md) · [Goal](GOAL.md) · [Tasks](TODO/README.md) ·
[Named voices](INDEPENDENT-VOICES.md) · [Instruments](INSTRUMENTS.md)

## What this provides

The shared [instrumental adapter](../adapters/wfc/pythian.wfc.instrumental.pas)
connects actual named musical WFC passes to the primary note projector, instrument
planner, buses and scheduler. A successful plan has distinct parts, native notes
and source-free or explicitly bound instrument tones. Optional
[unpitched percussion](PERCUSSION.md) uses a separate rhythm-dependent graph group
and the same native performance. It never selects recorded
training-mix grains or silently substitutes a different renderer.

Studio now offers this finite runtime with explicit percussion as its primary
**Synthesized instruments · Experimental** route. Save an instrumental project
without recordings, choose tempo/key/bars/seed and sounds, then Check setup and
Generate instruments. Jobs provides the mix, six synchronized parts with
mute/solo, actual graph details and a listening-feedback link. The host keeps
working when the page closes; saving feedback never silently regenerates.
No recording-derived style learning or musical-quality claim follows from the
authored starter. Deeper graph editing, sound design and long instrumental
streams retain their linked [tasks](TODO/README.md).

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

The plan owns cloned models/session state, detached pitched notes and accepted
percussion recipes. CopyGraph returns
actual pass dimensions, proof flags, model token/state counts and dependency
indices. CopyProvider, CopyModel, CopyMusic, CopyConstraints, CopyPreferences and
CopyNotes expose detached accepted pitched data. CopyPercussionHits/Part describe
unpitched events/recipes; CopyPassTokens/States and CopyModel cover every group.
Copies of part tones still borrow native
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

An optional TPitchPattern supplies an operator-selected motif for bass, harmony
or lead. The primary pythian.music.pattern unit can quantize selected-channel pitch
spans onto explicit eighth-note cells; callers can also author or correct cells.
Unknown cells split examples and remain distinct from measured silence. The
starter explicitly repeats each known run four times to teach repeatable motifs,
with authored accompaniment. Those repetitions and accompaniment are authored
material, not observations of a recording or continuity across missing material.
AMinor selects the starter's minor accompaniment; it does not infer a key.

For this motif path, pass the starter's borrowed ContextModel as the final
TryCreateInstrumentalPlan argument. The shared musical-context provider learns
paired harmonic/rhythmic choices and their sequence relationships. It first
solves one actual context pass, preserving caller harmony/rhythm masks and soft
preferences. Accepted paired choices then constrain the named musical graph;
pitched roles remain independently selected. A contradictory lock fails rather
than being relaxed. ContextSolve reports the context negotiation separately.

CopyGraph exposes this additional graph group and its pinned-input lineage:
context group 0, pitched group 1 and optional percussion group 2. The sixteen-cell
C/unknown/silence/D fixture with drums has seventeen actual passes, each 16 x 1 x 1.
This is conditional generation, without backtracking across groups. A context
choice can still leave the following graph unsatisfiable; failures remain visible.
The ordinary Studio route does not yet expose these motif choices.

The caller adds the primary filtered echo on the harmony bus and a three-second
effect tail. Changing tonic changes actual training/model pitches; changing BPM
changes the exact performance clock. A seed or supported constraint may produce
different valid voice paths, but a different seed is not a guarantee of variation.

Without a motif, adding --drums as the sixth argument creates kick, snare and hat from authored
velocity-event models and explicit rhythm projections. The result has a second
four-pass graph group, and sixteen actual passes total. It retains pitched
harmonic proof and adds the primary master limiter. Graph groups and pinned-input
lineage are explicit; this does not claim one jointly backtracking graph.
The sixth and seventh arguments may also include --motif=60,?,r,62: MIDI note
numbers, ? for unknown and r for rest. Each entered note is an explicit attack.
For example, append '--drums' '--motif=60,?,r,62' to a sixteen-cell invocation.
The sidecar records the actual context model, seed, tokens and conditional groups.

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
