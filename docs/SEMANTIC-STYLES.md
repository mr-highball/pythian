# Reusable semantic style graphs

[Home](../README.md) · [Layered style](LAYERED-STYLE.md) ·
[Provider compatibility](INDEPENDENT-VOICES.md#provider-compatibility-and-replacement) ·
[WAV styles](WAVE-STYLE.md)

[`pythian.wfc.semantic.style`](../adapters/wfc/pythian.wfc.semantic.style.pas)
provides immutable `TSemanticStyle` definitions for actual reusable WFC provider
graphs. It persists semantic models, source/run evidence and generation controls,
then creates the existing mapped, named-voice or complete instrumental consumer directly. A caller can
reload a graph without reconstructing its dependency configuration in a demo.

This is a distinct artifact from PYS: PYS owns WAV measurement admission,
weighted relearning and saved sound recipes; the semantic graph owns an explicit
provider inventory and executable dependency configuration. Optional sound
bindings embed current PYS bytes, including their existing ancestry and policies.
The instrumental binding instead owns primary instrument and stem/mix recipes.
New semantic graphs use `pythian.semantic.style.v7`, conventionally stored as
`.pysg`. The primary archive owner retains a canonical parent graph and a shared
pool of recipe/model/evidence sections. Repeated parents count once. Immutable
payloads share storage and internally computed digests; returned bytes remain
detached. File identity is still SHA256 of the exact complete encoded archive.

Existing V4 source/control/blend, V5 recipe-variant and V6 scoped-control
artifacts import through the same primary codec and semantic factories, within
their original eight-occurrence bound. Their exact bytes, identities, model
meaning and parent IDs remain intact when embedded in a newer graph. Regenerate
V1–V3 development artifacts; those readers remain removed.

The [accepted ancestry task](TODO/DONE/NS-5_style-ancestry_01.md) records native/
actual JS edited-artifact and complete-corpus mix/stem replay, cancellation,
ordinary jobs, actual Studio and complete CI561/extracted qualification. Matching
server/worker bytes and browser assets are deployed to the fixed review slot.
This qualifies the mechanism, not the parent Studio blend interface or musical
usefulness.

`TSemanticStyle.CreateInstrumentalVariant(Parent, Recipe)` replaces only the
performed instrument, mix/effects, expression, form and performance options.
It retains the exact complete parent, source/corpus evidence, model text,
vocabulary, schema and provider preferences/locks. A changed audition is not
new learned evidence. The resulting node can be reloaded, used for instrumental
generation, derived again and selected as a blend/reblend parent. Cancellation,
incompatible recipes/clocks and the existing ancestry/byte limits still reject
without changing the parent. V5 cannot silently carry a different node kind or
rewrite frozen definition fields. Passage-scoped preferences require the linked
[style-control consumer](TODO/DONE/NS-4_scoped-style-controls_01.md); a global token
preference does not represent a short excerpt's scope.

## Time-scoped instrumental controls

`TSemanticProvider.Scopes` retains half-open musical ticks, explicit PPQ and step,
actual request origin, an optional hard token domain and separate positive token
preferences. `DeriveMusicalControls(StartTick, EndTick, Tonic, TonicBias, Parts,
Origin)` compiles requested musical controls against the existing vocabularies
and creates the existing control derivation. It never learns an audition or turns
its generated notes into new locks. Source observations, models and vocabulary
stay frozen; selective blends retain the chosen control parent's scopes too.

[`pythian.wfc.instrumental.policy`](../adapters/wfc/pythian.wfc.instrumental.policy.pas)
owns detached copying, provider-key binding, bounded validation and window
resolution for initial streams and retained edits. Sparse global locks intersect
scoped domains; soft global/scoped, drum and form preferences compose once at
each actual position. Existing primary sequence/domain/position-weight code owns
application and solving. Context projection is shared with the musical-control
compiler. The editor retains unrequested providers and outside-range states;
known future constraints enter the bounded planning window before solving.

Scopes keep their musical positions when a performance is longer and do not
repeat automatically. A shorter performance that cannot contain a scope rejects
with a useful length error. A changed tempo retains tick scope while changing
sample-time placement; incompatible PPQ/step, unknown providers/tokens, invalid
scope, conflicting hard domains and excessive combined weights reject. The
128-scope, existing token/preparation-work, ancestry and byte limits are explicit.
Callbacks preserve cancellation at validation and bounded window preparation.

The accepted shared-ancestry implementation removes the eight-occurrence limit
that blocked an actual edited style. It retains that six-node input, blends at
seven unique nodes, then reblends at eight. The
[ancestry task](TODO/DONE/NS-5_style-ancestry_01.md) records complete qualification
and deployment; ordinary selective blending remains the parent Studio outcome.

Ordinary Studio capture uses the actual edited frame range and completed clock
to retain musical ticks. If performed length/tempo/seed differs from the source
artifact, its actual recipe variant remains a parent of the scoped derivation.
Naming/reuse retain those ancestors and the original source context. Exact
audition notes remain in the song's decision journal, separately from style
policy. See [the scoped-control task](TODO/DONE/NS-4_scoped-style-controls_01.md) and
[WORK](WORK.md) for qualification and deployment status; no musical-usefulness
claim follows from persistence or a successful new performance.

The [selective blend/reblend extension](SEMANTIC-BLENDS.md) adds independent
provider contributions and retained multi-parent evidence to this same current
encoding. Final checked Win32/Win64 QA accepts
[the semantic blend task](TODO/DONE/NS-4_styles_02.md). The source-observation rules
below continue to apply to source archives; inherited joint evidence is kept
separate from independently weighted blend contributions.

The semantic archive now uses primary `pythian.stream.bytes`, little-endian
fields and canonical `pythian.text` on native and actual pas2js consumers. Native
sound replay is retained. The preceding v2 portability component preserved all23
captured archive/sound artifacts; v3 added the complete instrumental recipe and
observed-clock origin. V4 adds compact encounter-order token dictionaries,
64-bit prepared/run coordinates and the complete corpus receipt. The existing style
and blend/reblend fixtures run on pas2js. A mixed Unicode
recording group/domain archive has the same identity on both targets. Generated
measurement profiles can still differ with target floating-point math; this is
not a claim that independently measured sound profiles have identical bytes.
The32MiB bound, field/blob progress, cancellation, detached ownership and actual
model-generation checks remain enforced. `check-synthesis-portability.ps1`
includes both semantic fixtures under `-IncludeWfc`.

## Complete instrumental snapshots

Set `Instrumental.Enabled=True` and `NamedVoices=True`. Provider order is actual
harmony, joint rhythm, pitched roles, musical context, then percussion. A normal
bass/chords/lead plus kick/snare/hat style has nine models. Its recipe retains a
caller-defined label, material origin, sample rate, clock/seed/search options,
complete primary instrument definitions, six-part/master effect routing, drum
settings and rhythm eligibility, expression and authored phrase/form controls.
No genre enum, source PCM, borrowed model, factory or live instrument is stored.
The seed retains the full unsigned32 graph-seed range on native and pas2js.

`CreateInstrumentalStream` returns a `TSemanticInstrumentalStream` owning models,
instrument banks, buses and the existing `TInstrumentalMusicStream`. Pull mix and
stems through its borrowed `Stream`; keep the owner alive through playback. The
source style and input records may be freed immediately. Saved preferences and
hard locks cover every actual provider, including context and drums. They remain
separate from learned observation weights. Full instrumental styles reject the
older voice-only consumer so context/drums cannot silently disappear.

The overload taking `TInstrumentalStreamOptions` chooses a new performance
without changing the saved style bytes, models or learning receipt. Duration,
tempo, seed and lookahead remain explicit caller choices. PPQ/step must match the
saved provider schema; a retained form must still cover the requested cell count.
It can borrow a caller mixer and decision sink so native jobs use the same
binding and apply their mix once. The mixer must have the saved sample rate.
Keep the mixer and sink target alive until the owner is freed; construction or
callback failure does not free the caller's mixer. With no mixer argument, the
owner creates and frees the saved mix as before.

```pascal
Definition := Style.CopyDefinition;
Options := Definition.Instrumental.Options;
Options.Seed := 731;
Owner := Style.CreateInstrumentalStream(Options, Recorder.Append, Mixer, Progress);
try
  { Pull Owner.Stream.ReadOutputs; the source Style may already be freed. }
finally
  Owner.Free;
end;
```

[`MusicalCorpusStyleDefinition`](../adapters/wfc/pythian.wfc.semantic.corpus.pas)
captures actual corpus models and the learner's admitted independent samples,
including boundary rearticulation, source influence, gaps and actual proposal/
role origins. Supply the matching prepared/original source ledger and explicit
sound recipe; it does not invent parent audio hashes or identify instruments.
The original quantizer's tick origin and rounding retain fractional sample phase
when a contribution starts inside a proposal window. Capture/reload never rereads
the recording or runs WAV analysis. Model validation still replays the declared
symbolic learner, with no operator feedback write or implicit learning update.

`Corpus` retains actual source/selection classifications, source influence,
coverage, original contribution identities, proposal-run indices, ordered roles
and the actual corpus/model revision. Selected, processed, proposed, model-used,
budget-omitted and unmodeled time remain distinct. The revision uses the same
primary corpus identity function as the producer. A derived control variant
retains this receipt unchanged. A blend retains each complete receipt in its
parents and makes no invented single-corpus coverage claim at the blended root.

Prepared and original frame coordinates are64-bit. Exact interval scaling and
fraction comparison use primary `pythian.time`, including products too large for
a direct intermediate. Native counters retain Int64; pas2js rejects values beyond
its exact integer range. `OriginSha256` is an actual content digest. When a clip's
full parent was not hashed, `OriginMetadataIdentity` records its immutable metadata
binding instead; original range/clock and preparation evidence remain available.
A metadata digest never substitutes for a parent content hash. Unresolved
overlapping ancestry rejects rather than asserting independent evidence.

Primary [`pythian.sound.recipe.codec`](../src/pythian.sound.recipe.codec.pas)
persists detached oscillator/noise, additive, wavetable, FM/PM, layered, envelope,
modulation and complete effect recipes on native and pas2js. Explicit sample
descriptors are supported by this codec; the complete style's current admission
requires realizable synthesis recipes and does not yet resolve external sampler
bindings. Streamed gate percentages other than100 reject under the existing
articulation limit. The saved stream tail must cover its declared mix tail.

The native playlist job now prepares a private style candidate from the actual
corpus and performed instrument/mix recipe. Its receipt reports ready or a useful
unavailable reason; optional snapshot failure cannot turn completed music into a
failed song. Callback cancellation still propagates. The content-addressed `.pysg`
lives in `styles/` under the configured generated-asset store, with the receipt in
the ordinary job result. Capture does not reread the source or perform WAV analysis.
The later Studio save/blend interface remains separate from this native artifact.

`CreateBlend` also admits explicit
instrumental parent choices and actual weighted vocabulary unions, with saved
lineage and further blends. See the [instrumental blend contract](SEMANTIC-BLENDS.md#instrumental-parent-choices).
Ordinary Studio style saving/blending and operator usefulness remain tracked in
[instrumental styles](TODO/NS-5_instrumental-styles_01.md); a library replay does
not qualify that missing interface or musical preference.

## Definition and actual consumers

`TSemanticStyleDefinition.Providers` retains each provider's canonical actual WFC
model text, typed vocabulary/time contract, extraction policy, frozen vocabulary
hash, generation preferences and hard constraints. Choices are recovered through
the existing typed codec from the exact public token vocabulary; token indices
alone do not establish identity. Contracts include PPQ, musical domain, scope,
uniform/fixed-partition layout, unknown/rest policy, named role or ordered joint
role vector, pitch basis and optional original-clock conversion evidence.

Built-in vocabularies cover the existing provider contract: key, tempo,
onsets, intensity, pitch, joint pitch/rhythm, duration performance, harmony,
ordered rhythm actions, independent singleton voice frames, complete musical
context and canonical percussion `rest` / `hit:1..127` choices. The
[caller-provider contract](CALLER-PROVIDERS.md) additionally admits bounded
`spvCaller` traits through explicit caller codecs and generic projections.
Codec configuration belongs once per provider. Ordered tokens and declared
codec meaning share a vocabulary digest; source/run identities and boundaries
remain separate evidence checks. Unsupported
relative-key/palette conversions reject through that contract. A provider missing
from the inventory is absent, not an inferred default. There is no phrase-model
vocabulary yet; this format does not claim learned phrase/form behavior.

For a general graph, retain explicit `Projections` and leave `NamedVoices=False`.
`CreateSession(Seed, Registry)` returns an owned `TCompatibleProviderSession`, with exact
models, preferences, constraints and time mappings. A named-voice graph instead
sets `NamedVoices=True`, keeps the harmony/rhythm/role inventory in actual pass
order, and retains its harmony mode, pitch ranges and directed pair policies.
`CreateVoiceSession(Seed)` reconstructs `TNamedVoiceSession`, including collective
harmony proof. Its dependencies follow that retained configuration; a competing
explicit projection list rejects. An ordinary mapped graph cannot silently
ignore named-voice ranges or pair constraints.

Built-in graphs may omit the registry. A graph containing a caller codec requires
a live sealed registry at each admission, reload, parent reconstruction or new
session creation. An admitted session retains detached decoded choices and can
generate after registry/codec destruction; a style retains data and does not
keep registration alive. One operation budget covers recursive parents,
definition validation and internally created sessions. The fixed named-voice
schema remains harmony/rhythm/voice; caller traits use the generic graph path.

Both consumers retain their existing bounded search defaults and ownership
contracts. The caller supplies the generation seed. Saved preferences remain
separate from training contributions and hard constraints. A saved contradictory
lock can remain a requested control; generation reports failure without relaxing
it. Format admission does not promise every requested output scope is solvable.

## Independent observations, joint relationships and timing

In a source archive, every `TSemanticRun` binds a source identity by ledger index, a unique run identity,
original half-open frame interval and the exact gap since that source's preceding
run. Its provider token vectors and integer contribution weights explicitly retain
present and absent dimensions: an absent vector has zero weight and an empty grid.
Recordings and runs are never concatenated across a boundary or unknown gap.

Each run carries its own original PPQ and tempo changes plus a uniform grid or
fixed partition for every present provider. Its source clock must reproduce the
original frame extent exactly. Unequal provider cell counts are supported in
mapped graphs. All observed cells are hard-locked in a temporary actual WFC
session using those layouts; the existing mapper enforces broadcast, start-tick,
whole-cell conjunction, gap coverage and exclusive endpoints. Every declared
projection alternative must also occur in a corresponding mapped observation.
Connected observed providers retain equal contribution weights and are either
present or absent together. Relationships are not fabricated from independently
selected marginal vocabularies.

Named voices retain aligned joint rows, equal contribution weights and their
original aligned timing. Each observed run must satisfy the actual named graph's
harmony, rhythm, ranges, pair constraints and complete independent proof. This
matches the native graph's aligned-cell contract. Generated passages may still
combine learned histories as allowed by those declared constraints; retained
observations do not imply that every generated complete passage occurred before.

Loading replays each provider's actual learner from its ordered independent runs,
repeating samples according to their weights. Canonical model text must match
exactly, including latent states and boundary counts. Descriptive extraction
policies are retained, not executed. Controlled authored observations establish
this contract; they do not establish recording transcription accuracy.

## Source exposure and frozen ancestry

The source ledger retains SHA256, recording group, split, explicit vocabulary /
training / calibration / evaluation exposure, sample rate, frame extent and the
external source requirement. Contributing runs require the training split and
both training/vocabulary exposure. Held-out sources cannot claim either exposure.
Different identities in the same recording group must agree on both split and
exposure flags, so one source cannot hide the group's use in calibration.

Each source also retains `OriginSha256`, `OriginSampleRate`, `OriginFrameCount`
and a half-open `OriginStartFrame` / `OriginEndFrame`. These map the entire
prepared asset linearly to one contiguous interval of the original recording.
Original positions use Int64 even when a bounded prepared excerpt uses Integer
frames. Crop, re-encoding, gain changes and constant-rate resampling can retain
this mapping. Piecewise edits or concatenated recordings must be represented as
separate prepared assets/runs; the archive does not infer their transformations.
An original asset mapping to its own hash must retain its complete identity clock.
If the original appears in the ledger, it must itself be an original, not an
intermediate derivative. Same-original assets must agree on group and original
clock/extent, so their existing group split/exposure checks also apply together.

`PreparationEvidence` retains up to 64 KiB of the caller's preparation/audit bytes.
Set `PreparationSha256 := SemanticPreparationIdentity(Source)` after populating
the prepared/original geometry and evidence. This digest binds all those fields,
not just a free-standing label. Missing evidence, a stale digest, changed mapping
or contradictory original metadata rejects on creation and reload. The record
must explain the original relationship and transformations, including any
intermediate preparation; its truth remains a caller audit responsibility.
Neither this digest nor the archive hash authenticates an undeclared relationship.

Run intervals map through that retained source geometry. The contribution audit
compares exact rational original positions with bounded integer arithmetic:
adjacent fractional boundaries remain adjacent. Two overlapping runs from the
same original cannot both contribute positive weight to the same provider, even
if their prepared byte hashes differ. Distinct unconnected providers may observe
the same interval independently; joint providers retain their separate alignment
and equal-weight requirements. Intentional repeated training is represented by
one canonical run with its explicit integer weights, rather than duplicate assets.
`SemanticRunOriginRange(Source, Run, Start, End)` exposes the covering integer
frame interval for external audits, rounding outward; this display range may
share an edge frame even when the exact intervals do not overlap.

Hashes bind declarations to bytes; they are not signatures or authentication.
Reloading does not open external files. The external requirement states which
source material is necessary to repeat measurements, while stored token evidence
is sufficient to replay the declared models. Optional provider source clocks must
match a source-ledger identity and geometry. Embedded PYS sound sources and all
embedded context-selection ancestors must also appear in the exposure ledger,
including contexts reachable only through unselected historical PYS parents.

`CreateSource(Definition)` establishes frozen vocabulary hashes from the exact
public tokens. `CreateDerived(Parent, Definition)` currently permits only changes
to generation preferences and hard constraints. Complete parents are retained
through the shared archive. Each vocabulary points to the actual parent identity;
every model, source contribution, observed relationship, sound binding and extraction policy
must remain unchanged. A second derivation may use the first as parent. This is
reusable control derivation; `CreateBlend` and its independent contribution policy
are described in the accepted [blend extension](SEMANTIC-BLENDS.md).

## Sound and ownership

A `TSemanticSound` independently binds current PYS timbre and envelope bytes to an
existing semantic voice role. A missing side preserves the authored dimension;
an entirely absent binding remains absent. `CreateInstrument(RoleId, Zones, Rate)`
creates the existing `TStyleInstrument` with those profiles and caller-authored
zone settings. Explicit competing zone profile selections reject. The instrument
owns its copied measured factory and envelope, so the semantic style may be freed
after creation. Plans/playback still borrow instrument resources; caller-supplied
factories retain the existing borrowed lifetime. No abstract factory is serialized.
Saved PYS spectral trajectories retain their existing note-relative behavior.

Input records, nested arrays and byte blobs are copied. `CopyDefinition` and
`Encode` return detached data. Returned sessions own their models/configurations;
returned instruments own their saved sound definitions. The archive carries a
SHA256 trailer and checks complete canonical re-encoding after admission.
Corruption, incompatible contracts or failed evidence replay cannot publish a
partial style object.

## Capacity and replay

Bounds include32MiB per archive, fifteen archived providers,128 prepared sources,
4096 retained runs,262144 weighted observations per provider,64 contribution
weight and64 unique ancestry nodes (maximum path64). Compact token IDs retain every admitted row,
including zero-weight inherited observations; dictionaries have at most8192
retained meanings per provider. Model text is at most16MiB per provider. Actual
companion sample/token/state/history and graph bounds still apply. A complete
producer corpus may use64 sources,1024 proposal runs and65536 weighted observations;
admitted gaps can create several independent samples within a proposal run.

The [primary archive](../adapters/wfc/pythian.wfc.semantic.archive.pas) retains
at most131072 unique payload sections, with32MiB per complete file and per unique
payload pool. Codec byte/work counters and aggregate learning are separate.
The codec bound permits four32MiB traversals per admitted node (8GiB across64
nodes); it is a charged-work ceiling, not allocated RAM. Aggregate learning
preserves up to32 existing per-model512MiB charges per node, across at most64
nodes. Each actual learner invocation still has its original per-model bound.

Frozen control/recipe edits reuse already validated source evidence and models;
they still validate changed policy/recipe execution and codec admission. A blend
reuses a model only when its positive ordered evidence identities, integer
weights and model history order exactly match a validated parent. Other inputs
use the same primary weighted learner; there is no second learning algorithm.
Decoding validates parents before children and releases each full parent owner
at its final direct child. `ArchivePayloadBytes` reports unique retained byte
blocks, excluding headers/current decoded state; it is not process memory use.

Replay/reblending uses the shared weighted learner. Its observer bounds a
conservative comparison/history-work charge at536870912 per provider, including
unreported partial searches. Repetitive material is not rejected through an
observation-squared estimate. This is a work bound, not a time prediction or a
claim that every complex vocabulary fits. Existing mapped co-observation keeps
its separate16777216 work limit. Excessive input rejects without trimming models,
sources or rows. Collection lengths and payload sizes
are bounded during decoding, with semantic checks before consumer publication.
The complete instrumental layout admits up to six pitched and six drum parts
(fifteen models including context). Existing generic/named session bounds remain
eight providers; increasing archive capacity does not enlarge those consumers.
Corpus capture/save retains the actual supported source/run/observation ledger;
unsupported byte/work complexity remains an explicit failure, not partial saving.

## Verification scope

The [complete instrumental fixture](../tests/pythian.tests.instrumental.style.lpr)
exercises authored material and an actual weighted, cropped corpus with omitted
gaps and a fractional source clock. Saved/reloaded models, graph decisions,
expression, full mix and six synthesized stems match after input/style owners are
freed. All14 effects and the portable eight-recipe catalog are exercised. Invalid
provider controls, clock/bus mismatches, unsupported articulation, corruption and
construction cancellation reject. This proves persistence/execution, not musical
usefulness, inference accuracy or a deployed Studio style interface.

The maintained [semantic-style fixture](../tests/pythian.tests.semantic.style.lpr)
constructs source/derived graphs and compares actual generated tokens and latent
states over fixed seeds. It includes source gaps, incompatible PPQ, altered joint
rows, exposure laundering, incorrect source clocks, frozen vocabulary corruption,
unequal grids and start-tick versus whole-span evidence. A controlled waveform
supplies current PYS timbre/envelope evidence; reloaded named voices generate and
reloaded instruments render identical PCM after style/profile inputs are freed.
Preparation controls add crop/resample source and derived round trips, retained
exposure, missing/stale evidence, conflicting original metadata, overlapping versus
disjoint derivatives, exact fractional adjacency, independent provider observations,
explicit repetition weights and wide original-coordinate arithmetic. The current
encoding includes these fields directly; prior development fixtures regenerate.

```text
pythian.tests.semantic.style [OUTPUT_PREFIX]
```

With a prefix the fixture retains source/derived/named `.pysg` archives, the
controlled sound WAV/PYS, and paired original/reloaded instrument WAVs. Final
checked stable FPC 3.2.2 Win32/Win64 QA passed all task criteria on 2026-09-21,
including the preparation controls and exact target-local sound replay, with
zero leaks. Evidence and source hashes are retained under `build/qa-batch-06/`
and `build/semantic-provenance/`. Recording accuracy, actual listening and genre
quality remain separate acceptance work.
