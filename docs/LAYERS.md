# Coupled learned layers

[Home](../README.md) · [Provenance](PROVENANCE.md) ·
[Joint WAV learning](JOINT.md) · [Work](WORK.md)

[pythian.wfc.layers](../adapters/wfc/pythian.wfc.layers.pas) exposes the reusable
negotiated-pass mechanism used by Phanes's musical generator. A consumer can
require several earlier layers simultaneously, retaining observed combinations
and temporal relationships. Independent allowed-token lists cannot express the
same correlation: admitting C and F in one lane and E and A in another would
also admit F:E, even when only C:E and F:A were observed.

The [layered style direction](LAYERED-STYLE.md) extends this mechanism toward
key/tempo context, higher voice parts and reusable per-layer style composition.
The adapter below remains token-level; saved context and style semantics live in
their companion adapters.

## Contract

`TryGenerateLayers` accepts caller-owned, immutable actual WFC sequence models,
per-layer token/position constraints and complete projection rules. It returns
detached public tokens and latent state indices for each layer. Learning remains
with the existing WFC contract; this adapter contains no separate solver or learner.
The models may represent symbolic voices, measured WAV classes or other caller
vocabularies. The adapter does not reinterpret their tokens as notes.

Layers are supplied in dependency order. Each projection names one earlier
provider and one later consumer. Its rules cover every consumer public token
exactly once; alternatives within a rule are OR choices. Distinct providers are
conjunctive. Duplicate provider/consumer edges reject because the same-provider
OR semantics must not be mistaken for independent AND constraints.

The adapter creates private WFC overlay passes, applies model and position
constraints, installs each consumer's projection bundle, and invokes the actual
negotiated solver. Before publication it validates every latent path, every
position constraint and the captured public-token relationship at every cell.
No caller request, model or prior output is mutated. `False` and exceptions leave
the previous output intact. The actual report distinguishes contradiction,
within-pass backtrack exhaustion and provider-retry exhaustion.

Bounds are 1..8 layers, 1..1024 cells per layer, 262144 combined state/cell combinations,
28 projection edges, 4096 rules and 16384 source alternatives. The sum of
consumer states times provider states times cells is bounded at 16777216.
Per-pass backtracks allow 0..65536 and provider retries 0..1024. Defaults are 32
cells, seed 731, fragment extent, 512 backtracks and 64 provider retries.
All actual WFC extents are available; whole paths require observed endpoints.
Budgets bound declared work/search, not device deadlines or guaranteed solvability.

## Generation preferences

`TLearnedLayer.Preferences` supplies positive public-token choice multipliers,
separately from learned observation counts and hard position masks. Construct an
entry with `MakeLayerTokenPreference(Token, Multiplier)`. Omitted tokens have
multiplier 1; an empty list preserves the existing solve behavior. Each latent
state's choice weight is its learned count times its token's multiplier. This
changes WFC weighted selection and entropy ordering; it does not promise an exact
output proportion or override temporal compatibility, projections or locks.

For example, `MakeLayerTokenPreference('high', 16)` favors an already learned
`high` token over unlisted alternatives. To express relative suppression, raise
the other alternatives' multipliers. Zero is invalid: use a hard mask to exclude
a token. Preferences are per layer for its whole requested scope, not per cell.
Only choices still available to that pass can respond; a consumer preference
does not instruct negotiation to reopen a compatible provider merely to improve
the preference. There is no global aesthetic objective or new solver.

Named sessions own a detached copy. `SetPreferences(Name, List)` replaces the
complete pending list and marks that layer dirty. Selective regeneration includes
dirty layers and their dependents, preserving unrelated accepted tokens/states.
`CopyPreferences(Name)` returns a detached copy of the current requested settings,
including pending edits; it is not an accepted-output snapshot. Invalid edits
preserve the prior request. A failed solve preserves accepted output and pending
edits. Model replacement retains the list and rejects unknown tokens or excessive
weights against the candidate model before publication.

Limits are 1024 entries per layer, unique known tokens, multipliers 1..1024 and
a raw effective graph-weight sum no larger than signed 32-bit maximum per pass.
The sum includes position copies for fixed partitions. This conservative bound
can reject weights that a later common-divisor normalization could reduce.
Preference preparation has a separate aggregate limit of 16777216 work units:
ordinary passes charge `states² × (order + 1) × (public tokens + 1)` for public
domain resolution; position-compiled passes charge `states × cells × preferences`.
Existing graph and projection bounds also apply. No token is silently ignored,
weight rounded or budget raised.

Weights change only inside the private synchronous solve. All graph keys are
resolved before mutation, using WFC's public token-domain API or the owned
position compiler. A scoped owner restores original weights on success, failure
and exception, before sequence capture or later domain edits. Learned models,
observations and their serialized identities never change. Replay requires the
same models, ordered settings, masks, timing, seeds and solver/API versions.
`LearnedLayersVersion = 4` identifies this API behavior; it adds no saved-format
version or historical reader. [Saved style preferences](WAVE-STYLE.md#saved-generation-preferences)
now retain supported settings through reload and repeated blends. General role
controls remain under [WFC-LAYERS](MILESTONES.md#wfc-layers).

### Preference checkpoint — 2026-09-20

Checked stable Win32/Win64 and development Win32 pass the expanded existing layer
fixture. A fixed 32-seed × eight-cell panel increases the favored token from
120 to 237 of 256 choices with multiplier 16, identically for ordinary and fixed
partition graphs on all three targets. The independent key layer stays exact;
dependent articulation respects its projection. Controls cover transcript/state
replay, uniform scaling, detached ownership, hard locks, dirty dependency closure,
invalid edits, contradiction/recovery, replacement, clearing, overflow and the
public-domain preparation bound. All runs terminate with zero reported leaks;
existing WFC/RTL compiler warnings remain, with none from changed owned code.
All seven other direct tool/fixture callers rebuild on stable Win64, including
the public performance adapter through its consumers. Context-profile and saved
WAV-style regressions pass with zero reported leaks; these use empty preferences
and do not establish saved semantic preference persistence.

The maintained listening demo accepts an optional layer/token multiplier and
records it beside each unchanged model in its current JSON report. Checked stable
Win64 runs with seed 731 preserve the default WAV's existing hash. Applying
`pairs 48:64 16` changes the generated audio; its WAV and JSON replay exactly.
Both versions contain 64 notes / 706482 stereo frames. The preferred WAV's SHA256
is `1af3c11e80238e4f124a2b4eb1aa2f54cd706b8945a7cf629b6ac811fd6042d9`.
This demonstrates control through native rendering, not listening acceptance or
WAV-derived semantic preference learning.

Evidence is ignored under `build/layer-preferences/{stable,trunk,win64,consumer}/`.
Build the layer fixture with `-B -Sa -Cr -Co -Ci -gl -gh`, core/adapter/WFC search
paths and isolated output directories; run it with that directory as the optional
audition path. The demo additionally uses the tools search path. No package
refresh, remote CI or saved-style migration is claimed.

## Per-layer scopes

An empty `TLayerGenerationOptions.Scopes` uses the shared `CellCount` and
`Extent` defaults. Otherwise supply exactly one `TLayerScope` per layer with
`MakeLayerScope(CellCount, Extent)`; the shared defaults are then unused.
`ResolveLayerScope` returns the validated effective scope. Each scope permits
1..1024 cells and the actual WFC whole/prefix/suffix/fragment/wrap extents.

The adapter configures actual WFC pass layouts before applying models and masks.
Cell counts, neighbor wrapping and endpoint constraints belong to each pass.
Capture validates each path against that pass's own extent. Sessions copy the
scope array; later caller edits cannot change the session. Positional masks are
bounded by their target layer, and selective regeneration preserves independent
accepted passes even when their lengths differ.

The combined state/cell budget is the sum of each model's state count times its
own cell count. Default positional projections require identical provider/consumer
layouts and reject unequal scopes before graph construction. Separate pass lengths
do not imply musical-time alignment, broadcasting or resampling. Use the explicit
tick-grid or fixed-partition contracts below for relationships between resolutions.

The [held-context operator](PITCH.md#saved-duration-styles) uses one actual prefix
state for each single-valued saved key/tempo model, holding those output decisions
across independently sized performance spans. No model rewriting or repeated
source observations are used. Changing values reject; unknown key stays unknown.

The existing layer fixture now also checks 1/3/6-cell prefix/whole/wrapped passes,
owned scope arrays, a mask at the longest layer's final cell, selective preservation,
short-layer mask rejection and unequal-projection rejection. Both checked FPC
versions pass on i386-win32; see `build/held-context-{stable,trunk}/workflow.log`.

## Explicit musical-time mappings

Set `Options.TimeGrids` to one `MakeLayerTimeGrid(OriginTick, TicksPerCell)` per
layer. All grids use a caller-declared common integer tick unit, such as ticks at
480 PPQ. Each cell covers `[origin + index × step, origin + (index + 1) × step)`.
Steps are positive; origins and exclusive endpoints must fit signed 32-bit
integers, matching the actual WFC lattice contract. Names, scopes and grids are
copied by a session and remain fixed for its lifetime.

Choose each projection's `TimeMapping` explicitly:

| Mapping | Relationship |
| --- | --- |
| `ltmCellIndex` (default) | Same-position tokens on identical layouts. It does not infer time from different cell counts. |
| `ltmStartTick` | Sample the provider cell containing the consumer's start tick. Later provider changes during that consumer cell do not constrain it. |
| `ltmWholeCell` | Every distinct provider cell overlapped by the consumer's full duration must admit the consumer token. Different provider tokens can each match a declared alternative. |

For example, key, rhythm, harmony and voice passes can have 1/4/2/8 cells with
1920/480/960/240 ticks per cell. Key can constrain complete harmony spans; harmony
can constrain voice attacks while rhythm constrains each complete voice cell.
The models retain their original observations and latent histories. Multiple
providers remain conjunctive, and public-token rules still cover every consumer
token exactly once with nonempty, known, distinct provider alternatives.

Mapped relationships require explicit grids for every layer. Missing bounded
coverage rejects before graph construction; the provider's exclusive endpoint is
outside a start-tick query. A start-tick relationship permits a consumer gate to
outlive that sampled context, so use whole-cell coverage when the context must
hold throughout. A provider with explicit `wseWrap` repeats its declared grid;
whole-cell coverage checks each distinct overlapped provider cell once even across
multiple periods. There is no implicit wrapping, extrapolation or stretching.

For uniform grids, the adapter resolves latent graph values through the public sequence-domain API,
then installs actual WFC `RequireMappedFromPass` point or cell-coverage clauses.
No private key encoding, parallel solver or additional hidden pass is used.
Captured tokens are checked against every required provider cell before publication.
The projection-work bound includes all overlapped provider/consumer cell pairs.
Mapped preparation additionally bounds the sum, over participating models, of
`states² × (order + 1) × (public tokens + 1)` at 16777216. This conservatively limits
the public API's repeated model-validation scans; it is not a device time budget.

Unequal fixed intervals use the partition contract below. Changing a time plan
within a session and automatic alignment of WAV frames to musical ticks remain
separate work. Neither representation estimates BPM or retimes source audio.

## Fixed time partitions

`MakeLayerTimePartition([0, 120, 480, 1200])` describes three contiguous cells
of 120, 360 and 720 ticks. Use it in `Options.TimeGrids`, alongside uniform grids
if needed. Every partition has exactly `CellCount + 1` strictly increasing signed
32-bit boundaries. `OriginTick` and `TicksPerCell` must both be zero when boundaries
are present. The helper copies its input; a session also copies each nested
boundary array. Models, boundaries, scopes and relations remain fixed for that
session except for the existing compatible model-replacement operation.

Providers and consumers can both have unequal intervals. Start-tick and whole-cell
queries retain the half-open semantics above; index mapping requires identical
effective boundaries and wrapping, even for different timing representations.
A wrapped provider repeats its entire partition, including unequal cell widths.
Whole-span queries check every distinct overlapped cell, including the seam and
spans covering multiple periods. Arithmetic uses Int64 intermediates. There are
no gaps or overlapping cells; represent a rest as an explicit cell/token.

If any layer has a partition, the adapter compiles every layer's position/state
pairs into its own graph values. Each carries the original state's observation
weight, history compatibility and extent restrictions. Real mapped WFC point
requirements bind each occurrence to its actual provider cells during solving;
capture decodes original state indices and validates the original learned path,
mask and all provider relationships before publication. There is no relearning,
synthetic repetition of source evidence, dependency-source edit or commit filter.
Uniform-only requests keep their existing implementation.

The expanded representation has additional conservative preflight bounds:

| Resource | Limit |
| --- | ---: |
| Position/state values per layer (`V = cells × states`) | 1024 |
| Aggregate reference relation/domain arrays (`sum(12 × V² + cells × V)`) | 16777216 bytes |
| Aggregate declared position preparation work | 16777216 units |
| Aggregate mapped state/cell requirement clauses | 65536 |
| Aggregate provider-state × consumer-state × covered-cell pairs | 1048576 |

Preparation includes adjacency/history scans, relation-array work and rule matching.
Coverage scans also retain the 16777216 mapping-preparation bound. Limits reject
before graph construction and model cloning. The matrix estimate excludes graph
objects, strings, models, search state and other storage; it is not a process-memory
ceiling. Transactional model replacement can hold the old and candidate bounded
graphs concurrently. Larger corpora may need a more compact representation or
explicit hierarchical planning rather than raising these limits silently.

Named masks, dirty-provider inclusion, selective regeneration and compatible
replacement all use this path. Rejection retains accepted results and pending
edits. API version 3 introduced this behavior; the current version also includes
[generation preferences](#generation-preferences). These are API identifiers;
no saved artifact format or historical reader is added.

### Partition checkpoint — 2026-09-20

The existing layer fixture passes checked stable Win32/Win64 and development
Win32, all with zero reported leaks. It covers mixed uniform/partition layers,
unequal provider/consumer intervals, conjunctive providers, detached boundaries,
selective edits, replacement/replay/failure recovery, half-open endpoints, wrap
seams, signed extremes and resource rejection. Forty order-three requests compare
feasibility with the original sequence adapter across all five extents and 1..8
cells. Expanded-value replacement, aggregate matrix and mapped-clause failures
preserve output; pending edits remain usable.

Four new 32000-frame stereo WAVs at 16 kHz exercise unequal event timing before
and after a key-only edit. Dependent voice bytes change; the independent rhythm
stem is identical. All twelve fixture WAVs match across the three targets, and
the eight existing WAVs retain their preceding hashes. Stable Win64 also passes
the saved-style fixture and the recorded held-context public performance fixture.
Sources, logs and hash evidence are under ignored `build/layer-partitions/`.
Listening remains unassessed; these are authored controls, not learned voice roles.

This completes fixed-plan timing support, not WFC-LAYERS as a whole. Durations
selected during the same solve still require a cumulative-time or staged-planning
contract. Semantic provider registration, persistence and recorded integration
remain in [WFC-LAYERS](MILESTONES.md#wfc-layers).

### Mapped-layer checkpoint — 2026-09-20

Checked stable Win32/Win64 and development Win32 runs pass with no reported leaks
under `build/layer-time-map-{stable,win64,trunk}/`. The existing layer fixture covers
the 1/4/2/8-cell graph, mixed mapped/index relationships, actual dependency closure,
model replacement, detached grids, negative origins, partial coverage, half-open
endpoints, wrapped periods, contradictions and preparation limits. It compares the
result with independently specified harmony/rhythm token expectations.

This check also exposed an earlier dependency error: changing WFC's default pass
mode to overlay retains the default predecessor edge as a declaration. The adapter
now clears those edges **before** installing its declared projection relationships.
An independent later rhythm pass therefore stays outside a key edit's scope.
The no-grid session fixture now checks this exact scope too. `LearnedLayersVersion`
was raised to 2 to identify the corrected dependency behavior; no artifact format or historical
reader was added.

Optional fixture output includes two-second `mapped-voice-before.wav` and
`mapped-voice-after.wav` auditions plus `mapped-rhythm-before.wav` and
`mapped-rhythm-after.wav`. The key edit changes sounding pitches while the
independent rhythm stem stays byte-identical. These are authored controls, not
WAV-learned voice roles or listening-quality acceptance. The existing saved-style
fixture passes, and the original four-layer demo retains its recorded WAV hash.

## Nonuniform event-time feasibility — 2026-09-20

This rejected prototype predates the maintained [fixed partitions](#fixed-time-partitions).

The concrete consumer is a phrase whose event durations repeat 120, 360, 720 and
120 ticks while key context changes every 960 ticks. At 480 PPQ, each note uses
the key at its attack and keeps that pitch through later changes. This is a
declared musical policy, useful for a voice following an accepted duration plan;
neither the durations nor the key labels in this study are inferred from WAV.

The pinned companion's `TWfcLatticeLayout` has one origin and pitch per axis.
Its `RequireMappedFromPass` queries apply to a value's rule group, with offsets
relative to that uniform cell. They do not directly assign a different span or
query to each occurrence of the same value. The actual `DoValidateCommit` hook
can reject a complete candidate, but supplies no such relation to the earlier
domain filtering. Source inspection is backed by the bounded experiment below.

An ignored native prototype uses the real sequence learner, two actual dependent
passes and negotiated solving. Its commit hook captures validated public tokens
and checks each voice attack against its provider interval. It introduces no
private latent-key codec, parallel solver or dependency-source change. The fixed
policy requires all 15 requests to solve: 8/16/32 events at seeds 731, 211, 918,
17 and 42, with 512 within-pass backtracks and 64 pass retries throughout.

| Events | Uniform 330-tick control | Unequal-duration commit filter |
| ---: | --- | --- |
| 8 | 5/5 solved, zero retries | 2/5 solved, at 32 and 52 retries; three retry-limit failures |
| 16 | 5/5 solved, zero retries | 0/5 solved; five retry-limit failures |
| 32 | 5/5 solved, zero retries | 0/5 solved; five retry-limit failures |

The two schedules use their own independently calculated attack-time oracles;
they are mechanism controls, not an assertion that the musical schedules match.
All 13 failed unequal requests reach 64 retries/65 full candidate checks. These
are budget failures, not proofs that the requested relations are contradictory.
The first successful free case replays its exact tokens, latent states and
negotiation transcript.

A fully constrained 16-event control passes the irregular attack oracle,
conflicting-edit rollback and actual key-to-voice dependency closure. Both key
and voice masks are supplied for its paired edit, so this control does not claim
automatic dependent note selection. Native before/after renders each contain
138000 stereo frames at 24 kHz, including a 6000-frame release allowance. Listening
is unassessed; rendering an explicitly supplied answer does not clear free search.

**Do not adopt the commit filter as the nonuniform layer mapping.** The next
contract must make position-specific provider relationships available during
solving, before committing an entire candidate. A public adapter compilation or
reviewed companion extension must preserve the original learned paths and counts,
explicit dependency closure and bounded preparation/search. It needs start-point
and complete-span semantics, declared gap/overlap/wrapping behavior, owned mapping
data, failure preservation and selective-edit evidence. A fixed accepted duration
plan is the first consumer; durations chosen during the same solve additionally
need a declared cumulative-time or staged-planning policy. A larger retry budget
does not supply these contracts.

This was a scoped prerequisite under [WFC-LAYERS](MILESTONES.md#wfc-layers), not a
blocker for uniform-grid providers, corpus work or inference. This study left
maintained APIs unchanged. Checked FPC 3.2.2 Win64 execution is terminal with zero
reported leaks and no authored-source warnings; existing RTL/companion warnings
remain. Policy, Pascal source, build/run logs, hashes and the two auditions are
ignored under `build/nonuniform-pass-study/`. No other target, general
nonuniform API, saved schema or percentage credit is established by this study.

## Position-qualified compilation study — 2026-09-20

A subsequent native study establishes a bounded adapter route using the pinned
public WFC contract. Compile each pair of event position and original latent state
into a distinct graph value, retaining that state's observation weight. Position
domains admit only their own values; adjacent positions use the original model's
`StatesCompatible` relationship. Public sequence-domain analysis supplies the
declared extent restrictions. Captured values map back to original state indices
and pass `ValidateSequenceStatePath` before use.

Each occurrence can then carry its own `RequireMappedFromPass` point or region
query. The occurrence's fixed source tick becomes a world offset from its unit
graph cell. These are compiler-owned graph values, not the sequence adapter's
private key format. Original learned models remain unchanged; no synthetic
observations are appended and no extra learner or solver is introduced.

The same 15 unequal-duration requests from the preceding study now solve with
**zero pass retries**. A key-only mask edit regenerates the 16-event voice without
supplying voice answers. A conflicting voice-only mask reports contradiction,
preserves the accepted tokens/states, and recovers when cleared. Exact replay
retains tokens, original latent states and the negotiation transcript. A region
query over the irregular `[480,1200)` span rejects its incompatible keys across
tick 960, distinguishing complete-span requirements from attack sampling.

All five sequence extents pass an order-two boundary control; an impossible
one-cell wrapped cycle remains contradictory. A separate 2:1 observation-weight
control retains those weights at every position. The original model text remains
identical after compilation, generation and edits. The paired free renders match
the preceding explicitly constrained control's two WAV hashes, each 138000
stereo frames at 24 kHz. This establishes the changed generation path, not a
listening verdict or WAV-derived part ownership.

The existing saved recorded reblend also supplies its rhythm, pitch and duration
models to the compiler. Nine requests, at 1/3/32 positions per dimension, agree
with the original WFC sequence adapter: four solve and five report contradiction.
This artifact contains short order-three runs, including only three duration
states; it cannot support a 32-position prefix. Compilation correctly preserves
that limitation rather than repeating observations to invent a longer path.

### Capacity and adoption boundary

Position expansion has a material cost. For `N` positions and `S` original states,
the unpruned prototype registers `V=N*S` values. WFC's two six-direction byte
relation arrays plus its initial domain matrix require `12*V*V + N*V` bytes.
That estimate excludes other graph, analysis, search and object storage. The
prototype rejects more than 1024 values or 16 MiB for those named arrays before
applying anything to a graph; it is not a total-process memory guarantee.

| Original states / positions | Expanded values | Named matrix bytes | Local compilation / solve |
| --- | ---: | ---: | --- |
| 2 / 32 | 64 | 51200 | below timer resolution / 15 ms |
| 8 / 32 | 256 | 794624 | 32 / 203 ms |
| 32 / 32 | 1024 | 12615680 | 437 / 4782 ms |
| 32 / 64 | 2048 | Over the declared value limit | Rejected before graph application |

These are one checked FPC 3.2.2 Win64 run's observations, not portable throughput
promises. An initial per-edge `NewRule` builder spent about 22 seconds compiling
the eight-state case; its still-running 32-state attempt was deliberately stopped.
The final compiler prepares reciprocal public rule arrays in batches, avoiding
repeated inverse-closure work. The complete final run and recorded consumer are
terminal with zero reported leaks and no authored-source compiler warnings.

The subsequent [fixed-partition implementation](#fixed-time-partitions) adopts
this route with owned timing, aggregate bounds, named-session edits/replacement
and capture validation. Its contiguous-cell contract explicitly handles wrapping
and excludes gaps/overlaps. Durations selected within the same solve still need
a separate cumulative-time or staged-planning contract; large models may require
a more compact public companion representation.

Sources, predeclared policy, final logs, recorded-model comparison, hashes and
auditions are ignored under `build/positioned-pass-study/`. The rejected earlier
commit-filter study remains separately recorded. No maintained API, dependency
source, artifact format or goal percentage changes from this feasibility result.

## Named sessions and selective regeneration

`TLearnedLayerSession.Create(Layers, Projections, Names, Options)` owns detached
copies of the actual models and projection rules. Names are unique, case-sensitive
identifiers of 1..128 characters, in the same dependency order as the layer array.
Input models and arrays can be released or changed after construction. The normal
layer budgets, full projection coverage and time/vocabulary responsibilities apply.

`TryGenerate` establishes the accepted result. `SetConstraints(Name, Mask)` replaces
that layer's complete positional mask; an empty mask restores the model's original
domains, including extent/end-point restrictions. Invalid masks preserve the pending
mask. Constraint changes remain pending until a successful solve.

`TryRegenerate(RootNames, Seed, Sequences, Report)` invokes the actual companion
`TryRegenerateNegotiatedFrom`. WFC closes the named roots over declared projection
dependencies. Pending edits outside the requested closure become additional roots;
an edited provider cannot be silently skipped by requesting only a descendant.
Independent accepted passes retain exact tokens and latent states, even when the
regeneration seed changes. A contradictory descendant cannot rewrite an inactive
provider. The actual report retains effective root indices, active pass indices,
contradiction and search budgets, in constructor layer order.

False/invalid requests preserve the caller's result and `CopyAccepted` snapshot.
Pending edits survive a failed solve so the caller can replace or clear them and
retry. All returned arrays are detached. Names, scopes and relations are fixed for
the session; compatible models can be replaced through the method below. This is
finite generation, not a persisted stream checkpoint, semantic schema registry,
model migration API or mechanism for editing already committed audio.

The existing native layer fixture verifies a two-edge descendant chain, preserved
independent latent states under a changed seed, ownership after source models are
freed, pending-provider inclusion and failure/recovery. Both checked compilers pass.
The [saved WAV style operator](WAVE-STYLE.md#selective-edit-evidence) uses the same
session for actual audible onset edits. Logs: `build/layer-session-{stable,trunk}/`.

## Transactional model replacement

After initial acceptance, call
`TryReplaceModel(Name, Model, Seed, Sequences, Report)` to replace one learned
provider or consumer. The session clones the supplied model; the caller retains
ownership and can free it after the call. Model order and latent states may differ.
Existing positional masks, projection vocabulary, scopes and all normal request
budgets must remain valid. Unknown tokens or incomplete relations reject rather
than silently discarding locks or migrating a schema.

The replacement and any pending constraint edits supply roots to actual WFC
dependency closure. A full candidate graph is solved with independent passes
restricted to their exact accepted latent states. These temporary restrictions
are removed before publication, so a later selective edit can still regenerate
those passes. Replacing a consumer cannot implicitly change its ancestors.
Success publishes the replacement and affected results together. False or an
exception retains the original models, graph, accepted results, caller output and
pending masks. A rejected replacement is not queued for a later regeneration.

`TLayerModelReplacementReport` identifies the replacement, effective roots,
affected layers and preserved layers by constructor index. Its `Search` is the
actual **full candidate negotiation report**, not a selective-pass reuse report.
The candidate uses fresh random streams from the supplied seed; preservation
covers accepted tokens/states, not the old graph's internal random positions.
Independent results are checked again before publication. Replacement temporarily
holds both bounded graphs/models in memory and performs full graph construction
and solving; it is not a low-latency audio-thread operation. Normal selective mask
edits continue to use `TryRegenerateNegotiatedFrom` without this rebuild.

The extended [layer fixture](../tests/pythian.tests.wfc.layers.lpr) verifies a
changed-order rhythm provider, two dependent layers and an independent one-cell
key provider. It checks retained nested masks, rejected vocabulary, contradiction
rollback, pending edits, detached ownership, independent replay, subsequent
replacement and subsequent selective editing. A consumer replacement that would
contradict its preserved ancestor fails without changing any accepted layer.

Checked stable Win32/Win64 and development Win32 evidence is under
`build/layer-replacement-{stable,win64,trunk}/`. The fixture accepts an optional
existing output directory for 2.02-second paired auditions: `replacement-before.wav`
and `replacement-after.wav`, plus independent key stems. The rhythm changes from
alternating attacks to two adjacent attacks; the independent stem stays
byte-identical. These use authored symbolic controls and native synthesis. They
verify the changed sounding path, not WAV inference, genre learning or a listening
quality verdict. No format, vendor source or eight-layer limit changes.

## Precursor and native choices

Phanes learns four lane models, an order-1 observed harmony/melody pair model,
and an order-2 relative scale-degree interval model. Its voice solve uses the
dependency layout harmony + melody -> pairs -> intervals. Native fixtures exercise
that same four-pass relationship, including an interval constraint that requires
retrying a provider. This is semantic mechanism coverage, not a claim that every
Phanes seed produces identical notes in a differently named native graph.

The library accepts explicit constraints instead of Phanes's fixed four-beat
source anchor, source rotation, prior-section first-token lock and four named
application lanes. Existing complete spans can be constrained and revalidated
through all declared relationships. Phanes's `Restore` validates lanes individually;
that alone does not prove pair or interval admission. Its last-public-token seam
lock also does not retain arbitrary latent history; use the separate
[sequence stream](LEARNED-STREAMS.md) when that is the intended contract.

Choosing a provider matters. Whole independent voice assignments may require many
retries before a later pair model accepts them. The native example learns an
order-2 observed pair sequence first and projects it into bass, melody and interval
models. That preserves joint history and gives those consumers a coherent provider.
The adapter supports both layouts; no budget is silently raised after failure.

## Native listening example

```text
pythian.layers.demo OUTPUT.wav [SEED [LAYER TOKEN MULTIPLIER]]
```

The [demo](../tools/pythian.layers.demo.lpr) learns four actual models from two
authored 16-beat bass/melody motifs, generates 32 cells with observed endpoints,
and renders two native triangle voices at 120 BPM. It writes the WAV plus JSON
with complete model texts, hashes, latent states, note pitches and exact frame
coordinates. This demonstrates coupled symbolic generation and Pythian synthesis;
the separate [passage example](PASSAGES.md) demonstrates learning from recorded WAV.
No Phanes source, assets, browser or playback device is required to build it.
Optional preference layer names are `pairs`, `bass`, `melody` and `intervals`;
the token must exist in that layer's model. For example:

```text
pythian.layers.demo preferred.wav 731 pairs 48:64 16
```

The JSON records the requested preferences for reproduction through this command.
It is not a loadable semantic style or resumable session archive.
Native [per-voice note planning](MIDI.md#independent-synthesis-voices-and-ensemble-frames)
now supplies the exact frame gates, frequencies and voice records; the demo retains
its explicit continuous amplitude after planning. The audio remains byte-identical.

Seed 731 renders 64 notes into 706482 stereo frames at 44100 Hz, 16.02 seconds
including release. Output: `build/3.3.1-i386-win32/layers.wav`, SHA256
`f18415eaa85dccff19f5ac192ab23636ccb9364227b838050f432c0346560eb2`.
Left/right peaks are 0.207794/0.203491; RMS 0.055873/0.055253. The final graph
requires no provider retries. Repeating the command reproduces WAV and metadata
bytes exactly. Publication remains two separate file writes.

The [focused fixture](../tests/pythian.tests.wfc.layers.lpr) verifies expected
observed pairs/intervals, actual latent paths, deterministic tokens and states,
detached caller output, incompatible marginal lanes, duplicate/self/unknown
projection rejection, an actual provider retry, distinct zero-retry exhaustion,
request limits, retry after rejection, and the single-layer boundary.

Evidence: `build/layers-focused.log`, `build/layers-demo-build.log`,
`build/layers-demo.log`, `build/layers-replay.log`, `build/layers-metrics.json`.
Checked with the existing FPC 3.3.1 i386-win32 compiler. Both fixture and example
are in the normal build; this change was validated with their focused commands.
Operator listening, broad musical quality, stable FPC and other targets remain
unverified. This adapter does not close the WFC ensemble/arrangement inventory.
