# Selective semantic blends and further blends

[Semantic styles](SEMANTIC-STYLES.md) · [Independent voices](INDEPENDENT-VOICES.md) ·
[WAV sound profiles](WAVE-STYLE.md)

`TSemanticStyle.CreateBlend(Left, Right, Recipe)` creates an immutable reusable
semantic style by independently selecting and weighting compatible providers.
The result supports the same mapped/named generation consumers, instrument
bindings, control derivation, encoding and further blending as its parents.
It uses actual WFC learning over retained independent samples. It does not
average serialized model bytes or invent co-observed musical tuples.

## Independent provider controls

`TSemanticBlendRecipe.Providers` has one entry per existing provider, in the
compatible inventory's declared order. Each entry has `LeftWeight`,
`RightWeight` and `ControlParent`. Weights are nonnegative integers up to 64;
every active provider needs at least one positive parent. Zero excludes that
parent's training contribution for this provider. The selected parent need not
be the same for harmony, joint rhythm, bass, lead or other supported dimensions.
Named roles remain explicit contract identities; no role inference occurs.

For example, the focused consumer uses these independent ratios:

| Provider | Left | Right | Generation controls |
| --- | ---: | ---: | --- |
| Harmony | 1 | 1 | Left |
| Rhythm | 3 | 1 | Left |
| Bass | 0 | 1 | Left |
| Lead | 1 | 4 | Right |

Training contributions multiply the selected parent's already retained run
weights. After canonical repeated-evidence handling, each provider's complete
positive weight vector is divided by its GCD. Every resulting weight must fit
0..64 and all actual learner work bounds still apply. Scaling all weights for
one provider by the same factor leaves its normalized model unchanged. Ratios
that remain too large reject; they are never rounded, clipped or sampled down.
The exact request is retained in the recipe, and normalized contributions are
visible in `CopyDefinition.Runs`.

`ControlParent` independently chooses the complete saved preferences and hard
constraints from parent 0 or parent 1. Training weights do not modify them.
`CreateDerived` can then override preferences/locks without rewriting the blend's
models, observations, source ledger or sound bindings. Contradictory controls
remain explicit requests; archive admission does not promise generation success
and the native consumer never silently relaxes them.

A successful paired provider-weight edit reconstructs only that provider's
model contribution vector; other models and their controls remain exact. To
apply it to an already accepted named performance, use the existing
`TryReplaceProvider` with the same semantic contract. That consumer owns actual
WFC dependency closure, rollback and preservation of unrelated accepted tokens
and latent states. Constructing a new style does not itself mutate a live
session or schedule audio.

## Compatibility and joint evidence

Both parents must expose the same ordered inventory, compatible explicit
role/pitch/vocabulary/time contracts, identical frozen ordered public token
vocabularies, and equal learner history orders. Their active graph policy must
also match: mapped projections, mapping rules, named harmony mode, voice ranges
and directed pair restrictions remain unchanged. This preserves semantic
meaning without silently dropping a cross-layer constraint. Source measurement
bindings remain attached to the selected provider contract; complete independent
run clocks and source ancestry remain separately retained.

Different roles or role permutations, absolute versus relative pitch, unknown
policies, palette identities, PPQ/layouts, vocabulary growth and competing graph
policies reject. This API does not infer a conversion or rebuild a vocabulary.
Explicitly prepare and admit a compatible graph first when conversion is needed.
Corpus vocabulary growth remains its separate lifecycle; rejection here is not
a claim that those musical styles are fundamentally incompatible.

Source archives still require their original joint observations and paired
contribution rules. Named source rows prove actual harmony/rhythm/role relations;
mapped source rows prove their exact timing projections and every declared
alternative. Control-derived source archives retain those same guarantees.

A blend retains complete parent archives and their already proved joint rows,
including parents whose current contribution weight is zero. Its marginal
training weights are deliberately separate from those original joint-observation
weights. The new active graph keeps the same supported relationship policy and
uses its normal independent generation proof. A marginal run's token and timing
vectors remain intact even where its current contribution is zero, so reducing
one provider's weight cannot erase or fabricate an observed joint row.

The blend does not claim that its independently selected marginals were observed
together in a recording, that every inherited joint passage remains reachable
under the new model frequencies/controls, or that every generated combination
was heard before. Original joint evidence belongs to its original graph/model
owner. Reload validates those owners, reconstructs the blend recipe and all
current model contributions, and requires exact canonical bytes.

## Repeated evidence, overlap and lineage

Each source run receives a computed `ProviderEvidence` identity for every
present dimension. It binds the original recording, exact rational run endpoints,
provider tokens, extraction policy, frozen vocabulary and explicit observation
clock/grid, including cell boundaries. Source creation computes these identities;
source loading also requires exact canonical re-encoding. Blends inherit the
identities from their validated parents instead of recomputing them from a
composite extraction label.

The same leaf observation reached through different parents is recognized by
original interval and provider evidence, rather than parent-object equality.
Two policies are explicit in `Recipe.RepeatPolicy`:

- `srpMaximum`: retain the maximum requested effective weight for each identical
  leaf observation. Shared parent/ancestor paths do not accidentally add evidence.
- `srpAddExplicit`: sum those effective weights before GCD normalization. This
  deliberately repeats the same evidence; it does not increase unique recording
  coverage or create new observations.

Partial original-interval overlaps and conflicting provider annotations/clocks
reject when both contribute to the same provider. Adjacent exact rational
intervals remain distinct. Different unconnected provider contributions may
cover the same interval; no temporal concatenation results. Each retained run
is a separate actual learner sample, repeated only by its explicit normalized
weight. No transition crosses a source/run boundary or missing gap.

In a blended marginal ledger, runs from different ancestors need not be globally
chronological or disjoint across different providers. `GapBeforeFrames` records
the nonnegative uncovered gap after the previous maximum endpoint for that
prepared source; overlap is zero. The independent per-provider original-overlap
audit remains authoritative. Original source archives keep their stricter
ordered/nonoverlapping run contract unchanged.

`CopyParent(0/1)` returns an owned parent style, or nil for an absent side.
`CopyBlendRecipe` returns a detached recipe for a blend; control-derived styles
expose their blend parent through `CopyParent(0)`. Complete parents retain
original run identities, preparation bytes, source geometry, extraction policies,
model texts, controls, sound lineage and exposure. `VocabularyAncestor` names
an actual selected parent that supplied the frozen vocabulary; the recipe and
parent models identify all other inherited and independently overridden inputs.

All parent sources remain in the exposure ledger, even when no current provider
or sound selects them. Same-source declarations must agree; same-recording-group
split/exposure conflicts reject. A zero weight cannot hide calibration or
held-out ancestry. Reweighting never upgrades authored/generated annotations to
verified recording evidence. These hashes bind declarations, not their truth;
recording annotation accuracy remains separate acceptance work.

## Independent sound selection and weighting

Each `Recipe.Sounds` entry names an existing voice role and independently assigns
left/right timbre and envelope weights. Omit an entry to omit the role binding;
both zero for one dimension preserves the authored instrument dimension. A
positive weight requires that parent capability. Selecting one parent keeps its
exact existing bytes. Selecting both invokes native
`TWaveStyleProfile.CreateBlendLayers` for that sound dimension, with its existing
GCD normalization, harmonic/trajectory recipe, envelope and source bounds.

Sound does not average unrelated acoustic codebook indices. Timbre and envelope
composition retain the existing PYS meanings. Its required ancillary rhythm and
context are an explicit left selection inside the sound profile; they do not
replace the semantic graph's independently selected musical providers. All
embedded sources and context ancestors remain in the semantic exposure audit.

Sound repeated-evidence policy is separate: `ssrpReject` rejects overlapping
original source contributions. `ssrpAddExact` explicitly permits additive reuse
of the exact same prepared source evidence; the PYS constructor additionally
rejects conflicting measurements for that source. Overlapping differently
prepared original assets reject rather than receiving an implicit duplicate
conversion. This sound policy has no automatic maximum-weight mode. Choose one
sound parent for exact inheritance, or explicitly request additive composition.

The resulting style can create an instrument after reload and participate in a
further blend. Instruments retain their existing owned measured-source/envelope
and borrowed custom-factory lifetimes. Changing timbre weights leaves envelope
bytes, musical models, preferences and locks unchanged; changing envelope weights
likewise preserves timbre. The focused fixture checks rendered differences and
exact unrelated controls, not only lineage labels.

## Current encoding, bounds and verification

The same current `pythian.semantic.style.v1` encoding now records source,
control-derived and binary-blend kinds, parent bytes, blend recipe, contribution
identities and full definition. There is no historical-variant reader; regenerate
older development artifacts. Decode reconstructs rather than trusts a serialized
blend definition. Corruption or disagreement with the actual recipe cannot
publish a partial object.

Semantic ancestry is bounded to 8 encoded tree nodes, counting each retained
parent occurrence even when its identity repeats. `Depth` reports maximum path
length; `NodeCount` reports encoded occurrences. The former source/control-only
maximum depth 8 remains supported because those trees are single chains.
`blend(A,B)` has 3 nodes; `blend(blend(A,B),A)` has 5; the diamond
`blend(blend(A,B),blend(A,B))` has 7. Further expansion beyond 8 rejects explicitly.
These are semantic artifact bounds, distinct from PYS's existing depth/node
limits. No unimplemented DAG compaction is implied.

Other existing limits remain:32 MiB per archive,8 providers,32 source identities,
256 canonical runs,1024 observed cells per provider/run, bounded integer weights,
16-million-operation learning/replay estimates, and native graph/search limits.
The two-parent construction stages at most512 incoming run records before
canonicalization. Multiplication and addition are checked before narrowing.
Source, observation, control and graph incompatibilities reject before publication;
parents remain immutable. Returned definitions, recipes and bytes are detached.

`tests/pythian.tests.semantic.blend.lpr [OUTPUT_PREFIX]` is the independent caller.
It exercises unequal connected/named provider weights, selective bass, independent
controls, exact unrelated accepted states under a live lead replacement, source
boundaries, GCD equivalence, parent/ancestor maximum versus explicit addition,
blend/reblend/diamond reload, zero-selected exposure, incompatibility and overlap
rejection, and native sound replay. With a prefix it retains `.pysg` archives,
controlled source sound evidence and paired blend/timbre/envelope WAVs. Existing
semantic-style fixtures remain required for original source/control derivation
and preparation guarantees. Compilation alone is not final acceptance; task-flow
QA records execution, replay and listening results separately.

Final QA on 2026-09-21 accepts the [selective blend task](TODO/DONE/NS-4_styles_02.md)
on checked stable FPC 3.2.2 Win32/Win64. Existing source/control fixtures and new
blend fixtures pass with zero unfreed blocks; all 28 target-local artifact replay
comparisons match. Paired native renders differ under isolated timbre/envelope
edits while unrelated bindings and musical states remain exact. Listening remains
unassessed. Commands, source hashes and the all-criterion review are retained in
`build/qa-batch-07/`; this earns no recorded-provider or genre-quality acceptance.
