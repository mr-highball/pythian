# NS-3_validation_01 — Establish executable musical admission and evaluation contracts

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Make the existing evaluation requirements executable and consistent across note, timing, context, role, harmony, groove and sound providers. This task owns shared scoring/admission semantics, not the provider accuracy credited in later tasks.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../BEAT-TRACKING.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

Selected 2026-09-20 through the active dependency chain
`NS-5_corpus_02 -> NS-5_evaluation_01 -> NS-3_validation_01`, after corpus identity
was accepted. Reuse the maintained `pythian.pitch.evaluate` scorer: exact semitone
identity, one-to-one note matching, explicit ambiguous/unsupported reference
centers, 50-ms onset tolerance, offset tolerance max(50 ms, 20% duration), and
110-ms note-edge policy. Preserve the per-recording gates: coverage >=80%,
precision >=98%, onset F1 >=0.80, full-note F1 >=0.70. The shared binding/admission
contract and independent checks across the other declared outputs still need
completion. This selection/review earns no task credit and does not reopen
the held-out recordings.

In progress — 2026-09-20: [shared native evaluation](../MUSICAL-EVALUATION.md)
now provides evidence/clock/exposure checks, bounded event matching and explicit
categorical/scalar uncertainty/rest accounting. Checked stable Win32/Win64 pass;
the maintained beat lab consumes the shared scorer with exact report/audio parity.
Recorded flute/violin cell scores retain all prior counts and failures. Remaining:
complete source/reference-bound operator and per-provider annotation/admission
checks, plus fixed experiment budgets and discriminating next hypotheses. This
task remains TODO with no completion credit.

Further progress — 2026-09-20: the maintained
[file-bound operator](../EVALUATION-OPERATOR.md) verifies source/document hashes,
WAV geometry, reference/prediction policy clocks, frozen vocabularies and separate
family/estimator exposure records. Win32/Win64 fixtures pass; original recorded
annotations and retained inferred intervals reproduce the flute/violin scores.
Development verdicts cannot become independent case acceptance. Full ancestry
verification, provider-specific annotation/admission integration and fixed
experiment budgets remain open; no task credit yet.

**Acceptance Criteria:**

- Declare each supported input class, musical output, unknown/unsupported state, coverage denominator, timing tolerance and error measure; preserve existing phrase thresholds rather than weakening them.
- Bind references, annotation uncertainty, source/preparation hashes, policy and estimator identities to development and untouched evaluation partitions; document any known external-model training overlap.
- Provide or consolidate native scoring and independent reference checks for the claimed outputs, including wrong versus unknown results, rests, overlap and boundary rounding.
- Demonstrate that evaluation exposure, incompatible clocks/policies and absent references cannot silently produce an accepted result; treat tuned-on evaluation groups as development thereafter.
- Record fixed experiment budgets and stop/switch criteria for the current failed approaches, with a reproducible baseline and one discriminating next hypothesis per experiment; diagnostics alone do not close a provider.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.
