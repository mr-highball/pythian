# NS-6_observability_01 — Long-operation observability audit and shared callbacks

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Audit owned core, adapters and tools for long-running work without observable
progress or cancellation. Extend the primary implementations and connect the
operator-facing paths, reusing existing streaming/checkpoint contracts.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional
points. This improves usability and callable observability of existing outcomes.

Selected batch: Big Boss solo. Deliverable: documented coverage inventory,
portable callback contract and connected analysis/pitch/effects progress.
Closing evidence: callback cancellation/output parity and actual browser checks.
Stop on DSP/output changes, swallowed cancellation, fake percentages, or expansion
into unrelated algorithm work; distinct remaining gaps get explicit linked tasks.

**Acceptance Criteria:**

- AC1: Record coverage across core, adapters and maintained tools, distinguishing
  existing bounded pull/checkpoint interfaces from silent bulk operations.
- AC2: Extend shared bulk hashing, analysis, resampling and pitch operations with
  optional callbacks and documented units, exception/cancellation semantics.
  Hosts own presentation, scheduling and throttling; portable code owns no clocks
  or browser dependencies.
- AC3: Connect relevant Studio effect, capture/inspection and pitch work to
  measured job progress and common friendly labels. Existing inference/library
  monitoring stays usable, with any unaddressed gaps explicitly owned.
- AC4: Verify unchanged output, callback abort cleanup and meaningful intermediate
  progress; validate matched native/browser artifacts, document audit limits and
  preserve operator data during deployment.

**Blockers**

- [Learning progress foundation](DONE/NS-6_studio_20.md).

**Dev Notes:**

- 2026-10-03, Big Boss: user extends the lesson to all potentially long work.
  Initial scan finds reusable library/import and inference monitoring, bounded
  streaming interfaces, and silent pitch/effects plus bulk DSP calls. This task
  owns the broader audit; studio_20 remains bounded to the learning workflow.
