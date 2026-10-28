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

Execution status (2026-10-28): implemented; exact published qualification pending.
Big Boss works alone. Next deliverable: shared optional
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

- 2026-10-28, Big Boss: primary constructor/read callbacks are call-scoped;
  nested artifact hash/row work carries the actual one-based entry ordinal.
  `ReadBatch` now uses private output plus an explicit failed cursor. A read
  exception releases the active file, preserves both caller slots and requires
  reopening; caught reentry leaves the outer read intact, while an escaping
  error poisons it. EOF retains the empty/-1 contract. No observer is retained.
  Win32/Win64 each pass159490 checks/34 abort cases, zero leaks:33 original marker
  exceptions and one escaping reentry. All300 authored observation records and
  scope indices replay exactly after clean reopening; three artifact hashes
  match across both native targets. Maximum4096-entry metadata emits8394752 actual
  visits/32794 callbacks; local concurrent runs take10281/11422ms, not guarantees.
- The prior fixture expected reset to `-1` on malformed artifact failure. Its
  original failing check is retained under old-contract-run.log; update that
  intentionally superseded expectation to preserve index99 and an empty prior
  batch, then test failed-cursor rejection. All original corpus binding/center/
  scope/policy checks pass on both targets. The new explicit var-slot contract
  replaces the old out-slot clearing; no compatibility shim is retained.
- The maintained native auditor forwards primary JSON preparation, hashes,
  metadata visits, per-entry verification/read and report-ready phases. Own each
  JSON row before a later hash callback may throw. Its complete report matches
  the frozen actual consumer byte for byte: SHA256
  e7a9e55726977b025e773bd3d925c7e0036c9df6a41fd3371e458f8bd7dc6a6a,
  using two adjacent scopes/200 actual Pascal-backend observations. Reconcile
  supervisor/WAV/corpus/append controls with the shared observation unit; current
  supervisor passes1056 checks/14 original aborts, zero leaks (polling affects
  counts). A1024-row escaped-label RTL pretty-formatting probe returns809208 bytes
  in31ms without heap tracing,860ms with it, zero tracked leaks. Preserve this
  bounded synchronous residual, file I/O, string-list searches and RTL structural
  parsing explicitly; do not claim hard callback latency or new musical accuracy.
  Evidence is under the dedicated E-drive inference-corpus-progress-20261028-boss
  roots. Published CI465 passes the predecessor9b5a437; it does not qualify these
  current reader changes. Keep task15 open until current publication checks pass.

- 2026-10-28, Big Boss batch selection: AC1–3, primary reader and actual auditor
  forwarding with private output and failed-cursor handling. Closing evidence
  is original-exception/reentry/clean-reopen control, existing source/scope corpus
  checks and exact report/artifact replay against the frozen native auditor.
  Stop on a semantic change, hidden skip, partial publication or another required
  gap. Entry delivery nonclosing1 is retained. Source-independent authored
  inputs are engineering controls, not a new inference experiment or references.

- 2026-10-28, Big Boss: the AC3 WAV-operator inventory finds this separate path
  before extending scope. `ReadBatch` advances its entry cursor before lazy
  construction; adding a throwing observer there needs explicit failure state
  and private output handling, not a wrapper progress message. Preserve existing
  group/source isolation and exact full-source support. The WAV component has
  its own actual worker/abort/replay evidence under inference-operator-progress-
  20261028-boss; that evidence does not close this task or all parent AC3.
