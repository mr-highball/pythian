# Continuing learned audio sequences

[Home](../README.md) · [Joint models](JOINT-ARCHIVE.md) ·
[Activity and continuity](ACTIVITY.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

## Contract

[pythian.wfc.stream](../adapters/wfc/pythian.wfc.stream.pas) continues an actual
WFC learned sequence through bounded graphs. `TLearnedSequenceStream` borrows
an immutable `TWfcSequenceModel`, which must outlive it. The first chunk uses
observed start states. Later chunks receive the exact final latent state retained
from the preceding successful chunk, including higher-order history. Carrying
only the last public token would lose that information.

`TryNext` accepts `TSequenceChunkOptions`, actual WFC token constraints and a
caller-owned prior chunk. Options specify cell count, seed, backtrack budget and
whether this chunk must reach an observed end. Constraint positions are local
to the chunk. Success publishes a detached `TWfcGeneratedSequenceSegment`,
advances the Int64 count and retains one private predecessor index. Editing
either returned array cannot alter history. An end-marked successful chunk seals
the stream until `Reset` deliberately starts a new sequence from an observed start.

Solver failure returns False with the actual WFC report, preserving the prior
chunk, count and predecessor. Invalid input raises with the same preservation.
Callers may retry with changed requests; constraints are never silently relaxed.
Every result passes WFC segment-boundary and caller-domain checks before
publication. Version is `SequenceStreamVersion = 1`.

Per-chunk limits: 1..1024 cells, at most 262144 state/cell combinations,
0..65536 backtracks and no more constraint records than requested cells
(repeated positions still intersect). Total successful cells may reach
High(Int64); overflow rejects before generation. Retained history storage is
constant; temporary graphs and returned chunks are separately bounded.
This is a sequential API without concurrent callbacks, persistence or
caller-supplied predecessor restoration.

Chunk sizes, boundaries, seeds, budgets and model bytes are replay inputs.
Changing chunk size can change the result; there is no whole-versus-split
sequence identity promise. A valid chunk does not prove a later requested
length, endpoint or lock is satisfiable. An observed end is learned sequence
structure, not proof of an audible cadence.

## Native WAV workflow

```text
pythian.archive remix-stream-joint INPUT.pyac OUTPUT.wav SEED TOTAL_CELLS ACTIVITY_PATTERN CHUNK_CELLS SOURCE.wav...
```

Use a saved joint archive from `prepare-joint`. Source files are admitted by
their exact archived hashes and format independently of argument order. The
command loads the saved model and activity policy without learning or FFT.
`TOTAL_CELLS` is 1..4096; `CHUNK_CELLS` is 1..1024 and must fit the model's
state/cell budget. A final shorter chunk is allowed.

The activity pattern uses `a` onset candidate, `h` sustain, `r` measured silence
and `?` unrestricted activity. It starts at absolute cell zero and does not
repeat; omitted later positions are unrestricted. Shared `JointTokenConstraints`
translates the covered portion into actual chunk-local WFC domains.
The tool calls WFC's actual `WfcMusicArrangementSectionSeed(baseSeed, chunkIndex)`.
The last chunk requires an observed end. Failure never restarts a chunk from
a different predecessor.

After all chunks succeed, the tool validates their combined latent path as one
whole WFC sequence. One source-continuity pass and one overlap-add render span
all solver chunks, preserving the generated acoustic/activity pair at every
selected source coordinate. Audio is not independently faded or restarted per
chunk. WAV and sidecar writes follow generation/rendering; generation failure
preserves existing files. File-system publication of the pair is not yet atomic.

The sidecar retains source attribution/hashes, model text/hash, activity policy,
every grain, output hash and each chunk's size, derived seed, predecessor and
selected latent states. `extent` is `whole_in_chunks`. The older
`remix-saved-joint` retains its single-fragment semantics and output.

Only generation graphs are streamed here. The tool gathers up to 4096 cells
and renders a bounded in-memory clip through existing continuity/granular limits.
Unbounded audio output, macro-form controls, beat inference, pitch transcription
and cross-chunk musical development remain open. Output positions are still
analysis-hop units; measured activity is not beat certainty. See
[musical output timing](TIMED-LEARNING.md) for separate gate/attack controls.

## Evidence

`shared-stream.wav` is an integration artifact for longer learned-history
continuation and grain reconstruction. It has no beat-grid or phrase-level
arrangement. Its measured length and valid transitions do not establish a
coherent piece of music; musical structure and listening quality remain separate
acceptance work.

The separate [passage path](PASSAGES.md) now preserves whole source-declared bars
and provides an authored opening/reprise/ending for listening evaluation.

The [stream fixture](../tests/pythian.tests.wfc.stream.lpr) checks an order-3 model
where identical final public tokens require different continuations; caller
array mutation; rejected-call preservation and retry; observed-end completion;
reset/replay; and a 1601-cell alternating path across fifty chunks with an
independent token oracle and complete actual WFC path validation.

The two attributed recordings in the [corpus manifest](../tests/fixtures/wav-corpus.json)
were loaded through `build/corpus/shared-paired.pyac` with seed 731, 3072 cells,
pattern `a` and 256 cells per chunk. Twelve chunks produced 3148776 stereo
frames at 44100 Hz, about 71.401 seconds. Output:
`build/corpus/shared-stream.wav`, SHA256
`0806667b5e75520198f221b326bbcc8c7b3f60447648090fc763239f36207104`.

The [published joint checker](../tests/pythian.tests.wfc.joint.lpr) independently
verifies every latent transition, observed endpoint, section seed, grain
projection, source coordinate and measured source label. There are 344 onset
candidate and 2728 sustain grains: 846 from Pixel Sprinter, 2226 from Opening
Theme. Source-forward links total 2150/3071; mean normalized seam error is
0.185687 versus 1.028527 for the nearest-token baseline. These measure source
selection, not musical quality or listener preference.

Left/right PCM peaks are 0.883270/0.913177 and RMS 0.166939/0.163239.
Reversed source arguments reproduce identical WAV and complete metadata bytes.
Impossible silence constraints at cell zero and at the next chunk's first cell
(absolute cell 256) reject with both prior files unchanged.
The older saved-joint remix also remains byte-identical. Operator listening is
not verified.

Logs: `build/sequence-stream-validation.log`,
`build/stream-published-validation.log`, `build/corpus/shared-stream.log`,
`shared-stream-replay.log`, `shared-stream-rejection.log`,
`shared-stream-late-rejection.log`,
`shared-stream-inspect.json` and `saved-stream-regression.log`.
Compiler/target and full-build status are in the [work record](WORK.md).
