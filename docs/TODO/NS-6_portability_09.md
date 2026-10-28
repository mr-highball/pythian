# NS-6_portability_09 — Execute retained context/style archives on pas2js

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The actual portable named-voice consumer reaches retained context/style archives.
Compilation rejects context archive's transitively assumed UTF8String type;
the source also retains native Move text/digest copies. The style archive uses
native untyped stream overrides and memory access. These are executable
dependency boundaries, not covered by authored scalar tests or native archives.

Execution status: demonstrated prerequisite of
[voice observation17](NS-6_observability_17.md)'s actual portable consumer and
the full consumer gates of [UTF-8 admission07](NS-6_portability_07.md) and
[tempo codec08](NS-6_portability_08.md). Next deliverable: shared primary UTF-8
text/byte conversion and portable archive I/O using the existing stream-byte
adapter, with unchanged native formats and callback/publication contracts.
Closing evidence: actual native/pas2js archive consumers, original exceptions,
detached outputs, frozen canonical bytes, full portable named-voice consumer,
published integration and clean extracted core/full consumers. Stop on format,
model/clock/scientific-policy changes, copied codecs or another required gap.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit:0 additional.
Big Boss works solo. Keep WFC source unchanged; these are Pythian-owned codecs.

**Acceptance Criteria:**

- Reuse the primary scalar/UTF-8 implementation for canonical text/byte
  conversion on native and pas2js, preserving BMP/astral values, empty/NUL and
  byte policies without host transcoding or normalization. Returned managed
  values remain private through the final callback. Name synchronous residuals.
- Context/style archive text, digest and body byte paths use that primary
  implementation and existing stream-byte I/O. Retain current binary formats,
  budgets, canonical model text, ordering and SHA-256. Keep native and portable
  stream signatures in the adapter; remove native-only one-off memory paths.
- Actual native/pas2js consumers cover archive round-trip, malformed byte/text/
  checksum controls, copy ownership, cancellation/retry and frozen native
  artifact parity. Full portable voice construction/generation, published
  integration and extracted consumers pass before acceptance. Older native
  qualification alone establishes no portable archive execution.

**Blockers**

- [Shared primary scalar text — DONE](DONE/NS-6_metadata_01.md).
- [Primary binary fields — DONE](DONE/NS-6_binary-codec_01.md).
- [Primary byte stream adapter — DONE](DONE/NS-6_portability_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss: exact actual pas2js compile rejects context archive
  line45, identifier UTF8String. Read-only closure inspection finds native
  Move in text/digest copies and style's untyped stream override/Memory path.
  Scope this owner before any archive edits; do not extend07/08 into retained
  archives. Preserve compile failures in E-drive voice-integration-20261028-boss.
  Generic WFCc4e7569 passes all five upstream CI56 jobs, terminal24m35s,
  including actual browser13m32s and development12m18s. Downstream acceptance
  remains open. Counts56 open/82 DONE/138 total, NS6 18 open;52.45/47.55 and
  delivery entry2 remain. No stopped scientific family or operator review changes.
