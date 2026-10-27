# NS-6_observability_03 — Offline rendering and separation checkpoints

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Extend the remaining whole-clip DSP entry points with progress from their primary
engines. Separation permits two billion planned work visits, and whole-note/grain
render helpers can hide substantial work even though stream consumers have clocks.
North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Next deliverable: measured separation passes and bulk rendering callbacks, with
CLI forwarding. Closing evidence: output parity and cancellation in each expensive
pass. Stop on a second renderer, per-sample callbacks or changed audio.

Accepted 2026-10-27 for the four native criteria below. Optional observers now
reach primary separation, synth/note/chord/grain rendering, PCM16 writing and
bulk note/pitch evaluation. Actual Pascal operators forward the same contract.
Independent combined QA and final checked native execution pass; no DSP, score
math or codec was replaced. Zero additional credit. This acceptance does not
certify all inherited allocation/parsing boundaries as short, pas2js synthesis,
browser responsiveness or musical inference; remaining owners are linked below.

**Acceptance Criteria:**

- Add optional shared callbacks to separation spectral/mask/reconstruction passes;
  use real windows/cells/frames and retain construction cleanup on callback abort.
- Forward whole-note/chord/grain/synth rendering progress through the primary
  render implementation. Retain bounded stream/pull contracts and sample identity.
- Audit long WAV encode/export and bulk evaluation callers; connect genuinely
  long loops or document measured bounds, and expose phases in maintained Pascal
  operators without executing third-party inference.
- Tests cover mid-pass abort, retry, parity and callback frequency/work bounds.

**Blockers**

- [Shared callbacks and audit — DONE](NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss acceptance: separation reports spectral windows, magnitude
  and mask cells, reconstruction windows and residual frames, with interior
  abort/retry and exact nil/observed PCM. Spike implemented it; Spiegel
  independently checked cleanup and output preservation. The maintained CLI
  also observes its final source/reconstruction audit and both PCM16 exports.
  Authored 32,000-frame, 8-kHz stereo reconstruction differs by at most one PCM16 step
  (`1/32768`); that quantization bound is not a source-separation musical claim.
- Spiegel implemented synth, note/chord and grain forwarding through the
  existing primary loops. Final root and independent native fixtures pass
  187 checks each, including actual render parity, abort/retry, aggregate
  4,096-frame cadence and trailing-output counts. Allocation/output clocks and
  summed voice/grain work are distinct phases; overlap is not elapsed playback.
  The pull/stream contract is unchanged. Sparse internal gaps were inspected;
  the dedicated fixture explicitly checks trailing silence.
- Big Boss implemented WAV/export callbacks in the primary writer: confirmed
  frames after each sink block, borrowed-sample validation every 4,096 items,
  and encoded-array readback every 64 KiB. Final Win64 and checked Win32 pass
  1,730 checks each; independent Win64 also passes 1,730. Actual pas2js/Node
  passes 1,475 shared checks, excluding native filename I/O. Tests retain byte
  identity, exact exception identity, poisoned-writer/reentry behavior,
  recoverable input errors, empty/header failure, abort and retry. Confirmed
  bytes remain in borrowed sinks; SaveWavePcm16 retains direct-file writes and
  can leave a partial destination after failure. No atomic rollback is claimed.
  Existing streaming WAV boundary/regression checks pass.
- Core evaluation reports actual note-region, candidate, matching, pitch-pair
  and frame-comparison work. Active unknown totals finish with actual measured
  totals, not budget denominators. Final root and independent Win64 pass
  1,093 checks each. File-bound evaluator regression covers unchanged complete
  JSON, source-hash/scoring aborts, retained prior result and successful retry.
  Big Boss connected native evaluation callers and note/timing consistency;
  Spike connected reviewed-presence reference hashes and center construction.
  Final root and independent reference fixtures pass 91 checks each. Every
  checked native run above reports zero leaks.
- Actual checked CLI consumers: render writes 355,887 stereo frames at 44.1 kHz;
  MIDI render writes one authored note / 29,400 stereo frames; evaluator stdout
  remains valid JSON while the shared native console adapter sends throttled
  named counts to stderr. Reviewed-presence CLI emits an authored 800-center
  reference with hash/center phases. The native build registers all four new
  fixtures with fresh output roots and explicit tool-unit search paths. Build
  script parsing passes. No long private recording or operator response was used.
- Combined QA repaired a missing separation CLI audit phase, missing reviewed-
  reference forwarding and suppressed final unknown-work counts. Fixture-only
  repairs reset monotonic tracking on retry and isolate native stderr/exit code
  under pas2js; final fixtures were formatted and recompiled/executed afterward.
  An initial Win32 WAV invocation lacked its output directory; the retained
  failure was corrected with a fresh created E-drive directory. During the
  evaluation-count repair, a wrong-cwd build failed and an older executable ran;
  that execution is excluded. Fresh explicit-path 1,093-check results supersede it.
  No implementation task reached two failed formal QA submissions.
- Scope correction: Spiegel accidentally ran the existing synthetic pitch
  fixture while checking an API, contrary to the no-inference assignment. It
  used authored input only and reported zero leaks. Its log is retained, it was
  not repeated, and it supplies no scientific acceptance or completion credit.
- Evidence: dedicated E-drive `build/tests/runs/offline-progress-20261027-*`
  folders, with final root logs/manifests in
  `runs/offline-progress-20261027-boss-final/`. Stable FPC 3.2.2 checked Win64,
  checked Win32 WAV, and matched pas2js/RTL plus Node are separately scoped.
  [Coverage and residual boundaries](../../OBSERVABILITY.md) retain synchronous
  allocation/clip-copy/parsing limits and the remaining
  [retained-operation audit](../NS-6_observability_04.md). No universal callback
  latency or browser presentation is inferred. Stable service deployment and
  private catalog were not replaced for this native library/CLI batch.
- 2026-10-27, Big Boss: selected all four native criteria. Deliverable: shared
  separation and bulk-render callbacks plus observed WAV/export/operator paths.
  Closing evidence: exact audio/encoded-byte parity, bounded event cadence,
  interior abort cleanup and successful retry through actual callers. Stop on a
  duplicate engine/codec, changed output or per-sample callbacks. Spike owns
  separation/CLI/fixture; Spiegel owns synth, note/grain wrappers and render
  fixture; Big Boss owns WAV writer/export, other operator forwarding, audit,
  integration and final judgment. No musical credit follows from observability.
- A distinct actual pas2js render-closure blocker is recorded in
  [portability_03](../NS-6_portability_03.md). Native verification continues here;
  no unsupported JavaScript or browser claim may substitute for that task.
- 2026-10-03, Big Boss: `THarmonicPercussive.Create` has full spectrogram and
  median passes without callbacks; `RenderNoteSequence` delegates to whole-clip
  `RenderFrameTones`. Existing streaming clocks do not instrument these bulk APIs.
  See [audit](../../OBSERVABILITY.md). Those were the original gaps; acceptance
  above supersedes their open status within this task's scoped native phases.
