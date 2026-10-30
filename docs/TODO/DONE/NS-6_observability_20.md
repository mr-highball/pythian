# NS-6_observability_20 — Reuse observable immutable WFC model cloning

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Replace the repeated sequence-model copies made by text serialization in
Pythian's style, layers, voices, duration and event-corpus consumers. Their start/end callbacks
do not observe the codec interior. Cloning an immutable generic sequence model
belongs to WFC; Pythian owns adaptation to its existing work callback contract.
Reuse primary construction/copy behavior rather than adding another algorithm.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This extracts the independently useful model-copy prerequisite from
[parent04](../RETIRED/2026-10-29/NS-6_observability_04.md); every other original obligation remains.
No musical criterion or percentage is earned by this task's creation or checks.

Completed 2026-10-29 at Pythian e02d77fa41d021e3b036be99cb71e74ebd8f3227 and
WFC d4d30b120ee6ac6741387b206d971bb2877896aa. Exact upstream CI58 passes all five
jobs; [downstream CI498](https://github.com/mr-highball/pythian/actions/runs/40976178079/job/123804699827)
passes in 17m28s, including integration 16m1s and extracted consumers 38s.
Every original criterion and prerequisite below is satisfied. Full parent04,
actual Studio/phone and musical gates remain independent and OPEN.

Criterion advanced: parent04 AC1/2/5, observed retained model construction/copy.
Deliverable: generic observed immutable cloning plus all demonstrated Pythian
consumer replacements. Evidence: exact model identity, source lifetime,
original-exception abort/cleanup, actual portable/consumer execution and exact
upstream/downstream qualification. Stop on changed semantic state/PCM, a merely
wrapper-specific restriction, an existing fix or another required gap.

**Acceptance Criteria:**

- Isolate the required generic capability against pinned WFC, inspect the
  separate checkout for an existing fix, and follow the cross-repository
  procedure. Use a new branch from the reviewed pin, notify the user before
  source edits and preserve unrelated upstream work. No dependency source edit
  in Pythian's vendor checkout and no upstream merge are authorized here.
- WFC supplies one caller-owned immutable sequence-model clone with an optional
  synchronous borrowed observer. Reuse its primary observed constructor, retain
  exact ordered samples, literal tokens, state histories/counts, boundaries and
  model version, and keep source/clone independent after either is freed. No text
  roundtrip, mirrored validator or second copy algorithm is the clone mechanism.
- Report real construction visits and preserve original callback exceptions.
  A failed clone returns no result and disposes private state. Exercise every
  callback cancellation, retry, open/wrapped models, literal/Unicode identity,
  source preservation and nil-observer parity on native32/64 and actual pas2js.
- One Pythian adaptation forwards the primary work observer. Replace every
  demonstrated one-off serialization clone in style/layers/voices/duration/event corpus,
  preserving each consumer's ownership, coarse phase and final publication
  contract. Verify original model/selection/PCM and actual affected consumers;
  compiler success alone is insufficient.
- Qualify the upstream branch through its maintained conformance and all five
  CI jobs, then explicitly adopt the reviewed gitlink in Pythian. Pass affected
  native/actual portable and clean core/full extracted consumers plus exact
  downstream integration. Update task links and accounting together only after
  the complete criteria and prerequisites pass. Parent04 and actual Studio/
  musical gates remain independent.

**Blockers**

- [Upstream native build qualification01 — DONE](NS-6_wfc-build_01.md) —
  exact d4d30b1/CI58 passes all five jobs within the unchanged budget. Both
  original macOS timeouts remain recorded; downstream qualification stays here.
- [Portable passage ownership15 — DONE](NS-6_portability_15.md) — actual portable
  event-corpus qualification exposed a pre-existing wrong-source PCM failure.
  Its primary repair, exact oracle and extracted consumers qualify at384c6de/CI495.
- [Generic model/voice preparation17 — DONE](NS-6_observability_17.md) —
  accepted WFC pin c4e7569 supplies the primary constructor and observer bridge.

**Dev Notes:**

- 2026-10-29, Big Boss SOLO: terminal exact CI498 accepts the complete original
  task. Both clean exact Win64 packages pass 107/159 owned units and 120/280
  hashes; new clone/voice consumers from the actual extracted full package pass
  on native64 and actual pas2js (657 checks/6 aborts; 17221 checks/16 aborts).
  Native heaps are clean. WFC src/test trees are identical to locally tested
  5d69462, preserving every native32/64/pas2js consumer, all318 clone aborts and
  the exact70000-frame duration replay. Core Git source is unchanged from384c6de;
  106/107 old/current package source files differ only in checkout CRLF/LF, and
  all107 normalize identically. Reuse semantic core evidence with that explicit
  qualification, never raw-byte package identity. The initial private extracted
  runner split compiler switches; repaired orchestration changes no assertions
  or source, and preserves its original logs. Counts54/96 become53open/97DONE,
  total150, NS6 16 to15open;52.45/47.55 and delivery nonclosing0 remain. No
  upstream merge, deployment, inference, operator-response change or musical credit.

- 2026-10-29, Big Boss: build01 is accepted after all-five CI58 SUCCESS at exact
  d4d30b120ee6ac6741387b206d971bb2877896aa. Its src/test trees are identical to
  reviewed clone5d69462, preserving completed local consumer/replay evidence.
  Select explicit gitlink adoption and clean downstream/extracted qualification;
  this task remains OPEN until those original gates pass. No musical credit.

- Upstream build prerequisite01 now has candidate d4d30b1 on
  `codex/pythian-native-build-reuse`, retaining the exact5d69462 model/clone
  implementation and tests. Its native cache controls and command parity pass;
  all-five CI58 is live. Keep vendorc4e7569 and held Pythian changes until the
  exact upstream gate passes, then require this task's downstream/extracted gates.
- 2026-10-29, Big Boss: macOS CI57's one unchanged retry is terminal
  CANCELLED30m20s. Both attempts and all local successful clone work remain;
  no pin is adopted. Follow linked upstream build01 before further integration.
  Passage15's real whole-task acceptance atCI495 resets delivery nonclosing to0;
  this new prerequisite grants no credit or reset. No scientific family reopens.
- 2026-10-29, Big Boss SOLO: bounded domain-neutral required-clone consumer
  fails compilation against c4e7569 because the observable Clone entry point is
  absent. This demonstrates the missing proposed capability, not a broken
  existing API promise or a runtime/musical rejection. Public API/source audit
  finds only unobserved array-copy getters and text encode/decode; the separate
  expansion checkout and clone/copy branch search show no existing fix. The
  constructor already observes its private validation/copy work, so the proposed
  method can reuse it directly. Private E-drive sequence-model-clone-20261029-boss
  retains the unchanged compile consumer, original compiler failure and PLAN.
- Separate branch `codex/pythian-sequence-clone-progress`, fromc4e7569, is clean
  and pushed at5d6946288d6faffd08cfd31a76a9f833f535c51d; notice preceded source
  edits. Local native32/64 and actual pas2js each788662 checks/all318 clone
  aborts pass. Shared Pythian adaptation657/6 and actual voice17221/16,
  duration14 aborts/retries and measured event restoration pass on all targets.
  Original native64 layer/publication/wave consumers and70,000-frame exact
  duration PCM/continuation replay pass. Original portable event wrong-source
  PCM failure required linked portability15; its core repair qualifies separately.
- Upstream CI57 attempt1 reaches the existing30m macOS timeout during repeated
  compilation, with no reported assertion failure. Accepted macOS predecessor
  took24m31s. One unchanged macOS-only attempt2 is queued; no timeout expansion
  or repeated retry is selected. Pin staysc4e7569 until all upstream/downstream
  gates pass. Preserve the original failure and all scientific stops/exposures;
  current delivery nonclosing1 remains. No deployment, inference or feedback write.
