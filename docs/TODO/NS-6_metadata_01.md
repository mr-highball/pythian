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
Execution status: local qualification passed; published integration and extracted
consumers remain pending. Selected as the provider-observability prerequisite.
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

- 2026-10-27, Big Boss local qualification: `pythian.text` owns the extracted
  scalar traversal, explicit UTF-8 byte/empty/NUL policies and scalar ordering.
  Native `RawByteString` preserves caller byte identities regardless of code-page
  tag; pas2js traverses UTF-16 scalars and measures canonical UTF-8 bytes. No
  normalization is introduced. Corpus delegates with its existing NUL/4096-byte
  contract; provider delegates with its existing configured limits/NUL policy.
  Both context codecs use primary UInt32 fields with their semantic bounds.
  Deleted duplicate algorithms; no companion source change or generic WFC gap.
  Checked native targets each pass 73 authored primary checks; actual pas2js
  passes 65 representation-appropriate checks. Interior validation/comparison
  aborts retain the original exception and permit retry. Actual native provider
  runs each pass 231 checks, including UTF-8 byte limits, NUL/empty distinctions
  and rejection before caller dispatch. Corpus text/intake/adversarial consumers
  pass on actual pas2js; native corpus/context/provider consumers have zero leaks.
  All 12 same-target prior artifacts match on checked Win32 and Win64: context
  learning/profile, derived/reblended caller styles and WAVs, harmonic controls,
  and the actual caller example's style/authored/generated WAVs. Frozen four-unit
  blobs match `7da8569`; compiler logs prove those exact prior paths were used.
  The new fixture is registered in native integration and analysis portability;
  package closure discovers every primary unit. Ubuntu/extracted acceptance is
  still required before moving this task. Evidence and orchestration are under
  `E:/CodexWork/pythian/{build,tests,runs}/metadata-reuse-20261027-boss*`, including
  `VALIDATION.json`, prior source/consumer logs and `prior-artifact-parity.json`.
- 2026-10-27, Big Boss repaired issues: the first extraction changed the corpus
  facade's promised error message; its existing regression rejected that change.
  Restore the exact facade message while delegating the traversal. Initial failed
  log and repaired run remain in the evidence root. The source-proof wrapper
  also initially compared slash styles incorrectly; retain the successful prior
  Win32 results and normalize only log path separators. No product failure or
  rerun is concealed. Single-agent checks are solo evidence, not independent QA.
  Current staffing documentation now matches the user's supplied solo override.
  No recordings, responses, service slots or stopped scientific families change.
- 2026-10-27, Big Boss: provider audit before task04 edits found a second UTF-8
  decoder in `pythian.wfc.provider.codecs.CheckText`, and private UInt32 loops
  in context profile/archive code. The current corpus validator already owns
  target-aware scalar traversal but has a narrower NUL/byte policy. Stop
  extending duplicate implementations and extract the shared primitive first;
  preserve the differing contracts explicitly. This is Pythian-owned, with no
  demonstrated generic WFC defect. Original provider, context, batch and operator
  observability obligations remain with task04; adding this prerequisite grants
  no credit and resets no batch or scientific counter.
