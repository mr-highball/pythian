# NS-6_native-cache-path_01 - Preserve native cache I/O across supported Windows path lengths

[Active tasks](../README.md) · [Corpus styles](NS-5_style-corpus-capacity_01.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** Accepted — 2026-11-01
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

Delivered on 2026-11-01 at `0235194d51b8125b9dfba4198618fef64a3b7e20`.
Shared native I/O preserves long Windows paths and exact Unicode names, atomic
publication and explicit byte limits. The original long-root playlist and clip
consumers pass; rejected writes preserve accepted bytes. Complete
[CI556](https://github.com/mr-highball/pythian/actions/runs/41351329967) passes
maintained integration and both extracted packages. Local Win64 checks include
the independent wide-path assertion; Linux CI exercises the portable boundary.
No machine setting or service/browser change is required.

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

- 2026-11-01, Big Boss: all criteria pass. Complete CI556 at the exact source
  above verifies core123/WFC186 units and137/316 content hashes after extraction;
  the missing shared helper is present. Retained logs and packages match their
  GitHub artifact digests. Win64 paths9, playlist2,016,325 and clips39 have clean
  heaps; CI passes paths8 (Windows-only assertion excluded), playlist and clips.
  Evidence: E/runs/style-capacity-20261101-boss/ci556-logs and native-consumers03.
  Preserve the original long-path, fixture code-page and package omissions below.

- 2026-11-01, Big Boss: repaired actual ZIP consumers now pass on Win64 from
  fresh E-drive roots. Core verifies123 units/137 content hashes; WFC verifies
  186 units/316 hashes, including `unpacked/pythian/tools/pythian.tools.path.pas`.
  All consumer examples complete. Logs and ZIPs are retained as
  styles-ci555-package-{core,wfc}01; their manifest identifies the actual dirty
  candidate, not only the base Git revision. Full replacement CI remains required.

- 2026-11-01, Big Boss: exact CI555 at e88ac445 passes the maintained native
  integration and core ZIP consumer, then fails the extracted WFC consumer:
  `pythian.tools.path` was missing from the explicit packaged-tool list used by
  `pythian.tools.files`. The package must include that shared unit. Preserve the
  actual compiler log and before-script under E/runs/style-capacity-20261101-boss.
  Downloaded log artifact SHA256 matches GitHub's retained digest
  c91c5287e28186b83f7fc12cfd4523f2b05f703538881241f87f293c63cbe25f.
  This is the existing AC3 integration failure, not additional task scope or
  accepted effort. Test actual replacement ZIPs before the replacement push.

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
