# Persisted joint acoustic/activity models

[Home](../README.md) · [Joint generation](JOINT.md) · [Corpus format](CORPUS.md) ·
[Articulation](ARTICULATION.md) · [Work](WORK.md)

## Train once, reuse the actual paired model

[pythian.wfc.joint.archive](../adapters/wfc/pythian.wfc.joint.archive.pas)
saves an already trained joint model together with its measured corpus and
complete activity policy. Loading performs no FFT, palette training or WFC
learning. It recomputes activity labels from the stored features to validate
the persisted model independently.

The core PYAC archive format remains unchanged. Its opaque attachment uses
`pythian.wfc.joint.v1`, distinct from the existing acoustic-only attachment.
Each file contains one model kind. Existing acoustic archives retain their
original bytes and loader. The joint file carries its own complete measured
corpus, source identities and attribution; it does not require the original
acoustic archive for later generation. Both paths retain WFC as the companion.

## Native workflow

```text
pythian.archive prepare-joint INPUT.pyac OUTPUT.pyac [ORDER]
pythian.archive inspect-joint INPUT.pyac
pythian.archive remix-saved-joint INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES ACTIVITY_PATTERN SOURCE.wav [SOURCE.wav ...]
```

`prepare-joint` reads an acoustic-only archive, learns a paired WFC model from
stored features and tokens, independently validates it and saves the joint
archive. It uses the default activity policy and inherits the acoustic model's
order unless an explicit order 1..4 is supplied. It does not rerun FFT or train
a new palette. The input archive and output must have different paths.
Library callers can supply custom activity options and an existing trained model.

`inspect-joint` admits the stored model before reporting its attachment,
exact archive/model hashes, source metadata, paired vocabulary size and
complete activity policy.

`remix-saved-joint` admits the stored model, solves actual WFC paired-token
constraints and uses the stored activity policy in the action-aware continuity
planner. No learner is called on this path. Every original WAV must be supplied
once, in any order; the existing exact SHA256 binding selects source indices.

Pattern and solver semantics are those of [joint generation](JOINT.md):
`a`, `h`, `r` and `?` constrain a literal prefix of analysis-hop cells.
There is no implicit repetition, beat detection or output silence guarantee.
Use the separate [output articulation stage](ARTICULATION.md) for explicit
PPQ/MIDI gates after reconstruction. Unsupported model attachment kinds reject;
there is no automatic retraining fallback.

The output sidecar records `loaded_without_learning=true`, the admitted model
text/hash and the exact stored policy alongside every source-grain mapping.
The older `remix-joint` command remains available and derives its model each
time, reporting `loaded_without_learning=false`.
The [timed remix workflow](TIMED-LEARNING.md) additionally projects explicit
PPQ/MIDI gate attacks onto source-onset constraints and applies output gates,
reusing this saved model and policy without changing the attachment contract.

## Library and ownership

`EncodeWfcJointCorpus(corpus, model, activity)` admits and saves an existing
trained model. The corpus and model remain borrowed and unchanged.

`DecodeWfcJointCorpus(bytes, out model, out activity)` returns a detached
caller-owned corpus and model. Failure frees partially decoded objects, sets
model to nil, clears the activity record and raises. Callers must pass the
returned activity policy to subsequent action-aware planning; the CLI does
this explicitly. Existing objects should be held separately from output
parameters when an application needs to preserve its previous state.

`ValidateWfcJointCorpusModel(corpus, model, activity)` is also public. It checks:

- Order 1..4, open boundaries, source count, observation total and every
  individual recording length.
- Canonical paired token encoding and palette membership.
- Every observed n-gram, including leading beginning-of-sample markers,
  its frequency and its start/end counts.
- Missing, duplicate and unused paired states or vocabulary entries.

The validator independently counts observations rather than calling a learner
and comparing its output. It derives activity separately for every recording.
All counts remain separated at recording boundaries.

State lookup uses sorted observed integer keys and binary search, with
O(states) auxiliary memory and O(log states) lookup. The fixed alphabet is
96 possible pairs plus a beginning marker; four base-97 digits fit signed
32-bit integers. A dense 97^4 table is not allocated. The WFC model retains
its own bounded state/text contracts and serialization; validation does not
reorder or alter the saved model.

## Attachment bytes and versions

The existing outer archive digest covers all corpus and attachment bytes.
The joint attachment has a 48-byte header followed by canonical WFC sequence
text. Offsets are zero-based:

| Offset | Encoding | Meaning |
| --- | --- | --- |
| 0 | 4 ASCII bytes | JNT1 |
| 4 | u32 little-endian | JointAcousticVersion, currently 1 |
| 8 | u32 little-endian | AcousticActivityVersion, currently 1 |
| 12 | IEEE binary64 little-endian | MinimumFlux |
| 20 | IEEE binary64 little-endian | AdaptiveMultiplier |
| 28 | u32 little-endian | HistoryFeatures |
| 32 | u32 little-endian | PeakRadius |
| 36 | u32 little-endian | MinimumSeparationFeatures |
| 40 | u32 little-endian | MaximumSegmentFeatures |
| 44 | u32 little-endian | Exact following text byte length |
| 48 | WFC canonical text bytes | Actual paired model |

Integers must fit signed Integer and their respective policy ranges. Both
floating-point fields retain their exact bits and must satisfy finite activity
bounds. Unknown contracts/versions, invalid options, truncated headers,
length mismatches and trailing attachment bytes reject. Total attachment size
remains at most 16 MiB and the entire outer archive at most 32 MiB. Text loading
uses the real WFC decoder and requires identical canonical re-encoding.

A valid digest or structurally valid WFC model is insufficient for admission:
stored model counts must agree with the measured corpus under the stored
policy. Different option values that produce the same labels can validly
describe the same model; the options themselves remain stored exactly.

Computation and encoding finish before file publication. Input, validation or
solver rejection preserves existing outputs. File replacement and WAV/sidecar
publication remain ordinary writes; an I/O failure can leave partial output.
Atomic artifact replacement remains a separate delivery task.

## Verification

The focused [archive fixture](../tests/pythian.tests.wfc.joint.archive.lpr)
covers all four model orders, every custom activity field, canonical archive
bytes, exact paired-token/audio replay and action-aware planning. Adversarial
attachments receive newly valid outer checksums: unknown versions, invalid or
nonfinite options, trailing/truncated data, wrong contracts and a structurally
valid WFC model with wrong activity labels must reject. A separately learned
model with altered observation frequencies must reject before saving.

The tampering fixture uses WFC's own token-escape encoder and checks that its
target exists before changing it. The published-coordinate checker in
[the joint fixture](../tests/pythian.tests.wfc.joint.lpr) additionally binds the
actual saved model and all activity options to the generated metadata.

On 2026-09-14, FPC 3.3.1-20634-gd7f522a561 for i386 Windows passed
`./tools/build.ps1`: 38 standalone core units, eight WFC adapters, existing
native/WFC fixtures and all three new archive commands. The core compiles
without vendor source paths. Log: `build/joint-archive-validation.log`.
Focused fixture: `build/joint-archive-focused-validation.log`; final published
checker compilation: `build/joint-archive-mapping-compile.log`.
An isolated heap-traced run of every archive success/rejection fixture freed
all 44324 allocations, with zero unfreed blocks:
`build/joint-archive-ownership-validation.log`. No authored compiler warnings.

The two attributed CC0 recordings in the [joint evidence](JOINT.md#verified-evidence)
were prepared and replayed with:

```text
pythian.archive prepare-joint build/corpus/shared.pyac build/corpus/shared-paired.pyac
pythian.archive inspect-joint build/corpus/shared-paired.pyac
pythian.archive remix-saved-joint build/corpus/shared-paired.pyac build/corpus/shared-saved-joint.wav 731 512 a???h build/corpus/pixel-sprinter.wav build/corpus/opening-theme.wav
pythian.tests.wfc.joint build/corpus/shared-paired.pyac build/corpus/shared-saved-joint.wav.json build/corpus/shared-saved-joint.wav build/corpus/shared-joint.wav.json
```

The saved model retains 5353 observations, 30 paired tokens and 243 states.
All 512 source-grain records match the earlier derived-model mapping exactly:
57 onset and 455 sustain observations, with source-use counts 189/323 and
341 contiguous links. The WAV is byte-identical to that earlier reconstruction:
527360 stereo frames at 44100 Hz. Reversing source arguments reproduces both
WAV and metadata bytes. An unobserved silence request rejects and preserves
both previous files. The original acoustic archive still validates unchanged.

| Artifact | SHA256 |
| --- | --- |
| Joint archive | `321de68d103e55943f117326cf83271df3ab8539f22f9f310f9c31d00136e0be` |
| Original acoustic archive | `5405acab822bbfdd1d5534987b70ebac066a77ba5da91b48b126a8e97a3072c4` |
| Actual paired WFC model | `25cc734ffadf09430dc814fd833964133fa7da7bdda826abe9bd3783100da382` |
| Reconstructed WAV | `8776a742a772a5414c9b310ee1da5807002a9017314ad3ed3d43a40e9194a9e1` |

Evidence: `build/joint-archive-published-validation.log`,
`build/corpus/shared-paired-prepare.log`, `build/corpus/shared-paired-inspect.json`,
`build/corpus/shared-saved-joint.log`, `build/corpus/shared-saved-joint-replay.log`
and `build/corpus/shared-saved-joint-rejection.log`.

These checks establish saved-model admission and replay. Operator listening,
annotated source beat/onset accuracy, broader corpus coverage, stable FPC 3.2.2
and other targets remain unverified. The full synthesis and WAV music-learning
goal remains open.
