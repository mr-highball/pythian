# NS-6_delivery_06 — Deliver a current minimal native synthesis package

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Make the reusable Pascal synthesis library consumable now through a current,
bounded source package and concise example. A caller builds the portable core,
loads or creates audio, changes a synthesis control, renders, saves WAV and
reloads the result. This deliverable uses accepted native capabilities; recorded
learning, final musical providers, style acceptance and the operator application
are separate outcomes and do not block this useful library slice.
Deliver both an isolated core subset and an explicitly opted-in current WFC
companion source/example closure, so a caller can also build supported provider
extensions without waiting for the final recorded-learning workflow.

North star: NS-6. Outcome owner: WAV-05-DELIVERY, minimal native consumer slice.
Completion credit: 8 goal percentage points (0.80 overall points).
Current complete-goal allocation, 2026-09-29, with NS-6 weighted at 10 overall points,
under the user's authorization
to rebalance without preserving historical point allocations. All existing
acceptance criteria remain required; this plan revision earns no acceptance.
Allocation rationale: A current minimal native package makes the central reusable Pascal synthesis capability independently consumable now.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [accepted native checkpoint](DONE/NS-6_delivery_02.md) ·
[package script](../../tools/package.ps1) · [core example](../../examples/pythian.example.core.lpr) ·
[packaging](../PACKAGING.md) · [consumer contract](../CONSUMER-CONTRACT.md).

Execution status (2026-09-30): implementation batch 1 has passed local stable
Win32/Win64 fresh core/WFC archive checks; independent final QA and exact-revision
Linux acceptance remain required. The accepted earlier checkpoint does not
qualify this candidate. Next deliverable: independently review and publish the
frozen candidate, then verify its exact remote run. Closing evidence: inventories,
declared target/CI runs, changed control output, deterministic replay/reload and
focused failures. Stop at a missing target runner, nonreproducible input or broken
extracted closure and record its unblock/repair condition. Keep OPEN/zero credit
until every criterion and remote gate passes.

**Acceptance Criteria:**

- Freeze the current source revision and supported minimal API/input/target
  scope. Package its complete portable source/example closure, complete notices
  and precursor provenance. Deliver the opted-in current WFC companion subset
  separately, with its exact pin, complete adapter/dependency source closure,
  matched examples and notices. Exclude ignored private recordings, stale
  formats, browser/operator services, hidden caches and removed Phanes source.
- Extract the delivered archive into a fresh consumer root and compile/run its
  documented load-or-create → control → synthesize → save → reload example on
  the declared stable target matrix, including the affected remote CI path.
  Exercise both the core-only consumer with no WFC paths and the opted-in WFC
  source/example subset at its supported native scope, including the public
  closure needed by caller provider extensions. The companion mechanical
  example does not imply final recorded-provider or learned-style acceptance.
  Compile against extracted sources only, with fresh unit/output directories;
  record source and archive identities, inventory lengths/hashes and commands.
- Demonstrate that a declared control changes the expected output, fixed
  inputs/seed replay deterministically and saved WAV reload preserves its
  declared frame/rate/channel contract. Exercise the example's relevant bad
  input/control/output failures and document ownership and recovery bounds.
  Do not imply device playback, physical write atomicity, hard real time or
  accepted learned musical styles.
- Provide concise reproducible instructions and distributable or independently
  obtainable inputs with no absolute workspace path or unpublished dependency.
  Record the artifact inventory, supported scope and known limitations so an
  outside consumer can perform delivery_07 without this checkout.

**Blockers**

- [NS-6_delivery_02.md — DONE](DONE/NS-6_delivery_02.md)

**Dev Notes:**

- 2026-09-30 batch 1: Big Boss selected this ready library slice after corpus_05
  accepted and evaluation_01 AC1 closed while independent reference/calibration
  remained blocked. Neo exclusively owns the core example, generic actual-WAV
  verifier, package/build integration and public instructions/task/WORK; Ticket
  Guy exclusively owns the new caller WFC-provider example. Existing provider,
  source and vendor units remain read-only. Scope is create→declared control→
  synthesis→save→actual saved-file reload, exact fixed-seed replay, meaningful
  changed-control and failure boundaries, complete extracted portable/opt-in
  WFC source closure/notices/pin and current artifact identity.
- Candidate archives bind a base revision plus explicit dirty state and exact
  inventory hashes; uncommitted candidate bytes are never identified by HEAD
  alone. Both local stable Windows targets and the exact published revision's
  stable Linux CI must pass. Core and WFC extracted consumers are two ready
  components for independent Salty Boi QA. Keep the task OPEN with zero credit
  through candidate publication; complete/account only after remote success.
  A missing target runner or failed closure/control/replay stops that scope
  with its exact unblock condition. Our extracted tests are agent-run and do
  not count as actual independent delivery_07 use. No new inference, source
  acquisition or stopped calibration investigation is authorized.
- Current submitted implementation QA failures: 0. Two failed submissions
  transfer directly to Big Boss for repair. This is one active implementation
  batch; earlier stopped scientific counters remain unchanged.
- Local candidate archive checks passed stable FPC 3.2.2 i386-win32 and
  x86_64-win64: 98 core units/107 delivered inventory entries and 144 opt-in
  owned units/255 entries. ZIP extraction verifies every inventory length/hash
  before compilation; core consumers use only extracted `src` and fresh separate
  unit output. Core gain 1→0.5 retains 44,100 Hz/stereo/67,032 frames with maximum
  decoded PCM error 1.52587890625E-5; provider gain 0.25→0.5 retains
  16,000 Hz/stereo/16,000 frames with maximum error 3.0517578125E-5. Fixed-input/
  seed saved-file replay is exact on each target. Both paths exercise malformed
  input, gain/seed bounds, missing parents and preservation of existing outputs.
  These are candidate mechanical results, not final QA/remote acceptance.
- Published base `109696d93eec3832be701fbcc694f5122d911816` passed its maintained
  Linux integration step but failed its WFC extracted-package step: the reviewed
  catalog adapter's native annotation export dependency was absent. A frozen
  snapshot reproduced that exact missing unit on stable Win32. The candidate
  includes its complete six-unit native annotation closure/notices and the
  extracted tools search path; all delivered owned units now compile. HTTP,
  browser and service sources remain excluded; WFC source/pin remain unchanged.
  This existing delivery criterion owns the repair, not a generic WFC gap.

- 2026-09-29 current complete-goal credit basis: this task owns 8 NS-6
  goal points (+0.80 overall) by deliverable value. Nine open NS-6
  tasks allocate 85 goal points (+8.50 overall); the accepted contract and
  native checkpoint allocate 15 goal points (+1.50 overall), with zero baseline.
  Lifecycle support and actual ecosystem adoption are now explicit required
  outcomes. Earlier point amounts and conserved split totals are historical,
  superseded by this user-directed scope reassessment. Criteria and evidence
  requirements remain intact; planning earns no acceptance.


- 2026-09-29 this current minimal artifact is a distinct usable deliverable;
  it does not weaken or close any original delivery_03 criterion. The earlier
  checkpoint proves its frozen authored consumer only. Next deliverable: freeze
  the minimal contract/example and verify the freshly extracted current source
  archive. Closing evidence is the exact inventory, target runs, controlled
  output comparison, replay/reload and focused failure results. Stop at a
  missing target runner, nonreproducible input or broken extracted closure;
  name the unblock/repair condition instead of pulling all NS-3/NS-5 work or
  the operator application into this package.
