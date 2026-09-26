# Reusable context-learning bundles

[Home](../README.md) · [Musical context](MUSIC-CONTEXT.md) ·
[Layered style](LAYERED-STYLE.md) · [Work](WORK.md)

## Owned evidence and actual models

`pythian.wfc.context.archive.TContextLearningBundle` groups the two existing
key/tempo provider models with the admitted excerpts that produced them.
Each `TContextEvidence` retains a UTF-8 name, lowercase exact-source SHA256,
nonnegative `SourceFrameOffset`, nonempty admission-policy text and the complete typed PPQ grid. Grid source
offsets and excerpt boundaries survive; no implicit concatenation occurs.
The frame offset identifies the source frame corresponding to clock tick zero.
It defaults to zero for absolute source clocks. A tracked range can start its
relative clock at a measured pulse without rounding away that source position;
its grid start tick remains relative to this explicit origin.

Construction copies all nested arrays and learns both models through actual
WFC, with independently selected orders 1..4. Inputs may be released afterward.
`CopyEvidence` returns detached nested arrays, and `CopyModel(Dimension)`
returns a caller-owned actual model that outlives the bundle. `ModelText`
returns canonical text. PPQ, step and both orders are explicit read-only
properties. Models and evidence cannot be mutated through borrowed references.

A source hash is an identity claim about external bytes. The library does not
possess those bytes and cannot establish the correctness of their labels.
Admission policies are stored descriptions, never executed code. An unknown
key remains unknown. Selected tempos remain exact microseconds per quarter.

Limits are 4096 excerpts, 65536 total cells, 4096 UTF-8 bytes per name/policy
and 4 MiB total metadata. Existing context validation, common PPQ/step and WFC
model limits still apply. Duplicate excerpts are retained and contribute again;
there is no silent deduplication or equal-song weighting.

## Persistence and loading

The current development layout includes the source frame offset. Regenerate
earlier `.ptc`, `.pcp` and containing `.pys` artifacts; no historical reader is
retained. This consolidates the current contract under the
[development format policy](../PROJECT.md#development-format-policy).

`EncodeContextLearning(Bundle)` returns detached bytes.
`DecodeContextLearning(Bytes)` returns an owned bundle. Loading checks the
digest, versions, field extents, metadata and typed grids, then rebuilds both
models with the actual versioned WFC learner. Both canonical model texts must
match their saved counterparts exactly before publication. This catches
structurally valid evidence/model disagreement as well as damaged files.

This deliberate replay performs WFC learning during load. It performs no WAV
analysis, tonal ranking, pulse detection or policy execution. It retains enough
admitted evidence for model replay rather than requiring access to the original
audio or silently trusting an unattached model. A learner-version or canonical
model change rejects; automatic migration is not provided.

The standalone `.ptc` archive is bounded to 16 MiB including its trailer.
It does not require an acoustic/FFT corpus envelope, so symbolic and explicitly
authored context can use the same contract.

| Payload order | Encoding |
| --- | --- |
| Magic | Four bytes `PTC1` |
| Contract versions | Archive, native context, WFC context, WFC open model, learner and text versions |
| Orders and count | Key order, tempo order, excerpt count |
| Each excerpt | Name, source SHA256, source frame offset, policy; PPQ, source start tick, step, cell count; all key/tempo pairs |
| Models | Canonical key model text, then canonical tempo model text |
| Trailer | 64 lowercase ASCII SHA256 hex bytes over the entire preceding payload |

Integers are nonnegative little-endian u32 values limited to signed Integer
range. Text is u32 byte length followed by exact bytes. Each cell has two u32
values: key code 0..23 (root*2 + mode), or 24 for unknown, followed by tempo
microseconds per quarter. Counts and remaining bytes are checked before array
allocation. Trailing payload bytes reject. The digest binds payload integrity;
it is not a signature or proof that admitted musical labels are accurate.

## Reuse boundary and evidence

This is a reusable **key/tempo learning bundle**, not a complete style profile
or generation-resume checkpoint. It does not contain voice models, joint
constraints, selected output pins, solver state, per-layer weights or derived
blend lineage. A caller can inspect/copy its admitted evidence or use its two
models as providers; a future blend API must reconcile timing, joint evidence
and ancestry explicitly. No claim of automatic WAV style extraction follows
from saving the bundle.

The separate [context profile format](CONTEXT-PROFILES.md) now wraps these
bundles and records repeated per-dimension selections with complete parent
history. It leaves the bundle format unchanged. General weighted/joint style
combination and inference remain outside both contracts.

The existing `pythian.context.demo OUTPUT_PREFIX` now writes two exact authored
context declaration files and `OUTPUT_PREFIX.ptc`. It frees original evidence
and models, reloads the archive from disk, checks canonical re-encoding, checks
the external declaration bytes against saved source hashes, and obtains model
copies. It frees the restored bundle before using those models in all four
actual dependent-pass and native rendering combinations.

The current demo additionally saves and reloads two-stage context selections
before obtaining its provider models; see [the later profile evidence](CONTEXT-PROFILES.md).
The bundle, declaration files and four rendered WAVs retain their earlier bytes.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs are under
`build/context-archive-{stable,trunk}/`. The focused archive fixture covers
single/multiple excerpts, separate model orders, nested ownership, exact
binary/model replay, model copies surviving bundle destruction, rejected
version/count/trailing/truncated inputs, and changed valid key evidence with a
recomputed digest. Failed decoding preserves a previously assigned bundle.
The demo verifies source/timing/model reuse and exact rendered durations.
Both compilers produce identical archive/declaration/WAV bytes, and all four
WAVs match the earlier direct-learning outputs. Comparisons and hashes are in
`build/context-archive-replay.log`. The authored bundle SHA256 is
`5ecd85bda1061e8da2373356e42fffe828938198436104b25dd55046f1fa827b`.
Normal builds include this fixture and demo. Existing package ZIPs predate
this adapter; no new full-suite or extracted-package result is claimed.
