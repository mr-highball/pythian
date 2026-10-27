# NS-6_binary-codec_01 — Share portable binary archive field primitives

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The retained archive audit found repeated little-endian integer assembly and
binary64 reinterpretation in the primary corpus archive, retained wave style
and semantic style codecs. WAV metadata/header helpers also repeat unsigned
little-endian field handling. Consolidate those primitives into the portable
library before extending the retained archive callbacks. Format admission,
field prefixes, schemas and musical data remain with their existing owners.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS and ONE-IMPLEMENTATION.
Completion credit: 0 additional; this preserves the existing reuse invariant.
Big Boss owns implementation and solo verification under the supplied operator
override. Deliverable: one primary byte-field implementation, finite binary64
bit conversion and real consumer adoption, deleting superseded primitive loops.
Closing evidence: checked Win32/Win64 plus actual pas2js scalar execution,
same-target prior/current archives and affected WAV consumers. Stop on changed
serialized bytes, unqualified wide-number claims, duplicated replacement logic
or a dependency edit. This is a Pythian gap, not a generic WFC gap.

**Acceptance Criteria:**

- AC1: Primary Pascal helpers read/write unsigned little-endian fields, signed
  32/64-bit fields and finite binary64 values, with explicit target bounds and
  checked byte windows. Preserve signed zero, subnormals and finite extremes;
  reject nonfinite or unrepresentable values before publishing partial writes.
  Native full Int64 support must not imply more than the browser's exact domain.
- AC2: Adopt shared primitives in corpus, retained wave and semantic archive
  codecs and the duplicated WAV metadata/header helpers. Retain each format's
  admission limits, prefixes, scalar meanings and exact bytes. Remove the
  superseded scalar algorithms rather than maintaining compatibility copies.
  PCM decoding and MIDI-specific encoding are separate primary algorithms.
- AC3: Checked Win32/Win64 and actual pas2js fixtures verify authored byte/value
  oracles, high-bit and width boundaries, signed/wide limits, finite/nonfinite
  cases, byte-window rejection, untouched surrounding data and failed writes.
  Keep host bit reinterpretation isolated inside the primary numerical boundary;
  no browser/device APIs or third-party inference runtime enters the core.
- AC4: Execute affected corpus/style/WAV consumers and compare same-target
  prior/current archives, headers and representative audio. Verify the maintained
  Ubuntu build and extracted consumers at the published revision. Do not infer
  full WFC/pas2js support, phone behavior, performance or musical acceptance
  from a scalar fixture.

**Blockers**

- None. Existing format owners retain their downstream acceptance obligations.

**Dev Notes:**

- 2026-10-27, Big Boss pre-edit evidence at `f203195`: corpus archive
  `TArchiveWriter.Number`/`TArchiveReader.Number` repeat wave-style
  `PutNumber`/`TStyleCursor.Number`; binary64 bit assembly also repeats across
  their real fields. Semantic `TStyleIO.N`/`Q` repeats signed little-endian
  assembly. WAV `ReadLE`/`PutLE` repeats unsigned field handling. The existing
  primary `pythian.ieee754` owns binary32 interpretation; extend the primary
  numerical boundary rather than putting another host cast in an adapter.
  This linked task is created before expanding
  [wave-style callbacks](NS-6_observability_07.md). It adds no scope credit and
  preserves existing investigation counters and all format-specific obligations.
