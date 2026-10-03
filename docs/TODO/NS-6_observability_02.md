# NS-6_observability_02 — Catalog import checkpoints and cancellation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Extend the primary catalog import/verifier/copy path with shared progress, including
its callers in library preparation, capture saves and derived clips. Its current
outer job label is indeterminate while nested hashes/copies run silently.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional.
Deliverable: observable import phases and propagation of callback aborts without
turning cancellation into an ordinary per-file failure. Closing evidence: native
import cancellation, retry/atomic publication checks and consumer integration.
Stop on partially admitted sources, swallowed callback exceptions or duplicated
hash/copy algorithms. Big Boss owns assessment and integration.

**Acceptance Criteria:**

- Progress reports current bytes/items during import hashing, verification and
  copying, with truthful phase transitions and shared portable callback types.
- Callback exceptions propagate through per-file error handling; cancellation
  leaves durable originals and accepted catalog records intact and retryable.
- Library, capture and effects consumers forward callbacks to the same importer;
  no parallel import implementation. Add meaningful parity and abort checks.

**Blockers**

- [Shared observability contract — DONE](DONE/NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-03, Big Boss: audit of `pythian.tools.annotations.catalog` finds
  nested full-source hashes and staged copying inside `ImportLabelInbox`, with
  per-file exception handling. A stage label alone cannot give cancellation
  checkpoints here. This is distinct from the analysis/pitch/effects callback batch.
