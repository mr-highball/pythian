# NS-6_observability_12 — Repair generic WFC bulk constraint preparation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Coordinate a demonstrated generic WFC sequence-graph bulk-constraint gap in its
separate repository, then integrate the reviewed upstream commit explicitly.
Pythian's admissible 256-state/1024-cell request spends over 80 observed CPU
seconds inside bulk mask intersection without an interior callback, repeatedly
revalidating the same graph/model for individual masks. Audio interpretation
and Pythian's progress adaptation stay here; generic preparation belongs to WFC.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. Upstream branch: `codex/pythian-sequence-preparation`, based
on pinned `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`, in a separate worktree under
`E:/CodexWork/pythian/runs/wfc-sequence-preparation-20261027-boss/worktree`.
The existing `D:/Docs/GitHub/wfc` expansion checkout and attachments are preserved.
The user was informed of owner, branch and concrete gap before upstream edits.
Deliverable: one shared bulk preflight plus generic optional progress/cancellation
at actual owned boundaries, preserving public single-mask behavior and rollback.
Stop on changed domains/definitions/replay, swallowed cancellation, foreign
dependency edits in this checkout, unrelated upstream adoption or a distinct gap.

**Acceptance Criteria:**

- AC1: Isolate and repair redundant graph/model validation in WFC's bulk sequence
  constraints without weakening full malformed-request preflight, public token
  semantics or domain intersection. Use one shared implementation, not a Pythian
  copy. Add a dependency-free borrowed observer with truthful units/counts and
  original abort propagation through actual bulk preparation.
- AC2: Native Pascal regressions in WFC preserve graph definitions, seeded replay,
  pre-existing allowed domains and malformed/duplicate/out-of-range behavior.
  Interior/final callback abort restores the original domains and permits retry.
  Repeat the same authored 256-state/1024-cell repro to completion, recording
  actual work/cost without a universal latency or speedup claim. Qualify supported
  portable execution and unrelated existing sequence consumers.
- AC3: Link the upstream reviewed branch/commit and evidence here. Adopt only that
  revision through an explicit Pythian gitlink change, bridge generic work records
  to primary progress without reimplementing WFC, and run affected core-isolation,
  native provider/layer/style consumers and clean published integration. Upstream
  branch success alone closes no downstream criterion and authorizes no merge.

**Blockers**

- The generic WFC fix and its validated commit on the named branch.
- [Cross-repository procedure](../TASKFLOW.MD#cross-repository-wfc-gaps).

**Dev Notes:**

- 2026-10-27, Big Boss downstream qualification: explicit gitlink/borrowed bridge
  pass checked Win32/Win64 layer25077 checks/29 abort-retries/4477 callbacks
  (3161 companion), plus actual semantic/provider30766 checks/30674 callbacks,
  zero leaks. All34 same-target artifacts match independently compiled frozen
  `bcabd70` layers plus prior `47fa3d8` companion sources. Actual provider codec
  and maintained caller pass. Owned visit oracles13/8/2 remain unchanged; known
  generic totals are phase-local. All local handles are terminal; publish and
  require clean integration/extracted consumers plus upstream CI before closure.
- 2026-10-27, Big Boss upstream publication: reviewed/pushed
  [d1c1c81](https://github.com/mr-highball/wfc/commit/d1c1c81b914a71a31a27b4abefcabede4a567abd)
  on the named branch, with no merge. Maintained native sequence/preparation
  loops pass both checked targets: existing120 checks, new18528 checks with
  8 original interior/final aborts and5384 callbacks, zero leaks. Actual
  pas2js new fixture passes18532 checks; its additional malformed JS controls
  account for the count difference. Existing text consumer passes48 checks.
  Original nil-observer exact probe completes6594 ms; final observed workload
  2000/7344 ms are local Win32/Win64 observations only. Mixed pre-existing
  absent/empty domains now have explicit rollback/retry coverage. PowerShell
  maintained loop execution and Bash syntax pass. Upstream
  [CI50](https://github.com/mr-highball/wfc/actions/runs/40610315254) is running;
  final downstream acceptance is still open. Explicit Pythian gitlink and
  primary-callback bridge are drafted; source changes here never patch WFC.
- 2026-10-27, Big Boss failed checks: the new integration fixture initially
  inferred a fixed-width array from its first stage-name string, truncating
  later names and missing the intended abort. Replace it with a typed String
  array; preserve both failed logs in the E-drive record. A diagnostic build
  used the wrong working directory before execution; preserve that setup log.
  An additional Pythian layer pas2js compile stops at its pre-existing native
  `UTF8String` local in positioned masks. No browser support is claimed for
  that native adapter by this task; WFC's changed portable API executes under
  actual pas2js. [Support scope](NS-6_support_01.md) owns target declarations.
- 2026-10-27, Big Boss upstream draft: new shared preflighted intersection core
  removes repeated definition checks, with public single-mask guards retained.
  Generic borrowed phase/count callbacks cover graph model validation, full mask
  preflight, domain snapshot and intersection; final callback abort stays inside
  rollback. No callback is retained or called during rollback. Existing sequence
  suite120 passes checked Win64. The new exact near-limit/replay fixture passes
  18584 checks/8 original interior-final aborts/5384 callbacks on checked native
  Win32/Win64 and actual pas2js; native zero leaks. Original authored nil-observer
  probe now completes Win64 intersection in6594 ms. Observed replay fixture
  intersection2485/8781 ms are local timings with concurrent work, not a universal
  speed or latency bound. Upstream changes remain uncommitted, fixture/build/docs
  and unrelated consumer qualification are not finished, and Pythian adoption has
  not occurred. Keep this task open. Evidence stays under dedicated E-drive
  `build/runs/wfc-sequence-preparation-20261027-boss` roots.
- 2026-10-27, Big Boss: task11's residual probe uses only authored Pascal tokens
  and the public WFC contract. It creates 256 public tokens/states, order1,
  1024 cells and 262144 state/cells, then 1024 valid per-position masks. The
  current separate checkout at `85d19fe` and the pinned revision have identical
  `wfc_sequence_graph.pas` blob `8c01fc3eeceae5bd3da8869cf41f03fd52f86c25`;
  no existing fix was silently adopted. `IntersectSequenceTokenConstraints`
  preflights once, then calls the public single-token API for each mask, which
  repeats `ValidateAppliedModel` and salt preparation. Source is generic WFC.
  The verified isolated probe PID was externally stopped after 119.944 seconds
  total /119.609 CPU seconds, still in intersection. An earlier observation at
  38.48 CPU seconds was already in the same call: over 81 observed CPU seconds
  without completion. This is a lower-bound failure, not a completed timing or
  zero-leak result. Encode0/decode16/model-application1766/constraint-validation15
  milliseconds and two RTL copies below clock resolution precede the stall.
  Evidence/source/stop identity: dedicated E-drive layer-preparation run root,
  `companion-residual.lpr`, `companion-residual64.log`, `residual-external-stop.json`.
  The initial probe omitted `wfc_model` in uses; that compiler log is preserved
  and the setup was repaired before execution. All task11 owned-loop consumer
  checks still pass; this distinct upstream gap remains required in task04.
