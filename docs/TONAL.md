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

## Recorded key reference comparison

The next [local-key task](TODO/NS-3_context_01.md) comparison separates the
existing waveform representation from tonal interpretation. It uses the two
already audited external WAV/note references in the
[reference screen](STYLE-CARDS.md#reference-screening-and-musical-controls--2026-09-21),
preserving their shared development exposure. Original microphone chroma and
external note-duration profiles feed the same unchanged diatonic ranker.
The latter is an annotation-derived diagnostic, never an audio prediction.

The policy fixes the existing 4096-frame window, 1024-frame hop and 0.0001 silence
threshold, with duration weighting. Inspect each whole excerpt and eight-second
crops at four-second starts, retaining terminal crops of at least four seconds.
Every crop has explicit source-frame bounds and only its own end padding.
Retain all 24 candidates, weights, coverage and score gaps. External simultaneous
notes contribute their intersected sounding-frame duration without amplitude or
velocity weighting; summed note duration is not elapsed-time coverage.

Both WAV-only observation files must precede reference comparison. Exact hashes
bind original sources, accepted annotation packets, study source and fixed policy.
The publisher's whole-excerpt key convention is a declared reference diagnostic;
it does not independently annotate each crop or verify an absence of modulation.
No local-key accuracy or confidence claim follows from matching that convention.

Stop after this paired comparison. Failure even with the supplied notes points
toward tonal/temporal interpretation; failure confined to WAV evidence points
toward the waveform representation. Agreement calls for broader annotated
development coverage before admission calibration. None justifies a threshold
sweep on these two examples. The private native study under
`build/local-key-reference/` has completed both WAV observations in checked Win64
QA, within the work bound and with zero unfreed blocks. Comparison exposed a
study bug: the second publisher label is D minor, while the comparer assumed
D major. The repair retains the original observer source and both observation
artifacts, binds their exact hashes and uses the declared mode. A separate
comparison-source identity records that repair. QA accepts both repaired
comparisons with unchanged original observation fields, exact retained A-case
results and zero unfreed blocks. No waveform observation was repeated.

| Declared whole-excerpt key | WAV rank of declared key | External-note rank | WAV best/runner-up score gap | External-note score gap |
| --- | ---: | ---: | ---: | ---: |
| A major | 2 | 1 | 0.0009294803 | 0.0351228676 |
| D minor | 1 | 1 | 0.0072218663 | 0.0068233434 |

The A-major WAV profile ranks D minor narrowly ahead, while its supplied-note
profile ranks A major first. Under the fixed diagnostic policy, the next
investigation concerns the waveform representation; these examples do not
establish a general tonal-interpretation solution. Both representations rank
the D-minor convention first. The six/seven retained regions are diagnostic
windows, not independently labeled local-key cases. Score gaps remain uncalibrated.

The two observation passes used 127,746,048 / 156,991,488 planned FFT work units
and 4,500 / 5,484 ms, within the fixed budget. Exact source/observation/comparison
identities and the original failed comparison remain in
`build/local-key-reference/` and `build/qa-batch-08/`. No maintained algorithm,
confidence threshold, automatic admission or completion credit changes.

Source inspection identifies a concrete representation limit: the current
extractor assigns power using each FFT bin's center frequency. At 44,100 Hz with
4096 samples, bins are approximately 10.77 Hz apart, wider than low guitar
semitones. This does not yet prove the cause of the recorded ranking difference.
A single fixed private experiment now compares interpolated spectral peaks
with the unchanged ranker, starting with twelve known low-register tones and
then the same two exposed WAVs. It reuses the original baseline observations;
there is no parameter sweep or change to the maintained extractor.

The [published peak-profile method](https://essentia.upf.edu/reference/streaming_HPCP.html)
provides context for this representation choice. The local experiment uses a
simpler declared linear pitch-class split and claims no external implementation
parity. Its source and policy are frozen under `build/local-key-reference/`.
Checked Win64 QA passes all twelve known tones and silence, with no owned leaks.
The default representation assigns the wrong dominant class to five of these
low-register tones; the peak representation retains the intended class in all
twelve. This establishes the controlled representation limitation, not a general
transcription or key-detection result.

Both candidate WAV observations completed before interpretation. The declared
A-major whole-excerpt key improves from rank 2 to rank 1; D minor remains rank 1.
All six/seven original crop boundaries, 24 candidates and raw scores are retained.
The observation runs take 4,110 / 5,046 ms and 127,746,048 / 156,991,488 planned
FFT-work units, within the fixed budgets. That result led to the
[timed development comparison](#timed-development-comparison) below, before
maintained adoption or calibration. The initial pair does not establish
local-key accuracy, confidence, unknown rejection or independent acceptance.

## Local-key reference candidate

The [Schubert Winterreise Dataset 2.1](https://zenodo.org/records/10839767)
was screened on 2026-09-21 as a candidate for recorded local-key/change evaluation.
Its published inventory includes WAV recordings and three audio local-key
annotation sets. The archive is 517.4 MB with publisher MD5
`591c377c6d3db522fd159b8b70180978`. Acquisition into ignored build output now passes
the exact 517,380,038-byte length and publisher checksum; local SHA256 is
`774b9b874a82af042ee76f38260acab16bf6ef275c6d67363f96ce63167b99f5`.
The bundled README still calls itself version 2.0; preserve that original text
alongside the version 2.1 archive identity. No recording has been scored or admitted.

Original notices were inspected. The README declares CC BY 3.0 for the dataset;
the HU33 notice points to the Public Domain Mark, while the SC06 notice points
to CC BY-NC-ND 3.0. The README's description of SC06 differs from that notice.
The present development selection uses HU33 only and retains all notices;
no recording is included in published source or artifacts.

Only compositions D911-02 and D911-16 have been selected for development, with
their HU33 WAVs and all three matching local-key CSVs extracted unchanged.
Every performance of those compositions belongs to the development exposure
group. Remaining annotation/audio contents have not been inspected or scored.
The README declares the main audio as 22,050-Hz mono and annotation times in
seconds; the native reference preflight now verifies decoded geometry and exact
decimal time-to-frame conversion with nearest-frame, ties-upward rounding.
It also documents an artificial repeat in HU33 D911-01, which is excluded from
this selection. Do not interchange main-folder annotations with the separately
provided original-short material.

The supplied annotations already show an important boundary: annotator 2 leaves
gaps, while the other annotations may supply a key across the same passage.
In D911-16, the annotators disagree on the transition out of D major and one
includes B minor. Retain each annotator, missing coverage and disagreement;
absence is not an independently verified non-tonal label. No single annotation,
majority vote or filled gap is silently substituted for uncertain ground truth.
The later [score-to-audio ambiguity check](#score-transferred-ambiguity-check--2026-09-23)
qualifies four *interior ann2* gaps as that annotator's ambiguous/no-key policy,
while preserving this non-tonality limit and leaving leading/trailing gaps
unlabelled.

The checked Win64 preflight passes bounded original-byte identity, interval and
coverage checks with no owned leaks. Each row below partitions the full decoded
source, including unlabelled leading/trailing audio. Partial coverage means one
or two annotators supplied a label; disagreements within that category remain
explicit in the retained regions.

| HU33 development composition | Original frames | Unlabelled | Partial coverage | Full coverage, disagreement | Unanimous |
| --- | ---: | ---: | ---: | ---: | ---: |
| D911-02 | 2,230,272 | 122,292 | 772,632 | 152,145 | 1,183,203 |
| D911-16 | 3,053,568 | 121,359 | 624,456 | 84,231 | 2,223,522 |

Full-coverage disagreement does not require three distinct keys. Original annotator interval counts are
12/5/9 and 3/3/4. Five/two partially covered regions also disagree. Preflight
takes 329 / 438 ms, without waveform scoring. The exact packets and original
notices remain under `build/local-key-reference/swd/`; no reference-packet pass
earns task credit or changes the recorded material's development exposure.

The related [cross-version study](https://www.audiolabs-erlangen.de/content/05_fau/professor/00_mueller/03_publications/2020_SchreiberWM_LocalKey_ICASSP_PrintedVersion.pdf)
demonstrates why unseen performances of a familiar composition are insufficient
evidence of generalization to new music. Its annotation policy also assigns a
likely key to ambiguous passages. Therefore inspect each supplied annotation
policy, preserve disagreement and unknown regions, and group all versions of a
composition together before choosing development and untouched evaluation cases.

The next admission step belongs to [local-key acceptance](TODO/NS-3_context_01.md).
The fixed development comparison below uses the accepted reference preparation;
supported change/coverage limits and calibrated uncertainty remain prerequisites
to maintained admission and independent evaluation. Reference preparation alone
does not establish genre suitability or unknown rejection.

## Timed development comparison

The predeclared baseline/peak comparison now passes its native mechanics and
resource checks but fails its scientific requirement of improvement without a
source regression. Both full original 22,050-Hz mono recordings were observed
before comparison read either reference packet. The fixed 4,096-sample Hann /
1,024-hop lattice supplies identical four-second output cells and centered
eight-second aggregation contexts. Actual FFT support is retained separately;
local boundaries do not create artificial padding. All 24 fits and score gaps
remain available. The existing diatonic ranker is unchanged.

| Development source | Unanimous labelled frames | Baseline exact root/mode matches | Peak exact root/mode matches |
| --- | ---: | ---: | ---: |
| HU33 D911-02 | 1,183,203 | 553,455 (46.776%) | 791,154 (66.865%) |
| HU33 D911-16 | 2,223,522 | 1,055,754 (47.481%) | 791,154 (35.581%) |

The unweighted two-source mean changes from 47.129% to 51.223%, but source 16
regresses, so the frozen no-source-regression condition fails. Each annotator's original labelled
denominator, matches, mismatches and unknown duration is preserved separately,
alongside gaps, partial coverage and disagreement. All source frames reconcile.
Both representations return a candidate for every output cell: unknown duration
is zero. That is a forced development ranking, not demonstrated uncertainty
calibration or evidence that unlabelled audio has a known key.

The twelve known fundamentals and silence pass at this sample rate, as do
partial-hop, final-cell and gap/change/unknown-duration controls. Sources 02/16
produce 26/35 cells, with planned paired FFT work 214,106,112 / 293,142,528 and
elapsed time including serialization 7,360 / 10,078 ms. Conservative owned
clip/feature storage bounds are 35,622,560 / 42,479,072 bytes, not measured OS
process peaks. Both remain within the predeclared 400-million-work, 60-second,
128-MiB and 4-MiB-output limits. Checked stable Win64 runs report zero owned leaks.

One retained source-16 example identifies a concrete interpretation limitation.
At original frames [1,499,400, 1,587,600), all three annotators say D minor and
the eight-second context contains no annotated change. Baseline ranks D minor
then F major; peaks reverse those two. Both share the same diatonic pitch-class
set and equal coverage within each representation. The candidate score gap is
only 0.00171714. The preserved ranker distinguishes relative keys using fixed
root/fifth bonuses; this gap is not confidence. This example motivates checking
tonic/mode and temporal evidence, without claiming it explains every error.

Policy/source and full reports remain under `build/local-key-reference/swd/`:
`TIMED-POLICY.md`, `timed-key.lpr`, `TIMED-QA.md` and `timed-qa/`. Observation
SHA256 values are `2ad757d0a2d2e8f507d767d76fde6fa04d4124fd127c2be839360f5fb37eb9bc`
and `c5b58f59ee79838b57a3f1744a6ebb07759d93f0f989e3589d94ec0231d511e4`;
the comparison is `e878b267b6f0e653d117f19d72b3c0e27257aec8ace904468d7256f2dad9173c`.
The final verdict is in `build/qa-batch-09/report.txt`. Preserve this result and
inspect its errors/alternatives before declaring another hypothesis. Do not tune
these two recordings until they pass, adopt the candidate, claim independent
accuracy or earn task credit. Other compositions remain untouched.

## Frozen key-error audit

A separate native audit now classifies the saved baseline/peak rankings without
reopening audio, recomputing FFTs or changing predictions. It retains each
annotator and a separate unanimous subset. Every original-frame denominator,
exact/wrong/unknown total, context/category partition and reference-rank histogram
reconciles with the frozen comparison. Relative, parallel and fifth-related
errors remain wrong exact-key predictions; they earn no partial accuracy credit.

| Source / representation | Labelled unanimous frames | Exact | Relative | Parallel | Fifth-related | Other |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 02 / baseline | 1,183,203 | 553,455 | 352,800 | 58,212 | 218,736 | 0 |
| 02 / peak | 1,183,203 | 791,154 | 352,800 | 0 | 39,249 | 0 |
| 16 / baseline | 2,223,522 | 1,055,754 | 88,200 | 347,508 | 441,000 | 291,060 |
| 16 / peak | 2,223,522 | 791,154 | 352,800 | 435,708 | 352,800 | 291,060 |

Unknown prediction duration remains zero. All three individual annotators also
show improvement for source 02 and regression for source 16; the unanimous
subset is not substituted for those separate results. Missing reference duration
and disagreement remain visible, and overlapping groups are not independent cases.

The context split sharpens the diagnosis. In source 16's 1,675,800 unanimous
frames whose entire aggregation context is independently labelled constant by
all three annotators, exact frames fall from 705,600 to 441,000 while relative
errors rise from 88,200 to 352,800. The other error categories in that stratum
are unchanged. Exact totals in annotated-change and incomplete/discontinuous
contexts are unchanged. Thus the net exact-match loss occurs within labelled
constant contexts; it cannot be explained solely by crossing an annotated change.
Incomplete contexts are not called stable, and FFT support remains separately
recorded from the aggregation context used for this descriptive split.

Source 02's unanimous reference is always among the peak ranking's first two
entries. Source 16 instead retains reference ranks as low as fourteenth, including
within fully labelled constant contexts. Both close alternatives and more distant
errors therefore need attention. Inspecting all 24 fits does not establish that
choosing an alternative would be correct without an independent decision rule.

This audit motivated the fixed key-profile comparison below, testing tonic/mode
weighting before temporal smoothing. Its formula and no-source-regression gate
were declared before scoring. The existing precursor-compatible ranker and its
callers remain unchanged. This diagnostic
does not select a maintained classifier, calibrate uncertainty or close context
admission; independent composition-grouped evaluation remains required.

Evidence: `build/local-key-reference/swd/error-audit/` contains the frozen policy,
native source and report; `build/qa-batch-10/report.txt` owns final QA. An initial
inline-string collection truncated a coverage field name and rejected before
output. Explicit String typing and normal exception finalization repair it.
Controls, the full audit and existing-output rejection now pass with zero leaks.
The successful audit takes 1,568 ms, produces 768,557 bytes and reaches
20,414,464 bytes sampled private memory; this is not an exact OS peak.
Report SHA256: `5c2156f540c9186f55235b714c13a1711c003a6df71d1c4bba852c4673f7466e`.
Original failed logs and source identities remain retained. No task credit changes.

## Fixed key-profile comparison

The next native study applies one published Krumhansl–Kessler major/minor profile
pair using Pearson correlation, rotating through all 24 root/mode candidates.
The [method maintainer's description](https://extras.humdrum.org/man/keycor/)
and [Temperley's comparative paper, Table 1](https://davidtemperley.com/wp-content/uploads/2015/12/temperley-ms04.pdf)
provide the formula and numerical weights. No external implementation is copied.
The study holds the saved pitch-class weights, source clocks, cells, contexts and
FFT support fixed; it reads no WAV, runs no new FFT and tunes no coefficient.
All rankings for both recordings are saved before reference comparison. Raw
correlation and score gaps are not calibrated confidence; zero/constant profiles
produce unknowns. This tests interpretation of existing chroma, not a complete
published audio key-estimation pipeline.

The predeclared primary candidate is correlation on peak chroma; correlation on
original bin chroma is a fixed secondary diagnostic. The retain gate requires
an improved mean with neither recording worse than either original ranker result.
Each annotator remains separate; the unanimous subset does not replace them.

| Source | Unanimous labelled frames | Original peak exact | Correlation peak exact | Original bin exact | Correlation bin exact |
| --- | ---: | ---: | ---: | ---: | ---: |
| 02 | 1,183,203 | 791,154 (66.865%) | 378,819 (32.016%) | 553,455 (46.776%) | 176,400 (14.909%) |
| 16 | 2,223,522 | 791,154 (35.581%) | 470,106 (21.142%) | 1,055,754 (47.481%) | 440,559 (19.814%) |

The primary mean falls from 51.223% to 26.579%; unknown predictions remain zero.
All three annotators on both recordings also regress under the primary candidate.
The scientific gate fails. **Reject this fixed profile candidate and preserve the
existing ranker.** Do not switch profiles, smooth the output or tune these two
recordings until they pass. Next inspect changed cell decisions and their
pitch-class contributions against the retained references and alternatives before
declaring another observation/model hypothesis. This result alone cannot isolate
spectral harmonic contamination, temporal aggregation or a profile mismatch.
Independent key/change acceptance and unknown calibration remain open.

Checked stable Win64 controls, both-source prediction, comparison, existing-output
preservation and wrong-hash rejection pass with zero leaks. Prediction takes
1,649 ms and comparison 975 ms, with sampled private memory of 23,101,440 and
24,903,680 bytes respectively. These checks validate the failed experiment's
mechanics, not key accuracy. Source, frozen policy, predictions and comparison are under
`build/local-key-reference/swd/profile-study/`; final validation is recorded in
`build/qa-batch-11/`. Prediction SHA256 is
`d92c4efc4f9bfafb6e3559c33c49004836618dbc917742b5ff011534f92ee561`;
comparison SHA256 is
`12f369f486a6fd4761bb1ff086de0b81f1d8f18421b5227a3d46d4a98bc1d74b`.
No maintained admission behavior, task status or completion credit changes.

## Rejected-profile decision audit

A native audit now exactly reproduces every saved Pearson score before exposing
its twelve signed pitch-class contributions. The original numerator accumulation
and final division remain exact; separately normalized explanatory terms retain
a predeclared residual bound of 1e-12. Every labelled-frame transition reconciles
with the failed comparison, separately for each annotator, representation and
context state. No ranking, observation or accuracy result changes.

For the primary peak representation and unanimous references:

| Source | Previously exact, now wrong | Previously wrong, now exact | Of the losses: relative / parallel / fifth-related / other |
| --- | ---: | ---: | --- |
| 02 | 500,535 frames | 88,200 frames | 0 / 58,212 / 442,323 / 0 |
| 16 | 497,448 frames | 176,400 frames | 176,400 / 0 / 88,200 / 232,848 |

Source 02 loses 176,400 exact frames and gains 88,200 within fully labelled
constant contexts; source 16 loses 352,800 and gains 176,400 in that stratum.
The regression therefore includes stable annotated passages as well as changes
and incomplete contexts. Temporal smoothing alone is not established as a remedy.

The contributions expose specific dominant-related confusions. Source 02 cell 12
has a constant G-minor reference: the precursor peak ranker selects G minor,
whereas correlation selects D minor. The D-class contribution to the new-versus-
reference score difference is +0.313568; all remaining signed terms are retained,
including opposing terms. Source 16 cell 17 has a constant D-minor reference:
the precursor peak ranker selects relative F major, and correlation selects
A minor. A and E contribute +0.236137 and +0.117153 to A-minor versus D-minor
correlation, while F and D contribute -0.140387 and -0.057709. These are formula
contributions, not evidence that a particular sounding part owns those classes.

The fixed profile replacement trades existing mistakes for substantial new ones;
it does not merely repair relative-mode ambiguity. Stop changing profile weights
on these two recordings. A next inference proposal needs evidence that distinguishes
a sustained dominant from the tonic and separates genuine note-class activity
from spectral contributions. Folded, aggregated chroma cannot by itself identify
whether a class is a fundamental, overtone or accompaniment. Retain temporal
order and frequency provenance when defining that observation contract; do not
infer a new physical cause or select another classifier from this audit alone.
This remains within the existing local-key task's admission/evaluation criteria.

Checked stable Win64 controls, full audit and existing-output rejection pass with
zero leaks. The audit takes 3,497 ms, produces 3,463,508 bytes and reaches
66,293,760 bytes sampled private memory. All fit vectors, intersections, context
summaries and frame-weighted contributions are under
`build/local-key-reference/swd/profile-audit/`; final QA is in `build/qa-batch-12/`.
Report SHA256: `4189e48ad4c1047d7f2d534d6f789f4b411758ecdd7770fc6093a013d3a4a06d`.
No maintained provider, task completion or credit changes.

## Harmonic dictionary feasibility

A different representation was tested before another recorded key comparison:
fit nonnegative note spectra jointly, then combine their coefficients into pitch
classes. The [authors' NNLS Chroma description](https://github.com/c4dm/nnls-chroma/blob/master/README)
provides the method context. This owned Pascal experiment uses linear FFT
magnitudes and a fixed geometric harmonic dictionary, without their whitening,
log-frequency conversion or tuning; it is not a plugin port or parity claim.
No third-party implementation or new dependency is introduced.

The frozen policy uses mono 22050-Hz, 8192-sample periodic-Hann windows and MIDI
21..108 templates with up to sixteen harmonics, amplitude decay 0.7 and a 5-kHz
limit. Nonnegative coordinate descent retains all coefficients, residual energy
and convergence evidence. Availability means a converged observation, not note
or key admission. Synthetic controls vary phase and harmonic shape independently,
include gain/DC changes, simultaneous notes, missing fundamentals, silence and
an explicitly descriptive off-grid case. No recording or annotation is read.

Final numerical QA passes, but **31 of 72 feasibility cases fail**. Every failed
case converges under the unchanged tolerance and work limit. Pure sines at all
five tested pitches fail the declared 90% true-class concentration requirement;
some mismatched harmonic shapes also fail it. These cases can have the correct
largest note coefficient while assigning substantial weight to false classes.
The missing-fundamental MIDI-45 case instead selects MIDI 57, with only 66.766%
of coefficient mass on the true class. The two actual-note mixtures pass, retaining
98.324% and 98.975% mass on their two classes. Neither isolated success compensates
for the preservation failures.

Stop this fixed-shape representation before recorded execution. The fit can
explain spectral-shape mismatch by activating extra pitches; a small optimization
residual or correct top note does not establish a trustworthy pitch-class profile.
Do not sweep dictionary decay or relax the concentration gate. A later observation
contract must distinguish spectral-envelope variation from simultaneous-note
activity and preserve missing-fundamental ambiguity before another timed key run.
Tonic/temporal inference remains separately required even if that distinction passes.

The first implementation narrowed two `Max(0, Double-expression)` clamps to
Single through overload resolution. Compiler assembly exposed the issue. Explicit
Double branches and an exact nonbinary one-sweep regression fix it; the original
53-failure report is retained but superseded for scientific interpretation.
Only the affected harmonic suite was rerun, with unchanged policy and budgets.
This was a primary-owned implementation defect, distinct from scientific rejection.

Corrected checked stable Win64 QA takes 2,356 ms with 8,470,528 bytes sampled
private memory and a 220,106-byte report; numerical/replay controls and existing-
output preservation pass with zero leaks. Source, policy, original/corrected
reports and assembly evidence remain under `build/tonal-harmonic-feasibility/`
and `build/qa-batch-13/`. Corrected report SHA256:
`0f0beb6b1ae517142118b3956f7b10e4b23fe9a5ebeed10036b2ba4460c08807`.
No maintained ranker, source split, task completion or credit changes.

## Authored tonal-negative screen — 2026-09-23

One frozen [NS-3_context_01](TODO/NS-3_context_01.md) control screen asked whether
the existing positive top-two diatonic score gap also occurs after native
FFT/chroma analysis of signals with no single supported major/minor key. The
ignored `build/tonal-negative-screen/POLICY.md` fixed five 8-second, 22,050-Hz
mono recipes and the decision before execution: silence, deterministic white
noise, a click train, an equal 12-note chromatic cluster and a C-major triad.
The same default 4,096-frame window/1,024-frame hop, duration-weighted chroma
and unchanged `RankDiatonicFits` processed each complete signal. No reference
recording, style input, inference runtime or threshold sweep was used.

| Authored signal | Ranked candidates | First root/mode | First coverage | Top-two score gap |
| --- | ---: | --- | ---: | ---: |
| Silence | 0 | unknown | 0 | 0 |
| White noise | 24 | A#/major | .605843 | .000034384 |
| Click train | 24 | G/minor | .604785 | .000403354 |
| Chromatic cluster | 24 | G/major | .587352 | .000160963 |
| C-major triad | 24 | C/major | .997374 | .015870574 |

The triad passes the predeclared positive control, and the largest authored
negative gap (.000403354) is below its gap. The fixed decision is therefore
`recorded_evaluation_required`, not a chosen cutoff or automatic key admission.
All three non-tonal signals still produce 24 ranked alternatives: a top rank
cannot itself be interpreted as musical certainty. These constructed signals
do not verify false-admission behavior on independent recorded non-tonal or
ambiguous music. The Schubert annotation gaps are not such labels, and its
remaining compositions stay unopened for inference evaluation.

Each case declares 8,503,296 analysis-work units, below the frozen 20-million
limit; the checked stable FPC 3.2.2 Win64 run reports a 3,211,264-byte heap
size and zero unfreed blocks. The combined local output hash is
`a5361300c02a99f571534ce49903d7965abb7a8abb2a448b7bdc91191aa725f0`;
the source, frozen policy and output remain ignored under `build/`. No
maintained inference behavior, acceptance criterion or task credit changes.
Stop authored gap variants here. A later admission proposal needs independent
recorded positive and non-tonal/ambiguous references, temporal context and a
prospective threshold and coverage rule before any scored acceptance run.

## Percussion-only recording screen — 2026-09-23

After the authored screen, one separately described performed percussion
recording was selected before its bytes were opened: the [United States Navy
Band drum cadence on Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Drum_-_Cadence_A.ogg).
The page describes a drum cadence, identifies the U.S. public-domain basis and
lists the original 1,574,547-byte Ogg with SHA-1
`19d4fbf201e4990d9b2be9c454b209f36af86700`. The downloaded original
matches both; local SHA-256 is
`5083f07730c6ffb1cd2c3b5cc1a43714a0cfda04fe913935e83d1048466562e6`.
The description makes this a source-grounded percussion-only *candidate*;
it is not an expert no-key annotation for each local interval.

The verified external FFmpeg converter (2022-01-30 build) was used only to
prepare mono 22,050-Hz PCM16 WAV. Its 2,036,160 frames and SHA-256
`4f6a7dfb145719971aec28cc05c8fc1f53fac42e4bb6c48c38c235feac5d4a65`
were bound before scoring. The frozen Pascal screen reused the current
4,096-frame FFT/1,024-hop observation, 4-second owned cells and centered
8-second contexts. It preserved each cell's original source-frame interval,
24 ranked alternatives, coverage and score gap. The original Ogg, prepared
WAV, code, policy and full output remain ignored under
`build/tonal-recorded-negative/`.

All 24 cells returned 24 ranked alternatives. Their first ranks vary among
D minor, A minor and G-sharp major. The maximum top-two gap is **.009387836**
in cell 13, below the fixed authored C-major triad gap **.015870574**. The
predeclared decision is `broader_recorded_references_required`; no threshold
was selected. A percussion performance may contain pitched resonances, and
neither this description nor a single recording establishes universal
non-tonality. The result does not verify unknown admission or false-admission
rates in ambiguous music. No reserved Schubert composition was opened.

Stable FPC 3.2.2 Win64 reported 97,763,328 analysis-work units against the
150-million limit, 3,203 ms analysis against 30 seconds, a 20,648,094-byte
source/feature storage bound against 64 MiB and zero unfreed blocks. Full
local output SHA-256 is
`da26fcc7a3ed29545804952763df5fd16b35a314ec03c6694957a931b7f09f33`.
This closes no [local-key task](TODO/NS-3_context_01.md) criterion or credit.
Stop source-specific gap testing here; the next admission decision needs
multiple independently verified tonal and no-key/ambiguous intervals with a
prospective temporal and coverage rule.

## Loop-level reference qualification stop — 2026-09-23

The [Freesound Loop Dataset](https://zenodo.org/records/3967852) publishes
individual researcher annotations and source-specific licenses. Its
[annotation paper](https://jbls.fun/documents/ramires2020-ismir-freesound_loop_dataset.pdf)
distinguishes prominent tonal content, root and major/minor mode, and reports
multiple annotators for part of the set. These are *whole-loop judgments*, not
local-key/change labels. Annotators saw automatic pre-analysis suggestions;
the labels are reviewed human evidence but not algorithm-blind ground truth.

The 1,564,890-byte `annotations.zip` matches the publisher's MD5
`3920ee437802cf047a990b2968fa066c`; SHA-256 is
`e062f1f8e298730df92a879c302ce2c4f718039a3979442abc8aaca1258ac38e`.
A checked Pascal audit parsed 4,420 individual JSON files and found 1,472 IDs
with at least two annotations, matching the published multiple-annotation
count. Of these, 309 meet a strict unanimous `key=none`, `mode=none`,
percussion-only screen; 193 meet a strict unanimous named major/minor key with
a non-percussion role. These are *candidate counts*, before source-quality,
license or audio checks. The private audit output SHA-256 is
`ac05b461f1c5295b96a8a34d0d794be1ef1254b36353abbefb6b7caa11d9fd95`.

Before opening audio, a four-ID packet was frozen under ignored
`build/tonal-loop-reference/POLICY.md`: first two strict negative candidates
`101264` and `101895`, then first two strict tonal candidates `100902` (C
minor) and `111247` (D-sharp major). A Pascal ZIP64 index read only the
publisher's 128-KiB archive tail and 3,366,501-byte central directory;
four WAV entries and `metadata.json` were fetched by byte range rather than
downloading the 8.84-GB archive. A checked Pascal raw-deflate extractor
verified local names, central sizes and CRC-32. All five selected entries
passed; the four extracted WAVs total 3,062,490 bytes. Media, individual
annotations, policy, Pascal tools and exact hashes remain ignored under
`build/tonal-loop-reference/`.

The publisher metadata creates a source-quality conflict before any tonal
scoring: `111247` is unanimously labelled D-sharp major by the selected
researchers, but its uploader's filename declares `Key_C`. Its CC BY-NC 3.0
license also limits it to evaluation-only use, whereas `100902` is CC BY 3.0
and both negative candidates are CC0. Do not silently treat this selected
loop as a verified D-sharp-major positive or swap in another ID after seeing
the metadata. The frozen four-source screen **stopped before WAV analysis**;
there is no gap comparison, admission threshold, false-admission result or
local-key task credit. No held-out Schubert composition or user style mix was
opened.

The prior performed-percussion screen and this stopped qualification are two
nonclosing batches. Reassess at the task-flow checkpoint: independently
qualifying exact positive, no-key and ambiguous *intervals* is a reusable
reference deliverable separate from key inference. The new
[reference task](TODO/NS-3_context_03.md) owns that source/label packet before
another local-key scoring policy is frozen. Keep uploader descriptions,
researcher disagreements, automatic pre-analysis exposure, source licenses and
whole-loop versus timed-label scope explicit.

## Score-transferred ambiguity check — 2026-09-23

The [Winterreise dataset paper](https://research-portal.uu.nl/ws/files/98000909/3429743.pdf)
says annotator 2 (ann2) marked ambiguous score passages with a no-key label;
the publisher transferred score-level key regions to each performance's audio
clock using measure alignment and transposition. The annotators were aware of
earlier annotations, so their labels are distinct opinions but not independent
votes. The audio CSVs omit these no-key spans. A missing label at the start or
end of the recording has no equivalent interpretation.

A policy was frozen under ignored `build/context-reference-score/` before
running one Pascal-only mapping check on the already development-exposed HU33
D911-02 and D911-16. Original score ann2 CSVs were selectively extracted from
the checksum-bound dataset ZIP; current WAV, audio ann2 and prior preflight
JSON hashes were reverified. Every score row paired in order with its audio
row: five rows at a fixed **-2 semitone** transposition for D911-02, and three
at **-1 semitone** for D911-16, with identical modes. All substantial internal
score gaps have corresponding audio gaps, and no extra internal audio gap was
found. The existing exact decimal-to-frame policy binds the following original
22,050-Hz source intervals:

| Development source | Ann2 score gap | Audio gap (seconds) | Audio frames |
| --- | --- | --- | ---: |
| D911-02 HU33 | 14.832–24.833 | 25.62–42.22 | 564921–930951 |
| D911-02 HU33 | 29.832–33.666 | 54.46–61.22 | 1200843–1349901 |
| D911-02 HU33 | 39.832–46.333 | 75.04–86.72 | 1654632–1912176 |
| D911-16 HU33 | 10.999–24 | 25.2–53.52 | 555660–1180116 |

The bound preflight partition retains annotator 1 and 3's different keys
inside every ann2 gap. They sometimes agree with each other and sometimes
disagree. These four regions may be labelled
`ann2_score_transferred_ambiguous` for a development reference only, with
alignment uncertainty; they are **not** verified acoustic non-tonality,
consensus unknown or independent evaluation cases. Leading and trailing
uncovered audio remains unlabelled. No key estimator was executed.

Checked FPC 3.2.2 Win64 completed the two-source audit in 594 ms with zero
unfreed blocks. The ignored policy, Pascal source and result SHA-256 values
are `ce227456c3f1e7a02a4964afc8424585aa86cfc29e745a0bc17babb8b1ca931c`,
`22fbf0cb378975714e460e0a3d8bb794ee1fa56812718b2027fd79cf44065991`
and `db20b9c74842ae8eccf0512133fc853ccdb3257ca05e49ad11c582c2d93d31b`.
This advances the [reference task](TODO/NS-3_context_03.md) but closes no
complete criterion or credit: source-group-independent evaluation material,
reviewed acoustic no-key contrasts, a packet checker and frozen coverage
denominators are still required.

## Local-key reference group roles — 2026-09-23

Freeze the recording/composition boundary before opening more reference contents
or scoring another admission rule. Within the checksum-bound Winterreise archive,
all performances and derivative excerpts of D911-02 and D911-16 are
**development-exposed**. Reserve D911-05 and D911-19, including every
performance, score transfer and adjacent excerpt of either composition, for
**independent evaluation**. Do not inspect their audio or local-key annotation
contents while choosing a method or threshold. D911-01 is excluded because the
publisher added a repeat to its HU33 audio. Every other Winterreise composition
is quarantined pending a recorded role decision before its contents are used.
Different performances of one composition never cross roles.

The Freesound Loop Dataset annotation index was screened across the collection,
and the initial four WAVs were opened. Treat that collection as
**development-screened**, including candidate `102338`: its metadata describes
an original percussion capture by Brady Leduc, distinct from `101895` by
RytmenPinnen, but neither whole-loop description supplies timed acoustic
no-key truth. No FSLD loop is an untouched independent evaluation case. The
user's three full style mixes are preference examples, outside this local-key
reference packet. New sources need their own prospective group role before
labels or predictions are opened. This role map alone does not qualify the
reserved recordings or close the packet's group-isolation criterion; the Pascal
checker must enforce it against acquired source identities.

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
