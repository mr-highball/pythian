# Caller-defined WFC providers

Pythian accepts bounded caller-defined trait vocabularies through public Pascal
codecs and generic WFC projections. WFC is integral to full composition and
synthesis; the portable synthesis core remains independently usable. Audio
meaning and rendering belong to the caller/Pythian adapter boundary. This does
not make the fixed named-voice schema arbitrary, or support unbounded schemas.

The [caller codec unit](../examples/pythian.example.provider.extension.units.pas)
introduces harmonic balance without adding a library trait enum. The
[consumer](../examples/pythian.example.provider.extensions.lpr) admits styles,
reloads actual saved bytes with a fresh registry, releases registration objects,
generates dependent WFC sequences and renders native audio using the existing
[caller harmonic source](../examples/pythian.example.extension.units.pas).
Authored control WAVs retain exact parameter and clock provenance; they are not
inferred styles, acoustic ground truth or independent musical references.

## Build and run

Use native FPC with RTL/FCL from the root of a companion source package containing
these examples. Create `build/units` and `build/bin` first. No private include path,
asset, inference runtime, playback device or browser is required.

```text
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuexamples -Fuadapters/wfc -Fuvendor/wfc/src -FUbuild/units -FEbuild/bin examples/pythian.example.provider.extensions.lpr
build/bin/pythian.example.provider.extensions generated.wav
build/bin/pythian.example.provider.extensions replay.wav 731
```

On Windows add the executable's `.exe` suffix; quote paths containing spaces.
Checked cross-compilation may add `-Px86_64 -Twin64` with the matching installed
RTL. The CLI is `FRESH.wav [SEED]`, default seed 731, unsigned decimal
0..2147483647. Signs, fractions, nonnumeric seeds and larger values reject.
The output is 16000 Hz, stereo, 16000 frames: eight 120-tick cells at 480 PPQ and
120 BPM, each 2000 frames. Each voice holds 1600 frames and releases over 0.02
seconds inside its cell; the renderer's minimum frame count does not truncate
release. Harmonic balance changes the normalized second harmonic, while the
independent intensity provider controls amplitude.

For `generated.wav`, the consumer publishes four fresh files:

- `generated.wav`: generated PCM16, reloaded from disk and checked sample by sample.
- `generated.pys`: current style, reloaded from actual saved bytes with explicit registration.
- `generated-authored-0.wav` and `generated-authored-1.wav`: distinct authored control sources.

All four paths must be fresh in an existing parent. Invalid arguments, a missing
parent, a directory or any existing publication file reject before writes,
preserving existing bytes. Concurrent writers are unsupported. Direct writes
are not transactional: an I/O failure or interruption can leave partial new
files or an incomplete four-file publication. The caller owns cleanup/recovery;
no power-loss atomicity or automatic loading is promised.

## Declare meaning once

Implement `TProviderCodec` from
[the codec API](../adapters/wfc/pythian.wfc.provider.codecs.pas). Its three pure,
deterministic callbacks canonicalize configuration, decode token text to a
`TProviderCodecChoice`, and encode that choice back to the identical token.
Tokens and decoded payload bytes must be canonical UTF-8. `IsUnknown` is an
explicit field; neither an empty payload nor numeric zero invents unknown/rest
meaning. Input/configuration and returned payload arrays are detached at the
admission boundary, including before the subsequent Encode callback.

Use a namespaced identity and positive version, with a `TProviderCodecDeclaration`
and matching `TProviderCodecBinding`. The binding carries configuration once per
provider, plus units, unknown meaning and clock meaning. A declaration is copied
at registration and cannot be changed afterward. Declare positive work estimates
and positive maximum token/payload bytes. Supported clock meaning is exactly
`explicit-ppq-grid`; the surrounding provider contract supplies PPQ, grid and
source evidence. Configuration must already equal its canonical form; admission
does not silently normalize persisted meaning.

The harmonic example declares `org.pythian.example/harmonic-balance`, version 1,
units `second-harmonic-numerator`, unknown meaning `no-unknown-token`, and canonical
configuration `denominator=N`, N in 1..1000. `mix:M` requires canonical unsigned
decimal M in 0..N; the UTF-8 payload is just canonical M, and `HarmonicChoiceMix`
returns M/N. Leading zeroes, whitespace, signs, fractional values and unknown
choices reject. The preset denominator is 100 with tokens `mix:0`, `mix:35` and
`mix:100`. Its declaration uses configuration/decode/encode policy weights
32/48/48 and maxima 4 payload bytes / 8 token bytes. These are declared bounded
work policies, not measured CPU-time guarantees.

The public helpers create the binding/declaration, register the codec, produce
tokens, map detached choices to a typed mix, construct two authored source styles
and render sequences. Provider order is `pitch`, `balance`, `intensity`.
Explicit whole-cell projections associate pitch 60/64/67 with balance 0/35/100;
each advertised pair is co-observed in both authored runs. The runs retain
weights, exact original tick/frame boundaries and actual reference-WAV SHA256s.
Source models are learned from those retained token rows, not hidden data.

## Registration and lifetime

Construct caller-owned codec and `TProviderCodecRegistry` objects, call
`RegisterCodec` (or `RegisterHarmonicCodec`), then `Seal`. The registry borrows
codecs; destroying it does not free them. Keep both alive for each synchronous
admission call. Pass the sealed registry explicitly to
[provider/session admission](../adapters/wfc/pythian.wfc.provider.contracts.pas)
and the relevant [semantic-style APIs](../adapters/wfc/pythian.wfc.semantic.style.pas):
`CreateSource`, `CreateDerived`, `CreateBlend`, `CreateSession`,
`DecodeSemanticStyle`, `CopyParent` and `TryReplaceProvider` as applicable.
A later admission, replacement or parent reconstruction needs a live registry
again, even if its predecessor was already accepted.

Admitted sessions own detached bindings and decoded choices, so generation and
native rendering work after registry and codec destruction. Styles retain
serialized bindings, models and evidence; a later `CreateSession` still needs
explicit live registration. Neither object retains callbacks or registry
references. `CopyChoices('balance')` and `CopyContract('balance')` supply detached
session snapshots, as the consumer demonstrates.
There is no hidden global registry, dynamic module loading or executable payload
in a saved style. Native source factories have their separate borrowing/lifetime
obligations described in [the source/effect guide](CALLER-EXTENSIONS.md).

Use existing token preferences and constraints for soft weighting and hard locks.
Compatible replacement is an explicit admission operation; contradictory or
incompatible replacement fails without publishing a new accepted state. Do not
reinterpret saved tokens under another version/configuration. Missing, unsealed,
or incompatible registration rejects explicitly; callback errors and oversized
or noncanonical results are errors, not fallback to a built-in provider.

## Persistence, compatibility and evidence

The current format is `pythian.semantic.style.v2` only. Regenerate earlier
artifacts; no legacy reader is supplied. Explicit registration is needed for
source and nested-parent reload. One admission context spans recursive parents,
definition validation and internally created sessions, so nested work cannot
restart its budget. Do not change that context's borrowed registry mid-operation.

`SemanticVocabularyIdentity` hashes ordered public token text, the vocabulary,
unknown policy and complete codec binding (identity/version/configuration/units/
unknown/clock meaning). Source identities, run identities and source boundaries
are excluded from that meaning digest and validated separately. Equal vocabulary
meaning does not prove equal source evidence. Selective blends and further blends
must retain compatible meaning, explicit dependencies and original weighted
source/run evidence; parent reconstruction receives the registry explicitly.
Blended contribution rows use canonical `blend.run.N` IDs. Exact encoded source
parents retain their original run IDs; source boundaries, observation evidence
and normalized per-provider contribution totals remain traceable through both.
Some retained rows have zero weight for a selectively omitted provider while
still contributing to another provider.

## Admission bounds and caller obligations

The [codec constants](../adapters/wfc/pythian.wfc.provider.codecs.pas) bound one
complete admission operation, including nested reconstruction:

| Boundary | Limit |
| --- | --- |
| Registered codecs / distinct admitted bindings | 64 each |
| Namespaced ASCII identity | 128 bytes |
| Configuration per provider | 64 KiB |
| Token / decoded payload | 4096 UTF-8 bytes each, or smaller declared maxima |
| Callback dispatches | 262144 |
| Aggregate declared work | 16777216 policy units |
| Callback configuration/token/payload input and output | 32 MiB aggregate |
| Admitted decoded payload | 8 MiB aggregate |

Known input sizes and declared work are charged before dispatch. Declarations
are checked, and Decode reserves its declared payload maximum before running;
unused payload reservation is refunded after validating the actual result.
Returned configuration/token/payload sizes and token/payload UTF-8 are checked
before copying those results. Decoded payload is detached before Encode can
reuse a caller scratch buffer; canonical roundtrip identity is checked before
publishing accepted results. The 32 MiB counter measures callback I/O, not
all internal comparisons, copies or total process memory. These limits do not
bound execution or allocations inside arbitrary caller code. Purity,
determinism, truthful meaning/cost and sensible implementation remain caller
obligations; no sandbox, arbitrary-code isolation or hard-real-time claim follows.

The pinned WFC sequence implementation permits 1024 public tokens and 1024
states; Pythian provider model order is at most 64. [Layer limits](../adapters/wfc/pythian.wfc.layers.pas) additionally include
eight layers, 1024 cells, 262144 state-cell entries and 16777216 projection work
units. Styles are at most 32 MiB with eight retained ancestry nodes. These are
interacting upper bounds, not a promise that every maximum can be combined.
Named voice roles keep their fixed musical schema; custom traits use bounded
generic codecs/projections and explicit caller decoding into audio.

## Evidence scope and licensing

Focused worker checks on stable FPC 3.2.2 Win32/Win64 exercised actual dependent
WFC, registry release, fresh-registry saved-style reload, exact saved PCM,
same-target fixed-seed replay, malformed inputs and existing-output preservation.
With pitch/intensity fixed, changing balance altered waveform shape rather than
only scalar gain. Independent source and extracted-candidate QA also pass 221
maintained checks per stable target, including shared recursive admission,
failed replacement preservation and reusable blended native audio. This is
authored mechanical evidence; final clean committed archives and matching
published-revision Linux qualification remain pending.
The example's public-package mechanics do not establish actual third-party
adoption. Exact delivered-archive qualification is reported separately once it
passes.

Pythian and these examples use the [MIT license](../LICENSE); source files carry
complete notices. The included WFC dependency retains its
[license](../vendor/wfc/LICENSE) and exact revision. A source package's
`PROVENANCE.md` records precursor provenance; preserve its notices when reusing
sources. No dependency source edits are required for this example.
