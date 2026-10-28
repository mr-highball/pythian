# NS-6_observability_14 — Observe and cancel generic WFC solving

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Supply the generic solver prerequisite for retained generation in
[observability_04](NS-6_observability_04.md). The existing WFC trace sink deliberately
contains receiver exceptions and therefore cannot implement cancellation. A
domain-independent pinned-source reproduction raises from BeginTrace yet returns
a solved, committed graph with failed trace delivery. Preserve that diagnostic
contract; add a distinct optional work observer to the primary solver instead.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
All parent musical, browser and operation coverage gates remain required.

Batch criterion: AC1–3 below. Deliverable: generic work/cancellation on actual
solve boundaries with atomic graph acceptance and unchanged nil-observer replay.
Closing evidence: original abort identity, graph/domain/random-state preservation,
retry and native/actual pas2js controls, then reviewed downstream consumption.
Stop on altered search policy, swallowed cancellation, callback after commit or
invented overall percentage. Entry delivery nonclosing count0; a new task/branch
does not reset it.

Upstream owner: WFC, separate branch `codex/pythian-solve-progress`, based on
`6b419e6e33c7cec40f5936ef734defbe33319aaa`. Big Boss works alone. The user is
notified before upstream implementation. Do not edit dependency source here or
merge another repository's branch. Private reproduction and build evidence use
the dedicated E-drive `wfc-solve-progress-20261028-boss` roots.

Execution status (2026-10-28): candidate c496b1d follows a combined trace/work
contract rejection at predecessor29182bb, despite its green CI53 and downstream
CI463. The first cancelled work callback could cause trace rollback/footer before
BeginTrace; the public reproduction reports0/1/1. Move BeginDelivery earlier and
add healthy/failing receiver controls. Local native/pas2js44831/58 pass. CI54 and
new downstream integration/extraction remain required. After two nonclosing
candidate qualification cycles, reassessment limits work to this repair and its
verification; delivery nonclosing2, no counter reset or scope expansion.

**Acceptance Criteria:**

- AC1: Expose optional synchronous generic progress with documented phase-local
  units and borrowed callback lifetime through normal, negotiated, restarted and
  selective solve entry points. Instrument primary owned preparation/search/
  validation boundaries; name any synchronous residuals without a latency claim.
  Diagnostic trace delivery retains its existing independent failure semantics.
- AC2: Original observer exceptions abort before accepted graph publication.
  Restore values, generated flags, domains, pass selection, random streams and
  running state on cancellation, including final precommit cancellation. Never
  invoke the observer during rollback/destruction. Retry matches an untouched
  fixed-seed control and retains existing contradiction/backtrack budgets.
- AC3: Qualify exact nil/observed replay, cancellation and retry on native and
  actual pas2js, with maintained generic regressions and upstream validation.
  Explicitly integrate the reviewed commit and exercise an actual Pythian layer
  consumer plus core-only independence. No audio-specific vocabulary enters WFC;
  no musical or complete parent acceptance follows from solver instrumentation.

**Blockers**

- [Generic WFC preparation — DONE](DONE/NS-6_observability_12.md).
- [Generic WFC learning — DONE](DONE/NS-6_observability_13.md).

**Dev Notes:**

- 2026-10-28, Big Boss: downstream candidate uses one progress bridge and optional
  native consumer forwarding. Win32/Win64 each pass466607 checks/149 original
  abort-retries and zero leaks. Actual native/pas2js direct acoustic/token
  consumers each pass5630/12/2016, with all128 token/index cells identical.
  Four actual caller WAV/style artifacts remain byte-identical to the prior
  accepted package. The portable consumer caught passing a parameterless callback
  factory rather than invoking it; explicit Pascal calls fix the primary bridge
  and analogous layer helper calls. Retain the failing generated-code evidence,
  source/fixture repairs and successful actual executions under E-drive
  solve-bridge-20261028-boss. No hand-edited generated-JS fallback exists.
  Upstream browser/trunk jobs pass but whole CI53 and downstream published
  integration/package gates remain pending. This is solo verification.

- 2026-10-28, Big Boss: upstream candidate39ba66b passes local generic Win32,
  Win64 and actual pas2js44807 checks/56 original abort-retries each, including
  actual later restart/negotiation cancellation and original transcript hashes.
  Twelve separately compiled frozen-pin cases match56160 complete replay bytes
  exactly. All native runs are leak-free. Existing quota regression exposed an
  uninitialized work pointer during pre-transaction retained-provider validation;
  initialize it before any helper call, then pass67/67 on both native targets.
  Preserve that failure and the earlier prepare-interior omission/default-argument
  and fixture-portability repairs in the dedicated E-drive evidence.
- Published CI52 stops before solver execution on package interface/Lazarus order.
  Repair only that ordering at29182bb; the actual native checker verifies97 source
  units in all definitions. [CI53](https://github.com/mr-highball/wfc/actions/runs/40725260596)
  is in progress. Local qualification is not published acceptance; keep this task
  open until remaining gates pass. The explicit downstream candidate gitlink and
  shared acoustic/layer bridge are being qualified. No service, firewall, private
  source or saved answer is changed, and no helper is used.

- 2026-10-28, Big Boss: checked Win64 public-API reproduction at the exact current
  pin reports one throwing sink call, solved=True, aborted=False, failed trace
  delivery and committed value `a`, with zero leaks. This demonstrates a missing
  cancellation facility, not a regression in the documented trace contract.
  The separate expansion checkout has no solver work observer; preserve its
  unrelated branch and attachments. New worktree/branch starts at the reviewed
  pin. No stopped inference family or private recording is reopened.
