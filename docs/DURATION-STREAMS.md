# Changing durations and future stream edits

`pythian.wfc.duration.stream` combines a finite musical lookahead with the
[native scheduler](SCHEDULING.md). Durations come from an actual learned
pitch/duration model. Independent key and tempo providers cover explicit finite
PPQ partitions. A real WFC harmony/rhythm/voice graph then realizes the selected
spans. The consumer can replace a future window without rebuilding sounding
notes or bus effects.

This is an explicitly staged policy. A transaction solves duration, key and tempo
providers, recalculates cumulative span positions, checks context coverage, and
solves the dependent future ensemble. Failure in a later stage rejects the
transaction; it does not silently choose another duration, invent a context
value, or claim the earlier choice can always be realized. Callers can issue a
new bounded request with different masks or seed.

## Ownership and provider identity

Construct `TDurationStream` with three actual sequence models, explicit key and
tempo boundary vectors, an actual `TWfcMusicVoicesGraphConfig`, ordered unique
role identities, matching immutable instrument bindings, a bus graph, and
`TDurationStreamOptions`. The constructor clones every model. `ModelText` and
`MusicModelText` return their complete current canonical encodings; latent
indices are meaningful only within those exact models. Returned sequence, span
and note vectors are detached copies.

The joint rhythm vector and instrument vector use the declared role order;
`RoleModelIndex('lead')` resolves that identity to its musical mask slot. No
role, scale, tempo, or timing resolution is inferred from display names or
numeric token positions. Models cannot be replaced during a playback epoch.
Provider replacement remains the separate [named voice API](INDEPENDENT-VOICES.md)
contract.

The stream owns its scheduler and model clones. Instruments and any borrowed
source factories must outlive the stream, including release tails. Instrument
parameters remain immutable. The bus is borrowed and its processing belongs
exclusively to this stream until destruction. Callers must not process/reset the
bus concurrently or mutate its topology while the stream is in use.

## One explicit future transaction

`TDurationEdit` contains the current `Revision`, an accepted `FromSpan` boundary,
the desired total `SpanCount`, a seed, regeneration flags, and complete token
mask vectors. Positions are absolute provider cell coordinates. Masks are locks,
not likelihood weights. There is no hidden pending-mask store: the request is a
complete transaction, and an empty future mask deliberately leaves that
provider unconstrained. A mask on a frozen cell must agree with its accepted
emission. Invalid requests raise before publication.

The first request uses revision zero, starts at span zero, regenerates all three
providers and the musical ensemble, and arrives before any samples are
processed. Later pivots are accepted span starts or the accepted finite endpoint;
they must be at or after `NextFrame` when converted through the accepted clock.
The new plan must contain a nonempty suffix after the pivot. Changing the total
span count requires duration regeneration. Truncation to an empty suffix is not
an operation of this API.

Every regenerated suffix starts with the actual accepted predecessor state
from the private plan. The adapter applies real WFC segment boundaries, captures
and independently verifies the solved state paths, and joins the untouched
prefix. Callers cannot inject a predecessor index. `RequireObservedEnd` requests
an observed end for every provider, including retained paths; it does not make a
finite plan extensible or establish future solvability.

Key and tempo boundaries start at zero, strictly increase, and may have unequal
or nonuniform resolutions. A cell that began before the pivot is frozen in its
entirety, even when it straddles the pivot. New cumulative duration must fit both
finite context extents; exact endpoint equality is allowed. There is no padding,
repetition, quantization, or extrapolation. Tempo changes drive `TTempoMap`'s
native integer/rational PPQ conversion, preserving fractional timing through
boundaries.

Known pitch/duration spans require the caller-declared lead role to emit that
single pitch. Explicit unknown and silent spans retain distinct span metadata;
both realize as rests under this consumer's declared policy. They never create
inferred pitches. Known keys constrain new attacks to the declared major or
natural-minor scale. Unknown key explicitly imposes no scale restriction.
Sounding holds retain their original pitches across key changes. The actual
ensemble proof still enforces harmony, joint rhythm, voice ranges, holds,
collective coverage and configured voice-pair restrictions.

`RegenerateMusic=True` explicitly replaces the entire future ensemble. Key or
duration regeneration also re-solves that dependent window. Callers retain
specific future choices by supplying their masks in the complete replacement;
the fixture changes only the named lead's velocity while locking unrelated
musical choices. This operation is distinct from ordinary selective role edits
through `TNamedVoiceSession.TryRegenerate`, whose dependency and unrelated-state
preservation contract remains unchanged. A tempo-only edit retains every
musical token and latent state exactly and only recalculates future gates.

## What commitment protects

`NextFrame` is the next unrendered absolute frame. Successfully emitted samples
are immutable. A replacement retains native note objects whose attacks precede
the pivot, including oscillator/source position, envelopes, automation, release
tails and effect history. Even a pending note before the requested pivot is
protected by this policy.

The adapter builds a complete candidate note ledger before admission. Every
note starting before the pivot must retain exactly the same role, pitch,
velocity, attack, start frame and gate length. If a new tempo, duration or rhythm
would shorten or extend a hold that began before the pivot, the edit returns
`derCommittedNote`. It does not cut, restart, or stretch that note. Choose a
later boundary or issue the change before the note is admitted to the protected
prefix. Notes starting exactly at the pivot remain replaceable.

After all proofs and candidate tone construction succeed, one native
`TScheduledSynth.TryReplaceFuture` admits the replacement. Publication updates
the accepted plan and revision only after that atomic admission succeeds.
Nothing rebuilds the bus or its delay/filter/smoothing state.

## Rejection, limits and terminal failures

`derConflict` means a finite staged solve did not accept the request; it is not
a proof of global unsatisfiability. `derCoverage`, `derCommittedNote`,
`derFrameLimit`, `derVoiceLimit` and `derWorkLimit` identify the corresponding
admission boundary. Every rejection and staging exception preserves the
accepted plan, revision, playback cursor and scheduled future. The caller owns
its rejected request and may revise or discard it.

The current bound is 1..1024 cells per provider, at most 256 latent states per
model, 1..6 named roles (eight musical layers including harmony and rhythm), a
4096-note candidate ledger, finite configured frame extent, and native scheduler
voice/work limits. Sequence and pass backtracking each have explicit finite
limits of at most 65536. These bounds describe admitted work, not a hard real-time
latency guarantee. Generation and editing belong outside a device callback.

A failure inside `Process` is different: the scheduler becomes terminal and may
have advanced internal source/effect state. Caller output parameters and the
reported frame cursor remain unchanged, but retrying that frame is not recovery.
Destroy the stream and failed bus, create a fresh playback epoch, and explicitly
replay the desired musical plan. This API offers no implicit reset or resume.
Likewise, writing already generated samples to an external sink is outside the
transaction; an I/O failure can leave a partial file or consumed external bytes.
Recover the sink separately and replay from an explicitly retained source.

A [saved semantic style](SEMANTIC-STYLES.md) is reusable generation evidence,
not a resumable stream checkpoint. This adapter does not serialize scheduler
objects, effect histories, source lifetimes, cursor ancestry, or continuation
state for later import.

## Focused consumer and verification

`tests/pythian.tests.duration.stream.lpr` is an independent public API caller.
It learns typed models with actual history context, uses 480-tick key cells and
240-tick tempo cells, and schedules two named roles through a live native echo.
It covers sounding-hold rejection for tempo/duration/rhythm edits; explicit
unknown spans; a pivot inside a coarser context cell; exact and exceeded finite
endpoints; named voice and joint rhythm replacements; exact retained musical
states for tempo-only edits; detached results and disposed model owners;
revision, frame, voice and work rejection; and terminal processing recovery.
Twin schedulers compare emitted doubles exactly through failed edits and through
the protected prefix of a successful future edit.

An optional output prefix writes `-baseline.wav` and `-future.wav`, paired stereo
excerpts beginning at absolute frame 4000. Both use the same accepted history and
native effect state; the latter contains the future key/tempo/duration/lead
transaction. Target-local replay is the deterministic comparison; cross-target
floating-point bit identity is not a support claim. Final checked stable FPC 3.2.2
Win32/Win64 QA passed all five task criteria on 2026-09-21. Both first/replay
render pairs and exact native commitment/rollback comparisons pass, with zero
leaks. Evidence and source hashes remain under `build/qa-batch-06/` and
`build/duration-stream/`. Actual listening is unassessed; timing/edit acceptance
does not establish musical quality or recorded-provider accuracy.
