# NS-6_native-cache-path_01 - Preserve native cache I/O across supported Windows path lengths

[Active tasks](README.md) · [Corpus styles](NS-5_style-corpus-capacity_01.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Repair the native filesystem boundary exposed by actual playlist qualification.
The declared E-drive test root plus existing namespace/source/content hashes
produces a 261-character proposal-cache target. A shorter staging filename can
be created, but the direct Windows rename fails with OS error3. A shorter fresh
root passes the same 2,016,321-check consumer. Keep logical paths, content hashes,
bounded atomic publication and private data unchanged; do not require a global
Windows configuration change or hide the issue by shortening caller paths.

Primary attribution: NS-6. This distinct platform gap adds two effort units.

**Acceptance Criteria:**

- AC1: Shared native file boundaries correctly open/read and atomically publish
  the actual long cache target on Windows, retaining exact content and Unicode
  path meaning. Keep existing path/reparse checks and explicit byte limits.
- AC2: The original ordinary playlist consumer passes from its long fresh root,
  including actual cold/warm source learning, saved models and style artifacts.
  Short paths and independent clip learning still pass. No service/browser or
  system security setting is needed for this filesystem repair.
- AC3: Failure/overbound publication preserves existing accepted records;
  current native integration and extracted consumer qualification pass.

**Blockers**

- None.

**Dev Notes:**

- 2026-11-01, Big Boss: actual long-root consumers now pass: nine independent
  deep Unicode/atomic-budget checks, 2,016,325 playlist checks and 39 saved-clip
  checks, with clean heaps. Cold/warm caches, generated audio, saved candidates,
  cancellation and clip-only learning are exercised through the ordinary native
  callers. Existing bytes survive nonreplace and size-limit rejection. Evidence:
  E/tests/style-capacity-native-consumers03. Complete integration/extracted CI
  remains required before acceptance; no deployment or system setting changed.

- 2026-11-01, Big Boss: deep native path qualification remains in progress.
  Preserve path01/02/03 and RTL probe01–05 evidence on E. Probe04 proves an
  ANSI/UTF-8 comparison can select the wrong fallback even with intact input
  bytes. Shared native path normalization now compares bytes explicitly;
  probe05 independently verifies the intended Unicode filename. The maintained
  fixture also repairs its own implicit String conversion and independently
  checks the actual wide path. Full original long-root playlist/clip consumers
  follow; no task acceptance or system configuration change is inferred.

- 2026-11-01, Big Boss: preserve native-consumers01/02 under E/tests and the
  scj01 short-root control. The first failure retained only the checkpoint
  message. A second qualified executable adds the failing basename and OS error;
  its261-character `.pmp` target fails with OS3 while its parent exists. The short
  control passes with a clean heap. Follow this real prerequisite before closing
  corpus capacity; do not classify the filesystem error as a style-model failure.
  The existing two-nonclosing-batch counter remains; no effort is accepted.
