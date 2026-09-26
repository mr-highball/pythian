# File-bound musical evaluation

[Home](../README.md) · [Scoring contracts](MUSICAL-EVALUATION.md) ·
[Validation task](TODO/DONE/NS-3_validation_01.md) · [Work](WORK.md)

Prediction-ancestry repair (2026-09-21) passed final checked stable Win32/Win64 QA
and all shared-validation criteria. Eighteen new controls exercise the repaired
boundary alongside existing scoring cases. Retained recorded metrics are unchanged;
the exporter binds original inference bytes directly for identical target bindings.
Commands, source hashes and zero-leak logs remain under `build/qa-batch-06/`.
The prior evaluator omitted prediction traversal and could admit a declared
reference-derived prediction; the current contract below closes that omission.

The native `pythian.evaluate` operator connects the shared scorer to actual WAV,
annotation, prediction, policy and exposure files. It performs no inference or
learning. Event, categorical, scalar and attributed-note comparisons share one
current case contract. The `notes` metric combines cell accounting with the
existing `pythian.pitch.evaluate` interval scorer and all four phrase gates.

The [reference builder](PART-REFERENCE.md#file-consumer) expands reviewed part
intervals into the current reference document with a complete regular grid. It
preserves uncertainty and does not infer annotations or change scoring acceptance.

```text
pythian.evaluate CASE.json
```

The complete JSON report goes to stdout only after verification and scoring
succeed. Errors go to stderr with exit code 1. Exit code 0 means a valid score
report was produced, including when its numerical gates fail. Consumers must
read the verdict fields. The operator does not modify inputs or write output
files; shell redirection may capture the report. Input paths are resolved against
the case file's directory, with absolute paths also supported.

## Evidence contract

Every JSON object has the exact fields listed below. Missing, extra, duplicate
or incorrectly typed fields reject. Integer frame coordinates must use integer
JSON tokens; numeric strings and fractional/exponent spellings are not coerced.
Digests identify exact file bytes, including line endings, and use lowercase
SHA256. Preparation and estimator files may be nonempty text or another opaque
artifact; their content is hashed, not interpreted as truth. Annotation policy
uses the structured musical comparison contract below.

| Case field | Meaning |
| --- | --- |
| `format` | `pythian-evaluation-case` |
| `binding` | All fields of the shared evidence binding, listed below |
| `files` | Paths named `source`, `preparation`, `reference`, `annotation_policy`, `scoring_policy`, `estimator`, `prediction`, `ledger` |
| `prediction_sha256` | Exact normalized prediction file identity |
| `ledger_sha256` | Exact separately maintained exposure ledger identity |

The binding has `source_sha256`, `preparation_sha256`, `reference_sha256`,
`annotation_policy_sha256`, `scoring_policy_sha256`, `estimator_sha256`, `group_id`,
`sample_rate`, `source_frames`, `first_frame`, `end_frame`, `partition`,
`group_verified`, `previously_used_for_tuning`, `reference_complete` and
`estimator_training_overlap`. Partitions are `training`, `development`, `evaluation`;
overlap states are `unknown`, `not-applicable`, `disjoint`, `overlap`.

The source digest identifies the prepared WAV whose absolute frame clock the
observations use. Its header must agree with `sample_rate` and `source_frames`;
the scope must be nonempty and contained in that clock. The source stays open
denying writes where supported and is hashed before and after scoring. This
checks bytes and structural geometry, not every decoded sample's admissibility.
Concurrent mutation is unsupported. Other documents are verified byte snapshots.

The preparation record must describe decoding, channel/rate changes and original
source ancestry. The estimator record must identify the algorithm/model and
inference policy, including relevant dependencies. Hashing an incomplete manifest
does not establish that omitted ancestry is absent. Source-family verification,
complete exposure history and reference independence still require reviewed
provenance under the [corpus protocol](CORPUS-EVALUATION.md).

## Musical annotation contract

Annotation policy is a JSON object with exactly `format` =
`pythian-evaluation-annotation`, `output`, `input_class`, `scope_id`, `purpose`,
`reference_method`, `label_convention`, `time_convention`, `uncertainty_convention`.
All values are nonempty strings of at most 4096 bytes; `scope_id` is at most 256.
The reference method is `authored`, `independently-annotated` or
`independently-measured`. This records how references were obtained; it does not
verify the annotator's truthfulness. The ancestry checks still apply.

| Output | Input class | Metric | Unit |
| --- | --- | --- | --- |
| `notes` | `attributed-voice` | `notes` | `absolute-MIDI-semitone` |
| `onsets`, `beats` | `annotated-recording` | `events` | `source-frame` |
| `tempo` | `annotated-recording` | `scalar` | `microseconds-per-quarter` |
| `key` | `tonal-region` | `label` | `key-root-mode` |
| `part-ownership` | `attributed-part` | `label` | `part-note-identity` |
| `part-note-sets` | `attributed-parts` | `part-note-sets` | `role-MIDI-sets` |
| `part-notes` | `attributed-parts` | `part-notes` | `role-MIDI-sets` |
| `harmony` | `harmonic-region` | `label` | `chord-identity` |
| `harmony-changes` | `harmonic-region` | `events` | `source-frame` |
| `groove-events` | `attributed-part` | `events` | `source-frame` |
| `groove-accent` | `attributed-part` | `scalar` | `normalized-amplitude` |
| `groove-offset` | `attributed-part` | `scalar` | `quarter-note-offset` |
| `sound-spectrum` | `recorded-sound` | `scalar` | `normalized-band-energy` |
| `sound-envelope` | `recorded-sound` | `scalar` | `normalized-amplitude` |
| `presence` | `recorded-sound` | `label` | `audible-presence` |

The operator rejects mismatched input/metric/unit combinations. Normalized scalar
values must lie in [0,1]; quarter durations must be positive. Signed groove offsets
are relative to the independently annotated quarter-note clock, not a guessed
clock produced by the evaluated provider. A spectrum comparison declares one
band/normalization in its scope/conventions; an envelope comparison declares its
source/event alignment and level convention. Changing those requires new policy
bytes and matching bound observations.

Use `scope_id` and the convention fields to identify the particular voice/part,
metrical level, tonal/harmonic vocabulary, feature band or envelope. Define label
spelling/equivalence, timing conversion/rounding, uncertain/excluded annotations
and complete event coverage explicitly. Labels compare exact vocabulary indices;
the operator does not silently fold octaves, modes, roles or chord qualities.
Role comparisons need separate declared scopes and complete per-role reporting;
pooling a dominant part cannot substitute for missing-role acceptance.
The [part-note-sets comparison](PART-EVALUATION.md) represents all declared roles
and simultaneous pitches in one common grid. It accepts diagnostic purpose only;
endpoint agreement does not replace note timing or mixture-provider acceptance.
The [part-notes extension](OVERLAPPING-NOTES.md#file-bound-role-timing) additionally
checks per-role interval timing and consistency with the common center grid.
It remains diagnostic while the mixture reference packet is being qualified.

`purpose` is `primary` or `diagnostic`. Beat comparisons preserve the existing
30-ms primary and 70-ms diagnostic tolerances, converted using the shared nearest
frame/half-up rule. A diagnostic can pass its numeric gates but is never eligible
for `independent_case_pass`. All other declared numerical limits remain in the
hash-bound scoring policy; phrase minima remain fixed below. These are executable
comparison contracts, not calibrated production providers or corpus verdicts.

The complete annotation contract is included in the report. Current development
cases must regenerate their annotation/reference/ledger identities; no reader
for the earlier opaque annotation-policy draft is retained.

## Reference and prediction documents

Reference fields: `format` = `pythian-evaluation-reference`, `clock`,
`annotation_policy_sha256`, `observations`.

Prediction fields: `format` = `pythian-evaluation-prediction`, `clock`,
`estimator_sha256`, `observations`.

Both clocks contain `source_sha256`, `preparation_sha256`, `scoring_policy_sha256`,
`sample_rate`, `source_frames`, `first_frame`, `end_frame`, matching the case
exactly. Predictions do not need reference annotations or their hash. Reference
annotations must be generated independently of predictions, with declared
uncertainty and scope; deriving them from the evaluated estimator is invalid.

For events, `observations` is an increasing array of integer frames. For label
or scalar comparisons, it is an increasing array of cells with `frame`, `state`
and, only for state `value`, a numeric `value`. Other states are `rest`, `unknown`,
`ambiguous`, `unsupported`. Label values are zero-based vocabulary indices;
scalars use the policy's declared unit. Reference and prediction cells must have
identical centers. Dropping an unavailable prediction rejects rather than hiding
it from coverage. Shared scoring preserves rest errors and uncertainty counts.
For `presence`, the vocabulary is exactly `["audible"]` (index 0). A reviewed
`rest` is a cell state; unreviewed spans and explicit unknown reviews remain
`unknown`. Overlapping reviews become `ambiguous`. A presence case that declares
`reference_complete=true` must have no unknown, ambiguous or unsupported
reference center. Acoustic correctness and independence still require source
and reviewer evidence beyond the packet's schema.

## Scoring policy and verdicts

The scoring policy has `metric` (`events`, `label`, `scalar`, `notes`,
`part-note-sets`, `part-notes`), `unit`, `vocabulary`,
`tolerance_frames`, `scalar_tolerance`, `minimum_coverage`, `minimum_precision`,
`minimum_f1`, `minimum_reference_coverage`.

- `unit` declares the comparison's physical unit or musical meaning. A label
  vocabulary is a nonempty array of distinct nonblank strings; notes use the
  complete MIDI vocabulary and part sets use stable role IDs. Scalar/event
  metrics use an empty array. Category identity is exact, with no implicit equivalences.
- Events use integer frame tolerance and the shared one-to-one event matching.
  Coverage is recall. Label/scalar metrics set event tolerance and minimum F1 to zero.
  Scalar tolerance is nonnegative and must be zero for nonscalar metrics.
- Ratio thresholds are within [0,1]; coverage, precision and reference coverage
  minima must be positive. Event minimum F1 must also be positive. Thresholds
  are declared policy, not calibrated automatically by the evaluator.
- `metrics_pass` requires the numerical gates, a nonzero active-reference/event
  denominator and `reference_complete=true`. Incomplete annotations still yield
  diagnostic counts. For events, complete annotation is an external declaration;
  an event list alone cannot prove absence of unannotated events.
- `independent_eligible` requires a primary comparison and applies shared partition, verified family, previous
  exposure, reference completeness and external-training-overlap requirements,
  together with independent prediction ancestry.
- `prediction_ancestry_independent` and `prediction_ancestry_reason` expose the
  declared prediction-graph result. An empty reason means this check passes,
  not that the other independent-evaluation conditions pass. Declared reference
  dependence still yields unchanged diagnostic scores and a nonempty reason;
  missing or malformed required dependencies reject the case before scoring.
- `independent_case_pass` requires both preceding verdicts. It covers only this
  declared comparison. It does not establish provider accuracy over a corpus,
  pass additional phrase gates, or accept a learned style.

### Attributed-note phrases

The `notes` metric is for a separately attributed monophonic voice with complete
note annotations. It adds a `notes` array to both observation documents; each
entry has exactly `start_frame`, `end_frame`, `note`. Intervals share the source
clock, use MIDI 0..127, and must fit the source. Predictions cannot overlap;
overlapping reference intervals require ambiguous observation cells. Per-array
note count is bounded to 4096; each cell/interval consistency comparison is
bounded to 16777216 visits. Known note cells must agree with their intervals.
No-reference intervals mean reference rest; missing predictions remain explicit
non-value states. Incomplete/unknown annotations can use diagnostic label cases;
they cannot claim complete note-phrase acceptance through this input class.

The policy uses unit `absolute-MIDI-semitone`, ordered vocabulary `midi-0` through
`midi-127`, zero generic event/scalar tolerance, and full reference coverage.
Coverage must be at least 0.80, precision at least 0.98, and `minimum_f1` (full-note
F1 here) at least 0.70. Onset F1 must additionally reach 0.80. Lower policies reject;
a caller may make the configurable minima stricter. Ambiguous reference cells
remain visible in the report and prevent complete-coverage acceptance.

The existing note scorer supplies exact-pitch one-to-one onset/full-note matches,
50-ms onset tolerance, offset tolerance max(50 ms, 20% reference duration) and
110-ms common edge exclusion. Its existing nearest-frame rounding remains intact;
the report records the actual frame tolerances and error sums. Parsed thresholds
and the fixed gate floors use the same Double precision on Win32 and Win64.
No onset or duration success is inferred from cell accuracy.

## Exposure ledger

Ledger fields: `format` = `pythian-evaluation-ledger`, `groups`, `estimators`, `artifacts`.
Each group has `group_id`, `group_verified`, `previously_used_for_tuning`,
`partition`, `sources` (an array of prepared-source digests). Each estimator has
`estimator_sha256`, `training_overlap`.

Every source must belong to exactly one family entry; conflicting family
assignments and duplicate identities reject throughout the supplied ledger.
Every family's identity, partition and exposure declaration is validated, including
entries outside the immediate case. Case partition,
verification and tuning exposure must match that entry, and estimator overlap
must match its unique entry. A case cannot relabel itself as untouched while the
ledger records development use. Tuning exposure makes that family development
thereafter, including related encodings, excerpts and inherited learning inputs.

Each artifact has `sha256`, `group_id` and `parents` (artifact digests). Source
artifacts name their registered family; non-source artifacts use an empty group.
List parents before children and list each node's parents once in their ledger
order. Missing ancestors, cycles, duplicates and unregistered/hidden families
reject. Include the exact scored prediction and its full declared dependency
graph, plus preparation, reference annotations and estimator training, including frozen palettes, blended models and
other parents outside the immediate case. Roots without known dependencies use
an empty parent list; this is a provenance assertion, not discovered independence.

The source and preparation closures may contain only the selected recording
family. The preparation must include the prepared source in its closure; an
identity preparation is a record depending on that source. The reference closure
must include source, preparation and annotation policy, and must exclude the
evaluated estimator and its prediction. The estimator closure must exclude every
evaluation family, including unrelated evaluation recordings. A data-derived
estimator cannot declare training overlap `not-applicable`. Known training and
development ancestors may be used, but unknown external training overlap still
prevents independent acceptance. These checks concern training ancestry, not the
source passed to an estimator when obtaining the current prediction.

The prediction closure must include the exact bound source, preparation and
estimator. These may be reached through intermediate inference or transformation
artifacts; metadata matching alone is insufficient. A missing prediction root,
wrong required identity or incomplete/cyclic graph rejects.

The reference root anywhere in prediction ancestry gives
`prediction-depends-on-reference`. Other shared reference ancestors give
`prediction-shares-reference-ancestry`, including an annotation model consumed
through differently named helpers. Registered recording material in the shared
source/preparation closures, the exact preparation record and the annotation-policy
artifact itself are exempt: both sides need the same raw input and conventions.
Unclassified models/helpers beneath preparation or policy are not exempt merely
because those inputs are shared. A generic shared helper whose independence is not
represented by these input contracts remains ineligible; the evaluator does not
guess which portion of a declared dependency was used.

Additional evaluation-family sources reached by the prediction give
`prediction-uses-additional-evaluation-source`. Every registered estimator in that
closure is checked, including secondary variants: evaluation training ancestry
gives `prediction-estimator-uses-evaluation-source`, and unknown/overlapping
training gives `prediction-estimator-training-overlap`. Data-derived estimators
still cannot declare training overlap `not-applicable`. Parent source summaries
are calculated once in ledger order, avoiding one graph traversal per model.

The report retains the first applicable reason in the fixed order above. These
exclusions preserve numerical scoring for declared oracle/development controls;
even a perfect oracle score is never an independent case pass. Register all
consumed estimator identities and retain their actual ancestry. Renaming a node
does not remove its supplied parent edges, but undeclared model use remains
outside what a declared graph can prove.

The current ledger format now requires these fields; regenerate development
cases rather than keeping a reader for the superseded draft. Artifact identities
outside the case are declared ledger records. The operator checks their graph and
family/exposure consistency; it does not reopen every original/model asset or
verify the truth of a claimed parent edge. Review and retain their byte-bound
provenance under the corpus protocol before making an independent claim.

The caller must supply the current complete ledger, including prior uses and
ancestry outside this case. These files are an audit boundary, not an authenticated
registry: the operator cannot discover unrecorded related recordings, prove
training disjointness or prevent a caller replacing both case and ledger with
false declarations. Unknown model overlap remains ineligible.

## Bounds and verification

JSON/opaque documents are at most 8 MiB each, JSON nesting at most 16, the WAV
at most 1 GiB, ledger families/estimators/artifacts at most 4096 each, total
registered sources at most 4096 and parent edges at most 32768. Parent order
allows bounded iterative closure checks without recursion. Observation arrays are
within the shared scorer's item/frame limits. File-size limits may constrain
arrays before their theoretical item limit. Use declared excerpts for these
comparisons; aggregate many-hour workload acceptance remains a corpus task.

The maintained [file fixture](../tests/pythian.tests.evaluation.files.lpr)
generates complete authored label/scalar/event/note cases and verifies deterministic
reports, tolerance boundaries, changed/missing evidence, policy/clock mismatch,
exposure mismatch, removed observation centers, positive admission thresholds,
partial-reference rejection and passing development results remaining ineligible.
Prediction controls additionally cover missing/wrong roots, missing required
inputs, self-dependency, direct/transitive oracle inputs, shared annotation models,
additional evaluation sources and secondary estimator exposure. Valid direct and
transitive predictions and shared conventions retain independent eligibility;
oracle/development cases preserve the exact score object. These new controls
are compiled and await final QA.
Phrase controls additionally reject inconsistent cell/interval evidence and a
relaxed precision gate; a deliberately wrong duration fails full-note F1 despite
perfect cell coverage, precision and onset F1.
It and the [operator](../tools/pythian.evaluate.lpr) are in the native core build.
Checked stable Win32 and Win64 pass with no unfreed blocks.

Recorded verification under ignored `build/evaluation-operator/` reconstructs
references from original note annotations and predictions from retained inferred
intervals. All 2997 centers per recording agree with the previous independent
scores. The file-bound results retain flute coverage 82.4553%, precision 91.5727%
(cell gate fails), and violin coverage 87.0852%, precision 98.5520% (cell gate
passes). Combined phrase reports preserve flute onset/full-note F1
0.863157894737/0.852631578947 (overall phrase failure) and violin
0.96/0.857142857143 (development phrase pass). Original note counts and one-to-one
matches agree with the earlier scorer. Both are development-only with unknown external-model training overlap;
neither is independent acceptance. No inference or held-out material was run.

Final combined-phrase CLI reports are byte-identical between checked Win32 and
Win64, with zero unfreed blocks. The fixture's initial Win32 run exposed a decimal
threshold comparison against Extended constants; typed Double floors fixed the
boundary while preserving the same 80%/98%/0.80/0.70 requirements.

The declared ancestor graph checks pass final checked stable Win32/Win64 tests,
including the maintained file fixture and both exposed recorded-case CLIs, with
zero unfreed blocks. Recorded phrase counts remain unchanged and complete reports
are byte-identical across targets. Retained evidence is under
`build/qa-batch-01/`; no held-out material or new inference was used.
Controls cover an outside-plan palette grandparent, valid disjoint training,
unknown external overlap, evaluation leakage, missing/cyclic parents, hidden
families, contradictory source lineage and estimator-derived references. Recorded
development-case regeneration retains the original annotations and predictions;
it does not rerun inference or open held-out material.

The per-output annotation contract and reference-preserving/breaking controls
pass final checked stable Win32/Win64 fixtures and recorded CLI comparisons. The
controls distinguish wrong values from unknowns, missing/extra events, identical
pitch with different part ownership, chord quality and incorrect units. They
also keep a passing 70-ms diagnostic separate from its failing 30-ms primary.
These authored reference controls test scoring semantics, not inferred WAV truth.

Evidence and the all-criteria review are retained under `build/qa-batch-02/`.
No owned compiler warnings or unfreed blocks were found. This evidence originally
accepted [shared validation](TODO/DONE/NS-3_validation_01.md), +2 NS-3 points
(+0.50 overall). Infrastructure review on 2026-09-21 reopened that task: the ledger
never requires or traverses the scored prediction node, allowing declared direct
or transitive reference ancestry to evade independent-admission checks. Existing
passing fixtures omit this counterexample. The completion credit is withdrawn
until the prediction boundary is repaired and validated. Historical scoring
results remain evidence of those checks, not complete ancestry admission.
Provider accuracy remains separate; current experiment outcomes are recorded in
the [shared evaluation contract](MUSICAL-EVALUATION.md#fixed-next-experiment-budgets).
