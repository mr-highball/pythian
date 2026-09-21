# Selective context profiles

[Home](../README.md) · [Learning bundles](CONTEXT-ARCHIVE.md) ·
[Layered style direction](LAYERED-STYLE.md) · [Work](WORK.md)

[pythian.wfc.context.profile](../adapters/wfc/pythian.wfc.context.profile.pas)
adds immutable, persisted selection of independent key and tempo providers.
A source profile wraps a validated context learning bundle containing one or
multiple admitted excerpts. A derived profile takes key from one profile and
tempo from another. That result has the same API and format as its parents and
can participate in another selection.

[Explicit WAV admission](WAVE-CONTEXT-ADMISSION.md) now produces source profiles
with measured tonal evidence, a caller-selected key and either a declared clock
or explicitly selected measured pulse. Beat admission retains its quantized
phase in the existing grid start tick. Its external report is bound by hash in
the descriptive admission policy.
Selected [local pulse ranges](WAVE-CONTEXT-ADMISSION.md#changing-tempo-pulse-ranges)
also produce current profiles with changing tempo cells and a typed source
frame offset. Provider selection preserves that offset with the original bundle.

The [independent-voice operator](INDEPENDENT-VOICES.md#saved-context-feeding-the-voice-stack)
also consumes saved profiles through actual provider passes, then rebuilds its
authored harmony/rhythm/voice stack for the selected key and generated tempo.

This implements selective context reuse and ancestry. [WAV onset styles](WAVE-STYLE.md)
combine these profiles with weighted rhythm evidence and repeated saved blending.
Their named generation session preserves accepted key/tempo passes during onset
edits. General voice/harmony profiles, weighted context blending, joint constraints
and automatic WAV admission remain separate work. Selecting independent marginals
does not prove that the resulting key/tempo pairing occurred in a source.

## API and ownership

`TContextProfile.Create(Bundle)` owns a validated copy of encoded evidence and
models. The input bundle remains borrowed and can be freed.
`SelectContextProfile(KeyParent, TempoParent)` returns an owned derived profile.
Parents remain unchanged and may be freed afterwards. Exact PPQ and step ticks
must match; no resampling or grid normalization is implicit. Original source
start ticks and frame offsets, unknown keys, policies and independent model orders are preserved.

`CopyModel(cdKey/cdTempo)` returns an owned actual WFC model.
`CopyBundle` returns the complete original provider bundle; only the requested
dimension is authoritative for this selection. Its other dimension remains
original source evidence.

`Identity` hashes the complete profile archive. `ProviderIdentity` hashes the
selected original bundle archive. Derived profiles expose `ParentIdentity`
and `CopyParent` for each complete immediate parent. Source profiles reject
parent requests. These identities let callers trace selections through earlier
decisions to original source hashes and scoped admitted evidence.

`EncodeContextProfile` returns detached bytes. `DecodeContextProfile` (also
available as the validating `CreateArchive` constructor) checks complete
ancestry and replays each embedded bundle through existing actual WFC model
validation. It does not inspect external recordings or execute policies.
Digests protect integrity, not authenticity or label accuracy. Invalid decoding
preserves a previously assigned profile.

## Selection and bounded ancestry

Selection copies providers without pooling observations or modifying weights.
Reusing an ancestor therefore does not count observations again in the selected
models. Complete parent archives form an ordered tree, including repeated
appearances. History is retained even when selected providers happen to match;
different histories need not have identical profile identities.

Bounds are 16 MiB encoded bytes, depth 8 (source depth 1), 63 tree nodes and
65536 evidence cells across leaf appearances. Repeated appearances count toward
storage/admission budgets, not learned weights. Embedded bundles retain their
own limits. There is no deduplicated graph or external archive reference.

Validation replays bounded learner work. Model and parent copy operations
validate saved sources again; profiles do not cache live solver graphs.
Consumers should retain model copies for repeated generation.

The binary `.pcp` format uses nonnegative little-endian u32 fields:

| Field | Value |
| --- | --- |
| Magic, version, kind | `PCP1`, 1, source=0 or selection=1 |
| First length and bytes | Source: complete `.ptc`; selection: complete key-parent `.pcp` |
| Second length and bytes | Selection only: complete tempo-parent `.pcp` |
| Trailer | 64 lowercase ASCII SHA256 hex bytes over this node's preceding payload |

Nested nodes include their own trailers. Complete extents, kinds, versions and
digests are checked; trailing data rejects. Nesting cannot express cycles.
Decoding rejects excessive nesting and incompatible parent timing. Encoding is
deterministic for a given ordered history.

## Native operator and actual passes

```text
pythian.context.select --source INPUT.ptc OUTPUT.pcp
pythian.context.select KEY_PARENT.pcp TEMPO_PARENT.pcp OUTPUT.pcp
```

The selector prints profile/provider identities, timing and ancestry size.
It validates before writing and rejects output equal to either expanded input
path. Existing file writes are non-atomic; I/O failure may leave partial output.

`pythian.context.demo OUTPUT_PREFIX` builds profiles for source A, source B and
the two-source bundle. It selects keys from the two-source profile and tempo
from B, then reuses that result while replacing tempo with A. It saves these as
`.profile-1.pcp` (slow) and `.profile-0.pcp` (fast), releases original objects,
and reloads both. Declaration files and the original `.ptc` remain unchanged.

Loaded model copies drive actual key, tempo, bass and gate WFC passes. The demo
rebuilds the authored gate model and complete projection map for the selected
tempo vocabulary: WFC rejects source alternatives absent from the provider.
Consumers must reconcile dependent vocabularies when replacing models.
No generic dependency registry or automatic graph cache is claimed.
All four key/tempo pin combinations validate output tokens and exact duration.

## Evidence

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass source/derived model equality,
two-stage persistence after freeing originals, parent recovery, provider
identities, original orders/source offsets, detached bytes, incompatible timing,
depth limits and malformed archive rejection. Malformed cases include rehashed
invalid versions, kinds, lengths, damaged child data, truncation and trailing
bytes; prior assignment survives rejection.

The demo and both selector modes pass on both compilers. Four `.pcp` files,
the original bundle/declarations and four WAVs are byte-identical across
compilers. The bundle/declarations/WAVs also match the earlier context archive
checkpoint. The selector consumes two derived profiles to make a depth-4,
nine-node result.

| Profile | SHA256 |
| --- | --- |
| Two-source leaf | `8dd9c140a6206d5f73f2268cb289afba6a83662f17a5b3922fa9f46d039bd397` |
| First selection, slow | `ef10d744d34bf3d3fad1bae27326ffffe56b1272d372b28f92c4c87211a59ec5` |
| Second selection, fast | `43d3be0da6c5170073c4447206ed3e712e8569165a33958cea5ff91ebe0b77dc` |
| Further derivation | `215bebd1788b1829af591020f80c7ca7839d0bdf83003bbc5fb065b8f644e73b` |

Logs: `build/context-profile-{stable,trunk}/` and
`build/context-profile-replay.log`. Owned code has no warnings; companion/RTL
warnings remain. Normal builds include the profile fixture, updated demo and
selector smokes. This is not a full-suite/package refresh, a general song-style
milestone or approval of automatically learned musical structure.
