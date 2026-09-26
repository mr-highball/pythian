# WAV learning and listening

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[Provenance](PROVENANCE.md) · [Work](WORK.md)

For saved shared vocabularies, multiple recordings and generation without
relearning, see [persisted acoustic corpora](CORPUS.md).
For measured onset candidates, shared WFC rhythm cells and the optional grain
planner, see [activity and continuity](ACTIVITY.md).
For bounded RIFF/RF64 input blocks and PCM16 transcoding, see
[WAV reading](WAVE-READING.md). Existing learner/corpus budgets still apply.
The standalone learner now uses [bounded WAV analysis](ANALYSIS-WAVE.md):
window overlap and fixed hash buffers replace complete source/clip storage.
Other corpus and reconstruction tools retain their existing loading paths.
The core also exposes [long-source feature batches](ANALYSIS-WAVE.md#batches-and-source-coordinates)
with exact resume indices and retained cross-batch flux. The new
[feature-cache command](ANALYSIS-WAVE.md#cache-command) persists and resumes those
observations. [Journal training](ANALYSIS-WAVE.md#training-from-journals) now learns
a bounded shared palette and actual WFC model from the full cache, then auditions
selected source windows. Musical style quality and semantic layer providers remain open.

For measured tonal evidence, explicit key/unknown selection and caller-declared
tempo feeding saved WFC providers, see [WAV context admission](WAVE-CONTEXT-ADMISSION.md).
For measured onset behavior, weighted saved/repeated blends and selective edits
feeding native synthesized voices, see [WAV onset styles](WAVE-STYLE.md).
For periodic candidates, explicit monophonic admission and saved WFC note models,
see [pitch learning](PITCH.md). This is separate from polyphonic voice extraction.

The native path now runs from WAV recording to spectral features, an acoustic
palette, a learned WFC sequence model, constrained generation, and recorded-grain
reconstruction. Recorded material remains identifiable by source frame ranges.
This is a first audio-domain learning/reconstruction path, not a claim of note
transcription, beat-aware composition, or instrument synthesis from recordings.

## Operator commands

Build with `./tools/build.ps1`. Run the executables under the resulting
`build/<version>-<cpu>-<os>/` directory:

```text
pythian.inspect INPUT.wav
pythian.learn INPUT.wav OUTPUT_PREFIX
pythian.learn cache INPUT.wav OUTPUT.pyaf [--batch-features N] [--max-batches N]
pythian.learn journals OUTPUT_PREFIX [OPTIONS] INPUT.wav CACHE.pyaf [...]
pythian.learn contexts INPUT_PREFIX OUTPUT_PREFIX MAX_GRAINS CACHE.pyaf [...]
pythian.learn replay INPUT_PREFIX OUTPUT_PREFIX [OPTIONS] SOURCE.wav [...]
pythian.remix INPUT.wav OUTPUT.wav [SEED] [ACOUSTIC_FRAMES]
```

`inspect` emits JSON containing the file hash, format, duration and per-channel
linear peak/RMS/mean measurements. It does not measure perceptual loudness.
Journal [selection options](ANALYSIS-WAVE.md#journal-candidate-selection) include
`--candidate-bins`, `--selection-seed` and sticky `--source-weight`, independently
of training `--multiplicity`. Reports retain the selected source coordinates.
Optional [journal join planning](ANALYSIS-WAVE.md#journal-join-planning) uses
`--join-passes 1..8` to improve local joins while retaining per-token/source
contribution counts. Seam, source-switch and center-distance weights are independent.
`--join-swap-radius N` explicitly limits swap proposals to nearby output positions;
zero retains the global search. The saved policy replays without retraining.
[Saved journal profiles](ANALYSIS-WAVE.md#saved-journal-profiles) supply exact
palette/timebase/model bindings. `replay` requires explicit WAV sources but no
feature caches or learning. `journals --palette-from PREFIX` uses a saved vocabulary
as the fixed palette for new recordings; it does not merge their models.
Fresh training accepts `--max-tokens 1..32` (default 16), independently of source
weights. It cannot accompany `--palette-from`. Larger vocabularies can increase
model states and reduce the grain count admitted by the default generation
budget. `replay --state-cells N` explicitly selects and saves a bounded larger
budget when needed; see the [contract](ANALYSIS-WAVE.md#saved-journal-profiles)
and [full-length capacity evidence](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint).
`blend LEFT RIGHT OUTPUT LEFT_WEIGHT RIGHT_WEIGHT` then combines compatible saved
models with explicit integer evidence weights. The output can enter another blend
or `replay`; see [saved acoustic blends](ANALYSIS-WAVE.md#blending-saved-journal-models).
`contexts` attaches bounded source sequences from exact saved journals without
changing the learned model. They survive profile reload and repeated blends.
`replay --context-grains 8` enables variable-length source context after optional
join planning; `--context-uses N` caps starts per context, with zero unrestricted.
Both settings persist for subsequent replay without journals. See
[saved contexts](ANALYSIS-WAVE.md#saved-contexts-and-replay) for bounds and scope.
`--context-join-passes 1..8` optionally refines final boundaries by swapping whole
chunks with matching tokens; zero keeps it disabled. Probe count and chunk search
radius are independently saved. See [context boundary refinement](ANALYSIS-WAVE.md#context-boundary-refinement).
`learn` writes a `.wfcs` model and a palette/frame-token `.json` sidecar. Source
and model SHA256 values bind those records to their inputs. Native file hashing
uses the shared native `pythian.hash` implementation. Later stable/development
compiler and persistence evidence is recorded in [the work record](WORK.md).

`remix` learns from the supplied recording and generates an acoustic fragment
through WFC. Defaults are seed 731, 256 acoustic frames, and 256 allowed
backtracks. An acoustic frame advances 1024 source-rate sample frames; this is
not a beat or a MIDI tick. Generated fragments may begin and end inside learned
sequences. This CLI does not silently convert them into whole-song boundaries.

The output includes:

- `OUTPUT.wav`: PCM16 reconstruction, preserving mono/stereo format.
- `OUTPUT.wav.wfcs`: the actual learned WFC model.
- `OUTPUT.wav.json`: source/model/output hashes, versions, seed, bounds, and
  one source/output sample-frame mapping per generated grain.

Open the output WAV in a local audio player. The source recording can remain
recognizable: grains are reused from it. There is no claim of independent
original composition or freedom from the source's license. Input paths cannot
also be output artifact paths. File writes are currently individual operations;
an I/O failure can leave partial outputs. The hash-bearing sidecar lets callers
detect mismatch. These earlier sidecars are inspection-only; the
[archive reader](CORPUS.md) provides a separate validated persisted workflow.

## Reusable interfaces

[pythian.granular](../src/pythian.granular.pas) accepts borrowed source clips and
explicit grain records. Rate 1 preserves source sampling; other supported rates
use linear interpolation, which is not an anti-aliased sample-rate converter.
Grains can use rectangular or sample-centered Hann windows. Normalized overlap
divides by the larger of one and accumulated window weight, so boundary fades
survive. The output has a 16-million scalar-sample budget and a 64-million
sample-visit budget; sources are never mutated.

[pythian.reconstruction](../src/pythian.reconstruction.pas) plans exemplar grains
from palette-local token indices. It chooses the closest assigned source feature
to each center, retains exact source coordinates, and preserves partial window
lengths. This simple deterministic policy can smear transients or expose repeated
texture. An optional [continuity planner](ACTIVITY.md) now selects among matching
exemplars using source adjacency, overlap-sample agreement and onset candidates.
General onset accuracy and long-form continuity remain open.

[pythian.wfc.generation](../adapters/wfc/pythian.wfc.generation.pas) accepts native
WFC position/token constraints, seed, extent and backtrack budget. It validates
the solved sequence and caller constraints before publishing indices. Failed or
invalid requests preserve previous output. The report distinguishes exhausted
backtracking from contradiction; a focused odd-cycle fixture exercises both.
This synchronous API does not yet expose cancellation.

## Published-recording evidence

The [corpus manifest](../tests/fixtures/wav-corpus.json) pins download URLs,
authors, licenses, input bytes/hashes and the observed outputs. The recordings
are held under ignored `build/corpus/`, not bundled into the library. Both
publisher pages explicitly identify the files as CC0, checked 2026-09-14:
[Pixel Sprinter](https://opengameart.org/content/pixel-sprinter) by Zane Little
Music and [Opening Theme](https://opengameart.org/content/opening-theme-actionsuspense)
by nene. The former combines piano, strings and chiptune sound; the latter is an
orchestral action theme with percussion. These descriptions come from their
publisher pages, not an inference made by the learner.

| Recording | Source duration | Learned states | Output duration | Output L/R peak | Output L/R RMS |
| --- | ---: | ---: | ---: | --- | --- |
| Pixel Sprinter loop | 34.29 s | 129 | 11.96 s | 0.3554 / 0.3414 | 0.08381 / 0.08326 |
| Opening Theme | 90.00 s | 105 | 11.96 s | 0.5245 / 0.5809 | 0.12994 / 0.11511 |

Each complete source was decoded and analyzed at 44100 Hz, stereo, with no
external transcoding. Each model used 16 acoustic palette entries and produced
512 constrained grains at seed 731. Repeated runs with the current native
writer produced identical output SHA256 values. Independent platform file
hashes also matched the native loader's source hashes. The native inspector
confirmed finite, non-silent outputs with peaks below unity.

Example commands for already downloaded, hash-verified files:

```text
pythian.remix build/corpus/pixel-sprinter.wav build/corpus/pixel-sprinter-remix.wav 731 512
pythian.remix build/corpus/opening-theme.wav build/corpus/opening-theme-remix.wav 731 512
pythian.inspect build/corpus/pixel-sprinter-remix.wav
```

These are integration and signal-level observations. They do not establish
operator listening approval, meaningful long-form development, general corpus
coverage, beat accuracy or source separation. Silence and opposite-polarity
stereo are additionally covered by analytic fixtures; their presence in these
two recordings has not been annotated or assessed as a musical ground truth.
