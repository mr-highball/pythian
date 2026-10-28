# NS-6_serialization_01 — Observe bulk native JSON publication

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Actual style-card encoding builds its JSON values observably, then calls RTL
`AsJSON` synchronously. A valid authored one-trait/256-group/4096-bin card emits
3535085 bytes with no interior callback during that final formatting. Checked
Win64 without heap tracing measures828ms there; with heap tracing21234ms and
14.3GB cumulative allocation across the complete probe. The latter is diagnostic
overhead, not a production timing claim. Input allows up to64 traits. An endpoint
around formatting does not cover its interior or establish a latency guarantee.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. This is a linked prerequisite of retained evaluation AC2
in [task04](NS-6_observability_04.md), not an upstream WFC responsibility.

Deliverable: reuse an available Pascal streaming/buffered JSON serialization
boundary and consolidate maintained consumers into it. Keep native object-tree
I/O in the adapter; any shared scalar codec belongs to the primary library.
Inspect existing formatter/stream APIs before adding an implementation. Preserve
current canonical field order, escaping, numeric formatting, output bytes and
scientific semantics. Do not introduce a parallel comparator, a third-party
runtime, or callbacks disguised as trace events.

Closing evidence: actual large-card and report consumers, interior/final original
abort/retry with retained prior output, malformed/budget edges, byte parity,
bounded incremental work, measured publication residuals and clean published
integration/extracted consumers. Stop on format drift, invented byte totals,
callback-driven partial accepted publication or a distinct required gap.

**Acceptance Criteria:**

- AC1: Bulk native serialization exposes actual emitted byte/item work through
  borrowed callbacks inside its variable-size traversal. Preserve one shared
  formatter and remove superseded whole-document formatting from adopted paths.
  Unknown totals remain unknown until actual completion.
- AC2: Interior/final cancellation propagates the original exception, frees
  staging resources and preserves caller output/accepted files. Retry retains
  exact canonical bytes. Delimit synchronous allocation, scalar formatting,
  final copying and platform writes honestly; no event-loop latency guarantee.
- AC3: The actual style-card/retained-report consumer uses the shared boundary.
  Checked native, prior canonical byte controls, representative maximum-size
  traces and published integration/extracted consumers pass. Broader task04,
  scientific gates and musical credit remain separate.

**Blockers**

- [Shared progress contract — DONE](DONE/NS-6_observability_01.md).
- [Shared evaluation text](NS-6_portability_06.md) — retain exact native text
  bytes and the corrected fpjson/file-write bridge during serialization reuse.

**Dev Notes:**

- 2026-10-28, Big Boss: source/sizing proof is in E-drive
  `style-evaluation-20261028-boss/measure-bounds.lpr`, with separate checked
  heap-traced and no-heap logs. Native input is authored counts only; no private
  recording, learned claim or musical evidence is created. Preserve those logs
  and current canonical outputs. Discovery/naming closes no criterion and resets
  no counter. Return to the current portable-text/callback batch before selecting
  implementation here; no additional WFC branch was opened.
