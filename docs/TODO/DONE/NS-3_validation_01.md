# NS-3_validation_01 — Establish executable musical admission and evaluation contracts

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Make the existing evaluation requirements executable and consistent across note, timing, context, role, harmony, groove and sound providers. This task owns shared scoring/admission semantics, not the provider accuracy credited in later tasks.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../../BEAT-TRACKING.md) · [CORPUS-EVALUATION](../../CORPUS-EVALUATION.md).

Reopened 2026-09-21 after infrastructure review: the file evaluator checks
reference and estimator ancestry but never requires or traverses the exact
prediction node. A prediction can therefore declare a direct or transitive
reference dependency and still reach independent eligibility. This violates the
existing binding/exposure criteria below. Remove the previously earned +2 NS-3
points (+0.50 overall) until repair and final validation; preserve the historical
scoring evidence without retaining the complete-ancestry claim. No new credit or
separate duplicate task is allocated for this repair.

Completed 2026-09-21 after repair: the maintained file evaluator now requires the exact
prediction and its source/preparation/estimator closure, excludes declared
reference/shared-annotation ancestry and secondary estimator exposure from
independent eligibility, and preserves oracle/development scores with explicit
reasons. Final QA passed all criteria on checked stable FPC 3.2.2 Win32/Win64:
18 focused ancestry controls plus the existing thirteen-output/phrase controls,
with unchanged thresholds and denominators. Retained flute/violin predictions
reproduce all 2997 centers and previous metrics; flute still fails precision and
violin passes development only. No inference or untouched evaluation was run.
Commands, source hashes, reports and zero-leak logs are retained under
`build/qa-batch-06/` and `build/prediction-ancestry/`.
Restore the original +2 NS-3 points (+0.50 overall), returning NS-3 to 32%.
This repairs the prior acceptance; it adds no new scope or duplicate credit.

Historical acceptance, superseded by reopening above: on 2026-09-21 the
[shared native scorer](../../MUSICAL-EVALUATION.md) and
[file operator](../../EVALUATION-OPERATOR.md) were accepted as binding thirteen declared musical outputs
to source/preparation/reference/policy/estimator bytes, compatible clocks,
annotation conventions, uncertainty and complete declared exposure ancestry.
Bounded event/cell/note comparisons preserve wrong, unknown, rest and unsupported
denominators. Phrase gates remain 80% coverage, 98% precision, onset F1 0.80 and
full-note F1 0.70; 30-ms primary beats remain separate from 70-ms diagnostics.
Passing diagnostics or development cases cannot become independent acceptance.

Final checked stable FPC 3.2.2 Win32/Win64 fixtures pass preserving/breaking
references, unit/policy/clock mismatch, missing evidence, exposure and inherited
evaluation-data rejection. Existing unchanged core/pitch evidence covers rest,
overlap and boundary rounding. Original exposed flute/violin annotations and
retained predictions reproduce all 2997 centers and prior phrase metrics; reports
are byte-identical across targets, with no unfreed blocks. No inference or held-out
recording was run. The flute still fails precision; violin passes development only.
Fixed pitch/metrical hypotheses, baselines, candidate/ablation budgets and stop
conditions are declared in the shared contract. Final criterion review and commands
are retained under `build/qa-batch-02/`, with earlier evidence linked from the topics.

This accepts executable scoring/admission semantics. Annotation truth, unrecorded
ancestry, provider calibration, independent recording accuracy and style/listening
quality remain their declared owners. Accepted +2 NS-3 points (+0.50 overall),
moving NS-3 from 30% to 32%. The same integration accepts NS-4_layers_01 (+0.90),
moving overall completion from 57.0% to 58.4%. Return to the now-unblocked
[style-card specification](../NS-5_evaluation_01.md) on the originating NS-5 chain.

**Acceptance Criteria:**

- Repair the prediction admission boundary: require a ledger node for the exact
  scored prediction bytes, verify its bounded transitive source/preparation/
  estimator bindings, and reject missing, mismatched, cyclic or incomplete
  dependencies. Matching free-standing declarations are insufficient.
- Reject independent eligibility for direct or transitive reference-derived
  predictions, including declared reference-derived helpers and shared annotation
  model ancestry. Preserve legitimate raw-source/preparation access and truthful
  development/control scoring; hashes do not authenticate undeclared provenance.
- Demonstrate the repair in the maintained file consumer on checked native
  targets with absent prediction, direct reference, transitive helper, mismatched
  required-input and valid prediction controls. Preserve score denominators and
  thresholds, update current fixtures/operator guidance, and retain the original
  defect plus final evidence before restoring completion credit.
- Declare each supported input class, musical output, unknown/unsupported state, coverage denominator, timing tolerance and error measure; preserve existing phrase thresholds rather than weakening them.
- Bind references, annotation uncertainty, source/preparation hashes, policy and estimator identities to development and untouched evaluation partitions; document any known external-model training overlap.
- Provide or consolidate native scoring and independent reference checks for the claimed outputs, including wrong versus unknown results, rests, overlap and boundary rounding.
- Demonstrate that evaluation exposure, incompatible clocks/policies and absent references cannot silently produce an accepted result; treat tuned-on evaluation groups as development thereafter.
- Record fixed experiment budgets and stop/switch criteria for the current failed approaches, with a reproducible baseline and one discriminating next hypothesis per experiment; diagnostics alone do not close a provider.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

- Repaired defect (2026-09-21): checking only reference and estimator ancestry omitted the exact prediction node, allowing reference-derived predictions to reach independent eligibility. Final acceptance requires the prediction's complete declared source/preparation/estimator closure; see [file evaluation](../../EVALUATION-OPERATOR.md).

- Follow-up belongs to provider tasks: this evaluator cannot authenticate undeclared ancestry or turn development scores into independent musical accuracy. Preserve the repaired admission boundary when adding new prediction producers.
