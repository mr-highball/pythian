# Pythian project profile

[Home](README.md) · [Standards](vendor/athena/README.md) · [Work](docs/WORK.md)

Pythian aims to become the standard reusable audio synthesis library for Pascal.
The root namespace is `pythian`. Common audio behavior is extracted from WFC and
Phanes, then expanded into a fundamental synthesis and audio learning toolkit.

| Decision | Value |
| --- | --- |
| Baseline | Native FPC library and command-line tools, no IDE requirement |
| Language | Delphi mode Pascal, standard RTL/FCL, two spaces, UTF-8, LF |
| Compiler | FPC 3.2.2 stable baseline and 3.3.1 development compiler; i386-win32 and x86_64-win64 evidence scoped in [delivery](docs/PACKAGING.md) |
| Initial host | Windows; portable core with no Windows units |
| Browser / CGE / WASM | No application target selected; no core dependency |
| Build | `./tools/build.ps1` (checked native fixtures and command-line tools) |
| CI | [Native workflow](.github/workflows/native.yml), Ubuntu 24.04 / FPC 3.2.2; [first remote run passed](https://github.com/mr-highball/pythian/actions/runs/35557200115) at `0ecfe34` |
| Outputs | `build/<compiler>-<cpu>-<os>/` |
| Work profile | Lean, one primary agent |
| Publishing | Development snapshots on `hello-pythian` for ongoing review |
| Branch | `hello-pythian` |

## Dependencies

The retained submodules and former Phanes reference are MIT licensed. Current
pins are the root Git gitlinks; the revisions below also preserve extraction
provenance and are not automatic upgrade instructions.

| Submodule | Public source | Initial revision | Role |
| --- | --- | --- | --- |
| Athena | https://github.com/mr-highball/athena | `c610e897f532fb8fa9a272ea01d9c708e6c6cec2` | Shared standards |
| WFC | https://github.com/mr-highball/wfc | `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4` | Reference and retained constraint/learner companion |
| Phanes (removed) | https://github.com/mr-highball/Phanes | `21cbefee1de7c41c468751246354f846711e07c8` | Historical extraction reference; notices and provenance retained |

WFC remains a submodule for adapters and learners. The core must build without
either precursor source directory. Phanes was removed after the
[extraction and consumer audit](docs/REFERENCE-REMOVAL.md); its application assets
are not library inputs. WFC and Athena remain pinned submodules.

Current Athena pin: `b8cdb5b3c36d0b3670a4b722d98d905a2cb78de3`, updated from
upstream `main` on 2026-09-21 after the task-size/progress-checkpoint merge. The initial
revision above remains historical provenance. Adopt the shared
[Task flow standard](vendor/athena/docs/task-flow.md) through the local
[workflow](docs/TASKFLOW.MD).

## Acceptance

The [supported consumer contract](docs/CONSUMER-CONTRACT.md) declares the native
target matrix, source/API stability, required inputs and independent-delivery
checklist. Its definition is accepted; final workflow and independent-use results
remain separate milestone tasks.

Deliver reusable audio data, codecs, timing, synthesis primitives, composition
of those primitives, and native operator tooling. Extend learning from symbolic
MIDI into WAV recordings, retaining measured features and explicit uncertainty;
connect learned representations to the actual WFC contract and demonstrate
generation and audible reconstruction. See [architecture](docs/ARCHITECTURE.md)
for the boundaries and [work](docs/WORK.md) for evidence and outstanding gates.

Musical generation must compose small, independently controllable layers through
WFC passes: foundational context such as key and tempo informs harmony/rhythm
and higher voice parts. Style learned from one or several songs should become a
reusable input for generation and subsequent selective merges/blends, retaining
source evidence and lineage. This is an architectural requirement; core audio
fundamentals remain the priority. See [layered style](docs/LAYERED-STYLE.md) for
current support, planned contracts and acceptance criteria.

The intended learning unit is a style corpus, such as chillwave, stoner rock or
lofi, accumulated from many hours across recordings. A learned style must remain
reusable for generation and later blends. Short WAV excerpts are development
probes; they do not establish genre-level learning. See the
[long-source requirements](docs/LAYERED-STYLE.md#learning-a-style-from-many-hours).

The initial three names are user preference labels for development tests, not
claims to define their genres for everyone. They exercise the reusable core;
none is required for its basic function. Judge a resulting style against the
user-selected source evidence and declared listening and musical criteria;
do not infer universal genre traits from a label or compilation description.
Independent material is still required for an accepted reusable result. Seek
the user's judgment at substantial listening or design checkpoints, while
routine timed annotations and engineering checks use other supported evidence.
The user's listening priority is Pythian-synthesized output. Qualify recorded
dataset labels from publisher methods, source integrity and independent
acoustic evidence; do not make routine microclip labeling by the user the
default path to recorded acceptance.

The [north-star milestones](docs/MILESTONES.md#north-star-assessment) own the
current completion assessment. The [task catalog](docs/TODO/README.md) owns the
dependency-linked work items under [TASKFLOW.MD](docs/TASKFLOW.MD). Completed
implementation is summarized there by goal; detailed evidence stays in the work
record and topic pages. Reassess the full intended scope when evidence changes it.

## Pascal-only inference boundary

All new learning and inference execution, including experimental probes, uses
Pascal-owned implementation with FPC/RTL. This applies to observations, analysis,
model execution, codecs, validation and maintained tools. Do not execute through
a TensorFlow, ONNX, HDF5 or other third-party inference runtime. OS/compiler services
under FPC are platform facilities, not alternative inference implementations.
The portable core remains independent of WFC, hosts and playback devices.

The user permits one-off, external media acquisition and conversion to WAV for
private development inputs. Such converters stay outside the repository and do
not become maintained codecs, product dependencies, analysis or inference paths.
Pythian consumes the resulting WAV through its Pascal-owned readers and learners.
Keep source-specific private media and conversion artifacts under ignored `build/`.
Revisit this boundary if a compressed-media importer becomes a supported library
feature; it would then need Pascal-owned implementation and validation.

The former Win64 TensorFlow C adapter and its measured execution evidence are
retained as historical provenance in [native inference](docs/NATIVE-INFERENCE.md)
and [provenance](docs/PROVENANCE.md#optional-native-observation-adapter). They do
not qualify a Pascal-only producer. The historical Beat This! ONNX Runtime
reference in [beat tracking](docs/BEAT-TRACKING.md#learned-model-reference) is
also retired; its scores are development history, not a current inference path.
The [selective Pascal backend](docs/TODO/DONE/NS-3_validation_03.md)
passes controlled and source-bound recorded gates for its two NS-3 points.
The [practical Pascal inference task](docs/TODO/DONE/NS-3_validation_02.md)
passes maintained WAV execution, long-source cost, supervision and replay for
its remaining three NS-3 points. Preserve notices and exact source lineage.
Raw pitch or salience observations are not admitted
notes or learned musical roles. The first Pascal periodic-support probe failed
recorded specificity and remains rejected.

## Development format policy

This is a fresh library. Keep one current native format for each distinct
artifact contract during development; temporary revisions are not permanent
compatibility commitments. Consolidate superseded readers/writers and regenerate
development fixtures when a schema changes. Optional capabilities belong in the
current format, not separate historical format branches.

Retain a version, subset or adapter only when it serves a concrete consumer,
interoperability requirement or materially different contract. Record that value
and the supported scope before adding a compatibility path. A current format
identifier and measurement-policy identifiers remain useful for validation and
reproducibility; they do not imply support for every earlier development encoding.

## Scoped source-layout exception

`src/pythian.midi.smf.pas` retains the compact conditional/loop layout of
WFC's reviewed SMF codec to keep the initial extraction directly comparable.
Names and unit ownership are native Pythian; full notices remain. This exception
applies only to that port's existing layout, not new units or algorithms.
Complete canonical-byte parity with the actual WFC codec and independent
malformed-file fixtures are recorded in [MIDI evidence](docs/MIDI.md#verification).
Revisit the layout when the codec's behavior next changes, keeping the parity
fixtures for the shared contract.
