# NS-3_parts_03 — Accept role learning on independent mixtures

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Independently validate final role/event attribution and deliver evidence that semantic bass/voice providers can consume.

North star: NS-3. Outcome owner: WAV-03-PARTS.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [LAYERED-STYLE](../LAYERED-STYLE.md) · [PHRASE-EVALUATION](../PHRASE-EVALUATION.md).

The [frozen mixture policy](../PART-MIXTURE-POLICY.md) defines the initial scope,
per-role gates and family/exposure rules. Current part metrics remain diagnostic;
this task must integrate and verify independent case admission on the final path
before reporting a separate-recording acceptance verdict.

**Acceptance Criteria:**

- Freeze final attribution, preprocessing and uncertainty policy before the held-out matched-stem/mix packet is used.
- Pass the declared per-role accuracy, coverage, leakage and crossing criteria, reporting unsupported or missing roles explicitly.
- Recheck practical native runtime/memory and controlled regressions on the final path; preserve reproducible source/policy identities.
- Demonstrate stable role/event evidence and joint relationships through saved learning inputs, without treating generated output as independently observed training evidence.
- Record a separate-recording acceptance verdict and the exact supported mixture scope; failures stay open or require a new frozen evaluation set after tuning.

**Blockers**

- [NS-3_parts_02.md](NS-3_parts_02.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)
