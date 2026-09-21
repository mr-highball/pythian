# Mixture reference and admission policy

[Part evaluation](PART-EVALUATION.md) · [Reference preparation](PART-REFERENCE.md) ·
[Preparation task](TODO/NS-3_parts_01.md) · [Learning](TODO/NS-3_parts_02.md) ·
[Independent acceptance](TODO/NS-3_parts_03.md)

Freeze this policy on 2026-09-21, before using this packet to select or score a
mixture estimator.
The existing scripted controls have already been inspected and remain authored
development evidence. They are not blinded predictions. This policy makes the
existing scoring gates and remaining reference requirements explicit; it grants
no completion credit and changes no numerical threshold.

## Supported preparation and required scenarios

The first attributed-mixture packet targets bounded mono PCM16 WAV at 16000 Hz,
with separately available stems, a verified construction, original frame clocks,
and integer-semitone pitched events. Reuse the current exact authored construction
and separately identified derived external construction. Freeze each source,
window, stem mapping, gain, quantization and annotation policy before predictions.
No fitted gain, offset or resampling change may repair a failed acceptance run.
Retain distractors in the mixture instead of removing difficult sources after
observing results. This is a declared initial packet scope, not the final genre
coverage or a claim that arbitrary recordings are transcribed.

| Required scenario | Reference evidence and reported result |
| --- | --- |
| Bass with a lead/counterline | Time-local musical functions with documented reasons; per-role center and event results |
| Chordal accompaniment with simultaneous parts | Complete pitch sets and interval multiplicity, including chords with at least three notes |
| Pitch-order crossing | Stable identities and annotated before/after endpoints; endpoint correctness, wrong ownership and leakage |
| Repeated same-pitch overlap or unison | Separate event identities; center union distinguished from multiplicity and acoustic ownership |
| Quiet pitched part beneath other material | Nonzero isolated support and bound relative-energy evidence; missing/unknown predictions remain visible; no listening or perceptual-masking claim from energy alone |
| Rests and boundaries | Explicit known absence, attacks/endings, edge censoring and false admissions in rest |
| Uncertain ownership or sounding extent | Complete uncertain-region accounting, unassigned known pitches where justified, exclusions and no false independent verdict |
| Articulation/performance changes | Retained attack/release, controller and bend evidence; unsupported interpretation remains explicit |

The authored packet supplies deterministic controls for these measurement
boundaries. An external recording must establish real functions and acoustic
support rather than inherit the authored labels. Report which scenarios have
authored-only evidence, external development evidence, independent evidence or
no evidence. A missing scenario remains a gap, never an average over other cases.
Independent role-learning acceptance and representative style acceptance retain
their own task criteria; synthetic controls cannot discharge them.

## Role and acoustic annotation rules

Bass is the harmonic/rhythmic foundation in the passage; chordal is coordinated
harmonic support; lead is the foreground thematic or melodic line; pitched other
requires a positively described function such as a counterline. Instrument,
register, loudness, MIDI channel and filename alone establish none of these.
Roles can change over time and several stems can support one function. Retain
ambiguous regions when competing interpretations cannot be resolved.

Declare each case's role vocabulary before predictions. Every requested role
needs positive known reference events to support an accuracy verdict. An absent
role is missing coverage, not a perfect score. Unpitched percussion can have a
known source/function while integer-semitone note scoring is unsupported: do not
use drum key numbers as measured acoustic pitches. Keep that audio as declared
mixture context and report the unsupported event domain separately. Account for
all pitched contributors through known roles or explicit uncertainty/unassigned
evidence; do not silently omit an inconvenient pitched part.

Keep three distinct records: source identities and construction, symbolic key
gates/performance messages, and acoustic sounding annotations on the actual
prepared waveform. A controller or key gate is a reference aid, not an acoustic
endpoint. A digitally nonzero bin proves stored signal support, not note identity;
digital silence likewise does not recover a symbolic instrument's gate state.
Review can use score context, isolated audio, waveform/spectral evidence and
listening when available. Record the actual method, reviewer, revision and reasons;
never claim hearing, independent review or publisher confirmation that did not occur.

For each acoustic label retain the source event/stem identity, pitch and role
evidence, chosen half-open boundaries, temporal resolution and uncertainty.
Do not turn broad endpoint uncertainty into an exact interval by choosing a
convenient midpoint or a model's prediction. The current API excludes whole events
intersecting uncertain regions; retain that loss of coverage. Known `value` regions
assert complete exact annotations including gaps, while unknown/ambiguous/
unsupported regions remain distinct. Preserve repeated-note multiplicity and
source-contributor truth separately from identifiable ownership in the mix.

## Frozen scoring and dispositions

Use `part-notes` for joint center/event evaluation; `part-note-sets` remains a
center-only diagnostic. The required gates below are the existing operator gates,
applied independently to every declared role, never pooled across dominant parts.

| Measure | Fixed gate |
| --- | ---: |
| Correct reference pitch/center coverage | At least 0.80 |
| Scorable predicted pitch/center precision | At least 0.98 |
| Complete known reference coverage | 1.00 |
| Onset F1 | At least 0.80 |
| Full-note F1 | At least 0.70 |
| Annotated crossing endpoints | All correct; unavailable endpoints do not pass |
| Reference unassigned / extra or unscorable predicted unassigned pitches | None in an accuracy-pass case |

Timing uses exact pitch identity, 50-ms onset tolerance, offset tolerance equal
to the larger of 50 ms and one fifth of reference duration, and 110-ms scope-edge
exclusion. At 16000 Hz these fixed minima/edges are 800/1760 frames. Preserve
onset-only versus full-note assignments and their errors. Authored exact-arithmetic
controls keep their separate zero-tolerance policy; they do not substitute for
this recorded timing contract.

Report unique/ambiguous/unresolved wrong ownership, false-rest admissions, novel
pitches and the full leakage matrix. Wrong-owner errors are a subset of extras
and therefore consume the same maximum 2% scorable-prediction error allowance
implied by the precision gate; they are not ignored behind an overall note score.
Report each source case separately before any descriptive aggregate. No positive
reference or empty denominator means no supported accuracy verdict.

Uncertain-reference challenges have a different disposition from accuracy-pass
cases: they exercise preserved uncertainty and exclusion accounting, and must
not claim complete-reference or independent success. A high score on the known
remainder does not repair the missing truth. Do not delete the challenging region,
rename its role or change thresholds after seeing predictions. Reference preparation
can be accepted with explicitly documented uncertainty controls; learner accuracy
still requires complete, positive references for its declared supported cases.

## Recording families and task acceptance

The initial packet needs at least one verified development recording family and
one separate evaluation family, with the required role/scenario coverage recorded
explicitly. This is an initial reference-packet requirement, not enough evidence
for genre/generalization claims. All stems, mixes, excerpts and re-encodings of a
recording stay in its family and split. Register source-work identity and a bounded
duplicate/derivative review; different file hashes alone do not verify independence.
Unresolved membership stays provisional. The current second recording reservation
does not yet pass this gate.

Reference-only preparation exposure must be recorded separately from algorithm
tuning. Keep evaluation audio/labels and predictions out of implementation tuning;
freeze the final attribution/preprocessing/uncertainty policy before evaluation
use. If reference inspection influences implementation choices, that family becomes
development and independent acceptance needs fresh material. Model-training overlap
remains unknown unless appropriate evidence establishes it; no model is selected
by this policy. Current part metrics remain diagnostic-only and cannot grant
`independent_case_pass`; the final independent case/admission integration remains
part of the subsequent role-learning acceptance work.

After the [scope-preserving task split](MILESTONES.md#mixture-preparation-task-split),
`NS-3_parts_04` owns maintained native measurements, reference construction and
reproducible authored controls. `NS-3_parts_01` closes only when its external source
bindings, annotations, frozen families, scenario coverage and reproducible packet
satisfy all task criteria, with parts_04 accepted as its prerequisite.
`NS-3_parts_02` owns the actual attribution implementation and development
gates; `NS-3_parts_03` owns its untouched-recording verdict and saved-evidence path.
The split preserves the combined preparation requirements and total credit;
all numerical gates and scientific dispositions in this policy remain unchanged.
