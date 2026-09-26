# Persisted acoustic corpora

[Home](../README.md) · [WAV learning](WAV-LEARNING.md) ·
[Architecture](ARCHITECTURE.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

The optional [activity and continuity workflow](ACTIVITY.md) derives onset
candidates and plans source-continuous grains from these saved measurements.
The [joint workflow](JOINT.md) derives a paired acoustic/activity WFC model and
preserves both labels during reconstruction, while retaining this archive format.
The separate [joint attachment](JOINT-ARCHIVE.md) now persists that model and
its exact activity policy for generation without learning. It uses its own
attachment contract and explicit commands; acoustic-only archives stay compatible.

## Train once, generate later

`pythian.archive` provides native shared-corpus training, inspection and remixing:

```text
pythian.archive learn OUTPUT.pyac [--provenance TEXT] INPUT.wav [INPUT.wav ...]
pythian.archive inspect INPUT.pyac
pythian.archive remix INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES SOURCE.wav [SOURCE.wav ...]
```

Build it with the ordinary full build. `learn` analyzes each recording separately,
then trains one palette over their combined features. Each source remains a
separate WFC sample; no observation crosses a file boundary. Default analysis
is 4096-frame windows, 1024-frame hops and RMS silence threshold 0.0001.
The tool uses at most 16 palette tokens and WFC order 2. Library callers can
select analysis parameters, 1..32 tokens and companion orders 1..4.

`--provenance` sets a bounded UTF-8 description for subsequent sources until
the next such option. Include the source title, creator, license and reference
URL where applicable. This is caller-supplied attribution, not automatic license
verification. A missing description remains empty. The archive always stores
the source display name, complete-file SHA256, format and frame count.

`inspect` validates the archive and its WFC attachment before printing a compact
JSON description. `remix` loads the saved model and corpus, matches explicitly
provided WAV files to stored SHA256 values, solves through WFC, and reconstructs
nearest-center recorded grains. Input file order may change: hashes determine
source indices. Stored display names and provenance are never opened as paths
or fetched as URLs. All archived sources must be supplied exactly once.

The output WAV sidecar records the archive hash, source identities and attribution,
selected grain count per source, seed, solver versions and exact source/output
frame coordinates. A changed source file rejects before output publication,
even if only its WAV metadata changed. The loaded path performs no FFT, palette
training or model learning. It does recompute descriptor assignments and validate
stored model observations as part of admission.

## Core ownership and bounds

`pythian.corpus` owns immutable source metadata, copied measurement/token arrays,
one detached palette, and nearest-center representative coordinates. Constructor
and training outputs are caller-owned. Accessors return detached arrays;
`CopyPalette` returns a caller-owned palette. External audio clips are borrowed
during training or reconstruction and are not embedded in the archive.

The corpus admits 1..32 nonempty recordings with one common sample rate and
channel count. No implicit resampling, downmix or channel conversion occurs.
Duplicate file hashes reject rather than silently biasing training weights.
Across the complete corpus, there are at most 64 million scalar source samples,
65536 feature frames and two billion estimated FFT work units. Individual
analysis limits also apply. Training resets flux history at each source boundary.

Admission validates the complete expected feature grid, partial terminal window
lengths, finite measurements, RMS/peak relation, centroid range, normalized
chroma and silence consistency. Each saved token must equal the nearest center
for its saved measurements. Stored centers are restored directly from binary64;
they are not recomputed by clustering. These checks establish internal
consistency, not proof that an arbitrary author's measurements were derived
from the claimed audio. The native training tool obtains them from the exact
hashed bytes; the remix tool independently verifies those bytes again.

Representative selection uses the closest assigned feature over all recordings,
with source/frame order breaking exact ties. Empty clusters have no exemplar
and reject if explicitly requested. Partial final windows keep their actual
valid length. This extends the original deterministic grain policy to shared
vocabularies. The optional [continuity planner](ACTIVITY.md#continuity-constrained-reconstruction)
adds measured overlap and source-adjacency costs without changing this default.

## Archive format v1

`pythian.corpus.archive` implements a bounded binary format with an optional
opaque attachment. All fields have explicit order:

| Field | Representation |
| --- | --- |
| Magic | Four bytes, ASCII PYAC |
| Corpus / analysis / learning versions | Three little-endian 32-bit integers, currently 1 / 1 / 1 |
| Analysis options | Window and hop integers, then silence threshold binary64 |
| Palette | Count integer, then 15 binary64 components per center |
| Recordings | Count integer, then each recording in input order |
| Recording identity | Name, lowercase source SHA256, provenance; then sample rate, channels, source frame count |
| Recording observations | Count integer, then each observation in chronological order |
| Observation | Start frame, valid frame count, token, silent flag; then RMS, peak, centroid, flux and 12 chroma components |
| Attachment | Contract text, byte count, exact opaque bytes |
| Integrity trailer | 64 lowercase ASCII hex bytes: SHA256 of every preceding byte |

Integers occupy four bytes and must be 0..2147483647. Boolean values are 0 or 1.
Reals use IEEE binary64 in little-endian order; non-finite bit patterns reject
before floating-point arithmetic. Text uses a length integer followed by valid
UTF-8, at most 4096 bytes without NUL. The SHA256 source identity has exactly
64 lowercase hex characters. Each observation occupies 144 bytes.

The complete archive is at most 32 MiB; the attachment is at most 16 MiB.
An attachment has both a nonempty contract and nonempty bytes, or both are empty.
Version mismatch, invalid lengths, invalid coordinates, trailing payload bytes,
checksum mismatch and semantic inconsistency reject. The SHA256 trailer binds
the corpus and attachment against corruption; it is not an authenticity signature.

`pythian.hash` consolidates the Phanes-derived SHA256 helper using the standard
FPC `FpSHA256` unit. That unit and the archive path have been exercised with
the installed FPC 3.3.1 toolchain. The intended FPC 3.2.2 compatibility gate,
including this FCL capability, remains unverified.

The old `pythian.learn` JSON sidecars are inspection artifacts and are not
silently accepted as v1 archives. The existing one-shot commands remain available.

## WFC attachment and admission

`pythian.wfc.corpus` packages the real WFC sequence text under attachment contract
`pythian.wfc.sequence.v1`. The core never interprets WFC types or text.
`EncodeWfcAcousticCorpus` trains the actual WFC learner and stores its canonical
text; `DecodeWfcAcousticCorpus` uses WFC's own decoder and retains the saved
state order and counts.

An independent admission pass checks the open boundary, model order, public
tokens, recording lengths, every observed history/emission state, raw state
counts and start/end counts against the stored corpus. A bounded base-33 lookup
uses at most 33^4 integers, about 4.6 MiB. It does not rebuild a model or invoke a
solver. A structurally valid WFC model with a valid checksum still rejects when
its observations disagree with the corpus. Failed loading returns no corpus
and clears the output model.

Floating-point descriptor evaluation remains compiler/target dependent.
Binary64 round-trip is exact, but cross-platform training/replay parity is not
claimed; near-tie assignments on another target can cause admission to reject.

## Verification and current limits

Logs: `build/corpus-validation.log` (full build),
`build/corpus-core-build.log` (all core units without vendor search paths),
`build/corpus-core-validation.log` and `build/corpus-wfc-validation.log`
(focused development checks).

Fixtures cover complete byte round-trip, detached ownership, selection from
both recordings, exact grain-coordinate replay, all truncations of a small
archive, checksum corruption, rehashed unknown versions/oversized counts/NaN,
invalid feature coordinates and token assignments. WFC fixtures cover orders
1..4, full model admission, independent repeated loading, exact token/audio
replay, and a valid-but-mismatched companion model.

The two [published WAV recordings](WAV-LEARNING.md#published-recording-evidence)
were learned together with attribution retained. Native evidence:

- 5353 complete source observations, 16 shared tokens, order 2, 133 WFC states.
- Archive `build/corpus/shared.pyac`, SHA256
  `5405acab822bbfdd1d5534987b70ebac066a77ba5da91b48b126a8e97a3072c4`.
- Seed 731, 512 grains: 152 selected from Pixel Sprinter, 360 from Opening Theme.
- Output `build/corpus/shared-remix.wav`: 527360 stereo frames at 44100 Hz
  (11.958 seconds); L/R peak 0.51749/0.48654, RMS 0.10182/0.10511.
- Output SHA256 `bff6e8c2627369c4572c26b0036a30cf1ea333da9f0da4154c7dba0953abd07e`.
  A separate load with reversed input-file order reproduced it exactly.
- Supplying an unrelated WAV rejected and preserved the existing output hash.
- The one-source archived demo reproduces the earlier one-shot remix bytes:
  SHA256 `42842522b6f192343753f66d83204a77270f897de7f00acb8186f2b2e19903ed`.

Source files and generated archives/audio remain in ignored build output.
The [manifest](../tests/fixtures/wav-corpus.json) retains the portable source
identities and shared-run evidence. Detailed native reports are in
`build/corpus/shared-*.log`, `shared-inspect.json`, `shared-metrics.json`,
and `source-mismatch.log`.

File writes can still leave partial files on I/O failure. A truncated archive
will reject on load, but replacement is not yet atomic and the WAV/JSON output
pair is not a transactional publication. General music quality, operator
listening, beat alignment, general onset accuracy, long-form continuity, MIDI/WAV musical alignment,
mixed-rate conversion and broader compiler/platform coverage remain open.
