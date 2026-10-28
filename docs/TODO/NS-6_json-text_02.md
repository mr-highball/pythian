# NS-6_json-text_02 — Consolidate portable JSON decoding storage

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The primary JSON string decoder still fills a pre-sized text string one character
at a time. Actual pas2js output emits `LBuffer = rtl.setCharAt(...)` inside that
loop. JavaScript strings are immutable; pre-sizing this string is not a mutable
buffer and does not establish linear storage work on long tokens. Native scalar
correctness and small portable controls do not qualify long-token cost.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. Execution status: ready, with
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

- 2026-10-28, Big Boss discovery during serialization_01: actual generated
  `jw28-js/pythian.tests.json.write.js`, line2229, assigns `LBuffer` through
  `rtl.setCharAt` per scalar-copy unit in the retained decoder. The new writer
  avoids that pattern with bounded chunks and one final join. No decoder timing
  or storage repair is claimed in this discovery. Create this linked owner and
  return to the current serialization batch. Counts become54 open/77 DONE/131
  total, NS-6 16 open;52.45% is unchanged, with no criterion or counter reset.
