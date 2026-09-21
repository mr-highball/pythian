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
single-case verdicts remain distinct from provider/style acceptance.

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

Do not derive annotation truth from the estimator under evaluation. Per-provider
annotation/vocabulary adapters, full ancestry verification, calibrated admission
criteria and complete provider integration are still required by
[NS-3_validation_01](TODO/NS-3_validation_01.md). The APIs above do not close that
task on their own. Native inference execution/cost remains separately owned by
[NS-3_validation_02](TODO/NS-3_validation_02.md).

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
