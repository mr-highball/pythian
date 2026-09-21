# Pitch-class profiles and diatonic fit inspection

[Home](../README.md) · [Provenance](PROVENANCE.md) · [MIDI](MIDI.md) ·
[WAV learning](WAV-LEARNING.md) · [Corpus](CORPUS.md) · [Work](WORK.md)

## Extracted behavior

[pythian.tonal](../src/pythian.tonal.pas) extracts the duration histogram and
major/natural-minor selection heuristic from Phanes's
`tools/phanes.tools.midi.pas:ExtractSamples`. The source's complete MIT notice
and 2026 copyright holder are retained.

Phanes caps each note at four quarter notes, ignores velocity and picks the
first best scale fit. Its fixed excerpt windows, density bins and forced
nearest scale-degree mapping remain application policies. Pythian exposes
the duration cap, optional velocity weighting, all 24 ranked candidates,
coverage and score gap. It never changes notes or forces chromatic pitches
into a selected scale. This extraction uses Phanes's estimator; WFC's symbolic
score and training contracts remain at the companion boundary.

The same ranking accepts profiles aggregated from stored WAV chroma.
This adds an inspectable shared representation across MIDI and WAV sources.
It does not establish a musical key, recover fundamental pitches from polyphonic
audio, transcribe notes or alter a learned WFC model.
The separate [periodic pitch path](PITCH.md) now supplies single-source frequency
candidates and declared monophonic WAV-to-note learning. Chroma retains its
existing meaning; neither path establishes isolated voices in mixed music.

## MIDI weights

`NotePitchClassWeights(sequence, maximumNoteTicks=0, velocityWeighted=False)`
returns twelve nonnegative Double weights, indexed C=0 through B=11.
Each note contributes its gate duration in PPQ ticks to pitch modulo 12.
Zero cap means uncapped. Otherwise, each note's contribution is capped
independently. Optional velocity weighting multiplies duration by velocity/127.

Phanes-compatible weights use `4 * Int64(sequence.TicksPerQuarter)` and
velocity weighting disabled. Tempo changes do not affect musical tick duration.
Note release velocity, pedal extension and instrument interpretation are not
introduced. The immutable sequence remains borrowed and unchanged.

## WAV weights

`FeaturePitchClassWeights(features, options, sourceFrames, energyWeighted=False)`
uses existing normalized chroma windows. It does no FFT itself. The geometry,
RMS/silence relationship and chroma normalization are validated before
publishing a detached profile.

Each feature contributes `min(hopFrames, remainingSourceFrames)` duration
weight. This partitions source coverage instead of summing overlapping window
lengths. The chroma measurement still came from its full analysis window;
this weighting does not improve its time or pitch resolution.

With energy weighting enabled, the duration weight is multiplied by RMS
squared. Duration weighting gives equal-duration windows equal influence;
energy weighting emphasizes louder passages. Silent/empty chroma contributes
no pitch evidence. A non-silent signal outside the analyzer's chroma range may
also have no chroma evidence.

The existing analyzer uses spectral power folded into nearest pitch classes
for bins from 27.5 through 5000 Hz. Harmonics, leakage, percussion and mixtures
can therefore affect the profile. It is not a fundamental-frequency estimator.
Profiles use sample-frame units, optionally multiplied by RMS squared.
Normalized fits can be compared across profiles; raw MIDI tick totals and
WAV sample-frame totals are different units.

## Fit ranking and uncertainty

`RankDiatonicFits(weights)` checks finite nonnegative weights, each at most
1E100, and recomputes their total. For each root and major/natural-minor scale:

`rawScore = sum(weights in scale) + 0.15 * tonicWeight + 0.05 * fifthWeight`.

The precursor's operation and tie order are preserved before normalization.
Candidates sort by decreasing raw score, with exact ties retaining ascending
root and major-before-minor order. There are at most 24 candidates.

`Score` is raw score divided by total weight, so it can exceed one.
`Coverage` is in-scale weight divided by total weight. `ScoreGap` is the
difference between the best two normalized scores. None is a calibrated
probability or a correctness guarantee. A small gap exposes ambiguity rather
than resolving it. Floating-point arithmetic can distinguish mathematically
equal fits at very small scales; only exact computed ties use the tie policy.

Zero total weight yields no candidates, zero gap and candidate roots of -1.
It does not invent C major as an empty-input answer. Feature RMS is bounded
to the finite Single audio range with the same small rounding allowance used
for measured corpus admission. Existing note/analysis bounds keep constructed
profiles well below the general weight bound.

## Native inspection

The [native tool](../tools/pythian.tonal.inspect.lpr) prints JSON:

```text
pythian.tonal.inspect midi INPUT.mid [MAX_NOTE_TICKS]
pythian.tonal.inspect wav INPUT.wav [duration|energy]
pythian.tonal.inspect corpus INPUT.pyac [duration|energy]
```

MIDI mode uses strict note import, a default four-quarter-note cap and no
velocity weighting. A supplied zero cap disables the cap. The output records
the cap, PPQ, note count and discarded metadata/release-velocity/zero-length
counts. Unsupported performance events and ambiguous/dangling notes reject.

WAV mode performs the default 4096-frame/1024-hop analysis. Corpus mode uses
the existing measured features and emits a separate profile for each recording,
preserving source hashes and attribution. It reads the core archive while
treating any companion attachment as opaque; it does not validate WFC model
counts or run a learner. Use the model-specific archive loaders for generation.

All modes include policy versions, input identity, raw pitch-class weights,
all ranked fits and explicit score interpretation. WAV/corpus weighting
defaults to duration. No file is modified by this tool; redirect its JSON
into ignored build output.

## Verification

The [native fixture](../tests/pythian.tests.tonal.lpr) checks empty and uniform
profiles, exact tie ordering, independently calculated triad membership/bonuses,
duration caps, optional velocity weighting, non-overlapping coverage and energy
weights. Invalid chroma preserves the previous result. A bin-coherent A440
signal passes the actual FFT/chroma path and assigns over 99.9% of profile
weight to pitch class A; a single pitch does not establish a major/minor key.

Before reference removal, the optional `PRECURSOR_CHECKS` build called actual
Phanes `ExtractSamples` on 32 fixtures with varied pitches and durations. It
matched every selected root/mode using the explicit compatibility cap. Those
32 root/mode pairs are now constants in `CheckReferenceSelections`, exercised
by the ordinary native fixture without any Phanes import. The final actual-source
comparison and each captured pair are recorded in
`build/removal-audit/tonal-reference-run.log`; its build log identifies FPC 3.3.1
and the original comparison source is retained under that ignored audit directory.
The source revision remains `21cbefee1de7c41c468751246354f846711e07c8`.

Fixture case `c` in 0..31 contains 24 notes, with index `i` in 0..23: start
`i * 480`, duration `(1 + (i + c) mod 7) * 480`, pitch
`48 + (i * 7 + c * 3) mod 36`, velocity `1 + (i * 11) mod 127`. PPQ is 480,
the sequence ends at `31 * 480`, and tonal duration is capped at `4 * 480`.
The preserved constants were measured from the precursor, not generated from
the native implementation. Both installed compilers pass the resulting standalone
fixture; logs are `build/removal-audit/tonal-{stable,trunk}-{build,run}.log`.

On 2026-09-14, FPC 3.3.1-20634-gd7f522a561 for i386 Windows passed
`./tools/build.ps1 -CoreOnly`, including all 40 core units, checked native
fixtures and MIDI/WAV inspection smokes. Log: `build/tonal-validation.log`.
The WFC implementation is unchanged; its previous full integration evidence
remains in `build/timing-validation.log`. No new WFC integration claim is
inferred from the core-only run.

Focused logs: `build/tonal-focused-validation.log`,
`build/tonal-tool-validation.log` and `build/tonal-precursor-validation.log`.
Those earlier logs retain their original scope. The normal build now runs the
captured selections along with the independently calculated tonal fixtures;
see the [reference removal audit](REFERENCE-REMOVAL.md).

The [two attributed CC0 recordings](CORPUS.md) produce these heuristic results
from their saved measurements:

| Recording | Weighting | Best fit | Runner-up | Normalized gap |
| --- | --- | --- | --- | --- |
| Pixel Sprinter | Duration | F major | D natural minor | 0.0011096367 |
| Pixel Sprinter | Energy | F major | D natural minor | 0.0109128256 |
| Opening Theme | Duration | C major | D natural minor | 0.0087405313 |
| Opening Theme | Energy | F major | C major | 0.0017108507 |

These are observations of this heuristic, not verified keys. The different
Opening Theme rankings demonstrate sensitivity to weighting. No annotated
tonal ground truth was supplied.

Evidence files: `build/corpus/tonal-duration.json`,
`build/corpus/tonal-energy.json`, `build/corpus/tonal-pixel-wave.json`
and `build/tonal-midi.json`. The raw Pixel Sprinter WAV also passes direct
analysis/inspection. Its reported best fit and gap agree with the stored-feature
duration profile. The original archive and source bytes remain unchanged.

The later standalone captured-result fixture passes on FPC 3.2.2 and 3.3.1
i386-win32. Other targets, broad key-estimation accuracy and operator listening
remain unverified. The complete [Phanes removal audit](REFERENCE-REMOVAL.md) has
since passed; broader WAV learning goals retain their documented limits.
