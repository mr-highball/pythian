# NS-6_observability_14 — Observe and cancel generic WFC solving

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Supply the generic solver prerequisite for retained generation in
[observability_04](../NS-6_observability_04.md). The existing WFC trace sink deliberately
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

Accepted 2026-10-28 by Big Boss, solo verification. AC1–3 and prerequisites pass
at Pythian `57df5504f18f3304d26f162deebc5601e862d626` with explicit WFC pin
`c496b1d0a8a7570edd34aebaa9982bc32cc7fcf7`. The upstream branch remains unmerged.

- AC1: Optional borrowed prepare/search/commit observation reaches all six normal,
  negotiated, restarted and selective solve families. Counts are phase/pass-local;
  unknown totals and synchronous allocation/copy/RTL/planning/connectivity
  residuals are documented. Diagnostic receiver failures retain their contract.
- AC2: Checked generic Win32/Win64 and actual pas2js each pass44831 checks/58
  original abort-retries, including first-callback trace ordering and contained
  trace receiver failure. State, domains, flags, selection, random streams and
  retry remain exact; native runs have zero leaks. Frozen nonlinear transcript
  hashes36DF8F92/6F76591D and12 old-pin replay cases remain retained evidence.
- AC3: All five [upstream CI54 jobs](https://github.com/mr-highball/wfc/actions/runs/40732166290)
  pass at the exact pin, total22m17s, including actual browser conformance.
  [Pythian CI464](https://github.com/mr-highball/pythian/actions/runs/40732725755)
  job122973041029 passes14m47s, integration13m29s and both extracted consumers45s.
  Both clean Win64 extracted packages pass107/159 owned units and120/279 inventory
  entries. Current checked layer consumers pass466607/149 per native target,
  zero leaks; actual native/pas2js direct consumers each pass5630 checks/12 abort-
  retries/2016 callbacks with exact128 token/index cells. All38 prior packaged
  audio/model artifacts are unchanged.

The task adds no musical credit. Accepting it changes counts to52 open/80 DONE/
132 total, NS-6 14 open;52.45/47.55 remains unchanged. Real criterion closure
resets delivery nonclosing2 to0 after the recorded bounded reassessment. Parent04
still owns retained capture/copy, stream/voice and batch/inference/operator gaps.
No actual Studio, physical listening or whole-goal acceptance follows.

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

- [Generic WFC preparation — DONE](NS-6_observability_12.md).
- [Generic WFC learning — DONE](NS-6_observability_13.md).

**Dev Notes:**

- 2026-10-28, Big Boss: preserve both nonclosing qualification cycles. CI52
  rejected package ordering before solving. Predecessor29182bb then passed CI53
  and Pythian736a313/CI463, but the combined contract audit reproduced trace
  begins0/events1/ends1 when the first work callback cancelled. Reassessment
  restricted work to the demonstrated ordering repair and qualification.
  c496b1d establishes BeginDelivery first; the maintained healthy/failing trace
  regression now passes with original work cancellation intact. Final CI54 and
  CI464 qualify this repaired source, not the predecessor's green status.
  Detailed logs, original failures, private probes and current parity packet
  remain under E-drive wfc-solve-progress-20261028-boss and
  solve-bridge-20261028-boss roots. Core/full ZIP SHA256:
  `34cb061f3548b0f20b7d3ff525ca647d48237d9f47218557bbdec0d014e45cbb` /
  `201c9e2e39522a89da8523c48876b16a8365572d4450a71f21acff26a2b75e38`.
  No dependency source, service, private recording, answer or scientific policy
  is changed here. Later dated candidate statements below are historical gates.

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
