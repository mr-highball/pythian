# NS-6_observability_02 — Catalog import checkpoints and cancellation

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Extend the primary catalog import/verifier/copy path with shared progress, including
its callers in library preparation, capture saves and derived clips. The former
outer job label was indeterminate while nested hashes/copies ran silently.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional.
Deliverable: observable import phases and propagation of callback aborts without
turning cancellation into an ordinary per-file failure. Closing evidence: native
import cancellation, retry/atomic publication checks and consumer integration.
Stop on partially admitted sources, swallowed callback exceptions or duplicated
hash/copy algorithms. Big Boss owns assessment and integration.

Accepted 2026-10-27: measured importer phases use the primary callback/hash
implementation, with cancellation forwarded by library, capture and effects,
including their final library refresh. Spike implemented import checkpoints;
Spiegel integrated consumers; Big Boss integrated job/display checks and delivery.
After both components were ready, Spiegel independently checked the importer and
Spike independently checked capture/effects and reviewed integration. All three
criteria pass mechanically. No musical, actual-browser or physical-phone
acceptance is implied; zero additional goal credit.

**Acceptance Criteria:**

- Progress reports current bytes/items during import hashing, verification and
  copying, with truthful phase transitions and shared portable callback types.
- Callback exceptions propagate through per-file error handling; cancellation
  leaves durable originals and accepted catalog records intact and retryable.
- Library, capture and effects consumers forward callbacks to the same importer;
  no parallel import implementation. Add meaningful parity and abort checks.

**Blockers**

- [Shared observability contract — DONE](NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss acceptance: checked FPC 3.2.2 Win32 and Win64 import
  fixtures pass 395 checks each; independent Win64 execution also passes 395.
  Authored multi-buffer cases cover unchanged successful reports, original
  exception identity for EAudio and ordinary Exception, hash/copy/source/staged/
  existing verification cancellation, duplicate entries, cleanup, prior durable
  record hashes and retry. Earlier complete entries may remain accepted after a
  later abort; retry reconciles duplicates. No callback follows final record
  publication and can turn success into cancellation.
- Consumer evidence: library 588, capture 71 and effects 141 checked Win64
  assertions, zero leaks; independent capture/effects also pass 71/141. The
  original source-review/import/export contract passes, zero leaks. Actual
  selected-library native worker: 27 checks including persisted byte units and
  completed import phases. Actual pas2js/JSDOM recovery/display: 31 checks;
  all four browser programs compile. DOM is not actual browser playback.
  The native build registers the importer fixture with a fresh output root.
  Evidence: E-drive `build/tests/runs/import-progress-20261027-{boss,spike,spiegel}`.
- Repaired development findings: unthrottled nested notifications failed the
  existing library callback-count gate. The adapter retains its eight-MiB/
  five-second cadence and always forwards starts/resets/completion; direct import
  retains 8-KiB hash and 64-KiB copy checkpoints. Root review found final capture/
  effects refreshes also needed the shared callback bridge. An overly generic
  original-file label failed the recovery assertion and was repaired. An initial
  fixture helper compilation error was repaired. No formal combined QA submission
  failed; no implementation transfer was required.
- Execution correction: the retained staging helper uses cwd/build. Big Boss's
  first library-worker check created one isolated D-drive stage; its catalog-bound
  identity was verified and that exact three-file stage moved to E with hashes
  preserved. Further checks and the review service use an E-drive working directory.
  Fixed executable slots and historical D-drive evidence remain intact.
- Remaining work: [offline DSP](../NS-6_observability_03.md),
  [retained operations](../NS-6_observability_04.md), and actual operator/browser
  presentation. See [coverage](../../OBSERVABILITY.md) and [work](../../WORK.md).
- 2026-10-03, Big Boss: audit of `pythian.tools.annotations.catalog` finds
  nested full-source hashes and staged copying inside `ImportLabelInbox`, with
  per-file exception handling. A stage label alone cannot give cancellation
  checkpoints here. This is distinct from the analysis/pitch/effects callback batch.
