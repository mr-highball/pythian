# Long-operation observability

[Project](../PROJECT.md) · [Assessment](CODEBASE-ASSESSMENT.md) ·
[Tasks](TODO/README.md) · [Work](WORK.md)

Big Boss, 2026-10-03. The learning-progress lesson applies to the reusable
library as well as Studio: callers need real work counts, named phases and
cancellation checkpoints. This audit adds a shared contract and instruments
the paths below. It does **not** certify that every bulk operation is observable.

## Scope and findings

The static inventory covers 262 owned Pascal files: 101 core units, 40 WFC
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
| Browser-side primary analysis | Shared callback record works in pas2js; full analysis test encounters older native memory primitives | [portability_01](TODO/NS-6_portability_01.md); no full browser/WASM analysis claim |

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
or cooperative scheduling adapter. Current browser tests execute the shared
record, large counters and exception contract, plus the existing shared WAV
codec. The full analysis test stops at pre-existing `SizeOf` use in beat histogram
clearing; hash/WAV cache paths also use native memory operations. The tracked
portability task owns primary-code fixes and actual cross-target parity.

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
and the full browser analysis boundary remain explicitly open. Observability
repairs earn no additional north-star credit.
