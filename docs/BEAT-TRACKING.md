# Local tempo paths and source-aligned pulses

[Home](../README.md) · [Grid candidates](BEAT-GRIDS.md) ·
[Recorded events](EVENT-LEARNING.md) · [Work](WORK.md)

Selected contiguous pulse ranges can now become a reusable changing-tempo
[context profile](WAVE-CONTEXT-ADMISSION.md#changing-tempo-pulse-ranges), retaining
their source offset and driving an audition through actual saved WFC models.

[pythian.beat.track](../src/pythian.beat.track.pas) extends the constant-period
estimator with overlapping windows, a continuous candidate path and explicit
alignment to measured onsets. It retains both the raw grid and adjusted source
positions. This is offline timing analysis, not meter/downbeat inference or a
replacement for the WFC learner and solver.

The [joint candidate comparison](#model-candidate-comparison) recovers
polyrhythm and deception timing without supplied rate/band hints. Later
[source recurrence](#metrical-source-structure) and
[accent parity](#accent-parity-stopped) experiments retain unresolved wrong beat
levels and changing-clock regressions. None is an adopted estimator or admission
policy.

## Bounded candidate qualification protocol — 2026-09-23

This freezes the candidate-only development challenge for
[NS-3_tempo_04](TODO/NS-3_tempo_04.md) before running a new retention policy.
Use only the ARTBeaT (Rico Rosenbusch, 2024, CC BY 4.0) original WAV and supplied
beat CSV pairs below. IDs 02/05/19 are development probes; IDs 01/03/04 form a
recording-disjoint challenge already exposed to earlier timing investigations.
These are separate recordings within one authored dataset, so success cannot
establish independent natural-music or genre generalization. The other 19 IDs
remain closed for the later whole-track timing evaluation.

| Role | ID | WAV SHA-256 | Beat CSV SHA-256 |
| --- | --- | --- | --- |
| Development | 02 | `65c4daf2d97aa6e4550b15b352e5b876644e399dedd2341a9f09e9f352139c5c` | `15252eadcd3fea9de7d1cc62b3382c1086b59a193ff17aed9188971b8649d0e4` |
| Development | 05 | `223826b7c5713bda7d6cfb59e417b5db5ff738154e29c18c9d79c83d52598472` | `222009f01110cd1da40393d0f7c0869b4e9e3261f9fbffceb2f3a03692533595` |
| Development | 19 | `dd9f1bbe228be2ab575d578735462fd4899c00bcf9159121a8e57d554ebe65f2` | `89e13f0d39b2a6111f3435484144131df5ac6276a09922fa387838fbcda8cc8e` |
| Challenge | 01 | `5d14e4a31bc8cfeae19d1883dc6297dc3044cf64095cafe8702a41c1bcb20da2` | `93e21e04c90c103f4c714d601ebd3f92832ca4c30024998e90df43044d1bee13` |
| Challenge | 03 | `2e6abea29bb96a4c695da20de89f27c7b38cd6d91ad72149fa7dbaf3dbe977f1` | `88b6844917e4fa64e75c016154ebfd468a274106fcad058b9d5e25ef065d2dae` |
| Challenge | 04 | `0b59bd9b48188b973275128703e608cc1c5508bd788dcff814e46ec2ba434c17` | `0014e5083d612b5a39a21d4eda7ffd00a4bae1ff695d4d940e27c214b909fed0` |

Require full SHA-256 equality to these source and annotation identities in the
native reports. Run `MeasureWaveBeats` and
`TrackBeatGrids` without a supplied BPM range, band, reference phase or metrical
hint. Use the maintained 40–240 BPM, 0.25-BPM trial grid, 6-second tapered
windows, 1-second hop, original onset policy and 1.5 maximum transition ratio.
For every source, score all zero-based tracker windows whose owned interval
contains at least two supplied reference beats. Retain the one-beat windows as
diagnostic rows. In addition, report development windows 02:14–17 and 05:1–8
even when a row has only one reference beat; 19 is a changing-rate regression.
Owners and analysis spans are exactly those emitted by the native tracker at
the source sample rate; never move an owner to improve a match.

A candidate identity is the full source hash, grid measurement policy and
options, sample rate, zero-based window and pool indices, owner/source spans,
BPM, period and canonical phase. Preserve scalar support fields and selection
order. A retained candidate is eligible only if the native fitter admits it
without any reference lookup. For each candidate, render raw grid points only
inside its owned interval and native observed-span margin. Convert each CSV
timestamp to nearest source frame, half ties later; match points one-to-one
within 30 ms. A window has a *reference-compatible candidate* when one single
candidate reaches both precision and recall at least 0.75 against its owned
references. Choose the evaluation witness by highest F1, then recall, then
precision, then lowest pool index. Report that one candidate's precision,
recall, F1, matches, extras and misses per window, its exact pool index, and
separately the selected path's result. Annotation-selected candidates are
evaluation witnesses, never a stitched inference path or musical-confidence
claim.

The finite retained pool may hold at most 16 candidates per window, with no
more than 512 windows, 64 million fit visits per track or 524288 path-transition
visits. The chosen policy must retain reference-compatible candidates in at
least 90% of eligible 02 windows and 80% of eligible windows in each 01/03/04
recording. Require both beats in 02 window 16, and a retained rate within
0.5 BPM of 75 in 05 windows 1, 2 and 5; record 05/19 all-window candidate
coverage and selected-path full-output accuracy without optimizing selection
here. The authored seven subdivision/phase/mixture controls must retain their
exact existing alternatives.
The added authored control uses 48000 Hz, 432000 source frames and 32 observed
events at frame `4800 + 12000*i`, `i=0..31`. Its intended fast beat is every
event at 240 BPM. Weight is 1 when `i mod 4 = 0`, 0.75 when `i mod 4 = 2`,
and 0.5 otherwise. Require retained candidates within 0.5 BPM of 60, 120 and
240, with both 120-BPM phases represented at 4800 and 16800 frames modulo
period. These are supported alternatives, not equally true beat labels.
A second control uses the same rate and span with no events, then three events
at frames 4800, 16800 and 28800; neither may invent a candidate. These gates
cannot be weakened after reading the new candidate scores.

For every miss, classify source-reference absence/ambiguity, no admitted onset,
no fitted proposal, failed native eligibility, suppression by a named retained
candidate, loss at the 16-slot limit, or retained candidate with wrong path
selection. The current isolated 32-rank trace may explain an omission, but it
does not count as the maintained pool. Save all pre-reference candidate windows
first, then run the independent Pascal matcher; record the source/report hashes,
policy identity, work counts, complete pass/fail rows and unchanged regressions.
Stop if identities, bounds or provenance cannot be replayed; do not tune the
metrical selector or open the reserved evaluation recordings in this batch.

### First current-policy candidate baseline

The maintained [Pascal candidate checker](../tools/pythian.beat.candidates.lpr)
was added after the six current-policy `pythian.beats` reports were saved under
ignored `build/beat-candidate-qualification/reports/`. Stable FPC 3.2.2 Win32
generated every report from the original WAV with the default eight-candidate
pool and no annotation input. The checker then verified full WAV/CSV identities,
all default onset/grid/path settings, exact window geometry, the reported
fit-work and native path-transition bounds, and deterministic path reselection
before using shared `EvaluateEvents` at
30 ms. Run it as
`pythian.beat.candidates REPORT.json REFERENCE.csv SOURCE.wav SOURCE_SHA256 REFERENCE_SHA256`.
JSON goes to stdout and a concise failure summary to stderr. Its per-window
witness and selected path are reported separately.

| Recording | Compatible / eligible windows | Selected raw full-output F1 | Frozen gate |
| --- | ---: | ---: | --- |
| 02 arpeggio | 12 / 17 | .9762 | Fails 90% candidate coverage |
| 05 doubling | 7 / 9 | .8475 | Diagnostic; 75 BPM retained in windows 1, 2, 5 |
| 19 acceleration | 13 / 14 | .8974 | Diagnostic changing-rate regression |
| 01 calibration | 9 / 10 | .9744 | Passes 80% candidate coverage |
| 03 deception | 18 / 18 | .9885 | Passes 80% candidate coverage |
| 04 polyrhythm | 8 / 14 | .3913 | Fails 80% candidate coverage |

The five missing-compatible 02 windows are 0, 9, 10, 14 and 15. Six such 04
windows are 0, 5, 10, 15, 20 and 21. Some have missing reference matches;
others match all references but emit too many extra grid points for the frozen
precision gate. Their loss stages are not yet classified. Current 02 window 16
has a retained and selected index-2 candidate matching both owned references
without extras. The older diagnostic rank-13 loss was real for its isolated
prototype, but is not a current-policy defect. A pool-capacity change based on
that old row would chase the wrong cause.

These full-output F1 figures count all selected raw points and use the shared
30-ms scorer; earlier historical figures sometimes excluded predictions
outside the annotation span and are not direct numerical comparisons. This
checker does not establish a new candidate policy or qualified pool. The next
bounded investigation must trace the current failed windows through admitted
onsets, positive fits, local-peak eligibility, suppression and capacity, then
choose a retention change only if that trace shows one can satisfy the frozen
gates. No untouched timing recordings, source-selected bands, style sources or
third-party inference runtimes were used.

The two representative inference report SHA-256 values are
`359263bc20f689aba90e282457a479cdfc759d4512b44854f1d887da5314a3ad`
(02) and `f96c0b541f7843b3f927a69ac157bb3fc0c999a392c004c9b76ccef447705d53`
(04); checked score JSON hashes are
`3225bab487de72b19af9159aef6630ba1cdf1086d323d30e1f6d176d8feef2fd`
and `f88784b7fd50abe008a6cbd83fee73db37ae43f9f57697a39cdf4d25f12d81f4`.
The current eight-slot authored fast/half/double/phase and absent-observation
checks pass under stable Win32/Win64. Stable Win32/Win64 checker builds pass;
the 02 score JSON is byte-identical across targets and to a same-target replay.
Wrong reference identity and stale measurement-policy inputs fail cleanly.
No task credit or milestone percentage changes.

### Current-policy omission-stage trace

The optional `--trace` flag on the same Pascal checker replays the saved
observations through the maintained fitter and verifies every resulting pool
entry and the aggregate fit-work count against the pre-reference report. It
then scores positive trial proposals against the frozen reference to identify
the latest stage reached by a *compatible* proposal. This is post-inference
diagnosis; annotations neither enter fitting nor choose the output path.

| Recording | Missing window | Latest compatible stage | Admitted onset near reference beats | Other admitted onsets in owner | Witness extra grids supported by those other onsets |
| --- | ---: | --- | ---: | ---: | ---: |
| 02 | 0 | No compatible fit | 2/3 | 2 | 0 |
| 02 | 9 | Local peak filtered | 2/2 | 17 | 1 |
| 02 | 10 | Suppressed by selected trial 832 | 3/3 | 9 | 0 |
| 02 | 14 | Local peak filtered | 2/2 | 15 | 1 |
| 02 | 15 | Local peak filtered | 2/3 | 15 | 0 |
| 04 | 0 | No compatible fit | 1/2 | 4 | 0 |
| 04 | 5 | Capacity | 1/2 | 10 | 0 |
| 04 | 10 | No compatible fit | 1/2 | 20 | 0 |
| 04 | 15 | Local peak filtered | 1/2 | 10 | 0 |
| 04 | 20 | No compatible fit | 2/2 | 25 | 2 |
| 04 | 21 | Capacity | 2/2 | 12 | 1 |

The `no_compatible_fit` label means positive fits exist, but none meets *both*
0.75 precision and recall on that owned interval. It does not mean the fitter
returned no proposals. In 02 window 10, one compatible proposal reaches local
peak eligibility but is removed by trial 832. In 04 windows 5 and 21, compatible
peak-eligible proposals remain after the eight slots fill. Windows 9/14/15 in
02 and 15 in 04 lose compatible proposals before that selection stage. A larger
pool alone therefore cannot clear the frozen coverage gates.

The onset columns compare admitted native observations with the supplied beat
annotations at 30 ms. An onset away from an annotated beat may be a musical
subdivision or another valid sound; the count does not prove an acoustic false
onset. Likewise, an annotated beat with no admitted onset may still be audible
in the source. The 04 window-20 witness has two grid points supported by such
other onsets and is precision-incompatible despite both references having nearby
observations. Source-pulse presence or absence still needs independent review;
it cannot be inferred from this trace. Authored empty and three-observation
controls preserve unknown output without inventing pulses.

The other failed rows are 01 window 0 and 05/19 window 0, all with no
reference-compatible positive fit; 05 window 4 is a capacity loss. Recording
03 has no missing compatible window. All six saved reports replay with exact
pool and aggregate work parity. Stable FPC 3.2.2 Win32 and Win64 checked beat
and tracker tests pass, and both targets agree on the 02/04 failure stages.
Fresh normal Win32 inference for 02/04 is byte-identical to the original
reports (SHA-256 `359263bc20f689aba90e282457a479cdfc759d4512b44854f1d887da5314a3ad`
and `f96c0b541f7843b3f927a69ac157bb3fc0c999a392c004c9b76ccef447705d53`).
Trace artifacts are ignored under `build/beat-candidate-trace/`.
The checked Win32 trace JSON SHA-256 values are
`18c514cfdde19ac50c46a5cdaab61176a9fb4ae92b8a6fd24b307ebf9706eae1`
for 02 and `5e19c37cd7cbbaa9f87abe0637c3e1eb34de5b413171beb8ae707a176f15e83d`
for 04.

This is the second nonclosing batch after the protocol criterion. The source
pulse question, no-compatible-fit windows and recorded candidate gates remain
open, so no further tempo_04 criterion or task credit is claimed. The next
policy attempt needs a predeclared way to address fit and retention separately
within the frozen work and coverage bounds; another pool-size walk would not
answer the source-pulse ambiguity.

### Shared-arpeggio source-isolation screen stopped — 2026-09-23

The [ARTBeaT publisher](https://audiolabs-erlangen.de/resources/MIR/2024-ARTBeaT)
describes 02, 03 and 04 as opening with the same arpeggio. A fixed Pascal
screen asked whether this means a directly reusable *audio waveform* that
could be subtracted to isolate other source pulses. Its ignored policy in
`build/beat-shared-stem/PROTOCOL.md` froze all three original WAV hashes, the
[0.5, 2.5)-second source interval, stereo comparison, at most 100-ms lag, one
gain in [0.5, 2.0] and normalized residual RMS at most .001 (-60 dB). A
passing intro would only justify a later full-overlap source audit; it would
not itself label a pulse or qualify a beat candidate.

Checked stable FPC 3.2.2 Win32 bound all three original WAVs and compared 02
to 03 and 04. The source RMS was .032481 in both pairs. The best unconstrained
02-to-03 fit was lag -403 frames, gain -.187409, residual .983200; 02-to-04
was lag -120 frames, gain .126095, residual .990077. Both fail the frozen gain
and residual gates by a wide margin. The first run reported no eligible
gain/lag; one diagnostic rerun retained the same acceptance gate while
reporting the best unconstrained fits. Both checked runs reported zero
unfreed blocks. Exact ignored policy, Pascal source and JSON lines are under
`build/beat-shared-stem/`.

The publisher's musical description does not imply a bit-identical shared
stem. Stop this subtraction path without moving the interval or retuning its
limits. No source-pulse labels, candidate-policy change, task criterion or
credit follow. Tempo_04 still needs independently reviewable acoustic pulse
status and a predeclared fit/retention decision within its frozen gates.

<a id="accent-parity-stopped"></a>
## Alternating accent strength does not resolve beat level — 2026-09-23

The prior polyphonic failure retained a wrong fast pulse with strong source
recurrence and model agreement while a slower 96-BPM candidate had strong source
recurrence but no model agreement. A distinct fixed Pascal experiment tested
whether alternating low/mid/high accent mass exposes weak subdivisions. For each
existing half/same/double-period grid it compared per-band even/odd mean weights
in both analysis halves, multiplied the smaller parity consistency by the old
recurrence, and bounded the model-agreement contribution by that source score.
The frozen hypothesis, exact formula, controls, input scope, nine-case budget and
stop gate are retained in ignored `build/beat-accent-parity/POLICY.md`. No BPM,
band or threshold was selected per recording.
The model-event inputs were frozen historical outputs from the retired external
runtime comparison; this batch executed only Pascal code. They remain diagnostic
data and cannot establish a Pascal-native provider. Any future adopted beat
experiment must generate every inference observation through Pascal-owned code.

Checked FPC 3.2.2 Win32 controls passed for uniform fast pulses, 1/.25 alternating
accents, alternating band roles, common timing offset, gain scaling, absent/short
evidence and taper boundaries. The ablation reproduced each prior selected path
and raw clock exactly. All nine candidate and ablation reports were saved before
the unchanged independent Pascal 30-ms matcher scored them. The candidate's
reference-range F1 and full-output extra counts are:

| Input | Prior source recurrence F1 | Accent parity F1 | Full extras |
| --- | ---: | ---: | ---: |
| 01 calibration | .974359 | .974359 | 0 |
| 02 arpeggio | .987952 | .987952 | 0 |
| 03 deception | 1.000000 | 1.000000 | 1 |
| 04 polyrhythm | .986301 | .395604 | 38 |
| 05 doubling | .800000 | .608696 | 23 |
| 19 acceleration | .950000 | .886076 | 4 |
| Authored regular | 1.000000 | 1.000000 | 0 |
| Authored polyphonic | .033898 | .000000 | 45 |
| Authored tempo change | .863636 | .956522 | 0 |

The fixed nonregression and polyphonic gates fail. All 239 selected polyphonic
grid points have nearby band support, yet none of its 20 reference beats match.
The wrong selected fast candidates have parity consistency about .83–.95, so
the expected alternating contrast is not present in these observations; nearby
slower candidates also look parity-consistent. Full support and low unknown
counts therefore cannot certify metrical identity. The polyrhythm regression
shows that this parity factor also suppresses useful alternatives elsewhere.

**Decision:** stop this candidate without changing weights, windows, band
definitions or thresholds. Keep the maintained selector and the prior passing
development baseline. This is the second nonclosing metrical investigation
batch; reassess the observation model before another experiment. The next
candidate must distinguish musical pulse level from correlated band activity
and shared wrong model events using Pascal-owned inputs throughout, while
preserving true fast beats and independent
unknown/coverage accounting. No maintained code, independent evaluation,
listening verdict or task credit changes. Exact private report/source bindings,
the deterministic summary (SHA-256
`7146dc24a0e122e73ee66606c65a505f5af0a984e61f188fe9cb98ec62540a9e`)
and failure evidence remain under ignored `build/beat-accent-parity/`. These
short runs do not qualify many-hour throughput; a sampled peak memory result was
not retained for this failed candidate.

<a id="metrical-source-structure"></a>
## Repeated source accents and competing beat levels — 2026-09-21

The next fixed experiment compares each existing candidate period with half and
double that period, using the cached low/mid/high onset weights. At each grid
point it keeps the strongest nearby accent per band with the fixed 30-ms linear
taper. Adjacent grid vectors retain their band identities; their weighted overlap
is measured separately before and after the analysis midpoint. The smaller mean
recurrence is retained. These are acoustic bands, not inferred instrument roles.

The same-period score is compared with both alternative levels. Unavailable
alternatives remain unresolved, and tied levels remain explicitly ambiguous.
When all levels are available, support is the same-period recurrence divided by
their maximum. Otherwise it retains the same-period recurrence without assuming
that an unmeasured competitor is worse. This avoids excluding genuine slow beats
merely because the analysis window cannot contain enough double-period context.

The candidate combines this source support equally with model agreement when
at least two model events exist in scope. Otherwise it uses affirmative repeated
source support alone. It preserves all prior candidates, phase alternatives,
restarts, default path costs and clock reconstruction. The ablation removes the
new evidence and reproduces the previous method's nine complete selections and
raw clocks. Neither a chosen path nor repeated accents establish metrical confidence.

After the fixed observation controls passed QA, all predictions were saved before
reference scoring. The existing independent event matcher produced these results:

| Input | Prior method / ablation F1 | Source-structure F1 | Source-structure full-output F1 |
| --- | ---: | ---: | ---: |
| 01 calibration | .974359 | .974359 | .974359 |
| 02 arpeggio | 1.000000 | .987952 | .987952 |
| 03 deception | 1.000000 | 1.000000 | .988506 |
| 04 polyrhythm | .986301 | .986301 | .972973 |
| 05 doubling | .772727 | .800000 | .786885 |
| 19 acceleration | .656250 | **.950000** | .950000 |
| Authored regular | 0 | **1.000000** | 1.000000 |
| Authored polyphonic | .033898 | .033898 | .029851 |
| Authored tempo change | 0 | .863636 | .863636 |

All primary scores use the unchanged 30-ms tolerance and reference-range policy;
the last column retains endpoint extras. Acceleration has 38 matches, two extras
and two misses. Doubling gains matches but still has eleven full-output extras.
The polyphonic case retains 46 full-output extras. Recovering regular pulses when
the model emits none is useful evidence, but the general nonregression gate fails.

**Decision:** reject general adoption after this comparison, without a weight or
threshold retry. Preserve the acceleration/regular gains as development controls;
repeated band accents still do not resolve the shared wrong polyphonic beat level,
and authored changing-clock coverage remains insufficient. No maintained provider,
format, held-out evaluation, listening verdict or task credit changes.

The original source/model/band reports and policies remain unchanged. The first
candidate attempt stopped before emitting a report because the core requires a
phase smaller than its period. Reducing phase modulo the compared period preserves
the exact lattice; QA passed the added nonzero-phase control before resumption.
The original code/failure logs and correction identity are retained separately.
An earlier control-only exit cleanup leak was also fixed and retested by QA.

Evidence is ignored under `build/beat-metrical-structure/`: frozen policy,
geometry correction, native source, nine ablations, nine candidate reports,
eighteen score reports and process records. Final checked Win64 QA independently
recomputed selected recurrence across all nine comparisons, verified source/policy/
code bindings and exact ablation parity, and passed with no unfreed blocks. All
36 successful prediction/scoring logs are also leak-free. The first audit exposed
rounding in its untyped clamp expression; an explicit Double calculation fixed
the audit without changing predictions, policy or the 1e-9 comparison tolerance.
Both failed audit logs are retained separately.

The candidate leaves two of 145 owner windows unknown, retains 34 ambiguous
selections and uses source evidence with missing model events in 26 selections.
All 307 output frames have nearby band support, including the wrong polyphonic
pulses: source support alone does not establish the correct metrical level.
The 18 successful prediction processes took 32.14 seconds in total; the slowest
input took 3.239 seconds and the largest sampled process peak was 48,644,096 bytes,
within the declared budgets. These short cached-report workloads do not establish
many-hour throughput. The experiment allowance is consumed; no additional fit
or task credit follows from this audit.

<a id="model-candidate-comparison"></a>
## Model observations and retained candidates — 2026-09-20

The preceding model-only experiment now has a joint, source-bound development
comparison. All four cached flux candidate pools participate: full, low, mid and
high, at most eight candidates each. No reference rate, band, timing label or
per-recording selection enters inference. The unchanged maintained
`SelectBeatTrackPath` and `ReconstructBeatClock` APIs select/reconstruct the result.

Each candidate is compared with model events over the same original analysis
and observed-source span. Its score is symmetric one-to-one agreement within
30 ms, `2*matches/(grid_count+model_count)`. At least two matches offer it to the
path; otherwise the pool stays empty. Original source scores and candidate
identities remain visible. Default path costs/ratio bounds are unchanged, all
supplied restart barriers survive, and reconstruction restores the selected
band's observation span. Onset snapping is disabled to isolate rate/phase choice.
Invalid model source positions are counted separately and never become clock
inputs. An empty model does not trigger a replacement presented as accepted.

### Development results

All nine inference reports were saved before scoring. The established 30-ms
reference-range metric is shown alongside full-output accounting:

| Input | Native default/context | Model alone | Joint candidates | Joint full-output | Unknown owner windows |
| --- | ---: | ---: | ---: | ---: | ---: |
| 01 calibration | .974359 | 1.000000 | .974359 | .974359 | 0/10 |
| 02 arpeggio | .987952 | 1.000000 | **1.000000** | 1.000000 | 0/18 |
| 03 deception | 1.000000 | .705882 | **1.000000** | .988506 | 0/19 |
| 04 polyrhythm | .373626 | .918919 | **.986301** | .972973 | 0/24 |
| 05 doubling | .847458 | .790698 | .772727 | .772727 | 0/14 |
| 19 acceleration | .897436 | .622951 | .656250 | .656250 | 0/18 |
| Authored regular | 1.000000 | 0 | 0 | 0 | 14/14 |
| Authored polyphonic | 1.000000 | 0 | .033898 | .029851 | 0/14 |
| Authored tempo change | 1.000000 | 0 | 0 | 0 | 14/14 |

Polyrhythm now reaches the earlier supplied-rate/band result automatically:
36 matches, no in-range extras, one miss and one excluded prediction. Selection
uses multiple bands; selected analysis-span candidate F1 ranges from .9 to 1.0
against the reference, while bounded full-clock reconstruction still misses one
beat. Deception has 43 matches and one excluded output; the polyphonic control
has one match, 38 in-range extras, 19 misses and eight excluded outputs.
These clocks are reconstructed hypotheses, not newly admitted observed beats.

**Agreement cannot serve as confidence.** A separate post-inference audit scores
selected candidate grids against references over their analysis spans. On the
doubling input, windows 9/10 select 75.25 BPM with model agreement **1.0**, yet
reference F1 is only **.636364**. Six doubling windows have agreement at least .8
and reference F1 below .8. Two acceleration windows do too; window 16 reaches
.909091 agreement with .555556 reference F1. These .8 audit cutoffs summarize
failure cases only; they are not fitted or proposed inference thresholds.

The declared general nonregression requirement fails. Keep the automatic 03/04
gains as controls, but do not adopt this selection rule or an agreement gate.
The remaining problem includes common metrical errors and unmodeled/missing
pulses, not merely disagreement between two providers. Further work must represent
credible alternative beat levels and changing patterns, with independently
validated evidence for choosing or declining them. The model's missing regular
events and the mutually supported wrong polyphonic pulse also remain constraints.

### Evidence and limits

The independent dynamic-programming matcher checks all **4572** candidate/event
comparisons, including rejected candidates; source/report hashes, original
candidate identities and matched intervals agree. Tolerance edges, one-to-one
support, doubled-rate and missing-event controls pass. The complete 04 inference
report replays exactly on checked stable Win64. Final compile/run logs have no
owned warnings or unfreed blocks; the initial managed-array initialization warning
was corrected before inference. Work is bounded to 32 owners, 32 candidates per
owner, 128 model events, 64 local grid points and 524288 matching visits. The
largest actual matching count is **15336**. This cost excludes the earlier model
inference and band fitting; the latter's production work-limit gap remains open.

All processes are terminal under `build/beat-model-candidates/`. Policy, native
consumer/auditor, complete predictions, unchanged reference scoring, hashes and
failure diagnostics are retained. No maintained unit, package, format, runtime
dependency, held-out corpus or listening verdict changes. Network export fidelity
and provider calibration remain [validation prerequisites](MILESTONES.md#wav-validation).
The [pulse backlog](MILESTONES.md#wav-02-pulse) now records the demonstrated common
error and the automatic gains to preserve; this comparison earns no completion
points.

<a id="learned-model-reference"></a>
## Learned beat-model reference comparison — 2026-09-20

This is a historical comparison. An owned Pascal caller ran the published small1
ONNX export of [Beat This!](https://github.com/CPJKU/beat_this) through the native
ONNX Runtime CPU C API on 2026-09-20. The
[pinned acquisition and notices](PROVENANCE.md#beat-model-reference) remain under
ignored build output for provenance. The user's later Pascal-only instruction
prohibits running this foreign inference runtime again. It supplied neither a
Pascal network port nor an admitted musical provider, and there is no maintained
ONNX caller or build hook in this branch.

The comparison uses only the six existing ARTBeaT development recordings and
three authored controls. No reference timestamp, rate range or selected band
enters inference. Every prediction was saved before reference scoring. Native
WAV decoding, channel averaging and centered sinc conversion supply 22050-Hz
mono audio to the exported log-mel graph. The probe follows upstream minimal
peak processing and chunk aggregation, retaining every beat/downbeat logit,
unsnapped downbeat and source-coordinate prediction. Downbeats are unscored;
logits are not calibrated confidence or proof of an observed onset.

The declared probe bound is 30 seconds, 1501 mel frames, at most two chunks and
one inference thread, with unchanged Pythian resampling work limits. Existing
inputs use one chunk; synthetic coordinate controls cover the two-chunk join.
The resampler differs from upstream soxr. Export/network fidelity and full
upstream waveform-to-output parity are not established by this comparison.

### Results and decision

These are beat F1 scores under the existing 30-ms, ordered one-to-one matcher.
The reference-range column uses the established first/last-reference scope;
the full-output column includes every prediction, including endpoint extras.
The independent dynamic-programming match audit agrees in every case.

| Development input | Default/context F1 | Learned reference F1 | Full-output F1 | Reference-range matches / extras / misses |
| --- | ---: | ---: | ---: | --- |
| 01 calibration | .974359 | 1.000000 | 1.000000 | 20 / 0 / 0 |
| 02 arpeggio | .987952 | 1.000000 | .988235 | 42 / 0 / 0 |
| 03 deception | 1.000000 | .705882 | .695652 | 24 / 1 / 19 |
| 04 polyrhythm | .373626 | **.918919** | **.906667** | 34 / 3 / 3 |
| 05 doubling | .847458 | .790698 | .772727 | 17 / 0 / 9 |
| 19 acceleration | .897436 | .622951 | .622951 | 19 / 2 / 21 |
| Authored regular | 1.000000 | 0 | 0 | 0 / 0 / 24 |
| Authored polyphonic | 1.000000 | 0 | 0 | 0 / 19 / 20 |
| Authored tempo change | 1.000000 | 0 | 0 | 0 / 0 / 24 |

The reference range excludes one prediction each on 02/03/04/05 and four on the
authored polyphonic control; it excludes none on the others. At 70 ms the
polyrhythm reaches .945946, while all three authored controls still score zero.
The wider tolerance is diagnostic and does not replace the 30-ms comparison.

**Do not replace the maintained estimator with this model.** It obtains useful
automatic metrical evidence on the difficult polyrhythm without the preceding
study's supplied rate/band, but fails the declared nonregression requirement.
No beats on a supported input cannot be interpreted as proof of no pulse.
The next meaningful comparison should test source-supported joint use of retained
phase/rate alternatives and model observations, explicitly retaining conflicts,
missing evidence and unknowns. Per-recording oracle selection, a blanket fallback
on empty output, or a larger model alone would not establish that contract.

### Verification and limits

Silence produces no beat/downbeat events. Native mathematical log-mel controls
for silence, two tones and a chirp compare 1408 cells each against the graph;
maximum absolute log-feature errors are 0, .000171103 and .000115734, below the
predeclared .001 tolerance. This verifies scoped preprocessing, not network
export fidelity. Peak plateau/deduplication, snap ties and chunk coordinate/
coverage controls pass. The complete 04 report replays byte-for-byte.

The initial 02 run correctly rejected an endpoint prediction at frame 771750,
exactly its exclusive source end. A declared accounting amendment retains such
raw predictions and flags them outside the source rather than clipping or
silently dropping them. They are diagnostic events, not valid clock positions.
Initial 01 logits/events are unchanged by that reporting amendment. Source/score
hash bindings, event coordinates, complete-prediction accounting and endpoint
flags pass the native audit. Initial compile errors and endpoint failure logs
are retained; final checked stable Win64 runs report no owned warnings or
unfreed Pascal blocks. External runtime allocations are outside heaptrc's scope.

Recorded runs take approximately 9.6–20.3 seconds for 9.75–23.1 seconds of audio
on the local host. These include resampling, model/session loading, inference,
hashing and report output; they are not isolated model throughput or a many-hour
cost guarantee. All processes are terminal. Evidence is under
`build/beat-model-reference/`, with policy, accounting amendment, native sources,
acquisition pins, complete outputs and a checkpoint hash ledger.

No unused evaluation recording is consumed. The published annotation-directory
inventory does not list ARTBeaT, but this does not independently prove training
disjointness of every source. These inputs were already development data here.
Supported-case calibration, export fidelity, independent recording acceptance,
practical native deployment and maintained adoption remain under
[WAV-VALIDATION](MILESTONES.md#wav-validation) and
[WAV-02-PULSE](MILESTONES.md#wav-02-pulse). The comparison earns no completion
points and supplies no synthesis/style listening verdict.

## Window and path contract

`TrackBeatGrids(observations, sampleRate, sourceFrames, gridOptions, trackOptions)`
accepts the same ordered, unique, positively weighted source positions as the
grid estimator. Source identity and observation admission remain caller-owned.
The returned windows, candidate arrays and frame arrays are detached. Invalid
configuration, geometry or work rejects without replacing an assigned result.

Each half-open hop interval owns raw output grid points. Analysis is centered
on its midpoint and clipped to the source. Defaults are six-second windows and
one-second hops. Optional Hann tapering, enabled by default, emphasizes nearby
onsets. Weights are normalized before tapering; zero or underflowed tapered
weights are omitted. The original observations are unchanged. Each window uses
the existing candidate estimator with the same grid options.
The current estimator retains phase families using explicit concentration and
matched-weight measurements; see [its contract](BEAT-GRIDS.md#method). Candidate
index is selection order and does not assert a musical beat level.

Dynamic programming maximizes summed candidate score minus transition penalties:

- Tempo cost: `TempoPenalty * abs(log2(rightBpm / leftBpm))`.
- Phase cost: `PhasePenalty` times the right-grid cycle distance from the nearest
  left-grid pulse at the hop boundary, measured to its nearest right-grid pulse.
- A tempo ratio outside `[1/MaximumTempoRatio, MaximumTempoRatio]` has no edge.

Default penalties are 0.5 each and the maximum adjacent ratio is 1.5. Earlier
candidate indices win cost ties within `1e-12`. A window without candidates ends
the current path. If no candidate is reachable under the ratio bound, the current
window starts a new path. All alternatives and selected indices remain visible;
`StartsNewPath` records these boundaries. A ratio bound between neighbors does
not prove the selected metrical level is correct or forbid gradual octave drift.

This is an offline optimum over the retained window candidates. Later evidence
can affect earlier choices. It does not promise frozen prefixes, realtime latency
or the continuation semantics of Pythian's separate WFC generation streams.

## Raw grids and onset alignment

<a id="candidate-path-api"></a>
### Reselecting retained candidates

`SelectBeatTrackPath(windows, trackOptions)` exposes the existing path optimizer
without repeating measurement or fitting. Callers can filter retained candidates
using explicitly supplied base context, then select their phase/rate path together.
Only `MaximumTempoRatio`, `TempoPenalty` and `PhasePenalty` are used from the
options. Input `StartsNewPath` forces a continuity break; empty candidate windows
and impossible joins also break the path. The automatic tracker keeps its existing
behavior and does not acquire a new musical prior.

The returned windows and candidate arrays are detached. Indices address the
supplied pool; callers retain any mapping to an earlier unfiltered pool.
Other analysis metadata is copied. Reconstruct frames from the new selections:

```pascal
SelectedWindows := SelectBeatTrackPath(FilteredWindows, TrackOptions);
Clock := ReconstructBeatClock(SelectedBeatClockWindows(SelectedWindows),
  Observations, SampleRate, SourceFrames, ClockOptions);
```

Do not reuse a prior track's frame arrays after changing its selection. Source
identity, score meaning, consistent BPM/sample-frame periods, candidate filtering
and musical pulse interpretation remain caller-owned. The optimizer's sum over
overlapping windows is not a calibrated likelihood or admission confidence.
Deterministic ties likewise do not establish certainty.

The query accepts 1..512 contiguous sample-frame owners, at most 32 candidates
per owner and at most 524288 adjacent candidate-pair visits. Used scalar fields
must be finite; candidate BPM is 20..400, score 0..1, period .15..1152000 samples,
and phase magnitude at most the native clip-frame bound. These broad period
bounds cover the supported sample-rate/BPM envelope; they do not verify a source
rate. Unused analysis metadata is not re-admitted. Invalid calls preserve an
assigned result. Checked stable Win32/Win64 and trunk Win32 fixtures cover an
independently enumerated optimum, transient competing phases, deterministic ties,
explicit/missing/incompatible breaks, bounds and ownership. The
[conditional recorded comparison](#conditional-phase-path) verifies its use and
limits; [current packages](PACKAGING.md#current-api-delivery) deliver the API.

### Rendering a selected path

Grid points are restricted to the owning hop interval and local observed span
expanded by the grid timing tolerance. Unsupported windows produce no points;
the tracker does not extrapolate through an evidence-free gap.

`GridFrames` retains those raw positions. `FrameWindows` identifies the window
and selected candidate that produced each raw point. At joins between contributing
windows, `JoinGapRatio` compares the raw interval with the mean of the two periods.
Ratios below 0.5 or above 1.5 set `JoinUncertain` and increment `SeamIssues`.
These are raw-grid diagnostics, not a guarantee of aligned interval regularity
or musical accuracy. No raw point is silently deleted or moved by this audit.

`SnapToleranceSeconds` enables a separate, explicit alignment stage. Its default
is 100 ms, additionally capped at one fifth of the selected local period; zero
disables it. Adjacent raw points split the search space at their midpoint, with
ties belonging to the earlier point. Within this disjoint cell and tolerance,
choose the onset maximizing normalized input weight times
`1 - distanceFrames / (toleranceFrames + 1)`. Equal scores retain the earlier
onset. This favors nearby strong attacks while preventing duplicate use of an
onset or reversal of output order.

`Frames` contains the aligned result; `ObservationIndices` identifies the actual
input onset, or is -1 when a raw point remains unaligned. Every displacement is
recoverable from `Frames - GridFrames`. An aligned point may cross its raw owning
hop boundary, but the output remains strictly ordered. Alignment can choose a
spurious onset; its index is provenance, not proof of a musical beat. Missing
attacks remain predicted grid points rather than fabricated source observations.

## Bounds

There are at most 8192 input observations, 512 windows and 65536 output points.
Windows and hops are positive frame counts with hop no larger than window.
The existing per-window fitting budget remains 16 million conservative fit
visits; their aggregate is capped at 64 million and checked before fitting.
The grid's candidate limit bounds path work to at most 32-by-32 transitions per
neighboring window. Tapering and source alignment add bounded observation walks.
`FitWork` reports the conservative fit budget, including points later tapered out.
The estimator and tracker share `BeatGridFitWork`; windows with fewer than four
observations incur no fitting visits. Histogram/phase work is included for the
remaining windows. Neither the window-count bound nor batching overrides this
aggregate budget.

Maximum tempo ratio is configurable from 1 to 4, transition penalties from 0 to
10 and alignment tolerance from 0 to 200 ms. All real options must be finite.
Native sample/source bounds and minimum period are inherited from the grid API.
The tool's default one-second hop therefore limits it to 512 seconds; library
callers can choose other bounded windows/hops or analyze explicit excerpts.

## Native inspection

```text
pythian.beats INPUT.wav OUTPUT.json [MIN_BPM MAX_BPM] --track [--clock linear|step [--alignment-context]] [--audition OUTPUT.wav]
```

`--clock` adds a continuous phase reconstruction of the existing selected local
path and uses it for the optional audition. `local_track` remains in the report;
`continuous_clock` records shape/options, phase segments, numeric ambiguity,
unavailable intervals and each raw/aligned point with its source observation.
Without this flag, report and audition behavior are unchanged. The command does
not adopt the experimental joint-timing selector or imply automatic beat-level
admission. In particular, changing reconstruction alone cannot fix a wrong
selected tempo. See the [selected-clock API](#selected-clock-api).

The ordinary fixed-grid mode retains its arguments and source-overlay behavior,
using the current [measurement fields](BEAT-GRIDS.md#current-adoption-evidence--2026-09-19). Track
mode also records the global candidates for comparison, then adds `local_track`
with all settings, window candidates, path choices, raw and aligned positions,
observation indices, adjustments, restarts and grid-seam diagnostics. A global
candidate rank cannot select a local path and is rejected with `--track`.

The audition marks the aligned positions over the original recording using the
shared cue renderer. No source audio is retimed or newly composed. An empty track
can be reported; requesting its audition rejects before output publication.
WAV and JSON writes remain separate, with the same filesystem limits as fixed
grid inspection.

<a id="selected-clock-api"></a>
## Selected pulse clock API

[pythian.beat.clock](../src/pythian.beat.clock.pas) owns bounded reconstruction
independently of the tracker, WAV analysis and WFC. Call
`ReconstructBeatClock(windows, observations, sampleRate, sourceFrames, options)`.
Each `TBeatClockWindow` supplies one explicit period/phase, a half-open owner
interval, an observation support span, `HasPulse` and `StartsNewRun`. Windows must
cover the source in order. Missing pulses and explicit restarts break the clock;
unused pulse/support fields in missing windows are ignored. The caller owns
selection, source identity, support admission and the musical meaning of a pulse.

Existing tracker callers can use `SelectedBeatClockWindows(track.Windows)`. This
copies selected scalar fields into detached clock windows and preserves missing
candidates and `StartsNewPath`. It does not select an alternative or infer context.

```pascal
ClockOptions := DefaultBeatClockOptions;
ClockOptions.Shape := bcsStepWhenFeasible;
Clock := ReconstructBeatClock(SelectedBeatClockWindows(Track.Windows),
  Observations, SampleRate, SourceFrames, ClockOptions);
```

The default shape is `bcsLinear`. `bcsStepWhenFeasible` permits the endpoint-
constrained alternative described in the [clock study](#continuous-clock).
Neither is a general accuracy upgrade for every selected path. `Segments` retains
phase endpoints, interpolation periods, integral residuals, availability, numeric
ties, step parts and source window indices. Cycles restart locally for each run;
they are not song beat numbers. A feasible step is not a detected musical change,
and zero numeric ties is not evidence of confidence.

`RawFrames`, `Frames`, `FrameWindows`, `Periods` and `ObservationIndices` retain
the unaligned crossings, aligned output and their provenance. `FrameWindows`
describes the raw owner even when alignment crosses an adjacent owner edge within
the same run. Alignment cannot cross a missing interval, explicit restart or
rejected phase interval. Rejected phase spans exclude integer sample positions
in `[ceil(start), ceil(end))` from alignment.
`SupportToleranceSeconds` defaults to .03; `SnapToleranceSeconds` defaults to .1,
additionally capped at one fifth of the reconstructed period. Both accept 0..0.2;
zero snap tolerance disables alignment. Missing onsets retain raw predictions
and observation index -1.

`AlignmentMode` defaults to `bcaIndependent`, preserving existing output.
The optional `bcaNeighbourSupported` mode requires positive snap tolerance and
retains every decision in `AlignmentChoices`; see the
[alignment API](#alignment-api) for support and unknown semantics.

The API admits up to 512 windows, 1024 segments, 8192 observations and 65536
candidate integer crossings. `CrossingWork` counts crossings before support
filtering; the aggregate budget is checked before rendering. Selected periods
must represent 20..400 pulses/minute and finite source-bounded phases. Observation
positions are ordered, unique and source-bounded with finite weights in (0,1].
Returned arrays are detached; invalid inputs leave an assigned result unchanged.
These are per-call bounds, not a many-hour ingestion claim.

The maintained [fixture](../tests/pythian.tests.beat.clock.lpr) checks analytic
phase controls, exact steps, ambiguity, gaps/restarts, rounding, alignment,
ownership, malformed inputs, maximum windows and aggregate work rejection.
Checked stable Win32/Win64 and trunk Win32 clock and existing track/context
fixtures pass. Native adoption matches every studied clock field on six WAVs,
both selected paths and both shapes; source selections remain frozen. The
tool's existing source/measurement/track fields replay exactly, and both clock
auditions reopen with matching hashes, source geometry and no clipping. Evidence
is under `build/beat-clock-adoption/`. This adopts reconstruction only; arrangement,
early change timing, endpoint coverage and metrical admission remain open.

Explicitly reviewed ranges can now use
[`AdmitBeatClockRange`](WAVE-CONTEXT-ADMISSION.md#reconstructed-clock-ranges) to
reach the existing saved context/WFC providers. It reconstructs the selected
inputs and rejects ranges crossing missing, restarted or ambiguous/unavailable
phase evidence. The caller still declares quarter-note meaning.

## Evidence — 2026-09-14

The [focused fixture](../tests/pythian.tests.beat.track.lpr) follows an independently
authored 120-to-100 BPM impulse clock at 8000 Hz. Every aligned position retains
the matching source index. It also checks raw hop ownership, disabled alignment,
detached results, strict ordering, silence, explicit gap restarts, duplicate input
and preflight window/aggregate work limits. Equal-strength pulses exposed phase
smearing at the abrupt change; the raw frame and its explicit source adjustment
remain available rather than relaxing the reference timing tolerance.

The [WAV laboratory](../tools/pythian.beat.lab.lpr) now records global, raw local
and aligned local results against the same authored reference interval and 30 ms
tolerance. Reference WAV bytes are unchanged from the earlier laboratory.

| Source | Global matches / extras | Raw local matches / extras | Aligned matches / extras | Aligned mean error |
| --- | --- | --- | --- | --- |
| Regular 120 BPM | 24/24 / 0 | 24/24 / 0 | 24/24 / 0 | 0.75 frame |
| Polyphonic 96 BPM | 20/20 / 0 | 20/20 / 0 | 20/20 / 0 | 1 frame |
| 120-to-100 BPM change | 15/24 / 11 | 24/24 / 0 | 24/24 / 0 | 0.75 frame |

Raw local mean errors are 0.75, 292.4 and 200.625 frames respectively. All three
have zero flagged raw joins. Metrics are restricted to the authored interval;
complete frame arrays remain in the report, including any points outside that
interval. These are controlled examples, not a general beat-accuracy claim.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs:
`build/beat-track-3.2.2-checked.log`, `build/beat-track-3.3.1-checked.log`.
The fixture has no vendor dependency. Laboratory reports/WAVs, tempo-change
audition and Pixel report/audition reproduce exactly across compilers
(`build/beat-track-replay.log`). Original source WAVs and fixed-grid outputs remain
byte-identical (`build/beat-track-source-regression.log`,
`build/beat-track-global-regression.log`). Rejected mixed rank/track arguments
preserve existing output (`build/beat-track-rejection.log`).

Pixel produces 80 positions over 35 windows with no flagged raw joins. Opening
produces 130 positions over 90 windows and two flagged raw joins. Reports are
`build/corpus/pixel-beat-track.json` and `opening-beat-track.json`. Their counts
and source-aligned attacks are not annotated beat accuracy. Native inspection
of the Pixel audition is `build/pixel-beat-track-inspect.json`; the controlled
tempo-change audition is `build/beat-track-change-inspect.json`.

The normal build includes the new fixture and tracked audition smoke. No fresh
full suite or source ZIP is claimed for this additive unit. Annotated external
music, richer tempo variation, rubato, missing/offbeat attacks, metrical-level
selection still need broader evidence. The subsequent
[pulse event path](PULSE-EVENTS.md) admits source intervals into actual WFC
learning with explicit exclusions and independent training runs.

## Independent annotated development baseline — 2026-09-19

The unchanged native tracker now has a reference-based development baseline on
three WAVs from Rico Rosenbusch's **ARTBeaT (2024)**, licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The
[official dataset](https://audiolabs-erlangen.de/resources/MIR/2024-ARTBeaT)
supplies audio and author ground-truth timestamps as CSV/MIDI. This study uses
the CSV timestamps, not participant taps or another algorithm's output. Examples
02 (stable arpeggio), 05 (abrupt 75-to-150 BPM) and 19 (continuous 80-to-200 BPM)
were selected before inference. The other 22 examples were not evaluated.
These are development examples, not held-out genre evidence.

Original stereo 44100-Hz WAVs feed `pythian.beats --track --audition` without
resampling or altered defaults: 40–240 BPM, 0.25-BPM trials, eight retained
candidates, six-second windows, one-second hops, maximum adjacent tempo ratio
1.5 and 100-ms onset alignment capped at one fifth of the local period.
Annotations are read only by the separate native evaluator after inference.

The fixed protocol matches ordered timestamps one-to-one within 30 ms, without
phase correction, ignored startup intervals or metrical-multiple forgiveness.
Seconds round to source frames with half ties later. Predictions are scoped to
the first/last reference timestamp plus the tolerance margin; no tracker points
were excluded in these three cases. Complete positions remain in the reports.
An independent dynamic-programming match count agrees with the ordered matcher
for every raw/aligned score and tolerance. Timing error describes the matched
pairs, not missed beats or a minimum-error assignment.

| Example | Reference beats | Raw matches / extras / misses | Aligned matches / extras / misses | Aligned precision / recall | Aligned F1 | Seam issues |
| --- | ---: | --- | --- | --- | ---: | ---: |
| 02, arpeggio | 42 | 5 / 17 / 37 | 9 / 13 / 33 | 40.91% / 21.43% | 0.2813 | 2 |
| 05, abrupt change | 26 | 24 / 9 / 2 | 25 / 8 / 1 | 75.76% / 96.15% | 0.8475 | 0 |
| 19, acceleration | 40 | 16 / 7 / 24 | 18 / 5 / 22 | 78.26% / 45.00% | 0.5714 | 0 |

Raw F1 is 0.1563, 0.8136 and 0.5079 respectively. Aligned mean absolute error
among matched pairs is 5.709, 1.679 and 5.831 ms. A separately reported 70-ms
sensitivity check gives aligned F1 0.3125, 0.8475 and 0.6984; relaxing the timing
tolerance does not resolve the missing/excess pulse problem.

The subsequent diagnostic compares admitted onset observations to the same
references: 39/42, 25/26 and 35/40 have an onset within 30 ms. This measures
available attack support, not beat precision: subdivisions and other attacks
are legitimate onset observations. The remaining failures therefore cannot all
be attributed to missing attacks.

- On example 02, the reference is approximately 144 BPM. The retained candidates
  largely omit this neighborhood, and the selected path falls toward the
  40-BPM search floor. Changing only the path transition penalty cannot select
  a hypothesis that was discarded or never proposed.
- On example 05, early windows retain near-75-BPM candidates, including rank zero
  in windows 1–3, but the selected path stays around 150 BPM across the change.
  Its zero seam warnings do not certify the annotated beat level.
- On example 19, the path ends near 100 BPM while the reference reaches 200 BPM.
  Zero seam warnings coexist with 22 missed beats at 30 ms. Alignment improves
  timing on selected attacks but cannot repair the missing metrical level.

These observations gate [WAV-02-PULSE](MILESTONES.md#wav-02-pulse), feeding
[WAV-02-CONTEXT](MILESTONES.md#wav-02-context). Next investigate candidate
retention under subdivision-rich evidence and explicit beat-level alternatives,
then evaluate path selection across actual tempo changes. Preserve unknowns and
manual admission; no automatic confidence rule follows from seam counts. Local
key work remains independently ready. Freeze any selected policy and its
acceptance criteria before evaluating separate recordings.

### Reproduction and retained evidence

The source archive SHA-256 is
`55d29f0ea5c42c5babfaad6eb30e8b41d5deda9efe8b92694d8bba86a6b7edc3`.
Its README and complete license remain with the extracted dataset under ignored
`build/beat-context-study/source/`. Original source/reference identities:

| Example | WAV SHA-256 | Annotation CSV SHA-256 |
| --- | --- | --- |
| 02 | `65c4daf2d97aa6e4550b15b352e5b876644e399dedd2341a9f09e9f352139c5c` | `15252eadcd3fea9de7d1cc62b3382c1086b59a193ff17aed9188971b8649d0e4` |
| 05 | `223826b7c5713bda7d6cfb59e417b5db5ff738154e29c18c9d79c83d52598472` | `222009f01110cd1da40393d0f7c0869b4e9e3261f9fbffceb2f3a03692533595` |
| 19 | `dd9f1bbe228be2ab575d578735462fd4899c00bcf9159121a8e57d554ebe65f2` | `89e13f0d39b2a6111f3435484144131df5ac6276a09922fa387838fbcda8cc8e` |

Checked FPC 3.2.2 x86_64-win64 builds use `-B -Sa -Cr -Co -Ci -gl -Fusrc
-Futools`. The maintained command for each selected basename is
`pythian.beats INPUT.wav REPORT.json --track --audition ALIGNED.wav`.
The ignored native `evaluate.lpr` runs as `evaluate build/beat-context-study`;
it binds reports to source hashes/geometry, validates annotation ordering and
retains reference frames, raw/aligned metrics, selected-window BPM and hashes.
`inspect.lpr` exposes retained candidate ranks. Build logs, protocol, reports and
six source-plus-marker auditions remain in the same directory. The reference
auditions add Pythian markers to the attributed source; source WAVs are unchanged.

All processes finished. This baseline ran on stable Win64 only; no cross-target
replay, listening acceptance, key/downbeat accuracy, held-out acceptance or
percentage credit is claimed. No maintained implementation, default, format,
fixture count or dependency changed.

## Subdivision and phase-concentration experiment — 2026-09-19

The next [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) development experiment tests
candidate recovery without changing maintained defaults. The existing fit uses
one weighted circular resultant. Equal attacks at opposing phases cancel that
resultant; equal subdivisions can therefore suppress a musically usable slower
pulse even when all its attacks are present. This is a limitation of that
measurement, not proof that a particular metrical interpretation is correct.

An ignored native prototype deposits normalized onset weights into 64 circular
phase bins with linear interpolation, finds the largest triangularly smoothed
phase peak, and refines it using nearby weighted offsets. Let `P` be the trial
period and `T = min(P/4, rate*0.03)` the existing matching tolerance. Each attack
within `T` contributes `weight*(1-distance/T)`; others contribute zero. The score
is `max(0, (support/totalWeight - T/P)/(1-T/P))*sqrt(coverage)`.
`T/P` is the triangular kernel's uniform-phase expectation. This removes
first-harmonic cancellation without declaring the strongest phase a musical beat.

The experimental report explicitly identifies its changed measurement: the
`coherence` field stores the new contrast, and `minimum_coherence=0.15` is used
as minimum matched-weight fraction. These are temporary study copies, not a
changed public contract or another supported format. Any adoption needs explicit
measurement semantics rather than silently changing those existing fields.

Six authored 120-BPM observation cases cover quarter notes, equal eighths,
equal sixteenths, weaker offbeats, dominant offbeats and equal triplets. The
baseline retains a near-120 candidate in three cases; the prototype retains it
in all six. Both preserve the exact leading quarter-note grid. Equal subdivisions
do not identify a unique metrical level: the prototype still prefers faster
alternatives in several cases, and dominant offbeats move its retained 120-BPM
phase by half a beat. These controls establish availability, not beat admission.

The same three ARTBeaT development WAVs then run through unchanged onset, tempo
range, candidate count and tracking options. Native audits verify identical
source hashes, admitted onset arrays and analysis policies. Annotation matching
and its independent maximum-count check reuse the baseline protocol.

| Example | Baseline aligned F1 | Prototype raw / aligned F1 | Aligned matches / extras / misses | Aligned precision / recall | Seam issues |
| --- | ---: | --- | --- | --- | ---: |
| 02, arpeggio | 0.2813 | 0.6265 / 0.6265 | 26 / 15 / 16 | 63.41% / 61.90% | 1 |
| 05, abrupt change | 0.8475 | 0.8475 / 0.8475 | 25 / 8 / 1 | 75.76% / 96.15% | 0 |
| 19, acceleration | 0.5714 | 0.8974 / 0.8974 | 35 / 3 / 5 | 92.11% / 87.50% | 0 |

All scores use 30 ms. Example 02 produces 42 positions, with one beyond the
annotation span's tolerance margin excluded by the unchanged evaluation rule;
the other examples exclude none. At 70 ms, aligned F1 is 0.6265, 0.8475 and
0.9744. Mean aligned matched-pair errors at 30 ms are 3.598, 1.679 and 5.395 ms.

The arpeggio now has a leading global 144-BPM candidate, and selected local
tempos stay between 143 and 147.5 BPM. Remaining wrong positions around seconds
1–4 and 14–17 are approximately a half beat from the references. The fit retains
only one phase per trial BPM, so the path cannot choose a discarded competing
phase at the same tempo. The abrupt-change result still favors approximately
150 BPM across both sections. Increasing candidate availability is useful but
does not resolve phase or metrical-level selection.

The prototype keeps existing work ceilings and accounts for three observation
walks plus 4096 histogram visits per BPM trial. Aggregate fit work is 62497224,
48162528 and 60430644 against a 64000000 limit. This implementation leaves little
room for longer excerpts; reducing actual kernel work is needed before promoting
it. Raising the budget alone is not the next acceptance result.

Next preserve competing phases at the same tempo and test their selection with
subdivision/accent counterexamples and the recorded failures. Keep candidate
measurement, path selection and explicit admission distinct. Efficient bounded
fitting and beat-level ambiguity remain part of the same context milestone.
Do not compensate with a global phase shift or per-recording parameter choices.

Evidence is under ignored `build/beat-phase-study/`: the declared protocol,
isolated source variants, six controls, reports, native evaluator/audit, candidate
list and source-plus-pulse auditions. Checked FPC 3.2.2 x86_64-win64 builds use
`-B -Sa -Cr -Co -Ci -gl`, placing the experimental unit directory before `src`
and using separate compiled-unit output. The CLI and evaluator commands match
the baseline; source media and annotations are reused without modification.
All processes are terminal. The prototype is not selected for maintained use;
cross-target, listening and held-out acceptance remain unverified. No additional
recordings, library units, fixture programs, format branches or percentage credit
are added.

## Competing phases and bounded kernel work — 2026-09-19

The next prototype retains up to two phase peaks per trial tempo, separated by
at least a quarter cycle. It refines and scores each with the previous
concentration measurement. Nearby-tempo suppression now preserves candidates
whose pulse phases differ by at least a quarter cycle at the observation-span
midpoint. The overall eight-candidate limit and existing path settings remain.
This is an availability experiment, not an automatic choice of musical beat level.

Triangular smoothing now visits only bins within the kernel's support. In the
checked six-case control run, every bin/trial sum agrees with an independent
full circular convolution within `1e-12*(1+abs(reference))`. All six cases retain
120 BPM. Equal eighths, weaker offbeats and dominant offbeats additionally retain
both exact phases, 4800 and 16800 frames at 48000 Hz. The exact leading
quarter-note grid remains unchanged. Two proposals do not preserve every possible
phase of triplets or sixteenths; those controls establish the declared alternatives.

An optimized **single-phase** condition isolates the kernel change. On all three
development WAVs, native audits verify exact equality with the preceding prototype
of raw/aligned pulse frames, window ownership and source-observation identities.
All three pulse auditions and their reference auditions remain byte-identical.
Thus the following phase-expansion result is separate from the kernel optimization.

| Example | Previous aligned F1 | Two-phase raw / aligned F1 | Aligned matches / extras / misses | Aligned precision / recall | Seam issues |
| --- | ---: | --- | --- | --- | ---: |
| 02, arpeggio | 0.6265 | 0.8675 / 0.8675 | 36 / 5 / 6 | 87.80% / 85.71% | 0 |
| 05, abrupt change | 0.8475 | 0.8475 / 0.8475 | 25 / 8 / 1 | 75.76% / 96.15% | 0 |
| 19, acceleration | 0.8974 | 0.8974 / 0.8974 | 35 / 3 / 5 | 92.11% / 87.50% | 0 |

The fixed 30-ms protocol and original reference/source hashes are unchanged.
Example 02 still excludes one final prediction beyond the annotation interval;
the other examples exclude none. At 70 ms, aligned F1 is 0.8675 / 0.8475 / 0.9744.
The source/onset audit confirms identical input evidence and analysis policy.
The arpeggio's early half-beat errors are resolved in this run; approximately
half-beat errors remain after 15 seconds. The last two windows lack a second
retained candidate within 3 BPM of 144, directing the next inspection toward
proposal, local-peak and truncation losses. Zero seam warnings still
do not establish correct phase or metrical level. The abrupt-change ambiguity
is unchanged.

| Example | Previous fit-work bound | Optimized single phase | Optimized two phases |
| --- | ---: | ---: | ---: |
| 02 | 62497224 | 37582920 | 39876984 |
| 05 | 48162528 | 28784736 | 30271392 |
| 19 | 60430644 | 35516340 | 36432684 |

These are conservative logical fit-work counts, not elapsed-time measurements.
The new bound allows at most 2368 fixed histogram/phase visits per trial plus
three observation walks for one phase or five for two. The 64-million aggregate
and 16-million per-fit ceilings are unchanged. This clears the earlier
near-ceiling condition for these short examples; it does not establish arbitrary
excerpt-length or many-hour tempo-analysis capacity.

For [WAV-02-PULSE](MILESTONES.md#wav-02-pulse), next distinguish phase loss before
and after the eight-candidate truncation at the remaining late-window failures,
then address accent/beat-level evidence for the abrupt change. The prototype's
local-peak filter compares phase ranks at neighboring trial tempos; rank is not
a stable phase identity. Candidate capacity and identity need investigation
before increasing limits or changing path penalties. Keep uncertainty explicit
and preserve independent context, phrase and corpus work.

Evidence is under ignored `build/beat-phase-alternatives/` and
`build/beat-phase-single/`. The former contains the declared protocol, shared
variant sources, six controls, native evaluation/audit and two-phase auditions.
`STUDY_SINGLE_PHASE` selects the one-phase comparison;
`STUDY_KERNEL_AUDIT` enables full-convolution checks in the control build only.
All builds use checked FPC 3.2.2 x86_64-win64 with separate compiled-unit output;
the same native CLI/evaluation path and original development sources are reused.
The arpeggio two-phase audition SHA-256 is
`12dd7fc6a308460153b4f543ad5dd0deef337e804f1b5eca93038fb6835f1117`.
All processes are terminal. Maintained code/defaults remain unchanged; no new
recordings, held-out use, cross-target or listening acceptance, format branch,
fixture program or percentage credit is claimed.

## Candidate survival and path diagnosis — 2026-09-19

A read-only trace of the isolated two-phase prototype now separates proposal
availability, local-peak filtering, nearby-candidate suppression, the eight-slot
cutoff and final path selection. It reconstructs the tapered observation inputs
for arpeggio windows 14–17 and abrupt-change windows 1–8. Every field of the
original eight retained candidates reproduces within declared floating tolerances
(1e-7 frames, 1e-12 for BPM/scores/ratios, exact integer counts); the report hash is bound to
its evaluator record. No fitting or path policy changes in this diagnosis.

After fitting, candidate raw pulses are compared with reference timestamps inside
the same owned hop interval at 30 ms. The native observed-span margin still
limits pulse rendering. These annotation-selected per-window comparisons locate
lost alternatives; they are not inference, whole-track accuracy or an achievable
stitched path. A separate diagnostic rank walk continues to the already supported
32-candidate ceiling, verifying that its first eight reproduce prior inference.
It does not run a larger-candidate tracking path or change any default.

| Development location | Observed candidate survival | Consequence |
| --- | --- | --- |
| Arpeggio window 15 | A 144.75-BPM candidate survives at rank 7; its local raw F1 is 0.8. The actual path chooses rank 1 at 146 BPM with local F1 zero. | A useful alternative already reaches the path here; missing proposals alone do not explain the ending. Later candidate losses can also affect an earlier offline choice. |
| Arpeggio window 16 | A 144.75-BPM phase survives the local-peak filter and matches both owned reference beats. It reaches zero-based diagnostic rank 13, beyond the eight slots. Best retained local F1 is 0.5; the actual choice scores zero. | This phase is lost at capacity selection, rather than absent from fitting. Merely changing transition penalties cannot select it from the original pool. |
| Arpeggio window 17 | A 142.5-BPM phase passes the peak filter and matches the one owned reference beat. It remains outside the original eight; the extended walk later suppresses it with a 144.75-BPM candidate at rank 9. All original eight have local F1 zero. | The first-eight cutoff removes this available phase family. The extended suppression occurs after that cutoff, so it must not be mislabeled as suppression by the original retained pool. |
| Abrupt-change windows 1, 2 and 5 | The 75-BPM candidate survives at rank 1 and matches the owned references; the actual path chooses approximately 150 BPM at rank 0. | Increasing candidate capacity alone does not address these wrong beat-level choices. |

The default transition ratio bound is also relevant: the reference-compatible
75-BPM candidate in window 5 cannot connect directly to window 6's approximately
149-BPM candidate under `MaximumTempoRatio=1.5`. The ratio is nearly two.
Candidate availability, scoring and admissible changes therefore need separate
consideration. This is an explicit existing policy limit, not evidence that
raising it alone will select the correct metrical interpretation.

Ownership boundaries limit the diagnostic. For example, a pulse just before
15 seconds can match a reference just after that boundary in the whole-track
evaluation but become an extra/miss when each owned interval is scored separately.
Likewise, a 49.75-BPM alternative matches the single reference in one abrupt-change
window; that local F1 of one does not identify the musical tempo. Apparent losses
at the local-peak stage must be checked against full-track timing and sustained
behavior before treating them as defects. Phase rank across neighboring trial
tempos remains an identity concern, not a failure proven by that local metric.

The next [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) work is bounded candidate
selection that preserves distinct phase families, alongside explicit beat-level
and abrupt-change reasoning. Compare any change with the existing full-track
protocol and controlled ambiguity cases. These investigations can proceed
independently; both feed automatic [context admission](WAVE-CONTEXT-ADMISSION.md).
Manual admission and the other provider/corpus work remain available.

Evidence is under ignored `build/beat-candidate-diagnosis/`: protocol, isolated
trace unit, native `diagnose.lpr`, build log and complete positive-trial records
with peak eligibility, original-pool suppression and extended diagnostic ranks.
Checked FPC 3.2.2 x86_64-win64 uses `-B -Sa -Cr -Co -Ci -gl`, the trace directory
before `src`, and separate unit output. All twelve window reconstructions pass;
all processes are terminal. No new whole-track inference, audition, recording, held-out
evaluation or maintained implementation change is included. Whole-track results
remain 0.8675 / 0.8475 / 0.8974 at 30 ms; no percentage credit or automatic
admission is inferred from this diagnosis.

## Bounded phase families and transition comparison — 2026-09-19

The next isolated experiment changes candidate selection within the existing eight
slots. It chooses the strongest eligible tempo/phase anchor, then reserves one
slot for the strongest eligible competing phase within its 3-BPM neighborhood,
if available. Phases must differ by at least a quarter cycle at the observation
midpoint. It removes that tempo neighborhood and repeats. Earlier trial order
breaks score ties; an unpaired anchor consumes one slot. Candidate output now
follows selection order rather than global score order, explicitly labeled in
the study report. Two-phase fitting, onset evidence, local-peak filtering, scores
and path settings remain fixed. No reference annotations enter inference.

Seven controls preserve the exact quarter grid, 120-BPM availability and both
equal/accented eighth phases. The added 120/90-BPM mixture retains both tempos.
This checks one competing-tempo case, not general preservation of all useful
alternatives: reserving a companion can displace another tempo. The path still
has eight states per window; fit-work counts remain 39876984 / 30271392 /
36432684. Selection makes at most three trial-array scans per anchor, with no
more anchors than available slots. This is a bounded selection policy, not an
increase in candidate capacity.

The fixed whole-track evaluator gives:

| Development WAV | Prior aligned F1, 30 ms | Phase-family raw F1, 30 ms | Phase-family aligned F1, 30 ms | Aligned matches / extras / misses |
| --- | ---: | ---: | ---: | --- |
| 02, stable arpeggio | 0.8675 | 0.9880 | 0.9639 | 40 / 1 / 2 |
| 05, abrupt 75-to-150 change | 0.8475 | 0.8475 | 0.8475 | 25 / 8 / 1 |
| 19, continuous 80-to-200 increase | 0.8974 | 0.8974 | 0.8974 | 35 / 3 / 5 |

The arpeggio has 41 scored predictions and one excluded beyond the fixed reference
margin; the other examples exclude none. At 70 ms, aligned F1 is 0.9880 / 0.8475 /
0.9744. All three have zero seam issues. Source hashes, onset arrays and analysis
policies match the preceding prototype exactly. Arpeggio phase retention improves,
but alignment now loses one otherwise correct raw match at 30 ms: the final
scored grid frame 752672 moves to onset frame 751524 against reference 753376.
The raw error is 704 frames; the adjusted error is 1852 frames, outside the
1323-frame tolerance. Keep raw and adjusted timing visible in future acceptance;
this observation does not justify globally disabling alignment.

A separate comparison changes only `MaximumTempoRatio` from 1.5 to 2. Across all
three WAVs, native audits verify identical candidate arrays, complete path records
(after normalizing that one setting in memory), pulse points and audition bytes.
The abrupt-change path still favors approximately 150 BPM throughout. Removing
the direct-doubling restriction alone is therefore insufficient on this case.
No preferred replacement limit is established.

The weaker-offbeat control also exposes the score's limits: the 240-BPM grid
explains both strong and weak attacks and scores 1, while the retained 120-BPM
strong-beat grid scores about 0.6454. Concentration and coverage measure pulse fit;
they do not by themselves identify the intended quarter-note level. Next develop
explicit accent/metrical evidence or uncertainty that prevents unsupported
admission, coordinated with abrupt-change handling. Compare against these fixed
development cases and controls before freezing policy for separate recordings.

For [WAV-02-PULSE](MILESTONES.md#wav-02-pulse), phase retention has a promising
development result; beat-level selection and alignment remain open acceptance
constraints. These gate automatic tempo in
[WAV-02-CONTEXT](MILESTONES.md#wav-02-context), which feeds
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration). Manual admission, local key,
phrase, corpus and fundamentals work remain independently runnable. Clear the
pulse gate with declared timing/beat-level criteria, explicit measurement
semantics, bounded resources and frozen-policy evaluation on separate recordings.
Do not convert this three-example improvement into overall completion credit.

Evidence is ignored under `build/beat-phase-families/` and
`build/beat-phase-families-ratio2/`: declared protocol, isolated Pascal sources,
seven controls, checked FPC 3.2.2 Win64 builds, reports, native evaluation/audits and
source-plus-marker auditions. `STUDY_TEMPO_DOUBLING` selects the ratio comparison.
The arpeggio phase-family audition SHA-256 is
`3cfea54d4f6ba3acec4c2daa513a602d2cf89cbd3acd66744fad196310084e6c`.
All processes are terminal. Maintained algorithms/defaults are unchanged; no
cross-target, listening or held-out acceptance is claimed. The other 22 ARTBeaT
examples remain unevaluated. This adds no maintained fixture or format branch.

## Alternating-strength path experiment — 2026-09-19

A fixed, isolated accent policy tests whether alternating attack strengths can
resolve the remaining beat-level choices. It keeps the eight phase-family
candidates and their scores intact. For each grid, complete pulse neighborhoods
inside the analysis window receive the maximum untapered onset weight multiplied
by linear proximity, within the smaller of 30 ms and a quarter period. Empty
slots have zero strength. With at least six slots, the absolute difference of
even/odd mean strengths divided by their sum gives contrast; otherwise contrast
is zero. Path emission becomes `score * (1 - contrast)`. No coefficient search
or annotation enters inference. The comparison uses the preceding ratio-2 run,
which had reproduced the ratio-1.5 path exactly; other track settings stay fixed.

Eight analytic checks pass: equal pulses, missing intervening pulses, alternating
1/0.5 weights, whole-cycle phase and common-gain invariance, identical evidence
under two beat-level interpretations, insufficient slots and zero observed mass.
In particular, the same 120-pulse-per-minute sequence with alternating weights
can represent either 60-BPM subdivided beats or 120-BPM accented beats. It gives
the same contrast of 1/3 in both interpretations. This is an information limit
of these inputs, not a test establishing either musical label.

| Development WAV | Prior aligned F1, 30 ms | Accent policy aligned F1, 30 ms | Matches / extras / misses | Result |
| --- | ---: | ---: | --- | --- |
| 02, stable arpeggio | 0.9639 | 0.9639 | 40 / 1 / 2 | Exact prior raw/adjusted points and audition bytes |
| 05, abrupt 75-to-150 change | 0.8475 | 0.7619 | 16 / 0 / 10 | Approximately 75 BPM throughout; the later true doubling is missed |
| 19, continuous 80-to-200 increase | 0.8974 | 0.6129 | 19 / 3 / 21 | Moves toward the slower level, ending near 100 BPM |

At 70 ms, aligned F1 is 0.9880 / 0.7619 / 0.6774. Seam issues are 0 / 0 / 1.
The abrupt-change result has perfect scored precision but only 0.6154 recall;
fewer extra pulses cannot be treated as successful beat admission. The six-slot
requirement also gives slow candidates with insufficient support no penalty,
while better-supported faster candidates can be penalized. Missing evidence and
measured absence of alternation must be distinguished in any later contract.

Native audits confirm exact source/onset/analysis inputs, global and every local
candidate field, fit-work counts, window bounds and all other track settings.
Reports keep original scores, contrast, slot counts, even/odd means and separate
path emissions. Additional explicit observation/slot visits are 13123 / 8763 /
6154, with a 64000000 study ceiling and 65536-slot storage bound. These counts
are separate from fitting and exclude runtime array initialization. Reports are
hash-bound to the fixed native evaluator; no new held-out source was used.

Reject this unconditional accent penalty as a replacement. Do not tune it against
these three WAVs or infer that all accent evidence is useless. The next
[WAV-02-PULSE](MILESTONES.md#wav-02-pulse) result needs to separate pulse fit,
metrical interpretation and evidence sufficiency. Investigate independent
band/part evidence around the change and retain unresolved level alternatives
when observations cannot distinguish them. Clearing criteria must preserve real
fast accented beats and acceleration as well as reject false subdivisions;
insufficient evidence must not silently reward a slower tempo. These criteria
feed automatic [context admission](MILESTONES.md#wav-02-context), then
[style integration](MILESTONES.md#wav-04-integration). Existing caller admission
and unrelated providers/fundamentals remain runnable.

Protocol, isolated Pascal sources, checked FPC 3.2.2 Win64 build/run logs,
controls, reports, audits and auditions are under ignored
`build/beat-accent-study/`. The abrupt-change audition SHA-256 is
`3ac5b800b582b697514da780a3d9478a921105b576ddd92cf226b09a3402fb8e`.
All processes are terminal. No maintained algorithm/default, current format,
fixture inventory or percentage estimate changes. No listening, cross-target,
automatic admission or held-out acceptance is claimed.

## Frequency-band evidence probe — 2026-09-19

The maintained analyzer now offers optional
[frequency-band measurements](ANALYSIS-WAVE.md#optional-spectral-bands--2026-09-19)
from its shared FFT pass, including bounded WAV batches. A native diagnostic
uses the same three development WAVs and existing phase-family candidates.
Bands are `[0,200)`, `[200,2000)` and `[2000,Nyquist]` Hz. Each existing onset
receives the maximum band flux among features whose window center lies within
30 ms of that onset. Maxima are selected independently by band, so these onset
weights need not sum to the broadband value. No onset, candidate or path is
selected using annotations or these new measurements.

The probe retains pulse-slot counts, observed band weight, even/odd means and
alternation contrast for every candidate. `has_contrast_evidence` explicitly
distinguishes insufficient slots/zero pulse mass from measured zero contrast.
It makes no metrical decision. On the abrupt-change WAV, the leading retained
150-BPM hypothesis shows:

| Owned interval | Low-band contrast | Mid-band contrast | High-band contrast |
| --- | ---: | ---: | ---: |
| 1–2 seconds | 0.313 | 0.753 | 0.218 |
| 9–10 seconds | 0.326 | 0.051 | 0.155 |

Mid-band alternation differs across the change while low-band contrast remains
substantial. This supplies information hidden by a single broadband accent
measurement, but it is not a ready tempo rule. In the acceleration example,
the retained 160-BPM candidate at 10–11 seconds has low/mid/high contrasts
0.998 / 0.908 / 0.167. Selecting a band or penalizing strong alternation alone
can still favor the wrong beat level. Constant-grid drift, spectral content and
accent hierarchy must remain separate concerns; these observations do not
identify instruments or establish which concern caused each contrast.

All source hashes bind to prior reports. For all three sources, 97-feature WAV
batches reproduce every whole-clip band magnitude/flux value exactly; complete
band partitions sum to aggregate feature flux within 1e-12. The new core API's
analytic, stereo, resume, rejection and long-coordinate checks pass on three
Windows targets. Rebuilt maintained beat reports and auditions reproduce the
original baseline bytes exactly. Maintained beat defaults are unchanged; the
phase-family prototype's F1 remains 0.9639 / 0.8475 / 0.8974, and no new selection
accuracy or listening approval is claimed.

For [WAV-02-PULSE](MILESTONES.md#wav-02-pulse), the measurement prerequisite is now
available. Next test temporal evidence across bands with explicit metrical
alternatives and evidence sufficiency, protecting fast accented beats and
acceleration. Do not choose a winning band or threshold from these three cases.
Policy freeze and separate-recording acceptance still precede automatic
[WAV-02-CONTEXT](MILESTONES.md#wav-02-context) and semantic
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration). This adds no percentage
allocation and does not block independent local-key, phrase or fundamentals work.

Ignored artifacts are under `build/band-analysis/`: native probe, per-source band
reports, batch-identity checks, three-target fixture logs, journal checks and
baseline report/audio replay. All processes are terminal. The other 22 ARTBeaT
examples remain unevaluated; the existing dataset attribution continues to apply.

<a id="temporal-band-recurrence"></a>
## Temporal band recurrence and a joint-timing counterexample — 2026-09-20

A native study now tests repeating temporal patterns in the existing continuous
band-flux series. Unlike the earlier band-accent probe, it does not copy nearby
feature maxima onto multiple onset observations. It retains the same WAVs,
1024-frame FFT/256-frame hop, bands [0,200), [200,2000), [2000,Nyquist], and
six-second analysis intervals around one-second owner intervals. Maintained
candidate selection, pulse paths and their accuracy scores remain unchanged.

For each band and lag, Pearson correlation uses overlapping feature pairs with
separate means and variances. Lags span 0.15–2.4 seconds, capped at one third
of the available interval; at least sixteen pairs and nonzero variance are
required. Unavailable evidence remains explicit. Complete signed curves and
up to six positive local peaks per band are retained. Peaks describe repeated
feature shapes, which may span several beats; they are not BPM estimates.

Between windows, twenty-five time-scale alternatives `2^(k/12)`, `k=-12..12`,
compare positive correlation profiles using interpolated lag positions and
cosine similarity. Each band needs sixteen supported lag samples and positive
norms; the report retains band/sample counts and every alternative. A scale of
0.5 means the recurring pattern's period halves, while 1 means it stays the
same. Similarity is not calibrated probability, and a boundary maximum does
not exclude rates outside the tested 0.5–2 range.

Adjacent windows share substantial input. A separate comparison therefore uses
the most recent earlier window whose analysis interval ends at or before the
current interval starts. These intervals are disjoint in feature-center ownership;
FFT support can straddle their boundary. No statistical independence is claimed.
The following results refer to these separate-window comparisons, not detection
latency or exact tempo-change timestamps.

| Source | Observed relative-pattern evidence | Limit |
| --- | --- | --- |
| ARTBeaT 02, stable arpeggio | All twelve comparisons select diagnostic scale **1**, including the added-instrument portion. Similarities 0.673–0.901. | One stable arrangement example does not establish general arrangement invariance. |
| ARTBeaT 05, 75→150 | Windows 6–11 prefer **0.5**. For current interval 6.5–12.5 s versus earlier 0.5–6.5 s, similarity is **0.815684**, compared with **0.659270** for unchanged scale; all three bands contribute. | Later pairs both spanning the faster portion prefer 1. Six-second windows can mix regimes; absolute beat level and change position remain unadmitted. |
| ARTBeaT 19, acceleration | Most later comparisons prefer shortened periods; windows 11–13 select **0.707107**, with similarities 0.546–0.634. Earlier comparisons include an unchanged-rate choice and similarities as low as 0.242. | There is no uniformly reliable rate trajectory; fixed-window lag profiles smear changing periods. |
| Authored regular / polyphonic clocks | Every comparison prefers **1**, with similarity ranges 0.944–0.995 / 0.939–0.991. | The wrong 192-BPM fixed-grid leader on the polyphonic case is still not corrected by this observation. |
| Authored 120→100 clock | Windows 7–12 prefer **1.189207**, the nearest tested factor to the declared 1.2 period increase. | This is relative pattern-rate evidence, not accurate reconstruction of the source clock. |

### Controls and the missing relationship

An independent integer-moment Pearson reference agrees with the centered
implementation. Known periods reproduce unit correlation. Per-band positive
gain/DC transformations change correlations by at most about 3e-15; these are
feature-level invariance checks, not guarantees for arbitrary audio processing.
A controlled rate doubling prefers scale 0.5 with similarity 0.999899898.
Unchanged fast accented input retains scale 1. Flat/short inputs remain unavailable,
and identical observations under different beat-level labels remain identical.

A further control, declared after the source measurements and before its own
execution, exposes information discarded by independent-band autocorrelation.
Positive feature patterns initially alternate between bands on a fixed clock.
Two continuations are compared: a real doubling preserving that alternation,
and an unchanged clock where alternating band identity becomes simultaneous.
Their per-band recurrence curves agree to about **1e-15** and both score
**0.999927974** for time scale 0.5. Yet the zero-lag relationship between the two
bands has opposite signs. Joint timing can distinguish this feature-level
counterexample; the separate recurrence curves cannot.

**Decision:** temporal recurrence supplies useful relative-rate evidence, but
cannot alone authorize a tempo change. The next inference representation must
retain joint band timing or other discriminating context, expose arrangement/
pattern-change alternatives and preserve unknown outcomes. A similarity threshold
cannot separate the two constructed continuations. Do not repeat the rejected
scalar accent penalty or treat recurrence agreement as automatic quarter-note
admission. This keeps [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) open, supplying
the remaining requirement to [automatic context](MILESTONES.md#wav-02-context).

### Verification and retained scope

The fixed measurement policy precedes all six source runs. The three existing
ARTBeaT development recordings retain Rico Rosenbusch's dataset attribution and
CC BY 4.0 notices from the earlier baseline; no other recording or held-out
annotation is used. Source/report hashes and geometry are checked before temporal
measurement. Feature count is capped at 4096, windows at 32, and correlation work
is preflighted below 64 million pair visits per source. Recorded visits are
24468882 / 18069552 / 24091386; each authored case uses 18492408. Source analysis,
curve/profile computation and report serialization take about 1.8–2.4 seconds per
local run; these are observations, not realtime or many-hour guarantees.

Checked stable Win64 controls and all six measurements pass their accounting
checks with no unfreed blocks. An initial managed-result initialization warning
is corrected; final study builds have no warnings. The abrupt-change source
replays every report field except elapsed time exactly after the preflight fix,
including all curves, alternatives and source bindings. No broad library suite
is repeated for this ignored study.

Artifacts are under `build/beat-band-recurrence/`: Pascal unit, controls, probe,
native summary/replay checks, complete reports, policies and logs. Original policy
SHA256 is `f55d50702d55503687a10874f77e2499c02660e3bc482f9149dd2ceae6d54287`;
the additional control has its own declaration. No maintained estimator, format,
dependency or public API changes. Whole-track F1 remains **0.9639 / 0.8475 /
0.8974**; there is no new listening, automatic tempo or completion credit.

<a id="joint-band-recurrence"></a>
## Joint band timing retains the missing relationship — 2026-09-20

The next native study retains all nine ordered band-pair lag correlations instead
of only the three independent-band curves. For pair `(i,j)` and positive lag `l`,
it compares band `i[t]` with band `j[t+l]`; pair identity and signed correlation
survive rate comparison. The same FFT features, sources, windows, lag limits and
twenty-five time-scale alternatives are used. This supplies the relationship
missing from the preceding counterexample, without changing the maintained beat
path or asserting which recurring period is a quarter note.

Each rate alternative reports signed cosine similarity for every available pair,
their mean, minimum, negative-component count and supported sample counts. The
earlier positive diagonal-only result remains alongside it. Negative components
are neither clipped nor reassigned to other bands. Flat/short evidence stays
unavailable; correlation and profile similarity remain measurements, not calibrated
probabilities. Band relationships do not establish instrument or part ownership.

### Controlled distinction and numerical correction

The prior true-doubling and unchanged-clock role-change cases still have identical
diagonal-only scores. The joint comparison now gives:

| Feature-level continuation at time scale 0.5 | Joint similarity | Opposing ordered pairs | Minimum pair similarity |
| --- | ---: | ---: | ---: |
| True doubling with relationships preserved | **0.999934589** | 0 / 9 | 0.999934589 |
| Unchanged clock, alternating identities become simultaneous | **0.111103843** | **4 / 9** | **-0.999934589** |

The one-ninth relationship follows the constructed five agreeing/four opposing
pairs and passes an explicit check. Thus the original information loss is resolved
for this control. It is not a general arrangement classifier or a tempo-admission
threshold. Identical observations assigned different absolute beat-level labels
still remain indistinguishable.

Independent integer-moment references cover asymmetric band pairs. The existing
centered two-pass diagonal implementation agrees with the new moment method.
Positive gain/DC transformations, known rate doubling, unchanged fast accents,
quiet nonflat bands, silent-band exclusion and insufficient context pass. Only
four ordered pairs are available when two bands vary and the third is silent;
the missing band does not contribute a fabricated similarity.

An additional check at the admitted 4096-feature span found that ordinary prefix
sums could fabricate variance in constant inputs. Compensated accumulation of
values, squared values and cross-products fixes this failure with the same
variance guard: overlap power must exceed `64 * Double epsilon * raw squared sum`.
The failed control, original unit and initial source results are retained, and a
separate numeric-fix declaration precedes the corrected source reruns. No musical
threshold, recording split or lag/rate setting changes. The constant-span control
now passes; final gain/DC/diagonal control error is about 1.1e-14.

### Recorded and authored observations

All six original sources are rerun after the numeric correction. These results
refer to separate-window comparisons as defined above, not exact change timing.

| Source | Joint observation | Remaining interpretation |
| --- | --- | --- |
| Stable arpeggio, ARTBeaT 02 | All twelve comparisons still prefer scale **1**. | Early instrument additions produce one opposing component despite the unchanged clock; blanket rejection on any negative component would discard useful stable-tempo evidence. |
| Abrupt 75→150, ARTBeaT 05 | Windows 6–10 prefer **0.5** with no opposing components. At window 9, joint similarity is **0.609859**, versus **0.300803** for scale 1; its weakest pair remains positive at 0.303169. | Window 11 changes to scale 1 with one opposing pair. Mixed/shortened windows and arrangement hypotheses still need a declared admission policy. |
| Acceleration, ARTBeaT 19 | Every separate-window comparison now prefers a shorter period: scales 0.629961, 0.707107, 0.749154 or 0.793701, with no opposing components at those maxima. | Neighboring rate alternatives can be close. This establishes directional pattern-rate evidence, not an accurate instantaneous BPM trajectory. |
| Authored regular / polyphonic | Every comparison prefers **1**. | The existing wrong fixed-grid 192-BPM leader on the polyphonic case remains unresolved. |
| Authored 120→100 | Windows 7–12 still prefer **1.189207**, nearest the declared 1.2 period ratio on this rate grid. | A relative-rate comparison does not supply beat phase, exact period or metrical identity. |

Final diagonal audits have no availability differences and maximum correlation
error at most about **3.24e-12**, below the predeclared 1e-9 bound. They check every
window/lag rather than only favorable candidates. The corrected abrupt-change
report also replays every field except elapsed time exactly, including full
signed curves, component comparisons, source bindings and numeric policy.

Moment accumulation shares overlap statistics, so nine cross-product walks cost
**36703323 / 27104328 / 36137079** conservative pair visits for the three recorded
sources, below the existing 64-million measurement budget. Prefix feature visits
are reported separately. The independent old-method diagonal audit adds
24468882 / 18069552 / 24091386 explicitly reported visits; it is not hidden in the
inference cost. Each authored source uses 27738612 joint visits. Local complete
runs, including FFT analysis, audits and report serialization, take about 2.5–3.4
seconds. This is not a many-hour throughput or realtime guarantee.

Checked stable Win64 controls, all six corrected runs and replay pass with no
compiler warnings or unfreed blocks. Reports retain all nine curves and all rate
components under a declared 16-MiB report limit. The original three ARTBeaT
development sources and their attribution/CC BY 4.0 notices remain unchanged;
no new recording or held-out annotation is used.

Evidence is ignored under `build/beat-joint-recurrence/`, including both policies,
Pascal sources, controls, initial failure/results, corrected reports and native
summary/replay logs. Original policy SHA256:
`ec459a3a4cfe0381a97a39d9ec329d540bb20ab055b89e4f6f4ac337dfd30c1b`.
Numeric-fix policy SHA256:
`2f2ddf8b5934e469e2422b1189813fb32723c236647cc45337f2b570f02dbb72`.

**Next closing result:** use this retained evidence in an explicit
pattern-stability/rate/arrangement/unknown policy and evaluate the resulting full
beat path, phase and metrical alternatives. Preserve unchanged fast accents and
instrument additions as well as real rate changes; do not substitute a blanket
negative-pair veto. This advances the input representation for
[WAV-02-PULSE](MILESTONES.md#wav-02-pulse), while native public adoption and
automatic [context admission](MILESTONES.md#wav-02-context) remain open. Maintained
whole-track F1 is still **0.9639 / 0.8475 / 0.8974**. No new inference accuracy,
format, dependency, listening approval or completion credit is claimed.

<a id="joint-timing-path"></a>
## Joint timing improves doubling but does not yet supply a reliable clock — 2026-09-20

The next experiment actually selects and renders complete beat paths using the
corrected joint timing measurements. It improves the abrupt doubling example,
preserves the stable clocks, and regresses acceleration. **Do not adopt this
policy as automatic tempo admission.** The maintained tracker remains unchanged.

### Declared inference and controls

The native study regenerates the same WAV observations and local candidate grids.
It verifies source/report hashes, window geometry and exact baseline raw/aligned
positions before changing selection. Each eligible window compares its candidate
period with the path's candidate in the most recent wholly earlier analysis
window. The saved 25 signed similarities are interpolated in log2 time scale;
outside [0.5, 2], or across unavailable endpoints, the rate is unsupported.

Three competing potentials are retained: rate similarity at that period ratio,
unchanged-pattern similarity at unity, and unknown evidence at zero. The added
score is `max(rate, unity, 0) - max(unity, 0)`, with unit weight. Ties prefer the
unchanged-pattern interpretation, then unknown. This simple arrangement option
only permits declining the rate hypothesis; it does not model a changed musical
arrangement. Similarity and path scores are not calibrated probabilities.

Existing unary candidate scores and 0.5 tempo/phase penalties stay fixed. The
maximum adjacent ratio becomes 2 to permit doubling. Bounded search retains 32
histories per ending candidate (up to 256 total), then separately 128 (up to 1024).
Long-range optimization is approximate. Native rendering and onset alignment are
an exact study copy of the maintained tracker with a finishing wrapper; no
maintained API or source changes.

A delayed-evidence control revises an earlier candidate and agrees with an
independently enumerated optimum. Unity ties, unavailable and out-of-grid
comparisons retain their declared semantics. Zero joint weight reproduces the
exact existing ratio-2 dynamic program on every source. Both search bounds
produce identical selected candidates, phases, hypothesis labels, objective
scores and raw/aligned output on all six sources. Each search also replays exactly.
Agreement at these two bounds does not prove global optimality.

The feature-level ambiguity control is still a **decision failure**: true
doubling earns .999934589, but the unchanged-clock role-pattern change still
earns a positive .111103843 and is labeled rate. Its unity similarity is negative,
so the zero-valued unknown alternative cannot defeat the small positive rate
score. Retaining opposing relationships solved the information loss; this scoring
rule does not yet use that information to reject the counterexample.

### Complete beat results

Annotations enter only the separate evaluator after inference. It reuses the
existing 30-ms reference scope and ordered matching, checked against an independent
maximum-cardinality matcher. These are the same three development recordings and
three authored WAVs; no held-out recording is used. ARTBeaT attribution remains
Rico Rosenbusch, CC BY 4.0, with the existing dataset notices.

| Source | Baseline aligned F1 | Joint-path aligned F1 | Matched / extra / missed, after | Assessment |
| --- | ---: | ---: | --- | --- |
| Stable arpeggio / instrument additions | .963855 | .963855 | 40 / 1 / 2 | Exact existing path retained; raw F1 remains .987952. |
| Abrupt 75 → 150 | .847458 | **.943396** | 25 / 2 / 1 | First five owner windows select about 75 BPM instead of 150; six extras removed. |
| Acceleration 80 → 200 | .897436 | **.875000** | 35 / 5 / 5 | Two additional extras and two reported seam issues; regression. |
| Authored regular | 1 | 1 | 24 / 0 / 0 | Exact existing path retained. |
| Authored polyphonic | 1 | 1 | 20 / 0 / 0 | Exact existing local path retained; wrong global 192-BPM leader remains unresolved. |
| Authored 120 → 100 | 1 | 1 | 24 / 0 / 0 | Exact existing path retained. |

Zero-weight ratio-2 results equal the baseline on all six sources, so the doubling
gain is not explained by relaxing the transition limit alone. Raw and aligned F1
agree for every row except the already known arpeggio alignment loss.

The abrupt path still changes too early: extra aligned beats remain at 5.196735
and 5.998435 seconds, plus the original missed initial reference beat. Acceleration
adds unmatched beats at 3.029184 and 5.025397 seconds. It also exchanges one timing
miss near 10.85 seconds for one near 14.85 seconds; total matches/misses stay fixed.
Directional rate evidence therefore does not establish change timing or coherent
phase across owner-window joins. Both bounds choose the same regressed path, so
increasing this search capacity has no demonstrated benefit on these inputs.

### Decision and next implementation

Keep the maintained path and automatic-admission status unchanged. The next
[PULSE](MILESTONES.md#wav-02-pulse) work must represent a continuous beat clock and
change timing across windows, and compare actual arrangement-change explanations
with rate and unknown alternatives. Six-second descriptor relationships should
constrain their covered intervals without being treated as precise instantaneous
tempo or independent repeated votes. These are hypotheses to test, not proven
causes of every error. Protect the stable instrumentation changes, short control
counterexample, true doubling and accelerating phase continuity together. A
weight/threshold sweep or larger beam alone is not the next closing result.

Checked stable Win64 controls, six source runs, repeated paths, two search bounds
and independent score accounting pass, with no compiler warnings or unfreed
blocks. Each search stays below 262144 extensions; the largest observed count is
117224. The recurrence measurement workload is upstream and not included in that
count. Inputs remain bounded at 32 windows / 8 candidates, 16-MiB joint reports
and 4-MiB beat reports. No realtime or many-hour claim follows from this study.

Ignored artifacts: `build/beat-joint-path/`, including native inference/evaluation,
controls, complete paths, error timestamps and original/corrected study bindings.
Policy SHA256:
`302f3065fc6f727ddc9fc16e331f76af392257153f4ce458036f8dc64379a812`.
This is useful development progress, with no new completion or listening credit.

<a id="continuous-clock"></a>
## Continuous phase with a constrained rate-step alternative — 2026-09-20

The next native experiment isolates clock reconstruction from candidate selection.
It freezes both the maintained baseline candidates and the preceding joint-path
candidates on all six development WAVs. A continuous phase representation with a
feasible interior rate-step alternative preserves the doubling gain and removes
the acceleration regression **on the joint-selected paths**. This is a successful
reconstruction experiment, not automatic tempo, arrangement or metrical admission.

### Representation and declared comparison

Each active owner-window center supplies fractional phase and rate from its
selected candidate. The next phase is unwrapped to the integer cycle nearest
the previous phase plus elapsed time times the mean endpoint rate. Exact half-cycle
ties choose the later cycle deterministically and are reported as ambiguous;
nonpositive phase intervals are rejected. Missing candidates split the clock.
Edge extrapolation stops at the active run's owner bounds, and rendering retains
the prior observation support limits. Numerical tie reporting is not calibrated
musical uncertainty.

The first declared variant interpolates phase linearly between centers, then
renders integer crossings. It eliminates independent-grid joins but can smear a
real rate step. The same bounded onset alignment is retained, with its period/5
cap derived from the reconstructed interval. Constant phase clocks, half-frame
rounding, owner assignment, missing-window gaps, ambiguity, nonpositive intervals
and replay have focused controls. Analytic smooth acceleration has at most 23 ms
error under its independently derived 25.5-ms bound. An exact abrupt clock exposes
a **167-ms early beat** from interpolation.

An initial half-frame control caught floating interpolation just below the exact
tie. Before any WAV runs, a scale-aware 64-Double-epsilon rounding guard fixes
that case; just-below/above inputs outside the guard retain ordinary rounding.
The failure, original unit and rounding declaration remain in the study folder.

After evaluating linear phase, a separately declared second variant adds an
endpoint-constrained step. For duration `d`, endpoint rates `r0,r1` and phase
advance `q`, the switch offset is `(q - r1*d)/(r0 - r1)`. Use it only strictly
inside the interval, with a numerically resolvable rate contrast and unambiguous,
positive phase progression. Otherwise retain linear phase. Both subintervals
preserve endpoint phase; no annotation or fitted switch-time threshold is used.
The exact abrupt-clock control is recovered, an infeasible-step control falls
back, and the analytic acceleration error remains at most 23 ms.

This alternative is **step-capable**, not a physical change detector. It also
finds feasible steps on smooth acceleration and on stable recordings with small
candidate fluctuations. Interpolation feasibility alone cannot label tempo changes.

### Results at the unchanged 30-ms scoring tolerance

| Source | Maintained baseline aligned F1 | Joint path with old joins | Joint path, linear phase | Joint path, step-capable phase |
| --- | ---: | ---: | ---: | ---: |
| Stable arpeggio / instrument additions | .963855 | .963855 | .963855 | .963855 |
| Abrupt 75 → 150 | .847458 | .943396 | .905660 | **.943396** |
| Acceleration 80 → 200 | .897436 | .875000 | .948718 | **.948718** |
| Authored regular | 1 | 1 | 1 | 1 |
| Authored polyphonic | 1 | 1 | 1 | 1 |
| Authored 120 → 100 | 1 | 1 | 1 | 1 |

The final joint/step combination has 25 matches / 2 extras / 1 miss on doubling,
and 37 / 1 / 3 on acceleration. The latter removes the two newly inserted join
beats and recovers two previously missed matches. Remaining acceleration errors
are the initial/final reference beats and the miss near 5.488481 seconds paired
with an extra at 5.536395 seconds. Doubling still has the early-change extras at
5.196735 and 5.998435 seconds and misses the initial beat. Reconstruction does not
repair the selected change location.

With baseline-selected candidates, linear phase alone also reaches .948718 on
acceleration, but the step-capable variant returns to .897436. Thus reconstruction
and selection must be assessed together; this is not a universal renderer upgrade.
All other baseline-selected aligned scores remain unchanged. Raw scores match
aligned scores except arpeggio (.987952 raw versus .963855 aligned) and the linear
authored slowdown (.958333 raw, restored to 1 by alignment). The step alternative
restores that slowdown's raw score to 1. Equal scores do not mean identical frames.

The final joint paths admit 4 / 5 / 10 / 0 / 1 / 1 step intervals in table order,
with zero numerical phase ties or rejected intervals. The four arpeggio steps
illustrate why these counts cannot be reported as detected musical changes.
No reference enters inference. The independent ordered matcher audits all scores;
ARTBeaT development attribution remains Rico Rosenbusch, CC BY 4.0, with retained
notices. No held-out recording is used.

### Verification, limits and next adoption boundary

Native source analysis reproduces the saved candidates and both prior raw/aligned
paths before reconstruction. Every original linear-clock field replays exactly
after adding the step alternative. Both clock variants replay full segments,
positions and observation assignments. An explicit initial-anchor initialization
removes a compiler warning; the final acceleration report replays every field
except elapsed time exactly. Final checked stable Win64 builds have no warnings
or unfreed blocks. The original failed rounding control is retained separately.

Two cue-overlay WAVs exercise the changed audible timing path through the library
writer/reader. Doubling has 599760 frames / 27 cues / peak .698273; acceleration
has 760690 frames / 38 cues / peak .517487. Both preserve 44100-Hz stereo source
geometry and reopen with matching hashes. These are listening-ready diagnostics,
not new listening acceptance or style generation.

The study remains bounded to 32 owner windows, 128 segments, 65536 output beats
and 4-MiB prior reports. Source analysis plus both reconstructions/replays takes
about 1.8–2.4 seconds locally; upstream joint analysis and path search are separate.
No many-hour/realtime claim follows. Artifacts are under
`build/beat-continuous-clock/`; original and step declarations precede their
respective source runs. Original policy SHA256:
`d52fc5411684fdec93dc6640ba6f0f413e41ddb87094d6c6b2ed0f958bff3c7b`.
Step declaration SHA256:
`b7e4913cd47251fb77b33b397c8a54c4732651a9dc9d875e85676a0f875b2fb5`.

The next [PULSE](MILESTONES.md#wav-02-pulse) implementation should carry this
phase-continuous representation into the smallest useful native boundary for
selected pulse hypotheses, preserving raw evidence, alternative shape and gaps.
Joint inference must still resolve arrangement changes, early switch timing,
endpoint coverage and metrical alternatives before automatic context admission.
The earlier role-pattern counterexample remains a failure of selection. Do not
interpret a feasible rate step or a zero tie count as confidence. Maintained
defaults/APIs remain unchanged in this experiment; no completion credit is added.

<a id="relationship-competition"></a>
## Competing band relationships retain the role-change ambiguity — 2026-09-20

The next native study removes the known false rate bonus without changing any
of the six development beat paths. It compares the original nine-pair mean with
three coherent alternatives: reversing the centered activity of band 1, band 2,
or both, while fixing band 0's sign. Each ordered pair receives the product of
its two band signs. This models a narrow change in band relationships rather
than independently discarding unfavorable pairs. Identity wins numerical ties;
missing pairs remain missing. No similarity threshold or weight is fitted.

A better nonidentity fit excludes that rate-only explanation from the path
potential. It does **not** establish unchanged tempo or identify instruments.
Rate and relationship changes occurring together remain ambiguous under this
observation. The original unity comparison remains in the potential's baseline;
excluded interpolation endpoints prevent a rate bonus. All four scores for all
25 alternatives remain bound to the frozen recurrence report and source SHA256.

The true-doubling control retains its **.999934589** bonus. The role-change control
has identity score **.111103843**, while a coherent reversal explains it at
**.999934589**; its bonus becomes zero/unknown throughout the rate grid and tested
midpoints. This fixes the earlier selection counterexample at the feature level.
A single opposing pair with stronger preserved structure still accepts identity.
Missing relationships, disconnected-band ties and unchanged observations with
different absolute metrical labels retain their declared ambiguity.

### Complete development paths and limits

The candidate observations, local scores, transition penalties, 32/128 history
bounds and six inputs remain fixed. New paths are reconstructed with the
maintained clock API, including the previously declared step-capable shape.
Annotations enter only the existing independent 30-ms matcher.

| Source | Excluded rate alternatives / compared alternatives | Aligned F1 after reconstruction | Change from prior joint-selected clock |
| --- | ---: | ---: | --- |
| Stable arpeggio / instrumentation additions | 134 / 300 | .963855 | No candidate or raw/aligned frame changes |
| Abrupt 75→150 | 160 / 200 | .943396 | No changes; 25 matches, 2 extras, 1 miss |
| Acceleration 80→200 | 188 / 300 | .948718 | No changes; 37 matches, 1 extra, 3 misses |
| Authored regular | 136 / 200 | 1 | No changes |
| Authored polyphonic | 124 / 200 | 1 | No changes |
| Authored 120→100 | 131 / 200 | 1 | No changes |

These counts describe alternative explanations, not independent observations or
accepted beats. No comparison's original best rate is excluded. Both search
bounds agree on complete paths/scores/hypotheses, and all final selected-path
scores equal the earlier study. The study supplies a useful ambiguity constraint,
not improved recording accuracy or evidence of general arrangement recognition.
The maintained selector is unchanged; its default scores remain .963855 /
.847458 / .897436. No held-out recording or listening verdict is used. ARTBeaT
attribution remains Rico Rosenbusch, CC BY 4.0, with the existing notices.

An initial implementation overloaded measured availability with rate exclusion.
That also removed some unity comparisons and inflated doubling/acceleration path
scores. Initial sources/results remain in `initial-gating/`. A declared correction
separates those flags, preserves the original comparison baseline and checks that
exclusion never increases a proposed bonus. All six cases were rerun after the
correction. Checked stable Win64 controls, complete path/clock replay, both search
bounds and full report replay pass without compiler warnings or unfreed blocks.
No maintained inference API, package, dependency or format changes.

Evidence is under `build/beat-relationship-competition/`. Policy SHA256:
`ae7bd87d98b675a97fe8d1b1343d8d68e6ab6912b26ce44a3f222bf8cafba40b`.
Gating correction SHA256:
`70ec458f3b2ad0783bb53040aa058486ac033d551fd6f996050c0585727b27ef`.

**Next closing result:** locate change timing within the intervals actually
covered by descriptors, including the two early doubling extras, while retaining
these ambiguity controls and combined doubling/acceleration gains. Broader
arrangement transformations, correlated overlapping evidence, endpoint coverage,
metrical alternatives and frozen independent evaluation remain necessary before
adopting automatic [pulse/context admission](MILESTONES.md#wav-02-pulse).

<a id="switch-localization"></a>
## Fixed endpoint templates do not reliably locate the tempo switch — 2026-09-20

The conditional switch experiment addresses the doubling path's early owner-
window transition. It retains that path's 75/150-BPM hypotheses and considers
phase-continuous joins between them, scoring source features on each side of
each join. The result **fails the recorded upgrade gate**; it is not adopted.

The frozen policy applies only when exactly one adjacent selected period ratio
exceeds the existing 1.5 transition limit. Three-band positive flux uses the
existing 1024-frame/256-hop analysis. Each clock learns a 32-bin cyclic mean from
three periods at its source endpoint; pooled training mean-square power normalizes
band residuals, with flat evidence unavailable. All intervening features are
scored once under the before/after templates. Both constant-template null costs,
every possible phase-continuous join and numerical ties remain visible. Stable
endpoint patterns are an assumption, not a validated fact about the recording.

An authored feature control recovers its exact switch at frame 600. A constant
clock favors the unchanged null; flat evidence stays unavailable. Independent
band gain preserves the complete cost profile. These controls establish the
conditional calculation, not its musical suitability.

### Recorded result and error separation

ARTBeaT 05 is the only one of the six development sources to enter the declared
single-abrupt-change branch. Its training regions end at 2.4 seconds and begin
at 12.4 seconds. The model scores 1723 feature centers across all three bands,
enumerating 13 joins. It chooses **7.201112 seconds**, with cost **2726.501384**
versus constant-clock costs **2836.592416 / 3007.205115**. The earlier feasible
join at **6.401112 seconds** costs **2749.852634**. Lower residual than both nulls
therefore does not establish the correct change time.

| Doubling output | Aligned F1 | Matches / extras / misses | Interpretation |
| --- | ---: | --- | --- |
| Previous joint-selected step clock | .943396 | 25 / 2 / 1 | Two early extra beats |
| Conditional localized clock | .920000 | 23 / 1 / 3 | Late switch loses a real beat; alignment adds a separate error |

Before onset alignment, the localized clock scores **.960000**: 24 matches,
zero extras and two misses. The initial reference beat remains missing, and the
late switch misses the beat at **6.796667 seconds**. Alignment then moves the
final raw beat from **13.199819** to **13.172971 seconds**. Its nearest reference
error increases from **11.859 ms** to **38.707 ms**, outside the fixed 30-ms gate.
This distinguishes a change-timing failure from an alignment failure; reporting
only the improved raw score would hide the regressed listening path.

Per-band residual diagnostics reproduce every original inference field exactly.
Their separate minima are **12.001112 seconds (low), 7.201112 (mid), and 6.401112
(high)**. The disagreement is consistent with the fixed endpoint templates
conflating evolving spectral patterns with clock timing; this is an inference,
not proof of the musical role of any band. Do not choose favorable band weights
or training lengths from this recording. The phase/tempo model needs a way to
retain changing patterns and timing uncertainty.

The other five clocks are copied unchanged by applicability: acceleration stays
.948718, stable arpeggio .963855, and the three authored cases 1. These are
preservation checks, not evidence that this model localizes their changes.
The maintained selector and the experimental relationship-competition path both
remain unchanged. No held-out source or automatic-admission claim is added.

Checked stable Win64 controls, bound source identity, complete feature accounting,
phase-equal joins, full fit/clock replay and independent matching pass. The detailed
report replays byte-for-byte. Raw/aligned diagnostic cue WAVs each reopen at
599760 stereo frames / 44100 Hz with 24 cues, matching hashes and no clipping;
peaks are .629150391 / .698272705. They retain Rico Rosenbusch / CC BY 4.0 source
attribution and are unassessed listening aids. No compiler warnings or unfreed
blocks appear. All evidence is under `build/beat-switch-localization/`.
Policy SHA256:
`123af8ffe83128b2f39dbbacccddf7095ae86405e4751f9cbdafb92e01d3da13`.

**Decision:** reject this fixed endpoint-template candidate. Continue
[WAV-02-PULSE](MILESTONES.md#wav-02-pulse) with evolving band-pattern/clock
hypotheses, interval coverage and phase uncertainty. Protect valid raw beats when
alignment has competing onset explanations. These requirements join the existing
metrical, endpoint and independent-recording gates; a timing-only or raw-score
improvement cannot clear automatic context admission.

<a id="alignment-context"></a>
## Neighbour-supported alignment preserves uncertainty — 2026-09-20

Candidate inspection separates two alignment failures. The localized doubling
clock has a weak but correctly timed onset at 13.217007 seconds; the existing
weight/distance score instead chooses the slightly stronger event at 13.172971.
The arpeggio has no suitable measured onset near its final valid raw beat.
Choosing another onset and declining alignment are different required outcomes.

The declared study uses up to two adjacent beats on each side as witnesses,
excluding the current beat. At least two original observed alignments must be
available within the same run. Their signed offsets, together with zero, form
an allowed interval with one sample of rounding allowance. The existing
weight/distance rule chooses among original eligible candidates inside it.
Original gap/restart/rejected-phase and disjoint-candidate bounds remain intact.
Witnesses are frozen before contextual decisions, avoiding recursive reinforcement.

No eligible candidate means **alignment unknown**, retaining the raw frame only
for a diagnostic clock. Fewer than two witnesses means **context unavailable**,
retaining the original choice. Neither is automatic admission. This is a local
support assumption, not calibrated confidence. Controls preserve constant and
alternating offsets, interior gradual drift and run isolation. Unsupported drift
extrapolation stays unknown. Identical observations labeled as an isolated genuine
departure or a distractor cannot be distinguished by this rule.

### Development results and observed coverage

The instrumented copy captures the maintained clock's exact candidate cells;
complete saved-clock fields and original selected observation indices agree
before refinement. The six sources use both baseline and joint-selected step
clocks. A seventh diagnostic uses the rejected localized doubling hypothesis.

| Joint-selected source | Original aligned F1 | Context diagnostic F1 | Context-supported onsets / output frames |
| --- | ---: | ---: | ---: |
| Stable arpeggio | .963855 | .987952 | 28 / 42 |
| Abrupt doubling | .943396 | .943396 | 17 / 27 |
| Acceleration | .948718 | .948718 | 22 / 38 |
| Authored regular | 1 | 1 | 22 / 24 |
| Authored polyphonic | 1 | 1 | 18 / 23 |
| Authored 120→100 | 1 | 1 | 22 / 24 |

The localized doubling diagnostic improves from .920000 to .960000, with 16/24
context-supported observations. Its late-switch miss remains, so this does not
rehabilitate that rejected inference model. None of the baseline paths regress.
Full-output F1 includes raw fallback; counts include all output frames, while
the established metric excludes predictions outside the reference span.

Observed-only precision/recall for the three joint-selected recordings is
**1/.642857, .882353/.576923, and .954545/.525000**. These outcomes make the
coverage limit explicit: an improved diagnostic clock is not reliable admission
of all observed beats, nor a calibrated rule for rejecting musical timing.

### Frozen checks on previously unused dataset examples

After freezing the rule, the first three unused dataset IDs were evaluated using
the maintained default tracker and step clock. All three inferences completed
before the separate evaluator read their full annotations. ID 01's first three
calibration timestamps had been inspected for format during setup, after the
rule froze but before the written protocol; it is a calibration check, not a
fully untouched reference. IDs 03 and 04 had unused audio/timing references.
Their descriptions were known. These related dataset examples do not establish
independent natural-music or genre generalization.

| New probe | Original → context full-output F1 | Unknown snaps | Observed-only precision / recall |
| --- | ---: | ---: | ---: |
| 01, calibration | .974359 → .974359 | 0 / 19 | 1 / .95 |
| 03, rhythmic deception | 1 → 1 | 20 / 44 | 1 / .558140 |
| 04, polyrhythm | .373626 → .373626 | 20 / 56 | .40 / .378378 |

Each passes the declared per-recording nonregression gate, with no subsequent
rule change. That gate tests one conditional refinement assumption. The
polyrhythm path remains near 144 BPM while the annotated beat level differs;
alignment cannot resolve that metrical choice. The deception result shows that
the local witness rule can decline many otherwise accurate snaps. No automatic
provider gate closes.

Used ARTBeaT IDs are now **01, 02, 03, 04, 05 and 19**; **19 examples remain
unused**. Earlier statements about 22 unused examples describe their historical
checkpoints. These three new probes cannot count as fresh held-out evidence for
later changes. Source attribution remains Rico Rosenbusch, CC BY 4.0.

Checked stable Win64 controls, original-candidate parity, actual core/raw/aligned
parity on new inputs, bound source/report identities and the independent matcher
pass. The complete deception report replays byte-exactly. No maintained source,
default, format, package or listening verdict changes. Evidence is under
`build/beat-alignment-context/`. Policy SHA256:
`786edca0cfcbd1ffaaf1e64613d2b39e275249bd1e12c1431bfd7602f78c85a6`;
new-input protocol SHA256:
`7c551c9790566b56e95dcbdd3655bbd98a1c052635949fe46a2dde324da28ecc`.

The subsequent [public alignment API](#alignment-api) adopts this explicit
optional policy with unknown decisions, preserved barriers and default replay.
Automatic [PULSE](MILESTONES.md#wav-02-pulse)
admission still needs evidence distinguishing genuine departures from distractors,
metrical/part relationships, evolving clocks and useful observed coverage; raw
fallback accuracy cannot substitute for those outcomes.

<a id="alignment-api"></a>
## Optional alignment API — 2026-09-20

[pythian.beat.alignment](../src/pythian.beat.alignment.pas) provides
`AlignBeatObservationsWithContext(cells, observations, sourceFrames)` independently
of tracking, WAV analysis and WFC. Each cell declares its raw sample frame,
inclusive candidate bounds, tolerance and nondecreasing continuity `RunId`.
Cells must be ordered, disjoint, source-bounded and contain their raw position;
candidate bounds cannot exceed tolerance. Observations must be strictly ordered,
source-bounded and finitely weighted in (0,1]. Work is bounded by 65536 cells,
8192 observations, 64 eligible candidates per cell and 262144 candidate visits.
Inputs are borrowed, results detached, and a failed assignment preserves the
caller's previous result. Global weight normalization retains very quiet evidence.

The fixed `two-neighbour-offset-envelope` policy uses up to two original observed
choices on each side within the same run. With at least two witnesses, eligible
offsets must lie within the witness envelope including zero and one sample of
rounding allowance. Existing weighted-distance scores rank the surviving choices.
The result retains the selected and original observation indices, witness count,
offset envelope and separate `Unknown` / `ContextUnavailable` flags. Unsupported
alignment retains the raw frame and observation -1. Insufficient context keeps
the original choice; it may also be unknown when no observation exists. Witnesses
never use newly refined choices. This is conditional onset refinement, not a
confidence score or musical admission rule.

Set `TBeatClockOptions.AlignmentMode := bcaNeighbourSupported` to use this policy
with the clock's exact existing candidate cells. Missing windows, explicit
restarts and rejected phase intervals bound both candidates and witnesses.
`AlignmentChoices` is empty in the default independent mode. The beat and
context tools accept `--alignment-context` after `--clock linear|step`; their
optional clock reports retain the policy and every decision. Explicit
[context admission](WAVE-CONTEXT-ADMISSION.md#reconstructed-clock-ranges) binds
that report into the saved provider evidence without a new format.

Checked stable Win32/Win64 and trunk Win32 core fixtures cover competing onsets,
alternating timing, drift, unknown endpoints, missing context, barriers, quiet
evidence, ownership and rejected inputs. Existing track/context fixtures pass
on stable Win64. Adoption reproduces complete default clocks and every contextual
decision on all nine recorded/authored study probes: both frozen selected paths
on the original six, the default path on IDs 01/03/04, and the rejected localized
doubling diagnostic. This is implementation parity, not new held-out evaluation.
The beat tool preserves the prior default report and WAV byte-for-byte. Optional
report fields match the study; its cue WAV reopens with matching hash/geometry
and peak .517486572. Saved authored and recorded context paths pass actual WFC
replay. Evidence is under `build/beat-alignment-adoption/`; current delivery is
recorded in [packaging](PACKAGING.md#current-api-delivery).

No new musical acceptance or listening verdict follows from adoption. The
polyrhythmic beat-level failure, genuine isolated timing versus distractors,
evolving-clock inference, endpoint support and useful observed coverage remain
in [PULSE](MILESTONES.md#wav-02-pulse).

<a id="band-pulse-comparison"></a>
## Separate band pulse paths fail musical selection — 2026-09-20

Separate frequency-band pulse paths expose additional evidence but **do not
resolve the polyrhythmic beat level or replace the maintained onset path**.
This comparison uses only the nine existing development inputs. The known
96-BPM annotation on ARTBeaT 04 was already inspected during diagnosis; none
of these measurements is a fresh held-out test.

Native analysis retains the existing [0,200), [200,2000) and [2000,Nyquist]
bands, plus full-spectrum flux as a matched measurement control. Each stream
supplies positive local maxima over two feature neighbors on each side, with
earlier plateau ties and complete-window context. Observations use the feature
center, not a localized transient. Weights normalize within a stream; reports
also retain original maximum flux and integrated flux share. Weak-band
normalization is not confidence, and frequency bands are not instrument labels.
Unchanged default candidate scoring/path selection and the maintained step clock
with optional contextual alignment process each stream independently. Every
candidate, selection and unknown decision remains inspectable.

Feature controls recover 96/144/120-BPM pulses, preserve positive-gain scaling,
reject silence/incomplete context and retain the earlier plateau maximum.
Native two-carrier WAV controls recover simultaneous 96/144 pulses when their
low/high roles are swapped, as well as a common 120 pulse. These controls establish
separable constructed rhythms; they do not choose which rhythm is a musical beat.

All source inference precedes reference scoring. Full-output F1 below uses the
unchanged 30-ms matching and reference-span policy. **Baseline is the maintained
default selection plus contextual alignment**, not the experimental joint-selected
path used in some earlier tables. Scores include raw fallback; they are not
observed-only coverage or precision.

| Development input | Baseline | Full flux peaks | Low band | Mid band | High band |
| --- | ---: | ---: | ---: | ---: | ---: |
| 01 calibration | .974359 | .655172 | .000000 | .655172 | .655172 |
| 02 arpeggio | .987952 | .926829 | .134831 | .963855 | .987952 |
| 03 deception | 1.000000 | 1.000000 | .068182 | .976744 | .729412 |
| 04 polyrhythm | .373626 | .395604 | .118812 | .395604 | .395604 |
| 05 abrupt doubling | .847458 | .847458 | .276923 | .866667 | .847458 |
| 19 acceleration | .897436 | .987342 | .063492 | .936709 | .987342 |
| Authored regular | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| Authored polyphonic | 1.000000 | .677966 | .000000 | .246154 | .677966 |
| Authored 120→100 | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |

The acceleration gain cannot offset calibration/polyphonic regressions.
Calibration's full/mid/high paths choose approximately 240 BPM against the
maintained 120. On polyrhythm, full/mid/high paths still principally choose 144;
the low band has no stable correct solution. Their flux shares are .331322,
.366941 and .301737, so choosing a band by total strength is not established.
High-band observed-only precision/recall is .483871/.405405: frequent abstention
does not turn the remaining choices into reliable musical beats.

### Candidate availability and the known-rate diagnostic

In the polyrhythm, a candidate within 1 BPM of the known 96 appears in 13/24
full-flux windows, 6/24 low, 12/24 mid and **24/24 high**. No stream selects it.
The high-band candidate pool therefore has rate information that its chosen
path ignores. Presence in the pool is not proof of correct phase or quarter
identity.

A separately declared, explicitly reference-informed diagnostic selects the
high-band candidate nearest 96 BPM in each window, using its existing score
and then index to break ties. It uses no annotated beat phase/timestamps in
reconstruction, preserves existing owner/support/run boundaries, and scores only
afterward. This produces 38 output positions; within the scored scope it has
**24 matches, 13 extras and 13 misses: F1 .648649**, identical before/after
alignment. Its 26 context-supported observations have precision .576923 and
recall .405405. Even supplying the known rate leaves substantial phase error.
This is a diagnostic using a known answer, not an automatic improvement or a
reason to prefer the high band, hardcode a rate or add a generic tempo prior.

**Decision:** reject raw band-peak paths as a replacement or automatic band-vote
policy. Preserve localized onset admission while investigating joint competing
patterns, metrical interpretation and phase. Both the retained 96-BPM alternatives
and the known-rate phase failures must constrain that work. More band votes or a
rate-only preference does not address the demonstrated failure; the changing-rate
and stable/polyphonic controls remain mandatory comparisons.

### Work bounds and verification

Raw peaks are substantially denser than admitted onsets. The original study
completed IDs 01/02/03, then the maintained 64-million per-stream fit bound rejected
04 before reference scoring. That failed condition is retained. An explicitly
separate study copy raises only its work cap to 128 million per stream; the unit
name is its only other tracker change. At most 4096 features, radius-two peaks,
32 windows and 801 trials give a conservative 98992386-visit per-stream bound.
The 16-million per-window bound remains. The four-stream study cap is 512 million;
actual totals range from 93180330 to 255569463, with a largest individual fit of
64430037. **Maintained library bounds and algorithms do not change.** This is
not evidence of practical many-hour ingestion.

Checked stable Win64 controls and all final measurements/evaluations terminate
without owned warnings or unfreed blocks. Native audit verifies the two allowed
tracker text changes, report-helper import-only changes, source/score bindings,
flux conservation, work sums and exact preservation of the first three reports'
musical fields under the expanded bound. The complete 04 report replays byte-for-
byte. Initial evaluation failures in diagnostic logging/schema and an authored
reference path were corrected without changing matching or inference; their logs
remain alongside the successful results. No additional target, listening verdict,
package refresh, source format or held-out use is claimed.

Evidence is ignored under `build/beat-band-pulses/`, with final reports in
`expanded/`. The original policy SHA256 is
`060f29a422bf7b1288ef5e2e2966dbc42837bfc51ccca755fea010c2c9e9685a`;
work-bound amendment
`1753c9177088fce0dbab485c632dfd2c5833aab60d4d116259572b8be3156a71`;
known-rate diagnostic
`3d0c94261d13a2eb3013357b6509e7647d4392f6351141baf5772cd6127b8d94`.
Public source attribution remains ARTBeaT by Rico Rosenbusch, CC BY 4.0, with
the previously retained notices. [PULSE](MILESTONES.md#wav-02-pulse) owns musical
selection/phase work; [VALIDATION](MILESTONES.md#wav-validation) owns practical
observation cost and admission scope. No north-star outcome closes.

<a id="conditional-phase-path"></a>
## Retained phase paths under declared rate context — 2026-09-20

The preceding known-rate failure is primarily a choice among retained phases,
not an absence of useful local evidence. A source-bound diagnostic compares
near-96-BPM candidates at each of the 37 annotated polyrhythm beats. The old
nearest-rate selection supports 25 within 30 ms; some retained candidate supports
**all 37**. Twelve reference beats lose their phase during local selection, and
one additional locally supported beat is lost when those choices are joined.
These nearest-distance counts diagnose reference coverage; they are not a separate
one-to-one accuracy score or an annotation-informed selection policy.

A declared comparison then keeps the same high-band pool and known ±1-BPM range
around 96. It compares the old nearest-rate rule, highest local candidate score,
and the existing continuous path objective with its unchanged .5 tempo/.5 phase
penalties and 1.5 ratio limit. No reference timestamps enter phase selection.
Missing pools and explicit restarts retain their boundaries; all outputs use the
same maintained step reconstruction and optional contextual alignment.

| Conditional selection | Full-output F1 | Matches / extras / misses | Context-supported observations; precision / recall |
| --- | ---: | --- | --- |
| Previous nearest rate, local score tie | .648649 | 24 / 13 / 13 | 26; .576923 / .405405 |
| Highest local score within declared range | .864865 | 32 / 5 / 5 | 27; .846154 / .594595 |
| Continuous candidate path within declared range | **.986301** | **36 / 0 / 1** | **21; 1 / .567568** |

Raw and aligned F1 are equal in each row. The continuous path emits 37 positions,
36 within the scored reference scope; the initial beat remains missed. Its
full-output accuracy includes raw fallback and does not erase limited observed
coverage. Controls independently enumerate a small graph optimum and cover
transient wrong local winners, equal alternatives, real restarts, missing windows,
incompatible joins, replay and detached ownership. Costs and eligibility are not
tuned after the recorded result.

The existing maintained command with the same known rate range is also checked:

```text
pythian.beats INPUT.wav REPORT.json 95 97 --track --clock step --alignment-context --audition OUTPUT.wav
```

It remeasures localized combined onsets and refits a restricted pool, rather than
reselecting the retained high-band alternatives. On this source it obtains only
.438356 raw / .410959 aligned F1. Thus the useful result depends on retaining
appropriate phase evidence as well as constraining rate; a generic rate-only
preference or changing the default search range is not justified. Its diagnostic
cue WAV reopens with matching source geometry/hash and peak .814910889; no listening
verdict is inferred from that check.

The [public candidate-path query](#candidate-path-api) now reproduces every
conditional study choice, clock field and unknown decision. This is reusable
conditional selection, **not automatic 96-BPM admission or a high-band policy**.
The rate and band in this development diagnostic were informed by earlier
reference-based inspection. Other band paths previously regress, and no new
held-out recording is used. Automatic work must infer metrical interpretation,
competing patterns, phase and relevant observations jointly while retaining
ambiguity, practical cost and the existing stable/changing-rate controls.

Default clock and contextual choices remain exact on all nine existing study
inputs, including both frozen paths on the original six and the rejected
localized diagnostic. The constrained native tool report/audio also replay
unchanged. Public selection checks pass stable Win32/Win64 and trunk Win32;
the existing clock/admission fixture passes stable Win64. Fresh source packages
and extracted consumers verify delivery separately. Evidence is ignored under
`build/beat-phase-context/`; no format branch or automatic default promotion is
added. The observation/scoring work runs on checked stable Win64 only.

Accounting policy SHA256:
`66505dc2e878f59c8a365f5d020a5f7688d816fab063ee5c1f513f00f7c203db`;
path policy:
`6900c8676b529824f426553568e5d790e68cdbfc34e73955826dde3915c67036`.
The same ARTBeaT source and retained CC BY 4.0 attribution apply. Musical
acceptance remains under [PULSE](MILESTONES.md#wav-02-pulse) and
[VALIDATION](MILESTONES.md#wav-validation).

## Maintained phase-family measurement — 2026-09-19

The bounded 64-bin/two-phase fitter and eight-slot phase-family selection are now
the maintained implementation. Adoption preserves the reviewed prototype's fit,
selection and tracking behavior. Circular-coherence names are replaced with
`PhaseConcentration`, `MatchedWeightFraction` and `MinimumMatchedWeight`, and
reports name the measurement policy. The estimator and tracker share one work
calculation; fewer than four observations do no fitting. The old fitter and old
report fields are not retained as compatibility branches. This is a pulse
measurement contract; automatic quarter-note admission remains a separate gate.

On the three existing ARTBeaT development WAVs, native audits map only the
prototype's temporary measurement names and then verify exact source/onset inputs,
original candidate metrics, complete local-track records and audition bytes on
stable Win64. Fixed evaluation reproduces aligned 30-ms F1 0.9639 / 0.8475 / 0.8974.
Compared with the earlier maintained baseline, these were 0.2813 / 0.8475 / 0.5714.
No additional recording or held-out example was used for adoption.

Checked stable Win32/Win64 and development Win32 pass existing beat, tracker and
explicit-context admission fixtures. The beat fixture now includes seven
subdivision/accent/mixture controls, analytic matched-weight/concentration
measurements and one/odd-slot capacity. The tracker reaches its 512-window limit
on silence without fictitious fit charges. Across all three targets, the three
WAVs retain exact onset frames, raw/adjusted pulse frames and observation indices.
For the arpeggio, Win32 onset weights differ from Win64 by at most 6.94e-18 and
one PCM scalar sample differs by one quantization unit; the other two audition
WAVs are byte-identical. Do not claim universal byte-identical cross-target audio.

The native lab exposes a fixed-grid ranking regression: the polyphonic source
now leads with 192 BPM and 19 extra pulses, whereas the old leading 96.25-BPM
grid had none. A retained 96-BPM candidate at index 1 still matches all 20
references without extras, and the local path also matches all 20 without extras.
Regular and changing-clock tracked lab cases match all 24 references without
extras. The lab now checks reference-grid availability for constant-clock cases;
it continues to publish every candidate and the wrong first-ranked result.
Adoption improves the pulse alternatives/local path; it does not establish
correct fixed-grid rank-zero musical selection. This tradeoff remains a clearing
constraint for [WAV-02-PULSE](MILESTONES.md#wav-02-pulse).

Stable Win64 also verifies the real companion path: explicit admission of 24
tracked source pulses saves a 46-cell context profile; reloading it drives WFC
key/tempo passes and 23 authored pulse tones in 555660 output frames. Independent
source/report/profile and pulse-gate checks pass. This is base-context playback,
not learned voice generation or genre-quality acceptance. The event-remix
consumer rebuilds with the current measurement fields.

The next work remains temporal band evidence, explicit metrical alternatives,
alignment and uncertainty. Correct candidate availability alone does not clear
automatic [WAV-02-CONTEXT](MILESTONES.md#wav-02-context), hence semantic
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration). Local-key, phrase, corpus
and fundamentals work remains independently ready. Delivery must verify the new
source checkpoint; earlier packages cannot establish its delivery acceptance.

Evidence is ignored under `build/beat-promotion/`: adoption protocol, retained
pre-change core sources, three-target logs, native semantic/cross-target audits,
fixed evaluations, lab reports and source/profile/audition files. All processes
are terminal. No dependencies, branch or index changed; no new fixture program,
historical format branch, listening acceptance or percentage allocation is added.
