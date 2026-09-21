# Optional native pitch observations

[Project](../PROJECT.md) · [Phrase evaluation](PHRASE-EVALUATION.md) ·
[Provenance](PROVENANCE.md) · [Task](TODO/DONE/NS-3_validation_02.md)

## Scope and admission boundary

The optional Win64 adapter executes the pinned CREPE tiny converted model through
TensorFlow 2.18.1 CPU's C API. Pascal owns graph assembly, source preparation,
identity checks, streaming, artifacts, process supervision and command-line tools.
The portable core and WFC have no runtime dependency. This is checkout-only
functionality: ordinary core builds, CI and extracted core/WFC packages do not
acquire or include these optional assets.

This Win64 qualification does not narrow the final native delivery matrix. Any
producer required by the final accepted workflow must also run on every target
declared by the [consumer contract](CONSUMER-CONTRACT.md), under the existing
[final-workflow delivery task](TODO/NS-6_delivery_03.md). This adapter alone does
not close that delivery requirement.

Each observation contains an exact 16-kHz source-clock center, input AC RMS and
all 360 float32 salience values. These are **raw measurements**, not calibrated
probabilities, admitted notes/rests, event boundaries, roles or learned providers.
The earlier fixed frame-admission policy remains rejected. A subsequent provider
must establish its own recorded accuracy, unknown handling and final execution
cost. The maintained YIN estimator is unchanged; the roughly 17 processing-seconds
per audio-second comparison concerns the earlier private scalar model study.

The first qualification passed the contract checks, twelve numerical controls,
all six short rate/channel cases, both retained recorded comparisons and the
five-minute preparation/resource case. The continuous-hour attempt failed near
the thirty-second boundary without publishing an artifact. Its original generic
timeout did not retain a phase, so setup remains a hypothesis rather than a
proven cause. The repaired initialization path now passes focused requalification
and the single second hour run. All execution-task criteria are accepted within
the scope below; provider accuracy and corpus-scale acceptance remain separate.

## Assets and build

Use the opt-in [asset acquisition script](../tools/get-inference-assets.ps1) and
[exact manifest](../adapters/inference/assets.lock.json). The default asset tree
contains `model/model.json`, thirteen named weight shards, the complete model MIT
license, `runtime/lib/tensorflow.dll`, and the runtime's original `LICENSE` and
`THIRD_PARTY_TF_C_LICENSES`. The loader verifies the exact model, every shard,
runtime DLL and all three notice files; another DLL or model export rejects.
No automatic upgrade or acquisition occurs during inference or ordinary builds.

The converted demo topology is pinned at
`de4888e6d448357ceafea10fc6010061c6f19a55`; preprocessing references were inspected
at `c9b71ce61491454125a0693f584f7244f29d9884`. Full upstream MIT notices remain in
derived graph code. The runtime ZIP, DLL, licenses and acquisition URLs are pinned
in the manifest. TensorFlow's [C installation documentation](https://www.tensorflow.org/install/lang_c)
identifies 2.18 as the final supported Windows C package release; this adapter
therefore carries an explicit maintenance limitation and does not imply a current
cross-platform runtime support promise.

`tools/build-inference.ps1` compiles the dedicated Win64 consumer and fixture with
checked FPC settings. It does not run inference. Use existing verified native
toolchains; no training-language environment is required.

## Native interfaces

- `TInferenceRequest` declares exact source SHA256, policy, selected channel,
  processing scope, waveform-support bounds, first center, hop and delivery size.
- `TInferenceWaveJob` verifies and holds the source, prepares a rolling window,
  and feeds a borrowed `TInferenceBackend` and `TInferenceSink`. Its state is
  single-use. Sink batches are provisional until `Complete`; errors and cooperative
  cancellation call `Abort`. A sink must preserve its previous accepted state.
- `TTinyPitchRuntime` owns one model session. One live instance per process and
  no concurrent/reentrant activation are supported. Framework process pools may
  outlive the session, so the verified DLL remains loaded until process exit.
- `RunInferenceProcess` uses a dedicated worker with hard process memory/time
  limits and cancellation. It publishes only after successful worker termination
  and full artifact validation. Existing output survives rejection or cancellation.
- `TInferenceFileReader` requires the expected source/preparation identity and
  validates the complete artifact before exposing bounded batches.

No runtime C types appear in the observation contract. In-process callers have
cooperative cancellation between windows; they must use the supervisor for hard
interruption of a stalled external call. The supervisor polls cancellation every
50 ms and terminates the worker on cancellation or failed budgets. Borrowed source,
backend and sink objects must remain unchanged during execution; callbacks cannot
reenter their active objects. Caller-provided backends are explicit test/custom
measurement hooks and do not establish the pinned production estimator identity
by themselves. Each backend declares its own estimator identity, which is stored
and checked separately: a custom-backend artifact rejects when a reader expects
the pinned estimator. Only the pinned worker is qualified by this task.

## Preparation and exact source coordinates

Supported source rates are 16,000, 44,100 and 48,000 Hz, mono or stereo, using the
existing bounded WAVE reader's PCM encodings. The caller selects one channel;
there is no implicit downmix. 16-kHz input passes through exactly. Other supported
rates use the owned centered Blackman-windowed sinc stream: cutoff
`0.94/max(1,sourceRate/16000)` and the existing fixed support/cache policy.

Every tensor has 1024 samples and the same one-frame graph geometry as the retained
fidelity comparison. Frame centering/RMS normalization occurs in framework
float32; reported input AC RMS is accumulated in Double. Session configuration
sets one intra-operation and one inter-operation thread and a five-second
operation timeout. Runtime thread-pool/XLA/thread-count/oneDNN environment
overrides reject, keeping those settings outside undeclared policy variation.

All request coordinates use the full resampled source's 16-kHz clock. Processing
scope controls emitted centers. Separate input-support bounds control where a
window is padded with zero. To split a source without adding false edges, retain
the same enclosing support bounds and choose adjacent processing scopes. The
stream seeks at an exact rational phase boundary with actual filter halo;
delivery batches never create padding or reset the resampler. True WAVE endpoints
retain the resampler's constant extension before window-support padding.

The source byte hash, original rate/channels/frame count, selected channel,
support and processing bounds, center/hop, model/runtime hashes and preparation
policy all bind the artifact. Scheduling batch size is intentionally excluded
from measurement identity, so changing 1 to 32 must preserve artifact bytes.
Changing source bytes, scope, preparation or estimator policy rejects reuse.

## Bounds and evidence required

| Boundary | Declared limit |
| --- | --- |
| Cold source/model/runtime setup | 30 seconds |
| Complete supervised job, including verification | 30 seconds plus processed scope duration |
| Worker peak private commitment, external runtime included | 2 GiB |
| Observation density | At most 100/s; hop 160..16000 samples |
| Delivery batch | 1..32 windows; cancellation checked between activations |
| Processing scope |At most one continuous hour per job |
| Raw observation | 1456 bytes: int64 center, float64 RMS, 360 float32 values |
| Hard cancellation | Within 2 seconds after request |
| Observing-phase progress stall | 5 seconds |

The Windows job object installs its memory limit before the suspended worker
resumes. Its OS peak commitment includes runtime allocations that Pascal heap
tracking cannot see. [Windows job accounting](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_extended_limit_information)
tracks the peak between supervisor polls. This is distinct from working-set/RSS
sampling and from Pascal heap leak checks.

At 100 Hz, raw observations require 524,160,000 bytes per hour plus a small bounded
header and checksum. Ten hours imply about 5.24 GB of raw output. The declared
throughput target permits at most ten hours plus per-job setup for ten qualified
one-hour jobs; full-source verification/preparation still needs workload budgeting.
Memory stays bounded through streaming. These are projections; they do not certify
a ten-hour corpus, provider accuracy, disk capacity or style learning.

Required qualification separates short controls at all supported rates/channels,
the two retained 30-second recorded fidelity comparisons, one 5-minute 48-kHz stereo
preparation/resource case and one real continuous-hour development recording.
Cold setup and complete cost are reported separately. Batch replay, adjacent
scope halos, source/policy rejection, damaged/incomplete artifacts, sink/backend
failure, cancellation, runtime stalls and OS memory rejection have focused fixture
cases. Do not repeat a full matrix after a failure unless its changed boundary
requires it.

Cold setup means a fresh worker/session with source and asset verification; it
does not claim an empty operating-system disk cache. Reports also separate the
first observation (including graph warm-up) and the remaining warm observation
phase. These phases include native preparation and sink delivery, not merely
isolated network arithmetic. The final source/artifact verification and teardown
remain in the complete-job time.

The dedicated worker uses exactly two independent initialization lanes: one
native thread verifies and holds the complete source while the main thread
verifies the runtime, model and notices and creates the session. Both must finish
successfully before any measurement. This overlaps verification work without
skipping source bytes, changing hashes or adding inference threads. Reports give
both lane durations; elapsed cold setup is their joined wall time, not their sum.
Readiness values distinguish unfinished (0), successful (1) and failed (-1)
initialization. Setup, total-time, observing-stall, final-verification and memory
budget failures have distinct diagnostics, including phase, elapsed time and
the applicable frozen limit. The thirty-second setup limit is unchanged.

## Current artifact and command

The current `PINF1` artifact has a bounded canonical identity header, ordered
fixed-size little-endian observations and a SHA256 completion trailer. There is
one encoding, no legacy reader and no embedded note-admission policy. A missing
trailer, wrong extent, checksum, center sequence, nonfinite value or expected
identity rejects. A private staging artifact is replaced atomically only after
full validation; incomplete files are never accepted measurements.

Staging creation uses the Windows exclusive `CREATE_NEW` operation. A sink owns
the file only after that operation succeeds; a competing sink cannot truncate a
completed artifact. Abort marks the owned open handle for deletion before closing
it, using [handle-based file disposition](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-setfileinformationbyhandle).
It never deletes an unowned pathname after a failed open or repeated abort. If
the OS refuses cleanup, an incomplete staging file may remain rather than risk
deleting a later owner's file.

```text
pythian.inference.wav measure MODEL_DIR RUNTIME_LIB_DIR SOURCE.wav OUTPUT.pinf
  SOURCE_SHA256 CHANNEL SCOPE_START16K SCOPE_END16K INPUT_START16K INPUT_END16K
  FIRST_CENTER16K HOP16K BATCH_SIZE
```

Pass arguments on one command line. The tool prints a native execution report;
it does not interpret salience or label a source. Exact acquisition and initial
[arithmetic-fidelity evidence](PHRASE-EVALUATION.md#native-model-fidelity-checkpoint)
remain distinct from the maintained-path qualification below.

## Qualification — 2026-09-21

Final QA accepts the maintained consumer on checked FPC 3.2.2 Win64, using the
declared pinned assets and unchanged budgets. The host is a Ryzen 5 1600 with
six cores/twelve logical processors and approximately 16 GiB physical memory.
Resource runs were sequential, without competing analysis or compilation.

| Evidence | Accepted result |
| --- | --- |
| Twelve scalar/runtime controls | Maximum activation difference 3.58e-7; no changed peak bin |
| Recorded flute and violin comparisons | 2,997 observations each; exact centers, maximum activation difference 7.15256e-7, no changed peak bin |
| Six short rate/channel cases | All supported rates with mono/stereo pass time/setup/private-memory limits |
| Five-minute 48-kHz stereo case | 30,000 observations; 259,797 ms total; 20,687-ms setup; 101,515,264-byte worker peak |
| Continuous-hour 16-kHz stereo source, channel 0 | 360,000 observations; 2,420,266 ms total; 20,313-ms setup; 103,051,264-byte worker peak |
| Ownership, failure and replay | Sink collision/cleanup, source/policy identity, batch replay, halo, corruption, memory/stall limits and bounded cancellation pass |

The hour joins source verification in 11,125 ms and runtime setup in 20,313 ms;
first observation takes 94 ms, and the remaining observation phase 2,364,265 ms.
Its complete 524,160,407-byte artifact passes final verification and publication.
Successful qualification runs report zero owned leaks. Original failure logs
remain alongside the accepted second submission; passed unchanged arithmetic
cases were retained instead of rerunning the entire matrix.

Exact commands, source manifests, host inventory, terminal logs and reports are
retained under `build/native-inference/` and `build/qa-batch-08/`. The accepted
hour report is `submission2-hour-report.json`. It binds the original 131,770,456-
frame input, selected channel and model/runtime identities; one hour was emitted.
This proves the declared observation execution path, not note admission,
arbitrary-length input performance, many-hour training or final portable delivery.
