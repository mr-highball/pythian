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

WFC is integral to the full composition and audio synthesis product: its
learned constraints and independently controlled passes feed Pythian's native
sound realization, saved styles, selective blends and further blends. Core-only
distribution is a required independent foundation, while a companion consumer
explicitly selects the WFC source closure. This distribution choice does not
make full-product WFC acceptance optional. The
[minimal package](TODO/DONE/NS-6_delivery_06.md) verifies both subsets; final recorded
workflow acceptance remains [integration](TODO/NS-4_integration_01.md) and
[delivery](TODO/NS-6_delivery_03.md).

Audio DSP, provider vocabularies/codecs, musical clocks, source evidence,
uncertainty and sound mapping belong in Pythian. Only a reproduced generic
solver/learner contract gap belongs in WFC's separate local repository, on a
new branch with the user informed before edits, under the
[cross-repository procedure](TASKFLOW.MD#cross-repository-wfc-gaps). Do not patch
the dependency source in this checkout. The current
[boundary audit](CODEBASE-ASSESSMENT.md#wfc-boundary-audit) found no demonstrated
generic defect and made no WFC branch or dependency change.

The former [external-runtime observation adapter](PROVENANCE.md#optional-native-observation-adapter)
is historical evidence and is outside the supported Pascal-only workflow. The
[accepted Pascal execution task](TODO/DONE/NS-3_validation_02.md) qualifies the
owned replacement. [Final workflow delivery](TODO/NS-6_delivery_03.md) must supply and
exercise that producer on each declared stable target before claiming the
workflow is delivered; compiled core consumers alone cannot prove that step.

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

## Updating a pinned consumer

### Identify and retain the accepted snapshot

`hello-pythian` moves as development continues; its latest commit is not an
acceptance verdict. The [minimal consumer packet](MINIMAL-CONSUMER-HANDOFF.md)
identifies the accepted `bdd55eb04a89d0271241da6111f42e47039055d6` core/companion
archives, hashes, exact CI run and supported targets. Retain the selected ZIP,
`PACKAGE-INFO.txt`, `SHA256SUMS`, notices and your own caller/input evidence.
Verify the ZIP before extraction and its inventory afterward. Metadata records
the base revision, clean/dirty state, compiler and WFC pin; a dirty candidate's
base revision alone does not identify its bytes. If the frozen download has
expired, request a qualified replacement rather than substituting branch HEAD.

For a Git source checkout, use a fresh destination and pin the same revision:

```text
git clone --no-checkout https://github.com/mr-highball/pythian.git pythian-bdd55eb
git -C pythian-bdd55eb checkout --detach bdd55eb04a89d0271241da6111f42e47039055d6
git -C pythian-bdd55eb submodule update --init --recursive
git -C pythian-bdd55eb rev-parse HEAD
git -C pythian-bdd55eb submodule status --recursive
git -C pythian-bdd55eb status --short
```

The submodules must match this checkout's gitlinks, with no missing, changed or
conflicted entries. Do not update WFC to its moving branch. A companion ZIP
already contains the selected WFC source; a core-only consumer needs no WFC.
Preserve your old checkout, caller source and accepted outputs until the new
candidate is qualified.

### Review changes before switching

Inspect the published commits, affected Pascal interfaces, format contracts,
examples and dated [package evidence](PACKAGING.md) between your pinned revision
and the proposed replacement. For example, in the checkout above:

```text
git -C pythian-bdd55eb log --oneline de45c9e..bdd55eb -- src adapters/wfc tools examples docs PROJECT.md
git -C pythian-bdd55eb diff de45c9e bdd55eb -- src adapters/wfc examples docs/SEMANTIC-STYLES.md
```

These inspect an actual published change range; replace both revisions for your
own upgrade. Current change/deprecation notices live in those commits and the
owning API/format documents. There is no promised release cadence, notice period
or legacy-reader tier. In this example the semantic style contract advances to
`pythian.semantic.style.v2` and removes the v1 reader; the
[caller-provider guide](CALLER-PROVIDERS.md#persistence-compatibility-and-evidence)
describes the new codec binding and admission requirements. New source may
require caller changes or regeneration even when a unit filename is unchanged.

Build the candidate with the declared compiler/target and matching RTL/FCL in
fresh unit/executable directories. Probe `fpc -iV`, `fpc -iTP` and `fpc -iTO`,
including any target flags used for compilation. Follow the packet's extracted
commands or the [checkout build commands](PACKAGING.md#build-and-package);
`tools/build.ps1 -Compiler EXISTING_STABLE_FPC -CoreOnly` selects the core build,
and omitting `-CoreOnly` includes the companion. Replace the compiler placeholder
with your existing verified executable. Keep a changed compiler, dependency pin,
configuration or generated browser assets explicit; rebuild affected consumers
with the matched toolchain rather than mixing old compiled units or JS/RTL.
Operator staging follows the [fixed-slot LAN procedure](LAN-REVIEW-SERVICE.md).

### Regenerate affected artifacts from retained inputs

Use the new current writer/producer with the original legally available inputs,
preparation/annotation policies, source clocks and boundaries, uncertainty,
exposure and provenance. Retain old bytes for comparison; changing a format tag
or filling missing evidence with defaults is not regeneration. If inputs or
independent support are missing, stop with that artifact unqualified. Register
the compatible caller codec explicitly when a semantic style is admitted or
reloaded, including retained parents; a new session cannot borrow a destroyed
registry. See [semantic styles](SEMANTIC-STYLES.md) and the caller guide.

The existing authored example is a concrete current-format recreation route.
From the companion root, create fresh `build/update-units`, `build/update-bin`
and `build/update-output` directories, then run:

```text
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuexamples -Fuadapters/wfc -Fuvendor/wfc/src -FUbuild/update-units -FEbuild/update-bin examples/pythian.example.provider.extensions.lpr
build/update-bin/pythian.example.provider.extensions build/update-output/generated.wav 731
build/update-bin/pythian.example.provider.extensions build/update-output/replay.wav 731
```

Windows executables have the `.exe` suffix. Each fresh stem creates a WAV, a
current semantic style (`.pys` here) and two authored control WAVs. The consumer
reloads actual saved style bytes with fresh registration and checks saved PCM.
Compare generated/replay WAV and style hashes on the same target. This example
recreates authored inputs; it does not migrate an old recording-derived model
or supply independent musical truth. Existing `bdd55eb` qualification proves
that route, not a caller's unexecuted upgrade. For your affected artifacts,
release/reload and recheck identity, controls, failure recovery and replay under
the owning contract. Requalify changed source on affected targets; exact-revision
package/CI checks are required before calling new delivered artifacts accepted.
Unchanged-path evidence may be reused only with exact identities and impact
review. Do not relabel old qualified archives as a later revision.

### Report a reproducible update failure

Prepare a small redacted report for the
[repository issue tracker](https://github.com/mr-highball/pythian/issues) if your
account can submit there, or the maintainer-agreed consumer review channel.
Public issue creation is currently restricted; the
[consumer handoff](MINIMAL-CONSUMER-HANDOFF.md#return-these-results) supplies report
fields, not a promise of unrestricted submissions or a response time. Include:

- Old/new source revisions, ZIP/inventory hashes, subset, clean/dirty state and
  companion pin; identify any local caller or library changes.
- OS/CPU, compiler version/target/RTL, build flags and matching assets, exact
  minimal commands, exit status and useful error/log excerpts.
- Expected versus actual behavior, first failing stage, format/policy identities,
  source/input hashes, clock units, seed/settings and source rights/provenance.
- Same-target replay/reload results and the last valid output's preservation or
  failure state; provide a small redistributable reproducer where possible.

Keep private paths, credentials and unlicensed media out of the report. Preserve
the failed candidate separately. A correction needs affected-path rechecking
against its exact revised source/package; actual outside-user maintenance
acceptance remains the [support task](TODO/NS-6_support_01.md).

## Entry points and runtime obligations

| Consumer operation | Public entry point and owning contract |
| --- | --- |
| Load, measure and render native audio | Core audio/WAV, musical clocks, sources, processing and scheduling interfaces mapped in [Fundamentals](FUNDAMENTALS.md#supported-capability-families); begin with the [core example](../examples/pythian.example.core.lpr). |
| Learn bounded recorded features and reload a source-bound model | [WAV learning](WAV-LEARNING.md), [event learning](EVENT-LEARNING.md) and [streamed learning](LEARNED-STREAMS.md); the [event example](../examples/pythian.example.events.lpr) frees learning and reloads before generation. The packaged `pythian.learn` commands exercise journal learning, blend, further blend and saved replay. |
| Decode, derive and persist a style | `DecodeWaveStyle`, `TWaveStyleProfile.Encode`, `CreatePreferred`, `CreateBlendDimensions` and `CreateBlendLayers` in [pythian.wfc.style](../adapters/wfc/pythian.wfc.style.pas); [saved style contracts](WAVE-STYLE.md) own evidence, weights, preferences and ancestry. |
| Discover and edit uniform musical providers | `TStyleGrid`, `CreateSession`, `CopyProvider`, typed masks and `Capture` in the [grid API](GRID-STYLE.md). Inspect the actual provider list before setting locks or preferences. |
| Generate measured duration spans | `TStylePerformance`, its named session and `Capture` in the [performance API](PERFORMANCE.md), yielding a native plan with its exact musical clock. |
| Run bounded note/duration comparisons | Companion `pythian.style.comparators MANIFEST.json FRESH_OUTPUT_DIR`; [bounded execution](STYLE-CARDS.md#bounded-note-duration-execution) owns its current formats, authenticated inputs and mechanical limits. This is not grounded musical acceptance or qualification of an older package snapshot. |
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

For comparator failures, preserve `OUTPUT.attempt/packet.json`, its failure
reason, completed-render count, source/annotation/policy identities, seeds and
solver ledger. Only nine complete outputs permit publication under the fresh
requested directory; `grounded_acceptance` remains false. Keep a failed attempt
under its failed identity instead of renaming it as a completed packet.

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
