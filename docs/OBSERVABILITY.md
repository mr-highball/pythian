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
| Library discovery/preparation | Byte/item callbacks reach nested import; existing library notification throttle, cancellation and staged index publication retained | [observability_02](TODO/DONE/NS-6_observability_02.md) |
| Streaming synthesis/WFC audio | Existing bounded pull, frame clocks, state and cancellation retained | A caller can observe each block; bulk helpers are a separate gap |
| Pascal inference | Existing observation checkpoints, budgets, cancellation and deadlines retained | Reconcile remaining operator phases in [observability_04](TODO/NS-6_observability_04.md); no third-party execution |
| Primary scalar text | `text_validate_bytes` counts canonical UTF-8 bytes every 1,024 bytes; `text_compare_scalars` counts compared scalar pairs every 256 items. Totals remain unknown until the actual end | [Metadata reuse](TODO/DONE/NS-6_metadata_01.md); native raw bytes and pas2js UTF-16 scalars share the policy, with borrowed callbacks and original abort exceptions |
| Layer request/graph construction | `layer_prepare_visits`, `layer_constraint_visits`, `layer_preference_visits` count actual owned loop visits every 256 items; totals unknown until final count | [Layer preparation](TODO/NS-6_observability_11.md), local checked consumers pass; publication pending. Borrowed observer is not retained. Mask callback abort rolls back domains before pending-mask publication |
| Catalog import and verification | Shared measured hash/copy/verification phases; callback failures escape per-file error handling | [observability_02](TODO/DONE/NS-6_observability_02.md) |
| Offline render, separation, export and evaluation | Primary native engines report measured windows/cells/frames/comparisons; maintained operators forward callbacks | [observability_03 — DONE](TODO/DONE/NS-6_observability_03.md); scoped phases below |
| Retained corpus archive and WFC model validation | Actual feature/attachment/hash bytes and owned lookup/state/token validation are observable through the native archive operator | [observability_05 — DONE](TODO/DONE/NS-6_observability_05.md); synchronous residuals below |
| WFC chord composition planning | Actual compatibility checks and target visits, unknown traversal total until counted; prior caller output preserved on abort | [observability_06 — DONE](TODO/DONE/NS-6_observability_06.md) |
| Retained style/provider and batch evaluation | Nested style serialization/validation/blending/provider preparation and inference reporting still need assessment | [observability_04](TODO/NS-6_observability_04.md) |
| Primary analysis in pas2js | Full callback consumer executes shared primary algorithms; optional timer adapter yields between bounded WAV analysis batches | [portability_01 — DONE](TODO/DONE/NS-6_portability_01.md); actual browser presentation and WASM remain unqualified |
| Primary synthesis in pas2js | Actual shared synth/instrument/note/chord/grain cases execute with measured callbacks, abort/retry and exact supported clocks | [portability_03 — DONE](TODO/DONE/NS-6_portability_03.md), [timing repair — DONE](TODO/DONE/NS-6_portability_04.md); synchronous Node consumers, no browser/WASM claim |

Per-sample oscillators, filters and small fixed transforms should not publish a
callback per sample. Observe their caller's bounded render block instead. Static
admission limits alone do not establish acceptable latency: remaining bulk paths
must either gain checkpoints or provide measured evidence for their bound.
There is no demonstrated generic WFC defect from this audit. Companion source
was not changed; any such finding follows the separate-repository procedure.

Later layer-preparation measurement (2026-10-27) demonstrates a generic WFC
bulk-mask preparation gap, superseding that earlier audit boundary. At the
admissible 256-state/1024-cell budget, the isolated public WFC call did not finish
before external stop after119.944 seconds total. Two process observations prove
over81 CPU seconds spent in the same intersection call; no completed timing or
zero-leak result is claimed for that interrupted probe. Encode/decode and model
application preceded it (0/16/1766 ms); mask preflight took15 ms, with two RTL
copies below timer resolution. These are one local checked Win64 workload, not
universal bounds. Boundary checkpoints do not expose those dependency interiors.
The separate WFC branch `codex/pythian-sequence-preparation` and explicit downstream
integration are owned by [task12](TODO/NS-6_observability_12.md). Provider/registry/
context interiors, later generation/capture/replacement and other residuals remain
with task04; this construction component is not full-operation responsiveness.

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

## Native catalog imports

`ImportLabelInbox` accepts the shared optional callback. `import_hash_bytes`,
`import_copy_bytes` and `import_verify_bytes` report actual bytes of the current
file and phase; verification restarts for each source/staged/existing read.
The primary SHA implementation retains its 8-KiB checkpoints; staged copying
reports every 64 KiB. `import_items` reports entries already processed before
starting the next entry. A phase reaching its byte total is not an import result.

Callback exceptions propagate unchanged through ordinary per-file failure
handling. An interrupted uncommitted entry leaves no importer `.partial` file;
previously accepted records and originals remain intact. Earlier complete entries
may remain accepted after a later cancellation, so retry reconciles them as
duplicates. There is deliberately no callback after the final record commit that
could report cancellation after successful publication.

Library preparation, capture inspection/saving and effects saving use this same
importer. The library adapts notifications to its existing eight-MiB/five-second
cadence, always forwarding phase starts, resets and completion. Capture/effects
also forward their observer into the final library refresh through one callback
bridge. No hash or copying algorithm is replicated in the bridge. The common
Studio display names the import phases; native job history retains byte units.
Actual browser/phone presentation remains part of the open operator matrix.

## Offline native consumers

Accepted 2026-10-27: [offline checkpoints](TODO/DONE/NS-6_observability_03.md)
extend the existing primary engines. Nil observers preserve audio/score/encoded
results. These are synchronous stage measurements, not an overall percentage
or an asynchronous job scheduler.

| Primary boundary | Stage and measured units | Checkpoint cadence |
| --- | --- | --- |
| Harmonic/percussive separation | `separation_spectrum` and `separation_reconstruction`: analysis windows (`wuFrames`); `separation_magnitudes` and `separation_mask`: spectral cells; `separation_residual`: original frames | 16 windows, 4,096 magnitude cells, 256 mask cells and 4,096 residual frames, plus start/end |
| Synth and note/chord wrappers | `synth_allocate_frames`: output frames including trailing silence; `synth_voice_frames`: summed rendered voice frames | Allocation start/end; 4,096 aggregate voice frames across voice boundaries |
| Granular renderer | `grain_mix_frames`: summed grain frames; `grain_output_frames`: all output frames including gaps/tail | 4,096 aggregate mix/output frames and start/end |
| PCM16 writer/export | `write_wave_pcm16`: confirmed frames; `validate_wave_samples`: borrowed-array scalar samples; `encode_wave_bytes`: returned-array bytes | Existing 4-KiB sink blocks, 4,096 validation items, 64-KiB readback blocks |
| Overlapping-note evaluation | `evaluation_note_regions`, `evaluation_note_candidates`, `evaluation_note_matching`: actual comparison visits | 4,096 visits; active total unknown, final total equals actual completed work |
| Pitch evaluation and native consistency checks | `evaluation_pitch_pairs`, `evaluation_pitch_frames`, `evaluation_note_cells`, `evaluation_timing_cells`: actual comparisons | 4,096 comparisons; pitch pairs distinguish onset/full passes; timing consistency has an unknown active total |
| Reviewed-presence reference | Primary `verify_audio_bytes` plus `reference_centers`: completed centers | Shared 8-KiB hash blocks and 256-center blocks |
| Separation CLI audit | `separation_audit`: source/reconstruction frames | 4,096 frames and start/end |

Separation's mask and reconstruction stages interleave. Track counters by stage,
not one last global value. Their `wuFrames` spectral counts are FFT windows,
not original-source frames. Summed voice/grain work includes overlaps and can
exceed playback duration. No stage uses a maximum-work budget as completed work.
The shared native console adapter retains each stage/pass, emits starts/resets/
completion and throttles intermediate stderr lines to 250 ms. Evaluator stdout
remains machine-readable JSON.

Callback exceptions preserve their identity and release local resources. The
PCM16 writer updates its frame count only after its borrowed sink confirms a
block; a sink/observer exception poisons that writer. Confirmed bytes remain.
Input-validation and short-Finish errors retain their previous recoverability.
`SaveWavePcm16` still writes its caller-named file directly, so cancellation can
leave a partial file. Stage output elsewhere if atomic publication is required.

The audit retains distinct static bounds: separation admits at most 8 million
spectral cells / 2 billion planned visits; synth at most 100 million costed
visits; grains at most 64 million visits / 16 million output samples. Immutable
clips admit 64 million scalar samples. Overlapping notes admit 4,096 notes per
side, 16,384 regions and 50 million matching visits; pitch evaluation admits
16,777,216 pairs. Reviewed references admit 32,768 centers / 50 million
label-center visits. File-bound evaluation admits 8-MiB documents / 1-GiB sources.
These are admission limits, not measured latency bounds. Allocation, immutable
clip validation/copying, bounded planning and RTL JSON parsing remain synchronous
between checkpoints. The retained [batch audit](TODO/NS-6_observability_04.md)
owns the remaining nested metadata/graph/publication assessment; it must measure
or instrument those boundaries before describing them as short. This batch does
not promise a maximum time to cancellation inside an allocator, FFT, median,
stream write or callback.

Final checked Win64 fixtures pass 187 render, 1,730 WAV, 1,093 evaluation and
91 reference checks; independent helper checks pass the same counts. The full
file-bound evaluation and separation regressions pass. All checked native runs
report zero leaks. Checked Win32 WAV passes 1,730; actual pas2js/Node WAV passes
1,475 shared checks, excluding filename I/O. Render/MIDI-render/separation/
evaluation CLIs exercise the same primary engines with authored inputs. Evidence
is under E-drive `build/tests/runs/offline-progress-20261027-*`.

This qualifies the stated native phases and portable WAV callbacks. The later
[shared synthesis repair](TODO/DONE/NS-6_portability_03.md) now executes the actual
primary consumer under pas2js, retaining the original instrument compiler failure
and independently reproduced [exact-clock defect](TODO/DONE/NS-6_portability_04.md).
Four source/render cases compare all emitted samples; the original 187-check
render callback fixture also executes on both targets. See the
[supported limits](MIDI.md#shared-synthesis-and-exact-counter-limits). No browser,
WASM, physical-phone or musical result is inferred. No service/browser asset
replacement was needed for these library/CLI changes.

## Retained corpus and composition consumers

Accepted 2026-10-27, native scope only: the
[corpus archive](TODO/DONE/NS-6_observability_05.md) and
[composition planning](TODO/DONE/NS-6_observability_06.md) APIs expose optional
shared callbacks through their maintained Pascal CLIs. These independently
usable consumers were split from observability_04 with no added credit. Its
remaining retained-style/provider/evaluation/inference requirements stay open.

| Owned boundary | Real measured work | Cadence and completion |
| --- | --- | --- |
| Primary archive encode/decode | `archive_encode_features`, `archive_decode_features`: observations | 256 features; decode active total unknown, actual final total |
| Archive attachment copy | `archive_encode_attachment`, `archive_decode_attachment`: bytes | 64-KiB blocks, confirmed local copy counts |
| Archive payload digest | Existing `verify_audio_bytes`: bytes | Shared 8-KiB SHA checkpoints; archive trailer excluded from its payload digest |
| Primary persisted-corpus validation | `corpus_validate_features`: observations | 256 validated features; existing palette encode/representative callbacks also forwarded |
| Pythian WFC corpus model validation | `wfc_corpus_lookup`: initialized entries; `wfc_corpus_states`: actual items across both state passes; `wfc_corpus_tokens`: corpus observations | 4,096 lookup entries, 256 state/token items; counts can interleave |
| Pythian chord compatibility/reachability | `composition_compatibility`: state-pair checks; `composition_reachability`: target visits | 64 compatibility checks /256 target visits; active traversal total unknown, final total actual |

The WFC corpus validator is owned here, not in the companion. Independent QA
caught its missing callback in the first submission. The repaired second
submission reports its actual work and preserves exception identity and nil
failed-decode model cleanup. Generic companion learning, model text handling
and solving remain synchronous, and no companion defect was demonstrated.

The capped authored corpus contains 65,536 features and a 1-MiB opaque attachment:
257 encode-feature callbacks, 258 decode-feature callbacks, 257 validation
callbacks and 17 attachment callbacks per direction. Final maintained native
Win32/Win64 fixtures pass 11,712 checks each; maintained WFC corpus tests cover
interior lookup/token abort on public encode/decode, exact observed encode retry,
decode retry, saved-model token/audio replay and unchanged borrowed archives.
The populated eight-source/13-state composition reports 169 compatibility checks
and 2,002 target visits. Independent boundary checks retain prior output on
initial/interior/final observer failure. All valid checked native runs report
zero leaks. Fixture wall times include multiple passes/abort/retry and concurrent
target execution; they are not per-operation performance comparisons.

Actual maintained CLI output against `e0049c8` preserves archive bytes,
inspection JSON, saved-model remix WAV and composition WAV/report (excluding
the different output pathname). Counts go to stderr. No audio playback, actual
browser presentation, pas2js archive execution or musical acceptance follows.

Static archive limits remain 32 MiB, attachment 16 MiB, 32 sources and 65,536
features. WFC validation's order-four lookup admits at most 1,185,921 entries.
Composition retains its existing 16,777,216 combined-work cap; the cap is never
a progress denominator. Allocations, whole-array copies, bounded metadata,
reachability cell scans and generic companion calls remain synchronous. A final
reachability callback precedes remaining path validation/generation. No maximum
cancellation latency is promised. Existing archive CLI direct file writes remain
non-atomic; completed local stages are not durable publication. The capped
whole-memory archive does not certify journal-based many-hour semantic recovery.

Evidence: E-drive `build/tests/runs/{archive,composition}-progress-20261027-*`
and `build/tests/runs/retained-progress-20261027-*`, including frozen prior-revision
consumers, exact hashes, measured counts, failure/review evidence and final native
runs. Stable service assets and private operator records were not changed.

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

## Semantic style archives and selective blends

The [semantic callback task](TODO/DONE/NS-6_observability_08.md) is accepted at
`19124a6`: stable FPC3.2.2 Win32/Win64 checks and actual Ubuntu
[run448](https://github.com/mr-highball/pythian/actions/runs/40567472267) pass.
Maintained integration and extracted core/WFC consumers qualify the published
revision. This instrumentation earns no additional musical credit.

Optional callbacks reach source/derived/blend constructors, encode/decode,
definition/parent copies and generic/named session preparation. Vocabulary,
preparation and run identities forward through the same owned serializer and
primary SHA implementation. Existing archive schemas and musical math are
unchanged. The maintained caller example uses the shared console adapter;
packaging includes it and accepts the build's output-root override.

| Owned boundary | Reported work |
| --- | --- |
| Archive input/output/blob/copy | Actual bytes in 64-KiB blocks |
| Archive numeric fields | Actual visits every 4096 fields; total unknown while active |
| Vocabulary tokens | Actual token visits, aggregate cadence |
| Source/run/provider validation | Actual items, including source/preparation evidence |
| Run clocks and joint constraint preparation | Actual cell visits every 256; active total unknown, actual final total |
| Co-observed projection pairs | Actual tested pairs every 4096; active total unknown, actual final total |
| Blend source/run/provider preparation | Actual items and parent-side passes |
| Semantic ancestry and embedded source/exposure audits | Actual node/depth and source visits |
| Session preparation | Actual provider loads and preparation boundaries |
| Payload/identity digests | Primary `verify_audio_bytes` checkpoints |

Checked native fixtures cover populated multi-source/provider/run styles,
selective blend/reblend, exact nil/observed archives/session results, original
callback exceptions, cleanup, unchanged borrowed parents/registry and retry.
Named session and embedded sound audit failures also retain exact exception
identity and zero leaks. Twenty selected cancellation/retry cases run in the
new fixture; callback-count assertions are not twenty thousand distinct product
outcomes. All 23 saved semantic fixtures replay exactly against a separately
compiled prior revision on each target. The maintained caller's generated WAV,
style and two authored WAVs retain exact same-target bytes.

Caller codec bodies and generic WFC model decoding/learning/solving remain
synchronous. Provider-contract internals and nested context metadata remain
with [observability_04](TODO/NS-6_observability_04.md); embedded wave-profile
internals remain with [observability_07](TODO/DONE/NS-6_observability_07.md). Embedded
source/parent callbacks describe the semantic audit and call boundaries, not
interior work in those other units. RTL allocations/copies remain synchronous.
No maximum cancellation latency, browser yielding, phone performance or musical
acceptance is inferred. Evidence: E-drive `runs/semantic-style-progress-20261027-boss`.

## Pitch-model preparation

The accepted [pitch preparation task](TODO/DONE/NS-6_observability_09.md) adds optional shared
callbacks to pitch, paired pitch/rhythm and both duration learner overloads.
Checked Win32/Win64 learner and retained-source fixtures and actual Ubuntu
[run449](https://github.com/mr-highball/pythian/actions/runs/40571651841) pass at
`f203195`, including maintained integration and extracted consumers.

`pitch_validate_cells` visits all raw cells, including zero-weight sources.
`pitch_scan_cells` counts active-source cells scanned to separate known runs;
`pitch_encode_cells` counts admitted cells encoded. `pitch_measured_spans` and
`pitch_duration_spans` count actual converted/validated spans. These item stages
report every 256 visits and at completion. `pitch_weighted_cells` and
`pitch_duration_weighted` count observations copied into weighted samples,
reporting when a completed sample crosses a 256-observation boundary. Active
totals remain unknown; final totals are actual completed work, never the cap.

The retained source constructor forwards its observer through all three model
families. Its archive and the four canonical model texts match prior same-target
bytes. The focused fixture checks 16 cancellation/retry selections, exact
exception identity, released unpublished state and unchanged borrowed inputs.
Generic WFC learning and RTL copies remain synchronous. Other wave-profile
preparation, preference/blend/parent/archive loops and CLI forwarding remain with
[observability_07](TODO/DONE/NS-6_observability_07.md); this source pitch callback does
not qualify them, maximum latency, Studio presentation or musical accuracy.

## Retained wave-style profiles

The [wave-profile task](TODO/DONE/NS-6_observability_07.md) is accepted at `af46648`
after checked native consumers and actual Ubuntu
[run451](https://github.com/mr-highball/pythian/actions/runs/40590839661), including
integration and both extracted packages. It provides
optional callbacks through source/preference/blend constructors, detached
copies, parent reconstruction and current-format archives. The maintained style
CLI forwards them on stderr; stdout and publication remain separate.

Owned cell/token/coefficient/lookup loops report at 256 visits and completion.
Weighted samples count actual samples, independently of raw cell counts.
Ancestry nodes count visits with unknown total until complete. Archive numeric
prefix fields report every 4,096 fields; stream/copy/blob bytes every 64 KiB;
hash callbacks retain primary SHA cadence. Serialized stream bytes exclude the
64-byte digest trailer; the subsequent identity hash includes it. Each nested
input can restart its stage. No cap is reported as completed work.

Evidence/component copying reports completed arrays, not their individual
elements; RTL allocation/copy calls remain synchronous. Context codecs and
selection, generic WFC learning/model codecs, clock/grid construction, pitch/
rhythm/intensity admission, duration evidence/spans/articulation, harmonic
factoring and envelope/factory construction also retain synchronous calls.
Their entry/exit counters describe calls, not interior cancellation. The native
fixture records local call intervals with `GetTickCount64`; zero is below timer
resolution. Composite parent-copy intervals include observed nested work and
must not be treated as uninterrupted time. These fixtures neither measure all
maximum workloads nor promise cancellation latency, browser yielding or phone
performance. Provider/context internals retain
[observability_04](TODO/NS-6_observability_04.md).

Primary measurement now has the separately tracked candidate below. The
existing dense pitch tracker is also forwarded. Profile acceptance alone does
not qualify raw measurements or musical accuracy.

## Source measurement and admission

[Source measurement](TODO/DONE/NS-6_observability_10.md) is accepted at `7da8569`
after native/pas2js checks and actual Ubuntu
[run452](https://github.com/mr-highball/pythian/actions/runs/40595844656), including
integration and both extracted consumers. It serves the primary Pascal units
and actual retained style CLI.
Both pitch-cell measurement overloads, admission and summaries accept the shared
optional callback. `pitch_cell_measure` counts visited cells, including cells too
short for the estimator; `pitch_cell_estimates` counts only completed estimator
calls. Copied window frames count actual visits, with unknown total until counted.
Cell/admission/summary counters report every eight visits and at completion;
window copies report every 1,024 frames. A constant-grid constructor reports a
call boundary and frees its result if the final callback rejects it.

Dynamics validates actual RMS values and source onsets, counts completed windows,
and reports actual frame visits every 1,024 frames. Frames shortened at EOF use
their real lengths; overlapping windows can visit the same source frame more
than once, and both stereo channels are included in each frame. Validation,
reference selection, intensity projection and final cell verification report
every 256 items. Projection does not turn rejected onsets into training labels.
Native style commands forward these callbacks on stderr without changing saved
evidence, stdout or publication. Pitch admission holds its candidate array until
validation and the final callback pass, avoiding partial caller arrays on abort.

Individual `EstimatePitch` calls, grid construction and RTL allocations remain
synchronous. The fixture measures one 8,192-frame near-limit estimator call with
16,773,120 declared squared-difference terms on Win64/pas2js and 16,777,216 on
Win32 under its existing rounding. Observed local intervals span 203–297 ms
native and 219–234 ms pas2js. This is a representative workload, not a maximum
latency guarantee or browser-yielding evidence. Numerical/decision rules are
unchanged; native same-target prior artifacts and actual pas2js checks qualify
mechanics, not recorded accuracy. Evidence is under dedicated E-drive
`build/tests/runs/measurement-progress-20261027-boss*`.

## Validation and limits

The original 2026-10-03 native callback suite has 385 checks, including identical hashes,
resampled samples, analysis features, pitch estimates, learned centers and abort
cleanup. Existing hash, WAV analysis, weighted journal/WFC tests also pass, as do
164 real Studio worker checks, 130 effects checks and 53 capture checks. The
shared callback contract passes actual pas2js/Node execution with counters above
32 bits, unknown totals, invalid bounds and callback exceptions. Build logs and
authored browser traces are under ignored `build/observability/`.

These checks establish mechanics and output preservation, not musical truth,
complete physical-phone qualification or universal responsiveness. A short job
can finish between browser polls. The offline native phases above are accepted;
retained style/metadata operations and actual browser presentation remain
explicitly open. Shared synthesis qualification is scoped above. Observability
repairs earn no additional north-star credit.
