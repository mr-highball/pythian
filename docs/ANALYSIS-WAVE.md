# Bounded WAV analysis

[Home](../README.md) · [WAV input](WAVE-READING.md) ·
[Learning](WAV-LEARNING.md) · [Work](WORK.md)

The native analysis engine now accepts a window source as well as a complete
clip. The standalone WAV learner uses that boundary to avoid retaining either
the complete encoded file or a decoded clip. FFT features, acoustic palette
training and actual WFC learning keep their existing semantics.

## Spectral power partitions

[pythian.spectrum](../src/pythian.spectrum.pas) supplies
`PartitionPowerSpectrum(Power, Bands, FirstBin, LastBin)` for callers that need
frequency-localized evidence from an existing power spectrum. It returns total
scoped power, one summary per requested band and a complementary gap before,
between and after the bands. Each summary retains inclusive bin bounds, summed
power, the strongest positive bin and its power. Positive peak ties choose the
lowest bin; empty or zero-power regions use peak bin -1. Empty gaps have
`LastBin = FirstBin - 1`.

The caller supplies finite nonnegative bin powers and chooses the spectrum's
normalization, channel/window policy, frequency mapping and DC treatment. For
example, scope `1..N div 2` excludes DC in an ordinary positive-frequency FFT
power array. The query performs no FFT, windowing, one-sided doubling, frequency
estimation or noise/harmonic classification. A gap means unselected bins, not
automatically noise. Use `bin * sampleRate / N` for FFT-bin frequency when that
is the caller's declared transform geometry.

Inputs contain 1..32769 bins and 0..128 bands. The inclusive scope must be valid;
bands must be nonempty, ordered, disjoint and wholly inside it. Zero bands leave
one gap covering the scope. Callers clip or reject frequency requests before
constructing bin ranges. Every input power, including bins outside the scope,
must be finite, nonnegative and at most `MaxDouble / (4 * inputBinCount)` to keep
accumulation bounded. Work is linear in input/scoped bins plus bands. This offline
query allocates bounded result arrays and returns detached results; invalid input
preserves the inputs and a previously assigned result. Ordinary Pascal record
assignment can still share dynamic-array storage between caller-held copies.

The maintained [spectrum fixture](../tests/pythian.tests.spectrum.lpr) checks known
power conservation, residual geometry, positive/zero peaks, adjacency, maximum
sizes, rejected bounds/nonfinite inputs and managed-result ownership. Checked
stable Win32/Win64 and development Win32 runs pass with zero reported leaks.
The [recorded residual study](PHRASE-EVALUATION.md#spectral-partition-checkpoint)
uses this public query over 652 spectra and reconciles its harmonic powers with
the prior independent band loops. Evidence is under `build/spectral-partition/`.
No saved analysis/style format or existing feature semantics change. Packages
predating the new unit need the [current-source refresh](MILESTONES.md#wav-05-delivery).

## Interfaces and ownership

`TAudioAnalysisSource` in [pythian.analysis](../src/pythian.analysis.pas) declares
immutable sample rate, channel count and frame extent. Its `ReadWindow`
implementation supplies exactly the requested interleaved samples. The engine
validates their count and finiteness, then treats them as read-only. The source
must remain stable during the call. Custom source exceptions propagate.
`AnalyzeAudioSource` publishes features only after complete success; failed
analysis preserves the caller's previously assigned feature array.

`AnalyzeAudio` wraps a borrowed immutable clip through this same engine.
There is one implementation of Hann windowing, per-channel power aggregation,
RMS, peak, centroid, positive spectral flux and chroma. Partial final windows
remain zero-padded, with RMS computed over valid samples only.

`AnalyzeWave` in [pythian.analysis.wave](../src/pythian.analysis.wave.pas) borrows
a `TWaveFrameReader` and analyzes its entire audio from frame zero. It caches
the previous window's overlapping tail, reads only missing frames and reuses
cached samples in partial final windows. Temporary sample storage scales with
window size, not recording duration. The reader remains caller-owned and
normally ends at EOF; source failures retain the reader's existing poisoned
state contract. Invalid options reject before consuming windows.

For these whole-result calls, this is bounded input storage, not an unlimited
or real-time analyzer.
Features are still returned together. Existing limits remain: mono/stereo,
64..16384 power-of-two window frames, hop 1..window, at most 65536 observations
and 2000000000 planned FFT work units. Source geometry is limited to 64000000
frames; the standalone learner additionally retains its former 64000000 scalar
sample cap and 256000044 encoded-byte cap.

## Batches and source coordinates

`AnalyzeWaveBatch(reader, options, firstFeature, maximumFeatures)` supplies bounded
observations from a long RIFF/RF64 source. It uses the same feature engine as the
whole-result APIs. The default maximum is 1024 observations; each call retains
the existing FFT-work limit, including its context observation. The caller can
release a completed batch before requesting the next one. No whole-recording
feature array or decoded sample buffer is allocated.

`TWaveFeatureBatch` returns:

- `FirstFeature` and `NextFeature`: Int64 indices on the source's hop grid. Use
  `NextFeature` for the next request; the interval is half-open.
- `SourceStartFrame`: the Int64 source origin of the batch. Add each feature's
  local `StartFrame` to recover its absolute sample coordinate. For an empty
  completed batch this origin is the source's exact frame count.
- `Features`: emitted observations only, including valid sample counts for
  partial windows at the actual source end.
- `Completed`: all source observations have been emitted. Requesting the final
  `NextFeature` again returns an empty completed batch.

Every noninitial batch reconstructs the preceding spectrum so that positive flux
agrees with uninterrupted analysis. That context observation is not emitted or
counted again. Windows extend across batch boundaries; zero padding occurs only
at the actual source end. The preceding spectrum is reconstructed even when its
reported feature was silent, preserving the existing engine's flux semantics.
Changing batch size or reopening an unchanged source does not change observations.
Batch boundaries do not declare song boundaries or reset musical history.

`AnalyzeAudioSourceRange` exposes the same feature-index range behavior for
existing custom window sources. Their local source geometry remains bounded;
the WAVE batch adapter maps long Int64 coordinates into these bounded ranges.
Both APIs validate budgets before reading samples. Source failures can advance
or poison the borrowed reader; failed calls preserve a previously assigned result.

The caller must bind resume indices to exact source identity and analysis options.
This API does not persist checkpoints, commit observations or aggregate a palette.
Those consumers must verify source hash/geometry and analysis policy, commit a
batch before advancing its durable index, and reject gaps or duplicate indices.
The [feature journal](#persistent-feature-journal) now supplies that storage and
recovery boundary. An explicitly declared new song starts its own musical history;
song segmentation and aggregation remain linked work in [WAV-04](MILESTONES.md#wav-04).
Existing saved corpus and learner limits remain in force; a long-source analysis
pass alone is not a learned many-hour musical style.

## Persistent feature journal

`TFeatureJournal` in [pythian.analysis.journal](../src/pythian.analysis.journal.pas)
stores measured acoustic features before palette/model training. This is one current
`.pyaf` cache contract, distinct from the finished `.pyac` corpus/model archive.
It supports bounded append and replay without requiring all observations or audio
in memory. It is not a second style format, and no historical journal readers are
retained. Incompatible development caches should be regenerated.

The binding contains the exact source SHA256, sample rate, channels, Int64 frame
count, current analysis version and window/hop/silence options. A batch size is a
processing choice, so it does not change that binding. Callers must verify source
identity; the journal cannot establish it from a pathname or supplied digest alone.

The journal borrows a seekable stream exclusively from byte zero and requires an
explicit commit callback. A file-backed callback flushes the file handle; an
in-memory consumer can explicitly provide a no-op. Source/stream stability and
sequential, non-reentrant use are required. `Append` validates and encodes a complete
batch before writing. It advances `NextFeature` only after the checksum and commit
callback succeed. A write or flush failure poisons the instance; reopen the stream
to discover what was completely stored. A complete record may survive a reported
flush failure, so resumed progress comes from verified records rather than the last
caller acknowledgment.

Opening verifies the binding, chain, feature geometry and checksums in bounded
records. It performs no writes. `TailBytes` reports an incomplete final record;
`RecoverTail` explicitly truncates just that tail and commits the truncation.
Complete corrupt records, invalid counts/order, changed bindings and nonempty
partial headers reject without repair. A fresh empty stream can initialize a
journal. A damaged nonempty header has no trusted source-bound progress and
requires a new cache. `Rewind` / `ReadNext` replay committed batches for consumers;
EOF preserves the previously assigned batch. Duplicate or skipped observation
ranges reject before writes.

The current encoding uses little-endian integers, finite IEEE binary64 feature
values and lowercase ASCII SHA256 digests:

| Component | Stored fields | Bytes |
| --- | --- | --- |
| File header | `PYAFJ001`, analysis version, source geometry/hash, analysis options and header digest | 172 |
| Batch header | Int64 first index, count, preceding digest, header digest | 140 |
| Each observation | Valid frames, silence flag, RMS, peak, centroid, flux and 12 chroma components; coordinates derive from the bound hop/index | 136 |
| Batch trailer | Digest of the complete batch header and payload | 64 |

Counts are limited to 4096 observations per stored batch. Header checksums validate
counts before they determine a payload allocation. The preceding digest and next
index detect missing/reordered middle records. An incomplete final header, payload
or digest can be removed; a complete digest mismatch cannot. Checksums detect
corruption, not authenticate a producer. Storage capacity scales with observation
count, while working memory remains bounded. Opening scans the existing cache;
there is no unverified fast-resume index.

## Cache command

```text
pythian.learn cache INPUT.wav OUTPUT.pyaf [--batch-features N] [--max-batches N]
```

This command creates or resumes the feature journal using default analysis options.
Batch size defaults to 1024 and may be 1..4096; zero maximum batches means continue
to source completion. A positive maximum stops after that many newly committed
batches, so the next invocation can resume with a different batch size. Reopening
a completed cache appends nothing. The JSON report identifies the binding, resume
and next indices, total observations, completion, batches appended and any removed
incomplete tail bytes. It does not report a trained palette or WFC model.

The WAV stays open denying writes where supported. The command hashes it before
opening the cache, checks the binding before recovery or append, and hashes again
after the requested work. A detected source change removes this invocation's new
observations and preserves its earlier prefix. Concurrent source modification is
unsupported. Cache opening never truncates an existing file: native open/create
and an exclusive lock prevent competing cache writers. Each accepted append and
recovery calls the native file flush. These are tested process/write-recovery
semantics; filesystem/hardware power-loss guarantees are not independently verified.

The original `pythian.learn INPUT.wav OUTPUT_PREFIX` path retains its existing
palette/model behavior and budgets. The journal-backed consumer below now trains
without collecting a whole feature/token array. Remaining source balance and
semantic style work belongs to [WAV-04](MILESTONES.md#wav-04).

## Training from journals

```text
pythian.learn journals OUTPUT_PREFIX [OPTIONS] INPUT.wav CACHE.pyaf [...]
```

The command accepts 1..32 WAV/cache pairs with matching analysis/timebase contracts.
It verifies source and cache identity, trains a shared 16-token acoustic palette
and order-2 WFC model, and writes the current WFC text model, a JSON training report
and a 128-grain WAV audition. The report includes palette centers, source/cache
hashes, analysis options, integer weights, actual/weighted observation counts,
candidate coordinates, selected slots and generation tokens. The model is decoded from its
serialized representation before generation. All content is prepared and source
identity rechecked before writing outputs; the three file writes are not an atomic
transaction. The JSON is a training report, not a new saved semantic style format.

`--multiplicity N` applies to subsequent source pairs until changed; default is one.
It means positive whole-segment integer weight. It does not add unique recordings
or automatically equalize duration, genre influence or generated source usage.
Each pair declares a separate sample. By default it includes the whole journal;
the CLI and library also support explicit nonoverlapping observation ranges.
Neither infers song boundaries inside a long mix.

### Selecting sections without copying audio

`--range FIRST_FEATURE COUNT` applies only to the immediately following WAV/cache
pair in `journals` or `fit`. Both numbers are Int64; the first index is zero-based
and nonnegative, and the count must be positive and fit the completed journal.
Repeat the same WAV/cache pair with disjoint ranges to declare separate samples
within one long recording. Omit `--range` on another pair to use its whole journal;
range selection is not sticky. Put training/generation weight options before
`--range`, not between it and its pair.

```powershell
pythian.learn journals build/sections --multiplicity 3 --range 20 140 source-A.wav source-A.pyaf --multiplicity 1 --range 200 140 source-A.wav source-A.pyaf
pythian.learn fit build/sections build/sections-fit.json 0.25 --range 20 140 source-A.wav source-A.pyaf --range 200 140 source-A.wav source-A.pyaf
```

History resets between ranges even when they share source/cache bytes. Palette
training, WFC counts, candidate selection and saved continuation use the declared
ranges; saved profiles and repeated blends retain their absolute coordinates and
weights in the current contract. Exact duplicate or overlapping observations
within a training request reject; use multiplicity for deliberate repeated
evidence. A range is not an additional independent recording.

Feature `i` starts at source frame `i * HopFrames`. Selection restricts observation
indices/window starts; it does not crop the underlying measurement window, reset
its measured flux predecessor, or create a new WAV. To exclude a neighboring
section's audio, choose observations whose windows and required predecessor
context lie within the intended section. Adjacent excerpt ranges from the same
recording do not establish a recording-level held-out split.

The command still allows at most 32 declared pairs/ranges. Each pair currently
verifies its full source/cache identity, and selected ranges scan through the
existing journal; memory stays bounded, but many ranges can repeat I/O. Replay
needs one WAV per distinct source hash, even when that source has several ranges.
Its file-level `--source-weight` override applies to every range of that source;
saved per-range weights and library segment controls remain distinct. Context
attachment takes one cache per saved range in profile order, repeating the path
when needed. See the [range checkpoint](WAV-STUDIES.md#journal-range-checkpoint).

### Reusable learning layers

The reusable layers are:

- `TAcousticVectorReader` and `TAcousticPalette.CreateFromReader` share the existing
  deterministic farthest-first initialization and eight Lloyd iterations with
  the bounded array constructor. Each pass retains only centers, weighted sums
  and counts; no whole-corpus vector array is required. The reader is borrowed,
  repeatable and immutable. Pass counts/weights must agree. Integer mass is bounded
  by 9007199254740991; per-vector multiplicity is a positive Integer. Weighted sums
  use ordinary floating-point arithmetic, so grouping repeated observations can
  change low-order rounding. Existing array entry points keep their 65536 cap.
- `TJournalTrainingReader` in [pythian.learning.journal](../src/pythian.learning.journal.pas)
  borrows completed journals and up to 4096 declared segments. It rejects overlapping
  source ranges instead of silently duplicating observations, supports explicit
  multiplicity, and preserves Int64 source/feature coordinates. `Rewind` controls
  the journals' cursors; callers must not interleave other readers. Selected ranges
  retain the journal's measured spectral context; segment boundaries reset sequence
  history, not already measured feature values.
- `LearnJournalAcousticModel` in the [companion adapter](../adapters/wfc/pythian.wfc.learning.journal.pas)
  accumulates open-boundary state, start and end counts through the public WFC model
  constructor. Its state lookup is fixed-size; token sequences are not retained.
  Orders 1..4 are supported. History crosses journal batches and resets only at
  declared segment boundaries. Multiplicity scales counts and repeated sample-length
  metadata, without rereading repeated audio. The companion's 1024-state, 4096-sample
  and Integer observation/count limits still apply; larger vocabulary/order requests
  can reject rather than discard evidence.
- `FindJournalRepresentatives` remains available for one nearest observation per
  token. The CLI uses the bounded candidate selector below and seeks only selected
  Int64 coordinates into small clips for the existing renderer. It checks headroom
  before PCM16 encoding. Whole long-source clips are never allocated by this path.

The source's fixed feature-hop clock is not an admitted musical tempo. Palette
tokens encode joint spectral/energy behavior, not independently learned voices.
Models with identical token names but different palettes are not automatically
compatible for merging; retain palette/timebase identity with any saved model.
Current multi-source training rebuilds one shared vocabulary from measured evidence.
Repeated saved semantic style blends still require the admitted providers and
contracts in [layered style](LAYERED-STYLE.md).

## Journal candidate selection

`TJournalCandidatePool` in
[pythian.learning.selection](../src/pythian.learning.selection.pas) makes one reader
pass and retains the nearest assigned observation for each token, declared segment
and temporal bin. Bins divide a segment's feature range into equal ceiling-sized
intervals; empty token/bin combinations stay empty. Ties retain the first observed
window. The cap is 65536 slots, each containing coordinates and distance, with no
retained waveform or feature history. Keep the source/palette bindings with the
pool. It can outlive its borrowed construction reader and palette.

`Select` accepts fixed palette-token indices, a weight per declared segment and a
nonnegative selection seed. It returns candidate slot indices without changing
the pool, model or tokens. Integer smooth weighted rotation adds each eligible
segment's weight to its credit, picks the highest credit (first segment on ties)
and subtracts the total eligible weight from that segment. Ineligible segments
retain their credits. Zero disables a segment; a token with no enabled candidate
rejects the whole request. Shares are soft and depend on token availability; they
are counts of selected grains, not audible energy proportions or exact quotas.

Within the chosen segment/token, the seed sets the initial bin rotation. Selection
cycles through populated bins and skips an immediately repeated window when that
segment has another candidate. A sole candidate can still repeat. The seed is an
offset, not random sampling; offsets congruent modulo the bin count are equivalent.
Requests are bounded to 4096 grains and 64 million grain × segment × bin positions.
The selector does not optimize waveform seams or infer musical phrases. The existing
whole-corpus continuity planner still requires loaded clips and is a separate path.

| CLI option | Scope and default |
| --- | --- |
| `--candidate-bins N` | Global, 1..32 bins per segment/token; default 4. |
| `--selection-seed N` | Global, 0..2147483647; default 731. Rotates candidates independently of the fixed WFC generation seed 731. |
| `--source-weight N` | Sticky for subsequent WAV/cache pairs; 0..4096, default 1. Controls generation eligibility and soft source contribution. |
| `--multiplicity N` | Sticky for subsequent pairs; 1..4096, default 1. Controls training evidence only; companion total-sample/count limits still apply. |
| `--range FIRST_FEATURE COUNT` | Only the immediately following pair; defaults to the whole journal. Declares a separate sample without copying source audio. |

The library and CLI weight declared segments, which can be complete WAVs or
selected ranges. Reports contain populated `candidates`,
`generated_candidate_slots`, source weights/use, unique selected windows, immediate
repeats, contiguous source links and source switches. Changing a generation control
does not modify the learned model. The `replay` command reloads saved candidates,
palette and model without caches or training; library callers can also reuse
the same in-memory pool/model for multiple selections.
This diagnostic report replaces its former representative list in place; no
historical reader or new persisted style format is introduced.

The CLI zero-pads partial EOF candidates to the declared analysis window before
Hann rendering. Their reported `valid_frames` remain the actual source extent.
This preserves the generated clock: `(grain_count - 1) * hop_frames + window_frames`
output frames, independently of selected source windows.

## Checked journal partition selection

`SelectJournalPartition` in
[pythian.learning.journal](../src/pythian.learning.journal.pas) returns ordinary
`TJournalTrainingSegments` for the existing reader, palette and WFC learners.
It validates the whole in-memory training/development/evaluation plan before
selecting a partition. Recording-family IDs and exposure declarations prevent
known cross-partition reuse; they do not infer recording identity or prove
independence. See the [contract and evidence](CORPUS-EVALUATION.md#library-partition-selection).
The command-line operator also accepts explicit per-pair group/exposure metadata
with `journals OUTPUT_PREFIX --partition training|development`; see the
[operator contract](CORPUS-EVALUATION.md#operator-partition-selection).
Unselected inputs are checked for integrity, but do not feed learning/generation.
There is no partition manifest reader or implicit split assignment.

## Saved journal profiles

The companion `TJournalModelProfile` in
[pythian.wfc.learning.profile](../adapters/wfc/pythian.wfc.learning.profile.pas)
loads the current journal `.json` report and actual `.wfcs` model into owned,
detached palette, candidate-pool and model objects. Its accessors are borrowed.
It performs no source or cache reads, feature extraction, clustering or training.
Source display names never authorize file access.

The report requires `vocabulary_sha256`, `model_binding_sha256` and each source's
`first_feature`. Regenerate earlier development reports that lack these fields;
there is one current reader, with no historical fallback or new binary format.
The whole-corpus `.pyac` contract is unchanged.

[pythian.learning.binding](../src/pythian.learning.binding.pas) defines the core
fingerprints. Vocabulary bytes are the ASCII domain `pythian.acoustic.vocabulary`
without a terminator, then little-endian unsigned 64-bit analysis version,
learning version, sample rate, channels, window and hop; IEEE binary64 silence
threshold; unsigned 64-bit palette count; and the ordered centers' 15 binary64
components each. Signed zero is canonicalized to positive zero. The bound-model
digest hashes ASCII `pythian.acoustic.bound-model`, followed by the 64 lowercase
hex characters of the vocabulary digest and exact serialized-model digest.

The loader checks these bindings, source/range geometry, disjoint ranges for a
shared source hash, candidate grid/bin/EOF extents, model token coverage, order,
boundary and weighted observation/sample counts. It limits each input to 16 MiB,
JSON nesting to eight levels and structural punctuation to one million characters;
validated objects have at most 64 members, sources at most 32 and palette entries
at most 32. Existing candidate and companion model budgets still apply. These
checks establish internal consistency, not authenticity or proof of measurement:
the loader does not rederive model counts or nearest candidates from journals.

```powershell
pythian.learn replay build/study build/replayed source-B.wav source-A.wav
pythian.learn journals build/new-study --palette-from build/study source-C.wav source-C.pyaf
```

Replay requires all source WAVs explicitly, in any order; byte hashes match them
to saved segments and are checked again after rendering. No `.pyaf` inputs are
needed. Defaults retain the saved generation seed, selection seed, grain count,
source weights and join policy. Overrides are `--seed`, `--selection-seed`,
`--frames` (1..1024), `--join-passes` (0..8), `--join-swap-radius` (0..4095),
and sticky `--source-weight` (0..4096)
for subsequent source files. Zero disables a source; unavailable tokens reject.
Replay writes a reloadable report, unchanged model and new WAV under a distinct
output prefix. The three writes are not an atomic multi-file transaction.

`journals --palette-from PREFIX` freezes the saved ordered centers and requires
the same analysis options, sample rate and channels. New journals train a new
model and candidate pool in that vocabulary. Reports retain parent vocabulary
and model digests. `RequireCompatible` checks exact vocabulary/timebase plus
companion order/boundary before future combinations. Different model bytes are
allowed; identical token names with different centers are not compatible.
This supplies a reusable acoustic starter. Compatible saved models can then use
the [blend API](#blending-saved-journal-models); neither operation establishes
semantic style inference. A fixed palette can poorly represent material outside
its training set.

For fresh vocabulary training, `journals --max-tokens 1..32` exposes the existing
palette capacity; the default remains 16. This is a maximum, since fewer distinct
observations can produce fewer centers. It cannot be combined with `--palette-from`:
a saved starter fixes the ordered vocabulary. Changing capacity or retraining
centers creates a different vocabulary identity, not a new file-format version.
Models in different vocabularies cannot be blended without relearning compatible
models from their source evidence.

Capacity must be evaluated alongside source coverage and generation cost. The
[three-source study](WAV-STUDIES.md#journal-third-source-checkpoint) measures better
in-sample feature fit at 32 tokens but a larger WFC state space. Generation retains
a maximum of 1024 grains and a default budget of 262144 state cells (grains times
model states). `replay --state-cells N` explicitly selects a budget from 1 through
1048576; `TAcousticGenerationOptions.StateCellBudget` supplies the adapter control.
Initialize options with `DefaultAcousticGenerationOptions`. The current report
saves `state_cell_budget`; reports without it use the default. No format branch
is introduced. Learned streaming retains its separate 262144-cell bound.

The error reports requested cells, selected budget and that model's maximum grain
count. The 771-state study fits 340 grains by default; explicitly selecting 789504
cells admits the full 1024-grain path through the same intact WFC graph. See the
[capacity checkpoint](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint) for
measured resources, constraints, transitions and rendered replay. State cells are
a logical bound, not a byte or elapsed-time guarantee. Better feature fit and a
longer generated path do not establish sustained musical quality.

### Measuring frozen vocabulary coverage

`MeasureJournalPaletteFit` in
[pythian.learning.journal](../src/pythian.learning.journal.pas) measures a frozen
palette in one sequential pass over a borrowed training reader. It returns owned
statistics for each declared segment: distinct and weighted observation counts,
mean/maximum squared distance, nonsilent count/mean, token occupancy and entropy
effective count, self-transitions and longest same-token run. Runs cross storage
batches and reset at declared segment boundaries. Multiplicity is reported
separately; it does not inflate per-recording coverage or average errors. A zero
nonsilent count explicitly means no nonsilent evidence.

The caller supplies a finite squared-distance limit in `0..15` for the current
15-component vector; the report counts observations at or below that limit. It is
an exploratory vector-space diagnostic, not a calibrated musical-quality threshold.
Memory holds per-segment statistics and the existing bounded journal batch, not
all recording vectors. The palette and model are unchanged.

```powershell
pythian.learn fit build/study build/fit.json 0.25 source-A.wav source-A.pyaf source-B.wav source-B.pyaf
```

The maintained command accepts 1–32 WAV/cache pairs and measures whole journals
or explicitly selected ranges using the saved profile's analysis options,
sample rate and channels. It shares the non-sticky `--range` syntax above.
Each journal has diagnostic multiplicity one; saved training weights are not
reapplied to inflate its evidence count.
It verifies source/cache bindings and source bytes before writing one diagnostic
report. The output path must differ from all inputs. Validation failures leave
an existing report untouched; the final file write is not an atomic transaction.
Report fields retain profile/model/vocabulary and source/cache digests, feature
ranges, the caller's limit and each range's measurements. `recording_in_profile`
reports source-hash membership only: neither membership nor absence establishes
training/held-out provenance. The evaluator must declare recording splits before
policy selection. There is one current diagnostic contract and no legacy reader.

The [coverage checkpoint](WAV-STUDIES.md#palette-fit-checkpoint) connects this
measurement to [WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary)'s remaining
coverage, weighting and capacity decisions. It does not admit a reusable genre
style or clear downstream listening acceptance.

### Rendering selected source windows

The shared core `RenderJournalSelection` borrows a pool and source-window
callback, reads each selected slot once, validates its exact valid sample count,
zero-pads EOF and applies the existing Hann grain renderer. The returned clip is
caller-owned. Requests are preflighted at 4096 selections, 16 million output
samples and 64 million window samples of work; the output clock remains
`(grain_count - 1) * hop_frames + window_frames`.

## Blending saved journal models

The companion [pythian.wfc.learning.blend](../adapters/wfc/pythian.wfc.learning.blend.pas)
exposes `BlendJournalProfiles(Left, Right, LeftWeight, RightWeight)`. It borrows
both profiles and returns a detached, caller-owned profile. `EncodeReport` and
`EncodeModel` persist it through the same current report/model contract. No WAVs,
journals, reclustering or retraining are needed. Both parents must have exactly
compatible ordered palettes, timebases, model order/boundary and candidate-bin
policies, including when one has weight zero.

```powershell
pythian.learn blend build/style-A build/style-B build/blend 1 2
pythian.learn blend build/blend build/style-B build/derived 2 3
pythian.learn replay build/derived build/derived-audition --join-passes 4 source-A.wav source-B.wav
```

Weights are integers 0..64 with at least one active parent. They multiply actual
state, start and end counts and existing source multiplicities; counts are added
after remapping public-token indices. No ratio, duration or greatest-common-divisor
normalization occurs. Thus `(A + 2B) * 2 + 3B` retains `2A + 7B` evidence. Equal
weights do not mean equal recording duration or perceptual contribution. A zero
weight contributes no counts, candidates, source entries or lineage.

Optional source contexts follow the active parents. Source indices remap through
the same exact range/cache identity map. Matching anchors coalesce, retaining the
longer compatible prefix and minimum center distance at shared observations.
Conflicting tokens or geometry reject. Bounds remain 2048 anchors / 65536 windows;
training multiplicities do not replicate context storage. A parent without
contexts contributes its existing fallback candidates normally.

Exact repeated source-hash/range/cache identities share one source entry and add
multiplicities. Distinct nonoverlapping ranges remain separate; partial overlap,
conflicting geometry or conflicting cache identity for an exact range rejects.
Raw observation totals count the retained distinct ranges once, while weighted
totals reflect all explicit repetitions. Candidates remap to the retained sources;
a shared bin chooses smaller center distance, breaking ties by earlier feature
index. Output public tokens and states use canonical palette-index order. This
preserves learned structural states and counts. Compatible generated paths may
cross between the parents' state sets, but this supplies no new joint recording
evidence. Sample lengths follow retained source order.

Blending preflights the companion's 4096 weighted samples and signed-Integer
observation count. The union retains at most 1024 states and 32 source ranges.
`blend_parents` identifies immediate active parent report/model hashes and weights;
`training_lineage` retains up to 64 original profile/model identities with cumulative
integer contributions. Repeated identical report identities coalesce. Both fields
are optional together for newly trained profiles and required together for a blend;
reload validates their shape, digests, duplicate identities and weight bounds.
These are declared lineage records, not authenticated measurement evidence.
The flat lineage avoids embedding historical profiles or adding format versions.

Blend output has generation weights of one and no inherited audition, selected
slots or join measurements. `replay` chooses new tokens from the blended model;
its explicit source weights remain independent of training contributions. The
CLI writes `.json` and `.wfcs`, requires an output prefix distinct from its parents
and rejects a prefix already containing a WAV audition. The two writes are not
an atomic transaction. Replay generates the WAV under its own output prefix.

The [blend checkpoint](WAV-STUDIES.md#journal-blend-checkpoint) verifies a saved
blend used in a further blend and source-bound audio reconstruction. Broader
musical continuity, genre quality and admitted base/part providers remain open.

## Journal join planning

[pythian.learning.continuity](../src/pythian.learning.continuity.pas) exposes
`TJournalJoinPlanner` independently of WFC and file codecs. Construction borrows a
candidate pool and a source-bound `ReadWindow` callback. The callback returns exactly
the candidate's valid interleaved samples; the planner validates them and pads real
EOF to the declared analysis window. Only incoming/outgoing probe samples persist,
and planning performs no further waveform reads. The pool remains borrowed for
the planner's lifetime. The CLI callback uses its already verified WAV readers.

The caller supplies a feasible slot sequence, normally from `TJournalCandidatePool.Select`,
and optional per-position locks. Local edits substitute a window in the same
token/segment pool or swap equal-token segment assignments with alternate windows.
Each accepted edit strictly reduces weighted cost. Tokens, per-token/segment
counts, locked slots and the initial global immediate-repeat ceiling are hard
constraints. Source switches in this API count declared segment changes, including
distinct ranges in the same WAV. A plan can reduce switching without changing
overall contribution, but it can change contribution within a shorter time region.
Lock positions when their exact windows must remain fixed.

The planner uses the shared `NormalizedGrainJoinError` in
[pythian.granular](../src/pythian.granular.pas), also used by the existing
[whole-corpus planner](ACTIVITY.md). The metric sums squared differences between
paired overlap probes and divides by their summed energy plus `1e-20`.
The score is zero for identical probes and approaches two for opposite signals.
It is a sampled local mismatch measure, not perceptual quality or musical phrasing.

The total cost is seam weight × summed join error + source-switch weight × switch
count + center weight × summed candidate distance. Selection considers up to 64
evenly spaced overlap frames (default 16); a nonoverlapping window pair uses its
end/start sample. Each search pass visits unlocked positions, their same-segment
candidates, and compatible source swaps in stable order. Ties retain the current
path. Alternate windows during swaps avoid some repeat-constraint traps; bounded
local search can still stop short of a better global arrangement. A run can reduce
diversity or trade seam error against fewer switches. Compare all reported metrics.

Construction rejects more than 64 million slot × window × channel sample positions.
Search accepts at most 4096 grains and 1..8 passes. It counts compatible token/segment
pairs before search and rejects a conservative bound above 64 million probe-sample
visits. The bound includes both sides of each proposal and endpoint evaluation.
Requests that exceed a budget reject rather than silently shrink candidate coverage.

`SwapRadius = 0` retains the global swap search. A positive radius limits each
proposed equal-token source swap to that many output grain positions forward.
Same-source bin substitutions still consider every bin. Repeated local swaps
can move a source assignment farther across passes; the radius bounds proposals,
not final displacement. Tokens, per-token/source counts, locks and the initial
immediate-repeat ceiling remain hard constraints.

The local preflight counts all equal-token pairs within the radius, including
currently equal-source pairs: source assignments there can change during search.
This keeps the bound valid after edits. With a fixed radius the pair scan grows
linearly with output length; the global policy retains its quadratic scan.
`ProbeWorkBound` reports the conservative planned probe-sample bound, not elapsed
time or actual visits. The [sustained study](WAV-STUDIES.md#journal-sustained-checkpoint)
uses radius four to admit 1024-grain passages within the existing budget.

| CLI option | Scope and default |
| --- | --- |
| `--join-passes N` | Global, 0..8; default 0 disables join planning. The library default is 4. |
| `--join-swap-radius N` | Global, 0..4095 output grain positions; default 0 keeps global swaps. Positive values explicitly restrict swap proposals. Available in journal training and replay; saved replay inherits the policy. |
| `--join-seam-weight X` | Global, finite 0..16; default 1. |
| `--join-switch-weight X` | Global, finite 0..16; default 0.2. |
| `--join-center-weight X` | Global, finite 0..16; default 0.05. |

Weights use a decimal point in the CLI. Example: append `--join-passes 4` to an
existing journal training command. Reports retain the final candidate slots and
add before/after seam, switch, repeat, center-distance and total-cost measurements,
plus `swap_radius` and `probe_work_bound`. Existing reports without these optional
fields retain the global policy.
The same WFC model and output clock remain in use. These are optional fields in
the current diagnostic report, with no new saved style format or compatibility reader.
See the [recorded comparison](WAV-STUDIES.md#journal-join-checkpoint) for evidence
and the remaining continuity gate.

## Bounded source-context selection

[pythian.learning.context](../src/pythian.learning.context.pas) adds an independent
core context pool beneath the companion layer. `TJournalContextPool.Create`
borrows the training reader, exact palette and existing candidate pool during
construction. It owns detached source/range bindings, a copy of the fallback
pool, the vocabulary/timebase digest and forward windows around each populated
representative. One sequential journal pass retains up to 32 grains per anchor,
2048 anchors and 65536 total windows. Context stops at recording boundaries;
partial real-EOF windows keep their actual valid-frame counts.

The constructor verifies each anchor's token and coordinates against its journal.
It does not rehash source WAVs or prove the authenticity of stored measurements;
the host supplies verified source/cache bindings. Its accessors expose source
bindings, context lengths and individual windows without sharing mutable arrays.
`Fallback` is borrowed from the context pool and must not be freed by callers.

`Plan` starts with feasible fallback slot indices and optional exact window locks.
It preserves each output token and exact per-token/source contribution counts.
Locked contributions are reserved before greedy variable-length context selection.
Options expose maximum run length, a per-context start-use cap (zero means
unrestricted) and deterministic tie-breaking seed. A run length of one returns
the original selection. Unmatched positions use the existing fallback pool.

Quota exhaustion can otherwise strand a rare token in a source with only one
retained window. Bounded same-token/source substitutions and equal-token position
swaps repair immediate repeats while preserving both edited neighborhoods,
counts and locks. If the initial repeat ceiling still cannot be met, the entire
original selection is returned with `Reverted`; partial improvement is not
published as a feasible result. The report distinguishes context/fallback grains,
started context runs, repair edits, final contiguous links/repeats and work bound.
Started context runs are not inferred musical phrases or final uninterrupted runs.

Matching and repair preflight share the existing 64-million selection-visit
budget, including a conservative quadratic swap allowance. The 4096-grain
structural limit does not guarantee every context request fits that budget.
The greedy planner does not promise globally optimal continuation, low seam
error or phrase quality. Context-start limits also do not bound every repeated
window when retained contexts overlap.

`RenderJournalContexts` reads each distinct selected source coordinate once,
verifies extents, zero-pads true EOF and uses the shared Hann overlap-add renderer.
It retains the existing sample/work bounds and exact output clock. Rendering the
unchanged fallback selection matches the existing slot renderer exactly.

Checked stable/development Win32 and stable Win64 journal fixtures cover observed
window identity, recording/storage boundaries, locks, disabled sources, exact
contribution counts, replay, rare-token quota repair, disabled-context PCM parity,
EOF padding and rejected work bounds. Native sustained auditions supply separate
[paired continuity evidence](WAV-STUDIES.md#journal-context-selection-checkpoint).
The core compiles without companion search paths.

### Saved contexts and replay

`TJournalContextPool.CreateFromContexts` restores copied source bindings and
context arrays without journal reads. It validates palette/timebase identity,
source ranges, grid/EOF extents, finite distances, consecutive observations,
duplicate anchors and bounded storage. Restored anchors are ordered by source
and first feature; nested arrays are detached from the caller.

The companion profile's optional `source_contexts` object retains the vocabulary
digest and bounded rows of source index, first feature, token sequence and center
distances. Frame coordinates and true-EOF extents derive from existing profile
source bindings. This is a capability within the current report/model contract,
with no new format version or historical reader. `Contexts` is nil when absent.
`WithContexts` returns a detached enriched profile after exact vocabulary and
source/range checks; it preserves the model and parent profile.

```text
pythian.learn contexts INPUT_PREFIX OUTPUT_PREFIX MAX_GRAINS CACHE.pyaf [...]
pythian.learn replay INPUT_PREFIX OUTPUT_PREFIX --context-grains 8 SOURCE.wav [...]
```

`contexts` requires a fresh output prefix and one exact cache per saved source
range, in profile order. Cache digests and journal bindings are checked before
reading. It writes the enriched current JSON and unchanged model, without
retraining or rendering an audition. Output writes are not an atomic transaction.
Replay later requires explicit hash-matched WAVs and no training journals.

`replay --context-grains 0..32` caps each selected context chunk; zero disables
the context stage, while one preserves the original fallback selection.
`--context-uses 0..4096` limits starts per retained context; zero is unrestricted.
Neither option is a global copying limit: overlapping contexts, fallback and
repair may reuse source windows, and adjacent selections may form a longer
source-contiguous run. The [reuse study](WAV-STUDIES.md#journal-context-reuse-checkpoint)
measures this distinction and the continuity/repetition tradeoff.
The selection seed also breaks context ties. Positive run requests require the
saved capability. These controls are saved for subsequent replay; enabling
contexts on a newly attached profile is explicit. Source generation weights stay
independent of training weights. Exact positional window locks remain available
through the core API; the CLI currently invokes it without positional locks.

Optional waveform join planning runs first on fallback slots. Active context
reports store those slots as `base_candidate_slots` and final source coordinates
as `generated_context_windows`, alongside actual final source-use/diversity
counters and context/repair diagnostics. The join measurements describe that
earlier fallback stage; they are not final context-output seam scores.
Overall seam averages also include zero-error transitions between adjacent source
windows. Evaluate newly assembled boundaries separately before claiming improved
joins; the current context selector ranks token matches and reuse, not waveform
compatibility at those new boundaries.
Disabled reports retain `generated_candidate_slots`. Replay recomputes the path
from the saved recipe, rather than trusting recorded generated coordinates.

The [saved-context checkpoint](WAV-STUDIES.md#journal-context-save-checkpoint)
verifies attachment, compatible blends, a further blend, cache-free replay,
source remapping, malformed-input rejection and cross-target audible replay.
These structural checks do not authenticate the underlying measurements or
establish musical phrasing; source lineage and quality gates remain explicit.

### Context boundary refinement

Portable `PlanJournalContextJoins` in `pythian.learning.continuity` optionally
refines a completed context path. It partitions the initial path into maximal
source-contiguous chunks and proposes whole-chunk swaps only when lengths and
token sequences match. A chunk containing any locked position cannot move.
Every selected window and its metadata retain their exact multiplicities, so
source contributions, per-window reuse and window diversity remain unchanged.
Boundary-spanning repeated patterns and source switches can still change.

The function reads each distinct coordinate once and retains bounded incoming
and outgoing probes. `ExtractGrainJoinProbe` in `pythian.granular` now supplies
the same overlap/EOF policy to both candidate and context-boundary planning.
It checks every supplied sample, zero-pads partial EOF and compares endpoints
when grains do not overlap. Probe storage is detached from the source callback.

A swap must reduce total sampled mismatch without increasing the mean over
newly assembled boundaries or the immediate-repeat count. Internal chunk audio
is preserved. Source-contiguous transitions are counted separately; report
fields describe sampled waveform costs, not dense or perceptual guarantees.
The planner is a bounded local search; it cannot replace an already-selected
chunk with a better source passage or guarantee globally optimal boundaries.

Defaults are four passes, 64 probe frames and a forward radius of eight original
chunks. Bounds are 1..8 passes, 1..64 probes, radius 1..64 and 1..4096 grains.
Conservative preflight includes sample reads, coordinate deduplication, token
comparisons, swaps and edge probes within 64 million visits. Large combinations
can reject before callback reads; structural maxima are not a promise that all
combinations fit. Caller arrays remain unchanged and the returned path is owned.

```text
pythian.learn replay INPUT_PREFIX OUTPUT_PREFIX --context-join-passes 4 SOURCE.wav [...]
```

The maintained tool requires an enabled context stage. `--context-join-passes 0`
disables refinement (the default); `--context-join-probes` and
`--context-join-radius` expose its independent controls. All three settings remain
in the current profile and replay without journals or retraining. Core positional
locks remain available; the CLI still supplies no positional locks.

The `context_join_planning` report records before/after all-boundary and
assembled-boundary sampled means, assembled counts, repeats, swaps and work.
`context_planning` still describes the preceding context selector. Final
`generated_context_windows` and usage counters describe the refined output.
The [boundary checkpoint](WAV-STUDIES.md#journal-boundary-refinement-checkpoint)
records dense source comparisons, auditions and explicit remaining limitations.

## Journal learning evidence — 2026-09-15

The following is the original single-representative checkpoint. Current selection
evidence follows in the [milestones](WAV-STUDIES.md#journal-selection-checkpoint).

Checked stable/development Win32 and stable Win64 fixtures compare journal training
with explicitly expanded short evidence. Weighted centers agree within 1e-12.
Orders 1..4 produce byte-identical WFC model text to the companion learner across
batch sizes 1, 7 and 13, explicit recording boundaries, multiplicity and a one-cell
segment. Overlapping ranges reject. The normal learner retains exact prior JSON
and model output; the short journal path produces the same model and cross-target
audio bytes.

The complete 2h17m source cache trains 128683 observations into 16 palette tokens
and 244 WFC states. Its 128-grain audition has 134144 stereo frames at 16 kHz
(8.384 seconds). Local training, binding checks and rendering take 49.892 seconds.
Stable Win32 and Win64 produce identical model/audio bytes. An independent native
operator loads the model from disk without training and replays every reported
token. Selected source coordinates reach frame 122473472, beyond the old whole-clip
budget. Audio peaks are 0.23828125 / 0.21612549. The model SHA256 is
`13774d9001c05a8c6a2d1d4c86a60529449c7f69662efff6dfea23b9fec9d8b5`;
audio SHA256 is `ee0d9da3a45f59dff7d0441ed62619a0acbf9f85774e7be993593b35ea8a065d`.

A two-source probe uses 129152 unique observations. Multiplicities 1 and 274 give
128683 and 128506 weighted observations respectively, totaling 257189 and yielding
242 WFC states. The companion reports 275 weighted samples, representing two actual
recordings. Its audition uses 107 grains from the long source and 21 from the short
source. Similar training mass does not enforce similar generated source use.

The single-source audition uses 13 representatives and repeats the same one in
75/127 neighboring pairs; the weighted probe uses 15 and repeats in 88/127 pairs.
These fixed-seed observations expose the single-representative limitation. They
do not establish genre recognition, musical phrasing or acceptable blend quality.
Candidate pools and source controls were the next work from this checkpoint;
broader listener evaluation, held-out recordings and semantic providers remain open. Evidence and
auditions are in ignored `build/journal-learning-{stable,trunk,win64}/`; final
focused builds are under `current/`. No package refresh or Linux/remote CI is claimed.

## Source identity and learner integration

`Sha256Stream(stream, byteCount)` in [pythian.hash](../src/pythian.hash.pas)
hashes an exact span beginning at the current stream position. It uses an
8192-byte buffer and the same native compression/finalization implementation as
`Sha256Bytes`. Short positive reads accumulate. Nil streams, negative counts
and counts above 2305843009213693951 reject before reading. Early EOF and source
exceptions can advance the stream but preserve a previously assigned digest.
The function neither seeks nor closes the borrowed stream.

The tool helper `AnalyzeWaveSource` holds its file open denying writes where
supported, preflights source/analysis budgets, hashes exact file bytes, analyzes
windows, then checks file size and digest again before publishing features and
source information. Concurrent modification is unsupported; the second digest
detects ordinary intervening changes, not an adversarial changing-file snapshot.
This adds a second sequential hash read in exchange for bounded source storage.

`pythian.learn` uses this helper; its JSON field order, source/model hashes,
palette and actual WFC model format remain unchanged. Other corpus, inspection
and reconstruction tools retain their existing source-loading contracts.
Output files remain separate writes; atomic replacement is separate work.

## Journal evidence — 2026-09-15

Checked stable/development Win32 and stable Win64 fixtures pass feature/chroma
round trips, duplicate rejection, interrupted header/payload/digest recovery,
flush failure with a surviving complete record, binding mismatch and complete
corruption rejection. All three targets reopen the stable-generated short cache.
A physical file truncated by 17 bytes resumes at index 348 and recovers the exact
accepted cache. A different WAV source rejects without changing it. Original
learner JSON and WFC outputs remain byte-identical to the retained earlier tool.

The full headroom-prepared WAV source yields 128683 stored observations in two
invocations, with fresh-process resume at index 2048. The completed cache is
17526764 bytes, SHA256
`b12aa48d56f2420b388dff8e43cebf6db12604e9deb109b8feb816dc2f5e21b7`.
The final current executable verifies the complete journal and appends zero
batches without changing its bytes. Local combined elapsed time is 460.605 seconds;
sampled peak working set is 7049216 bytes. Evidence is under ignored
`build/feature-journal-{stable,trunk,win64}/`, with final focused builds in `current/`.
The ordinary build includes the new journal fixture. No full ordinary build,
refreshed package, Unix execution or remote CI is claimed by this checkpoint.

## Long-source batch evidence — 2026-09-15

Checked stable/development Win32 and stable Win64 fixtures pass exact whole/batch
feature parity at hops 1, 47 and 128 with batch sizes 1, 7 and 31. Each request
starts from an independently reset reader position. RF64 source coordinates beyond
High(Integer), real EOF tails and rejected resume preservation also pass. Existing
core and actual WFC corpus fixtures pass on checked stable Win32.

The full floating WAV probe has 131770456 stereo frames at 16 kHz (8235.654 seconds).
It yields 128683 observations in 1024-observation batches, with no gaps or duplicate
coordinates. A fresh-process tail from index 126977, using batches of 137, matches
the uninterrupted 1706-observation tail exactly. Local analysis time is 412.719
seconds; the sampled process peak working set is 7233536 bytes. The probe streams
explicit feature fields to an ignored diagnostic file; this is not a new maintained
archive format or a durable learner checkpoint.

Evidence: `build/wav-batch-{stable,trunk,win64}/` and `build/wav-long-source/`.
The full feature diagnostic SHA256 is
`123a8530ca59ca6082aedfe02821b7a2397d5f13e940ebd20d7b42af3e11086e`;
the replayed tail is
`38bd62766563a018f58df573fb79609e050e6805f8e1e373cd48574bf8b39282`.
These record bytes are a local same-target comparison, not a portable file contract.
The full source uses external rate preparation; native analysis does not quantize
its floating peaks. No many-hour palette/model training or musical acceptance is claimed.

## Optional spectral bands — 2026-09-19

`AnalyzeAudioBands(clip, options, edges)` and
`AnalyzeAudioSourceRangeBands(source, options, edges, firstFeature, count)` return
the existing features alongside caller-defined frequency-band measurements.
`AnalyzeWaveBandBatch(reader, options, edges, firstFeature, maximumFeatures)`
provides the same measurements with the existing bounded Int64 WAV resume path.
Its `Batch` carries coordinates/progress and `Bands` aligns with `Batch.Features`.
Noninitial batches reconstruct the preceding spectrum; EOF batches retain band
metadata with empty value arrays. This supports long-source processing without
retaining all observations or decoded samples.

Supply 2..33 finite, strictly increasing edges within zero through Nyquist.
A subset of that frequency range is also valid. FFT bin
centers belong to `[lower, upper)`; the final upper edge is included. Each band
retains its edges, a raw windowed-FFT magnitude sum after independent channel-power
combination, and positive spectral flux normalized by the same full-spectrum
current/previous magnitude denominator as the original feature. Silent features
have zero band flux. A partition covering the full spectrum sums to aggregate
flux within floating summation tolerance. These are bin measurements, not
time-domain filters, separated instruments or probabilities.

The shared engine performs no additional FFT. Existing frame/FFT-work limits
apply; at most 32 pairs of value arrays are retained, each bounded by the returned
feature count. Band assignment adds at most 32 comparisons per spectral bin
once per call, then constant work per bin and normalization per band/feature.
Invalid edges reject before source reads and preserve an assigned result.
`TAudioFeature`, its journal encoding and existing APIs retain their contracts.
Bands are optional returned measurements; this change adds no persisted format
or historical reader. Consumers must retain source identity and band policy when
using these measurements as learning evidence.

The existing WAV-analysis fixture now checks independent centered-impulse spectra,
bin-edge ownership including DC/Nyquist, normalized rising flux, antiphase stereo,
silence, exact resumed band values, invalid admission and RF64 coordinates beyond
32 bits. Checked FPC 3.2.2 Win32/Win64 and FPC 3.3.1 Win32 pass. The journal fixture
also passes on stable Win64. Three development WAVs reproduce whole-clip band
values exactly in 97-feature batches, including overlapping windows and context;
their band partitions reconstruct aggregate flux within 1e-12.

Rebuilding the unchanged maintained beat consumer produces byte-identical complete
JSON reports and source-plus-marker WAVs to the original three-recording baseline.
Thus this optional measurement addition preserves that listening path; it does
not promote the experimental beat algorithms or establish new musical accuracy.
Evidence is under ignored `build/band-analysis/`. See the
[band-evidence probe](BEAT-TRACKING.md#frequency-band-evidence-probe--2026-09-19)
for observed limitations and the next admission gate. Current-source packaging,
remote CI and new listening acceptance are not claimed by this checkpoint.

## Earlier whole-result evidence

Checked FPC 3.2.2 and 3.3.1 i386-win32 builds pass:

- Exact equality of every feature field between decoded-clip and WAV-window
  analysis, using stereo antiphase tone, silence, a transient and partial final
  windows at hops 1, 47 and 128 with window 128.
- A 13-byte short-read stream consumes each PCM sample exactly once despite
  overlap. Invalid preflight preserves reader position. A failure after the
  first successful window preserves prior features and confirmed reader state.
  Malformed custom windows and nonfinite samples reject without publication.
- Native SHA256 known answers and exact stream/byte equality at padding and
  8192-byte buffer boundaries, with three-byte reads, nonzero start position,
  declared subspans, early EOF and original source-exception checks.
- Existing actual WFC learning/generation fixtures, including PCM16 bridge,
  spectral expectations, constraints, replay and recorded-grain reconstruction.

The retained earlier learner executable is dated 2026-09-14 21:33:43 UTC,
before this input refactor. Its SHA256 is
`bfe4116abada1c2f62604c8a746f9013f2066a2b095eaa9620f7ccca2796b17f`.
Both updated compilers produce byte-identical JSON and WFC model files to that
earlier binary for the original attributed Pixel Sprinter and Opening Theme
recordings. Pixel has 1477 observations / 129 states; Opening has 3876 / 105.
Each uses 16 acoustic tokens. Source identities remain in the
[recording manifest](../tests/fixtures/wav-corpus.json).

| Output | SHA256 |
| --- | --- |
| Pixel JSON | `5a7702a1b935659ba3af08a42f6151f2f7c1578aeae01c9e1ab85b01c8dfe3e7` |
| Pixel model | `d5341afd14c52fa265cfa955f57ce1df4d4d4ecc44e17306c90852fe9ce9310c` |
| Opening JSON | `52782ab332c4a6795a03d50ba13fdc5d4ed395169bd5fdca0d002c5da2162bc4` |
| Opening model | `ca302264e00cedf40d6a5e89710b0c6ae7c02d7bc33369e1bb1fce4ce534531e` |

Logs and artifacts: `build/analysis-wave-{stable,trunk}/` and
`build/analysis-wave-replay.log`. The focused core fixtures have no warnings;
WFC-linked builds retain companion/RTL warnings. The normal build now includes
the window-source fixture. This checkpoint does not claim a full-suite run or
refreshed source ZIPs. It reduces sample storage; it does not establish automatic
musical key/tempo admission, source separation or reusable layered song styles.
