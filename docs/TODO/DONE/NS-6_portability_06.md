# NS-6_portability_06 — Execute shared style evaluation with portable text

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

The actual pas2js compiler rejects `UTF8String` in the primary style distribution
API at `1be04c0`; the existing distribution fixture cannot execute. The style-card
API also depends on that type in evaluation bindings. A native callback pass
cannot qualify these shared consumers. Do not hide the failure with a test stub,
parallel comparator or an alias that silently changes byte limits/scalar order.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. This is a demonstrated prerequisite of the shared checks in
[retained evaluation task04](../NS-6_observability_04.md). Preserve its partially
implemented callbacks and the frozen pre-change native evidence.

Execution status: accepted at `1ed5e34` after actual native/pas2js qualification
and [Ubuntu CI460](https://github.com/mr-highball/pythian/actions/runs/40700972559),
including maintained integration and both extracted core-only/full consumers.

Deliverable: adopt the existing primary scalar-text contract in evaluation
bindings, style distributions and cards. Preserve valid canonical native text,
byte limits, sorted identity order, histogram math, clocks and scientific gates.
Make malformed scalar rejection explicit; do not normalize caller identities.
Closing evidence: actual native/pas2js consumers, BMP/astral ordering and exact
UTF-8 byte boundaries, malformed text, original exceptions, native report parity
and published integration/extracted consumers. Stop on changed scores or exposure
semantics, host conversion, duplicated scalar logic or a separate required gap.

**Acceptance Criteria:**

- AC1: Shared evaluation bindings/distributions/cards compile and execute through
  their actual primary APIs in native Pascal and pas2js. Use `pythian.text` for
  scalar validation/order and byte limits, preserving each caller's empty/NUL
  and surrounding-ASCII-space policy. Retain valid canonical native identities.
- AC2: Checked native and actual pas2js fixtures cover ASCII, BMP/astral extremes,
  exact byte limits, malformed scalars, sorted/duplicate identities, detached
  arrays, original callback cancellation and retained output. Existing authored
  arithmetic, uncertainty and exposure controls remain unchanged and pass.
- AC3: Prior native canonical card/CLI reports remain exact. Maintained integration
  and extracted core-only/full consumers pass at the published revision. Repair
  task links/accounting together; no musical credit or invented ground truth.

**Blockers**

- [Native JSON scalar preservation](NS-6_json-text_01.md) — demonstrated real
  Linux literal and checked Windows escape paths; accepted at the same revision.
- [Shared scalar implementation — DONE](NS-6_metadata_01.md).
- [Shared callback contract — DONE](NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss acceptance: shared primary evaluation APIs execute in
  native Pascal and actual pas2js with scalar policies, byte/order boundaries,
  detached state and original exceptions preserved. Prior same-target canonical
  artifacts and CLI reports remain exact. Shared JSON prerequisite and actual
  published Ubuntu CI460/job122860363942 pass at
  `1ed5e340c061db3993ae1a32434522d04b73c62a`, including maintained integration
  and extracted core-only/full packages. AC1–3 and prerequisites pass. Move both
  tasks and repair incoming links/accounting together; retain the original
  CI459 rejection below as history. This solo engineering acceptance earns no
  musical points. Parent04 and bulk formatting remain open; delivery nonclosing
  count resets0 only on this real closure.

- 2026-10-28, Big Boss published rejection: CI459 at `31d3033` is terminal Failure
  in29s/job25s. Its actual new fixture passes operations0–3, then rejects native
  Unicode file round-trip. Original native/portable arithmetic/callback evidence
  remains valid at its scope, but does not qualify this Linux boundary. Native
  RTL source and local diagnostics expose host conversion plus a separate lossy
  escape path. Follow the linked JSON owner; no task move, credit or counter reset.

- 2026-10-28, Big Boss local qualification: checked Win32/Win64 each pass981181
  checks/208 original abort-retries/489827 callbacks, zero leaks; actual pas2js
  subset197186/98/98228. Original distribution,94 card, binding/event/clock and
  native file-bound controls pass. Prior CLI report bytes are exact on both
  targets. New mixed-tag identity and UTF-8 byte-boundary/order checks use the
  primary scalar implementation, without native test stubs. The old evaluation
  fixture's native-only FillChar/SizeOf initialization is replaced by the same
  typed default table, so its actual existing controls also execute in pas2js.
  The native JSON bridge and shared byte writer preserve supplied bytes. The
  actual adapter diagnostic changes only tags: old JSON75936 versus75914 bytes
  and file-writing conversion disagree; repaired JSON/file bytes both75914 and
  scalar comparison0. Preserve both logs. A final synchronous JSON formatting
  gap has its own [owner](../NS-6_serialization_01.md), retaining parent04 AC2.
  Exact published integration/extracted consumers remain pending; this task is
  still open, with no criterion/counter reset or musical credit claimed.

- 2026-10-28, Big Boss: scalar adoption initially left native RTL identity
  comparisons in place. An authored diagnostic shows identical seven bytes
  `EE8080F0908080` tagged0 versus65001 compare unequal through RTL equality,
  but equal through the primary scalar comparator. Replace owned binding,
  vocabulary, trait, units and denominator comparisons with that one primary
  implementation. The byte-preserving JSON round-trip also needs a byte/scalar
  test oracle, rather than a host-tag-sensitive RTL comparison. Keep both native
  diagnostic logs and the initial rejection evidence. An earlier expanded
  Unicode fixture incorrectly retained a coverage gate after dropping bins;
  repair its authored counts, not the production coverage/scoring rules.

- 2026-10-28, Big Boss: frozen source `1be04c0` fails the actual pas2js build at
  `pythian.evaluation.style.pas(38,40)`, identifier not found `UTF8String`.
  Native baseline distribution and94 card controls pass on Win32/Win64; old CLI
  reports and fixtures are retained in E-drive `style-evaluation-20261028-boss`.
  An initial JS command ran while baseline extraction was still live and found
  no input file; that orchestration log is preserved separately. The subsequent
  compiler failure occurs against the confirmed frozen source. Creating this
  owner closes no criterion and resets no nonclosing counter; entry count is0.
