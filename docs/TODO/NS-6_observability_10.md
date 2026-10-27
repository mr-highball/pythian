# NS-6_observability_10 — Observe source measurement in wave-style learning

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Expose actual work and cancellation in primary pitch-cell and onset-dynamics
measurement, then forward it through the retained style CLI. These raw source
measurements precede the retained profile constructor; profile/model callbacks
do not observe them. `MeasurePitchCells` calls the pitch estimator per cell,
while `MeasureOnsetDynamics` visits source windows without a callback today.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Execution status: prerequisite-blocked. Big Boss owns this task solo under the
current supplied operator instructions. Next deliverable: optional shared
callbacks in the primary implementations and both pitch-cell overloads, with
real cell/window/frame units and forwarding through the actual CLI. Preserve
estimation, admission, provenance and output. Closing evidence: populated native
consumers, unchanged measurements/archives/stdout, original callback exceptions,
cleanup, unchanged borrowed input and retry. Stop on altered pitch/dynamics
math, invented totals, duplicated analysis or a distinct required gap.

**Acceptance Criteria:**

- AC1: Audit and observe owned pitch-cell and onset-dynamics measurement loops,
  forwarding into existing shared analysis where applicable. Use aggregate
  cadence and actual work units; retain one primary implementation.
- AC2: The maintained `learn-pitch`, `learn-dynamics` and `learn-duration` paths
  forward measurements on stderr while preserving stdout, source evidence and
  learned archives. Completion remains separate from durable publication.
- AC3: Checked Win32/Win64 consumers exercise nil/observed equality, interior
  callback abort with original exception identity, cleanup and retry. Measure
  and name remaining synchronous estimator/validation calls and their workload;
  do not infer a maximum latency or musical accuracy from mechanical checks.

**Blockers**

- [Shared progress contract — DONE](DONE/NS-6_observability_01.md).
- [Retained wave-style API and CLI](NS-6_observability_07.md).

**Dev Notes:**

- 2026-10-27, Big Boss: discovered while checking task07's actual CLI. Primary
  `MeasurePitchCells` and `MeasureOnsetDynamics` have no observer parameter.
  Task07 forwards its retained profile/model API and the already supported dense
  pitch tracker; it does not certify these measurement interiors. This is a
  distinct Pythian-owned prerequisite to complete CLI source observability,
  with no demonstrated generic WFC defect or new musical credit.
