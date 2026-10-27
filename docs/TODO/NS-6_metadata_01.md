# NS-6_metadata_01 — Share provider/context metadata primitives

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Consolidate the provider codec's private UTF-8 scalar validator with the primary
portable corpus-text implementation, and replace context archive/profile scalar
byte loops with the accepted primary binary fields. Preserve distinct caller
contracts: corpus text rejects NUL and stays within 4,096 UTF-8 bytes; caller
codec text has its declared limits, optional emptiness and existing scalar
policy. Share the algorithm without silently changing those requirements.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Execution status: ready, selected as the provider-observability prerequisite.
Big Boss owns implementation and solo verification. Deliverable: one portable
Unicode scalar validator/comparator with explicit byte/scalar policy, actual
corpus/provider adoption, and primary binary-field adoption in both context
codecs. Delete superseded scalar loops. Include optional shared callbacks for
long text validation, with actual units and original exception propagation.
Closing evidence: native/pas2js text oracles, corpus/provider consumers, malformed
boundaries and policies, abort/retry, unchanged same-target context/provider
archives and actual caller execution. Stop on encoding/normalization drift,
altered context bytes, hidden host code-page conversion or a distinct gap.

**Acceptance Criteria:**

- AC1: A single primary portable implementation validates Unicode scalars and
  canonical UTF-8 byte limits across native and pas2js; corpus comparison uses
  the same scalar traversal. Explicit empty/NUL policies retain each consumer's
  current behavior. No target-dependent normalization or host conversion.
- AC2: The actual provider codec and corpus text consumer use the shared
  implementation; context archive/profile numeric fields use `pythian.binary`.
  Remove their superseded private algorithms while retaining semantic bounds.
- AC3: Authored native/pas2js fixtures exercise scalar extremes, malformed data,
  exact byte limits, policy distinctions, callback abort and retry. Checked
  Win32/Win64 actual context/provider consumers preserve same-target canonical
  bytes and caller behavior, with zero leaks. Published clean integration and
  extracted consumers pass. This earns no musical credit.

**Blockers**

- [Primary binary fields — DONE](DONE/NS-6_binary-codec_01.md).
- [Shared text portability — DONE](DONE/NS-6_portability_02.md).
- [Shared progress contract — DONE](DONE/NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss: provider audit before task04 edits found a second UTF-8
  decoder in `pythian.wfc.provider.codecs.CheckText`, and private UInt32 loops
  in context profile/archive code. The current corpus validator already owns
  target-aware scalar traversal but has a narrower NUL/byte policy. Stop
  extending duplicate implementations and extract the shared primitive first;
  preserve the differing contracts explicitly. This is Pythian-owned, with no
  demonstrated generic WFC defect. Original provider, context, batch and operator
  observability obligations remain with task04; adding this prerequisite grants
  no credit and resets no batch or scientific counter.
