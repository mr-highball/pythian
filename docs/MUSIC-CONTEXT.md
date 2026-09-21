# Typed musical context and WFC providers

[Home](../README.md) · [Layered style](LAYERED-STYLE.md) ·
[Coupled passes](LAYERS.md) · [Native clock](../src/pythian.time.pas) · [Work](WORK.md)

## Native timeline and scope

[WAV context admission](WAVE-CONTEXT-ADMISSION.md) connects measured tonal fits
to explicit key/unknown decisions and complete-cell scopes under a declared
constant clock. The native API stays independent of WFC; the operator creates
saved companion profiles and retains an external measurement report.

`pythian.music.context.TMusicContext` owns a copied `TTempoMap` and ordered
`TKeyChange` records. Key context must start at tick zero. Each change holds
until the next one, including a query exactly at the timeline endpoint.
There are at most 65536 changes. `CopyClock` and `CopyKeys` are detached;
the original clock and input arrays can be released or changed after construction.

`TKeyContext` currently admits roots 0..11 and the existing major/natural-minor
modes. Root -1 with major mode is the canonical unknown value, carrying no
claim of major tonality. Unknown remains explicit through learning and decoding.
This contract does not automatically accept the top tonal-fit candidate as a key.
Other modes, time signatures and uncertain tempo candidates need separate
admission or extensions; a positive tempo map represents a selected output clock.

`Grid(StartTick, StepTicks, CellCount)` compiles a requested half-open PPQ scope.
It returns copied key and microseconds-per-quarter values for every complete
cell, retaining PPQ, start offset and step. A value applies over the whole cell.
At most 65536 cells are admitted, with the end tick inside the existing Integer
timeline domain. A declared key or tempo change strictly inside a cell rejects,
even when its value repeats. Refine the grid or choose a different scope
explicitly; no averaging, rounding, inferred bar boundary or hidden resampling
occurs. Changes exactly at the right edge belong to the following scope.

The timeline keeps its original clock. A scoped grid stores the source start
tick, but is not an archive of source identity or an audio-frame mapping.
Use the original clock for absolute source timing. A future profile must retain
the grid's source identity and admission evidence in addition to these values.

## Actual WFC context learning

`pythian.wfc.context.LearnContextModel(Grids, Dimension, Order)` returns an
owned actual `TWfcSequenceModel` for `cdKey` or `cdTempo`. Every supplied
grid is a separate open training sample. Input grids must share exactly the
same PPQ and step; even mathematically equivalent alternative resolutions need
explicit normalization before admission. Different start offsets and lengths
are allowed. Limits are 4096 samples, 65536 total cells and orders 1..4, plus
the real WFC model's vocabulary/state bounds.

Each cell contributes one observation, so longer excerpts contribute more.
Repeated excerpts also repeat their evidence. This API does not invent
weights or transitions across source boundaries. Key and tempo models are
independent marginals; required key/tempo/voice joint relationships still need
explicit additional models/projections. Independent models do not prove that
every generated combination occurred in the sources.

The versioned semantic identifiers are `pythian.context.key.v1` and
`pythian.context.tempo.v1`. Canonical key tokens append
`root * 2 + modeOrdinal` (major 0, natural minor 1), or `unknown`.
Tempo tokens append exact integer microseconds per quarter, avoiding rounded
BPM conversion. Decoders reject noncanonical spellings. These identifiers name
the two provider vocabularies; the generic layer adapter still binds graph
dependencies by position rather than a general semantic registry.

`MusicContextFromTokens(Keys, Tempos, PPQ, StepTicks)` creates an output
timeline starting at zero. It coalesces consecutive equal values and builds
the existing exact PPQ clock from the tempo sequence. The caller owns the
result. The caller must retain and supply the learned model's PPQ/step contract:
serialized WFC model text alone does not store it. This function validates typed
values and matching extents; latent path validity remains the solver/capture
contract. It does not transpose or retime a source WAV.

## Demonstration and evidence

The [context-learning bundle](CONTEXT-ARCHIVE.md) now saves admitted excerpts,
source identities/policies, PPQ/step and both canonical provider models together.
The current demo writes `OUTPUT_PREFIX.ptc` and two authored source declaration
files, releases original learning, then reloads from disk and verifies the source
hashes before generating the four WAVs below. Restored model copies outlive the
bundle. The earlier direct-learning evidence below retains its recorded scope;
archive replay has a separate checkpoint.

Native command: `pythian.context.demo OUTPUT_PREFIX`.

Two authored eight-cell excerpts supply C major / 500001 us per quarter and
D natural minor / 600001 us per quarter. The adapter learns key and tempo
providers. Two further learned models provide bass pitch and note-gate length.
Explicit complete projections connect key to bass, and tempo to gate length.
The generated tempo also controls native note rendering at 24000 Hz.

The demo runs all four key/tempo pin combinations through
`TryGenerateLayers`, which uses actual WFC overlay passes, negotiated solving,
path capture and relation validation. It checks every output token against its
declared dependency before producing:

| Suffix | Bass MIDI pitch | Gate ticks | Stereo frames |
| --- | ---: | ---: | ---: |
| .c-fast.wav | 48 | 240 | 48000 |
| .d-fast.wav | 50 | 240 | 48000 |
| .c-slow.wav | 48 | 120 | 57600 |
| .d-slow.wav | 50 | 120 | 57600 |

PPQ is 480, step is 240 ticks. A key pin changes bass while preserving the
selected tempo/rhythm; a tempo pin changes the rhythmic descendant and duration
while preserving the selected key/bass. Each request solves the full graph;
this example does not implement caching or selective graph regeneration.
These are controlled synthesized phrases, not automatically extracted WAV
keys/voices or a claim of reusable style blending.

The later [context profile workflow](CONTEXT-PROFILES.md) selects and persists
these independent providers through repeated derivation. It retains parent
history and rebuilds the demo's gate binding for each selected tempo vocabulary,
while preserving all four rendered outputs. General style blending remains open.

Checked FPC 3.2.2 and 3.3.1 i386-win32 evidence is under
`build/context-{stable,trunk}/`. Native tests cover unknown context, detached
ownership, half-open scope, rejected interior changes, overflow admission and
an independently calculated fractional-clock endpoint. Adapter tests compare
the complete learned model text against two explicitly separate samples at
orders 1..4, exercise canonical decoding and reconstruct a changing output clock.
The four-pass demo checks all pin combinations and exact rendered durations.
All four WAV files are byte-identical across the two compilers;
`build/context-replay.log` records comparisons and hashes. New owned units
compile without warnings; existing companion/FCL warnings remain.
Normal builds include both focused fixtures and the demo. Existing package
archives predate these units; this is not a package or full-suite checkpoint.
