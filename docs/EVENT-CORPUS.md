# Shared recorded-event learning

[Home](../README.md) · [Event learning](EVENT-LEARNING.md) ·
[Pulse admission](PULSE-EVENTS.md) · [Layered style](LAYERED-STYLE.md) · [Work](WORK.md)

`pythian.wfc.event.corpus` learns one event vocabulary from selected recordings in
an existing measured acoustic corpus. It reuses native passage measurements and
the actual WFC sequence learner. Every song and admitted run remains a separate
training sample; merging evidence does not introduce transitions between them.

## Library contract

`TRecordedEventLearning.Create(Corpus, Inputs, QuantumFrames, PaletteSize, Order)`
accepts 1..32 source inputs. Each input names an original corpus source index,
strictly increasing passage bounds, local run indices and onset-start flags.
Run indices follow the existing event partition contract: -1 excludes an interval;
admitted runs are dense, ordered and contiguous. A run cannot resume across a
gap. Each selected source must contribute at least one run, and a source can
appear only once. Duplicate evidence requires a future explicit weighting policy.

The shared palette is trained only from admitted interval measurements across
all selected sources. Excluded intervals train neither the palette nor WFC and
cannot become reconstruction members. Each admitted interval contributes one
observation; longer recordings may therefore contribute more evidence. Inputs
share the measured corpus's sample rate/channels and one explicit duration
quantum. Separately trained palette indices are never concatenated or equated.

Limits are 4096 intervals per source, 65536 total input intervals, 4096 training
runs, 1..32 palette classes and WFC orders 1..4. Actual companion model limits
still apply. The palette/model are owned by the learning object and exposed as
borrowed immutable definitions. Source identities, members and model data are
detached from the input corpus/arrays; those inputs may be freed after creation.
[Recorded-event archives](EVENT-ARCHIVE.md) now persist and independently admit
these definitions without FFT, clustering or WFC relearning.

Each member retains its original corpus source index, exact start/frame count,
input interval index, global training-run index and acoustic/duration/onset token.
`SelectMembers(Tokens, Seed)` prefers an observed matching neighbor in the same
run; otherwise it chooses deterministically among matching recorded members.
It accepts 1..1024 tokens with at most 16777216 member comparisons. It selects
source realizations; actual WFC generation/path validation is a separate step.

## Native reconstruction

The `pythian.passage.RenderPassages` overload accepts borrowed same-format source
clips and `TRecordedPassages` with explicit source/start/count fields. Its native
core has no WFC dependency. Existing single-source rendering delegates to the
same implementation and retains its output.

Contiguity requires the same source index and adjacent source coordinates.
A switch between recordings receives the existing within-fragment linear edge
fades even when their frame numbers happen to align. Output uses original source
durations, with no stretching, resampling or overlap mixing. All source ranges,
format agreement and the 16000000-scalar-sample output ceiling are checked before
audio allocation. Source slots and output references are caller-owned; external
WAV identity verification belongs at the file boundary.

## Operator workflow

```text
pythian.event.merge INPUT.pyac OUTPUT.wav SEED EVENTS SOURCE.wav ONSETS.json [SOURCE.wav ONSETS.json ...] [--pulses]
```

The operator loads exact source WAV hashes against the measured corpus and admits
each onset report through the shared native reader. Default mode uses onset
intervals; `--pulses` applies the existing tracked-pulse admission independently
to each recording. It uses a shared eight-class event palette, order 2, a roughly
20 ms frame quantum and bounded actual WFC fragment generation. The library API
exposes palette size, order, quantum and per-source interval/run choices.

Output is a PCM16 WAV, actual WFC model text (`.wfcs`), JSON evidence and a reusable
recorded-event archive (`.pyac`). Evidence includes
source attribution/hashes, original interval/run admission, shared palette,
model/output hashes, solver versions and every selected source/output range.
The acoustic archive's existing model attachment is not used for event training.
Use the [saved operator mode](EVENT-ARCHIVE.md#native-use) to generate from the
archive without onset reports or learning. Writes are not an atomic four-file transaction.

The source table can select a subset of a measured corpus. The operator translates
original corpus indices to loaded audio slots only at rendering. Inputs cannot
be overwritten by the output paths; duplicate recordings and incompatible inputs
reject. Neither successful generation nor a shared palette guarantees that a
particular output selects fragments from every contributing song.

## Evidence and limits

Checked FPC 3.2.2 and 3.3.1 i386-win32 builds use
`-B -Sa -Cr -Co -Ci -gl`. The focused fixture compares complete model text against
three independent manually specified WFC samples, verifies song/gap separation,
duplicate-source rejection, detached ownership and an independent sample/gain
oracle across both a contiguous join and a recording switch. Existing native
passage checks pass unchanged. Logs and artifacts are under
`build/event-merge-{stable,trunk}/`.

The attributable Pixel Sprinter and Opening Theme recordings in the
[existing corpus](WAV-LEARNING.md) pass both operator modes with seed 731 and
64 generated events:

| Mode | Admitted events | Independent runs | Tokens / states | Output frames |
| --- | --- | --- | --- | --- |
| Pulse intervals | 191 | 12 | 71 / 145 | 1207709 |
| Onset intervals | 1251 | 2 | 100 / 625 | 283462 |

Both sources contribute training observations. In these particular outputs,
pulse mode selects Pixel Sprinter members and onset mode selects Opening Theme
members exclusively. This proves shared training and valid source reconstruction,
not audible blending of both songs. A separate native checker verifies source
file hashes and every output PCM sample against source coordinates and an
independent edge-gain calculation. WAV, JSON and model replay across compilers,
plus unchanged single-source pulse output, are recorded in
`build/event-merge-replay.log`.

The standard build includes the corpus fixture and operator/output-checker smoke
using its existing authored synthesis source. That smoke was exercised separately
in `build/event-merge-stable/smoke-{run,verify}.log`; it retains 16 events and
176252 frames. A duplicate-source operator request rejects with all three prior
output hashes unchanged (`build/event-merge-stable/rejection.log`). This checkpoint
does not claim a full-suite rerun, refreshed package or another target platform.

These events retain coarse acoustic/duration relationships. They do not establish
isolated musical voices, annotated beat accuracy, learned phrase structure,
weighted style profiles or recursive style blends. Saved event admission is now
implemented; per-layer normalized representations and explicit source weighting remain next
steps under the [accepted style architecture](LAYERED-STYLE.md).
