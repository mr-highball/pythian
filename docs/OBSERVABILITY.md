# Long-operation observability

[Project](../PROJECT.md) · [Assessment](CODEBASE-ASSESSMENT.md) ·
[Tasks](TODO/README.md) · [Work](WORK.md)

Big Boss, 2026-10-03. The learning-progress lesson applies to the reusable
library as well as Studio: callers need real work counts, named phases and
cancellation checkpoints. This audit adds a shared contract and instruments
the paths below. It does **not** certify that every bulk operation is observable.

## Scope and findings

The 2026-10-03 static inventory covered 262 owned Pascal files: 101 core units, 40 WFC
adapters, five inference adapters and 116 tools/browser units or programs.
It excludes tests, generated output and dependency source. Loop/callback counts
in `build/observability/inventory.csv` guide inspection; they are not measured
runtime coverage. Manual review followed public bulk entry points and their
Studio callers, plus existing streaming, inference and library contracts.

| Boundary | Current behavior | Evidence or remaining owner |
| --- | --- | --- |
| Primary SHA-256 bytes/stream | Optional measured bytes, checkpoints every 8 KiB, final callback after digest calculation | Known-answer/stream tests and abort before EOF |
| Shared clip/source/range/band/WAV analysis | Optional emitted-window counts every 16 windows; one context FFT remains outside returned-window count | Existing exact range/band parity; callback output/abort checks |
| Resampling | Output frames every 1,024 frames; equal-rate detached copy has start/end callbacks | Every output sample agrees; abort returns no partial clip |
| Pitch tracking | Analysis windows every 16 estimates, final callback after span construction | Pitch/note parity and mid-operation abort |
| Onset/beat measurement | Candidate onsets every eight, tempo trials every eight; shared WAV pipeline forwards the callback | Authored beat pipeline parity; no-evidence inputs may skip the beat stage |
| Acoustic learning | Feature preparation, counted reader passes, encoding and representative selection; journal reader shares the same record | Weighted journal/palette/WFC parity and callback abort tests |
| In-memory corpus training | Forwards into primary analysis, palette learning and token encoding | Shared implementation; retained archive/intake work remains below |
| Studio learning/generation | Source bytes, analysis windows, learning passes, generated frames; cache reuse and final publication are explicit | Accepted [learning-progress batch](TODO/DONE/NS-6_studio_20.md) and real worker checks |
| Studio source/capture inspection and pitch exploration | Shared hash, volume, onset/beat, resample and pitch counts, shown by the common progress component | Native capture checks and authored browser runs; short stages can finish between UI polls |
| Studio effects | Selected audio plus tail frames, hash bytes and derived-copy bytes; common progress display | Native effects parity/cancellation checks and browser completion/cancel paths |
| Library discovery/preparation | Existing byte/item callbacks, cancellation, staged publication and throttling retained | Inner catalog import still needs [observability_02](TODO/NS-6_observability_02.md) |
| Streaming synthesis/WFC audio | Existing bounded pull, frame clocks, state and cancellation retained | A caller can observe each block; bulk helpers are a separate gap |
| Pascal inference | Existing observation checkpoints, budgets, cancellation and deadlines retained | Reconcile remaining operator phases in [observability_04](TODO/NS-6_observability_04.md); no third-party execution |
| Catalog import and verification | Outer phase can remain indeterminate during nested hashes/copies; per-file exception handling needs careful abort propagation | [observability_02](TODO/NS-6_observability_02.md) |
| Offline render, separation, export and evaluation | Whole-clip work can remain silent; separation admits up to two billion planned visits | [observability_03](TODO/NS-6_observability_03.md) |
| Retained corpus/style/archive/provider operations | Nested serialization, validation, blending and composition reachability need further measured checkpoints | [observability_04](TODO/NS-6_observability_04.md) |
| Primary analysis in pas2js | Full callback consumer executes shared primary algorithms; optional timer adapter yields between bounded WAV analysis batches | [portability_01 — DONE](TODO/DONE/NS-6_portability_01.md); actual browser presentation and WASM remain unqualified |

Per-sample oscillators, filters and small fixed transforms should not publish a
callback per sample. Observe their caller's bounded render block instead. Static
admission limits alone do not establish acceptable latency: remaining bulk paths
must either gain checkpoints or provide measured evidence for their bound.
There is no demonstrated generic WFC defect from this audit. Companion source
was not changed; any such finding follows the separate-repository procedure.

## Shared callback contract

[`pythian.progress`](../src/pythian.progress.pas) defines `TWorkProgress`:
`Stage`, `Done`, `Total`, `Units` (items/bytes/frames/observations), and `Pass`.
Bulk APIs accept an optional `TWorkProgressCallback` as a trailing argument.
`nil` preserves the same computation without an observer. Labels belong to the
presentation adapter; stage identifiers belong to the operation.

- Calls are synchronous and borrowed. The callback must not re-enter the
  operation or mutate its inputs. Keep it cheap.
- Raise an exception to abort. Instrumented operations propagate it and release
  local resources; a borrowed input stream may already have advanced. An aborted
  journal reader is poisoned and must be reopened. Retrying is a caller decision.
- Counts describe the **current stage/pass**, not overall completion. A new
  pass or input may restart counts. `Total = 0` means unknown or empty and must
  never become a percentage. During discovery `Done` may increase while total
  remains unknown. Studio normalizes that case to its indeterminate job state.
- A full stage bar does not mean durable publication succeeded. Only the host's
  terminal completed state establishes success. Failed/cancelled states remove
  the running bar; reused learning explicitly skips analysis and learning.
- The core owns no clock, thread, UI, device or browser API. Hosts schedule work,
  choose publication frequency and maintain their own cancellation flag. Studio
  checks deadlines at every checkpoint and polls disk-backed cancellation at most
  once per 100 ms, with an unconditional check before completion. Repeated
  same-stage/pass publication is throttled to 500 ms; boundaries publish immediately.

For example, a caller-owned observer can forward measurements and stop a scan:

```pascal
procedure TMyHost.OnWork(const AWork: TWorkProgress);
begin
  if FStopRequested then
    raise EMyCancelled.Create('Cancelled');
  PublishProgress(AWork); // caller-owned status/UI adapter
end;

Digest := Sha256Stream(Input, BytesToRead, Host.OnWork);
Features := AnalyzeAudio(Clip, Options, Host.OnWork);
```

A callback does not yield a browser event loop. Long pas2js work needs a worker
or cooperative scheduling adapter. The shared primary analysis consumer now
executes under actual pas2js/Node, including hash, WAV, resampling, pitch,
learning, beat measurement and abort paths. The host adapter below yields WAV
analysis batches; this does not make every synchronous bulk API asynchronous.

## pas2js analysis execution

Accepted 2026-10-27: [the primary portability repair](TODO/DONE/NS-6_portability_01.md)
removes reachable native memory/text assumptions while retaining one primary
algorithm. Native and pas2js share finite IEEE-754 binary32 interpretation, WAV
decoding/window analysis, FFT and SHA-256 compression. The shared stream byte
adapter handles only physical stream representation; native fast byte copies
and unsigned word arithmetic remain at their representation boundary. SHA stream
counts reject above `2^53-1` in pas2js and `2^61-1` natively. Large-counter checks
do not imply that a huge stream was traversed.

[`TCooperativeWaveAnalysis`](../adapters/pas2js/pythian.analysis.cooperative.pas)
is an optional pas2js host adapter. It calls primary `AnalyzeWaveBatch` for
1..64 features per timer turn, retaining no whole-recording feature array. Its
batch callback receives original-source coordinates and completion metadata;
the cursor advances only after that callback succeeds. Keep the reader/source
immutable and alive until terminal notification or destruction. A host can
stage its own journal and publish it only after completion. Saving/staging a
batch is not proof of durable overall publication.

`Start` defers the first read; unrelated timers run between turns. `Cancel` is
observed before the next batch and may also be called from a batch callback.
Batch or reader failure ends the job. A terminal callback exception records
failure and propagates to the host without a second notification. Destroying
the adapter clears its pending timer; defer destruction until outside callbacks.
Choose a small batch for the device. An individual FFT batch is synchronous,
and there is no promised millisecond bound. This adapter does not survive page
suspension or replace Studio's durable native jobs.

The maintained [cross-target check](../tools/check-analysis-portability.ps1)
accepts explicit native/pas2js compiler paths, matching RTL source/JavaScript and
an output root. It runs the same primary fixtures on both targets, executes
the timer adapter in Node, and invokes a Pascal comparator over the emitted
feature rows. The full callback suite passes 385 checks per target; authored
analysis passes 257 per target, with eight compared rows at the predeclared
`1e-6 * max(1, abs(left), abs(right))` tolerance. Maximum observed difference is
`8.099e-9`. Exact PCM/hash contracts, Fourier alias preservation and 14,055
finite binary32/oracle checks are separate from that floating tolerance.
The cooperative fixture passes 345 scheduling/cancel/failure/publication checks.
The original encoder/RF64 fixture remains alongside the new reader fixture.

Local optimized native float32 WAV decoding took a median 234 ms both before
and after across three alternating runs of 16,777,216 authored frames; exact
checksums agree and the prospective 1.25 time-ratio limit passes. Whole WAV
analysis/cache medians were 531 ms before and 532 ms after across three
alternating 2,097,152-frame runs, retaining the emitted RMS/centroid sum. Scoped
native hash timing also showed no observed regression. These are local throughput
checks, not universal latency or browser performance guarantees. Checked native
fixtures and independently authored adversarial probes report zero leaks.
Evidence is retained under E-drive `build/tests/runs/analysis-portability-20261027*`.

This qualifies actual pas2js execution and timer scheduling, not visual browser
presentation, physical-phone performance or WASM. Filename-based WAV I/O is
native-only; pas2js callers supply bytes or streams. Other native units and
inference runtimes are not implicitly qualified. Future WASM requires its own
compiler, host I/O and execution evidence. Actual Studio browser qualification
remains with the existing [continuity](TODO/NS-5_continuity_04.md) and
[listening-comparison](TODO/NS-6_studio_22.md) tasks.

## Validation and limits

The current native callback suite has 385 checks, including identical hashes,
resampled samples, analysis features, pitch estimates, learned centers and abort
cleanup. Existing hash, WAV analysis, weighted journal/WFC tests also pass, as do
164 real Studio worker checks, 130 effects checks and 53 capture checks. The
shared callback contract passes actual pas2js/Node execution with counters above
32 bits, unknown totals, invalid bounds and callback exceptions. Build logs and
authored browser traces are under ignored `build/observability/`.

These checks establish mechanics and output preservation, not musical truth,
complete physical-phone qualification or universal responsiveness. A short job
can finish between browser polls. Imports, offline DSP, retained style operations
and actual browser presentation remain explicitly open. Observability
repairs earn no additional north-star credit.
