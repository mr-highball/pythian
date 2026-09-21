# Supported native consumer and distribution contract

[Home](../README.md) · [Project policy](../PROJECT.md) ·
[Package evidence](PACKAGING.md) · [Capability map](FUNDAMENTALS.md) ·
[Delivery acceptance](MILESTONES.md#delivery-release)

This contract defines the supported development surface and the acceptance needed
for final independent delivery. Dated build/package evidence applies to its exact
snapshot; it does not certify later changes. The intended learned workflow still
requires the musical, style and independent-consumer acceptance in the
[task catalog](TODO/README.md).

## Compiler, target and dependency scope

| Compiler and native target | Support expectation and evidence boundary |
| --- | --- |
| FPC 3.2.2, i386-win32 | Stable baseline; checked full builds and freshly extracted consumers are recorded in the package evidence. |
| FPC 3.2.2, x86_64-win64 | Stable native target; checked affected consumers and extracted companion packages are recorded separately from full Win32 builds. |
| FPC 3.2.2, x86_64-linux on Ubuntu 24.04 | Native CI target; the maintained workflow builds and verifies both extracted subsets. See the dated CI record in package evidence for the exact run and revision. |
| FPC 3.3.1, i386-win32 and x86_64-win64 | Development compiler compatibility, limited to the dated consumer/fixture checks in package evidence; not a substitute for the stable target matrix. |

Final accepted-workflow packages must pass on all three stable compiler/target
combinations above. Other compilers, OS/CPU pairs and development compiler
revisions need their own evidence before inclusion. Use Delphi mode and standard
RTL/FCL; no IDE is required. Build orchestration uses PowerShell. Keep generated
units and executables separate by compiler/target outside delivered source.

The **core subset** is the owned `src/pythian.*` library: audio, timing, MIDI/WAV,
analysis, synthesis and reusable learning data. It has no WFC, Phanes, browser,
engine or playback-device dependency. The **companion subset** adds
`adapters/wfc`, the exact pinned WFC source and its notices. Actual constraint
learning, named sessions and saved-style providers use this companion. WFC types
belong at that boundary. Athena supplies repository standards, not a runtime
dependency; Phanes is removed and contributes only retained extraction provenance.

Use the [maintained build and package commands](PACKAGING.md#build-and-package)
for a checkout and the [standalone package instructions](../packaging/README.md)
for a ZIP. A checkout must initialize the recorded submodule pins; a companion ZIP
already includes its selected WFC source closure. Never resolve a moving companion
branch as though it were the recorded pin.

## API and artifact stability

The distribution is a source development snapshot. Public interfaces are the
owned Pascal unit interfaces and their linked contracts, with examples showing
supported calls. Internal implementation details and ignored studies are not
additional supported entry points. No stable binary ABI, semantic-versioned API
freeze or perpetual source compatibility is promised. Consumers pin a snapshot,
recompile against it and review changed contracts before upgrading.

The [development format policy](../PROJECT.md#development-format-policy) owns the
rule: one current native format for each distinct artifact contract. Regenerate
superseded development artifacts from retained inputs when the schema changes.
Current identifiers and measurement-policy identities support validation and
replay; they do not promise historical readers. Retain a compatibility path only
for a recorded concrete consumer/interoperability requirement. MIDI and WAV retain
their explicitly documented interoperable subsets.

## Entry points and runtime obligations

| Consumer operation | Public entry point and owning contract |
| --- | --- |
| Load, measure and render native audio | Core audio/WAV, musical clocks, sources, processing and scheduling interfaces mapped in [Fundamentals](FUNDAMENTALS.md#supported-capability-families); begin with the [core example](../examples/pythian.example.core.lpr). |
| Learn bounded recorded features and reload a source-bound model | [WAV learning](WAV-LEARNING.md), [event learning](EVENT-LEARNING.md) and [streamed learning](LEARNED-STREAMS.md); the [event example](../examples/pythian.example.events.lpr) frees learning and reloads before generation. The packaged `pythian.learn` commands exercise journal learning, blend, further blend and saved replay. |
| Decode, derive and persist a style | `DecodeWaveStyle`, `TWaveStyleProfile.Encode`, `CreatePreferred`, `CreateBlendDimensions` and `CreateBlendLayers` in [pythian.wfc.style](../adapters/wfc/pythian.wfc.style.pas); [saved style contracts](WAVE-STYLE.md) own evidence, weights, preferences and ancestry. |
| Discover and edit uniform musical providers | `TStyleGrid`, `CreateSession`, `CopyProvider`, typed masks and `Capture` in the [grid API](GRID-STYLE.md). Inspect the actual provider list before setting locks or preferences. |
| Generate measured duration spans | `TStylePerformance`, its named session and `Capture` in the [performance API](PERFORMANCE.md), yielding a native plan with its exact musical clock. |
| Apply selective edits and solve | `TLearnedLayerSession` in [named layers](LAYERS.md); training weights, soft preferences and hard locks have different meanings. Realize captured plans through caller-selected core voices and file I/O. |

Ownership is declared per interface, not inferred from a Pascal record assignment.
The style grid/performance definitions copy their input style; their sessions own
independent copies and may outlive those definitions. Keep the definition when
constructing its typed masks or capturing its original models. Returned owned
objects require caller release with `try/finally`. Captures return detached data,
but assigning a record with dynamic arrays can share those arrays: copy before
mutating aliases. Borrowed streams, journals, factories or definitions must remain
alive for the consuming call/object where its contract says so.

Audio positions and block counts are sample **frames**, with channels separate;
rates are frames per second. Do not confuse samples across all channels with
frames. Floating seconds use the explicit floor/ceiling policy of
`pythian.time.SampleFramesFromSeconds`. Musical positions are ticks under an
explicit PPQ and tempo map; tempo-provider values are microseconds per quarter.
Source frames, source offsets, output frames, uniform cells and generated duration
spans are distinct coordinates. Use the core clock/grid mappings rather than
treating token indices as seconds, beats or notes. Unknowns and silence retain
their documented distinct meanings.

Declare finite scopes and use each interface's validated limits. For example,
grid `CellCount` and performance `SpanCount` are 1..1024; key/tempo context must
cover the generated duration, and models must share the required PPQ/vocabulary.
Search budgets, source/ancestry counts, analysis windows, work, memory and output
lengths remain bounded under their owning contracts. A supported numeric value
can still be absent from a learned vocabulary or infeasible under joint locks.
Provider inspection alone does not establish feasibility or inferred voice roles.

Handle argument/admission exceptions and reported solve failure before publishing
a result. Named-session failures distinguish infeasibility and exhausted budgets;
successful solving is followed by capture validation. Failed capture does not
undo a solved session; build a candidate plan before replacing the accepted one.
Processing chains/streams can enter a failed state after partial advancement and
require their documented reset or replacement. Physical writes and consumed
input cannot be rolled back by in-memory candidate validation. Late file I/O can
leave partial output; durable atomic replacement is not promised.

## Inputs and deterministic replay

An intended learned-workflow consumer needs the exact current saved style/model
bytes, source/evidence identities, admission policies and compatible companion
revision. Grain reconstruction additionally needs one exact source WAV per saved
distinct source hash; a model does not contain that PCM. Saved synthesis recipes
can render without reopening original audio where their contract permits it, but
loading their evidence does not independently verify the original recording.
Learning needs the admitted source WAVs and declared analysis/cache inputs.

Retain legal source access, attribution, preparation lineage, clocks, partitions,
exposure and annotation/admission records for the claimed musical result. Unknown
or rejected evidence must remain explicit; caller declarations are not automatic
proof of independent evaluation. The [corpus evaluation contract](CORPUS-EVALUATION.md)
owns recording identity and exposure; the [musical evaluation contract](MUSICAL-EVALUATION.md)
owns measurement acceptance. The library package includes neither external music
nor optional research model/runtime assets. Optional references recorded in
[provenance](PROVENANCE.md) are not hidden production prerequisites. Any future
adoption must declare its exact artifacts, licenses, dependency and execution scope.

For replay, record the source/package and WFC revisions, compiler/target, artifact
hashes, current format/policy identities, explicit seed, provider order/scope,
budgets, masks/preferences, training/blend weights, clocks and realization settings.
Release and reload saved inputs in a fresh consumer process before comparing.
Require exact model/serialization and output-byte replay where the relevant
contract and target evidence establish it. Record separately any numerical
tolerance with its policy. General cross-platform floating-point byte identity,
musical correctness and listening quality do not follow from deterministic tokens.

## Independent-consumer success checklist

This is the required acceptance protocol, not a claim that an independent consumer
has already passed it. [Final packaging](TODO/NS-6_delivery_03.md) supplies the
accepted workflow and inputs; [independent acceptance](TODO/NS-6_delivery_04.md)
owns the external reproduction and verdict. Current packaged authored-audio
examples demonstrate mechanics and cannot substitute for accepted recorded styles.

1. **Identify and unpack.** Record the exact source ZIP or checkout revision,
   subset, compiler/target and companion pin. Verify the complete `SHA256SUMS`
   inventory and full notices against fresh extraction. The manifest verifies
   bytes; it is not a signature. Obtain declared external inputs legally and
   verify their hashes and preparation records.
2. **Build outside the checkout.** Follow the package README using only delivered
   source paths and standard compiler libraries, with fresh output directories.
   Build all delivered owned units and run the appropriate examples. Record the
   command, exit status and warnings; no developer workspace paths, stale compiled
   units, removed precursor files or hidden caches may be required.
3. **Load admitted learning.** Load the accepted saved models/styles from disk,
   verify current format, ancestry and source bindings, and supply audio where
   reconstruction requires it. Inspect admitted and unknown dimensions. Confirm
   changed/missing input hashes and incompatible contracts reject clearly.
4. **Control and generate.** Discover the available named providers, apply the
   documented selective locks/preferences and generate through actual WFC.
   Check dependent passes and preservation of unaffected accepted layers. Capture
   a valid clock/plan and render playable audio. Record infeasible/budget-limited
   requests and the documented preservation or recovery behavior.
5. **Save, reload and derive again.** Free original learning/session state; reload
   saved artifacts and reproduce the declared result with the same settings.
   Selectively blend accepted sources, save/reload the result, then blend that
   result again. Verify weights, complete lineage, retained/changed dimensions,
   compatibility rejection and reproducible generation at each stage.
6. **Record the scoped verdict.** Retain artifact hashes, environment, settings,
   results and actionable usability/listening observations. Resolve supported
   failures and recheck the affected path. Identify which recorded styles and
   controls passed; one consumer cannot establish broad ecosystem adoption.

## Distribution, notices and unclaimed scope

The maintainer-selected policy is development source snapshots on `hello-pythian`
for ongoing review, as recorded in the [project profile](../PROJECT.md). Core and
companion source ZIPs are the existing delivery artifacts; they are not installed
compilers, precompiled libraries or tagged releases. No new release platform,
release cadence or long-term compatibility tier is selected by this contract.
Final accepted packages and independent handoff follow the checklist and existing
delivery tasks. This documentation task alone authorizes no root commit,
publication, release or external message; separate maintainer instructions govern
those actions.

Keep the complete [project MIT license](../LICENSE), original copyright holders,
all applicable derived-file notices, the companion's full license when included,
and [precursor provenance](PROVENANCE.md). Preserve Phanes-derived attribution
after removal of its source. Record exact included revisions and complete package
inventory. Exclude development recordings, private inputs and optional reference
assets from source packages. A library license does not grant redistribution rights
to unrelated recordings or models; any separately supplied asset needs its own
full applicable license/notices and provenance.

Supported native use does not promise browser/WASM, engine integration, device
callbacks, allocation-free operation, hard real-time deadlines or hardware clock
synchronization. WAV support is the declared mono/stereo RIFF/RF64 PCM/float reader
subset and canonical PCM16 output; universal codecs and arbitrary speaker layouts
are outside scope. General polyphonic transcription, learned instrument roles,
genre quality and many-hour style acceptance remain subject to their own tasks.
The ambition to become a standard Pascal audio library is not evidence of adoption.
