# File-bound musical evaluation

[Home](../README.md) · [Scoring contracts](MUSICAL-EVALUATION.md) ·
[Validation task](TODO/NS-3_validation_01.md) · [Work](WORK.md)

The native `pythian.evaluate` operator connects the shared scorer to actual WAV,
annotation, prediction, policy and exposure files. It performs no inference or
learning. Event, categorical, scalar and attributed-note comparisons share one
current case contract. The `notes` metric combines cell accounting with the
existing `pythian.pitch.evaluate` interval scorer and all four phrase gates.

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
SHA256. Preparation, annotation policy and estimator files may be nonempty text
or another opaque artifact; their content is hashed, not interpreted as truth.

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

## Scoring policy and verdicts

The scoring policy has `metric` (`events`, `label`, `scalar`, `notes`), `unit`, `vocabulary`,
`tolerance_frames`, `scalar_tolerance`, `minimum_coverage`, `minimum_precision`,
`minimum_f1`, `minimum_reference_coverage`.

- `unit` declares the comparison's physical unit or musical meaning. A label
  vocabulary is a nonempty array of distinct nonblank strings; other metrics
  use an empty array. Category identity is exact, with no implicit equivalences.
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
- `independent_eligible` applies shared partition, verified family, previous
  exposure, reference completeness and external-training-overlap requirements.
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

Ledger fields: `format` = `pythian-evaluation-ledger`, `groups`, `estimators`.
Each group has `group_id`, `group_verified`, `previously_used_for_tuning`,
`partition`, `sources` (an array of prepared-source digests). Each estimator has
`estimator_sha256`, `training_overlap`.

The selected source must belong to exactly one matching family entry; conflicting
family assignments and duplicate selected identities reject. Case partition,
verification and tuning exposure must match that entry, and estimator overlap
must match its unique entry. A case cannot relabel itself as untouched while the
ledger records development use. Tuning exposure makes that family development
thereafter, including related encodings, excerpts and inherited learning inputs.

The caller must supply the current complete ledger, including prior uses and
ancestry outside this case. These files are an audit boundary, not an authenticated
registry: the operator cannot discover unrecorded related recordings, prove
training disjointness or prevent a caller replacing both case and ledger with
false declarations. Unknown model overlap remains ineligible.

## Bounds and verification

JSON/opaque documents are at most 8 MiB each, JSON nesting at most 16, the WAV
at most 1 GiB, ledger families/estimators at most 4096 each, and observation arrays
within the shared scorer's item/frame limits. File-size limits may constrain
arrays before their theoretical item limit. Use declared excerpts for these
comparisons; aggregate many-hour workload acceptance remains a corpus task.

The maintained [file fixture](../tests/pythian.tests.evaluation.files.lpr)
generates complete authored label/scalar/event/note cases and verifies deterministic
reports, tolerance boundaries, changed/missing evidence, policy/clock mismatch,
exposure mismatch, removed observation centers, positive admission thresholds,
partial-reference rejection and passing development results remaining ineligible.
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

Per-provider annotation/admission integration and complete ancestor-ledger enforcement
remain open in the validation task; its next experiment budgets are
[declared separately](MUSICAL-EVALUATION.md#fixed-next-experiment-budgets). These
checks advance that task without closing it or changing completion percentages.
