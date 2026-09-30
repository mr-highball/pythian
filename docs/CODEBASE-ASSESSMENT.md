# Codebase assessment — 2026-09-29

[Project](../PROJECT.md) · [Task catalog](TODO/README.md) · [Consumer contract](CONSUMER-CONTRACT.md)

2026-09-30 accepted implementation update: the detached
[caller intake API](../src/pythian.corpus.intake.pas), actual source-bound
native admission/journal learner and [caller guide](CORPUS-INTAKE.md) pass all
corpus_05 criteria at their declared scope. The maintained
[style-card API](../src/pythian.evaluation.style.card.pas) and strict file
consumer close evaluation_01 AC1 only; independent grounding/calibration and
full comparator/control outcomes remain open. This does not qualify inferred
musical styles, many-hour acceptance or outside use. The dated audit below
retains its original evidence scope; live credit is **49.40 / 50.60 remaining**.

The bounded [caller-provider outcome](TODO/DONE/NS-4_providers_01.md) is now
accepted at frozen `bdd55eb04a89d0271241da6111f42e47039055d6`: explicit borrowed
registration, detached session choices, source-independent semantic identity,
shared recursive admission limits and v2-only persistence preserve caller
meaning through selective blend/reload/further blend. A genuinely custom
harmonic-balance trait drives native audio through dependent WFC. Independent
QA and exact clean Windows/Linux package inventories qualify this mechanical
scope; acoustic inference and non-agent adoption remain unearned.

Minimal source delivery is also accepted at frozen source
`de45c9eb05c9592e15ab19a1b581659610722d13`: clean core/WFC archives passed
stable Win32/Win64 extraction/consumers and the exact revision's successful
Linux integration/package run. Uploaded archive bytes and inventories were
downloaded and verified. The actual saved-file core geometry is 67,032 frames
(including release), rather than its 66,150-frame renderer minimum. The new
caller-owned canonical-pitch provider is mechanical delivery, not arbitrary
semantic vocabulary/codec extension. [Artifact evidence](PACKAGING.md#accepted-minimal-artifact--2026-09-30)
and the [consumer packet](MINIMAL-CONSUMER-HANDOFF.md) leave actual independent
use, listening and full learned-style workflow acceptance open.

This is a source, contract and recorded-evidence audit of the current checkout. The source audit is supplemented by the focused build-script cleanup checks recorded below; it is not a fresh whole-library, browser, listening or independent-consumer verdict. Dated results apply to the revisions and paths named in their records; an unchecked box remains open even when its implementation appears present. The intended product is a reusable Pascal synthesis library with trustworthy WAV learning and integral WFC composition/synthesis, style generation, blending and further blending for a *user-specified* style. Chillwave, stoner rock and lofi are development test choices, not public style categories or universal genre definitions ([PROJECT](../PROJECT.md), [layered-style direction](LAYERED-STYLE.md#accepted-direction-and-priority)).

## Capability and boundary map

| Area | Maintained affordance and evidence | Boundary still needing acceptance |
| --- | --- | --- |
| Portable synthesis | Root `src/pythian.*` exposes owned audio clips, clocks, WAV/MIDI, oscillators, sampled and spectral sources, envelopes, modulation, instruments, effects, buses, scheduling and streams. [Fundamentals](FUNDAMENTALS.md#supported-capability-families) maps interfaces to focused tests/examples; [consumer contract](CONSUMER-CONTRACT.md#entry-points-and-runtime-obligations) states ownership, frame coordinates, budgets and failure recovery. `tools/pythian.render.lpr` and `tools/pythian.compose.lpr` exercise direct rendering without WFC. | No device playback, hard real-time or arbitrary codecs are promised. Caller-selected source/instrument settings and authored composition do not prove recorded musical inference. Partial physical writes are possible ([Fundamentals](FUNDAMENTALS.md#support-decisions-and-outstanding-evidence)). |
| WAV learning and inference | `src/pythian.wave.read.pas` has a bounded, seekable frame reader; `src/pythian.analysis*.pas`, `src/pythian.learning*.pas`, `adapters/inference/pythian.inference.*.pas` and Pascal tools provide measurement, journals and Pascal-owned execution. [Native inference](NATIVE-INFERENCE.md#scope-and-admission-boundary) and accepted [NS-3 execution](TODO/DONE/NS-3_validation_02.md) scope the producer. | Observations, pitch salience and proposals are not admitted notes, roles or reference truth. Reliable recorded beat, note, context and part inference remain NS-3 work; results need source-bound independent references and actual listening where specified. No external inference runtime qualifies. |
| WFC persistence and control | `adapters/wfc/` owns the retained companion boundary. `pythian.wfc.semantic.style.pas` defines source identities, runs, providers, sound, `CreateSource`/`CreateDerived`/`CreateBlend`, encode/decode and sessions. `pythian.wfc.learning.blend.pas`, `pythian.wfc.style.pas`, grid, performance and layers expose weighted profiles, named controls and replay. [Consumer contract](CONSUMER-CONTRACT.md#entry-points-and-runtime-obligations) identifies public calls; [layered style](LAYERED-STYLE.md#existing-support-and-remaining-gaps) distinguishes saved mechanisms from admitted style. | Compatibility and finite provider budgets constrain blends. Existing round trips demonstrate admitted dimensions, not arbitrary full-song learned styles, complete voice/phrase structure or general taste transfer. NS-4/NS-5 own musical integration and style acceptance. |
| Corpus and long form | `src/pythian.corpus*.pas`, `pythian.music.compose.longform.pas`, `pythian.continuity.pas`, `adapters/inference/pythian.inference.corpus.pas` and `tools/pythian.inference.corpus.audit.lpr` provide bounded processing and identity/continuity mechanisms. [Corpus evaluation](CORPUS-EVALUATION.md#source-identity-and-split-rules) specifies recording/group/exposure separation. | Multi-hour scale and distinct-source contribution are separate from a convincing long-form style. [Layered style](LAYERED-STYLE.md#learning-a-style-from-many-hours) still calls for qualified, many-recording evidence, repeated generation and source-linked listening; source labels alone cannot establish musical quality. |
| Operator and feedback | Native `tools/pythian.label.catalog.lpr`, `tools/pythian.tools.listen.*.pas` and Pascal/pas2js `tools/label-workbench/` separate proposals from reviewed answers. The work record reports copied-catalog queue/replay, browser and 390 px checks, and fixed-path LAN repair ([latest work](WORK-HISTORY.md#fixed-qa-runtime-path-and-browser-cleanup--2026-09-29)). | The physical phone listen/play/Save verdict and complete end-to-end operator QA remain open. A recent phone Save failed with HTTP 431 and then received focused repair; isolated QA is not a physical-phone retest ([phone repair](WORK-HISTORY.md#phone-save-request-header-repair--2026-09-29)). Example labels are workflow fixtures, not ground truth. |
| Delivery | `tools/build.ps1`, `tools/package.ps1`, `.github/workflows/native.yml` and `packaging/README.md` build and extract core/WFC source closures. The accepted [native checkpoint](NATIVE-CHECKPOINT.md) records stable Win32/Win64 and Linux CI at `0ecfe34`, verified inventory and authored-example consumers. | Those artifacts predate current changes. A current minimal source consumer and a full accepted-workflow package need separate exact-revision checks. The reviewed task/checkpoint/work records contain no accepted independent reproduction of either current deliverable; [consumer checklist](CONSUMER-CONTRACT.md#independent-consumer-success-checklist) is a protocol, not a pass. |

## Prioritized decisions and risks

1. **Deliver a small current library slice independently of final style research.** The existing source ZIP mechanism and public core/WFC interfaces support a minimal load → control → synthesize → save/reload example, but the accepted checkpoint is frozen and self-run. Split current-snapshot packaging from an actual outside-checkout consumer verdict, with no claim of learned genre quality. This makes the project's central reusable-library claim testable now while full workflow work continues ([package script](../tools/package.ps1), [checkpoint](NATIVE-CHECKPOINT.md), [consumer contract](CONSUMER-CONTRACT.md)). NS-6 owns both results; no defect task is needed.
2. **Keep recording evidence separate from generated meaning.** The saved inference and style architecture can carry provenance, but proposals and measurements only become musical claims through qualified source identity, reviewed labels, independent partitions, comparator policy and synthesized-output listening. The open NS-3/NS-5 tasks already own these gates ([WAV learning](WAV-LEARNING.md), [corpus evaluation](CORPUS-EVALUATION.md), [milestones](MILESTONES.md#north-star-assessment)). Do not award style credit for a longer file, more tokens or a label name.
3. **Treat WFC blend reuse as a precise, bounded public contract.** Saved style ancestry, explicit weights and repeated derivation exist, but provider compatibility, vocabularies, timing grids and sound/source obligations restrict which arbitrary user inputs can combine. Report rejection and retained dimensions; test user-selected source styles without special genre rules. Open NS-4/NS-5 tasks cover the missing admitted dimensions and quality ([semantic style source](../adapters/wfc/pythian.wfc.semantic.style.pas), [consumer obligations](CONSUMER-CONTRACT.md#inputs-and-deterministic-replay)).
4. **Close the actual operator listening path.** The current mobile queue and HTTP repairs have focused evidence, yet the physical-phone audio/Save flow and full copied-catalog QA remain open. Keep exact request/asset identity, source-frame spans and reviewed-vs-proposal separation. The workbench is supporting infrastructure for trustworthy learning, not the whole library deliverable ([accepted editor/queue](TODO/DONE/NS-6_authoring_01.md), [physical/full operator task](TODO/NS-6_authoring_02.md), [work](WORK-HISTORY.md#review-queue-clarity-and-listening-media-recovery--2026-09-28)).
5. **Refresh delivery only at the right scope.** A documentation audit cannot extend `0ecfe34` package evidence to changed inference, browser and style code. Current source closure, notices, pinned WFC, Pascal producer on the declared stable matrix, artifact hashes and fresh external use must be checked at their respective task gates. Linux upload step success was observed, while local inspection of that uploaded artifact was blocked by unauthenticated 401 ([checkpoint](NATIVE-CHECKPOINT.md), [packaging](PACKAGING.md#first-remote-checkpoint)).

## Maintained versus experimental evidence

The maintained path is the checked source tree (`src/`, `adapters/`, `tools/`, `tests/`, `examples/`), its declared current formats and the exact package closure. Ignored `build/` files are fixtures, logs, private media, generated JavaScript, executable slots and candidate studies, not distributable APIs. The former TensorFlow C and ONNX observations are retained as historical provenance; the first Pascal periodic-support recorded probe was rejected ([PROJECT](../PROJECT.md#pascal-only-inference-boundary), [native inference](NATIVE-INFERENCE.md)). Source-specific converted WAVs may be private development inputs but cannot become hidden dependencies of a public package. WFC remains a pinned, licensed companion; removed Phanes remains provenance and notices rather than a runtime import ([PROJECT](../PROJECT.md#dependencies), [package script](../tools/package.ps1)).

## Source and verification detail

The [core consumer](../examples/pythian.example.core.lpr) creates three seeded
frame tones, exposes caller gain/seed, renders 67,032 stereo frames at 44.1 kHz
including release, saves PCM16 and reloads the actual file, checks exact bytes
and geometry, and reports a hash. Its `uses` list contains RTL and owned core
units only. The 66,150-frame argument is a minimum, not a render cap. Current
minimal acceptance binds the frozen delivery revision above; its actual outside
consumer verdict remains open. The
[WFC example](../examples/pythian.example.wfc.lpr) loads WAV, measures features,
learns a finite acoustic palette/model, solves a bounded sequence and renders
selected source grains. That example is acoustic reuse; it does not itself
demonstrate admitted note/role learning or a reusable full musical style.

Focused maintained fixtures cover meaningful contracts: the
[seekable WAV reader](../tests/pythian.tests.wave.read.lpr),
[Pascal WAV inference](../tests/pythian.tests.inference.wave.lpr),
[corpus bounds](../tests/pythian.tests.inference.corpus.lpr),
[semantic style persistence](../tests/pythian.tests.semantic.style.lpr),
[semantic blending](../tests/pythian.tests.semantic.blend.lpr) and
[listening catalog](../tests/pythian.tests.listen.catalog.lpr).
In particular, semantic blend fixtures check actual generation/reload,
unequal provider weights, unchanged parents after incompatible rejection,
corrupt-lineage rejection and sound PCM replay. The
[style implementation](../adapters/wfc/pythian.wfc.semantic.style.pas) caps its
encoding at 32 MiB and canonical independent runs at 256. Those finite bounds
and compatibility checks matter when promising user-defined styles: arbitrary
user preference labels do not imply unlimited or incompatible model merging.
Fixture existence and source inspection are not fresh pass results.

The [native build](../tools/build.ps1) uses checked FPC flags, project-owned
fixtures and isolated unit/output roots under `build/`; its `CoreOnly` option
supports an explicit core boundary. The [package script](../tools/package.ps1)
stages native source files and selected examples, optionally adds pinned WFC
sources/notices and a small learner-tool closure, writes a checksum inventory,
extracts the ZIP, verifies count/length/hash closure and compiles extracted
units/examples. It does not currently stage the complete native inference
adapter/tool or browser/operator application closures. Full workflow delivery
must therefore qualify and extend its declared closure; a successful current
minimal package establishes only its stated slice.

The [native CI definition](../.github/workflows/native.yml) selects Ubuntu
24.04 and FPC 3.2.2, runs the maintained build, extracts/checks core and WFC
packages and retains ZIP/log artifacts for 14 days. The defined workflow is
not evidence for another revision. Current stable Windows matrix, exact Linux
run identity and actual uploaded artifact-byte inspection are recorded for
de45c9e in [packaging](PACKAGING.md); full workflow and outside use remain open.

The documentation generally distinguishes measured/admitted/synthesized and
accepted/open behavior, but the former fixed three-genre task chain and the
monolithic NS-6 packaging/consumer gates obscured the reusable-library priority.
The rebalance assigns a [current minimal native package](TODO/DONE/NS-6_delivery_06.md)
and [actual independent minimal use](TODO/NS-6_delivery_07.md) their own gates,
and separates the [editor/queue contract](TODO/DONE/NS-6_authoring_01.md) from
[physical LAN listening and final operator QA](TODO/NS-6_authoring_02.md).
The dated 2026-09-29 complete-goal allocation assigned nine open NS-6 tasks
85 goal points (8.50 overall), with no acceptance earned by the rebalance.
The full recorded workflow continues to require accepted musical
integration and blend/reblend evidence; a minimal consumer cannot close it.

The completeness audit also assigns explicit owners for
[caller-owned synthesis extensions](TODO/NS-2_extension_01.md),
[accepted caller-provider/trait integration](TODO/DONE/NS-4_providers_01.md),
[maintained support/update use](TODO/NS-6_support_01.md) and
[actual ecosystem adoption](TODO/NS-6_adoption_01.md). Public abstract source and
effect APIs and generic layer inputs exist, but their implementation fixtures
do not establish independent caller extension or continued product use.
Single-snapshot packaging and one reviewer likewise cannot establish a
supported maintenance cycle or de facto standard status. Independent caller
use, support and adoption remain open; an adoption floor alone does not
justify a standard claim. The editor/producer queue contract now passes its
owned current-source criteria and independent browser QA; physical LAN/audio
and full operator use remain separate. The current ledger credits 49.40
weighted points, with 50.60 remaining.

## WFC boundary audit

WFC is integral to the full composition and audio synthesis product while
`src/pythian.*` remains an independently usable foundation. The pinned
[sequence learner](../vendor/wfc/src/wfc_sequence.pas) accepts caller UTF-8
tokens and isolated corpus samples; its
[sequence graph adapter](../vendor/wfc/src/wfc_sequence_graph.pas) exposes
projection maps, partial maps and segment boundaries. The generic solver owns
bounded pass negotiation and selective descendant repair, documented in
[selective negotiation](../vendor/wfc/docs/selective-negotiation.md) and checked
by source fixtures for repair horizons, separate budgets, atomic failure,
locks and replay in
[its conformance test](../vendor/wfc/test/wfc_selective_negotiation_test.lpr).
[Immutable fragment composition](../vendor/wfc/src/wfc_pipeline_compose.pas)
already assembles independently authored recipes with explicit identities.

Pythian's [layer session](../adapters/wfc/pythian.wfc.layers.pas) invokes actual
`TryRegenerateNegotiatedFrom`; model replacement builds a candidate graph,
fixes unaffected latent states and publishes only after validation. Its
[provider contract](../adapters/wfc/pythian.wfc.provider.contracts.pas) and
[semantic style](../adapters/wfc/pythian.wfc.semantic.style.pas) own musical
roles/vocabularies, PPQ/time grids, source evidence, uncertainty, sound/profile
lineage and selective blend/reblend. The fixed built-in provider enum and
missing caller codec/registration path are Pythian extension concerns, not
demonstrated generic solver defects.

This read-only source/contract/fixture audit found no reproduced unsatisfied
generic WFC contract; it did not execute upstream tests or prove universal
solver correctness. No upstream branch or dependency change was made.
Future demonstrated generic gaps follow the
[cross-repository procedure](TASKFLOW.MD#cross-repository-wfc-gaps): separate
local repository, new branch, user informed before edits and reviewed integration.
Audio/provider adaptation stays here; dependency source in this checkout stays
untouched. Existing provider/integration and minimal WFC consumer tasks own
the product boundary, with no duplicate upstream task added by this audit.

## Bounded maintained-code cleanup

Read-only inspection covered tracked owned implementation, adapters, tools,
fixtures/examples, packaging and native CI. No maintained TensorFlow, ONNX or
HDF5 execution reference, embedded credential-like literal or hardcoded private
LAN address was found by the targeted scan. This is a scoped inspection, not a
proof that every possible secret or defect has been excluded. Phanes mentions
in hash, oscillator and tonal units explain preserved extraction provenance;
they are not removed-source imports. Dataset/publisher URLs, license holders
and public attribution are intentional. Loopback bindings and private-address
validation implement the selected service contract rather than a personal
deployment dependency.

The justified change is in [workbench build configuration](../tools/build-label-workbench.ps1):
developer-specific absolute compiler/RTL defaults were replaced by explicit
arguments, `PAS2JS` or PATH compiler selection, and `PAS2JS_RTL_SOURCE` /
`PAS2JS_RTL_JS`. Missing RTL configuration fails with an actionable message;
the script still verifies required matched-RTL files and compiles both Pascal
pages with the caller's selected runtime. It does not guess a runtime from
another installation. PowerShell parsing, missing-configuration rejection,
and both explicit-argument and environment-configured builds passed using the
existing verified pas2js 3.3.1 toolchain. Logs and local configuration stayed
under ignored `build/workbench-config-cleanup/`; no machine-specific location
is a tracked build default. Pascal behavior, live assets and service processes
were not changed by this build-script cleanup.

The Win64-only supervised inference build is intentional at its current scope:
the maintained process adapter and CLI use Windows process/job APIs. Removing
the target guard would not make that path portable. Core independence and the
full final-delivery target contract remain separate gates. No further
implementation deletion is justified by this inspection; unverified concerns
remain acceptance work rather than proven stale logic.

This audit found no basis to mark any open musical, operator or consumer criterion
accepted. The cleanup compiled the changed build path only; it did not run
musical suites, launch a service/browser or establish listening or independent
consumer acceptance. Other evidence is source/contract inspection, task and
milestone accounting and recorded terminal results. Final QA remains with the
assigned reviewer.
