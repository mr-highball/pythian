# NS-6_serialization_01 — Observe bulk native JSON publication

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Before this repair, style-card encoding built its JSON values observably, then called RTL
`AsJSON` synchronously. The authored one-trait/256-group/4096-bin probe emitted
3535085 bytes with no interior callback during that formatting. Checked
Win64 without heap tracing measured828ms there; with heap tracing21234ms and
14.3GB cumulative allocation across the complete probe. The latter is diagnostic
overhead, not a production timing claim. Input allows up to64 traits. An endpoint
around formatting does not cover its interior or establish a latency guarantee.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. This is a linked prerequisite of retained evaluation AC2
in [task04](../NS-6_observability_04.md), not an upstream WFC responsibility.

Execution status: accepted at `ae91789` after checked native/actual pas2js
consumers, exact prior report bytes, separate capacity traces and
[Ubuntu CI461](https://github.com/mr-highball/pythian/actions/runs/40707332384),
including maintained integration and both extracted core-only/full packages.

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

- [Shared progress contract — DONE](NS-6_observability_01.md).
- [Shared evaluation text](NS-6_portability_06.md) — retain exact native text
  bytes and the corrected fpjson/file-write bridge during serialization reuse.

**Dev Notes:**

- 2026-10-28, Big Boss acceptance: exact published source
  `ae91789367ff27dc441182fcbefc1d8587b1c360` passes Ubuntu CI461,
  job122882866023, terminal Success10m5s. Maintained integration9m4s and both
  extracted consumers41s pass. AC1–3 and prerequisites pass with the native,
  actual pas2js, prior-byte and measured-boundary evidence below. Both clean
  extracted Win64 packages also pass107/158 owned units and120/277 inventory
  entries. CI upload-container digests: logs
  `43b58f8821f205db8095fd94c31577d421abba4e5b98508f407a16fa5555e0e4`,
  packages `c49b50a76870a966060e87c591ab4597d140ad9345704eb59f215448ce241aa9`.
  These are not the native package ZIP hashes. Move this task and incoming links
  together;53 open/78 DONE/131 total, NS-6 15 open. Overall52.45/47.55 unchanged;
  real closure retains delivery nonclosing0. Parent04, decoder storage02 and
  actual browser/phone qualification remain open. Preserve all earlier failures
  and residual timings; verification was solo, with no musical credit.

- 2026-10-28, Big Boss local qualification: native Win32/Win64 each pass656
  serialization checks/12 original abort-retries/409 callbacks, zero leaks;
  actual pas2js174/4/92. The actual Win64 style consumer passes3292106/230/1645208
  with zero leaks; prior357 JSON and94 card controls pass. Thirteen frozen
  artifacts and the actual CLI report are exact. Byte callbacks advance by at
  most4099 emitted UTF-8 bytes; native node visits are iterative. The portable
  buffer uses geometric native bytes or bounded JS chunks/final join; RTL still
  owns finite-number formatting. No whole-card `AsJSON` remains in either adopted
  writer. Borrowed tree/callback contracts exclude re-entry/input mutation.
  Published Linux and both extracted consumers are still the closing gate.

- 2026-10-28, Big Boss measured residuals: checked no-heap Win64 actual card with
  256 groups/4096 bins emits3535085 bytes in1438ms, encoder1250ms,10742 callbacks,
  maximum observed byte-checkpoint gap16ms. Maximum64 traits with original small
  groups emits115771 bytes in15ms; exact8MiB scalar budget emits8388608 bytes
  in328ms. Final shrink/copy measure0ms only at the available clock resolution.
  These exercise separate capacity axes, not every simultaneous maximum or a
  latency guarantee. No speedup over the old synchronous828ms is inferred.
  Evidence: dedicated E-drive `json-write-20261028-boss` build/test/run roots.
  Preserve the diagnostic probe's missing-output-directory and constant-name
  compile failures; their orchestration repairs change no product policy.

- 2026-10-28, Big Boss distinct gap: actual emitted pas2js shows the retained
  decoder still using per-character `rtl.setCharAt` on its pre-sized string.
  Create [json-text_02](NS-6_json-text_02.md) to consolidate that storage after
  this writer is qualified, then return here. Do not expand this batch into
  decoder performance work or infer a measured latency from source inspection.

- 2026-10-28, Big Boss consumer failure: the new actual-byte oracle exposes
  the existing style-progress fixture's `GText`/expected text as host `String`.
  Assigning the UTF8String result there transcodes its Unicode and changes length.
  Use the existing primary `TScalarText` for those retained values. Preserve the
  failing byte-oracle log and normal repair/retry; do not change production byte
  totals or the fixture's arithmetic, exposure or cancellation expectations.

- 2026-10-28, Big Boss batch selection: AC1–3, entry nonclosing0 after real
  JSON/portability closure in Ubuntu CI460. Installed RTL `DumpJSON` has fixed
  compressed syntax, whole-key/string formatting before writes and a host String
  bridge, so it cannot retain the actual canonical byte/progress contract.
  Reuse RTL numbers, primary scalar traversal and one bounded portable text
  emitter; native object-tree traversal stays in the adapter. Require old bytes,
  portable/native escapes/budgets, original aborts, actual large-card/report
  consumers and published integration/extracted packages. Naming this selection
  earns no criterion or musical credit. No listener, private media/answer or WFC
  changes are selected.

- 2026-10-28, Big Boss: source/sizing proof is in E-drive
  `style-evaluation-20261028-boss/measure-bounds.lpr`, with separate checked
  heap-traced and no-heap logs. Native input is authored counts only; no private
  recording, learned claim or musical evidence is created. Preserve those logs
  and current canonical outputs. Discovery/naming closes no criterion and resets
  no counter. Return to the current portable-text/callback batch before selecting
  implementation here; no additional WFC branch was opened.
