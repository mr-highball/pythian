# NS-6_portability_12 — Execute primary journal consumers on pas2js

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Actual compilation of the shared selection callback consumer stops at the
primary journal's native-only UTF8String group ID. Inspection also finds raw
native Move/WriteBuffer assumptions in the primary feature-journal codec and
vocabulary/model binding hash consumer. Reuse the existing primary text, binary,
IEEE754 and stream-byte implementations, preserving native current-format bytes.
Do not add a parallel browser journal, codec or digest implementation.

Execution status: local native32/64 and actual pas2js gates pass; clean extracted
and exact published integration remain. Prerequisite to [selection19](NS-6_observability_19.md).
Next deliverable: the actual primary journal/selection consumer executes on
native32/64 and pas2js with matching canonical bytes, group identity and binding.
Closing evidence and stop condition: freeze native journal/binding bytes before
editing; run independent Unicode/byte-boundary/group-isolation and codec-failure
controls plus original consumers. Stop on accepted native byte or cohort drift.
Primary attribution: NS-6; secondary inference/selection use earns no extra credit.
North star: NS-6. Outcome owner: independently reusable portable library.
Completion credit: 0 goal percentage points (0.00 overall points).
Credit is earned only when every acceptance criterion and task-flow completion requirement passes.

**Acceptance Criteria:**

- Journal group IDs use the shared scalar-text contract and the same1..256
  canonical UTF-8 byte bound on every target. Preserve exact identities without
  normalization and native outer-ASCII-whitespace behavior; reject malformed
  text/NUL, leaked or disguised source groups and invalid partition admission.
  Do not use the browser host's broader Trim whitespace convention.
- Primary feature-journal and binding codecs/hash consumers use shared portable
  byte/scalar operations. Retain all frozen native header/record/chain and
  vocabulary/model binding bytes/digests without introducing another format.
  Malformed/truncated/corrupt inputs and failed publication preserve their
  documented state and caller-output behavior.
  Keep the successor's existing native layout estimate explicitly named as a
  native payload metric; do not invent a JavaScript heap size. Its scalar
  selection/indexing behavior remains portable independently of that metric.
- Run original meaningful native journal consumers, explicit canonical byte/
  Unicode/partition/binding controls, and the actual primary shared selection
  callback consumer on checked native32/64 and actual pas2js. Retain all failure
  evidence, boundaries, ownership, replay and native leak results.
- Qualify the public portable path from clean extracted core sources and exact
  published maintained integration. No browser UI, WASM, musical inference or
  additional musical credit follows from portable execution.

**Blockers**

- [Shared binary fields — DONE](DONE/NS-6_binary-codec_01.md)
- [Shared metadata/scalar text — DONE](DONE/NS-6_metadata_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: all three targets pass384 canonical journal/group/binding
  checks,38 stream-byte boundary/failure checks and362071 actual selector checks.
  Original native journal/learning/successor/profile consumers pass, zero leaks.
  Frozen1668-byte journal snapshots and vocabulary/model digests remain exact.
  TCorpusText preserves the original native UTF8String field and canonical scalar
  identity; using a raw-string alias first lost Unicode through native code-page
  composition. Shared exact transfers accumulate short positives, matching the
  verified native RTL; the first single-transfer assumption was incorrect and
  repaired before qualification. Signed-zero journal bytes and semantic binding
  zero canonicalization retain their different original contracts.
- 2026-10-29, Big Boss: the vocabulary fixture supplies frozen pre-change native
  parameter bytes for its RMS/centroid components. Native Math.Min/Max overloads
  quantize these components differently from pas2js; hashing different inputs
  cannot establish codec parity. All original digest expectations remain, and
  the feature transform is unchanged. These checks prove equal given parameters
  bind identically, not exact cross-target feature transformation. A nested
  constant-array compiler crash was repaired by flattening the same64 bytes;
  explicit unsafe-integer and native-layout metric fixtures required Pascal
  expression corrections before actual portable execution. Private failures and
  raw logs are retained. No inference, browser UI or musical acceptance follows.

- 2026-10-29, Big Boss: selection19's actual pas2js compile rejects UTF8String
  at primary learning journal line60. The verified pas2js RTL Trim strips
  broader Unicode whitespace than native Trim, so a conditional string alias
  alone would not preserve group identity/admission. Raw feature-journal
  floating/string buffers and binding hash writes also require primary portable
  codec reuse. Native selection and actual audio-session gates already pass;
  this failure is retained rather than hidden behind a compile-only browser claim.
