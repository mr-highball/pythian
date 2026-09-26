# Recorded musical passages

[Home](../README.md) · [WAV learning](WAV-LEARNING.md) ·
[Learned streams](LEARNED-STREAMS.md) · [Work](WORK.md)

The passage path retains whole source bars and provides an explicit opening,
reprise and ending for listening evaluation. The earlier `shared-stream.wav`
checks longer learned-history continuation and short-grain reconstruction;
its duration does not establish musical form. This path changes the unit of
learning and reconstruction to a complete recorded bar.

The same underlying interval aggregation and renderer also support the separate
[onset-event learning path](EVENT-LEARNING.md). That path learns measured event
durations without assuming source bars, and retains this bar workflow's contract.
The renderer now also accepts explicit source/start/count references across
multiple recordings; [shared event reconstruction](EVENT-CORPUS.md#native-reconstruction)
describes its format, ownership and continuity contract.

## Core contract

`ReadWaveLoopInfo` in [pythian.wave](../src/pythian.wave.pas) reads optional
ACID loop metadata inside a bounded RIFF/WAVE envelope. Missing metadata returns
`Found = False`. Short or duplicate declarations, malformed chunk extents and
nonfinite tempo reject. Audio format/sample validation remains `DecodeWave`'s
responsibility. Unknown metadata chunks retain RIFF padding semantics.

Field order and flag meanings were checked against the primary
[libsndfile WAV reader](https://github.com/libsndfile/libsndfile/blob/master/src/wav.c).
Beat count uses the meter's denominator unit, while BPM counts quarter notes,
as documented in [loop information](https://github.com/libsndfile/libsndfile/blob/master/docs/command.md#sfc_get_loop_info).
This is an independent Pascal implementation using the existing RIFF helpers;
no libsndfile source or dependency was imported.

[pythian.passage](../src/pythian.passage.pas) exposes three reusable operations:

- `LoopBarBounds` requires a looping declaration with complete bars, bounded
  meter/tempo, and source-duration agreement within the greater of one frame or
  one part per million. Integer floor boundaries cover the exact source extent.
  **Frame zero as downbeat is an assumption**, not an annotated attack measurement.
- `MeasurePassages` aggregates immutable stored features over supplied source
  boundaries. Each feature owns its hop interval for duration weighting; RMS,
  centroid and chroma use energy weights. Peak remains an overlapping-window
  estimate. These descriptors do not identify notes or exact transients.
- `RenderPassages` concatenates selected passages at the source rate, preserving
  stereo samples. Optional linear fades lie inside output endpoints and source
  jumps; contiguous neighbors preserve their join. No time stretching occurs.
  Bounds may describe arbitrary increasing source intervals, independently of
  ACID metadata. Returned clips are caller-owned and detached.

The core accepts up to 4096 passages and a 16-million scalar-sample output budget.
Invalid bounds, source indices or fade requests reject before output allocation.
These units have no WFC or Phanes dependency.

## Operator path

Build with the normal [native build](../README.md#build-and-listen), then use:

```text
pythian.passage.remix INPUT.pyac SOURCE.wav OUTPUT.wav SEED BARS [PALETTE_SIZE]
pythian.tests.passage.output INPUT.pyac SOURCE.wav OUTPUT.wav
```

The optional corpus recordings are identified in the
[source manifest](../tests/fixtures/wav-corpus.json). With the existing local corpus:

```powershell
./build/3.3.1-i386-win32/pythian.passage.remix.exe build/corpus/shared.pyac build/corpus/pixel-sprinter.wav build/corpus/pixel-passages.wav 731 32
./build/3.3.1-i386-win32/pythian.tests.passage.output.exe build/corpus/shared.pyac build/corpus/pixel-sprinter.wav build/corpus/pixel-passages.wav
```

The tool admits the exact source WAV by its corpus SHA256 and decoded format.
It reuses stored measurements, trains a new passage palette and calls the actual
order-2 WFC learner and constrained solver through the existing adapters. The
archive attachment's short-window model is unused; no new FFT is performed.

The authored form pins source bars 0..3 at the opening and again eight bars before
the end, then pins the final four source bars at the output ending. These concrete
bar choices also constrain WFC tokens. The intervening bars are generated with
observed start/end admission; source selection prefers a contiguous class member
and otherwise uses deterministic seed/position selection. An incompatible form
rejects without relaxing constraints. This policy belongs to the operator tool;
the reusable core accepts arbitrary passage sequences.

Output requests support 16..64 bars, subject to the core sample budget, and 1..32
palette tokens (default four). `OUTPUT.wav.json` records source/archive/model/output
hashes, declared clock, palette, source tokens, every source/output coordinate and
concrete pin. `OUTPUT.wav.wfcs` holds the actual trained model. Validation and
rendering precede publication. These are separate file writes: filesystem failures
can still leave a partial artifact set.

## Evidence and listening

The exact Pixel Sprinter loop by Zane Little Music, CC0, has 1,512,000 stereo
frames at 44100 Hz. Its ACID chunk declares 80 beats, 4/4 and 140 BPM: twenty
75,600-frame bars. This agrees with source duration. The raw root-note field
has no validity flag and is not used as a key claim. Opening Theme has no such
declaration and this tool rejects it rather than assigning a guessed clock.

The seed-731 run produces 32 bars, 2,419,200 frames, about 54.857 seconds. Four
acoustic classes produce nine actual WFC states. Listen to
`build/corpus/pixel-passages.wav`; the opening returns at about 41.143 seconds
and the four source ending bars begin at 48 seconds. Output SHA256:
`fde808e1ad5253d69c093335573972010b3b420b6d414bfd1a56f57276ab766a`.
Left/right peaks are 0.773529/0.738983; RMS 0.135497/0.133061.

The [core fixture](../tests/pythian.tests.passage.lpr) covers independently authored
ACID bytes, missing/malformed metadata, duration and meter rejection, 4/4 and 6/8
grids, partial-hop feature weights, exact stereo copying and fades at source jumps.
The [published checker](../tests/pythian.tests.passage.output.lpr) verifies source
and model binding, concrete form pins, an independent reachable latent-state path
with observed endpoints, and every PCM sample against source/fade coordinates
within PCM16 quantization. It does not call the WFC solver for its path check.

Replay reproduces all three output files exactly. Missing metadata, an unknown
source hash and contradictory form with a 32-token palette reject while preserving
the prior files. Evidence: `build/passage-focused.log`,
`build/passage-published-validation.log`, `build/corpus/pixel-passages.log`,
`pixel-passages-replay.log`, `pixel-passages-rejection.log` and
`pixel-passages-inspect.json`. Compiler/full-build status is in [Work](WORK.md).

Operator listening remains unverified. Preserved bar content and an authored
reprise are concrete structural advances; acoustic classes still permit harmonic
or phrase discontinuities. Source downbeat annotation, automatic beat inference,
cadence-aware endings, learned larger forms and multiple source clocks remain
open. This example rearranges recorded music; it does not establish transcription
or original composition.
