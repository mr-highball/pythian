# NS-6_portability_01 — Primary analysis callbacks in a pas2js consumer

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Make the instrumented primary analysis path runnable by a real pas2js consumer.
The portable progress record works, but compiling the full progress/parity test
currently reaches older native memory primitives (`SizeOf`, `Move`, `FillChar`).
Do not describe full browser-side analysis as verified until this boundary passes.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Deliverable: one shared supported implementation and actual native/pas2js parity.
Closing evidence: the portable analysis/hash/resample/pitch callback paths execute,
including abort and large counters. Stop on copied analyzers or hidden JS algorithms.

**Acceptance Criteria:**

- Reproduce and repair primary beat/hash/WAV window portability blockers while
  preserving native output, byte interpretation, caller ownership and performance.
- Run meaningful authored parity/cancellation cases in native Pascal and pas2js;
  use a worker/cooperative scheduling adapter for responsive browser presentation.
- Document supported versus future WASM execution explicitly; a callback alone
  does not yield the browser event loop or establish WASM support.

**Blockers**

- [Shared callback contract — DONE](DONE/NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-03, Big Boss: full test compile stops at existing
  `pythian.beat.pas` histogram clearing (`SizeOf` unsupported); hash and WAV cache
  code also use native memory operations. Evidence:
  `build/observability/pas2js-progress-build.log`. The narrower
  `pythian.tests.progress.portable` passes in actual pas2js/Node, including
  counters above 32 bits and callback exceptions. No full analysis parity credit.
