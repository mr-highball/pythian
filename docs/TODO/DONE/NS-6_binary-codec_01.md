# NS-6_binary-codec_01 — Share portable binary archive field primitives

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

The retained archive audit found repeated little-endian integer assembly and
binary64 reinterpretation in the primary corpus archive, retained wave style
and semantic style codecs. WAV metadata/header helpers also repeat unsigned
little-endian field handling. Consolidate those primitives into the portable
library before extending the retained archive callbacks. Format admission,
field prefixes, schemas and musical data remain with their existing owners.

Accepted 2026-10-27 at `f973df7`: native/pas2js scalar and actual format evidence
below is joined by successful Ubuntu
[run450](https://github.com/mr-highball/pythian/actions/runs/40581158188).
Maintained integration and both extracted core/WFC consumers pass at the
published revision. Big Boss performed solo checks; CI is not independent code
review. No additional musical credit or new target scope is implied.

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

- 2026-10-27, Big Boss acceptance: actual Ubuntu run450/job122460574595 is
  terminal Success at `f973df7`, total11m58s/job11m55s. Maintained integration
  and both extracted consumers pass. Retained artifact containers are
  `native-fpc-logs` (746 KB, SHA256 `c279180d3bfb9ecda540e2c9489761fd04d3661f8d38da9494203318b2029378`)
  and `pythian-source-packages` (1.67 MB, SHA256 `04a2f1bf810744082bbf720552e31cd2f1acb0d076d46001702343ab2cdc5893`).
  These are GitHub container digests, not individual source ZIP hashes. This
  closes AC4 alongside the local AC1–3 evidence. Earlier pending statements
  below record intermediate checkpoints. Full retained-profile observation
  remains with its linked owner; no phone/WASM or musical gate closes here.
- 2026-10-27, Big Boss local qualification: checked Win32/Win64 each pass
  33,071 scalar assertions; actual pas2js passes 33,113, including its additional
  unsafe-integer rejection cases. This includes 16,376 selected finite binary64
  patterns and authored value/endian/boundary oracles, not exhaustive 64-bit
  coverage. Native WAV reading/streaming, passage metadata, corpus archive and
  semantic source/blend consumers pass with zero leaks. Actual pas2js PCM/RF64
  headers and the 55-case frame-reader fixture pass; the existing 14,055-case
  binary portability fixture also passed at the unchanged IEEE32 boundary.
  Immediate-prior `6b14cb7` consumer sources were separately compiled on each
  native target. All 24 corpus/style/audio files match byte-for-byte; no
  cross-target PCM or full WFC/pas2js qualification is inferred.
  Three alternating large-corpus timings per version/target meet the predeclared
  1.25 ratio: Win64 medians 11,311/11,432 ms prior/current (1.01); Win32
  12,354/11,977 ms (0.97). The initial generic-field version passed but measured
  1.12/1.21 ratios; it is preserved as `performance-general-fields.json`.
  The canonical UInt32 specialization removes that avoidable field cost; bounded
  variable-width calls delegate to it for width four. No format adapter retains
  the superseded primitive loops. A typed-constant default-argument compile
  error was repaired with a true constant; its native/pas2js logs are retained.
  Evidence is under E-drive `build/tests/runs/binary-codec-20261027-boss*`.
  Published Ubuntu integration/extracted consumers remain required for AC4;
  the task remains open without additional milestone credit.
- 2026-10-27, Big Boss implementation: shared scalar helpers and a primary
  finite binary64 bit boundary replace the archive and WAV header/loop primitives.
  A bounded try-reader also preserves the frame reader's RF64 overflow sentinel
  without duplicating its byte assembly. Scalar authored oracles, finite pattern
  coverage and failed-write boundaries pass on checked native and actual
  pas2js; the browser's unsafe signed64 input is rejected explicitly. Earlier
  fixture construction used signed JavaScript bitwise results for a Cardinal
  high word; its corrected arithmetic construction and original failed log are
  preserved. Explicit pas2js numeric conversions and an untypable unsafe fixture
  literal were also repaired. No format schema or inference policy changed.
  The immediate-prior comparison initially matches all 24 corpus/style/audio
  files per native target; rerun changed paths after the final bounded-reader
  consolidation before qualification. Prospective runtime check: three
  alternating executions of the same 65,536-feature corpus consumer per target,
  using the median current/prior ratio and a 1.25 stop threshold. This is a local
  regression check, not a universal performance or cancellation-latency claim.
- 2026-10-27, Big Boss pre-edit evidence at `f203195`: corpus archive
  `TArchiveWriter.Number`/`TArchiveReader.Number` repeat wave-style
  `PutNumber`/`TStyleCursor.Number`; binary64 bit assembly also repeats across
  their real fields. Semantic `TStyleIO.N`/`Q` repeats signed little-endian
  assembly. WAV `ReadLE`/`PutLE` repeats unsigned field handling. The existing
  primary `pythian.ieee754` owns binary32 interpretation; extend the primary
  numerical boundary rather than putting another host cast in an adapter.
  This linked task is created before expanding
  [wave-style callbacks](../NS-6_observability_07.md). It adds no scope credit and
  preserves existing investigation counters and all format-specific obligations.
