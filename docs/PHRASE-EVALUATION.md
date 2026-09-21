# Recorded phrase evaluation

[Home](../README.md) · [Pitch contracts](PITCH.md) · [Milestones](MILESTONES.md) ·
[Work](WORK.md)

The core now supports [harmonic fitting along a declared changing phase](SOURCES.md#phase-harmonic-fitting).
Known glide/vibrato controls recover constant harmonic coefficients and render
through the native source; stationary-fit consumers retain their evidence.
This supplies a primitive for investigating the drift confound below. It does
not infer a trustworthy phase path, select register or alter any recorded phrase
score. Those admission steps remain [WAV-03-REGISTER](MILESTONES.md#wav-03-register)
and [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre); held-out recordings remain unused.

## Identity evidence reassessment — 2026-09-21

A native audit of the frozen predictive-phase cache reconciles all 5,994 scoring
centers across 96 flute and 87 violin events. Flute retains 1,706 correct, 105
octave-error, 7 other-wrong and 45 reference-rest admissions; violin retains
2,178 correct, no octave errors, 9 other-wrong and 23 reference-rest admissions.
Unknown coverage is accounted separately. Predictions and recorded scores do
not change; this is a diagnostic of why the proposed correction admitted nothing.

Among the 11 flute events containing octave-error centers, the lower-register
hypothesis has 42 available measurements out of 43 triples. Of those, 32 fail
the required odd-component prediction gain of at most -.01. Failure includes
weakly negative and zero gains, not only positive values. The upper hypothesis
has 18 available triples and 25 unavailable; available triples include 4 gain
failures and 11 full-error failures, which may overlap. Three events also lack
the required two triples. No event passes every guard. Fixed-frequency ablation
has the same availability and no passing event; it does not resolve the gap.

The native summary retains correct, octave-error, other-wrong and rest-admission
event cohorts for both recordings and both hypotheses/conditions, including the
empty violin octave cohort. Cohorts and windows overlap and cannot be summed as
independent trials. Event-level support cannot be assigned specifically to rest
centers within a mixed event. Correct-note cohorts also frequently fail these
guards; guard failure itself is not a pitch-identity classifier.

**Decision: stop the proposed amplitude-envelope coupling correction experiment
under its declared evidence gate.** The cache does not establish the independently
changing component that would justify that correction. It does not prove that
envelopes are useless. Missing upper measurements are not evidence for an octave
change, and a favorable upper measurement does not erase opposing lower evidence.
Do not weaken the guards, force register changes or alter presence boundaries.

The next bounded diagnostic belongs to [note identity](TODO/NS-3_notes_01.md):
first inspect retained fit caches, then, if needed, predeclare an unchanged-algorithm
measurement that records exact unavailability reasons, first/second-window AC
energies, second-harmonic power ratios, proposed frequency correction, target
energy and source coordinates for all events in both recordings. The current
cache retains only an availability Boolean. Fixed-frequency ablation shares the
same harmonic support floor, so it is not an independently available phase-free
test. Explaining missing measurements will not itself resolve a coherent stack
compatible with two registers; a new identity observation still needs independent
discrimination controls. [Presence](TODO/NS-3_notes_02.md) remains separately open.

Evidence is retained under `build/phrase-identity-reassessment/` and
`build/qa-batch-10/`. Checked stable Win64 audit execution takes 2,959 ms with
zero leaked blocks; the 32-row native summary takes 608 ms with zero leaks and
8,409,088 bytes sampled private memory. The original controls leaked one
35-byte argument temporary; normal termination repairs that path and its focused
rerun passes. The successful data report remains bound to its original producer;
no waveform/model rerun or changed score is inferred. A shell convenience
aggregation was superseded by the validated Pascal summary and is not analytical
evidence. SHA256 identities:

- Original report: `8b40cbb5c54dcbd70de56900fb1305a62b60f853935f36271a4b4a36c3eec8d4`.
- Native summary: `b7677d540b3c7e0b7f3a61c9529562b7a704eba29852ea65ebe9be972fc114e0`.
- Summary source: `e518f82ff7ca13042d723684f853aba69686a3cf57b1f0030945098e227d866f`.
- Summary policy: `11eb360aaec189220e6148996395b237e8612139f83f342dbf1a9bead69fd6f0`.

Both note tasks remain open without additional completion credit. The failed
scientific correction gate is distinct from the repaired control cleanup defect.

## Cached availability attribution — 2026-09-21

The retained fit-cache inventory finds no first/second-window harmonic coefficients
or energies for this predictive calculation. Earlier phase studies use different
windows and models and cannot be joined by event index. A native cache-only
classifier nevertheless tests what can be proved from retained frequencies and
paired predictive/fixed observations, following the original branch ordering.
Changed frequency proves that common phase-support checks were reached; unchanged
frequency may reflect an early exit or exactly zero correction. Unresolved cases
retain explicit alternatives rather than an invented failure cause.

All 96 flute and 87 violin events, each with lower/upper hypotheses, pass source,
baseline, original algorithm/policy and window-geometry checks. The native summary
records the following **identical** predictive/fixed stage counts:

| Recording / hypothesis | Retained triples | Available | Unresolved |
| --- | ---: | ---: | ---: |
| Flute / lower | 509 | 279 | 230 |
| Flute / upper | 509 | 30 | 479 |
| Violin / lower | 767 | 699 | 68 |
| Violin / upper | 769 | 474 | 295 |

No unavailable triple can be uniquely attributed to the corrected-frequency or
target-energy exit. This does not prove those exits never occurred. Both flute
hypotheses have four pairs too short for any triple and sixteen insufficient for
the two-triple proposal; both violin hypotheses have one of each. These categories
overlap and cannot be added. No pair is rejected by nominal Nyquist geometry.
Triples/windows overlap too; these are accounting units, not independent trials.

**Next: predeclare one trace-only replay of the unchanged predictive calculation**
on each existing development recording. Record the first actual exit branch and
only the intermediates reached before it; later values must be absent, not zero.
Require exact equality of the five original output fields against the frozen
cache on the same compiler/target before interpreting traces. Preserve all events,
source windows, four-harmonic fits, constants and branch order, with the existing
fit-work bound and 15-minute/512-MiB limit per recording. Check branch controls
first; stop on replay mismatch. No model execution, new recording exposure,
threshold tuning or register/presence correction is part of this diagnostic.
The rejected envelope proposal stays stopped. Explaining availability remains a
prerequisite to selecting a justified new identity observation, not its acceptance.

Checked stable Win64 controls and classification pass with zero leaks; the
classifier takes 2,906 ms with 40,058,880 bytes sampled private memory. Native
summary checks stage conservation, complete event/hypothesis coverage and geometry;
it takes 1,088 ms with 25,522,176 bytes sampled private memory and zero leaks.
Evidence and frozen packets are under `build/phrase-availability/` and
`build/qa-batch-11/`. Classifier report SHA256:
`0dcfd9fdc31890b6ca199111d91940cfc34d7ec28fd739cafc03f682ae75fa8d`;
stage summary SHA256:
`d6a60004cae4778f192e07b73634764f89e81c17124d67f0cdda855b189777e0`.
No task status, musical score, completion credit or failed-submission count changes.

<a id="predictive-phase"></a>
## Predictive harmonic phase comparison — 2026-09-21

The [fixed experiment allowance](MUSICAL-EVALUATION.md#fixed-next-experiment-budgets)
tested whether past harmonic phase predicts a future waveform window differently
under adjacent-octave hypotheses. Each candidate fits four harmonics plus DC in
the first two complete windows, estimates frequency correction from their second
harmonic phase, and predicts the third window without fitting that target.
The ablation removes frequency correction. At most sixteen event-local windows
are used, with width `max(320, ceil(4*16000/f)+1)` at 16 kHz.

The frozen proposal requires at least two triples per hypothesis. Every lower
triple must have available phase, at least .01 odd training power share and
normalized odd prediction gain <= -.01; every upper triple must have available
phase, gain >= .01 and normalized full error <= .5. Phase support requires the
declared second-harmonic power floor and correction within one semitone. Pure
even-harmonic ambiguity remains unresolved. Only supported +12-semitone proposals
are allowed; event boundaries, cents and all other baseline decisions stay fixed.
These are experimental guards, not calibrated confidence.

Final checked Win64 physical controls passed before recorded measurement:
fourteen low/ordinary/quiet/short/gap/mixture/weak- and missing-fundamental/vibrato/
octave-change cases, including the two new coherent/incoherent odd-component
controls, plus pure-even ambiguity. The two new cases distinguish the constructed
phenomenon. They do not establish its applicability to the recorded errors.

One paired measurement ran on each existing 30-second development excerpt. Both
conditions changed **zero** of 96 flute and 87 violin events. Independent final
auditing reproduced exact baseline intervals, all 2997 scoring centers per
recording, reference bindings and metrics in both conditions. Flute retains
1706 correct centers, 112 wrong pitches including 105 octave errors, and 45
false-rest admissions; violin retains 2178 correct, nine wrong pitches, zero
octave errors and 23 false-rest admissions. Precision remains **91.5727% /
98.5520%**. Flute fails the 98% development gate. All eleven flute events with
downward octave-error centers fail the combined correction guards.

Measured wall time was 2.962 / 3.705 seconds, sampled peak working memory
32,919,552 / 37,253,120 bytes, and fit work 87,955,200 / 132,759,000 for flute /
violin, within the preregistered bounds. Successful controls, scoring and audit
report no leaks. Initial scoring requests used the wrong baseline policy and
rejected before evaluation; those failure logs remain separate. Correcting the
policy argument did not rerun inference or alter the rule.

**Decision:** reject this predictive rule without tuning. Its constructed
separation does not resolve the actual errors; no maintained provider, default,
format, independent evaluation or completion credit changes. Reassess source
evidence for identity and presence together before declaring another hypothesis.
The private frozen policy, native study, measurements, process records and
scoring remain under `build/phrase-predictive-phase/`; final controls, hashes and
independent audit are retained under `build/qa-batch-04/`.

<a id="rate-view-strength"></a>
## Pooled pitch ranking with original frame strength — 2026-09-20

A controlled follow-up separates the preceding pooled observation's pitch ranking
from its maximum activation. For each frame, scale pooled per-note support so its
maximum equals the original single-view maximum within MIDI 33..86. Preserve
pooled relative ranking and tuning. Zero original strength yields zero support;
positive strength with no available pooled identity rejects. Equal maxima return
the pooled values exactly. This is an uncalibrated observation decomposition,
not a learned presence estimator or a new confidence claim.

Source RMS, local activity, pooled candidate-period floor, attack hints, graph
costs and admission rules remain fixed. Independent auditing reconstructs both
maxima from raw caches and verifies all 2997 restored maxima per recording.
Every pooled activity measurement remains byte-equivalent in JSON. Moreover,
the local unknown-state emission equals the original baseline at all 2997 frames
on each recording. Global event decisions can still change because note-state
evidence changes; preserving this local cost does not lock note presence.

| Recording / condition | Correct coverage | Admitted precision | Wrong pitches / octaves | False-rest admissions |
| --- | ---: | ---: | ---: | ---: |
| Flute / preferred | 82.4553% | 91.5727% | 112 / 105 | 45 |
| Flute / pooled mean | 81.9236% | 94.3764% | 78 / 71 | 23 |
| Flute / restored strength | **84.1469%** | **92.2629%** | 105 / 93 | 41 |
| Violin / preferred | 87.0852% | 98.5520% | 9 / 0 | 23 |
| Violin / pooled mean | 86.2455% | 98.4932% | 15 / 6 | 18 |
| Violin / restored strength | **88.0848%** | **98.3043%** | 12 / 0 | 26 |

Restored strength keeps **all 1706 previously correct flute centers**, corrects
eleven formerly wrong centers and gains 24 correct centers from unknown. Three
wrong centers become unknown, 98 remain wrong and seven formerly unknown centers
become wrong. The final correct count is 1741. Violin keeps 2176/2178 formerly
correct centers, loses one to wrong and one to unknown, and gains 27 correct
centers from unknown, ending at 2203. It retains all nine earlier wrong pitches
and admits two new wrong pitches from unknown. These paired accounts distinguish
recovery from suppression rather than crediting precision alone.

Flute onset/full-note F1 becomes .877005/.866310; violin becomes .960000/.857143.
Flute still fails the unchanged **98% precision** gate. Violin passes its four
development gates, but that does not establish the condition's broader controls
or independent admission. The earlier pooled condition's higher flute precision
depended substantially on its attenuated strength and reduced coverage.

**Decision:** keep the preferred baseline. Retain separate identity and strength
channels as an architectural direction; neither the original maximum nor
multi-view agreement supplies trustworthy presence or octave correctness.
This result does not justify another global strength/weight sweep: 93 flute octave
errors remain. Further work needs discriminating identity/presence
evidence while preserving the recovered coverage, real octave changes and the
existing low/short/quiet/gap/mixture requirements. Independent phrase evaluation
remains blocked until inference and those controls freeze.

The checked Win64 study passes a two-candidate ratio/tie oracle, exact neutrality,
zero/invalid evidence and a controlled note/gap/quiet/octave observation sequence.
That sequence supplies observations directly; it is not an actual transformed-
model waveform acceptance test. Both recorded predictions precede scoring.
Unchanged native scoring, independent raw-peak/activity checks and paired audits
against both original and pooled conditions pass. Neutral original/original
inputs replay all original decisions/measurements exactly, excluding declared
metadata and elapsed time. No new model measurement, held-out use, maintained
source/package, dependency, format or listening verdict changes.

Policy, native helper/controls/inference/audit, per-frame peaks and all terminal
logs remain under ignored `build/phrase-rate-strength/`. Final checked builds have
no warnings, and successful runs report no Pascal heap leaks. These checks do
not establish calibrated observations or production many-hour cost. This supports
[register](MILESTONES.md#wav-03-register) and
[boundaries](MILESTONES.md#wav-03-boundaries), without milestone completion credit.

<a id="playback-rate-observations"></a>
## Playback-rate observations and unchanged decoding — 2026-09-20

A fixed diagnostic compares the existing tiny-model cache with observations at
half and double playback speed, mapping pitch back by one octave. The owned
centered sinc resampler prepares the same 30-second source excerpt at 32000/8000
Hz; its samples feed the pinned 16-kHz TensorFlow reference consumer. Original
centers map exactly. The 1024-sample views span 32/128 ms of original time, versus
the original 64 ms. This changes observation duration and spectral bandwidth as
well as pitch; it is not a pure pitch-shift experiment or independent model evidence.

Both views retain 2997 raw activation vectors per recording. Mapping uses the
exact 60-bin octave displacement in the model's 20-cent coordinates; unavailable
edge bins are excluded. Eight transformed 220/440/659.255/880-Hz tone observations
pass the predeclared 30-cent / .5-activation controls (largest error 2.94 cents).
Source-center/duration and explicit zero-padding checks pass. All four recorded
measurements finish before reference classification; a complete transformed
flute cache replays exactly.

Raw ranking uses maximum support per MIDI note and a single arithmetic mean of
available aligned views. On reference-active centers, that mean increases correct
rankings from **1807 to 1898** for flute and **2266 to 2367** for violin. These are
raw rankings, not admitted note accuracy. Sixty of the preferred decoder's 105
flute octave-error centers are wrong in all three views; agreement also occurs at
25/45 flute and 10/23 violin false-rest admissions. Agreement therefore remains
insufficient pitch/presence confidence.

A separately declared follow-up feeds that one mean into the unchanged preferred
period-entry decoder. Original-window RMS and physical centers remain intact;
activity/floor calculations, attack hints, transition costs, tuning and admission
thresholds retain their original rules. Pooled metadata identifies derived
observations and all three parent hashes. There is no weighting or threshold sweep.

| Development result | Preferred: flute | Pooled: flute | Preferred: violin | Pooled: violin |
| --- | ---: | ---: | ---: | ---: |
| Correct active centers | 1706 | 1695 | 2178 | 2157 |
| Wrong pitch centers | 112 | 78 | 9 | 15 |
| Wrong octave centers | 105 | 71 | 0 | 6 |
| Reference-rest admissions | 45 | 23 | 23 | 18 |
| Unknown active centers | 251 | 296 | 314 | 329 |
| Correct coverage | 82.4553% | 81.9236% | 87.0852% | 86.2455% |
| Admitted precision | 91.5727% | **94.3764%** | 98.5520% | 98.4932% |
| Onset F1 | .863158 | .869565 | .960000 | .948571 |
| Full-note F1 | .852632 | .858696 | .857143 | .857143 |
| All four development gates | Fail | **Fail** | Pass | Pass |

Independent paired accounting shows why this is not general register recovery:
flute corrects nine previously wrong centers and makes 28 wrong centers unknown,
while making 50 correct centers unknown. Another 30 formerly unknown centers
become correct and three become wrong. Violin corrects no previously wrong center,
loses 66 correct centers to unknown, gains 45 correct centers from unknown and
admits seven new wrong centers. Thus the precision gain partly comes from reduced
coverage. Flute still fails the unchanged 98% precision requirement.

**Decision:** retain the preferred baseline. Rate views are candidate evidence
for further work, not an accepted replacement or a reason to raise milestone
completion. A future observation/admission rule must distinguish useful view
disagreements from common errors, preserve passing violin behavior and separate
register correction from rejection. Before adoption it still needs actual
low/short/quiet/gap/mixture controls and frozen independent phrase evaluation;
the tone controls here do not establish those requirements. Held-out material
remains unused, and there is no new library model/dependency or format.

Native diagnostics independently reconstruct reference labels and reconcile every
cohort to the earlier score. Both baseline replays preserve every original
decision/measurement field, excluding elapsed time and policy/file metadata.
The unchanged native scorer and paired auditor bind source/reference/inference
hashes. Final checked Win64 programs have no warnings or reported Pascal leaks.
Initial set-constant, shared-file and compiler-path errors, plus explicit counter
initialization, are retained in the study evidence; diagnostic output is unchanged
after initialization. Runtime allocation accounting is not proved by Pascal heap
checks. Each transformed 30-second batch takes 6.17–6.38 seconds for windows/model
evaluation, excluding graph setup/resampling; these are scoped observations,
not a many-hour cost or native-scalar performance claim.

Evidence is ignored under `build/phrase-rate-observations/`:

- Observation policy SHA256: `91b0ba63c950832afde77898497cbef40a7f91d7be21c394ba1c22c10871aace`.
- Decoder-comparison policy: `5146e4f91422ba3e6b74e8a8c4249d999ae0fcda63075e295127e3ffd611b8fb`.
- Replayed double-speed flute cache: `985becdd5428f62a4fc248452b5792088978f58af116efe8a6a44b2850ee8633`.

<a id="full-capacity-comparison"></a>
## Full-capacity pitch model with the unchanged decoder — 2026-09-20

A bounded reference comparison replaces tiny-model salience with official CREPE
full-model salience while retaining the preferred entry/activity/event decoder,
source windows, attack hints, admission thresholds and independent scoring.
The question is whether greater model capacity clears the existing recorded
register/presence failures without an additional policy change. It does not.

| Development result | Preferred tiny: flute | Full: flute | Preferred tiny: violin | Full: violin |
| --- | ---: | ---: | ---: | ---: |
| Correct active centers | 1706 | 1797 | 2178 | 2336 |
| Wrong pitch centers | 112 | 122 | 9 | 28 |
| Wrong octave centers (subset) | 105 | 109 | 0 | 8 |
| Reference-rest admissions | 45 | 64 | 23 | 52 |
| Unknown active centers | 251 | 150 | 314 | 137 |
| Correct coverage | 82.4553% | 86.8536% | 87.0852% | 93.4026% |
| Admitted precision | 91.5727% | **90.6203%** | 98.5520% | **96.6887%** |
| Onset F1 | 0.863158 | 0.864583 | 0.960000 | 0.960894 |
| Full-note F1 | 0.852632 | 0.854167 | 0.857143 | 0.927374 |
| All four development gates | Fail | **Fail** | Pass | **Fail** |

The same 2069 flute and 2501 violin reference-active centers are evaluated. Full
finds additional correct notes, and violin full-note matching improves from
75/86 estimates to 83/90. Those improvements do not compensate for the required
98% precision failure. Neither recording changes the acceptance thresholds.

Independent paired accounting finds **100 flute centers keep the same wrong
pitch**. Seven wrong centers become correct, while thirteen previously correct
centers become wrong and eleven become unknown. Another 108 previously unknown
centers become correct. For violin, eight centers retain the same wrong pitch;
four correct centers become wrong and forty become unknown, while 202 unknowns
become correct. Agreement between these two related models therefore cannot be
treated as independent evidence that a pitch is correct.

### Controls and scope

Eight phased known-frequency frames pass the existing 30-cent and minimum .5
activation bounds; positive gain/DC variants preserve salience within .0002.
The weak/missing-fundamental and genuine-octave diagnostic frames retain their
expected pitch identities. Quiet and silent diagnostic inputs remain below the
separate RMS gate; raw normalized activation is not presence confidence.

On the actual four-second six-note synthetic source, full still returns only
five events: the 30-ms 55-Hz note is absent. The 30-ms 440-Hz note, separated
440-Hz pair and quiet 220-Hz note remain present. Long 55-Hz onset is 0.413375 s;
no claim of short-low-note recovery is made. The unchanged six-note checker
fails explicitly. Recorded measurements remain a diagnostic capacity comparison,
not acceptance despite that control failure. The coherent-cycle hybrid's earlier
six-note recovery is a separate result and is not silently added here.

### Reference implementation and provenance

Weights come from the official [CREPE model revision](https://github.com/marl/crepe/tree/bb29b8d99a89924476d112d27ed470e4ac5617c0),
using the [pinned upstream topology](https://github.com/marl/crepe/blob/c9b71ce61491454125a0693f584f7244f29d9884/crepe/core.py).
The full MIT notice is retained. The source is read as a reference; Python is not
executed. A native Pascal importer uses the existing HDF5 1.10.6 C API, retains
its notice, and checks all 38 float32 tensor ranks/shapes/finite values. All
**88977312 weight bytes** exactly match independent native `h5dump` extraction
across thirteen shards. No tensor transposition or quantization is applied.

The existing Pascal TensorFlow 2.18.1 CPU C-API graph builder consumes those
hash-bound shards with its file-size bound increased for full weights. The full
channels are 1024/128/128/128/256/512, with 2048 dense inputs and 360 outputs.
The upstream pre-flatten permutation exchanges an extent-one axis and preserves
linear element order; dropout is inactive at inference. This is a reference
runtime experiment, not a full-model native arithmetic port or Keras-output
fidelity certification. Replaying the generalized study decoder on both original
tiny caches preserves every original decision/measurement field exactly,
including latent states, intervals, activity measurements and attack candidates.
Only elapsed time and the study's policy/baseline-file metadata are excluded.

Each recording uses the same 2997 centered windows, 1024 samples and 10-ms hop.
All saliences are finite and bounded 0..1. Measurement runs use four intra-op and
one inter-op threads, with oneDNN substitutions disabled. The two recordings run
sequentially and take **90.296 / 90.250 seconds** for their 30-second excerpts;
synthetic measurement takes 13.859 seconds. These are local elapsed observations
(other study checking also occurred), not controlled benchmarks or native-scalar
speed comparisons. Conservative convolution/dense work is 1410023424 multiply-adds
per frame including padded positions, or 4225840201728 per recorded batch.

Evidence is ignored under `build/crepe-full-comparison/`: declared policy,
pinned source/weights/notices, importer and independent extraction, graph adapter,
controls, raw caches, unchanged-decoder inference, scores, paired accounting,
baseline replay and logs. Final checked Win64 programs report no owned compiler
warnings or unfreed blocks. Initial function-pointer binding and replay filename
errors were corrected before the accepted checks; their failure logs are retained.

- HDF5 SHA256: `b6fd2758b03a8625a16fe86cd474ff0d8f30ad9a05e4bee2244e13e98664f860`.
- Imported manifest: `28924a4f35a71b37c550d4a6d836d37a70ec9c67798fb62dc92aa687c32a5bd3`.
- Declared policy: `99a2c159192be591bdb4b4c4d9e82e8c7130cae707bd1a085ed31b1a99a901e1`.

**Decision:** keep the preferred baseline. This result rejects the tested
drop-in replacement, not every possible calibrated use of a larger model.
Do not undertake a full native port on the strength of capacity alone. The next
[register](MILESTONES.md#wav-03-register)/[boundary](MILESTONES.md#wav-03-boundaries)
approach needs discriminating pitch-identity and presence evidence, preserving
short/quiet notes and genuine octave changes. Calibration or representation
changes require their own declared controls and paired evaluation. Held-out
recordings remain unused; no library dependency, production model, native format,
milestone completion or genre acceptance changes.

<a id="companion-ownership-checkpoint"></a>
## Companion-part coincidence does not explain register errors — 2026-09-20

The earlier residual-spectrum studies found coherent octave-related content in
the disputed flute notes. Before making separation or joint part ownership a
prerequisite for resolving those notes, a native diagnostic checks whether the
wrong admissions coincide with the annotated companion part in the same existing
development performance. Both directions are evaluated on all 2997 centers.

The diagnostic independently parses both note files, reproduces their reference
labels on the original floor-onset/ceil-ending 8-kHz grid, and verifies original
WAV/reference/score bindings. Every admitted center is retained, including correct
notes, wrong octaves, other wrong pitches and admissions during reference rests.
Contiguous error runs preserve their source centers and companion labels; they
do not infer physical note edges. Reference labels classify results only and
never enter the estimator. All cohort totals reconcile to the unchanged scores.

| Target / cohort | Centers | Companion active / at rest | Exact companion-note matches | Companion pitch-class matches |
| --- | ---: | ---: | ---: | ---: |
| Flute / correct | 1706 | 1587 / 119 | 182 | 209 |
| Flute / wrong octave | **105** | 92 / 13 | **0** | **0** |
| Flute / other wrong pitch | 7 | 6 / 1 | 0 | 0 |
| Flute / reference-rest admission | 45 | 36 / 9 | 3 | 3 |
| Violin / correct | 2178 | 1713 / 465 | 173 | 203 |
| Violin / wrong pitch | 9 | 5 / 4 | 0 | 0 |
| Violin / reference-rest admission | 23 | 15 / 8 | 0 | 3 |

Neither part has ambiguous reference overlaps on this grid. The exact companion
matches in the correct cohorts are also reference unisons. Of the 105 flute
octave errors, none matches even the companion pitch class; thirteen occur while
the companion reference is at rest. Simple simultaneous companion-note capture
therefore cannot account for this observed register failure.

This result does **not** establish acoustic independence, exclude all leakage or
unannotated sound, identify the physical cause of the extra partials, or prove
that a particular harmonic belongs to a particular source. Three matching flute
rest errors do not establish a leakage classifier. No waveform separation,
reference relabeling, note correction, model comparison or held-out evaluation
was performed. Preferred inference and all four recorded gates remain unchanged.

Keep [register](MILESTONES.md#wav-03-register) and
[boundaries](MILESTONES.md#wav-03-boundaries) independently actionable. Their next
observation model must resolve pitch identity and presence/rest ambiguity in the
target recording; they do not acquire a new dependency on general
[mixed-part admission](MILESTONES.md#wav-03-parts) from these errors. Preserve the
known articulation, weak-fundamental and short-note counterexamples when comparing
a richer representation. The existing tests do not justify another unconditional
periodicity/coherence cutoff or removal of companion-like notes.

Policy, native diagnostic, complete reports, error runs and terminal logs remain
ignored under `build/phrase-companion-ownership/`. Checked stable Win64 compilation
has no warnings and final runs report zero Pascal heap leaks. An initial reporting
assertion used incorrect score-field names and rejected before publication; those
names were corrected to the unchanged scorer contract. No production API, format,
dependency or package changes, and no additional completion credit, follow.

<a id="coherent-cycle-hybrid-checkpoint"></a>
## Coherent short-note support and actual-estimator hybrid — 2026-09-20

A shared fit across the claimed support span rejects the preceding two-tone
counterexample while retaining the short-note controls. After the existing cycle
selection, one DC/sine/cosine fit at the selected frequency covers every sample
between the first and last retained cycles. The original residual-power limit
0.01, AC RMS floor, frequency range, period consistency, center allowance and
frequency refinement remain unchanged. One additional fit over at most 1024
samples bounds the new work. Local and whole-span residuals remain separate.

The 220 + 331 Hz mixture now rejects: its best local residual is still 0.000517169,
but its whole-span residual is **0.999230511**. All sixteen phased 30-ms notes,
the exact prior gated-tail phase with gain/DC variants, quiet low sustain, real
gaps, silence, constant DC and all three negative controls pass. These controls
do not establish general harmonic or mixed-source observation accuracy.

### Actual-estimator short-note result

The synthetic comparison reuses source/model/policy-bound native salience. Before
adding observations, every original baseline state and interval replays exactly.
An available candidate within MIDI 33..86 and 25 cents supplies the previously
declared fixed 0.95 hypothesis support only when stronger than its same-note model
support. This is not calibrated probability. Model measurements remain unchanged
in their bound cache; the report retains old support/tuning and added observations.
The winning-pitch activity floor is recomputed; entry scale, attack hints, temporal
graph and final admission gates remain unchanged. No reference enters inference.

The actual hybrid recovers **all six authored notes**, including the previously
missing 30-ms 55-Hz note. An independent native check verifies note identities,
no extra notes, onset tolerance 50 ms, ending tolerance max(50 ms, 20% of reference
duration), and separate real gaps against the bound synthetic source.

| Note / authored interval (seconds) | Hybrid interval (seconds) |
| --- | --- |
| 55 Hz / 0.400..1.000 | 0.393375..1.013375 |
| 55 Hz / 1.300..1.330 | **1.293375..1.333375** |
| 440 Hz / 1.700..1.730 | 1.693375..1.733375 |
| 440 Hz / 2.100..2.300 | 2.093375..2.303375 |
| 440 Hz / 2.340..2.540 | 2.333375..2.543375 |
| Quiet 220 Hz / 3.000..3.500 | 3.003375..3.503375 |

There are 109 available/applied observations across 398 centers. Observation
processing takes 1.140 seconds on this four-second cached-input workload; this
excludes the earlier model pass and is not an end-to-end inference benchmark.

### Recorded transfer and decision

The same frozen condition runs against the two existing development recordings,
with exact original baseline replay first. Flute has only **2 available / 0 applied**
observations; violin has **6 available / 2 applied**. Whole-span near-sinusoidal
support is too sparse here to change the musical decision.

| Result | Flute | Violin |
| --- | ---: | ---: |
| Correct / wrong active centers | 1706 / 112 | 2178 / 9 |
| False admissions in reference rests | 45 | 23 |
| Coverage | 82.455292% | 87.085166% |
| Precision | **91.572732%** | **98.552036%** |
| Onset / full-note F1 | 0.863158 / 0.852632 | 0.960000 / 0.857143 |

These metrics equal the preferred period-entry baseline. Independent paired
accounting confirms **zero changed frame classifications** for both recordings.
Flute still fails the unchanged 98% precision gate; violin retains its four
development passes. Held-out material remains unused. Observation-only timings
are 22.312 / 17.047 seconds for the two 30-second excerpts, run concurrently;
they are not isolated performance comparisons or total model cost.

**No replacement is adopted.** The short-note feasibility result is useful, but
near-sinusoidal support does not resolve recorded presence/rest or register.
The next approach must represent coherent harmonic/changing sound and competing
pitch identities, retaining uncertainty and the now-passing low/quiet/gap/mixture
controls. Do not widen this fit's thresholds to force recorded coverage or treat
the fixed added support as calibrated confidence. This remains
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries), coordinated with
[register](MILESTONES.md#wav-03-register) and
[validation](MILESTONES.md#wav-validation); phrase freeze is still blocked.

Policy, native sources, full diagnostics, compact score inputs and terminal logs
are ignored under `build/cycle-coherent-support/`. The existing scorer's 2-MiB
input bound rejects the expanded reports; a native projection retains every
inference field except the observation array and binds the full original by hash.
The scorer and its limits are unchanged. A first invocation also rejects an
incorrect measurement-policy argument before inference; that log is retained.
Those initial rejected invocations report runtime exception allocations. Final
checked stable Win64 builds have no warnings, and all successful control, hybrid,
synthetic-check, projection, scoring and paired runs report zero Pascal heap leaks.

<a id="refined-cycle-support-checkpoint"></a>
## Refined cycle support: mixture rejection still fails — 2026-09-20

Review of the existing `build/cycle-frequency-refinement/` policy, Pascal sources
and terminal logs establishes the next result after the cycle-local experiment
below. This is a study result, not an adopted provider or a new execution during
the milestone reassessment.

The declared revision fits frequency inside a bounded neighborhood of each
crossing-derived period, then requires enough observed span for the refined
period. It retains the previous residual, consistency and activity thresholds.
Its numerical search bracket is not a statistical confidence interval.

All sixteen phased short-note cases pass, as do the exact earlier failing phase
before/after gain and DC changes, quiet low sustain, two real-gap cases, silence
and constant DC. These controls construct support for the event decoder from
the new observation; they do not demonstrate a hybrid with the actual estimator.

The first negative control fails: equal-amplitude **220 + 331 Hz** tones produce
an available **280.009151197 Hz** estimate. The reported best-cycle relative
residual power is **0.000517169**, with eleven retained cycles and a combined
window-relative span of **116.121672..1016.359245** samples. A separate diagnostic
confirms this result and rejects the square-wave and changing-frequency cases.
The main control run stopped at the mixture failure.

The implementation returns the best individual cycle's fit with the combined
support span; it does not establish one coherent sinusoid across that span.
This identifies a missing support check, not proof that adding it would solve
general musical admission. The next observation design must account for coherent
support, unexplained mixture energy and explicit ambiguity while retaining the
short/quiet/gated controls. A small local residual cannot establish pitch identity.

The declared policy therefore stops actual cached-model hybrid and recorded
comparison. Neither is evidenced by these logs. Preferred inference, recorded
scores and held-out material remain unchanged. The work stays under
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries), coordinated with
[register](MILESTONES.md#wav-03-register) and
[validation](MILESTONES.md#wav-validation); it earns no additional goal credit.

<a id="short-note-admission-checkpoint"></a>
## Native low-short-note admission and cycle-support experiment — 2026-09-20

The missing 30-ms 55-Hz note is lost before final event admission. A source-bound
trace replays every original native estimator/period-entry state and interval
exactly. Around the authored note, MIDI 33 is the winning raw candidate; support
at centers 20934, 21094 and 21254 is **0.203642, 0.345235 and 0.175273**. Period-local
RMS is approximately 0.118, 0.122 and 0.103, and entry scale is 1. The activity floor
therefore does not suppress these centers. The latent path stays unknown throughout;
short/support/tuning rejection counts are all zero. Lowering the final duration
minimum would not restore an event that was never selected.

An independent waveform observation was then implemented as an ignored experiment.
Same-direction crossings propose a period; DC/sine/cosine fitting checks waveform
agreement. The predeclared scope is near-sinusoidal short passages, with explicit
50..1250-Hz bounds, residual-power ratio ≤0.01, AC RMS >1e-5, period agreement within
5% and a half-period center-coverage allowance. A proposed hybrid would add fixed
0.95 hypothesis support only when an available, in-tune candidate is stronger than
existing model support. That value is not calibrated confidence. **The hybrid was
not run or adopted**, because the required observation controls fail.

The initial whole-window crossing condition fails its first 30-ms 55-Hz control:
gate edges enter the crossing sequence and the period-consistency test rejects it.
A separately declared revision fits individual observed cycles before comparing
their periods, without changing thresholds. It retains the lowest-residual valid
cycle and explicit support span, with bounded work over the two polarity chains.
This revision recovers all **16 short-note controls** (55/110/220/880 Hz at four
phases), then fails the next identity check.

At phase 0.37, the candidate at source center 4614 (0.288375 seconds) is
**56.764069 Hz**, MIDI 34 at −45.344 cents, although the 55-Hz burst ended at
0.280 seconds. Residual power is only **0.003157324**. One retained crossing interval
ends at the gate edge, and the half-period allowance admits the later center.
Repeating that exact case at the original gain/DC and at half gain plus DC yields
the same frequency to within 5e-8 Hz. Thus the failure is not gain/DC sensitivity;
the cycle/edge interpretation can give a low residual with the wrong frequency.
The diagnostic still emits one final event, but that does not clear the failed
available-candidate identity requirement. Its off-grid tuning would also prevent
the proposed hybrid from admitting this particular candidate.

Execution stops at that failure. Quiet/gap/silence/non-sinusoidal controls later in
the declared sequence, the actual cached-model hybrid and recorded comparison
remain **unexecuted**. The initial and revised failures are preserved. No threshold
sweep, held-out input, estimator rerun or change to the preferred path occurs.

**Next decision:** separate a complete periodic cycle from a gate-truncated
crossing interval, with frequency refinement/uncertainty and explicit active-region
support before treating fit residual as admission evidence. Keep the new phased
and gate-edge counterexamples. Existing multi-harmonic fit contracts are unchanged;
they are not weakened to accommodate the short note. Broader presence/rest and
register work must still clear the original phrase gates.

Checked stable Win64 trace/control/diagnostic builds have no warnings (the small
failure diagnostic has one unused-constant compiler note). Runs report no Pascal
heap leaks. Trace replay succeeds; the two control conditions fail as described.
Policy, initial/revised native sources, controls and logs remain ignored under
`build/short-note-admission/`. No maintained library, saved format, dependency,
package, listening acceptance or completion-credit change.

<a id="note-context-checkpoint"></a>
## Waveform-qualified event context and real short-note check — 2026-09-20

A native boundary condition now uses source-timed, pitch-qualified waveform
attacks instead of unconditionally splitting at learned onset peaks. It materially
reduces fragmentation, but **does not pass recorded admission**. The existing
period-aware entry condition remains preferred. This is an implemented comparison
of boundary evidence, not the completed joint observation model or production API.

The predeclared condition reuses audited note-head observations, unchanged winning
pitch labels, 0.3 admission, the broad source RMS floor and three-center minimum.
Existing native envelope valleys and pitch-boundary qualification supply attack
anchors at the original scoring grid. Label changes/gaps begin events; an interior
anchor can begin a same-pitch repetition. Learned peaks cannot independently create
a second event around that attack, and weak onset activations do not veto notes.
This deliberately changes only event partitioning; note-presence calibration and
register remain separate requirements.

Constructed-observation controls pass delayed onset confirmation without a split,
distinct same-note anchors, a quiet three-center note, a four-center gap and silence.
Original direct-decoder events replay exactly from both unchanged input caches.
The native and earlier boundary-query implementations agree on the waveform
qualification results. Flute/violin supply 28/50 marked anchors and produce 114/95
raw events, of which 112/94 survive the existing scoring edge policy.

| Development measure | Flute: direct heads → contextual anchors | Violin: direct heads → contextual anchors |
| --- | ---: | ---: |
| Correct active centers | 1786 → 1790 | 2420 → 2409 |
| Wrong-pitch centers | 195 → 193 | 52 → 57 |
| Octave-error centers, included above | 141 → 145 | 0 → 0 |
| Notes admitted in reference rests | 194 → 216 | 167 → 178 |
| Coverage; gate ≥80% | 86.32% → **86.52%** | 96.76% → **96.32%** |
| Precision; gate ≥98% | 82.11% → **81.40%** | 91.70% → **91.11%** |
| Onset F1; gate ≥0.80 | 0.6288 → **0.7923** | 0.7946 → **0.9399** |
| Full-note F1; gate ≥0.70 | 0.5758 → **0.7826** | 0.7500 → **0.8962** |
| Scored estimated notes | 169 → 112 | 135 → 94 |

Independent paired accounting against the direct-head condition finds six gained
correct centers and two lost for flute; violin gains two and loses 13. Changed
partitioning changes which short segments survive, explaining frame-admission
differences despite unchanged raw labels. Against preferred period-entry inference,
the condition gains 133/252 correct centers but loses 49/21, and false-rest counts
are much worse than the preferred 45/23. Violin's full-note F1 exceeds the preferred
0.8571, but its precision fails where the preferred condition passes. Do not trade
away a required gate to adopt the event-count improvement.

### Actual native estimator on the short-note waveform

The earlier period-floor controls construct pitch support from known waveform
activity. They verify the floor/decoder contract, **not estimator recovery of a
short note**. The new check therefore runs the actual pinned native CREPE model
on all 398 scoring centers of the same four-second PCM16 source, then applies
the unchanged period-entry observation/decoder contract. No authored note labels
or expected-frequency hints enter inference. Native source RMS is independently
recomputed against every cached input; model and source bindings remain explicit.

| Authored signal | Actual native estimator + period-entry result |
| --- | --- |
| 55 Hz, 0.400..1.000 seconds | MIDI 33, 0.413375..0.993375 |
| 55 Hz, 1.300..1.330 seconds | **Missing** |
| 440 Hz, 1.700..1.730 seconds | MIDI 69, 1.693375..1.733375 |
| 440 Hz, 2.100..2.300 and 2.340..2.540 seconds | Two MIDI-69 events, 2.093375..2.303375 and 2.333375..2.543375; a 30-ms inferred gap remains. |
| Quiet 220 Hz, 3.000..3.500 seconds | MIDI 57, 3.003375..3.503375 |

The actual native path recovers the short 440-Hz note and quiet sustain, but is
not a demonstrated general short-note fallback: the 30-ms 55-Hz case still fails.
That is an end-to-end failure; its split between model support, temporal choice
and event admission has not yet been isolated. The scalar model pass takes
66.563 seconds for four seconds of audio, consistent with the earlier cost issue.
No fusion with the separate-head model is performed or claimed.

**Next:** retain the useful source-timed event identity and address presence/rest
and register evidence jointly, before another recorded candidate. Isolate the
native low-short-note failure at raw support, latent path and final admission;
an assumed fallback is insufficient. Any combined observation contract must
preserve the existing short/quiet/gap/repetition cases and all recorded gates.
Further independent onset-peak cutting or minimum-length changes do not address
the demonstrated limitations. Both models remain experimental and held-out
recordings stay unused.

Policy, native comparison unit/operator, synthetic estimator measurement/inference,
reports and terminal logs remain ignored under `build/note-context/`. Checked stable
Win64 builds/runs, focused controls, independent scoring and four paired comparisons
finish without compiler warnings or reported Pascal heap leaks. The prior raw-head
audit is reused; this does not claim a new full independent audit of the candidate
decoder. No maintained library, saved format, dependency, package or listening
acceptance changes. Completion remains 55.5 weighted points / 22 open outcomes.

<a id="note-head-support-diagnosis"></a>
## Head support and onset identity diagnosis — 2026-09-20

The source-bound diagnosis of the preceding comparison separates weak short-note
observations from event fragmentation. It reuses audited caches; no network,
inference policy, gate, preferred score or held-out input changes.

Both authored 30-ms notes have expected-pitch support below the fixed 0.3 admission
threshold before minimum-length filtering. Their raw retained note peaks remain
below that threshold even over a fixed 100-ms margin on either side:

| Authored case | Raw note peak, exact / expanded region | Interpolated onset peak, expanded region | Admitted winning centers, expanded region |
| --- | ---: | ---: | ---: |
| 30 ms at 55 Hz | 0.108175 / 0.135161 | 0.219980 | 0 |
| 30 ms at 440 Hz | 0.179983 / 0.189116 | 0.303355 | 0 |
| Quiet sustained 220 Hz | 0.716450 / 0.716450 | 0.109118 | 24 |

The short-note misses are therefore not caused solely by the three-center length
filter or interpolation. This does not prove there is no usable information in
other observations; it rules out fixing this condition by changing only its event
minimum. The quiet-note result also argues against making a strong onset peak a
mandatory admission condition. These activations are not calibrated probabilities.

Every same-note onset cut is classified relative to source-bound annotations,
using the existing 50-ms onset tolerance and nearest same-pitch reference onset:

| Cut classification | Flute | Violin |
| --- | ---: | ---: |
| Near onset whose preceding annotated note has the same pitch | 6 | 13 |
| Near changed-pitch onset, including the first note | 49 | 66 |
| Outside onset tolerance, inside one correct-pitch reference note | 19 | 4 |
| Outside onset tolerance, in a reference rest | 11 | 0 |
| Other/overlapping or wrong-pitch activity | 6 | 0 |
| **Total, reconciled with the independent decoder audit** | **91** | **83** |

The dominant cut class is near a changed-pitch attack. Thus an onset peak can
confirm an event already begun by the frame-label change; treating every peak as
another event creates a duplication mechanism. The table does not claim every
near-onset cut survives minimum-length filtering or that every interior cut is
perceptually false. Per-cut source time, activation and unbroken-label-run age
remain in the reports for the next observation design.

Reference-note coverage keeps raw retained peaks separate from interpolated peaks
and actual decoder cuts. A peak must have the expected pitch, reach 0.5 and lie
within 50 ms of the annotated onset; it need not win the frame's pitch selection.

| Reference cohort | Notes with onset in excerpt | Raw peak available | Interpolated peak available | Direct cut available |
| --- | ---: | ---: | ---: | ---: |
| Flute, preceding same pitch | 14 | 12 | 11 | 6 |
| Flute, changed pitch / first note | 82 | 75 | 75 | 47 |
| Violin, preceding same pitch | 13 | 13 | 13 | 13 |
| Violin, changed pitch / first note | 78 | 77 | 77 | 65 |

These cohorts include all annotated onsets inside the excerpt, including notes
later excluded by the scoring edge policy; their denominators differ from the
official 95/89 scored reference notes. More than one cut can fall near one onset,
so cut counts and covered-reference counts are also distinct. One flute repeated
onset has a raw peak but no qualifying interpolated peak. Peak coverage alone is
neither an onset F1 score nor a complete event result.

**Next implementation:** declare an event-context observation contract in which
pitch presence can start an attack, an onset can confirm that attack, and later
onset evidence can support a repeated note without unconditionally cutting an
existing event. Keep onset evidence optional for weak attacks. Preserve an
explicit path for short/quiet notes whose learned head support is inadequate;
do not assume temporal smoothing creates missing observations. The comparison
must preserve the short-note, true-gap and repeated-note controls, expose unknowns,
and pass the unchanged paired recorded gates before replacing the preferred path.
The register and short-note evidence gaps still prevent model adoption/porting.

Checked stable Win64 compilation and diagnostic runs finish without warnings or
reported Pascal leaks. The first reference-coverage loop used interpolated values
where raw peaks were requested; the corrected run reports both separately and
preserves the initial source/results. This changes no inference. Policy, correction
record, native source, synthetic/per-cut/per-reference reports and logs remain
ignored under `build/note-head-diagnosis/`. Existing audit identities bind the
cached measurements and inferred events; reference identities bind the diagnostic
annotations. No new saved format, production dependency or completion credit.

<a id="note-head-recorded-checkpoint"></a>
## Separate note/onset recorded comparison — 2026-09-20

**The declared direct-decoding policy is rejected as a replacement.** The pinned
[reference model](PROVENANCE.md#note-head-reference-model) recovers more correctly
pitched centers on both existing development excerpts, but admits substantially
more notes in rests and fragments note events. Neither recording passes all four
unchanged gates. This does not establish that every use of the model must fail;
it establishes that mechanical execution and more coverage do not justify adopting
this representation/decoder combination. The preferred period-aware entry path
remains unchanged.

The policy was declared before the recorded runs. Existing native sinc conversion
maps each exact 30-second mono 16-kHz excerpt to 22050 Hz. Model input windows have
43844 samples, a 36164-sample hop and 3840 samples of leading zero padding. Output
indices 15..156 retain explicit source coordinates:

`window × 36164 + output_index × 256 − 3840`.

Interior retained rows advance by 256 input samples; window joins advance by 68.
These are the declared input-grid coordinates, not upstream's empirical timing
correction or proof of musical onset accuracy. Note/onset values interpolate onto
the original 2997 scoring centers. Each recording uses 19 model windows and 2598
retained rows. Contour outputs are retained but do not supply tuning here.

The native comparison decoder selects the maximum note activation in MIDI 33..86,
with ascending-note ties, frame threshold 0.3 and the existing source AC RMS floor
of 1e-5. Consecutive labels form runs; a same-note local onset peak at least 0.5
splits a run. Runs shorter than three centers are discarded. There is no gap
filling, source-specific threshold or reference-derived timing shift. This is a
declared monophonic comparison, not parity with upstream postprocessing. Zero
cents is explicitly unmeasured; it is not a tuning-accuracy claim.

| Development measure | Flute: preferred → comparison | Violin: preferred → comparison |
| --- | ---: | ---: |
| Correctly pitched active centers | 1706 → 1786 | 2178 → 2420 |
| Wrong-pitch centers | 112 → 195 | 9 → 52 |
| Octave-error centers, included above | 105 → 141 | 0 → 0 |
| Notes admitted in reference rests | 45 → 194 | 23 → 167 |
| Unknown active centers | 251 → 88 | 314 → 29 |
| Coverage; gate ≥80% | 82.46% → **86.32%** | 87.09% → **96.76%** |
| Precision; gate ≥98% | 91.57% → **82.11%** | 98.55% → **91.70%** |
| Onset F1; gate ≥0.80 | 0.8632 → **0.6288** | 0.9600 → **0.7946** |
| Full-note F1; gate ≥0.70 | 0.8526 → **0.5758** | 0.8571 → **0.7500** |
| Scored estimated notes | 95 → 169 | 86 → 135 |

The existing paired scorer independently reconciles every center. Flute gains
127 correct centers (7 previously wrong, 120 unknown) and loses 47 previously
correct centers (24 wrong, 23 unknown). Violin gains 261 (2 wrong, 259 unknown)
and loses 19 (10 wrong, 9 unknown). Thus the coverage gain includes real recoveries
and regressions, rather than uniformly better evidence.

Independent native auditing checks all raw-head values and retained rows, model/
source/policy/code bindings, window extents, and the nonuniform source coordinates.
A linear coordinate walk and different interpolation expression reproduce every
note/onset value to at most 2.23e-16. A one-pass sum/squared-sum RMS calculation
reproduces the source-window floor inputs to at most 2.66e-15 across synthetic and
recorded cases. Separately constructed label/onset cuts reconstruct every event
without calling the comparison decoder. This audits execution of the declared
policy; it is not native-model numerical fidelity or calibration of activations.

Flute has 169 label changes and 91 same-note onset cuts; violin has 114 and 83.
Respectively 36/31 sub-three-center segments are discarded, leaving 171/136 raw
events and 169/135 scored events after the existing edge policy. These counts
locate fragmentation mechanisms; they do not identify every cut as false. The
synthetic audit also reconciles all five events and retains the
[short-note and quiet-note failures](#note-head-preliminary-controls). Passing
constructed-head controls does not clear those end-to-end failures.

Reference-runtime model calls take 2.344/1.937 seconds across the 19 windows;
native conversion takes 11.406/11.375 seconds. The two processes ran concurrently,
so these are scoped observations, not a serial benchmark or native-model speed
claim. Warm-up is included in model-call totals; model loading is separate.

**Next decision:** evaluate separate note/onset evidence within attack,
continuation and release states, rather than adopting these independent frame
thresholds and unconditional same-note peak cuts. First distinguish head support
from decoder suppression on the short-note controls, and inspect onset evidence
at true repeated notes versus within an existing attack/sustain. Declare the next
observation contract before scoring another candidate. Preserve explicit unknowns,
the preferred baseline, quiet/low/short-note controls and the unused held-out split.
Do not launch a production port or reinterpret activations as calibrated confidence
on this result. [Register](MILESTONES.md#wav-03-register),
[boundaries](MILESTONES.md#wav-03-boundaries) and applicable
[validation](MILESTONES.md#wav-validation) still block phrase acceptance.

The checked stable Win64 study/audit builds have no compiler warnings; native
controls, measurement, audit, existing score and paired accounting runs finish
with zero reported Pascal heap leaks. Runtime-owned allocations are outside that
claim. Policies, native study code, converted audio, raw heads, source-bound
reports and logs remain ignored under `build/note-head-recordings/`. No maintained
library inference, saved format, dependency source, held-out evaluation, listening
verdict or package changes. Engineering credit stays at 55.5 weighted points.

<a id="note-head-feasibility-checkpoint"></a>
## Separate note and onset observations — 2026-09-20

An isolated Pascal probe can execute the official
[Basic Pitch SavedModel](https://github.com/spotify/basic-pitch/tree/fa5997af0a8210982619003269994a1be25eddf3)
through the already verified TensorFlow 2.18.1 CPU C API. The model supplies
separate note, onset and pitch-contour heads, matching the observation gap exposed
by the boundary audit. **This establishes mechanical feasibility only.** It does
not establish recorded accuracy, native Pascal model execution or an adopted
dependency. Upstream assets/source remain ignored with their complete
[license and attribution](PROVENANCE.md#note-head-reference-model).

The probe pins graph/variable hashes and discovers tensor identities from the
loaded serving signature instead of guessing output order. The input is
`serving_default_input_2:0`, float32 `[1,43844,1]` at 22050 Hz. Signature outputs
are `StatefulPartitionedCall:0/1/2` for contour/note/onset respectively. Each has
172 time frames; contour has 264 bins and note/onset have 88 bins.

A policy declared before execution limits this first probe to silence, a steady
440-Hz sine and two interrupted 440-Hz notes, one window and one repeat each.
Every output value is finite and in 0..1, output shapes match, and all three heads
repeat exactly within the same process. Observed peaks are:

| Input | Peak note activation / bin | Peak onset activation / bin |
| --- | --- | --- |
| Silence | 0.160707 / 0 | 0.174347 / 83 |
| Steady 440-Hz sine | 0.763330 / 48 | 0.539600 / 48 |
| Interrupted 440-Hz sine | 0.757639 / 48 | 0.808941 / 48 |

Note bin 48 corresponds to MIDI 69 under the upstream MIDI-21 offset. Nonzero
silence outputs remain visible; neither peak activation nor this synthetic
agreement establishes calibrated confidence. The first inference takes 391 ms;
subsequent calls take 16..32 ms for a roughly two-second input on this machine.
Those six calls are a small reference-runtime measurement, not a sustained
throughput benchmark or a speed claim for a future Pascal implementation.

**Next:** declare and verify the recorded comparison's preprocessing, output
coordinates and event decoding before using the existing development pair. The
pinned upstream inference uses overlapping windows and trims output edges;
its note timing includes an additional window-dependent correction. Do not equate
concatenated frame index with an exact source timestamp without checking this
mapping. Its default minimum note length, about 127.7 ms, also does not meet the
existing short-note requirement and must not silently replace that scope.
Preserve the existing independent coverage/precision/onset/full-note gates and
held-out split. Compare recorded musical results before investing in a production
port; any chosen native implementation still needs numerical fidelity, cost,
provenance and downstream-use evidence under [WAV-VALIDATION](MILESTONES.md#wav-validation).

Checked stable Win64 compilation finishes without warnings after explicit
initialization of the retained output arrays. The run reports zero Pascal heap
leaks; reference-runtime allocations are outside that accounting. Complete policy,
Pascal probe, pinned upstream files, model, raw tensors, source-bound report and
terminal logs remain ignored under `build/note-head-feasibility/`. No recorded or
held-out audio, production inference, library dependency or package changes here.

<a id="note-head-preliminary-controls"></a>
### Preliminary decoding and waveform controls — 2026-09-20

The unfinished follow-on study under ignored `build/note-head-recordings/` has
native coordinate/interpolation and decoder controls passing for short/quiet
notes, repeated onsets, real gaps and silence. These controls provide constructed
head values; they do not establish that the acoustic model produces those values.

The saved four-second synthetic waveform run detects five intervals but misses
both authored 30-ms notes (55 Hz and 440 Hz). It also splits and truncates the
sustained 55-Hz note and admits the quiet 220-Hz note late. Thus keeping a 30-ms
decoder minimum does not by itself meet the end-to-end short-note requirement.
These observations were initially recorded by inspecting existing artifacts.
The subsequent [recorded comparison](#note-head-recorded-checkpoint) now completes
independent cache/event reconstruction for this synthetic case and both development
recordings. It preserves these failures; no preferred inference or milestone
credit changes. Whether each missed short note lacks usable head support or is
suppressed during decoding still needs to be distinguished.

<a id="harmonic-presence-control-checkpoint"></a>
## Stationary harmonic presence fails a short-note control — 2026-09-20

A predeclared observation comparison reuses the native six-harmonic fitter at
the raw-support winning candidate and tuning. It measures a centered window of
`max(160, ceil(4*16000/frequency)+1)` samples, preserving the fitter's four-cycle
contract. The proposed scalar is the square root of the fitted AC power fraction.
It multiplies the existing note-phase observations and enters the complementary
unknown observation; raw pitch evidence, graph costs, activity floor and event
admission remain unchanged. Missing source context is unavailable with neutral
scale, rather than padded silence. No reference label selects the candidate.

The 220-Hz gap, near-floor steady 55-Hz tone and 55-Hz gap controls pass. The
**30-ms, 55-Hz note fails: the baseline retains one event, while this condition
retains none**. The 1165-sample fit window spans roughly 73 ms and the stationary
whole-window model attenuates a valid shorter event. Neutral inputs replay the
original decoder in each executed case. This is a mismatch between that
observation model and the short-note requirement, not evidence of a defect in
the core waveform fitter.

Execution stops at that failure, before the remaining planned waveform controls
or any recorded comparison. The policy is rejected without a shorter fit window,
new cutoff or recording-specific exception. Do not use stationary fit quality
as a universal note-presence score or relax the core cycle contract to make this
experiment pass. Separate note/onset observations are the next approach above.

The checked stable Win64 build has no warnings, and the failed control run exits
1 with zero reported Pascal leaks. Policy, native observation/decoder/control
sources and the failure log are ignored under `build/phrase-harmonic-presence/`.
The core fitter, preferred period-entry inference, recorded scores and held-out
material remain unchanged.

<a id="boundary-emission-checkpoint"></a>
## Residual boundary emission audit — 2026-09-20

The preferred period-aware entry path now has a source-bound comparison of local
note and unknown emissions at every admitted scored center. This distinguishes
an observation that already favors a false note from a local preference retained
by temporal inference. It changes no inference, timing, threshold or score.

The declared audit reuses original raw salience, saved local activity and qualified
attack hints. It reconstructs the decoder's selected-state emission, octave edge
allowance, attack activity scaling and sustain-at-attack penalty, and compares it
with the unknown emission. Graph transition costs and future evidence are not
part of this local comparison. These values are uncalibrated observation scores,
not probabilities of musical correctness or a posterior confidence estimate.

| Recording / admitted-center cohort | Centers | Locally favors unknown | Locally favors note or ties |
| --- | ---: | ---: | ---: |
| Flute false rest | 45 | 9 | 36 |
| Flute correct note | 1706 | 13 | 1693 |
| Flute wrong pitch | 112 | 4 | 108 |
| Violin false rest | 23 | 11 | 12 |
| Violin correct note | 2178 | 39 | 2139 |
| Violin wrong pitch | 9 | 6 | 3 |

All nine flute false-rest centers that locally prefer unknown are attack1 states.
All 20 false-rest sustain centers locally favor their note. Violin's 11 unknown-
favored false-rest centers comprise seven attack1 and four sustain states. The
report retains phase, neighboring states, raw support, activity, both emissions
and the signed local log-cost difference for each center. Reference labels and
nearest-boundary distances classify observations only; they never supply an
inference feature or a replacement boundary.

**Decision:** relaxing a forced release transition does not directly address the
dominant flute residual: its false-rest sustain observations already favor a
note, and the unknown-favored errors occur at entry. Conversely, discarding every
locally disfavored note would also discard correctly admitted centers. These
counts are not a simulation of re-decoding after such a change; global results
could differ. They do not justify blanket edge trimming or another activity-floor
threshold. All admitted centers in this comparison clear the existing local floor.

The next boundary approach needs a note-presence/unknown observation that can
distinguish the recorded residual cases while retaining quiet/short notes and
legitimate attacks. Evaluate it alongside register evidence and the established
counterexamples before changing the event graph. Treat energy, periodicity and
pitch salience as conditional evidence; none alone identifies a musical note or
its annotated boundary. Any learned/calibrated observation must follow the shared
[validation requirements](MILESTONES.md#wav-validation), with independent recording
splits and explicit uncertainty. Temporal evidence remains useful and must not be
removed solely because an individual frame favors unknown.

The native audit independently re-reads reference notes, reconstructs admitted
labels from intervals, checks source/reference/inference/salience bindings and
reconciles all correct, wrong, octave and false-rest totals with existing scoring.
Checked stable Win64 builds and both runs finish without warnings or reported
leaks. Policy, Pascal source, full per-center reports and terminal logs are ignored
under `build/phrase-boundary-emissions/`. No model run, held-out use, maintained
code, saved format, listening verdict or delivery change occurs. The 45/23 rest
errors remain open; this diagnosis is not a boundary-quality acceptance result.

<a id="scoped-register-spectrum-checkpoint"></a>
## Declared-range normalization comparison — 2026-09-20

**Rejected as a register solution:** excluding below-range spectral power from
normalization changes none of the preceding mapped-bank note decisions. It does
not resolve the remaining flute errors or low violin articulation failure. The
preferred development inference remains the period-aware entry condition.

The policy was declared before measurement. It preserves the 32 sustain references,
eight excluded articulation challenges, candidate notes, waveform windows, activity
floor, six harmonic bands, donor selection and seven-component distance. If every
frequency-valid candidate's first band starts at bin 15 or above, all candidates
use power in bins 15..2048 instead of 1..2048 for normalization. At 16 kHz with
the existing 4096-point FFT, bins 1..14 lie below the estimator's declared 55-Hz
minimum. If any candidate's band overlaps those bins, the whole event retains
full-range normalization. No harmonic numerator is truncated and no audio is
filtered. This is a diagnostic comparison, not a new input-frequency policy.

All 40 references and both development recordings reproduce the previous
full-range band vectors within 1e-10. The paired scoped vectors retain the same
numerators and a candidate-independent normalization for each window. Across
452 flute windows, removed power averages **3.10%**, with a maximum of **51.34%**;
across 431 violin windows it averages **9.00%**, with a maximum of **58.48%**.
These are unweighted window statistics, not source attribution or whole-recording
energy estimates. Removing this power leaves all **96/96 flute and 87/87 violin**
event winners equal to the prior full-range bank comparison.

| Evaluation | Result |
| --- | --- |
| Articulation challenges | 7/8 retain their mapped pitch; low violin spiccato still changes MIDI 55 → 67. |
| Flute versus preferred entry baseline | Only event 2 changes MIDI 64 → 76, recovering 18 scored centers and sacrificing none; identical to the preceding bank comparison. |
| Flute recorded gates | Coverage 83.3253%, precision 92.5389%, onset F1 0.8737, full-note F1 0.8632. Precision still fails the 98% gate. |
| Violin recorded gates | Unchanged: coverage 87.0852%, precision 98.5520%, onset F1 0.9600, full-note F1 0.8571. All four development gates pass. |
| False-rest centers | Unchanged at 45 flute / 23 violin; the comparison does not move event boundaries. |

Synthetic controls confirm availability for quiet, short and DC-offset notes,
silence rejection, and exact full/scoped equality when the geometry guard protects
a 55-Hz fundamental or its weak-fundamental harmonic signal. Adding a 20-Hz
component to a 440-Hz tone changes the clean/contaminated feature distance from
1.137796 under full normalization to 0.000123 under scoped normalization. This
establishes the intended synthetic effect without implying recorded-note success.
Existing distance, missing-donor and tie controls also pass.

The separate native audit checks original-bank/source/split identities, scope
geometry, retained full vectors, scoped rescaling, every donor and candidate cost,
ranking decisions and exact preservation of interval fields other than note.
Independent distance reconstruction uses unit-vector inner products. Existing
recording-bound scoring and paired tools reconcile the reported outcomes.
Checked stable Win64 builds/runs have no warnings or reported leaks.

**Decision for the next approach:** below-55-Hz normalization alone is insufficient
under this representation and donor policy. Do not spend another iteration moving
that cutoff or treating all residual power as noise. Register work must address
the observed in-range octave-related structure and the independently demonstrated
sustain-to-articulation mismatch, with explicit ambiguity when evidence does not
identify a note. Compare competing explanations on correct and wrong cases before
another ranking change; earlier phase/periodicity failures remain constraints.
This result does not prove the cause of the in-range components, nor rule out
other uses of frequency conditioning. False-rest correction remains a separate
requirement before the combined phrase policy can freeze.

The declared policy, native comparison/audit sources, prepared bank, challenge and
phrase reports, scores and terminal logs are ignored under
`build/scoped-register-spectrum/`. The comparison consumes the maintained spectral
query without changing it. No production inference, saved format, model run,
held-out recording, listening verdict or package changes are adopted.

<a id="spectral-partition-checkpoint"></a>
## Frequency-resolved residual evidence — 2026-09-20

The portable [spectral partition query](ANALYSIS-WAVE.md#spectral-power-partitions)
now retains the information lost by the previous seventh distance component.
It summarizes caller-selected power bands and the intervening gaps, including
their peak bins. The register study supplies the existing six harmonic ranges;
the core owns general power accounting without pitch, WFC or instrument policy.

The recorded policy was declared before measurement. Native analysis reuses the
same mean removal, Hann windows, 4096-point FFT, 16-kHz inputs, activity/range
limits and six-band geometry. It measures all 40 bank sources and all 96 flute
intervals: **652 spectra**. Every retained candidate/window band amplitude matches
the prior bank/ranking cache within 1e-10, and bands plus gaps conserve scoped
power. No source choice, inference result, boundary, candidate ranking or score
changes. DC is excluded as before; near-DC energy remains measured.

For the reference upper octave in the 11 lower-octave-error flute events, mean
power fractions lie in these ranges:

| Region relative to the existing six bands | Range across the 11 events |
| --- | ---: |
| Below the first band | 2.18..43.27% |
| Between the bands | 2.99..22.94% |
| Above the sixth band | 0.005..0.174% |

The dominant residual is therefore lower/intervening content, rather than omitted
high harmonics. For comparison, 85 events containing baseline-correct centers
and no reference-upper-octave centers have below/between ranges of
0.32..12.53% and 0.09..3.83%. These event-level ranges overlap. They are descriptive
development cohorts, not confidence thresholds or independently accepted classes.

Peak locations distinguish two observations. Several below-band peaks are at
roughly 16..47 Hz. Others are near half the reference candidate frequency: event
8 has peaks around 332..336 Hz against a 660.7-Hz candidate, while its strongest
between-band peak is consistently around 992.2 Hz. Event 81 has below peaks
around 430..449 Hz against 878.0 Hz, with several between peaks around 1305..1313 Hz.
These octave-related peaks explain why discarding all residual energy or labeling
it uniformly as noise would lose relevant structure. They do not identify another
instrument, prove a subharmonic production mechanism or override reference labels.

The low violin spiccato challenge is different: at its mapped MIDI 55, mean
power is 94.75% inside the six bands, about 0.001% below, 0.76% between and 4.49%
above. Its prior failure remains principally the sustain-template harmonic-shape
mismatch identified in the preceding diagnosis, rather than the same residual
distribution as the flute cases.

**Next:** distinguish low-frequency recording content from octave-related partial
structure and retain uncertainty about source/part ownership. Any conditioning
must preserve genuine low notes, weak fundamentals and octave changes. Compare
the separated evidence on both correct and wrong cases before declaring another
register policy; a global residual weight, high-pass-only fix or periodicity veto
is not justified by these observations. Keep articulation and false-rest work
separate, and reuse the completed phase/coherence studies rather than repeating
their rejected thresholds.

The maintained spectrum fixture passes checked stable Win32/Win64 and development
Win32 builds, including over-limit rejection and preservation of prior managed
results. The public-query consumer and native peak inspection pass on stable
Win64; all final builds have no warnings and all processes report zero leaks.
The existing build script now includes the focused spectrum fixture. A complete
build/package or new listening review was not run for this change.

Policies, native `measure.lpr` / `inspect.lpr`, source-bound `recorded.json`,
reconciliation and peak logs, and compiler/fixture output remain ignored under
`build/spectral-partition/`. The public unit and focused fixture are maintained;
the experiment adds no saved-format branch, network estimator or held-out use.
Musical admission and the preferred period-aware entry baseline remain unchanged.

<a id="register-representation-diagnosis"></a>
## Register representation diagnosis — 2026-09-20

The rejected mapped-bank comparison now has a source-bound diagnostic explaining
why adding pitch coverage alone did not resolve the errors. **No ranking rule,
mapping label, threshold, event boundary or phrase score changes.** The work
checks nominal labels against existing waveform periodicity measurements and
attributes every candidate's stored distance to its seven components.

For all 40 bank sources, the native prefix and centered periodic estimators use
the same five 1024-sample windows as the bank, with their default 55..1200-Hz,
0.1 difference and 1e-5 silence settings. No alternate region or setting is
selected after a disagreement. Every estimated flute reference window agrees
with its mapped MIDI label; unknown results remain explicit. The low violin
spiccato challenge agrees with MIDI 55 in all five windows under both estimators.
This corroborates its label and identifies a spectral-distance failure, rather
than supporting an octave relabeling of that source.

The checks also retain counterexamples: one centered window of the soft MIDI-55
violin sustain reports MIDI 74, and a late MIDI-72 spiccato window reports MIDI 53
under both estimators. These measurements do not certify every bank label or
justify adopting periodicity as an unconditional octave authority. Prefix and
centered estimators are related measurements, not independent recordings.

| Descriptive case | Existing candidate cost | Component attribution / consequence |
| --- | ---: | --- |
| Low violin spiccato, nominal MIDI 55 | 0.645170 | Third/fifth band mismatches contribute 0.32381/0.21470; the fundamental-band mismatch is only 0.00009. Sustain-template shape dominates this rejection despite waveform support for the nominal pitch. |
| Same source, wrongly preferred MIDI 67 | 0.548160 | Sixth-band mismatch contributes 0.28810 and outside-band mismatch 0.12617. A smaller total template distance is insufficient evidence for octave correction. |
| All 11 flute events containing lower-octave errors | Varies by event | The outside-band component is the largest contribution to the reference upper octave's cost in every case, including the one corrected event. Its frequency placement was discarded by the seven-component representation. |

Attribution preserves the original candidate-dependent nearest donor/window
choices, records each selected pair and its features, and reconciles the component
sum to every stored cost within 1e-10. The diagnostic covers all eight challenges
and all 96 flute intervals, not only the failures shown above. Existing baseline
scores select the descriptive error cases; those labels never enter inference.

A descriptive follow-up applies the same two periodic estimators to the flute
event windows. The 11 events account for all 105 baseline lower-octave error
centers. Across their 102 estimator/window observations, 71 support the baseline
lower octave, 12 support the reference upper octave and 19 remain unknown.
No other note is estimated in that subset. These are overlapping observations,
not 102 independent examples. The one bank-corrected event has six observations
supporting its old lower octave and four supporting the corrected upper octave.
Thus a blanket periodicity veto would oppose that valid correction as well as
the failed violin change. Short windows outside the estimators' declared range
are reported unavailable; none of these 105 error centers is in such an event.

**Next decision:** retain frequency placement of residual energy so the next
experiment can distinguish below-fundamental content, between-harmonic content
and energy above the measured harmonics. Establish what is actually present in
correct and wrong cases before choosing background/other-component handling.
The current evidence does not prove noise, a second instrument, bad labels or
the appropriate correction. Do not simply downweight the seventh component,
discard it, or add a periodicity-voting shortcut against these known answers.
Articulation variation and false-rest boundaries remain separate concerns.

Checked stable Win64 label and attribution builds/runs pass without warnings or
reported leaks. Existing pitch admission validation checks estimator outputs;
source hashes bind converted bank samples and the original phrase WAV. Candidate
costs, window partitions and accounting reconcile with the rejected study.
No network-model run or held-out input is used. Policies, native `labels.lpr` and
`attribute.lpr`, `labels.json`, final `challenges-final.json` / `flute-final.json`
and terminal logs remain ignored under `build/register-bank-diagnosis/`. The final
attribution report adds explicit reconciliation of all periodicity categories;
the candidate costs and conclusions remain unchanged. This is diagnostic evidence,
not a new production estimator, accepted inference capability or genre result.

<a id="mapped-bank-ranking-checkpoint"></a>
## Mapped-bank octave comparison — 2026-09-20

**Decision: reject the declared bank-conditioned policy as a general register
replacement.** It preserves seven of eight separate articulation challenges,
but changes a correctly mapped low violin spiccato note from MIDI 55 to 67.
On the phrase development pair it corrects one flute interval without sacrificing
correct centers; flute precision still fails admission. The preferred inference
remains the period-aware entry condition below. No held-out material is used.

The policy was declared before ranking or phrase scoring. It uses the audited
[mapped reference bank](#register-reference-bank-checkpoint), with 32 sustain
sources as training and eight articulation sources excluded from donors. Flute
or violin is explicit caller metadata, not inferred instrument recognition.
For each event's baseline/lower/upper-octave candidate, measured windows retain
six square-root normalized band energies plus a seventh component containing
the square root of the remaining spectral energy. This preserves the variation
discarded by six-band normalization without assuming that unexplained energy
always indicates a bad pitch.

Candidate donors are the declared instrument's nearest lower/upper mapped roots,
including both dynamics. An exact root uses its two dynamics. No extrapolation
is allowed. Each target window takes the minimum squared seven-component distance
to the selected donor windows; candidate cost averages those minima. The baseline
and at least one alternative must have measurement and bank support to compare.
Missing alternatives supply no evidence. Lowest cost wins, preserving baseline
on exact ties; unsupported baselines remain unchanged. No confidence cutoff or
recording-specific adjustment is fitted.

All eight articulation challenges have a supported comparison. The four flute
staccato sources retain their nominal notes. Three violin spiccato sources do
also; the MIDI-55 source shifts upward despite matching-register sustain donors
being available. Thus the earlier missing-register explanation is insufficient
for this failure. The result is consistent with an articulation/representation
mismatch, but does not isolate which acoustic difference causes it. Those
challenge examples remain development data, not a new held-out acceptance set.

| Development condition | Correct coverage | Precision | Wrong / octave centers | False-rest centers | Onset F1 | Full-note F1 | Complete matches / estimates |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| Flute, period-aware entry baseline | 82.46% | 91.57% | 112 / 105 | 45 | 0.8632 | 0.8526 | 81 / 95 |
| Flute, mapped-bank comparison | 83.33% | 92.54% | 94 / 87 | 45 | 0.8737 | 0.8632 | 82 / 95 |
| Violin, baseline and mapped-bank comparison | 87.09% | 98.55% | 9 / 0 | 23 | 0.9600 | 0.8571 | 75 / 86 |

The native study measures 96 flute/87 violin intervals using 452/431 spectra.
All intervals have a conditional comparison. Flute event 2 changes MIDI 64 to 76
over analysis frames [18747,20187), recovering 18 previously wrong centers. It
retains all 1706 previously correct centers; violin retains all 2178 and changes
no notes. Independent paired scoring confirms unchanged unknown assignments and
false-rest counts. Boundaries, tuning and every other interval field remain
identical. Flute has 87 remaining octave-error centers, and its 45 false-rest
centers still impose the previously recorded 97.58% precision ceiling even if
all remaining pitch errors were fixed. The small gain does not close either gap.

Deterministic controls check preserved outside-band energy, distinct harmonic
positions, ties, unsupported baselines, missing alternatives and donor scope.
An independent audit derives donor eligibility through exhaustive bracket tests
and recomputes squared distance using unit-vector inner products rather than
the ranking program's squared coordinate differences. It verifies every stored
cost/winner, exact challenge measurement reuse, bank/policy/source bindings and
the unchanged interval fields. Existing native phrase scoring and paired
reference tools are reused without changed gates or tolerances. Checked stable
Win64 builds and all controls, inference, scoring and audit processes terminate
without compiler warnings or reported leaks.

Native study sources, policy, challenge results, both rankings/inference outputs,
scores and terminal logs remain ignored under `build/register-bank-ranking/`.
No estimator network rerun, production implementation, format or delivery change
occurs. The command sequence from the repository root is:

```text
compare controls CHALLENGES_JSON
compare phrase INSTRUMENT WAV PARENT_INFERENCE OUTPUT_PREFIX
audit CHALLENGES_JSON
audit RANKING_JSON PARENT_INFERENCE OUTPUT_INFERENCE
```

The study uses the unchanged 16-kHz WAV/8-kHz analysis geometry and existing
independent score/paired tools. Source, bank, policy and output hashes bind the
reports. Failed musical acceptance is retained rather than converted into a
process failure or omitted from the record.

Next investigate the acoustic distinction between the low violin sustain and
spiccato examples, and why the current representation still favors the lower
octave on most wrong flute events. Broader articulation/domain evidence or a
different representation must demonstrate that distinction before another phrase
reranking policy. Do not change a cutoff or donor order to preserve these known
answers, and do not promote the single improved flute interval as an exception.
The boundary work remains separately actionable.

<a id="register-reference-bank-checkpoint"></a>
## Independent mapped register references — 2026-09-20

The register study now has a separate bank of **40 mapped instrument recordings**
from the already attributed CC0 VSCO 2 CE library. This addresses the missing
low/high-register examples in the rejected local-donor policies. It establishes
reference availability, not a new pitch classifier or recorded phrase acceptance.
The source/mapping revision is `6dd651d55dde97fd4028699be9d4481f26917891`;
[provenance](PROVENANCE.md#mapped-register-reference-bank) records attribution.

The policy was declared before acquisition and measurement. Nominal MIDI notes
come from SFZ `pitch_keycenter`, not filename octave conventions. Playback
`tune` is retained, with its opposite sign used for nominal source cents. One
soft violin C4 mapping applies a -20-cent playback correction; measurement uses
+20 nominal source cents. These are mapping labels, not independently verified
instantaneous tuning. Instrument and articulation are supplied metadata.

The 32 sustain sources use both soft and loud dynamics. Flute notes are MIDI
60/64/69/72/76/81; violin notes are 55/57/60/64/67/69/72/76/79/81. Eight separate
staccato/spiccato sources are development challenges and do not train the sustain
bank. All sources and failures were retained; no source was selected by its fit
to the phrase recordings' errors. Source files total 85,263,658 bytes, within the
declared 40-file, 16-MiB-per-file and 320-MiB-total limits.

Native decoding selects channel zero and resamples the full clip to 16 kHz.
Exact float32 little-endian converted samples and their hashes are retained,
without PCM16 quantization. The fixed interval is 0.1..0.6 seconds for every
source. Five 1024-sample Hann windows feed the existing 4096-point FFT/six-band
measurement at the nominal frequency and adjacent octaves. The previous RMS,
coverage and 55..1200-Hz candidate bounds are unchanged. No better-sounding
region, coverage cutoff or note label was selected after observing the results.

| Reference group | Sources / nominal profiles available | Accepted shape windows / measured spectra | Nominal MIDI range | Range of per-source mean accepted six-band coverage |
| --- | --- | --- | --- | --- |
| Flute sustain, training | 12 / 12 | 60 / 60 | 60..81 | 90.92..99.93% |
| Violin sustain, training | 20 / 20 | 100 / 100 | 55..81 | 30.62..99.05% |
| Flute staccato, challenge | 4 / 4 | 17 / 20 | 69..81 | 79.33..95.79% |
| Violin spiccato, challenge | 4 / 4 | 20 / 20 | 55..79 | 85.16..98.76% |

All 200 windows clear the activity floor and yield spectra. Three flute staccato
windows fail the existing 0.1 harmonic-coverage rule and remain in the raw energy
vectors rather than the normalized shape averages. No whole source is too short
or unavailable. Nominal and lower-octave profiles are available for all 40;
upper-octave profiles are available for 23, with 13 outside the frequency range
and four without an admitted shape. Candidate exclusion must not be counted as
evidence that another octave is correct.

The low-A violin sustain has six-band coverage 66.50% soft and 30.62% loud.
This demonstrates substantial pitch/dynamic variation in captured energy; it
does not establish incorrect source labels or a new confidence threshold. Any
bank-conditioned comparison must preserve that variation and test the separate
articulations. A single sample library is not evidence of cross-recording musical
generalization, and these instruments do not represent the intended genre corpora.

Checked stable Win64 catalog, measurement and audit processes terminate with
zero reported leaks. Final measurement/audit builds have no warnings. The audit
checks all 40 unique source identities against the acquisition ledger and catalog,
training/challenge membership, converted hashes and ceiling-duration geometry.
It independently recomputes window RMS through the variance identity and verifies
all activity decisions and spectrum totals. The measurement reuses the previous
spectral function; the audit does not claim a second spectral estimator. An initial
audit build needed named static-array types for FPC's `Default` expression; no
measurement policy or output changed.

Policy, pinned mappings/license, acquisition hashes, native `catalog.lpr`,
`measure.lpr`, `audit.lpr`, converted samples, `measurements.json` and terminal
logs remain ignored under `build/register-reference-bank/`. To reproduce from
the retained catalog and source inputs, build the two programs with checked FPC
and `src`/`tools` search paths, then run from the repository root:

```text
measure NEW_MEASUREMENTS_JSON
audit NEW_MEASUREMENTS_JSON
```

Measurement refuses an existing report. Conversion uses the declared native
resampler; the audit also needs the retained acquisition hash ledger. No phrase
recording, phrase reference, network estimator or held-out recording is a bank
input. No ranking was executed, and no maintained inference/format changed.

Next declare the bank-conditioned register comparison before scoring it. Keep
the eight articulation challenges outside training, explicitly handle missing
pitch coverage, and compare paired phrase changes against the preferred
period-aware entry condition. Do not fit a cutoff to the known phrase answers.
The separate false-rest boundary gap remains open; this bank cannot close it.

<a id="period-entry-activity-checkpoint"></a>
## Entry activity with a period-aware silence floor — 2026-09-20

The follow-up separates activity evidence from sustained pitch. Raw RMS/support
and tuning remain available to the event-admission formulas. Local scale affects
only attack1/attack2 emissions and the unknown-state emission; sustain/release
emissions keep their original support. The existing activity floor has its own
RMS input. Graph edges, birth/transition costs and qualified attacks are unchanged.

Two declared conditions fail before any recorded scoring:

- Reusing the wider window's mean for the floor joins the 40-ms gap control into
  one note. Three wholly silent local windows have apparent RMS
  0.002620/0.001404/0.000534 because the wider mean is nonzero. Unattenuated sustain
  can bridge the gap even though attack scale is small.
- Subtracting the 10-ms window's own mean restores the gap, but fragments a steady
  55-Hz sine of amplitude 0.000015 into five notes. The original decoder retains
  one. Its raw/local floor-inactive counts are 1/42 out of 60 centers: a short DC
  estimate removes too much quiet low-frequency signal. Neutral activity inputs
  reproduce the original decoder's states, intervals and tuning exactly, so the
  changed measurement causes the failure.

The third policy changes window geometry instead of searching thresholds. Its
silence measurement uses the local mean over
`max(160, ceil(2 * 16000 / candidate_frequency))` samples. The candidate is the
maximum raw-support MIDI note, with its raw tuning and ascending-note tie order.
The 50..1250-Hz bound covers the decoder's note/tuning range; windows are at most
640 samples. No supported raw candidate means unavailable activity. The floor
stays 1e-5, and the preceding 10-ms attack scale remains unchanged. This conditional
measurement does not independently establish the candidate's musical identity.

The shared native measurement passes 27 control executions: the two failed cases,
additional 55-Hz gap/30-ms-note cases, and the preceding waveform controls. Neutral
activity exactly matches the original decoder throughout. Each policy was declared
before its own run; no period-count, amplitude-floor or graph-cost sweep is used.

| Development condition | Correct coverage | Precision | Wrong / octave centers | False-rest centers | Onset F1 | Full-note F1 | Complete matches / estimates |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| Flute, qualified baseline | 85.69% | 89.14% | 134 / 127 | 82 | 0.8283 | 0.8182 | 81 / 103 |
| Flute, preceding all-state activity | 79.60% | 92.06% | 106 / 99 | 36 | 0.8632 | 0.8000 | 76 / 95 |
| Flute, period-aware entry activity | 82.46% | 91.57% | 112 / 105 | 45 | 0.8632 | 0.8526 | 81 / 95 |
| Violin, qualified baseline | 88.28% | 97.61% | 22 / 0 | 32 | 0.9385 | 0.8380 | 75 / 90 |
| Violin, preceding all-state activity | 85.25% | 98.61% | 11 / 0 | 19 | 0.9492 | 0.8249 | 73 / 88 |
| Violin, period-aware entry activity | 87.09% | 98.55% | 9 / 0 | 23 | 0.9600 | 0.8571 | 75 / 86 |

**Decision: retain period-aware entry activity as the preferred development
condition, without production admission or policy freeze.** Violin still passes
all four gates. Flute now clears coverage, onset and full-note gates, but not
98% precision. Compared with all-state attenuation, it gains 59/46 correct centers
and restores 5/2 complete matches, while accepting 9/4 more false-rest centers.
The tradeoff is explicit; this is not an across-the-board improvement.

Relative to the qualified baseline, flute retains 1699 correct centers, loses
73 to unknown and one to wrong pitch, corrects six wrong centers, rejects 17 and
gains one correct from unknown. Violin retains 2177 correct centers, loses 31 to
unknown, rejects 13 wrong centers and gains one correct from unknown. The rest
audit removes 40/10 baseline errors but introduces 3/1, producing net reductions
of 37/9. Correct losses by old attack1/attack2/sustain/release1/release2 state are
36/14/5/3/16 and 13/5/3/2/8. The descriptive early/late-ending counts return to the
qualified baseline's 0/1 and 7/2. Higher F1 partly reflects fewer estimates;
onset-eligible counts remain 82/84.

The refreshed residual audit finds 11 wholly wrong flute events containing 107
wrong and 29 false-rest centers. Of 112 total wrong centers, 105 are lower-octave
errors; 82 are in sustain. Only three wrong centers favor the reference pitch
in raw salience. Violin has nine wrong centers and no wholly wrong events.
False-rest centers nearer the following onset/preceding ending are 33/12 and
16/7; those descriptive labels do not authorize reference-derived trimming.
Even perfect register recovery with all 45 flute rest errors retained would cap
precision at **97.58%**. Register evidence and remaining boundary admission are
still separate prerequisites.

Native inference first exactly replays the qualified baseline from cached raw
salience. The independent audit then reconstructs the raw winning candidate,
tuning, period window and RMS for every one of 2997 centers per part, using
sum/squared-sum variance rather than the measurement's two-pass deviation sum.
It verifies unchanged attack reports and source-bound paired rest totals. Existing
scoring, paired-reference, note diagnostics and residual tools are reused without
relaxed timing, eligibility or acceptance rules. An initial audit multiplied a
Single salience by an integer before applying Double cents; making that arithmetic
explicit fixes the audit mismatch without changing inference or its policy.

Evidence is ignored under `build/phrase-entry-activity/`: `POLICY.md`,
`FLOOR-POLICY.md`, `PERIOD-POLICY.md`, native entry/period units, control programs,
`infer.lpr`, `audit.lpr`, `period-controls-shared.log` and the flute/violin
inference, score, paired, measurement-audit, note-diagnostic and residual outputs.
Failed control logs intentionally exit 1; final period controls and recorded
processes exit successfully, with zero reported leaks. Checked stable Win64
builds have no warnings. No network inference, held-out data or maintained code
changes occur. Source/code/policy hashes are retained in the checkpoint ledger.

Use the [preceding command pattern](#local-activity-checkpoint) with the new study
directory and `PERIOD-POLICY.md`, adding `build/phrase-entry-activity` to compiler
search paths. The measurement audit additionally accepts the exact raw
`SALIENCE_PREFIX.salience` path as its sixth argument. Reuse the existing residual
audit as `residuals INFERENCE SCORE NOTES SALIENCE_PREFIX WAV OUTPUT.json`.
The period measurement adds at most two passes of `3000 × 640` sample visits;
the original waveform and per-decode bounds remain. Changed recorded decodes
consider 18617391/18619767 edges, below their 20-million bound.

Next work should target the remaining whole-event register errors with suitable
independent sound evidence, while retaining this entry/continuation separation
and the explicit rest/quiet-note counterexamples. Further floor or neighbor-order
variants alone cannot close phrase admission. Overall completion is unchanged.

<a id="local-activity-checkpoint"></a>
## Center-local activity and recorded note coverage — 2026-09-20

A declared condition separates local activity from the unchanged pitch model's
64-ms input window. At each existing 16-kHz center, it measures RMS over the
centered 160-sample (10-ms) output hop, subtracting the wider window's mean.
It replaces the decoder RMS input and multiplies all note supports by
`min(1, local_RMS / model_RMS)`; zero model RMS yields zero scale. Using the wider
mean avoids estimating DC from less than a low note's period. This is a fixed
acoustic cue, not calibrated confidence or a fitted threshold.

Raw pitch/tuning evidence, qualified attack candidates, graph/costs, event
admission and scoring rules remain unchanged. The existing event tuning-weight
formula consumes the changed RMS/support inputs; aggregate event tuning can
therefore change. No timbre reranking is combined with this condition.

Twenty-three waveform controls preserve steady 55/110/220/880-Hz tones at two
phases and ordinary/quiet amplitudes, a DC-offset tone, a 30-ms note, a 40-ms
same-note interruption and silence. Controlled pitch support describes a tone
present somewhere in the broad window; these controls do not run a learned model.
Both ordinary and quiet short notes remain, and the interruption produces two
notes with a silent center gap.

| Development condition | Correct coverage | Precision | Wrong / octave centers | False-rest centers | Onset F1 | Full-note F1 | Complete matches / estimates |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| Flute, retained qualified baseline | 85.69% | 89.14% | 134 / 127 | 82 | 0.8283 | 0.8182 | 81 / 103 |
| Flute, local activity | 79.60% | 92.06% | 106 / 99 | 36 | 0.8632 | 0.8000 | 76 / 95 |
| Violin, retained qualified baseline | 88.28% | 97.61% | 22 / 0 | 32 | 0.9385 | 0.8380 | 75 / 90 |
| Violin, local activity | 85.25% | 98.61% | 11 / 0 | 19 | 0.9492 | 0.8249 | 73 / 88 |

**Decision: useful activity evidence, rejected as a general replacement.** Violin
passes all four existing development gates (coverage ≥80%, precision ≥98%, onset
F1 ≥0.80, full-note F1 ≥0.70). Flute fails both coverage and precision. This does
not freeze a recording-specific policy or admit the supported phrase workflow.
Held-out recordings remain unused.

The independent paired audit exposes the cost of the improved precision:

| Changed centers relative to baseline | Flute | Violin |
| --- | ---: | ---: |
| Correct → unknown | 132 | 76 |
| Correct → wrong | 1 | 0 |
| Wrong → correct | 7 | 0 |
| Wrong → unknown | 22 | 11 |
| Wrong → different wrong pitch | 0 | 1 |
| Unknown → admitted pitch | 0 | 0 |
| False-rest pitches removed / introduced | 46 / 0 | 13 / 0 |

Lost correct centers by baseline attack1/attack2/sustain/release1/release2 state
are **38/17/22/22/34** for flute and **21/8/13/9/25** for violin. These phase names
are latent decoder states, not independent physical phase labels. The descriptive
nearest-onset audit finds early endings increase from **0 to 5** for flute and
**7 to 9** for violin; late endings stay 1/2. The number of onset-eligible estimates
stays 82/84, so the higher onset F1 partly reflects fewer estimates, not newly
matched onsets. Full-note matches fall in both parts. There is useful rest
discrimination, but global attenuation also removes accepted note coverage.

Next, separate use of local activity at note entry from sustained pitch and
release evidence. A condition must protect both ordinary and quiet short notes
and the silent-gap control before recorded comparison. Do not recover coverage
by extending every tail or lower the precision/coverage gates. Register remains
an independent failure; this condition still has 99 flute octave errors.

The native inference tool first exactly replays all baseline latent states,
note intervals and event tuning from the same raw cache. An independent audit
then recomputes every broad/local RMS and scale using sum/squared-sum arithmetic,
checks unchanged attack-candidate reports and reconciles paired rest counts.
The existing scorer and paired-reference audit retain all 2997 centers per part
and the original note eligibility/timing rules.

An initial audit mismatch exposed unintended Single-precision intermediate
calculations in diagnostic squared samples and overloaded clamps. The final
measurement/audit use explicit Double arithmetic, with no threshold or policy
change. Rebuilt controls, inference and all affected scoring/audits pass; final
musical counts equal the preliminary result. Earlier diagnostic failures remain
separate from final evidence.

Evidence is ignored under `build/phrase-local-activity/`: `POLICY.md`, native
`pythian.study.localactivity.pas`, `controls.lpr`, `infer.lpr`, `audit.lpr`,
`controls-double.log` and `{flute,violin}-double-*` reports/logs. Final checked
stable Win64 builds have no warnings; executions terminate with zero reported
leaks. No network inference, held-out input, maintained unit or format changes.
Build with `-B -O2 -Sa -Cr -Co -Ci -gl -gh`, `src`/`tools`, and study search paths
`build/phrase-local-activity`, `build/phrase-joint-events`,
`build/phrase-qualified-events`, `build/phrase-centered-candidates`, using isolated
unit/executable output. Commands from the root are:

```text
controls
infer SALIENCE_PREFIX WAV POLICY.md OUTPUT.json BASELINE_INFERENCE.json
score OUTPUT.json WAV NOTES POLICY.md SCORE.json
paired BASE_SCORE SCORE.json NOTES WAV
audit BASE_SCORE SCORE.json BASELINE_INFERENCE.json OUTPUT.json WAV
event.diagnostics OUTPUT.json SCORE.json NOTES
```

The scorer/event diagnostics reuse `build/phrase-joint-events/win64`; the paired
audit reuses `build/phrase-qualified-events/win64`. Local measurements add 160
sample visits per center, bounded by 480000 visits. Baseline replay and changed
inference each retain the existing 3000-frame/20-million-edge decoder limits.
The changed runs consider 18617391/18619767 edges. Existing waveform/qualified
attack work remains separately bounded. This is development evidence for
[boundaries](MILESTONES.md#wav-03-boundaries), not accepted inference, synthesis
listening, genre quality or additional overall completion credit.

<a id="pitch-conditioned-timbre-checkpoint"></a>
## Pitch-conditioned neighboring timbre — 2026-09-20

The follow-up to the contextual energy condition changes donor selection only.
A policy declared before execution selects up to eight eligible neighbors for
each candidate, ordered by absolute semitone distance to that candidate, temporal
midpoint distance, then earlier event index. Donor eligibility stays fixed:
within four seconds, duration at least 80 ms, an available baseline shape and a
different pitch class from the target. At least three donors are needed.
Baseline donor labels/shapes remain unchanged; no reference enters ranking.

The native reranker reuses the exact cached six-band vectors, shared waveform
windows, event boundaries and residual objective from the preceding condition.
It performs no new waveform measurement or network inference. The hypothesis is
that nearby pitches offer more appropriate sound references; the competing risk
is reinforcing wrongly inferred donor registers. No donor-count, time-radius or
score-cutoff sweep is performed.

| Diagnostic ranking | Recovered wrong centers | Sacrificed correct centers | Correct / wrong / false-rest centers | Rank-only precision |
| --- | ---: | ---: | --- | ---: |
| Flute, preceding energy condition | 112 | 3 | 1882 / 25 / 82 | 94.62% |
| Flute, candidate-pitch donors | 110 | 3 | 1880 / 27 / 82 | 94.52% |
| Violin, preceding energy condition | 0 | 48 | 2160 / 70 / 32 | 95.49% |
| Violin, candidate-pitch donors | 0 | 48 | 2160 / 70 / 32 | 95.49% |

**Decision: reject this condition too.** Relative to the preceding condition,
only flute event 35 changes rank, returning from MIDI 76 to baseline 64 and
losing two recovered centers. Violin ranks are unchanged. The same short flute
event 78 and low violin events 21/46 still sacrifice 3/20/28 correct centers.
The full 104/91 event sets are evaluated; none is unranked or removed.

The donor inventory explains a limit of this attempted conditioning. For violin
event 21 (baseline MIDI 55), its eight baseline-candidate donors have pitches
60, 71 and six 72s. Event 46's donors are 71 and seven 72s; its baseline and
upper candidates select the same donors. Ordering by pitch does not provide
missing observations near the low register, and a median over predominantly high
notes still supplies a high-register template. This rejects the declared neighbor
policy, not the broader possibility of learning pitch-dependent timbre from
adequate independently admitted examples. The evidence does not establish the
competing wrong-register-cluster explanation as the sole cause either.

Controls cover different low/high shapes, uniform-template invariance, target/
same-pitch-class exclusion, distance/cost ties, too few donors, short donors and
out-of-range donors. An independent native audit checks every selected donor's
eligibility and rank by counting preceding eligible alternatives, verifies exact
parent measurements, recomputes all residual costs and reconciles the unchanged
2997 scored centers per part with source/reference-bound baseline reports.

Evidence remains ignored under `build/phrase-timbre-context/`: `PITCH-POLICY.md`,
`rerank-pitch.lpr`, `audit-pitch.lpr`, `compare-pitch.lpr`, `pitch-controls.log`,
`{flute,violin}-pitch.json`, their audit reports and comparison logs. Checked
stable Win64 builds use `-B -O2 -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools` with
isolated unit/executable output. Builds have no warnings; all terminal executions
report zero unfreed blocks. Commands from the repository root are:

```text
rerank-pitch controls
rerank-pitch ENERGY_CACHE.json PITCH-POLICY.md OUTPUT.json
audit-pitch OUTPUT.json CURRENT_INFERENCE SCORE SCORE_INFERENCE NOTES PITCH-POLICY.md WAV AUDIT.json ENERGY_CACHE.json
compare-pitch ENERGY_CACHE.json OUTPUT.json AUDIT.json
```

Input is bounded to 8 MiB, 512 events, three candidates, five windows and six
amplitudes per window. The donor scan bound is `24 × event_count²`: 259584/198744
for these recordings. The report binds its parent measurement and both preceding
measurement policies. There is no new native artifact format or production label.

Next, use the existing [residual audit](#residual-event-checkpoint) to investigate
center-local onset support separately from the 64-ms model window. Most false-rest
centers lie near a following onset; this is a hypothesis about window support,
not permission to trim by reference proximity. Protect short/quiet attacks and
genuine sustain in controls before comparing recorded results. Further timbre
work needs evidence of suitable donor coverage, not another ordering of the same
unsupported local templates. Held-out material, listening acceptance and the
overall completion estimate remain unchanged.

<a id="neighbor-timbre-checkpoint"></a>
## Neighboring timbre and retained spectral energy — 2026-09-20

The next register probe uses nearby inferred events as harmonic-shape references,
rather than another local salience cutoff. This is an independently authored
contextual experiment, broadly motivated by
[Alvarado and Stowell's learned harmonic priors](https://arxiv.org/abs/1705.07104).
It does not implement their Gaussian-process model or reuse external code.
References enter only the separate audit; no production inference changes.

The first policy measures the inferred note and adjacent octaves in 55..1200 Hz.
Each event supplies up to five Hann windows wholly inside its inferred interval,
at most 1024 samples and at least 256, with native 4096-point FFTs at 16 kHz.
Six harmonic-band amplitudes form a normalized shape. AC RMS below 1e-5 or
harmonic energy below 0.1 of positive-frequency power is unmeasured. Bands use
half-width `min(0.4*f0, max(2*rate/window, 0.03*harmonic_frequency))`.

Each target uses up to eight nearest events within four seconds, excluding itself
and its inferred pitch class. Donors must last at least 80 ms and have a measured
baseline shape; at least three are needed. Median cosine distance ranks candidates
against unchanged donor profiles. No instrument label, reference note, octave
majority or iteratively relabeled donor is supplied.

**Normalized shape alone fails.** It ranks all 127 flute octave-error centers
correctly but damages 232 previously correct flute centers and 409 violin centers.
A subsequent descriptive audit finds that 229/232 flute and 382/409 violin
sacrifices retain at most half the baseline candidate's measured harmonic energy.
Candidate-specific valid-window counts also differ at 55 recovered and 62
sacrificed flute centers and 102 sacrificed violin centers. These observations
motivated a second declared condition, not a fitted rejection threshold.

The second policy compares candidates on the same waveform windows and accounts
for unexplained spectral energy. Its six amplitudes divide by the square root of
total positive-frequency power, without unit-shape renormalization or the target
candidate's coverage cutoff. For each unchanged donor template, squared dot product
gives explained band energy; cost is one minus its mean over windows. Median donor
cost determines rank. This is a coarse least-squares band-amplitude comparison,
not waveform reconstruction or calibrated confidence. No weight/cutoff is fitted.

| Diagnostic ranking | Recovered wrong centers | Sacrificed correct centers | Correct / wrong centers | Unchanged false-rest centers | Rank-only precision |
| --- | ---: | ---: | --- | ---: | ---: |
| Flute, normalized shape | 127 | 232 | 1668 / 239 | 82 | 83.86% |
| Violin, normalized shape | 0 | 409 | 1799 / 431 | 32 | 79.53% |
| Flute, residual on shared windows | 112 | 3 | 1882 / 25 | 82 | 94.62% |
| Violin, residual on shared windows | 0 | 48 | 2160 / 70 | 32 | 95.49% |

Baseline precision remains 89.14%/97.61%; production labels are unchanged.
The second condition changes 17 flute and two violin event ranks. Its remaining
sacrifices are flute event 78 (MIDI 74 → 86, three correct centers) and violin
events 21/46 (55 → 67, 20/28 correct centers). Both violin candidates still discard
more than half the original harmonic coverage. Accounting for energy substantially
reduces the original failure but does not establish a safe replacement rule.

**Decision:** reject both policies for production admission. Contextual harmonic
evidence distinguishes many sustained flute errors; a shared normalized timbre
template still misidentifies genuine low violin notes and a short flute note.
The next hypothesis must account for pitch/articulation-dependent sound while
protecting those counterexamples, rather than select a cutoff on these results.
Rest-boundary work remains necessary: even correcting every baseline flute pitch
error with all 82 false-rest pitches unchanged would cap precision at 95.88%,
below the existing 98% gate. No boundary, unknown region or scored center is removed.

Each condition passes nine pitched controls (sine, weak/missing fundamental,
quiet/DC input, true lower/upper octaves, a 30-ms note and a deliberately lower
reported note) plus unavailable silence. These controls establish neither
recorded timbre invariance nor musical admission. Measurements cover 104/91
inferred intervals and 468/435 spectra; all events have enough donors. The scorer's
103/90 estimated-note counts retain its existing endpoint rules. The audit checks
all 2997 centers per part, independently reconstructs reference/inferred labels,
and reconciles the original correct/wrong/rest totals. It also verifies exact
interval/state equivalence between the original inference and its boundary-API
replay, and independently recomputes the second condition's residual costs from
saved vectors with tolerance 1e-10.

Evidence is ignored under `build/phrase-timbre-context/`: original `POLICY.md`,
later `ENERGY-POLICY.md`, native `probe.lpr`, `probe-energy.lpr`, `audit.lpr`,
measurement/control logs and reports. Build with checked stable Win64,
`-O2 -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools`, using isolated output directories.
Both policies preserve source/inference binding; the second also binds the base
policy. Run from the repository root:

```text
probe controls
probe measure SOURCE.wav INFERENCE.json POLICY.md OUTPUT.json
probe-energy controls
probe-energy measure SOURCE.wav INFERENCE.json ENERGY-POLICY.md OUTPUT.json
audit MEASUREMENT CURRENT_INFERENCE SCORE SCORE_INFERENCE NOTES POLICY WAV OUTPUT
```

Final second-condition audits are `flute-energy-verified` and
`violin-energy-verified`. Checked builds have no warnings; controls, measurements
and audits terminate with zero reported leaks. Conservative work is
140661248/123069128 units, below 268435456. No learned network rerun, held-out
input, listening verdict, native format, library inference or completion credit
changes. [Register](MILESTONES.md#wav-03-register),
[boundaries](MILESTONES.md#wav-03-boundaries) and independent admission stay open.

<a id="native-model-fidelity-checkpoint"></a>
## Native model execution fidelity — 2026-09-20

The optional native CREPE tiny study now has a numerical comparison against
TensorFlow **2.18.1 CPU**, invoked through its
[C API](https://www.tensorflow.org/install/lang_c) from Pascal. This verifies
execution of the pinned converted topology/weights used by the study. It does
not compare another model export, establish musical accuracy or adopt a runtime
dependency for Pythian.

The reference harness reads the model's named weight manifest and constructs a
graph using framework convolution, bias/ReLU, inference batch normalization,
max pooling, reshape, dense and sigmoid operations. It does not call native
convolution or reuse the native folded normalization. Frame centering and RMS
normalization use framework float32 operations; the native study's Double
accumulation difference is included in the measured error. The pinned topology
was reviewed for layout, padding, strides, activation order and normalization.

Before execution, the comparison required maximum absolute activation difference
≤0.0002 and decoded frequency difference ≤0.5 cents. It also reports winning-bin
changes. Twelve controls cover sines, weak/missing fundamentals, quiet input,
gain/DC changes, silence, constant input, vibrato and an amplitude ramp. The
recorded comparisons check every one of 2997 retained frames per development part,
all 360 activations per frame. Exact source/model/cache hashes, centers and
recomputed input RMS bind the comparison; no reference note enters it.

| Compared input | Frames | Maximum activation difference | Maximum decoded difference, cents | Winning-bin changes / out-of-tolerance frames |
| --- | ---: | ---: | ---: | ---: |
| Controls | 12 | 0.000000358 | 0.000043 | 0 / 0 |
| Spring flute | 2997 | 0.0000007153 | 0.00006535 | 0 / 0 |
| Spring violin | 2997 | 0.0000007153 | 0.00006491 | 0 / 0 |

**Decision:** the declared-model execution check passes for the complete retained
development inputs. A transcription/layout error in native execution does not
explain their large octave-support differences. Preserve this comparator for
future arithmetic changes; do not schedule the same unresolved parity check again.
Musical interpretation, confidence calibration, native execution cost and frozen
independent evaluation remain open under [WAV-VALIDATION](MILESTONES.md#wav-validation)
and [register admission](MILESTONES.md#wav-03-register). Agreement with a framework
is not a musical admission result.

All study sources, downloaded reference runtime, original runtime licenses,
reports and logs remain ignored under `build/crepe-fidelity/`. The existing model
retains its complete upstream MIT notice under `build/phrase-learned-pitch/model/`.
Official runtime ZIP SHA256 is
`28acdcea6c6b34828cf0e95e67802b0f3577d51bc2e8915de811b7aa0b04452d`;
loaded DLL SHA256 is
`07687defc3f36ee93e372b692d37317b348369a80b3a36201a55d69d7d9edba8`.
There is no installation, production dependency, submodule change or new native
artifact format. The retained ZIP's license and third-party notices stay with it.

Build `compare.lpr` with checked stable Win64, `-B -O2 -Sa -Cr -Co -Ci -gl -gh`,
core/tool paths and both study unit directories. Run from the repository root:

```text
compare MODEL_DIR RUNTIME_LIB_DIR
compare MODEL_DIR RUNTIME_LIB_DIR RAW_PREFIX SOURCE.wav OUTPUT.json
```

Controls run before recorded comparisons. `controls.log`, `flute.json/.log` and
`violin.json/.log` are terminal and pass, with zero Pascal heap-tracker leaks;
that tracker does not inspect the external runtime allocator. The final native
build has no warnings. Reference comparisons take about 9.3 seconds per recorded
batch in overlapping runs, not a benchmark of the native scalar implementation,
whose existing roughly 17 processing seconds/audio second cost remains unresolved.
No inference, acceptance gate, held-out result, listening verdict or percentage
credit changes. Earlier checkpoints below retain their historical fidelity limits;
this section supplies the later scoped verification.

<a id="companion-annotation-checkpoint"></a>
## Companion frame/note annotation audit — 2026-09-20

The existing development failures were checked against the same recordings'
companion frame-pitch annotations. [URMP's documentation](https://labsites.rochester.edu/air/projects/URMP/URMP_doc.pdf)
defines 46-ms annotation windows with 10-ms hops. Its
[dataset paper](https://hajim.rochester.edu/ece/sites/gsharma/papers/LiMultimodalMusicDatasetTMMFeb2019_08411155.pdf)
describes manual corrections to frame and note annotations. These are related
annotation products, not independent estimators or a replacement reference.

A native diagnostic recomputes note labels using the existing 8-kHz rounding
convention and reconciles every row and correct/wrong/rest/octave total with the
qualified-event scorer. Each scored center matches the nearest annotated frame
within 5 ms, choosing the earlier frame on a tie. Positive annotated Hz rounds
to the nearest MIDI note; zero stays unvoiced. All 2997 centers per part match,
with no overlapping note labels at the scored centers.

| Wrong-pitch centers: companion frame annotation agrees with… | Flute | Violin |
| --- | ---: | ---: |
| Existing note reference | 127 | 9 |
| Inferred pitch instead | 2 | 8 |
| Neither voiced pitch | 3 | 4 |
| Unvoiced annotation | 2 | 1 |
| Total, unchanged | 134 | 22 |

Of the **127 flute octave errors**, the companion annotation supports the note
reference on **126** and is unvoiced on one; it never supports the inferred lower
octave. Restricting diagnosis to annotation windows wholly inside a single note
still leaves **87 wrong flute centers**, all supported at the reference pitch.
Thus nearest-frame alignment and note edges cannot explain the main register
failure. This does not disprove the measured physical lower-period component;
it reinforces the distinction between waveform periodicity and musical identity.

Violin retains four wrong centers in that interior split: three frame annotations
support the note reference and one supports inference. Of 82/32 pitched-in-rest
centers in flute/violin, the companion annotation is unvoiced on 60/20, agrees
with inference on 10/8, and marks another voiced pitch on 12/4. Annotation targets
differ near some transitions, but no label or scored center is substituted or
removed. Existing coverage, precision and note-F1 gates remain unchanged.

**Decision:** retain register as a genuine unresolved musical inference outcome.
Do not pursue global octave doubling, trim edges to hide it, or replace note labels
with whichever reference favors the estimator. [WAV-VALIDATION](MILESTONES.md#wav-validation)
must distinguish acoustic frame evidence from note-event labels and retain their
uncertainty. Boundary diagnosis can use this comparison descriptively; automatic
cuts still require reference-free evidence. The next register hypothesis must
explain sustained subharmonic ambiguity while preserving genuine lower notes.

Evidence is ignored under `build/phrase-reference-audit/`. Companion files come
from the same pinned preparation as the [existing recordings](#first-evaluation-protocol--declared-before-measurements).
The native `audit.lpr` binds source/frame-file pairs and hashes the notes,
inference, score and declared policy. Build with checked stable Win64,
`-B -O2 -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools`, using isolated output directories;
run `audit SCORE INFERENCE NOTES F0S WAV POLICY OUTPUT`. Final reports/logs are
`flute-bound` and `violin-bound`. Both terminate successfully with zero reported
leaks; the final build has no warnings. No maintained inference, model, artifact
format, held-out evaluation, listening verdict or completion percentage changes.

<a id="residual-event-checkpoint"></a>
## Residual event identity and phase audit — 2026-09-20

The source-bound audit of the unchanged qualified joint-event results separates
wrong note identity from boundary errors. It reads the original WAV identity,
reference rows, inferred intervals/states, score report and cached raw salience.
Independent interval/reference lookup at every admitted center reconciles with
the existing scorer. Source, reference, inference, score, metadata, salience and
diagnostic-policy hashes bind the report. References enter diagnosis only; no
inference, admission threshold or held-out recording changes.

| Residual evidence | Flute | Violin |
| --- | ---: | ---: |
| Correct / wrong / pitched-in-rest centers | 1773 / 134 / 82 | 2208 / 22 / 32 |
| Lower-octave / upper-octave / other wrong centers | 127 / 0 / 7 | 0 / 0 / 22 |
| Wrong centers in latent sustain state | 88 | 3 |
| Events with no correctly pitched admitted center | 17 | 3 |
| Wrong / rest centers in those events | 130 / 56 | 11 / 3 |
| Wrong centers with greater raw support for reference than selected note | 3 | 1 |
| Rest centers nearer a following onset / preceding ending | 64 / 18 | 23 / 9 |

For example, flute event 1 spans 2.033375–2.213375 seconds at inferred MIDI 64.
All 17 reference-active centers are wrong against MIDI 76, plus one rest center.
Mean raw selected/reference note support on those wrong centers is 0.754/0.131.
This is a whole-event register error, not solely an incorrect endpoint. Salience
support is the maximum activation among bins rounding to a MIDI note; it is not
a calibrated confidence or an independent truth label.

The five phase counts, ordered attack1/attack2/sustain/release1/release2, are:
flute wrong **10/6/88/16/14**, rest **26/13/32/3/8**; violin wrong **8/4/3/4/3**,
rest **13/6/5/1/7**. Latent phase names describe decoder states, not independently
observed physical note phases.

An ablation retaining only sustain centers gives flute coverage/precision
**70.57%/92.41%** and violin **75.77%/99.58%**. Both fail the unchanged 80%
coverage gate; flute also fails 98% precision. It loses 313 correct centers in
each part. This rejects blanket attack/release removal as a solution. It does
not evaluate a selective boundary policy or supply a new note-F1 result.

False-rest distance bins of ≤10, >10–32, >32–50 and >50 ms from the nearest
reference boundary contain **37/28/8/9** flute and **21/10/1/0** violin centers.
The 32-ms split is half the existing 1024-sample model window at 16 kHz. Most
rest errors lie within that distance, but proximity alone cannot establish that
window overlap caused them. Likewise, nearest-onset versus nearest-end assignment
does not prove an early attack or late release. None of these labels trims audio
or removes scored centers.

**Decision:** retain qualified articulation, reject broad edge-state deletion,
and separate register evidence from rest-boundary evidence. Before another
decoder-cost change, require a hypothesis that can distinguish the wholly wrong
events while protecting genuine short/quiet lower notes and octave changes.
Raw local salience already favors the wrong identity on almost every wrong
center, so treating its maximum as reliable confidence is unsupported. Model
numerical fidelity remains an independent [adoption gate](MILESTONES.md#wav-validation);
this audit neither proves nor disproves a model-implementation defect.

Evidence is ignored under `build/phrase-residual-events/`. Build `residuals.lpr`
with checked stable Win64, `-B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools`, and
isolated unit/executable output paths. From the repository root run:

```text
residuals INFERRED.json SCORE.json NOTES.txt RAW_PREFIX ORIGINAL.wav OUTPUT.json
```

The diagnostic reads its local `POLICY.md`, refuses an existing output and writes
the complete per-event accounting. Final reports/logs are `flute-complete` and
`violin-complete`; both processes exit successfully with zero reported leaks,
and the native build has no warnings. An earlier invocation supplied a WAV where
the note table was required; its input rejection is retained separately as
`violin-wrong-input.log` and is not a completed audit. No model measurement,
musical acceptance, listening verdict, package or maintained implementation is
changed by this diagnostic.

<a id="qualified-event-cues-checkpoint"></a>
## Pitch-qualified articulation cues — 2026-09-20

The next comparison changes only the evidence authorizing an attack cue in the
joint decoder. Generic waveform valleys remain candidates. The existing pitch
boundary query qualifies them using 80-ms left/right context outside an inner
20-ms gap: both sides must admit a pitch, and their notes must differ or central
evidence must include silence/no-period. The query uses the native 8-kHz sinc
excerpt and default 294-sample/80-hop pitch track. All original 16-kHz valley
positions, neural salience, joint costs/states, tuning admission, release behavior
and evaluation rules remain fixed. Reference annotations enter scoring only.

The declared waveform controls produce three amplitude-modulation valleys and
qualify none; a 60-ms interruption within a 220-Hz tone and a valley across a
220-to-330-Hz change each produce one qualified candidate. This establishes those
controls, not general articulation accuracy. The unchanged decoder retains its
preceding short-octave and state-transition protections.

| Development condition | Attack cues | Coverage | Precision | Wrong / octave centers | False-rest pitches | Complete matches / estimates | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute, all valleys | 253 | 85.65% | 87.42% | 142 / 136 | 113 | 72 / 138 | 0.7210 | 0.6180 |
| Flute, pitch-qualified valleys | 28 | 85.69% | 89.14% | 134 / 127 | 82 | 81 / 103 | 0.8283 | 0.8182 |
| Violin, all valleys | 233 | 87.92% | 97.00% | 30 / 0 | 38 | 70 / 106 | 0.8718 | 0.7179 |
| Violin, pitch-qualified valleys | 50 | 88.28% | 97.61% | 22 / 0 | 32 | 75 / 90 | 0.9385 | 0.8380 |

Both recorded parts now clear coverage ≥80%, onset F1 ≥0.80 and full-note F1 ≥0.70
in this experimental path. **Neither clears the required 98% pitch precision.**
Keep the qualified cue as the better-supported experimental condition; do not
admit the complete learned event policy or consume held-out recordings yet.
This does not replace the separate baseline's accepted mechanisms or establish
that neural inference is more accurate than that complete baseline.

The paired audit finds no previously correct center becomes wrong in either part.
Flute loses three correct centers to unknown, fixes four wrong centers, rejects
six wrong centers and introduces two wrong centers from unknown. Violin loses four
correct centers to unknown, fixes three wrong centers, rejects seven, changes two
wrong labels and gains ten correct/two wrong centers from unknown. All categories
reconcile with independently source/reference-bound frame totals.

Among eligible estimates, unmatched contiguous same-pitch reattacks fall from
29 to two for flute and from 15 to two for violin. The nearest-onset diagnostic
finds flute early/late endings change from 12/0 to 0/1; violin changes from 15/0 to
7/2. These are reference-based diagnostics, not inferred cuts or substitute gates.
The qualifier addresses much of the over-segmentation without a new release rule.
Residual octave errors and admitted pitch in reference rests still block precision.

### Reusable native context query

The useful context operation is now extracted into the existing portable
[pitch-region API](PITCH.md#boundary-context) as `SummarizePitchBoundary`.
Callers control context/gap lengths and region admission; output retains detached
left/right votes, missing-context status and central unresolved evidence. It does
not depend on WFC, waveform candidate discovery or a learned model. Qualification
is a cue and makes no standalone note-on/off guarantee. No saved format or default
learning policy changes.

The expanded maintained pitch fixture passes checked stable Win32/Win64 and
development Win32, including ownership, exact endpoints, zero gap, configurable
admission and failures before edge fallback. The study consumer compares every
core query against the preceding helper on all 486 recorded valley candidates.
A native replay audit verifies every report field except elapsed decoder time,
including source/model/policy bindings, candidate evidence, states and intervals.
The waveform controls also pass through the extracted query.

The two recorded decoder edge counts are 18617391 and 18619767, below 20 million.
Decoder time is about 0.22 seconds per cached 30-second excerpt on this checked
Win64 run; resampling, pitch context and file verification add work outside that
timer. This does not change the expensive original network measurement. All final
controls, inference, scoring, paired/event diagnostics and replay processes are
terminal with zero reported leaks and no compiler warnings.

Evidence is ignored under `build/phrase-qualified-events/`; three-target core
checks are under `build/pitch-boundary-api/`. Build the study `controls`, `infer`,
`paired` and `replay` with checked stable Win64 and core/tool/study paths; the
consumer also uses the unchanged joint decoder and preceding boundary helper.
Run `infer SALIENCE_PREFIX ORIGINAL_WAV POLICY.md INFERRED.json`, then the preceding
joint study's `score` and `event.diagnostics` commands. The local `paired` command
compares preceding/current score reports with original source and references;
`replay BEFORE.json AFTER.json` checks extraction equivalence. Core builds use
`-B -Sa -Cr -Co -Ci -gl -gh -Fusrc` and the existing pitch fixture; study builds add
`-O2`, tool/helper paths and isolated output directories. No remote CI, package
refresh, held-out result or listening acceptance is claimed.

The next acceptance decision belongs to register and residual rest/ending
admission, retaining the improved articulation path and the genuine short-note
control. Do not expand cuts or tighten away valid low/quiet notes merely to reach
precision. Native model parity, independent phrase evaluation and saved learning
remain required before the broader WAV goal can advance.

<a id="joint-note-event-checkpoint"></a>
## Joint attack, sustain and release inference — 2026-09-20

This study tests an explicit note-event model over the preceding cached learned
salience. It retains competing pitch identities while selecting attack, sustain,
release and unknown states together. It reuses the same two development excerpts
and exact comparison centers; no expensive model inference or held-out run is
repeated. The hypothesis is that brief octave-confused edges may inherit a pitch
supported by the sustain without deleting genuine short notes or octave changes.

The native decoder has 271 states: five phases for each of MIDI 33..86, plus
unknown. Attack and release may occupy one or two frames each; sustain may continue.
Per-note support is the maximum cached activation within half a semitone, retaining
every supported note. Sustain uses direct support; attack/release may also use
0.2 times support one octave above or below. Log costs have a 1e-8 floor. Unknown
uses one minus maximum note support. RMS at or below 1e-5 forbids pitched states.
These are declared heuristic costs, not calibrated probabilities.

Birth cost is `-ln(0.01)`, reduced to `-ln(0.5)` at the frame nearest a measured
waveform valley. Sustaining across that marked frame adds `-ln(0.01)`; ordinary
sustain self-transition costs `-ln(0.99)`. Valley measurement uses the existing
native default on the exact 30-second excerpt, never reference boundaries.
Admission requires at least three frames, sustain support reaching 0.5, and
sustain RMS-squared/support-weighted tuning within 25 cents. Intervals use the
existing half-hop edges; no reference-based trimming or extra cuts follow.

An initial synthetic control exposed a structural error: a genuine three-frame
octave note became two consecutive notes at the original pitch. The path invented
a same-note release/attack reset and used its octave-tolerant edge states to absorb
the real note. Before recorded scoring, the graph was corrected to require a
waveform cue for direct same-note reattack and to remove its unsupported melodic
distance preference from transcription. Unknown gaps can still separate repeated
notes. The initial policy/source and failing trace remain in the evidence folder;
no emission constant or recorded acceptance threshold was tuned.

The corrected controls pass stable notes, deterministic latent replay, sustained
and three-frame octave changes, a single octave-confused attack, same-note valley
reattack, rest gaps, quiet notes above the energy floor, event detuning rejection,
silence and input bounds. The corrected policy was then evaluated unchanged:

| Development condition | Coverage | Precision | Wrong / octave centers | False-rest pitches | Complete matches / estimates | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute preceding raw learned frames | 80.91% | 86.65% | 173 / 160 | 85 | Not evaluated | Not evaluated | Not evaluated |
| Flute joint events | 85.65% | 87.42% | 142 / 136 | 113 | 72 / 138 | 0.7210 | 0.6180 |
| Violin preceding raw learned frames | 72.01% | 97.35% | 32 / 7 | 17 | Not evaluated | Not evaluated | Not evaluated |
| Violin joint events | 87.92% | 97.00% | 30 / 0 | 38 | 70 / 106 | 0.8718 | 0.7179 |

**Reject adoption of this event policy.** It recovers coverage over the raw learned
frames, but both recordings still fail the required 98% pitch precision. Flute
also misses onset F1 ≥0.80 and full-note F1 ≥0.70. All gates remain per recording;
violin's improvement cannot offset flute's failure. The initial baseline's
qualified temporal/cut path remains a separate comparison, not replaced evidence.

Against that baseline, a paired audit finds flute fixes 11 of 95 wrong centers,
retains 75 identical errors and rejects nine. It loses 73 correct centers, 27 to
wrong labels and 46 to unknown, while adding 79 correct and 40 wrong centers from
previous unknowns. Violin fixes nine of 32 wrong centers, retains five, changes
one wrong label and rejects 17. It loses 87 correct centers, three to wrong labels
and 84 to unknown, while adding 271 correct and 21 wrong centers. Totals reconcile
with independent source/reference-bound frame scoring.

An annotation-based diagnostic explains part of the event failure. Among eligible
flute estimates, 31 directly follow the same pitch with no gap; 29 lack a matching
reference onset. Violin has 19 such reattacks, 15 without an onset match. This model
promotes generic envelope valleys into articulation too readily. Of estimates with
a matching pitch/onset, 12 flute and 15 violin endings are earlier than the allowed
offset tolerance; none are late under that nearest-onset diagnostic. These counts
are descriptive eligibility, not an alternative matching rule or a listening
verdict. Reference labels remain outside inference.

The next boundary hypothesis must distinguish genuine articulation from amplitude
modulation before a valley authorizes a new event, and distinguish quiet sustain
from an ending. The 30-ms octave control remains a protection against explaining
real notes away as edge ambiguity. Register admission is independently unresolved:
75 baseline flute errors retain the same wrong label here. More aggressive cuts
or treating the best path as confidence do not establish correct note identity.

The decoder considers 18641691/18639531 predecessor edges for flute/violin, below
the 20-million bound, and takes 219/203 ms respectively on this checked stable
Win64 run. This is decoder time only; original model measurement cost remains
unchanged. Backpointer/feature storage is preflighted against 16 MiB and 3000 frames.
Final controls, inference, scoring, paired audits and event diagnostics terminate
with zero reported leaks and no compiler warnings. The initial failed control's
exception report is retained separately. No production code, dependency, format,
held-out input, listening verdict or goal completion credit changes.

Evidence is ignored under `build/phrase-joint-events/`. Build `controls`, `infer`,
`score` and `event.diagnostics` with checked stable Win64, `-B -O2 -Sa -Cr -Co -Ci
-gl -gh`, core/tool/study paths and separate `-FU`/`-FE`. Run:

```text
controls
infer SALIENCE_PREFIX ORIGINAL_WAV POLICY.md INFERRED.json
score INFERRED.json ORIGINAL_WAV NOTES POLICY.md SCORE.json
event.diagnostics INFERRED.json SCORE.json NOTES
```

The preceding learned-pitch `paired` audit accepts the new score report and the
same baseline/source/reference arguments. Inference checks cached source/model/
measurement-policy/salience identities and recomputes every input RMS; scoring
checks inference/policy/source identities, interval validity, frame accounting and
the unchanged note-matching protocol. Model numerical fidelity remains unproven
against an upstream runtime and still gates any future dependency adoption.

<a id="learned-pitch-feasibility-checkpoint"></a>
## Native learned-pitch feasibility — 2026-09-20

An isolated Pascal study evaluates retained pitch salience from the official
[CREPE tiny demo model](https://github.com/marl/crepe/tree/de4888e6d448357ceafea10fc6010061c6f19a55).
The [research method](https://arxiv.org/abs/1802.06182) learns monophonic pitch
evidence from waveform input. This study tests a stronger acoustic representation
after local periodicity replacements failed; it does not establish note events,
mixture roles or genre learning.

The demo topology/conversion is pinned at
`de4888e6d448357ceafea10fc6010061c6f19a55`; upstream core/preprocessing references
were inspected at `c9b71ce61491454125a0693f584f7244f29d9884` without executing
their maintenance runtime. Thirteen float32 weight shards total 1,948,384 bytes.
The native loader verifies topology and shard hashes before fixed-shape inference.
The complete upstream MIT notice, copyright 2018 Jong Wook Kim, remains beside
the assets and in derived study code. No maintained dependency, external inference
runtime, submodule, default or saved-style format is added.

Native inference uses six convolution/ReLU/batch-normalization/max-pool stages,
256 flattened values and 360 sigmoid pitch activations. Weights and accumulated
activations are single precision; preprocessing and local weighted pitch decoding
use double precision. Independent convolution geometry, eight sine pitch/phase
controls, positive gain/DC invariance and invalid frame shape pass. Further
diagnostics distinguish weak/missing 220-Hz fundamentals from genuine 440-Hz tones.
Very quiet normalized signals retain high activation, confirming that activation
alone is not admission confidence; the separate input-energy gate remains required.
These controls **do not establish numerical parity with an upstream runtime** or
replace the existing complete analytic note-event protections.

The policy was declared before recorded inference. Both existing Spring
development parts use original mono 16-kHz samples, the first 30 seconds and
1024-sample windows centered at `294 + 160*i`, for 2997 windows. These are the
baseline's exact timestamps; zero padding applies only at excerpt edges. Each
source-bound artifact retains all 360 activations and input AC RMS. Measurement
does not read reference labels. The fixed diagnostic admits local nine-bin
weighted pitch only when RMS is greater than 1e-5, maximum activation at least
0.5, frequency 55..1200 Hz and nearest-MIDI tuning within 25 cents.

| Development recording | Correct / active centers | Coverage | Precision | Wrong / octave centers | False pitches in reference rests | Unknown active centers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute | 1674 / 2069 | 80.91% | 86.65% | 173 / 160 | 85 | 222 |
| Violin | 1801 / 2501 | 72.01% | 97.35% | 32 / 7 | 17 | 668 |

**Reject this native model plus fixed frame policy as an admission replacement.**
Neither recording clears both coverage ≥80% and precision ≥98%. No threshold
sweep, range adjustment or held-out evaluation follows. These are raw frame
results, not a controlled estimator-only comparison against the baseline's
temporal decoder and qualified event cuts. They neither rule out other learned
methods nor supply onset/full-note F1 or a phrase acceptance verdict.

A paired native audit compares the final baseline's admitted labels at the same
centers. Flute fixes seven of 95 baseline wrong centers, retains the same wrong
label at 74 and changes two to another wrong label; twelve become unknown.
It loses 149 baseline correct centers: 58 become wrong and 91 unknown. Sixty-one
previously unknown centers become correct and 39 wrong. Violin fixes two of 32
baseline errors, retains seven and rejects 23, while losing 385 correct centers
to unknown. It adds 178 correct and 25 wrong centers from baseline unknowns.
These counts reconcile with the independently recomputed frame totals.

Of the new flute errors, 133/173 wrong pitches and 79/85 false-rest pitches lie
within 50 ms of a reference onset or offset; violin counts are 28/32 and 17/17.
This is descriptive localization only: no center is removed from acceptance and
reference boundaries never enter inference. Forty wrong flute centers also lie
outside that band, so boundary trimming alone cannot establish register accuracy.

Checked stable FPC 3.2.2 Win64 measurement takes 506812 ms for flute and 505515 ms
for violin, each analyzing 30 seconds while the two processes run concurrently.
That is roughly 17 processing seconds per audio second on this machine, not a
portable throughput promise. Each batch has a conservative 110266583040
multiply-add bound against the declared 120000000000 limit. Long-corpus use needs
a measured throughput/memory plan; this scalar path is not accepted for many hours.

All final study builds have no warnings; controls, measurements, scoring and paired
audits are terminal with zero reported leaks. The scorer verifies completion,
model/policy/source/salience identities, every timestamp, finite score ranges and
independently recomputed input RMS. Reference timing retains the existing 8-kHz
floor-onset/ceil-end policy and excludes ambiguous overlaps. Precision includes
admitted pitches in reference rests. No held-out recording or listening verdict
is used. Policy, model assets/notices, Pascal sources, raw salience, reports and
terminal logs remain under ignored `build/phrase-learned-pitch/`.

Build `controls`, `measure`, `score`, `paired` and `stress` with
`-B -O2 -Sa -Cr -Co -Ci -gl -gh`, core/tools/study include paths and separate
`-FU`/`-FE` directories. Run `measure ORIGINAL_WAV MODEL_DIR POLICY.md PREFIX`,
then `score PREFIX ORIGINAL_WAV NOTES POLICY.md SCORE.json` and
`paired BASELINE_REPORT SCORE.json NOTES ORIGINAL_WAV`. Measurement and scoring
refuse existing outputs; incomplete raw files without final metadata are not
accepted. `controls MODEL_DIR` and `stress MODEL_DIR` exercise the native controls.

The next [register decision](MILESTONES.md#wav-03-register) must distinguish a
numerically faithful evidence provider from the joint attack/sustain/ending model
that consumes it. Retained salience permits investigation without another costly
measurement run, but a new joint policy needs declared counterexamples and the
unchanged recorded gates. Upstream numerical fidelity and resource cost remain
additional requirements before any model adoption. This checkpoint establishes
native feasibility and rejects the tested admission shortcut; it earns no new
musical acceptance or completion credit.

<a id="normalized-correlation-checkpoint"></a>
## Independent normalized-correlation comparison — 2026-09-20

The next recorded comparison replaces candidate measurement with an independently
authored direct-summation estimator based on [McLeod and Wyvill's method](https://www.cs.otago.ac.nz/graphics/Geoff/tartini/papers/A_Smarter_Way_to_Find_Pitch.pdf).
It normalizes autocorrelation by the energy of both overlapping sides, finds one
maximum per positive lobe after the zero-lag lobe, and interpolates peak position
and height. The first near-maximal peak represents the proposed period. This
tests a different acoustic representation where earlier threshold candidates
lacked the intended pitch; it does not reproduce the complete Tartini application.

The predeclared study keeps the same floating-point 8-kHz excerpts, 294-frame
windows, 80-frame hops and 55..1200-Hz range. It removes window DC and uses the
full decreasing overlap. Fixed study choices are a 0.93 relative peak cutoff and
0.8 minimum clarity. The selected note receives its clamped clarity as a decoder
score; unknown receives the complement. These are heuristic emissions, not
calibrated probabilities. Existing temporal transitions, event tuning, minimum
run, qualified cuts and scoring remain fixed. References enter evaluation only.

All twelve existing analytic controls pass, including quiet/weak fundamentals,
missing fundamentals, a dominant second harmonic, genuine octave changes, vibrato,
silence, detuning rejection and repeated articulation. Recorded acceptance fails:

| Qualified-cut condition | Coverage | Precision | Wrong / octave centers | Complete matches / estimates | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute baseline | 84.82% | 93.90% | 95 / 84 | 81 / 102 | 0.8325 | 0.8223 |
| Flute normalized correlation | 86.08% | 90.73% | 127 / 124 | 80 / 118 | 0.7606 | 0.7512 |
| Violin baseline | 80.21% | 98.38% | 32 / 0 | 75 / 89 | 0.9101 | 0.8427 |
| Violin normalized correlation | 76.97% | 97.12% | 51 / 15 | 59 / 107 | 0.8061 | 0.6020 |

**Reject adoption of this estimator/emission policy.** Neither recording clears
all four gates. The local and uncut temporal conditions also fail; no cutoff sweep
or range adjustment follows this result.

A paired native audit confirms original/reference identities and exact equality
of every report field outside the candidate study. Of the baseline's 95 wrong
flute centers, only 12 become correct, 76 retain the same wrong note and seven
become unknown. Thirty previously correct centers become wrong and 26 become
unknown. Violin fixes one of 32 wrong centers, retains 24 identical errors, changes
one to a different error and rejects six; it loses 165 previously correct centers,
157 of them to unknown. Additional previously unknown centers explain the complete
new totals; the categories reconcile with independently audited frame scores.

Agreement between the two complete inferred paths is insufficient too. Its
diagnostic flute coverage/precision is 82.12%/94.97%; violin is 73.61%/98.71%.
This is a frame-level diagnostic, not an implemented ensemble or a note-boundary
verdict. Agreement still retains 76 wrong flute centers, while discarding useful
violin evidence. Do not promote agreement into a confidence rule.

Independent audits reproduce score totals, event tuning and complete-match
eligibility. Checked stable Win64 runs are terminal, with no compiler warnings
and zero reported leaks. Each recording has 2997 windows and a conservative
130405464 direct correlation-term bound, below 268435456. Policy, Pascal sources,
reports, diagnostic WAVs, logs and hashes remain ignored under `build/phrase-nsdf/`.
Build `candidate.controls.lpr`, `periodicity.lpr`, `audit.lpr` and `paired.lpr`
with checked flags, core/tool paths and the study path; unchanged boundary helpers
come from `build/phrase-centered-candidates/`. Run the two existing source/reference
pairs with `PREFIX 0 30`. `paired BASE_REPORT NEW_REPORT NOTES ORIGINAL_WAV`
checks the comparison; the preceding `note.changes` audit checks note eligibility.

This rules out this local estimator replacement and simple agreement as solutions
to the remaining admission gate. The next [register decision](MILESTONES.md#wav-03-register)
needs an explicit joint note-event hypothesis retaining attack/sustain register
alternatives and genuine short lower notes, with unknowns where the acoustic
evidence cannot decide. A different scalar periodicity score alone has not supplied
that distinction. No maintained inference/default/format, held-out evaluation,
saved-style admission, listening verdict or completion credit changes.

<a id="spectral-register-checkpoint"></a>
## Independent spectral register ranking — 2026-09-20

The next probe adds an acoustic comparison instead of masking conflicting
windows or rejecting complete events. Pitch-class grouping alone cannot cover
the existing failure set: some wrong-register events have no later admitted
segment at the intended octave, while genuine octave changes must remain distinct.

The diagnostic is inspired by the harmonic peak/gap comparison in
[Camacho and Harris's SWIPE work](https://scholarsmine.mst.edu/ele_comeng_facwork/7041/).
It is an independently authored, simplified spectral comparison, **not an
implementation or evaluation of the full published method**. No external code is
copied. The following fixed geometry, weighting and scope are prototype choices.

At each unchanged admitted window center, measure the event's inferred pitch
including its mean cents, plus the neighboring octaves inside 55..1200 Hz.
Each alternative uses eight of its own periods, DC removal, a symmetric Hann
window and a native FFT padded to a power of two at least four times that length.
Missing edge support or AC RMS at most 1e-5 remains unmeasured. A cosine kernel
rewards first/prime-harmonic peaks and penalizes intervening gaps; side negative
lobes have half weight, with inverse-square-root frequency decay. Compare it
with square-root spectral magnitude, normalized by spectrum and positive-kernel
L2 norms. This uses uniform Hz bins, no ERB remapping, no multi-window interpolation,
no pitch refinement and no admission cutoff. Scores are not probabilities.

The policy was recorded before execution. Seven controls pass: six rank the correct
register for sine, missing fundamental with harmonics two/three, weak fundamental
with a stronger second harmonic, quiet sine, a genuine upper-octave sine and DC
offset; silence remains unmeasured. These are stationary acoustic controls, not
proof of correct attack or short-note interpretation.

| Baseline-admitted centers / ranked alternatives | Flute | Violin |
| --- | ---: | ---: |
| Previously correct; rank remains correct | 1658 | 2006 |
| Previously correct; another octave ranks higher | 97 | 0 |
| Previously wrong; intended note now ranks highest | 3 | 0 |
| Previously wrong; same wrong note ranks highest | 91 | 32 |
| Previously wrong; a different wrong octave ranks highest | 1 | 0 |
| Newly correct rankings lacking the original candidate | 0 | 0 |
| Unmeasured among those active centers | 0 | 0 |
| Reference-rest centers, excluded from register accuracy | 19 | 1 |

**Do not use the winning spectral rank to relabel notes.** The flute tradeoff is
strongly adverse; violin has no gain. For example, wrong flute event 1 favors
the intended 76 over 64 at window 215 (scores 0.5546 versus 0.4665), but correct
event 3 at window 277 favors 64 over its correct 76 (0.4131 versus 0.3484).
The three recovered rankings all already had reference-candidate support in the
original measurement. This probe does not solve the absent-candidate cases.
It also says nothing about how a faithful full SWIPE implementation would perform.

The measurement program reads only the source and the baseline report. It
reconstructs the original floating-point excerpt, verifies source identity and
the baseline's encoded-excerpt hash, and saves all three scores and availability
flags per admitted center. A separate native audit binds the source, baseline
report and reference hashes, verifies frame/event coordinates and alternatives,
and compares rankings with the annotations. References never enter measurement.
No baseline labels, boundaries, tuning, unknown regions or note scores change.

Checked stable Win64 controls, measurement and audit runs are terminal without
compiler warnings. The 1869 flute / 2039 violin measured centers require
82308670 / 107117802 conservative work units, below the declared 268435456 cap.
Policy, native sources, reports, audits and hash ledger remain ignored under
`build/phrase-spectral-register/`. Held-out recordings remain unused.

This adds recorded counterexamples to WAV-03-REGISTER rather than an admission
rule. Next distinguish attack-local register evidence from the musical event's
continuation/context, including fully wrong-register events that have no correct
admitted continuation. Preserve genuine short lower notes and weak fundamentals;
do not simply prefer the octave common elsewhere in the recording. Neither
periodic nor this spectral score alone supplies the missing musical decision.

<a id="candidate-likelihood-checkpoint"></a>
## Candidate likelihood and octave-conflict rejection — 2026-09-20

The centered qualified-cut baseline's wrong flute centers split into three
acoustic cases: the annotated note has greater candidate mass than the selected
note at 11 centers, weaker/equal positive mass at 43, and no candidate mass at
41. Of the 41 interior errors, eight have stronger reference mass, 25 have
weaker/equal mass and eight have none. All 32 wrong violin centers are near note
boundaries and lack the annotated candidate. These annotations are used only
by the independent audit; they do not enter measurement or decoding. Candidate
mass is model support, not calibrated correctness probability.

A predeclared admission experiment then tested a specific uncertainty rule.
Within an otherwise eligible decoded event, if the same competing octave wins
the local maximum-mass comparison for at least the existing three-window minimum
run, reject the whole event as unknown. Unknown or a different winning label
breaks that competing run. No octave is substituted, tuning limits are unchanged
and no threshold sweep is performed. Raw centered candidates, temporal decoding
and qualified cuts remain the baseline's inputs.

The twelve existing analytic controls pass, preserving weak/missing fundamentals,
quiet notes, genuine octave changes, vibrato, tuning and articulation behavior.
None activates the new rejection, so those passes establish preservation only;
they do not establish useful discrimination on recorded conflicts.

| Part / qualified-cut condition | Coverage | Precision | Wrong / octave centers | Complete matches / eligible estimates | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute, baseline | 84.82% | 93.90% | 95 / 84 | 81 / 102 | 0.8325 | 0.8223 |
| Flute, whole-event rejection | 81.97% | 95.23% | 66 / 55 | 79 / 98 | 0.8290 | 0.8187 |
| Violin, baseline | 80.21% | 98.38% | 32 / 0 | 75 / 89 | 0.9101 | 0.8427 |
| Violin, whole-event rejection | 74.41% | 98.26% | 32 / 0 | 73 / 87 | 0.8977 | 0.8295 |

**Reject this admission policy.** Flute still misses 98% precision; violin loses
its required 80% coverage. In flute, four removed events contain 59 correct and
29 wrong audited centers. Two of those events are entirely wrong-register
(15 and 14 centers); the other two are entirely correct (54 and five centers).
Only three local conflicting centers erase the correct 54-center event. In
violin, two removed events contain 72 and 73 correct centers and no wrong ones;
their local conflicts affect only ten and twelve centers. Whole-event rejection
therefore converts brief competition into much larger coverage loss. False-rest
counts stay 19 for flute and one for violin.

A new native paired audit checks source/reference identities, every top-level
measurement field and all 2997 raw candidate frames per recording. They are
unchanged. Every retained event has identical note, boundaries and mean tuning;
only complete events are removed. The independent interval/tuning audit also
reproduces the reported counts. The independent-candidate condition changes no
events; the uncut temporal condition has the same coverage tradeoff. These checks
rule out changed input or measurement as the cause of this regression.

The result narrows the next register decision: a short competing run cannot veto
an entire event, and changing temporal preferences cannot select an absent
candidate. Next investigate attack/continuation-local register hypotheses that
retain raw alternatives and limit unknowns to the supported uncertain interval.
The required counterexamples now include these fully correct recorded events,
alongside genuine short octave notes and weak/missing-fundamental controls.
Do not select a competing-run fraction from the successful/failed events above;
that would be another fitted cutoff, not independent admission evidence.

Checked stable Win64 likelihood, control, inference and audit runs are terminal.
Ignored evidence is under `build/phrase-candidate-likelihood/`, with the rejection
prototype, declared policy, reports and paired audits in `competition/`.
`compare BEFORE AFTER REFERENCES` verifies unchanged evidence and lists dropped
events; the existing `audit REPORT REFERENCES` verifies scores and tuning.
Source/result hash ledgers bind the checkpoint. No maintained inference code,
default, saved format or held-out input changed. Register and phrase acceptance
remain open; this rejected policy earns no milestone credit.

<a id="even-harmonic-phase-checkpoint"></a>
## Waveform phase from an even harmonic — 2026-09-20

This probe refines the preceding candidate-frequency phase using the waveform's
second harmonic. It fits only the second/fourth harmonics plus DC in each unchanged
analysis window, using twice the candidate phase and the native two-harmonic
fitter. The second-harmonic coefficient power divided by twice measured AC RMS
squared must be at least 0.01 in every fitted window. This predeclared availability
guard is not calibrated confidence, and its ratio is not a bounded physical-energy
fraction. Missing support remains unmeasured.

Subtract the candidate-phase origin from the fitted second-harmonic angle,
unwrap successive residual angles using the nearest full-turn branch, and divide
by `4*pi` to obtain a fundamental-cycle correction. Interpolate corrections
between window centers and hold at the fitted edges; remove the initial correction
so the path starts at zero. The native phase fitter validates the corrected path
and unchanged four-harmonic windows. Retain every correction and support knot.
Corrections beyond the final fitted center are held, not separately measured.

Odd harmonics do not choose this correction; subsequent odd coherence is the main
diagnostic. The components still come from the same audio, with finite-window
leakage and shared noise. This is not statistically independent validation, and
better even coherence is partly fitted by design. A second harmonic need not keep
the same musical identity through a real note change.

Seven controls pass before recorded measurement. Refinement improves odd coherence
from 0.0400 to 0.9986 for a detuned weak fundamental with a stronger second harmonic,
and from 0.6504 to 0.9991 for vibrato. The quiet detuned control retains the same
result. An absent second harmonic rejects. A real octave transition remains near
0.625, and an amplitude ramp near 0.751; neither is made fully coherent. Even the
stationary control changes slightly from 1 to 0.99997, showing that this operation
is not automatically beneficial. Earlier phase-integration/harmonic controls pass.

| Development input | Retained / measurable events | Lower / higher fit error than candidate phase | Higher / lower odd coherence | Conservative work bound |
| --- | ---: | ---: | ---: | ---: |
| Spring flute | 103 / 47 | 24 / 23 | 15 / 32 | 60652800 |
| Spring violin | 90 / 65 | 53 / 12 | 51 / 14 | 73249920 |

Pairs use only events measurable under this policy; these counts cannot be
compared as success rates against the preceding larger measurable set. Flute has
52 insufficient-reference events and four previously unsupported window geometries.
Violin has 20 insufficient-reference events, two candidate-phase four-cycle failures
and three previously unsupported geometries. The reference guard is unchanged.
Work reserves four four-harmonic-fit equivalents per geometrically eligible event,
conservatively covering the additional two-harmonic fit, below 268435456.

The result supports conditional phase modeling. For example, violin event 18's
odd coherence rises from 0.0216 to 0.8329 over ten fit windows; all 21 audited
centers are correct. But register counterexamples remain: flute event 58 has four
wrong-octave audited centers and coherence 0.8113 over two windows, while event 77
has 16 correct centers and coherence 0.7181 over eight windows. Correct violin
event 61 remains at 0.3018 over its first sixteen windows. No cutoff follows from
these examples, and unsupported reference components are not rejected notes.

The separate source/report/reference-bound audit retains exactly the preceding
pitch counts and all event labels/boundaries. No note edits, threshold sweep,
held-out use, maintained-library changes or new artifact format are involved.
Checked stable Win64 measurement/audit runs are terminal with no compiler warnings.
Policy, native sources, correction knots, paired JSON, hashes and logs are ignored
under `build/phrase-even-phase/`.

Keep this conditional phase evidence with [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre).
The next [register investigation](MILESTONES.md#wav-03-register) should examine
acoustic candidate likelihood and temporal/attack support, retaining genuine
octave changes and quiet notes. Further unconditional coherence-threshold searches
are unsupported by these probes. Register work need not wait for a general
automatic phase provider; their acceptance claims remain distinct.

<a id="changing-phase-checkpoint"></a>
## Candidate-frequency phase integration — 2026-09-20

The changing-phase probe tests the next hypothesis: integrate the existing
candidate frequencies before comparing harmonic consistency. It retains every
qualified-cut event from centered condition 2, including its note and boundaries.
For each event, use that exact note's measured frequency at each analysis-window
center. Require at least two knots, no missing candidate, no gap over two hops,
and endpoint holds no longer than one hop. Interpolate frequency linearly and
integrate with the trapezoidal rule at source-sample positions, starting at zero
cycles. Exact frequency knots are retained; annotations do not enter measurement.

Use exactly the preceding fixed-frequency probe's nonoverlapping windows and
four harmonics. Fit once at the event's fixed frequency and once along the
estimated phase; rotate coefficients to their respective event origins. Existing
cycle, rank, work and sampling bounds remain in force. This estimates a phase
hypothesis from periodic measurements; it does not measure absolute acoustic
phase or calibrate the correct register.

Constant/glide knot integration and missing/gapped/excessively held support
controls pass. The preceding eight signal controls also pass: known phase restores
odd coherence to 1 for vibrato and a continuous real octave transition; amplitude
ramps remain about 0.7518. A pure second harmonic has negligible odd power, so its
numerical odd coherence has no register meaning. These controls distinguish the
phase integrator/fitter from the quality of inferred recording frequencies.

| Development input | Retained / measurable events | Lower / higher fit error with estimated phase | Higher / lower odd coherence | Conservative fit-work bound |
| --- | ---: | ---: | ---: | ---: |
| Spring flute | 103 / 99 | 91 / 8 | 88 / 11 | 30326400 |
| Spring violin | 90 / 85 | 66 / 19 | 59 / 26 | 36624960 |

Fit error here is mean squared relative error across the same windows, not pitch
accuracy. Work conservatively charges both fits for each geometrically eligible
event and stays below 268435456. Two additional violin events (21 and 44) lack
four integrated cycles in at least one unchanged window. They remain unmeasured;
the probe does not lengthen their windows to improve the result.

The phase hypothesis improves some important correct-note cases. Flute event 7
changes odd coherence from 0.1370 to 0.8003 and squared relative fit error from
0.06274 to 0.00714. Nevertheless, register classes still overlap: flute event 58
has four wrong-octave audited centers and coherence 0.8890 over two fit windows.
All 77 audited centers in flute event 79 are correct, yet its first sixteen fit
windows yield 0.2626. Violin event 18 has 21 correct audited centers and coherence
0.0216 over ten fit windows. Correct violin event 4
even drops from 0.2516 to 0.0651 while its fit error improves. Thus improved local
reconstruction does not establish stable inter-window phase or the right octave.

A separate source/report/reference-bound audit confirms unchanged admitted
frame counts: flute 1755 correct / 95 wrong / 84 downward-octave / 19 false-rest;
violin 2006 / 32 / 0 / 1. No notes are edited or admitted, no cutoff is selected,
and held-out recordings remain unused. Integration of candidate frequency is a
useful diagnostic, but its uncertainty, evolving harmonic shape and short-event
support still need separation before register or timbre admission. Preserve the
paired baseline rather than treating estimated phase as automatically better.

Evidence is ignored under `build/phrase-changing-phase/`: predeclared policy,
native measurement/integration/audit sources, exact knots, paired JSON, hash
ledger and terminal logs. Checked stable Win64 measurement and audits have no
compiler warnings. Maintained library behavior and saved artifact formats are
unchanged; this is development evidence, not a broader accuracy claim.

<a id="harmonic-coherence-checkpoint"></a>
## Short-window harmonic coherence — 2026-09-20

The next register probe tests whether odd-harmonic phase consistency separates
an incorrectly low octave from a true lower note. Policy was recorded before
measurement. It consumes the centered candidate reports' qualified-cut condition,
using each inferred note plus its mean cents; annotations enter a separate audit
only. Source, recreated excerpt, candidate report and reference hashes are checked.

Four harmonics are fitted in consecutive nonoverlapping windows from each event
start. Width is `max(160, ceil(4 × rate / frequency) + 1)` frames at 8 kHz; require
two complete windows and cap at sixteen. The sine/cosine coefficients are rotated
to the event origin before computing separate odd/even coherence: squared magnitude
of the summed coefficients divided by window count times summed coefficient power.
Odd coefficient-power share and mean squared relative fit error are also retained.
These are diagnostics, not calibrated probabilities or physical energy fractions;
coherence of a numerically negligible component has no useful pitch meaning.

Eight analytic controls pass their declared stationary-identity or finite/bounded
checks. True weak fundamentals, missing fundamentals and quiet stationary tones
retain odd coherence 1. A 35-cent, 5-Hz vibrato control yields 0.6655, an amplitude
ramp 0.7518, and a real octave transition inside the measured interval 0.5000.
Those varied controls explicitly show that coherence need not be 1 for valid
musical behavior.

| Development input | Inferred events / measurable events | Fit work | Unchanged correct / wrong / downward-octave / false-rest centers |
| --- | ---: | ---: | --- |
| Spring flute | 103 / 99 | 15163200 | 1755 / 95 / 84 / 19 |
| Spring violin | 90 / 87 | 18312480 | 2006 / 32 / 0 / 1 |

Counts include inferred events before note-score edge exclusion. Short events or
unavailable harmonic scope remain explicitly unmeasured. Both work totals remain
below 268435456. The independent interval/reference audit reproduces the prior
frame counts; no notes, windows or scores were changed by this measurement.

The evidence rejects a simple coherence cutoff. Wrong-octave flute events 1 and 2
have odd coherence 0.1897 and 0.4237, but event 6 is also entirely wrong and reaches
0.7674 with only two windows. Correct flute event 7 has coherence 0.1370 over the
first sixteen windows; all 94 admitted centers in its full event are correct.
Correct violin event 11 likewise reaches only 0.0776 while its 73 admitted centers
are correct. Thus both error and correct-note cases span low and high coherence;
fixed event frequency, changing phase and available window count matter.

Do not promote this scalar into pitch doubling, rejection or candidate weighting.
Further [register work](MILESTONES.md#wav-03-register) needs event/attack context
and evidence that distinguishes frequency drift and short transients from competing
registers. [Boundary work](MILESTONES.md#wav-03-boundaries) remains independently
ready; both still gate phrase freeze. Held-out recordings remain unused.

Evidence is ignored under `build/phrase-harmonic-coherence/`: `POLICY.md`, native
`coherence.lpr` / `audit.lpr`, controls, source-bound JSON and per-event audit logs.
Checked stable Win64 builds use `-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools` with local
unit/output directories. Run `coherence CANDIDATE_REPORT ORIGINAL_WAV OUTPUT_JSON`,
then `audit CANDIDATE_REPORT REFERENCE_NOTES OUTPUT_JSON`. All runs are terminal.
No maintained implementation/default, new audition, listening verdict, held-out
admission or completion credit is claimed.

## First evaluation protocol — declared before measurements

Use genuine multi-note URMP recordings with the accompanying audio-aligned note
annotations. The [official documentation](https://labsites.rochester.edu/air/projects/URMP/URMP_doc.pdf)
defines note rows as onset seconds, frequency Hz and duration seconds. Its MIDI
files are musical scores, not a substitute for recorded timing. Attribution:
Bochen Li, Xinzhao Liu, Karthik Dinesh, Zhiyao Duan and Gaurav Sharma,
"Creating a multi-track classical music performance dataset for multi-modal music
analysis: Challenges, insights, and applications", IEEE Transactions on Multimedia,
2018. [Official project](https://labsites.rochester.edu/air/projects/URMP.html).

Acquire only selected audio/annotation files from the public YourMT3 16-kHz
preparation mirrored in `J1mmymm/MIMuT_Data_v2`, revision
`3a62b3a1c8bb263a6a6ac37559070339ddb81080`. Record exact SHA256 identities and
preparation provenance. The original URMP sample download currently returns 404.
Keep external recordings and annotations under ignored build output; they are
evaluation inputs, not files in Pythian's MIT source packages.

- Development: first 30 seconds of `08_Spring_fl_vn`, separate flute and violin.
- Held out for the selected policy: first 30 seconds of `03_Dance_fl_cl`, separate
  flute and clarinet. Do not use these outcomes to select thresholds or fixes.
- Measure mono channel 0 after native resampling to 8000 Hz. Primary policy is
  the existing default pitch range 55..1200 Hz, difference threshold 0.1,
  silence RMS 0.00001, 10-ms hop, three-window minimum run, 25-cent admission,
  and default analysis width. The previously available 110-ms width is a declared
  diagnostic comparison, not a license to choose the better held-out result.
- Retain rejected short runs, unknown pitch and silence as distinct outcomes.
  Frame metrics use stable span labels at measured window centers. Reference
  overlap is ambiguous and reported separately; reference pitch outside the
  supported range remains visible in coverage rather than being discarded.
- Target at least 80% correct coverage of unambiguous reference-active centers
  and at least 98% precision among admitted pitch centers. Report reference rests,
  false pitches, wrong pitches and unknowns separately. These are acceptance
  targets, not promised current accuracy.
- For note events, use exact semitone identity, onset error at most 50 ms and
  offset error at most the larger of 50 ms or 20% of reference duration.
  Report onset-only and onset-plus-offset precision/recall/F1 separately, using
  maximum ordered one-to-one matching. Targets are onset F1 >= 0.80 and full-note
  F1 >= 0.70. Use a common 110-ms excerpt-edge exclusion for note scoring.

These recordings are supplied as isolated parts. Their names establish declared
instrument roles; this does not test discovery of voices in a mixed recording.
Repeated same-pitch notes, held notes and rests must remain visible in the result.
Do not extend a finite learned WFC path by repeating an excerpt merely to satisfy
a requested output length. Reassess the remaining voice/phrase milestone from
the observed errors before awarding its points.

## Native evaluation and repeatable workflow

[pythian.pitch.evaluate](../src/pythian.pitch.evaluate.pas) evaluates a borrowed,
immutable pitch track against sorted absolute reference-note intervals at the
track's sample rate. It uses the track's stable span labels, retaining rejected
short runs as unknown even though the raw candidate remains available. It reports
reference-active/rest/ambiguous centers, correct and wrong pitch, octave errors,
false pitch in rests, and active unknowns caused by no period, frequency range,
tuning/MIDI admission or short-run filtering. Octave errors are a subset of wrong
pitch; unknown causes partition active unknowns. Note matching uses two bounded
dynamic-programming rows and separates onset-only from onset-plus-offset matches.
Error sums cover the onset-only matched pairs, including their failed offsets.

Limits are 4096 reference notes, 16777216 window/reference or note-matching pairs,
and absolute coordinates no larger than 2^53-1 frames. References outside the
frequency range remain in coverage. Empty reference sets count every admitted
pitch as false; ratios with zero denominators report zero. Both reference and
estimated notes must lie wholly inside the common note-scoring edge exclusion.

The [native operator](../tools/pythian.phrase.wav.lpr) reads aligned note rows,
fingerprints both inputs, extracts and resamples one declared mono region, then
measures and evaluates it without supplying reference notes to the estimator:

```text
pythian.phrase.wav SOURCE.wav NOTES.txt OUTPUT_PREFIX START_SECONDS LENGTH_SECONDS [WINDOW_FRAMES] [--region-study]
```

It writes a JSON report, a PCM16 source excerpt and a sine audition of stable
estimated runs. That audition is diagnostic resynthesis. Successful execution
can report `meets_declared_targets: false`; command success is not quality
admission. Invalid references or output/input collisions reject before output
writing. Publication of the output files is not a transaction against physical I/O
failures.

The optional [recorded workflow](../tools/recorded-phrases.ps1) pins the selected
assets and their SHA256 hashes, compiles the evaluator without companion search
paths, runs the native scoring checks, and evaluates both declared window widths:

```powershell
./tools/recorded-phrases.ps1 -Compiler fpc
```

Its default set is `Development`. `-EvaluationSet HeldOut` is available for the
fixed-policy evaluation checkpoint; keep it unused while selecting development
changes. The script delegates all audio, parsing, scoring and learning to Pascal.
The ordinary build compiles the evaluator and runs scoring checks without acquiring
external recordings.

For development recordings, the workflow also invokes the existing companion
duration learner and saved-model generator. This learning consumes the encoded
PCM16 excerpt and records its hash; evaluation measures the floating-point
resampled excerpt before that encoding. These are explicitly different sample
representations and can have slightly different admission near boundaries.
Generated eight-span fragments preserve measured unknown/silent tokens under the
existing output policy; velocity and timbre are authored. They demonstrate actual
saved WFC generation, not completion of dependent context/part style integration.

## Development baseline — 2026-09-15

All four cases fail at least one predeclared target. No estimator, admission
threshold, window choice or acceptance target was tuned in this checkpoint.
The held-out Dance recordings have not been evaluated.

| Development part / window | Pitch coverage | Pitch precision | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: |
| Spring flute / default 294 frames | 77.57% | 92.19% | 0.6812 | 0.6114 |
| Spring flute / diagnostic 880 frames | 75.62% | 85.13% | 0.6422 | 0.5963 |
| Spring violin / default 294 frames | 71.69% | 99.61% | 0.7246 | 0.5217 |
| Spring violin / diagnostic 880 frames | 72.48% | 96.17% | 0.5813 | 0.4729 |

Default flute scoring finds 116 wrong active pitch windows, all octave errors,
plus 20 false pitches in reference rests. Its 348 active unknown windows comprise
156 no-period, 136 tuning/admission and 56 short-run rejections. Default violin
has four wrong active windows (three octave errors), three false pitches in rests
and 704 active unknowns: 304 no-period, 349 tuning/admission and 51 short-run
rejections. Neither case has a reference-active silence classification or an
outside-frequency-range unknown. These are window counts, not distinct notes.

There are 95 eligible flute reference notes and 134 estimated runs; 78 onsets and
70 complete notes match. Violin has 89 reference notes and 118 estimated runs;
75 onsets and 54 complete notes match. This exposes missing coverage and note
fragmentation/boundary errors alongside octave ambiguity. Longer integration
reduces onset and full-note F1 on both parts; it is not a general phrase fix.

The encoded excerpts learn 135 flute pitch runs within 245 total spans and 119
violin runs within 238 spans. Their saved models generate five and four audible
notes respectively in eight-span diagnostic fragments, with SHA256 WAV identities
`bd277c1d6b6130af1f9fec9b1dbc889e9fa14549a3acf1644e2c8aafdf0ba62d` and
`7490069d76654dce6efbc830a873e28f07f5e7f903227ae61603b012d612e3ec`.
These short results did not resolve the separate 32-span style-provider rejection.
The later [scope checkpoint](WAV-STUDIES.md#duration-scope-checkpoint) identifies
that isolated-note model's finite prefix, verifies a supported 32-span second
blend and repairs monophonic release spill. It does not clear phrase-quality admission.

Evidence is under `build/recorded-phrases-{compiler}-{cpu}-{os}/`, with orchestration
and replay summaries under `build/phrase-evaluation-{stable,trunk,win64}/`.
Checked stable/development Win32 and stable Win64 pass scoring and the development
workflow. Cross-target comparison caught Single intermediate arithmetic in the new
F1 helper on Win64; explicit Double intermediates fix it, with a regression oracle.
Raw learner window measurements may differ by floating-point rounding; discrete
admissions, learned models and rendered audio are checked separately.
All evaluation reports, WAVs and saved model text replay byte-for-byte across
the three targets (38 exact artifact comparisons including other identical JSON).
The two Win64 raw learner reports differ only in floating measurements, by at
most 1.43e-12 absolute; a native comparison confirms identical discrete evidence.
Output/input collision and malformed-reference requests preserve accepted outputs.
The full ordinary build, refreshed packages and remote CI were not run here.

Next address the demonstrated octave ambiguity and fragmentation using development
evidence and controlled counterexamples. Preserve uncertainty and reference-free
estimation; do not merely relax tuning thresholds to increase coverage. Then
freeze the revised policy and use held-out recordings for the declared acceptance
decision. No phrase milestone points are earned by this baseline.

## Musical note regions — 2026-09-15

The octave investigation distinguishes physical periodicity from a musical event.
For example, flute window 211 (8-kHz excerpt, 80-frame hop) estimates about
332.03 Hz while the annotated note is near 663 Hz. The normalized difference
minimum near lag 24 is 0.00848, versus 0.20105 near lag 12. The lower periodic
component is present during the attack; doubling all such measurements would
also corrupt genuine lower notes. The raw estimator remains unchanged.
The [YIN method](https://www.ee.columbia.edu/~dpwe/papers/deChevK02-yin.pdf)
provides the periodic-signal basis; musical event interpretation needs additional
temporal evidence rather than treating its periodicity score as note certainty.

Two existing mechanisms were examined before adding inference. Default onset
localization finds 365/341 candidates and 332/314 resolved rises on the encoded
flute/violin excerpts, far above the 95/89 eligible reference notes. Harmonic
preprocessing with a 256-frame window, 64-frame hop, seven-frame temporal median
and 17-bin frequency median gives full-note F1 of 0.5858/0.4883, below the raw
baseline. It is not adopted as a phrase repair. Evidence is in
`build/phrase-octaves/`, including native periodicity diagnostics and separation
reports. These are development investigations, not another held-out evaluation.

The [region summary](PITCH.md#musical-note-hypotheses-within-regions) now combines
energy support and tuning within explicit candidate events, preserving raw
measurements and all competing note votes. `EvaluatePitchNoteIntervals` scores
those independent hypotheses with the same ordered matching, edge exclusion and
tolerances as the raw-track evaluation; it does not manufacture raw estimates.

```powershell
./tools/recorded-phrases.ps1 -Compiler fpc -RegionStudy
```

The maintained optional workflow appends `-regions` to its output prefixes. Each
report includes the following two baseline study conditions and all detector options.
The subsequent [ending study](#support-bin-endings--2026-09-15) adds a third condition:

- **Reference-boundary diagnostic:** use the annotated intervals to isolate the
  within-event inference question. No reference pitch enters the inference.
  Five overlapping reference intervals per part are skipped as region inputs
  because the summary requires nonoverlap; all eligible references remain in
  scoring. This condition is not end-to-end accuracy or style-learning evidence.
- **Detected-onset regions:** use existing native analysis, onset localization
  and event planning. No reference boundaries enter inference. The current
  detector supplies 303 flute and 305 violin intervals. These intervals include
  excess detections and do not establish physical note offsets.

Default 294-frame pitch-window results, with the original acceptance tolerances:

| Part / inference condition | Estimated notes | Matched onsets | Matched full notes | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flute / raw stable runs | 134 | 78 | 70 | 0.6812 | 0.6114 |
| Flute / detected-onset regions | 76 | 60 | 57 | 0.7018 | 0.6667 |
| Flute / reference-boundary diagnostic | 74 | 73 | 73 | 0.8639 | 0.8639 |
| Violin / raw stable runs | 118 | 75 | 54 | 0.7246 | 0.5217 |
| Violin / detected-onset regions | 103 | 76 | 57 | 0.7917 | 0.5938 |
| Violin / reference-boundary diagnostic | 71 | 71 | 71 | 0.8875 | 0.8875 |

Counts apply after the common edge exclusion. Reference totals remain 95 flute
and 89 violin notes. The 880-frame diagnostic yields full-note F1 of 0.6036/0.5340
with detected boundaries and 0.8171/0.8944 with reference boundaries. Neither
window's detected-boundary result passes the full-note target on either part.
The study does not replace the original raw frame-coverage/precision evaluation.

`--region-study` adds a `.regions.wav` sine audition using detected-onset hypotheses
only. Reference-derived intervals never enter this audio. Inferred notes occupy
whole proposed intervals, so rests and physical offsets remain unproven. The
audition complements the unchanged raw `.estimated.wav`; it is not WFC output.
The workflow's separate saved WFC model still learns from the encoded source
with the existing raw duration learner. Region hypotheses are not admitted for
style learning merely because the workflow runs successfully.

Checked stable/development Win32 and stable Win64 exercise the region API,
explicit interval scorer, both study conditions and diagnostic auditions.
Evidence is under `build/phrase-regions-{stable,trunk,win64}/` and the existing
`build/recorded-phrases-{compiler}-{cpu}-{os}/` output directories. The controlled
checks retain real octave changes across explicit boundaries, distinguish tuning
excursions from sustained off-grid tuning, preserve raw data and reject ambiguous
or insufficient evidence. No file-format generation or estimator policy changed.

All study WAVs and learned model text replay exactly across the three targets:
38 artifact comparisons are byte-identical. Ten JSON comparisons retain identical
discrete evidence, with floating measurement differences no larger than 1.43e-12,
checked by a native comparator. The original source/estimated auditions remain
byte-identical, and rejected study options or output/input collisions preserve
accepted artifacts. Default detected-region audition SHA256 values are
`8884f283244fc11320829aa63aead15f004d348ff24c45c1fbef3cabca1917eb` (flute) and
`ff9cd242e3608991385f2196b188658d9845d5958944d5bec4494600cc76db55` (violin).
The maintained study workflow passes all three targets. Current package refresh,
the full ordinary build and remote CI were not run.

Next build source-derived note onset/offset proposals that cooperate with region
pitch support, explicitly testing repeated notes, real octave jumps, weak attacks
and background noise. Better boundaries must improve the detected condition;
the reference-boundary diagnostic cannot close that requirement. Validate frame
coverage/false admissions and held-out note accuracy before saving inferred note
behavior into reusable styles or assigning milestone credit.

## Support-bin endings — 2026-09-15

The unchanged `--region-study` option now also reports **detected-onset gated
regions** and writes `.gated.wav`. It preserves each admitted detected attack and
ends at the last supporting center-aligned pitch hop bin, clipped to its candidate
region, with zero padding. Per-vote support extents and actual proposed note start
and end frames are serialized in excerpt-local analysis frames. Scoring maps
those intervals to the absolute analysis timeline. Reference boundaries never
enter either inferred audition. This is an ending hypothesis, not a physical
release measurement; gaps inside a vote's support extent remain possible.

`EvaluatePitchIntervalFrames` scores explicit nonoverlapping note intervals at
the unchanged track window centers. It uses track geometry and supported frequency
range, not raw pitch labels. Reference overlaps are reported and excluded;
out-of-range reference notes stay in coverage. Gaps are unknown, never measured
silence. Frame scoring has no note-edge exclusion. Each study condition now
reports these frame scores alongside its existing independent note-interval
score, making the coverage cost of shorter gates visible.

A development-only 20-ms onset energy-window probe reduced full-note F1 to
0.4000/0.5697 for flute/violin. It was not adopted; the maintained detector keeps
its existing 5-ms window. Evidence is under `build/phrase-boundaries-probe/`.

Default 294-frame pitch-window results:

| Part / condition | Pitch coverage | Pitch precision | False pitch centers in rests | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flute / detected regions | 74.92% | 90.22% | 99 | 0.7018 | 0.6667 |
| Flute / gated regions | 73.51% | 92.97% | 70 | 0.7018 | 0.6901 |
| Violin / detected regions | 77.37% | 95.84% | 44 | 0.7917 | 0.5938 |
| Violin / gated regions | 75.85% | 97.83% | 31 | 0.7917 | 0.6042 |

Gating adds two full-note matches for flute (59/95) and one for violin (58/89).
Estimated-note counts stay 76/103. It reduces false admissions in rests and raises
precision, but also removes correct active coverage. Neither result meets the
declared targets, so gating is retained as an explicit study condition, not
promoted into learned styles. The original raw/source and detected-region
auditions remain unchanged. This measured tradeoff supersedes any assumption
that a better note F1 alone implies a better complete transcription.

For the 880-frame diagnostic, gated coverage/precision are 71.41%/91.91% for
flute and 78.13%/96.15% for violin; full-note F1 is 0.6272/0.5437. These also fail.
With reference boundaries, default coverage/precision reach 81.49%/99.12% and
80.29%/100%, respectively. That diagnostic uses known boundaries and excludes
overlapping intervals from inference; it is not an end-to-end acceptance result.
The held-out set remains unused and no inference thresholds were relaxed.

Checked stable/development Win32 and stable Win64 pass the gate and inferred-frame
fixtures and the maintained development workflow. Controls cover trailing silence,
repeated notes, real octave boundaries, clipped padding, invalid/unknown support,
absolute frame scoring, ambiguous references and false admissions in rests.
Forty WAV/model cross-target comparisons are byte-identical; twelve JSON
comparisons retain identical discrete evidence, with raw/vote measurement
differences <= 1.43e-12. A collision with the added gated output rejects before
writing and preserves all five existing artifacts. No owned warnings were emitted
by the pitch fixture or phrase operator builds.

Evidence: `build/phrase-boundaries-{stable,trunk,win64}/`, with the maintained
reports and auditions under `build/recorded-phrases-{compiler}-{cpu}-{os}/`.
Default gated WAV SHA256 values are
`370ce80284595fa9284f008c623c18bb58e88af7938762ab928129466b457e63` (flute) and
`21516de8183c1e90f6c6147417a7613a8ee710ee7f5117646db5ce8425af856b` (violin).
The separate saved WFC duration workflow still consumes raw measured source
evidence and reproduces its earlier short fragments. The 32-span style-provider
failure remained open at this checkpoint; the later
[scope diagnosis](WAV-STUDIES.md#duration-scope-checkpoint) distinguishes infeasible
isolated-note scope from supported multi-note paths. Current package refresh, ordinary full build and remote CI
were not run at this checkpoint.

Next improve event segmentation jointly with pitch support, addressing excess
splits and missed attacks while retaining actual repeated-note and octave
transitions. Compare coverage, false admissions and complete-note accuracy to all
existing study conditions; simple endpoint trimming is insufficient. Do not use
the held-out recordings to select that policy or award phrase milestone credit.

<a id="phrase-partition-checkpoint"></a>
## Pitch-supported partition experiment — 2026-09-19

A development-only native experiment tests whether joining excess onset regions
can repair fragmentation. It reuses the same Spring flute/violin inputs, first
30 seconds, default 294-frame pitch window, existing detector, region admission
and evaluation tolerances. Reference notes enter scoring and the later boundary
audit only; they do not enter the partition or inferred gates. Held-out recordings
remain unused. No maintained estimator, learner, default or file contract changes.

The probe chooses a partition of existing adjacent onset regions by dynamic
programming. It can join at most 32 regions spanning at most two seconds; it
cannot introduce a missing boundary. An unadmitted single region costs its window
count. An admitted region costs unsupported window count plus three, plus six
times the sum of squared contrasts at removed internal onsets. Admission still
uses the existing minimum support, coverage, energy share and tuning policy.
These costs are an experimental objective, not measured musical probabilities.

Three gate conditions isolate timing effects: retain the proposed start, begin
at the winning note's first supporting hop bin, or allow half a pitch window
(147 frames / 18.375 ms) of pre-roll before that bin, clipped to the region.
All end at the last supporting bin. An extent may still enclose unsupported gaps;
none of these gates establishes a physical attack, release or rest.

| Part / condition | Coverage | Precision | False pitch centers in rests | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flute / maintained gated baseline | 73.51% | 92.97% | 70 | 0.7018 | 0.6901 |
| Flute / partition, original starts | 77.57% | 90.12% | 129 | 0.6988 | 0.6747 |
| Flute / partition, support starts | 72.45% | 96.52% | 20 | 0.6988 | 0.6867 |
| Flute / partition, support starts with pre-roll | 76.80% | 95.32% | 37 | 0.7108 | 0.6988 |
| Violin / maintained gated baseline | 75.85% | 97.83% | 31 | 0.7917 | 0.6042 |
| Violin / partition, original starts | 83.53% | 96.05% | 40 | 0.8481 | 0.7089 |
| Violin / partition, support starts | 80.01% | 97.42% | 15 | 0.8354 | 0.7089 |
| Violin / partition, support starts with pre-roll | 82.85% | 97.32% | 17 | 0.8481 | 0.7089 |

Every condition fails at least one declared target. Violin's F1 increase also
hides a recall loss: the estimated-note count falls from 103 to 69, while complete
matches fall from 58 to 56 of 89 references. Flute's pre-roll condition estimates
71 notes and matches 58 of 95, versus 76 estimates and 59 matches in the baseline.
Do not promote a policy on its F1 increase without inspecting missed notes.

A separate native audit asks whether any candidate boundary lies within the
unchanged 50-ms onset tolerance of each eligible reference onset. It deliberately
ignores pitch identity and one-to-one matching: this is proposal availability,
not another note score or evidence of correctly detected attacks.

| Boundary observation | Flute | Violin |
| --- | ---: | ---: |
| Eligible reference notes | 95 | 89 |
| Consecutive same-pitch references | 14 | 13 |
| Original proposed regions | 303 | 305 |
| Selected partition regions | 271 | 231 |
| Reference onsets with no original boundary in tolerance | 18 | 1 |
| Additional onsets losing an available boundary in the partition | 3 | 13 |
| Same-pitch onsets missing an original boundary | 6 | 0 |
| Same-pitch onsets losing an available boundary | 2 | 10 |

For example, the flute detector has no nearby proposed boundary at 4.110 or
6.420 seconds; merging cannot repair those omissions. Conversely, the violin
partition removes available boundaries near ten repeated-note onsets. Onset
contrast and pitch agreement alone are therefore insufficient to choose which
boundaries may be removed in this experiment.

The experiment is **not adopted**. The next linked work is
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries): support missing-boundary
proposals and repeated-attack preservation together, then compare all admission
metrics per recording before freezing a policy. Keep source-derived uncertainty,
rests, weak attacks, real octave changes and held notes in the controls. Neither
joining regions nor trimming their endpoints alone clears this result.

Evidence is under ignored `build/phrase-partition-study/`: `partition.lpr` calls
the existing native analysis/scoring libraries and the local `phrase.partition`
probe; `diagnose.lpr` performs the separate boundary audit. Final reports are
`fl-final.json` and `vn-final.json`, with explicit probe costs/gate controls,
source/reference fingerprints, candidate regions and inferred intervals. Their
`.partition.wav` files are diagnostic sine resynthesis of the pre-roll condition,
not learned WFC output or accepted styles. The `.gated.wav` files retain the
maintained baseline hashes recorded above. Earlier exploratory outputs are not
the final artifact set. Checked compilation and execution cover stable Win64
only; no cross-target, held-out or listening acceptance is claimed. No new core
unit, maintained tool, fixture or format version is introduced.

<a id="envelope-attack-checkpoint"></a>
## Waveform valleys and protected boundary experiment — 2026-09-19

The next development experiment supplements spectral onset proposals with
[measured envelope valleys](ONSETS.md#envelope-valley-evidence). This measurement
is now available in the portable library and optional native inspection. The
musical policy built on it remains experimental: a waveform dip can also be
modulation or noise, and a pitch change can occur without a dip.

The same 30-second Spring recordings and default pitch/evaluation policy are
retained. The library measures complete 10-ms RMS windows at a 2-ms hop, searches
local minima within 20 ms and flanking peaks within 80 ms, and admits measurements
at depth >= 0.35 when both peaks exceed RMS 0.0001. No reference timing or pitch
enters measurement or partitioning. Valleys augment existing proposed regions
with at least 10 ms between boundaries. Boundaries within 10 ms of a valley
cannot be crossed by the experimental partition. The preceding partition costs,
region admission and support-start pre-roll/end gates otherwise remain unchanged.

Final results using the maintained measurement function:

| Part / condition | Estimated / complete matches | Coverage | Precision | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / maintained gated baseline | 76 / 59 | 73.51% | 92.97% | 70 | 0.7018 | 0.6901 |
| Flute / augmented regions, gated | 107 / 56 | 76.12% | 93.92% | 57 | 0.6634 | 0.5545 |
| Flute / protected partition with pre-roll | 102 / 58 | 79.70% | 96.38% | 20 | 0.7005 | 0.5888 |
| Violin / maintained gated baseline | 103 / 58 | 75.85% | 97.83% | 31 | 0.7917 | 0.6042 |
| Violin / augmented regions, gated | 108 / 53 | 74.49% | 98.26% | 24 | 0.7716 | 0.5381 |
| Violin / protected partition with pre-roll | 87 / 66 | 77.05% | 99.18% | 7 | 0.8636 | 0.7500 |

Reference totals stay 95 flute / 89 violin. Violin improves in actual complete
matches as well as precision and note F1, but fails the 80% coverage target.
Flute gains coverage/precision and reduces false admissions in rests while
over-splitting more notes and losing full-note F1. Every condition still fails at
least one predeclared target; the policy is not frozen or admitted to style learning.

The independent boundary-availability audit uses the same 50-ms tolerance and
continues to ignore pitch identity and one-to-one matching. Flute has 254 measured
valleys, 474 augmented regions and 436 partition regions; violin has 234 valleys,
442 augmented regions and 398 partition regions. The probe protects 256 / 234
boundaries; a nearby valley can protect more than one existing boundary.

Flute reference onsets lacking any nearby proposal fall from 18 to eight;
consecutive same-pitch onsets lacking one fall from six to two. Violin still has
one unavailable onset and no unavailable same-pitch onset. The protected partition
removes no available boundary near these reference onsets, including repeated
notes. This clears the earlier experiment's specific suppression failure on the
development set, not note-attack accuracy or general repeated-note acceptance.

Controlled native examples explain the remaining limit: one smoothly modulated
held tone produces four correctly measured valleys, while a constant-power octave
transition produces none. The new measurement passes both controls. The next
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) result must distinguish
articulation from modulation, combine pitch-change evidence where energy is
uninformative, and retain coverage before deciding which boundaries to protect.
Adding every valley or merging by pitch agreement alone is insufficient.

Checked onset fixtures and maintained inspection builds pass stable/development
Win32 and stable Win64 without companion paths. The fixed violin excerpt's
inspection retains exact discrete fields across targets; a native recursive
comparison bounds floating differences to 1e-9. Stable/development Win32 JSON
bytes match; whole-report Win64 byte parity is not claimed. Optional valley
measurement leaves the existing cue WAV identical. The default report matches
the preceding maintained tool, and duplicate options preserve accepted output.

The full phrase experiment and availability audit ran on stable Win64. Final
evidence uses `fl-core` / `vn-core` prefixes under ignored
`build/phrase-attacks-study/`; earlier prefixes describe the initial scratch
measurement grid and are not the final library-path results. Baseline gated WAV
hashes remain unchanged. The final experimental `.partition.wav` hashes are
`3dec5e2ec6d4c29a4bb3bb352f32bb2674fb1666366a5b40558da96056b47b2e` and
`4b2c8a48001935dadd27e3320e7de8bee8442f69bcee696d7afe363593f8dd0b`.
These are diagnostic sine resyntheses, not learned WFC output or listener approval.
The held-out recordings remain unused; no musical milestone credit is awarded.

<a id="periodicity-boundary-checkpoint"></a>
## Periodicity-qualified boundaries and register diagnosis — 2026-09-19

This development experiment tests whether evidence on both sides of a waveform
valley can distinguish articulation from smooth modulation. It retains the same
Spring recordings, 30-second excerpts, raw pitch measurements, region admission
and scoring tolerances. Left/right pitch summaries cover 80..20 ms before and
20..80 ms after each proposed boundary. A valley qualifies only when both side
notes are admitted and either differ or a silent/unresolved-period window occurs
within 20 ms. An unresolved estimator window is evidence, not proof of silence.
Twenty-eight flute and fifty violin valleys qualify under this exploratory policy.

Pitch-change proposals additionally use the midpoint of each contiguous band of
unlike admitted side notes on the pitch hop grid. Two conditions distinguish
adding such a proposal from requiring it: the first protects every pitch-change
cut; the second leaves these cuts optional in the partition while retaining
protection around qualified valleys. Costs, support-start pre-roll and support-bin
endings remain as previously declared. No references enter these decisions.

| Part / condition | Estimated / complete matches | Coverage | Precision | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / qualified valleys only | 74 / 62 | 80.04% | 95.61% | 34 | 0.7456 | 0.7337 |
| Flute / plus protected pitch changes | 96 / 66 | 82.46% | 95.09% | 20 | 0.7016 | 0.6911 |
| Flute / plus optional pitch changes | 94 / 73 | 85.84% | 94.52% | 35 | 0.7831 | 0.7725 |
| Violin / qualified valleys only | 78 / 71 | 79.65% | 98.76% | 16 | 0.8982 | 0.8503 |
| Violin / plus protected pitch changes | 80 / 72 | 80.45% | 98.77% | 15 | 0.8994 | 0.8521 |
| Violin / plus optional pitch changes | 80 / 73 | 80.61% | 98.87% | 15 | 0.9112 | 0.8639 |

Both combined violin conditions meet all four development targets. Flute still
fails pitch precision and onset F1 in the optional-change condition. This is not
a frozen policy or held-out result, and one successful development part cannot
admit general recorded phrase learning. It does establish that keeping proposals
separate from mandatory cuts materially affects musical results.

Native controls pass on stable/development Win32 and stable Win64: a continuously
modulated held tone supplies eight valleys but no qualified attack; a constant-
power 220-to-440-Hz transition supplies one pitch-change proposal at frame 8067
versus the authored frame 8000; a 50-ms interruption between same-pitch tones
supplies one qualified valley and no pitch change. These are controlled mechanisms,
not coverage of arbitrary weak attacks or instrument mixtures.

An independent native audit reconstructs errors from saved inferred intervals,
raw window-center geometry and hash-matched annotations. For the optional-change
condition it confirms 68 wrong active flute centers, including 64 octave errors,
plus 35 false pitches in rests. Violin has eight wrong active centers, no octave
errors and fifteen false pitches in rests. Several flute intervals admit a lower
octave during a recorded attack; blindly doubling low notes would corrupt genuine
lower notes and octave transitions.

The [YIN paper, section II.F](https://www.ee.columbia.edu/~dpwe/papers/deChevK02-yin.pdf)
describes selecting a stronger nearby periodic estimate and re-estimating the
original window in a restricted period range (checked 2026-09-19). A targeted
native diagnostic explores that mechanism with the library's strict rejection
retained. It searches every sample offset within +/-73 frames and refines within
+/-20% of the selected period. It is not a complete implementation or evaluation
of the paper's algorithm.

Annotations select the 68 erroneous inferred flute centers for this diagnostic;
they do not select a lag or period. One target already has the correct raw nearest
note; four have a correct best-neighbor nearest note. Refinement yields one correct,
61 wrong and six unresolved targets. The work bound is 217472976 pitch operations.
These targeted nearest-note counts are not admission scores or end-to-end accuracy.
No track or generated audition changes. The result does not justify adopting a
full temporal pass as the solution to these longer octave-ambiguous attacks.

Next address [WAV-03-REGISTER](MILESTONES.md#wav-03-register) alongside
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries): infer a musical note from
event-level competing registers while retaining measured periodic evidence and
explicit ambiguity. Both feed phrase admission; their investigation can proceed
together without a circular completion dependency. Protect genuine low notes,
octave changes, quiet notes, vibrato and rests before freezing a policy.

The full recorded experiment and independent error audit ran on stable Win64.
Evidence is under ignored `build/phrase-periodicity-study/`, with final comparison
prefixes `fl-soft` / `vn-soft`, interval audits `fl-errors.log` / `vn-errors.log`
and the separate annotation-selected `fl-temporal` diagnostic. The two Win32
control runs are under `build/phrase-periodicity-{stable,trunk}/`. Final diagnostic
sine auditions have SHA-256
`b63194a1543befd8cd231fefcdd2e889cd41d15fcff690127a35746662f75ca4` and
`cc9de524e495a06c171a783ba4fbbbc6282aa97a0fde0bfc086a673666129fa6`.
The flute hash is unchanged by the separate temporal audit. These are not learned
WFC performances or listener acceptance. Held-out recordings remain unused; no
maintained estimator, default, format, package or percentage credit changes.

<a id="partition-energy-checkpoint"></a>
## Partition energy-cost counterexample — 2026-09-19

The region learner ranks raw periodic votes by RMS-squared energy, while the
experimental partition objective rewards the winning note's unweighted window
count. A paired development study tests replacing that reward with
`PeriodicWindows * winning EnergyShare`. All admission thresholds, proposals,
protected cuts, note/boundary costs, support gates and scoring stay fixed. Reports
declare the support policy explicitly. References remain scoring inputs only.
This tests one region-local energy objective; it is not a general evaluation of
energy weighting or an alternative pitch estimator.

For the qualified-valley plus optional-pitch-change condition:

| Part / reward | Estimated / complete matches | Coverage | Precision | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / window count, preceding checkpoint | 94 / 73 | 85.84% | 94.52% | 35 | 0.7831 | 0.7725 |
| Flute / local energy share | 84 / 70 | 84.97% | 95.54% | 26 | 0.7933 | 0.7821 |
| Violin / window count, preceding checkpoint | 80 / 73 | 80.61% | 98.87% | 15 | 0.9112 | 0.8639 |
| Violin / local energy share | 77 / 71 | 79.65% | 98.81% | 15 | 0.9036 | 0.8554 |

An independent saved-interval/reference audit confirms 56 wrong active flute
centers, including 50 octave errors, and 26 false pitches in rests. Violin has nine
wrong active centers, no octave errors and fifteen false rest centers. Flute still
fails precision/onset criteria; violin now fails coverage. Fewer estimated notes
raise flute full-note F1 despite reducing complete matches from 73 to 70.

Native controls isolate the partition objective from boundary discovery: each
two-second, 8-kHz signal has a true 220-to-440-Hz transition after one second.
The two supplied candidate intervals independently admit MIDI 57 and 69. Their
shared cut has zero strength, so the partition must decide whether to retain it.
The four peak-amplitude pairs are `0.3/0.3`, `0.03/0.3`, `0.3/0.03` and
`0.003/0.003`. The count reward preserves both notes in all four. The energy reward
merges the unequal-amplitude cases into one note, losing the quiet lower note in
one and the quiet upper note in the other. It preserves the equal-amplitude cases,
including the uniformly quiet control. This is a specific relative-level failure,
not evidence that quiet notes lack measurable pitch.

**Reject this objective for adoption.** Region-local energy share can make a
valid quiet event cheap to discard when grouped with a louder neighbor. The next
[register investigation](MILESTONES.md#wav-03-register) must distinguish competing
octave interpretations from genuine transitions using corroborating event evidence,
and preserve these counterexamples. Do not simply raise a merge penalty until
these controls pass. Coordinate that evidence with
[boundary inference](MILESTONES.md#wav-03-boundaries); phrase-policy freeze remains
gated by both development results before held-out evaluation.

Checked FPC 3.2.2 stable Win64 builds have no warnings. Count controls exit zero;
energy controls exit one with exactly two failed preservation cases. Both recorded
energy runs and independent interval audits finish successfully. Evidence is under
ignored `build/phrase-energy-study/`: `partition.controls.lpr`, the copied study
units, `fl-energy` / `vn-energy` reports and logs, and `fl-errors.log` /
`vn-errors.log`. Define `ENERGY_SUPPORT` to select the experimental objective;
omit it for the count control. Compile with `-B -Sa -Cr -Co -Ci -gl`, core/tool
paths and that study directory. Run the study with the preceding checkpoint's
source/reference pairs, `PREFIX 0 30 --region-study`; audit region-study index 10.
Diagnostic sine WAV SHA-256 values, flute then violin, are
`5c8810aa103cec584ff4150d7bbbf2075f7747df5b792239210610ef61060759` and
`7c989a5d940a67ad6515de94a71757f1c773080b0b2e753f6b79e06214ac99bf`.
No Win32 parity, held-out evaluation, learned WFC performance or listener acceptance
is claimed. Maintained code and defaults remain unchanged; no milestone credit.

<a id="pitch-candidate-checkpoint"></a>
## Retained pitch candidates and temporal decoding — 2026-09-19

The next development experiment retains alternative periodic interpretations
before selecting a note sequence. The primary
[pYIN paper](https://webspace.eecs.qmul.ac.uk/s.e.dixon/pub/2014/MauchDixon-PYIN-ICASSP2014.pdf)
motivates retaining multiple threshold-dependent candidates and voiced/unvoiced
pitch states before temporal decoding (checked 2026-09-19). This native prototype
uses its own explicitly reported discretization and transition policy; it is not
a complete pYIN implementation or a reproduction of the paper's reported results.

The study uses the same 30-second Spring excerpts, floating analysis clips,
294-frame windows, 80-frame hops and scoring protocol. It computes the existing
cumulative-normalized difference and retains the first local minimum under each
of 100 thresholds, 0.01 through 1. Exact beta(2,18) mass in each threshold bin
weights its selected candidate. There is no fallback when no minimum qualifies.
Period interpolation uses the raw difference. The existing frequency range,
silence RMS and 25-cent tuning filter apply; discarded mass becomes unknown.
These are model weights, not calibrated probabilities of musical correctness.

Two conditions use identical candidate evidence: independent maximum-mass choices
and a 256-state Viterbi path, with voiced/unvoiced states for each MIDI note.
Both state types share a normalized `exp(-abs(note difference)/2)` pitch-transition
kernel; voicing persists with weight 0.99 and changes with 0.01. Initial states
are uniform. Unvoiced states emit the same unknown mass; no zero-mass observation
receives an artificial floor. The model permits real octave jumps. A prior
single-unknown-state probe unfairly favored unknown persistence relative to
individual pitch states; its saved diagnostic is superseded by this shared-kernel
comparison. No reference note enters candidate measurement or decoding.

Runs shorter than three windows remain unknown. Accepted run intervals use
center-aligned hop bins; they do not use the separate region partition or infer
repeated-note attacks. Consequently this is a pitch-path comparison, not a
replacement for the stronger region/boundary results above.

| Part / condition | Estimated / complete matches | Coverage | Precision | Wrong / octave centers | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / independent candidates | 132 / 70 | 76.66% | 92.42% | 112 / 112 | 18 | 0.6872 | 0.6167 |
| Flute / temporal candidates | 115 / 70 | 77.62% | 94.14% | 89 / 89 | 11 | 0.7429 | 0.6667 |
| Violin / independent candidates | 117 / 53 | 70.97% | 99.78% | 1 / 0 | 3 | 0.7379 | 0.5146 |
| Violin / temporal candidates | 110 / 50 | 70.81% | 99.77% | 1 / 0 | 3 | 0.7236 | 0.5025 |

Neither temporal result passes all declared targets. The unchanged raw flute
baseline has 77.57% coverage, 92.19% precision and 116 octave errors. Temporal
candidates improve its precision and note scores, but fail to resolve register
admission. Violin coverage/note scores regress slightly against its raw baseline.

Independent native interval/reference auditing reproduces coverage, precision,
wrong-pitch/octave and false-rest counts. It also checks every saved candidate
vector plus unknown mass sums to one within 1e-12. That check initially caught
rounding in the prototype's unknown-mass clamp; retaining Double arithmetic fixes
the discrepancy. The final builds and reports include that correction.
The annotated pitch has positive candidate mass at 1822/2069 active flute centers
and 2001/2501 active violin centers. Requiring mass at least 0.01 gives 1777 and
1964 respectively. These annotation-selected availability counts are diagnostic
upper bounds on selection from this filtered candidate set, not usable inference
or achieved accuracy. The violin set leaves almost no margin above 80% coverage.

Eight native controls pass, each checking 190 centers outside a one-window margin
around the authored transition: equal-level, quiet lower, quiet upper and uniformly
quiet octave transitions; a 100-ms quiet lower note; missing-fundamental and
dominant-second-harmonic transitions; and a pitched tone followed by silence.
The short-note result covers its interior pitch, not onset/offset accuracy.
These controls establish neither arbitrary noise/vibrato behavior nor mixtures.

Next retain continuous pitch/tuning alternatives through event inference rather
than discarding off-grid candidates early, and combine candidate evidence with
the existing articulation proposals. Evaluate that hypothesis against both the
raw path and qualified-boundary baseline; do not relax acceptance or overwrite
raw pitch measurements. This is [WAV-03-REGISTER](MILESTONES.md#wav-03-register)
work coordinated with [WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries).
Combined-policy freeze and held-out phrase admission remain downstream.

Evidence is under ignored `build/phrase-candidates-study/`: native candidate unit,
study program, eight-case control, independent audit, final `fl-candidates` /
`vn-candidates` reports/logs and diagnostic sine auditions. Checked FPC 3.2.2
stable Win64 builds have no warnings. Compile with `-B -Sa -Cr -Co -Ci -gl`,
`src`, `tools` and the study directory as unit paths. Run `periodicity` with the
same source/reference pairs as above and `PREFIX 0 30`; run `audit REPORT NOTES`.
Measurement and decoder work are explicitly bounded; the decoder preflight for
2997 windows is 196411392 state-transition visits. This is an offline bounded
excerpt experiment, not multi-hour streaming. Audition SHA-256 values are
`acb395c70d8bfabc015fddce32b660debd6cda824ccd64e04973629c36ecae12`
(flute) and `1a3aca37a6a5a1773994e59724a3224ca5d27afb5ff407533bc525150d48339b`
(violin). No Win32 parity, WFC/listening acceptance or held-out result is claimed.
Maintained core/defaults, format contracts and milestone percentages are unchanged.

<a id="candidate-event-tuning-checkpoint"></a>
## Candidate tuning at event scope and articulation cuts — 2026-09-19

This development study moves tuning admission after candidate decoding. Each
threshold-supported candidate retains its nearest note and continuous cents
offset, including offsets outside the per-window 25-cent tolerance. Candidate
weights, periodic measurement, range/RMS limits and temporal transitions remain
as in the preceding checkpoint. Within each decoded same-note run, normalized
RMS-squared energy weights the candidate cents. The run must still have at least
three windows and a mean within the original 25-cent tolerance. Raw pitch-track
estimates and their existing tuning decisions remain intact.

The articulation condition additionally splits runs at the earlier qualified
waveform valleys, mapped to the nearest hop-bin boundary. Run length and tuning
are evaluated after splitting. This directly compares optional event separation
with the unchanged temporal labels; it does not modify the decoder to favor cuts.
Saved reports retain candidate cents, raw RMS, proposed cuts, accepted event means
and counts of tuning-rejected events. No annotations enter these decisions.

| Part / event condition | Estimated / complete matches | Coverage | Precision | Wrong / octave centers | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / independent candidates | 114 / 79 | 82.12% | 92.04% | 128 / 123 | 19 | 0.7656 | 0.7560 |
| Flute / temporal, no added cuts | 101 / 80 | 84.49% | 93.08% | 112 / 93 | 18 | 0.8265 | 0.8163 |
| Flute / temporal, qualified cuts | 105 / 80 | 84.44% | 93.37% | 107 / 92 | 17 | 0.8100 | 0.8000 |
| Violin / independent candidates | 92 / 74 | 77.61% | 99.08% | 12 / 0 | 6 | 0.8840 | 0.8177 |
| Violin / temporal, no added cuts | 86 / 76 | 80.09% | 98.04% | 33 / 0 | 7 | 0.9029 | 0.8686 |
| Violin / temporal, qualified cuts | 89 / 79 | 79.81% | 98.33% | 28 / 0 | 6 | 0.9101 | 0.8876 |

The uncut temporal violin condition meets all four development targets, narrowly
on coverage and precision. Both temporal flute conditions meet coverage/onset/
full-note criteria but fail precision. Adding qualified cuts raises violin note
matches while dropping coverage below target; flute onset/full-note scores fall.
Neither mandatory cutting nor this candidate model is selected as a new default.
The earlier qualified-partition baseline remains a separate comparison, including
its stronger flute precision and passing violin development result.

The independent native audit reconstructs every accepted event's tuning mean
from saved candidate cents and raw RMS, checks the 25-cent limit and positive
candidate support, and reproduces frame accuracy and candidate-mass totals.
Candidate availability increases to 1971/2069 active flute centers and 2384/2501
violin centers; mass at least 0.01 gives 1907 and 2330. These remain diagnostic
availability counts, not accuracy or calibrated confidence. Among the uncut
temporal flute condition's 112 wrong centers, the reference note has positive
candidate mass at 62, at least 0.01 at 42, and no candidate mass at 50. None of
violin's 33 wrong centers has the annotated note in its candidate set. Thus
reweighting the same per-window candidates alone cannot repair every error.

Twelve analytic controls pass after event admission and qualified cutting. The
preceding eight cases retain their expected interior pitch/unknown labels. Two
steady +35-cent notes are rejected, while +/-35-cent, 5-Hz vibrato around the
nominal pitches retains both events. A 4-Hz amplitude-modulated held tone yields
one event; a same-pitch pair with a 50-ms gap yields two. Each control checks 190
centers outside a one-window margin around the authored transition; this does not
establish exact attack/release timing or arbitrary noise/mixture behavior.

Next separate register selection failures from absent candidate support, and use
event/attack context to interpret transient periodicity without erasing true
octave changes. Retain the tuning evidence and counterexamples. Coordinate
[WAV-03-REGISTER](MILESTONES.md#wav-03-register) with
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries); candidate generation,
temporal selection, event tuning and articulation must remain independently
inspectable. [Phrase admission](MILESTONES.md#wav-03-phrases) still waits for both
development parts before policy freeze and held-out evaluation.

All study, twelve-control and independent-audit runs are terminal on checked
FPC 3.2.2 stable Win64, without owned warnings. Evidence is in ignored
`build/phrase-event-candidates/`, with `fl-events` / `vn-events` reports, logs and
auditions. Build `periodicity.lpr`, `candidate.controls.lpr` and `audit.lpr` with
`-B -Sa -Cr -Co -Ci -gl`, core/tool/study unit paths and ignored output paths.
Use the same source/reference pairs and `PREFIX 0 30`; run `audit REPORT NOTES`.
Audition hashes, all diagnostic sine synthesis rather than learned performances:

| Part | No added cuts: `.candidates.wav` | Qualified cuts: `.events.wav` |
| --- | --- | --- |
| Flute | `a0f01731259368b4e5a02b84548ade1960b06bf6c6d2928b6a7d02946307aab7` | `afea59444f341e4af87172374c4bddf989a06653c754ace594ee0b78e3890cc8` |
| Violin | `4544f2d6e0e8afef3b2f27e3520314adfafb3dc2e9aed1bf8cb2e400fe431b92` | `e82293e7cc61dcd34b125da22b0a745dd3492bf39a7ded4be5aca72ff18da529` |

Held-out recordings remain unused. No maintained API/default, format, package,
cross-target parity, WFC/listening acceptance or milestone credit changes.

<a id="candidate-note-projection-checkpoint"></a>
## Adjacent-note projection counterexample — 2026-09-19

This paired development experiment tests whether rounding each continuous pitch
to one MIDI note prematurely discards useful neighboring interpretations. It
instead divides each candidate's mass linearly between its two adjacent integer
MIDI notes, retaining the cents offset relative to each. These are two musical
interpretations of one measured period, not additional measured spectral peaks.
All temporal, event-tuning, articulation and evaluation policies remain fixed.

| Part / temporal condition | Estimated / complete matches | Coverage | Precision | Wrong / octave centers | False rest centers | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute / no added cuts | 99 / 80 | 84.15% | 93.55% | 106 / 89 | 14 | 0.8351 | 0.8247 |
| Flute / qualified cuts | 103 / 80 | 84.10% | 93.80% | 101 / 88 | 14 | 0.8182 | 0.8081 |
| Violin / no added cuts | 86 / 74 | 79.65% | 98.08% | 33 / 0 | 6 | 0.9029 | 0.8457 |
| Violin / qualified cuts | 89 / 77 | 79.41% | 98.37% | 28 / 0 | 5 | 0.9101 | 0.8652 |

Flute precision improves modestly against the preceding event-tuning condition,
but still fails. Violin loses its development coverage pass and two complete
matches in each temporal condition. Broader note support is insufficient: the
uncut violin path still has 33 wrong centers although 19 now have positive mass
for the annotated note, versus zero previously. The corresponding flute count
is 74 of 106 wrong centers; 32 still lack support for the reference note. These
annotation-selected diagnostics cannot be used as inference inputs.

Do not adopt this projection as a replacement or tune further scalar weights to
these two excerpts. Continue [WAV-03-REGISTER](MILESTONES.md#wav-03-register) with
explicit event/register context and a distinction between absent support and
wrong selection, coordinated with the attack evidence in
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries). Keep the preceding baselines
and their counterexamples. The independent
[synthesis-quality outcome](MILESTONES.md#fund-quality) remains ready and should
receive the next engineering work alongside this unresolved musical research.

The twelve existing analytic controls pass. Independent native audits reproduce
event-tuning means, candidate-mass totals and frame scores for all three saved
conditions on both recordings. Checked FPC 3.2.2 stable Win64 builds have no
owned warnings; all processes are terminal. Sources, commands, reports and logs
use the preceding study layout under ignored `build/phrase-note-projection/`,
with prefixes `fl-projection` and `vn-projection`. Compile the same three programs
with checked flags and this study's unit/output paths. Uncut diagnostic sine WAV
hashes are `e691d3bba0a2869ccb801096bcf97660c5a153e364bf510944a2ca1a0c0ef582`
(flute) and `52dfc8f822f1e1b9653944b1ab90e47625552482eab66c2dfaeab5c102114a0e`
(violin). No maintained implementation, held-out evaluation, listener/WFC
acceptance or percentage credit changes.

<a id="register-boundary-diagnosis"></a>
## Register and transition diagnosis — 2026-09-19

An independent audit of the existing event-tuning reports separates errors near
annotated note boundaries from errors inside notes. It uses the original temporal
condition without added cuts, not the adjacent-note projection. A wrong active
center is near a boundary when it is less than 50 ms after the reference onset
or at most 50 ms before its offset. This diagnostic uses annotations to explain
errors; those annotations are not available to inference.

| Part | Wrong active centers | Downward / upward octave errors | Near boundary | Interior | Interior without reference candidate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flute | 112 | 93 / 0 | 68 | 44 | 10 |
| Violin | 33 | 0 / 0 | 33 | 0 | 0 |

Thus violin's absent reference candidates at wrong centers occur at transitions;
flute also has sustained register/support failures. Adding the existing qualified
cuts leaves 44 interior flute errors and reduces violin's boundary errors to 28,
but retains the previously reported coverage tradeoff. Neither result changes
the acceptance decision.

A separate context count finds 15 wrong violin centers and one false-rest center
in inferred events whose note lies exactly between the preceding and following
inferred notes, which are two semitones apart. No correct centers meet that
condition in this excerpt. This is a development observation, not permission to
erase intermediate notes: duration, continuity, attacks, genuine passing notes
and glides have not been distinguished by that count.

The next probe uses actual WAV samples and the existing native harmonic fitter,
without reading annotations. At each inferred event's note plus measured mean
cents, it compares four harmonics at frequency `f` with two harmonics at `2f`,
using the same samples and highest modeled frequency. It reports residual/AC RMS
and the lower fit's odd-harmonic coefficient-power share. The latter is a ratio
of squared fitted coefficients, not an exact finite-window energy fraction or
a calibrated probability of register correctness. Source and recreated excerpt
hashes must match the saved candidate report.

Some wrongly low flute events have little odd-harmonic support: events 1 and 2
have shares 0.021 and 0.041; events 6 and 9 are approximately 0.100 and 0.097.
However, the analytic true-lower-note control with a dominant second harmonic
has share 0.100 too. A scalar cutoff followed by pitch doubling would therefore
damage valid lower notes. The pure-second-harmonic control is indistinguishable
from a tone at twice the nominal lower frequency. Whole-event stationary fits
also leave substantial residuals on some correctly pitched events; this probe
does not separate drift, noise and unmodeled harmonics.

Four analytic fitter controls pass: pure fundamental, missing fundamental with
second/third harmonics, dominant second with a weaker fundamental, and second
harmonic alone. All 102 flute and 87 violin event intervals are measured; these
counts precede the evaluator's edge exclusions. Cumulative fit work is 28545600
and 31053600 respectively, below the declared 268435456 bound. This is a bounded
development diagnostic, not a many-hour inference implementation.

Next investigate short-window harmonic alternatives and event/attack context,
retaining ambiguity where evidence is insufficient. Coordinate
[WAV-03-REGISTER](MILESTONES.md#wav-03-register) and
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries), without making either wait
for the other. Protect true lower/quiet notes, missing fundamentals and real
octave changes, and distinguish fast passing notes/glides from transition errors.
Both development gates must clear before
[WAV-03-PHRASES](MILESTONES.md#wav-03-phrases) freezes policy and evaluates the
reserved recordings; that admission supplies
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration).

Evidence is ignored under `build/phrase-register-context/`: `audit.lpr`,
`harmonics.lpr`, build logs, `fl.log` / `vn.log` and `fl-harmonics` /
`vn-harmonics` JSON/logs. Checked FPC 3.2.2 stable Win64 builds use
`-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools` and study-local output paths.
Run `audit CANDIDATE_REPORT REFERENCE_NOTES` and
`harmonics CANDIDATE_REPORT ORIGINAL_WAV OUTPUT_JSON`, using the preceding
event-tuning reports and Spring source/reference pairs. Independent audit checks
retain candidate-mass totals, event-tuning means and frame scores. Builds have no
owned warnings; all runs are terminal. No pitch edits, new default, maintained
API, held-out use, new audition, listening acceptance or percentage credit is
claimed. Existing package evidence remains applicable to unchanged source code.

<a id="centered-candidate-checkpoint"></a>
## Centered candidate support and articulation tradeoff — 2026-09-19

This development comparison applies the [centered difference support](PITCH.md#centered-periodic-measurement)
to the preceding event-tuning candidate experiment. Every candidate lag now has
the same window-center support; half-frame shifts average neighboring difference
sums. The threshold distribution, temporal decoder, event tuning, run minimum,
attack cuts and evaluation remain fixed. Raw pitch tracks and the inputs to
qualified-cut detection remain the preceding prefix measurements. This isolates
candidate timing; it is not a wholesale change to the phrase pipeline.

Both first-30-second Spring parts retain their exact source/reference bindings,
8-kHz analysis, 294-frame windows and 80-frame hops. Each has 2997 candidate
windows, with a conservative centered work bound of 129524346 difference terms,
below 268435456. Reference annotations enter scoring/diagnosis only.

| Part / temporal condition | Coverage | Precision | Wrong / octave centers | Complete matches / estimates | Onset F1 | Full-note F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flute, prior / no cuts | 84.49% | 93.08% | 112 / 93 | 80 / 101 | 0.8265 | 0.8163 |
| Flute, centered / no cuts | 85.07% | 93.72% | 99 / 84 | 81 / 101 | 0.8367 | 0.8265 |
| Flute, prior / qualified cuts | 84.44% | 93.37% | 107 / 92 | 80 / 105 | 0.8100 | 0.8000 |
| Flute, centered / qualified cuts | 84.82% | 93.90% | 95 / 84 | 81 / 102 | 0.8325 | 0.8223 |
| Violin, prior / no cuts | 80.09% | 98.04% | 33 / 0 | 76 / 86 | 0.9029 | 0.8686 |
| Violin, centered / no cuts | 80.53% | 98.24% | 35 / 0 | 70 / 86 | 0.8914 | 0.8000 |
| Violin, prior / qualified cuts | 79.81% | 98.33% | 28 / 0 | 79 / 89 | 0.9101 | 0.8876 |
| Violin, centered / qualified cuts | 80.21% | 98.38% | 32 / 0 | 75 / 89 | 0.9101 | 0.8427 |

Flute precision still fails 98%. The centered violin conditions meet the four
declared aggregate targets but lose complete matches relative to their paired
baselines; they do not establish an across-recording policy. Independent boundary
diagnosis finds 41 interior flute errors, eight without reference-candidate
support, versus 44/10 previously. All 35 uncut violin errors still lie within
50 ms of a reference boundary. Centering does not resolve register or event scope.

A further native audit compares complete-match eligibility for each reference
and checks that the totals reproduce the ordered one-to-one scores. For uncut
violin, exactly six previously matched references lose eligibility:

- References 19, 21, 46 and 51 end too early. Their offset errors move from
  -389/-381/-317/-413 frames to -469/-461/-557/-493 frames, crossing their
  existing duration-dependent tolerances. Three changes are one 80-frame hop;
  the fourth is three hops. No tolerance is changed.
- References 32 and 33 are consecutive MIDI-72 notes. The centered uncut path
  joins them into one interval. Existing qualified attack cuts restore both
  matches; the four early endings remain, explaining 79→75 for that condition.

These indices are zero-based positions in the annotation file, used only for
diagnosis. The flute gains one complete match: reference 29's onset error changes
from 427 to 347 frames, crossing the fixed 400-frame onset tolerance. These are
boundary effects, not evidence for a global timing shift or different thresholds.

The next [WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) result should combine
independent attack and release evidence with pitch support. A continuous
periodicity path must not erase an audible repeated attack, and a support-bin
ending must not be treated as a physical release without evidence. Retain weak
attacks, rests, glides and genuine short/passing notes. Continue
[WAV-03-REGISTER](MILESTONES.md#wav-03-register) on the remaining interior/octave
errors. Neither investigation waits for the other; both still gate the combined
policy freeze and held-out [phrase evaluation](MILESTONES.md#wav-03-phrases).

The twelve existing analytic candidate controls pass. Independent native audits
reproduce candidate-mass totals, event-tuning means and all three conditions'
frame scores on both recordings. The event-change audit verifies the complete
match totals above. Checked FPC 3.2.2 stable Win64 builds have no owned warnings;
all processes are terminal. Evidence is ignored under
`build/phrase-centered-candidates/`, with `fl-centered` / `vn-centered` reports,
diagnostic sine auditions and logs. Build `periodicity.lpr`,
`candidate.controls.lpr`, `audit.lpr` and `note.changes.lpr` using checked flags
and core/tool/study unit paths. Run the existing source/reference commands with
`PREFIX 0 30`; use `note.changes PRIOR_REPORT CENTERED_REPORT REFERENCE_NOTES`.
The preceding register audit also runs on each centered report for boundary counts.

No new maintained implementation/default, saved contract, held-out use,
cross-target result, WFC/listening acceptance or percentage credit is claimed.
The core centered API retains its separately verified scope; this phrase
experiment is not adopted as a default. The uncut flute/violin diagnostic WAV
SHA256 values are respectively
`d06728ab8f9d837e04eefe75647562e2fd2b74906f64c4b050d542f6c303b244`
and `5a99aa97dedb0ec767b808a43f5908d5a43d257a5f106fb579743772a8733e09`.

<a id="energy-fall-release-checkpoint"></a>
## Energy-fall release counterexample — 2026-09-19

The next probe measures [local energy falls](ONSETS.md#energy-fall-evidence)
independently of pitch stability. It uses the preceding centered, qualified-cut
intervals as proposals, preserving every pitch, attack and event count. The rule
is declared before either recording runs: 20-ms adjacent energy windows, mean
power fall at least 0.000001 and contrast at least 0.2; search within ±80 ms of
the inferred end, bounded by the event's own start and the next attack. A resolved
maximum replaces the proposed end only with complete context and away from search
edges. Otherwise the existing end remains. There is no blanket duration shift,
change to pitch thresholds or annotation input to this measurement/decision.

This **does not qualify as a release policy**. Selecting the strongest fall often
chooses decay inside an active note and removes valid coverage:

| Part / condition | Coverage | Precision | Complete matches / estimates | Full-note F1 |
| --- | ---: | ---: | ---: | ---: |
| Flute, centered qualified-cut baseline | 84.82% | 93.90% | 81 / 102 | 0.8223 |
| Flute, strongest local energy fall | 74.09% | 94.51% | 50 / 102 | 0.5076 |
| Violin, centered qualified-cut baseline | 80.21% | 98.38% | 75 / 89 | 0.8427 |
| Violin, strongest local energy fall | 65.49% | 97.62% | 35 / 89 | 0.3933 |

The probe examines 103 flute and 90 violin intervals before the common edge
exclusion. It applies 87/76 proposals, retains 6/3 for insufficient context and
10/11 as unresolved. Bounded source-read work is 330161/306375 respectively.
For example, the violin event beginning at frame 60027 already ended too early
at 61707; the energy fall selects 61132 instead. Its before/after RMS values are
0.01240/0.00996 with contrast 0.2157: that is a measurable decline, not evidence
that the note has stopped. No scalar retry is adopted to fit these examples.

The next boundary result needs sustained tail/activity evidence and separation
from a following attack, with explicit uncertainty when signal level, noise,
modulation or overlapping sources do not establish an ending. Retain the
independent attack decisions that restored the repeated-note pair; do not infer
release from the last stable pitch bin or the strongest decline alone.
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) remains runnable alongside
[WAV-03-REGISTER](MILESTONES.md#wav-03-register), and both still gate phrase policy
freeze and held-out evaluation.

The native probe verifies original WAV/reference hashes, recreates the excerpt
and checks its PCM hash against the candidate report. It checks unchanged
attacks/pitches, positive durations and no overlap with the next event, then
scores the intervals through the existing native evaluators and renders diagnostic
sine auditions. The primitive's independent power-sum/edge checks pass on three
Windows targets; this recorded probe runs on checked stable Win64 only. Evidence
is ignored under `build/phrase-release-evidence/`: `release.lpr`, build/run logs,
`fl.json` / `vn.json` and auditions. Compile with
`-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools` and study-local output paths; run
`release CANDIDATE_REPORT ORIGINAL_WAV REFERENCE_NOTES OUTPUT_PREFIX` using the
same Spring development inputs. All runs are terminal.

Diagnostic WAV hashes are
`c4837712cdb0bbc76e143349392e7687e0dd8907a1e6f82ba75f9bdaecb99b1e`
(flute) and
`8306a853764be9d88ff355c2aa6f2830569095fa90a1364162903de12e70895d`
(violin). These document the rejected rule, not accepted learned performances.
No held-out material, saved-style policy, listening approval or milestone credit
changes. The reusable primitive is maintained; this gate rule remains experimental
and unadmitted. Source packages still need their affected API refresh.

<a id="sustained-tail-checkpoint"></a>
## Sustained low-activity tails — 2026-09-19

This development condition replaces the rejected maximum-fall rule with a
terminal low-activity test. It reuses `TEnvelopeTrace` and centered periodic
measurement, retaining the same centered/qualified-cut interval proposals,
attacks, pitches and event counts. The rule is fixed before either recording:

- Measure nonoverlapping 10-ms RMS windows on the 8-kHz analysis grid. Use the
  peak of complete RMS windows inside the proposed event as the reference level.
- Search within ±80 ms of its proposed ending for a downward crossing below
  20% of that peak. Require at least 40 ms of complete low support and no rebound
  above that level through the next declared attack. Incomplete context stays
  unresolved; no zero padding supplies tail evidence.
- Confirm the first 40-ms low interval with centered pitch measurement. A
  periodic or outside-range result does not qualify. Only measured silence or
  no-period can support the low-activity proposal. No-period alone never triggers
  an ending. Use the first low RMS window's center as the proposed boundary.

Eight analytic cases pass before the recorded probe: abrupt and fading endings,
a temporary dip with recovery, a quiet continuing tone, a short gap before the
next attack, a low noise tail, steady sustain and a weak note with a low noise
tail. Accepted synthetic endings are within one 80-frame RMS window of the
authored ending; the temporary dip/continuing tone/short gap/sustain stay
unresolved. Reports explicitly distinguish unmeasured periodicity from a
measured no-period result.

| Part / condition | Coverage | Precision | Complete matches / estimates | Full-note F1 |
| --- | ---: | ---: | ---: | ---: |
| Flute, centered qualified-cut baseline | 84.82% | 93.90% | 81 / 102 | 0.8223 |
| Flute, sustained-tail proposals | 84.87% | 93.85% | 81 / 102 | 0.8223 |
| Violin, centered qualified-cut baseline | 80.21% | 98.38% | 75 / 89 | 0.8427 |
| Violin, sustained-tail proposals | 80.33% | 98.38% | 75 / 89 | 0.8427 |

This avoids the maximum-fall regression but does not improve complete-note
matching or clear admission. Of 103 flute intervals before edge exclusion, 14
receive proposals, 14 retain periodic tails, four lack sufficient tail context
and 71 have no sustained drop. The 90 violin intervals yield three proposals,
eight periodic tails, 14 insufficient contexts and 65 without sustained drops.
Flute precision still fails; no threshold retry is selected from these results.

The four previously diagnosed early violin endings remain unchanged. Three do
not establish a terminal low run, and one lacks sufficient low context before
the next attack. Additional source-bound diagnostic windows show why one gate
rule is insufficient. Event 45 ends at frame 126587, yet subsequent centered
windows still estimate 524.110, 525.089, 523.541 and 522.516 Hz at centers 126599,
126679, 126759 and 126839, consistent with its inferred MIDI 72. Later windows
retain energy without a stable period. Other early-ending events likewise retain
fluctuating RMS with mostly no-period results. The report flags pitch windows
crossing an event start or the next attack; those diagnostics are never fed back
into the tested rule. Their existence does not establish ownership of every
sample or an annotated note offset.

Next distinguish pitch-supported continuation of an existing event from
uncertain residual sound, using event context and independent attack boundaries.
Keep unknown activity distinct from silence, preserve quiet notes and repeated
attacks, and do not bridge rests merely because energy remains. This extends
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries)'s evidence requirements;
[WAV-03-REGISTER](MILESTONES.md#wav-03-register) remains the separate prerequisite
for trusting inferred note identity. Neither investigation waits for the other,
and both still precede combined-policy freeze and held-out phrase evaluation.

Evidence is ignored under `build/phrase-sustained-tail/`: `tail.evidence.pas`,
`controls.lpr`, `release.lpr`, build/run logs, `fl.json` / `vn.json` and diagnostic
sine auditions. Checked stable Win64 controls/probes are terminal without owned
warnings. Build with checked flags and core/tool/study unit paths; run `controls`,
then `release CANDIDATE_REPORT ORIGINAL_WAV REFERENCE_NOTES OUTPUT_PREFIX` on the
same Spring development inputs. Source/reference/excerpt binding, unchanged
attacks/pitches, positive durations and next-event nonoverlap retain the preceding
probe's checks. Trace storage and confirmation/context measurement work are
preflighted against existing native bounds.

Diagnostic WAV hashes are
`a9cf5cbd5be9fb149628a8ace414557402a525f78fd807378469eed72aca2d15`
(flute) and
`924af88217de9b782d11f2baa88cbfb471fd2f81632665e9da89adff1d43eecb`
(violin). No maintained API/default, saved-style contract, held-out use,
cross-target claim, listening approval or percentage credit changes. This remains
an experimental condition, not an admitted release provider.

<a id="pitch-continuation-checkpoint"></a>
## Pitch-supported continuation probe — 2026-09-19

A separate experimental rule tests complete 320-frame pitch windows beginning at
the old ending, on the 8-kHz analysis signal. Windows advance by 80 frames, up to
seven attempts, and never cross the next declared attack. Each of the four
80-frame subwindows must exceed the existing AC silence threshold; centered
pitch must admit the event's existing MIDI note within 25 cents. The first failed
window stops the search. The proposed endpoint is the last admitted window center,
at most 639 frames later. This is continuation support, not a measured release.

Eleven analytic controls pass before recorded evaluation: a later ending, an
already-correct ending, a following declared same-pitch attack, a short rest,
quiet continuation, a real octave change, noise, a temporary long gap, an internal
10-ms gap, insufficient context and a phase reversal. No failed window is skipped.
The probe preflights cumulative pitch work and preserves pitches, attacks, event
counts and next-event nonoverlap. Source/reference/excerpt hashes retain the
preceding study's bindings; reference notes enter scoring only.

Against the centered qualified-cut baseline, flute coverage/precision and complete
matches remain 84.8236% / 93.9005% and 81/102. Violin coverage changes
80.2079% → 80.3679%, precision 98.3816% → 98.3847%, and complete matches
75/89 → 76/89 (full-note F1 0.842697 → 0.853933). This modest development result
does not resolve general endings, register or mixture ownership. The rule depends
on an already inferred note identity and stops at uncertain tails.

Checked stable Win64 controls and recorded runs are terminal under ignored
`build/phrase-pitch-continuation/`: `continuation.evidence.pas`, `controls.lpr`,
`release.lpr`, build/run logs, reports and diagnostic sine auditions. No maintained
API/default, saved contract or held-out evaluation changes. Further policy
admission remains under [WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) and
[WAV-03-REGISTER](MILESTONES.md#wav-03-register); this experiment earns no separate
milestone credit.
