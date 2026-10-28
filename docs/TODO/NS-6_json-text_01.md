# NS-6_json-text_01 — Preserve scalar identities through native JSON

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The real Linux CI459 consumer loses valid native Unicode JSON values. Installed
FPC3.2.2's reader converts UTF-8 through its host Unicode manager; its scanner's
Unicode-escape path also loses valid escaped BMP/astral text in an actual checked
Windows control. Initializing Unix conversion support alone cannot qualify both
paths. Do not weaken the fixture, mutate global conversion settings per call,
edit RTL sources or copy a second JSON grammar into Pythian.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. This is a demonstrated prerequisite of
[evaluation portability_06](NS-6_portability_06.md) and retained metadata work in
[task04](NS-6_observability_04.md). Preserve partial callbacks and all failures.

Deliverable: one primary portable JSON string decoder reusing `pythian.text`
scalar traversal/encoding. Native adapters frame string tokens through an ASCII
representation and restore the decoded bytes through RTL parser extension points;
the existing strict RTL parser still owns structural/numeric grammar. Consolidate
the maintained native JSON readers into this shared boundary. Preserve each
caller's byte/depth limits, duplicate-field policy, numeric values and ownership.

Closing evidence: native/pas2js scalar decoding, literal/escaped BMP/astral and
control cases, malformed scalars/escapes, retained output/cursor on original
callback abort, actual native consumers, prior bytes, Linux integration/extracted
consumers and resource cleanup. Stop on normalization, partial publication,
invented progress, altered scientific semantics or a distinct required gap.

Execution status: implementation under qualification. The primary portable
`pythian.json.text` reuses scalar traversal and encoding; native
`pythian.tools.json` restores decoded strings through the RTL key/value hooks.
The shared reader deliberately rejects previously tolerated invalid JSON in
legacy lenient readers. Valid numeric parsing remains RTL-owned. Input byte,
depth and container limits remain caller-owned; ASCII framing is at most six
times source bytes and cannot exceed the native string ceiling. Existing
unbounded-depth readers gain no invented depth policy. RTL structure parsing
remains synchronous between explicit endpoints; final formatting remains in
[serialization_01](NS-6_serialization_01.md).

**Acceptance Criteria:**

- AC1: Primary Pascal JSON string decoding preserves valid scalar values and
  UTF-8 byte limits on native and pas2js. Reuse the existing primary scalar
  implementation. Reject raw controls, malformed bytes/surrogates/escapes and
  incomplete strings; do not silently replace or drop them.
- AC2: One native reader delegates grammar/numbers to the existing strict RTL
  parser while preserving decoded keys/values independently of host code-page
  conversion. Adopt maintained readers, removing their duplicated pre-scan/parser
  preparation. Keep caller-specific limits and schema checks in their owners.
- AC3: Borrowed callbacks report actual source work. Interior/final original
  exceptions preserve caller result/cursor and free staged JSON. Actual native,
  pas2js and maintained consumers retain valid prior canonical outputs; clean
  published Linux integration and extracted core-only/full packages pass.

**Blockers**

- [Shared scalar implementation — DONE](DONE/NS-6_metadata_01.md).
- [Shared progress contract — DONE](DONE/NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss complete local consumers: all maintained native build
  commands pass across the preserved prefix and explicit continuations. Local
  extracted core/full packages pass107/158 owned units and120/277 inventory
  entries. Windows MAX_PATH and the comparator's cwd-relative build guard are
  repaired through shorter E output/cwd choices only; its133 synthetic assertions
  pass. No recorded-reference calibration, live service or private answers change.
  Exact source publication and actual Linux qualification remain required.

- 2026-10-28, Big Boss consumer repair: the broad native build exposes one
  former GetJSON stream overload in `pythian.part.prepare`. Retain its open,
  already hashed, write-denied stream and existing1MiB limit; read its bytes
  into raw text for the shared reader, without reopening the source or adding
  a second parser. Resume compilation and controls from that failed boundary.

- 2026-10-28, Big Boss local qualification: checked Win32/Win64 JSON fixtures
  each pass357 checks/6 original abort-retries/269 callbacks, zero leaks. Actual
  pas2js passes141/2/77. A separate default-manager diagnostic also passes;
  it is not actual Linux evidence. The actual Win64 style consumer now passes
  2923146 checks/210 original abort-retries/1460801 callbacks, zero leaks.
  Thirteen frozen native artifacts and the CLI report remain byte-exact. The
  initial test used a reserved Pascal unit suffix; rename it to `json.text`.
  Its Win32 float oracle needed a typed Double constant to match the existing
  RTL numeric API; production numeric parsing was not changed. Preserve logs.
  Full maintained-consumer and published qualification remain pending.

- 2026-10-28, Big Boss: CI459 fails at `31d3033` in native scalar file round-trip,
  after operations0–3 pass. Local RTL-default-manager diagnostics reproduce loss.
  A raw-token parser override repairs literals but not escapes; its scanner token
  is already changed. The added actual Windows escaped-key/value control also
  fails with its normal manager. Preserve logs under E-drive
  `style-json-20261028-boss`. Discard the unqualified cwstring-only approach.
  Previous batch is nonclosing1. This required reassessment selects a shared
  scalar boundary before more formatting work; the new owner resets no counter
  or credit and does not reopen a stopped scientific family.
