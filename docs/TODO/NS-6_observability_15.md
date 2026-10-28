# NS-6_observability_15 — Observe retained inference corpus validation and reading

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Finish the separate retained-input/operator prerequisite for
[observability04](NS-6_observability_04.md) AC3. The native WAV supervisor now has
shared callbacks, but `TInferenceCorpusReader` has no work observer and its lazy
artifact construction omits the new hash/row observer. The maintained corpus
auditor also hashes sources and builds its report without forwarding work.
Do not claim complete inference/operator coverage from the WAV consumer alone.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
All original parent, scientific, musical and browser gates remain required.

Execution status: ready. Big Boss works alone. Next deliverable: shared optional
call-scoped metadata/verification/read callbacks through the primary inference
corpus implementation and maintained auditor, preserving the current artifact,
manifest, group/source/scope and observation contracts. Reuse primary hash/JSON
behavior rather than adding a parallel parser, digest or reader.
Closing evidence: original callback identity, private batch publication, explicit
failed-reader/reopen behavior, exact source/scope rows and actual auditor report
replay against a frozen prior consumer. Use dedicated E-drive output; no new
recorded source, inference candidate or scientific tuning is selected.
Stop on changed observation policy, hidden skipped scopes, partial publication,
weakened validation, another generic dependency gap or a distinct prerequisite.
This split adds no credit and resets no nonclosing/scientific counter.

**Acceptance Criteria:**

- AC1: Forward the shared optional progress contract through actual metadata
  validation, lazy artifact hash/row verification and bounded corpus reading.
  Count actual owned visits/rows/bytes, keep unknown totals unknown and name
  synchronous RTL/platform residuals. Borrow observers only for each call.
- AC2: Preserve original observer exceptions and avoid exposing a partial batch
  or silently skipping a source/scope after cancellation. Declare and test the
  failed cursor's reopen contract, reentry policy and exact clean-reader retry.
  Reader cleanup releases its owned file; no source or accepted artifact changes.
- AC3: The maintained native corpus auditor forwards manifest/source/artifact
  and traversal work. Its completed report, exact source/scope boundaries and
  artifact bytes match a frozen prior actual consumer. Pass affected failure,
  cancellation, replay and original corpus controls with zero native leaks.
  These engineering checks establish no inference accuracy or musical credit.

**Blockers**

- [Shared work callbacks — DONE](DONE/NS-6_observability_01.md).
- [Primary hash publication — DONE](DONE/NS-6_hash-publication_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss: the AC3 WAV-operator inventory finds this separate path
  before extending scope. `ReadBatch` advances its entry cursor before lazy
  construction; adding a throwing observer there needs explicit failure state
  and private output handling, not a wrapper progress message. Preserve existing
  group/source isolation and exact full-source support. The WAV component has
  its own actual worker/abort/replay evidence under inference-operator-progress-
  20261028-boss; that evidence does not close this task or all parent AC3.
