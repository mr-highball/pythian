# NS-6_portability_01 — Primary analysis callbacks in a pas2js consumer

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Make the instrumented primary analysis path runnable by a real pas2js consumer.
The portable progress record works, but compiling the full progress/parity test
currently reaches older native memory primitives (`SizeOf`, `Move`, `FillChar`).
Do not describe full browser-side analysis as verified until this boundary passes.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Deliverable: one shared supported implementation and actual native/pas2js parity.
Closing evidence: the portable analysis/hash/resample/pitch callback paths execute,
including abort and large counters. Stop on copied analyzers or hidden JS algorithms.

Accepted 2026-10-27 at the native/pas2js execution boundary. The shared primary
hash, WAV decoding/cache, FFT and full callback consumer execute under checked
FPC and actual pas2js/Node. A separate pas2js timer adapter delegates bounded
batches to `AnalyzeWaveBatch`, yielding between turns without copying its engine.
Caller ownership, byte interpretation, cancellation and publication failures are
covered. Actual visual browser performance, browser file APIs and future WASM
are not qualified by this result; other bulk APIs still need host scheduling.

**Acceptance Criteria:**

- Reproduce and repair primary beat/hash/WAV window portability blockers while
  preserving native output, byte interpretation, caller ownership and performance.
- Run meaningful authored parity/cancellation cases in native Pascal and pas2js;
  use a worker/cooperative scheduling adapter for responsive browser presentation.
- Document supported versus future WASM execution explicitly; a callback alone
  does not yield the browser event loop or establish WASM support.

**Blockers**

- [Shared callback contract — DONE](NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-03, Big Boss: full test compile stops at existing
  `pythian.beat.pas` histogram clearing (`SizeOf` unsupported); hash and WAV cache
  code also use native memory operations. Evidence:
  `build/observability/pas2js-progress-build.log`. The narrower
  `pythian.tests.progress.portable` passes in actual pas2js/Node, including
  counters above 32 bits and callback exceptions. No full analysis parity credit.
- 2026-10-27, Big Boss: preserved that reproduction and repaired the primary
  implementation, rather than adding a browser analyzer. Spiegel owns shared
  hash/stream byte representation; Spike owns WAV reader/writer portability and
  authored cross-target analysis fixtures. Big Boss owns integration, finite
  binary32 interpretation, FFT variable identity, typed cache copies, primary
  corpus text reuse and the cooperative host adapter. Reachable `MaxSingle` and
  native-only text dependencies were exposed by actual compilation and repaired
  with shared scalar/text contracts. Unsupported filename I/O explicitly rejects
  in pas2js; callers supply bytes/streams. Other native units are not implicitly
  qualified for pas2js.
- Native Win32/Win64 and actual pas2js hash/stream/scalar/WAV checks pass within
  their recorded target scopes. The checked Win64 full callback suite and actual
  pas2js suite each pass 385 checks, including abort and unchanged results with
  an observer. Binary32 interpretation passes 14,055 bit/oracle cases on each
  target; the WAV reader fixture passes 55, separate from preserved PCM/RF64
  encoder coverage. The initial integration reused an existing encoder-test
  filename; Big Boss restored that test and kept reader checks in their own new
  fixture. No accepted coverage was discarded.
- The 257-check authored analysis fixture preserves exact PCM/hash geometry,
  all feature fields, overlap and source clock; its maintained native comparator
  checks eight actual native/pas2js rows at the predeclared `1e-6` scaled tolerance.
  Maximum observed feature difference was `8.099e-9`. Fourier same-variable
  rejection preserves input; distinct variables may share their original array.
  Native float32 WAV decoding median was 234 ms before and after, over three
  alternating runs of 16,777,216 authored frames with exact checksum; the
  prospective 1.25 ratio limit passes. This is local throughput evidence, not
  universal latency. Whole WAV-analysis/cache medians were 531/532 ms before/after
  across three alternating 2,097,152-frame runs, retaining the RMS/centroid sum.
  Scoped hash timing also found no observed native regression.
- Spike and Spiegel independently executed the other's components and Big Boss's
  scalar/FFT/cache/wrapper paths after components were ready. Spiegel's first
  adapter QA found terminal callback exceptions left a completed state; Big Boss
  repaired failure-state recording and rethrow without duplicate notification.
  Independent timer/reader/publication/cancellation probes verify the repair.
  This is one repaired implementation QA finding, distinct from scientific
  rejection. Native checked runs report zero leaks. Node host startup propagates
  Pascal runtime exit status; assertions/algorithms stay Pascal-owned.
- Maintained checks: `tools/check-analysis-portability.ps1`, with explicit output
  root and matching pas2js compiler/RTL. New native fixtures are also registered
  in `tools/build.ps1`. Evidence stays under E-drive `runs/analysis-portability-20261027*`
  and matching build/tests roots. No private media, live operator response,
  deployed service, browser session or dependency source changed. No musical
  acceptance or WASM/browser-visual claim follows. See
  [observability](../../OBSERVABILITY.md#pas2js-analysis-execution).
