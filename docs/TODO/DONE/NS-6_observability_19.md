# NS-6_observability_19 — Share observable journal source selection

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Batch and retained streaming selection duplicate the same weighted source/bin
rotation. The actual audio session forwards its observer into WFC, but stops
before selecting source windows. Consolidate selection in the primary portable
implementation and expose its actual owned visits, including final window
resolution, before publishing new cursor state.

Accepted 2026-10-29 at `b33c538a84ae2eb6ac1baf7f551956448d5948aa`, after
[primary journal portability12](NS-6_portability_12.md) acceptance. Checked
native32/64 and actual pas2js pass362071 selector checks and293 original-exception
abort/retries. All emitted setup/compatibility/slot/window checkpoints preserve
prior results and retained state on failure, with exact same-session retry,
reentry rejection and borrowed receiver lifetime. Both final native selections
retain all294966 values/2359728 bytes exactly:
`bbc73036c3103f5fdd16257b3d0b0b58d62c87df80d7c208b6b882b38d423e96`.

Original native journal/successor/profile consumers pass, including699 actual
audio-session caller aborts per target and exact PCM/lineage, zero leaks.
The full Win64 worker passes380 checks with all original assertions retained;
its160000-frame320044-byte WAV remains
`fea82882480eceae982305a79487e91eecbcc281f6a9c27c8746bab3e6409c07`.
Clean exact core/full packages and the extracted public API pass; core-only
native and actual pas2js consumers repeat362071 checks/293 abort/retries.
Exact published
[CI482](https://github.com/mr-highball/pythian/actions/runs/40880908655/job/123471848520)
is terminal SUCCESS: integration18m1s, extracted consumers44s. Big Boss verified
solo, without an independent-review claim. Parent04 retains ingestion/index
construction and render/duration interiors; transport18 retains actual browser
presentation. No musical credit, deployment or scientific reset follows.

This accepted component is a prerequisite to parent
[observability04](../RETIRED/2026-10-29/NS-6_observability_04.md). Actual Studio presentation remains
owned by [transport18](../RETIRED/2026-10-29/NS-6_observability_18.md); it does not block this primary
component's native/portable evidence. Journal ingestion/index construction and
render/duration interiors remain in parent04; do not claim whole-unit coverage.
Delivered: one shared selector with call-borrowed progress/cancellation,
atomic slot/window results and actual audio-session forwarding.
Closing evidence and stop condition: frozen exact selections and actual worker
WAV replay, abort at every emitted checkpoint with unchanged prior result/state
and exact retry, reentry rejection and native32/64/actual pas2js execution.
Stop on seed, weighted rotation, source clock/window, counter or audio drift.
Primary attribution: NS-6. Secondary musical use earns no duplicate credit.
North star: NS-6. Outcome owner: REUSABLE-OPERATIONS.
Completion credit: 0 goal percentage points (0.00 overall points).
Credit is earned only when every acceptance criterion and task-flow completion requirement passes.

**Acceptance Criteria:**

- Batch and streaming slot/window selection share one primary weighted
  selection implementation. Preserve eligibility, weights, seeded bin rotation,
  consecutive-window behavior, successor decisions and existing declared visit
  budgets/counters. All frozen pre-change successful results remain exact.
- Optional observers are synchronous and borrowed per call. Count actual owned
  work with truthful units and no invented percentage. Cover stream setup and
  its compatibility scan, token/eligibility/bin selection and window expansion;
  name bounded synchronous RTL copies and constant-time successor lookup.
- Every callback exception preserves its identity, the caller's prior assigned
  slot/window buffer and the retained selector's cursor, credits, previous actual
  window and counters. Same-session retry is exact. Reject mutating reentry;
  do not retain the receiver. Preserve existing input/lifetime obligations.
- Actual audio-session generation forwards the same observer into selection.
  Preserve its existing terminal-failure contract and prior caller PCM/position
  on abort; emitted earlier audio/WFC work is not promised rollback. Frozen
  actual worker audio and source/model/feedback lineage remain unchanged.
- Execute original relevant regressions plus boundary/abort/retry checks on
  checked native32/64 and actual pas2js for the portable component; qualify the
  maintained native consumer and clean extracted public API at the exact
  published revision. No actual browser, note admission or musical credit is
  implied by these checks.

**Blockers**

- [Primary journal portability12](NS-6_portability_12.md) — actual compile and
  raw codec/binding consumer gaps; native-only checks cannot satisfy this gate.
- [Primary analysis portability01 — DONE](NS-6_portability_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: final local native32/64 and actual pas2js pass362071
  selection checks and293 original-exception abort/retries. Both native targets
  retain the frozen294966-value2359728-byte selection packet exactly; original
  journal/successor/profile consumers pass, including699 actual audio-session
  aborts per target, zero leaks. The full native worker passes380 checks with
  every original assertion retained; its160000-frame320044-byte WAV remains
  SHA256fea82882480eceae982305a79487e91eecbcc281f6a9c27c8746bab3e6409c07.
  The private journal-selection-progress-20261029-boss packet preserves compile
  failures and repairs. Studio recovery compiles with the new activity labels;
  actual browser presentation remains transport18's open gate. No deployment,
  private-source/answer change or musical credit. Published/extracted gates remain.

- 2026-10-29, Big Boss: checked native32/64 pass362070 callback checks and293
  original-exception abort/retries, with exact future state and old caller
  buffers. Original selection/successor controls and actual profile/audio pulls
  pass699 original caller aborts on both targets, with exact PCM and zero leaks.
  A294966-value2359728-byte frozen pre-change packet is exact on both native
  targets, SHA256bbc73036c3103f5fdd16257b3d0b0b58d62c87df80d7c208b6b882b38d423e96.
  Actual pas2js compile fails on the existing native journal GroupId type;
  stop at linked portability12 before expanding scope or claiming portability.

- 2026-10-29, Big Boss: musical reassessment preserves the stopped pitch, local
  key, presence and pulse families. The pinned SwiftF0 runtime/training trees
  contain no frozen numerical fixtures; export checks produce model/report,
  not the numerical reference needed to reopen the failed Pascal candidate.
  No new model execution follows. This batch addresses the user's existing
  shared-implementation and long-operation requests through an actual retained
  audio path. It does not reopen musical experiments or grant musical credit.
