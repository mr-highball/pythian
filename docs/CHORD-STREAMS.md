# Streaming chords with delayed release

[Home](../README.md) · [MIDI and clocks](MIDI.md) · [General scheduled synthesis](SCHEDULING.md) ·
[Provenance](PROVENANCE.md) · [Work](WORK.md)

`pythian.chord.stream` extracts WFC's incremental ensemble preview renderer into
a standalone native API. It accepts one bounded frame of independent chords at
a time, preserves phase through holds, and can end a gate whose duration was
unknown when it started. A short output delay lets it shape the gate's final
samples retrospectively. No complete score or audio clip is retained.

## Native contract

`TChordStreamRenderer` takes `TChordStreamOptions` and one declared maximum chord
size per voice. `TChordFrame` contains the same number of voices, each with an
action and pitch/velocity tones. Pitches are strictly increasing MIDI values
0..127, with velocity 1..127. Rest has no tones; attack starts fresh oscillator
phase; hold must exactly match the preceding chord's pitches and velocities.
The renderer owns detached copies of capacities and admitted voice state.

`AdmitFrame(Frame, FrameCount)` uses sample-frame duration, including zero.
Even a zero-frame interval applies its actions. Admission requires `NeedsInput`;
drain `ReadSamples` between intervals. Invalid voice data, mismatched holds,
undrained admission and cumulative count overflow reject without changing the
previous state or delayed audio. Unexpected processing failures mark `Failed`
and reject further processing. Calls are sequential, without host callbacks.

`ReadSamples(MaxFrames, Samples)` returns detached normalized PCM16 values in
`TAudioSamples`, at most 2048 frames per call. A false result clears the output;
inspect `NeedsInput`, `Finished` or `Cancelled` to distinguish states.
`EndInput` closes the active chords and drains exactly the admitted duration.
`Cancel` discards all unreturned PCM and is terminal. Destruction performs no
I/O or draining. Samples already returned to the caller are never revised.

The retained mix ring has `ReleaseFrames + 1` integer slots. When a voice ends,
its oscillator phase is rewound only within that window to replace its previous
contribution with the release-shaped contribution. Other voices keep their own
phase and age. Attack and release gains combine by minimum, retaining the
precursor's integer rounding and fixed headroom from the declared capacities.

Limits are explicit:

- 1..384000 Hz; master volume 0..127; attack/release each 0..one second in frames.
- 1..4096 voice slots and at most 4096 declared tones in total. Zero-capacity
  silent slots are allowed; an all-silent configuration uses headroom one.
- Declared tone count times release frames is at most 16777216, bounding work
  when all voices close together.
- Cumulative frame counts fit nonnegative Int64. Rendering and memory stay
  incremental; elapsed duration does not enter phase multiplication.

The oscillator uses Pythian's existing fixed Q12 tuning and 24-bit triangle phase.
It preserves WFC's non-bandlimited preview sound. The general native synthesizer
continues to provide other source families, stereo placement and ADSR release
after note-off. Those are different rendering contracts.

## WFC bridge

`AdmitWfcEnsembleFrame(Renderer, Clock, Frame, LengthTicks, Tempo)` in
`pythian.wfc.music` converts an actual `TWfcMusicEnsembleFrame` and advances a
borrowed `TIncrementalTempoClock`. Clock sample rate and admitted sample extent
must match the renderer. Tick duration must be positive; fractional timing can
still produce a zero-sample interval. Rejected renderer admission restores the
clock's complete prior snapshot, including fractional carry.

The caller supplies one constant tempo per interval. Split an interval at a
tempo change, using holds for already attacked voices in later subdivisions.
Generator segment boundaries have no special audio meaning: continue feeding
the same renderer and clock so a leading hold can retain its predecessor.
Actual WFC models, solvers, arrangement policy and segment provenance remain
at the companion boundary. The [learned ensemble consumer](ENSEMBLE-STREAMS.md)
now plans a bounded phrase and realizes it through the actual ensemble stream,
preserving generated holds and comparing complete PCM against WFC.

`WfcEnsembleCapacities` now derives detached voice limits from the entire learned
vocabulary, checking native tone bounds before rendering. Its independent
capacity/ownership checks and example usage are recorded with that consumer.

## Native listening example

The normal build includes [pythian.chord.demo](../tools/pythian.chord.demo.lpr):

```text
pythian.chord.demo OUTPUT.wav
```

It streams an authored C–F–G–C progression with independent bass gates through
the native clock, renderer and sequential WAV writer. Thirty-two intervals
produce 352800 mono frames at 44100 Hz: exactly eight seconds, with an 882-frame
release delay and no appended tail. This is an extracted-renderer example,
not learned musical generation.

Artifact: `build/3.3.1-i386-win32/chords.wav`, SHA256
`0f3876e6748bb4b3fdff94bd07db5f021e96c1b363197e5c9dbc111bb1a91262`.
Peak is 0.491730; RMS is 0.150657. The stable compiler produces identical WAV
bytes. Listening quality has not been evaluated.

## Evidence — 2026-09-14

The [single native fixture](../tests/pythian.tests.chord.stream.lpr) compares the
stream with independently specified finite note gates. It exercises overlapping
chord/bass endings, zero-duration input, short notes whose attack and release
overlap, ring wrap, block-size changes, detached input/output/capacities,
changed-hold rejection, count overflow, premature end and cancellation.

With `WFC_CHORD_CHECKS`, the same fixture also feeds the actual precursor
`TWfcMusicEnsembleAudioRenderer`. Every emitted PCM sample agrees despite
different output-block sizes. Both FPC 3.2.2 and 3.3.1 i386-win32 pass:

| Rate | Release | Compared frames |
| --- | --- | --- |
| 44100 Hz | 20 ms | 19851 |
| 48000 Hz | 0 ms | 21606 |
| 32000 Hz | 1000 ms | 14404 |

The shared timeline includes zero-sample actions and tempo-crossing held chords.
A rejected changed-velocity hold preserves the native clock before valid retry.
This is evidence for the shared preview contract, not a claim that all native
synthesizers match WFC or that larger native bounds were exercised exhaustively.

Logs: `build/chord-native-validation.log`, `build/chord-wfc-validation.log`,
`build/chord-development-validation.log`, `build/chord-demo-validation.log`,
`build/chord-demo-replay.log` and `build/chord-inspect.json`.
