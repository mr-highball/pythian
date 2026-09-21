# Reusable semantic style graphs

[Home](../README.md) · [Layered style](LAYERED-STYLE.md) ·
[Provider compatibility](INDEPENDENT-VOICES.md#provider-compatibility-and-replacement) ·
[WAV styles](WAVE-STYLE.md)

[`pythian.wfc.semantic.style`](../adapters/wfc/pythian.wfc.semantic.style.pas)
provides immutable `TSemanticStyle` definitions for actual reusable WFC provider
graphs. It persists semantic models, source/run evidence and generation controls,
then creates the existing mapped or named-voice consumer directly. A caller can
reload a graph without reconstructing its dependency configuration in a demo.

This is a distinct artifact from PYS: PYS owns WAV measurement admission,
weighted relearning and saved sound recipes; the semantic graph owns an explicit
provider inventory and executable dependency configuration. Optional sound
bindings embed current PYS bytes, including their existing ancestry and policies.
Neither reader accepts historical development variants. The current semantic
encoding is `pythian.semantic.style.v1`, conventionally stored as `.pysg`.

## Definition and actual consumers

`TSemanticStyleDefinition.Providers` retains each provider's canonical actual WFC
model text, typed vocabulary/time contract, extraction policy, frozen vocabulary
hash, generation preferences and hard constraints. Choices are recovered through
the existing typed codec from the exact public token vocabulary; token indices
alone do not establish identity. Contracts include PPQ, musical domain, scope,
uniform/fixed-partition layout, unknown/rest policy, named role or ordered joint
role vector, pitch basis and optional original-clock conversion evidence.

The supported vocabulary is exactly the existing provider contract: key, tempo,
onsets, intensity, pitch, joint pitch/rhythm, duration performance, harmony,
ordered rhythm actions and independent singleton voice frames. Unsupported
relative-key/palette conversions reject through that contract. A provider missing
from the inventory is absent, not an inferred default. There is no phrase-model
vocabulary yet; this format does not claim learned phrase/form behavior.

For a general graph, retain explicit `Projections` and leave `NamedVoices=False`.
`CreateSession(Seed)` returns an owned `TCompatibleProviderSession`, with exact
models, preferences, constraints and time mappings. A named-voice graph instead
sets `NamedVoices=True`, keeps the harmony/rhythm/role inventory in actual pass
order, and retains its harmony mode, pitch ranges and directed pair policies.
`CreateVoiceSession(Seed)` reconstructs `TNamedVoiceSession`, including collective
harmony proof. Its dependencies follow that retained configuration; a competing
explicit projection list rejects. An ordinary mapped graph cannot silently
ignore named-voice ranges or pair constraints.

Both consumers retain their existing bounded search defaults and ownership
contracts. The caller supplies the generation seed. Saved preferences remain
separate from training contributions and hard constraints. A saved contradictory
lock can remain a requested control; generation reports failure without relaxing
it. Format admission does not promise every requested output scope is solvable.

## Independent observations, joint relationships and timing

Every `TSemanticRun` binds a source identity by ledger index, a unique run identity,
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
to generation preferences and hard constraints. Complete parent bytes are
retained, each vocabulary points to the actual parent identity, and every model,
source contribution, observed relationship, sound binding and extraction policy
must remain unchanged. A second derivation may use the first as parent. This is
reusable control derivation; weighted semantic merging is a separate task.

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

Bounds include 32 MiB per archive, eight providers, 32 source identities, 256 runs,
1024 observed cells per provider/run, 64 contribution weight, and eight ancestry
nodes. Provider/model and graph bounds remain in force. Replay work and mapped
co-observation each have explicit 16-million-operation estimates; excessive input
rejects rather than discarding evidence. Collection lengths and payload sizes
are bounded during decoding, with semantic checks before consumer publication.

## Verification scope

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
