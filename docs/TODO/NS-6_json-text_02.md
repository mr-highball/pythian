# NS-6_json-text_02 — Consolidate portable JSON decoding storage

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The primary JSON string decoder still fills a pre-sized text string one character
at a time. Actual pas2js output emits `LBuffer = rtl.setCharAt(...)` inside that
loop. JavaScript strings are immutable; pre-sizing this string is not a mutable
buffer and does not establish linear storage work on long tokens. Native scalar
correctness and small portable controls do not qualify long-token cost.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. Execution status: implementation under qualification, with
[shared output staging](DONE/NS-6_serialization_01.md) accepted at `ae91789`/Ubuntu CI461.
Consolidate decoded
text staging with the primary bounded buffer, retaining target-specific storage
only where required by native bytes versus immutable UTF-16 strings. Do not copy
the JSON grammar or retain a second inferior storage implementation.

Deliverable: existing `ReadJSONString` with bounded chunk storage on actual
pas2js, shared scalar validation/byte budgets, and exact existing native behavior.
Closing evidence: native and actual pas2js long literal/escaped strings, original
interior/final cancellation with retained output/cursor, prior byte parity and
measured increasing-size traces. Stop on normalization, quadratic whole-result
replacement inside the scalar loop, changed byte/source progress or a separate gap.

**Acceptance Criteria:**

- AC1: `ReadJSONString` reuses primary bounded staging instead of assigning
  individual characters into one growing immutable JS string. Native and pas2js
  retain canonical scalar/escape policies and exact UTF-8 byte limits.
- AC2: Long literal, escaped-control and BMP/astral cases retain exact output
  and cursor. Malformed/budget rejection and original callback exceptions preserve
  the caller's prior state. Callback counts remain actual source UTF-8 bytes.
- AC3: Actual portable increasing-size traces and native consumers qualify the
  changed storage path. Document allocation/final join residuals honestly; pass
  prior canonical checks and published integration/extracted consumers without
  claiming browser latency or musical acceptance.

**Blockers**

- [Primary JSON decoding — DONE](DONE/NS-6_json-text_01.md).
- [Shared output staging](DONE/NS-6_serialization_01.md) — reuse the qualified primary
  buffer rather than adding a decoder-specific chunk builder.

**Dev Notes:**

- 2026-10-28, Big Boss local qualification: `ReadJSONString` now borrows the
  primary TJSONTextBuffer for decoded staging, removing its separate growth and
  per-character copy implementation. Supply no emitted-byte observer to staging:
  the existing decoder observer still reports encoded source UTF-8 bytes only.
  Final shrink/join precedes the final source callback and caller publication;
  it remains synchronous. Native first growth uses16 units rather than4096 so
  short parsed tokens do not each allocate a page. Budget exceptions retain
  ETextValidation and now use shared text-budget wording; scalar/escape policy
  and valid bytes do not change.
  Checked Win32/Win64 each pass5859 checks/14 original abort-retries/2952 callbacks,
  zero leaks; actual pas2js5642/10/2760. Existing writer controls remain656/12/409
  per native target and174/4/92 portable. Long literal, escaped NUL, escaped astral
  and literal BMP/astral cases include byte boundaries, offset cursors, late
  malformed input and original interior/final cancellation with retained state.

- 2026-10-28, Big Boss measured frozen-source traces: actual pas2js input sizes
  1024/4096/16384/65536 scalars retain all12 original callback-count/source-byte/
  trace-digest records and exact decoded text/cursors. At65536 scalars the local
  literal case changes453ms to19ms, escaped NUL462ms to8ms, and escaped astral
  10130ms to18ms. These are single local probes, not latency bounds or musical
  results. Original source is frozen from `6610fe8` under the dedicated E-drive
  `json-read-20261028-boss` run root. Preserve the initial probe compile failure
  for an unavailable portable clock symbol; the repaired probe uses the same
  portable clock on both baseline and candidate. Published Linux and extracted
  consumers remain required; entry nonclosing1 has not reset.

- 2026-10-28, Big Boss selection after actual Studio prerequisite recheck:
  continuity_04's real-browser gate remains unavailable under explicit URL-policy
  rejection and a stale host firewall scope requiring administrator action.
  Keep that handoff pending and advance this independent core prerequisite.
  Batch AC1–3, entry nonclosing1. Reuse the qualified primary buffer, preserve
  decoder source counts and original caller cursor/output, and measure actual
  increasing-size portable inputs. Stop on normalization, copied JSON grammar,
  separate storage or another required gap. No musical credit or counter reset
  follows from selecting this task; published consumers remain required.

- 2026-10-28, Big Boss discovery during serialization_01: actual generated
  `jw28-js/pythian.tests.json.write.js`, line2229, assigns `LBuffer` through
  `rtl.setCharAt` per scalar-copy unit in the retained decoder. The new writer
  avoids that pattern with bounded chunks and one final join. No decoder timing
  or storage repair is claimed in this discovery. Create this linked owner and
  return to the current serialization batch. Counts become54 open/77 DONE/131
  total, NS-6 16 open;52.45% is unchanged, with no criterion or counter reset.
