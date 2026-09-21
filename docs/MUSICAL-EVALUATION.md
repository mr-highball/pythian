# Shared musical evaluation

[Home](../README.md) · [Validation task](TODO/NS-3_validation_01.md) ·
[Corpus protocol](CORPUS-EVALUATION.md) · [Work](WORK.md)

`pythian.evaluation` supplies portable evidence-binding checks, ordered event
matching and aligned categorical/scalar scoring. It depends only on the native
core and RTL. It does not infer musical truth, read source assets, detect related
recordings or certify style quality. Provider accuracy and independent acceptance
remain separate from a valid score calculation.

The [file-bound operator](EVALUATION-OPERATOR.md) now verifies actual WAV and
document bytes, exact observation clocks, vocabulary/scoring policy and a separate
exposure ledger before returning event, categorical or scalar scores. Its
single-case verdicts remain distinct from provider/style acceptance. Its `notes`
metric now combines exact label coverage/precision with the existing interval
scorer and the unchanged onset/full-note gates, checking that intervals and
observation cells describe the same inferred notes.

## Evidence and clocks

`TEvaluationBinding` identifies source bytes, preparation, reference annotations,
annotation policy, scoring policy and estimator with separate SHA256 digests.
Preparation includes decoding, channel choice, gain and rate conversion, even
when the selected preparation is identity. Estimator identity includes the
algorithm/model and the inference policy; a model name alone is insufficient.
The recording family, experiment partition, previous tuning exposure and known
external-model training overlap are explicit declarations.

References and predictions share an absolute prepared-source sample clock and
a nonempty half-open `[first,end)` scope. Integer-millisecond timing tolerances
round to the nearest frame, with exact positive half ties rounding up. This is
an explicit new helper contract; it does not change existing pitch annotation
conversion or its recorded rounding policy. A different preparation or boundary
rounding policy requires different bound evidence, not a silent interpretation.

`RequireSameEvaluationBinding` rejects any mismatched digest, source clock,
scope, family, partition, reference-completeness or exposure declaration. Missing
digests reject. An unverified family is development-only; a family used for
tuning cannot remain evaluation. Callers must first verify actual asset bytes
and consult the complete family/exposure ledger, including prior uses and palette
or model ancestors outside the immediate plan. The record cannot establish that
a caller's declarations are truthful or complete.

`IsIndependentEvaluation` indicates **eligibility**, not a passing musical result.
It requires verified unused evaluation identity, complete references for the
declared scope, and either no learned estimator or established disjoint external
training data. Unknown overlap and known overlap are distinct, both ineligible.
Development data can be scored; it cannot become independent evidence merely
because its numerical scores pass. Empty or uncertain references do not provide
positive coverage. Acceptance must additionally apply the provider's frozen
coverage/error criteria and the required independent-recording coverage.

## Shared scoring semantics

`EvaluateEvents` takes strictly increasing reference/prediction frame arrays and
an explicit scope. Duplicate or out-of-scope points reject rather than being
silently cropped. Equal-tolerance ordered one-to-one matching reports matches,
misses, extras, precision, recall, F1 and absolute timing-error sum. Each reference
can match once. The deterministic earliest matching maximizes match count;
its error sum is not a minimum-error assignment. Empty-reference recall and F1
are zero. Events with different roles or metrical meanings require separately
declared comparisons; a pulse array does not establish quarter notes or downbeats.

`EvaluateCells` compares explicit common observation centers. Categorical values
match exactly under a bound vocabulary. Scalars compare absolute error under a
bound unit/tolerance and retain compared count, error sum and maximum error.
The scorer rejects mismatched centers, invalid states, nonfinite scalar values,
unordered/duplicate centers and count/scope overflow. Unknown predictions must
remain in the grid; deleting difficult centers is not valid evaluation.

Reference states are value, rest, unknown, ambiguous or unsupported. Unknown,
ambiguous and unsupported annotations remain visible as separate counts, with
admitted values in those cells reported as unscorable. An estimator's unsupported
pitch/range is instead an unsupported **prediction against a known reference**,
so it remains in the active-coverage denominator. Reference rest is independent
of the estimator's silence/activity decision.

For categorical and scalar cells:

- Active coverage = correct / annotated active reference cells, including wrong
  and unavailable predictions in the denominator.
- Precision = correct / (correct + wrong + admitted values in reference rests).
- Reference coverage = (annotated active + annotated rest) / all declared centers.
- Unknown-active includes non-value predictions; measured rest-in-active is also
  reported separately. Measured rest and unknown in reference-rest cells remain
  distinguishable. Scalar errors include incorrect admitted values, while missing
  values remain visible through coverage rather than a fabricated zero error.

Budgets are 1048576 cells or events per supplied array, frame coordinates through
2^53-1, and event tolerance through 10^9 frames. Inputs are borrowed. Functions
return values only after validation/scoring succeeds, preserving an existing
caller assignment on failure. No product artifact format or historical reader
is introduced.

## Provider contracts and remaining admission work

The following maps the declared musical outputs to scoring primitives. A row
describes the required comparison, not a claim that its learned provider is
accurate or that all annotations and admission thresholds already exist.

| Provider / input class | Reference and output | Error/coverage contract |
| --- | --- | --- |
| Monophonic notes / separately attributed voices | Absolute MIDI at observed centers, note onset/end intervals | Exact labels; active coverage and precision include rest false positives. Existing `pythian.pitch.evaluate` owns one-to-one onset/full-note matching and overlap/edge semantics. Preserve >=80% coverage, >=98% precision, onset F1 >=0.80 and full-note F1 >=0.70 per recording. |
| Timing / scoped beat observations | Annotated event frames with declared metrical level; local clock/rate where available | Event misses/extras and timing error on a reference-defined scope. Primary recorded comparison is 30 ms; 70 ms remains a separately named diagnostic. Phase/level/coverage must not be replaced by provider agreement. Automatic admission thresholds remain with the tempo tasks. |
| Local key / tonal passages | Root/mode vocabulary at reference centers, with explicit ambiguity and unknown spans | Exact categorical identity, coverage and incorrect admissions; the vocabulary/policy must define modes and spelling equivalence. Independent local-key references and admission remain with context tasks. |
| Part ownership / attributed stems and mixtures | Stable declared part IDs and per-part note/activity references | Separate part/voice comparisons and ownership errors; dominant parts cannot hide missing quiet parts. Joint role/pitch vocabularies and crossing/overlap annotations remain with part tasks. |
| Harmony / annotated harmonic passages | Chord/root/pitch-class-set labels and change events | Frozen categorical vocabulary plus change timing. Unknown harmony cannot become a rest or arbitrary major chord. Annotation conventions and thresholds remain with harmony work. |
| Groove / annotated rhythmic parts | Per-role events, accents and microtiming relative to the annotated clock | Per-role timing/missing/extra events and scalar accent/microtiming error in declared units. Preserve rests and uncertain metrical interpretation. Joint relationships remain with groove work. |
| Evolving sound / supported recorded source classes | Source-bound normalized spectral/envelope features and reconstruction evidence | Scalar error with finite units, coverage and explicit unsupported observations. Learned pitch must not substitute for timbre fit; listening/reconstruction and calibrated limits remain with timbre tasks. |

Do not derive annotation truth from the estimator under evaluation. Shared
work in [NS-3_validation_01](TODO/NS-3_validation_01.md) binds each
comparison to its declared input class, output/role, annotation convention and
frozen vocabulary/unit, and exercises reference-preserving versus reference-breaking
controls across those outputs. The structured annotation/input/output contract
and its controls pass final checked stable Win32/Win64 verification. The file
operator's existing ancestry controls passed on checked stable Win32/Win64, but
infrastructure review found that the prediction root is never required or
traversed. Shared admission is reopened for that defect and its missing controls;
the earlier checks do not establish complete prediction ancestry. Hash-bound
declarations also cannot prove an omitted source relationship or annotation truth.

Calibration, independent recorded accuracy, production admission and provider
integration remain with the named tempo, context, notes, parts, harmony, groove
and timbre tasks. Their criteria must freeze before their independent evaluation;
the shared task does not need their final accuracy results to finish. This keeps
its existing scope of shared scoring/admission semantics separate from the
provider outcomes that depend on it. Native inference execution/cost is owned by
[NS-3_validation_02](TODO/NS-3_validation_02.md).

## Fixed next-experiment budgets

These are predeclared development investigations, not executed results or provider
acceptance. Each affected task must preserve its final acceptance criteria. Run
one hypothesis at a time, freeze its input/policy identities before prediction,
save predictions before independent scoring, and retain failed outcomes. An
implementation correction may rerun the same frozen comparison once; a changed
hypothesis requires a new written decision, not an unbounded parameter sweep.
Previously untouched evaluation stays closed until inference and admission freeze.

### Pitch identity and presence

Owner: [recorded identity](TODO/NS-3_notes_01.md), coordinated with
[presence and boundaries](TODO/NS-3_notes_02.md).

- Baseline: the preferred entry-activity inference in the
  [recorded phrase evidence](PHRASE-EVALUATION.md#rate-view-strength), reproduced
  by `pythian.evaluate` from original annotations and retained intervals. Flute
  has 1706 correct centers, 105 octave errors and 45 rest admissions; violin has
  2178 correct, no octave errors and 23 rest admissions. Preserve the recorded
  source, inference and reference identities in each case. Reproduce all four
  phrase metrics before attributing any change to a new hypothesis.
- Next discriminating hypothesis: phase-consistent prediction of the next
  waveform window, evaluated separately under adjacent-octave hypotheses, can
  supply identity evidence missing from pooled activation strength. Phase must
  be estimated without reference notes; fixed-phase oracle reconstruction alone
  does not test the hypothesis. Pure even-harmonic ambiguity must remain unknown,
  not become a fabricated confident fundamental.
- Fixed experiment allowance: one new observation rule and one removal-of-that-
  observation ablation. Reuse the existing low/short/quiet/gap/mixture waveform
  controls; add at most two authored controls that directly distinguish the
  hypothesis. Then at most one prediction/scoring pass per condition on each
  existing 30-second development recording. No new network inference or capacity
  comparison is part of this experiment. Limit each candidate run to 15 minutes,
  512 MiB peak working memory and 256 MiB of new observations per excerpt; record
  measured cost and stop on overrun rather than silently increasing the limit.
- Continue only if the waveform controls pass, real octave changes remain
  distinguishable, and paired accounting shows fewer wrong octave admissions
  without losing previously correct coverage or passing violin behavior. A
  precision gain obtained only by suppression fails this discriminator. Stop
  this approach after the one candidate/ablation comparison if the observation
  does not separate those cases; do not retry global strength or confidence sweeps.
- Provider acceptance still requires coverage >=80%, precision >=98%, onset
  F1 >=0.80 and full-note F1 >=0.70 per recording, then frozen independent
  evaluation. Passing an experimental discriminator is not that acceptance.

The pitch experiment allowance above was consumed on 2026-09-21. The frozen
[predictive-phase comparison](PHRASE-EVALUATION.md#predictive-phase) passed
physical controls but changed no recorded notes in either condition. Its
continuation criterion failed; retain the baseline and do not retry thresholds.
Reassess discriminating identity/presence evidence before a new preregistration.

### Metrical selection and changing clocks

Owners: [beat level](TODO/NS-3_tempo_01.md) and
[changing clocks](TODO/NS-3_tempo_02.md).

- Baselines: the native/default and model-plus-candidate results for the nine
  existing cases in the [joint comparison](BEAT-TRACKING.md#model-candidate-comparison).
  The four cached band pools, source scope, 30-ms primary matching and separate
  70-ms diagnostic are fixed. Reproduce source identities, selected candidates
  and both reference-range/full-output scores before a new comparison.
- Next discriminating hypothesis: an explicit competition among half-, same-
  and double-rate interpretations, scored by repeated accent/role structure over
  adjacent windows, can distinguish mutually agreeing wrong levels from a
  supported metrical choice. Agreement alone cannot admit a level; inconclusive
  structure must retain alternatives/unknown, including changing-pattern spans.
  No reference rate or per-recording band selection may enter inference.
- Fixed experiment allowance: one selection rule and one ablation removing the
  structural evidence, over the same nine development cases. Use cached model
  and band observations; no new model or recording acquisition. Retain the
  existing bounds of 32 owners, 32 candidates per owner, 128 model events,
  64 local grid points and 524288 matching visits. Limit each excerpt to five
  minutes and 512 MiB peak working memory; cap the whole comparison at 30 minutes.
- Preserve automatic deception/polyrhythm gains and test doubling, acceleration
  and all three authored controls explicitly. Report observed-source coverage,
  unknown windows, wrong-level admissions and full-output errors alongside F1;
  abstaining on difficult windows cannot masquerade as improved overall coverage.
  Stop after the declared comparison if common wrong levels remain admitted or
  the authored/changing-clock baseline regresses. Switch the evidence model,
  not another agreement threshold. Independent matching must still agree.

The metrical experiment allowance was consumed on 2026-09-21. The fixed
[source-accent comparison](BEAT-TRACKING.md#metrical-source-structure) preserves
deception/polyrhythm and improves acceleration and missing regular pulses, but
fails the declared general nonregression criterion on authored controls. Retain
its evidence without adoption or a threshold retry. Final source/recurrence,
ablation-parity and resource audits passed QA; the independent audit's clamp
precision correction changed no prediction or acceptance threshold.

Production backend selection, native arithmetic fidelity and aggregate many-hour
cost are owned by [native execution](TODO/NS-3_validation_02.md), not preaccepted
by these small studies. Experimental budgets are fixed stop conditions, not
claims that existing or proposed code already meets them.

## Verification — 2026-09-20

The maintained [fixture](../tests/pythian.tests.evaluation.lpr) passes checked
stable Win32 and Win64 with no unfreed blocks. It checks evidence mismatch and
exposure, missing references, partial/unknown external training overlap,
hand-derived cell/rest/scalar counts, half-frame rounding, duplicate and
half-open endpoint rejection. A bounded independent dynamic program verifies
event matching cardinality on ambiguous neighborhoods. `tools/build.ps1`
includes this fixture in the native core path.

The maintained [beat lab](../tools/pythian.beat.lab.lpr) now consumes the shared
event scorer. Its three authored cases retain exact pre-change report and WAV
bytes on stable Win64: regular, polyphonic and changing tempo. Existing lab
reference-window cropping remains explicitly its caller policy; the scorer
does not decide that scope or claim full-recording observed coverage.

A native audit also re-scores all 2997 retained centers from each preferred
flute/violin development result. It reproduces their prior counts and ratios:
1706/2178 correct, 112/9 wrong pitches, 45/23 admissions in reference rests,
82.4553%/87.0852% coverage and 91.5727%/98.5520% precision. These are parity checks
against the previously audited annotation assignments, not new inference or
independent evaluation. Flute still fails its 98% precision gate.

Evidence is ignored under `build/shared-evaluation/`: two-target core checks,
pre-change beat-lab source, before/after reports/audio and recorded score audit.
No held-out source was opened. No synthesis, inference, package or completion
percentage changes are claimed by this scoring consolidation.
