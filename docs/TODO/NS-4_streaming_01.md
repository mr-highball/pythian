# NS-4_streaming_01 — Provide bounded long-duration generation sessions

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Make a saved source-bound WFC model produce audio incrementally for a caller's
chosen duration, including two minutes, two hours and twenty-four hours. Reuse
one continuous solver boundary, selection history and overlap-add timeline.
Portable audio buffering/rendering stays core-only; WFC sequencing belongs in
the adapter. Output length must not require a whole-audio allocation or grain ledger.

North star: NS-4. Outcome owner: WFC-STREAMING.
Completion credit: 5 goal percentage points (0.75 overall points).
Basis: five unearned integration_01 points transfer here; its full recorded
provider, blend/reblend and listening requirements remain at thirty points.
Credit is earned only after all criteria and prerequisites pass.

Execution status: selected; Big Boss owns assessment and implementation for this
solo operator expansion. Next deliverable: reusable Pascal generation session
with bounded pull/consumer buffering. Closing evidence: deterministic continuous
PCM across block sizes, exact 64-bit clocks, cancellation/failure and measured
memory/throughput. Stop at an actual generic WFC gap and follow TASKFLOW's separate
repository/new-branch procedure; no companion-source edits in this checkout.

**Acceptance Criteria:**

- AC1: Caller-selected positive duration/total frames uses checked 64-bit clocks;
  two-minute, two-hour and twenty-four-hour requests are representable at the
  supported rates. Work and allocation per pull are bounded independently of
  total duration. Report real limits; increasing an old cap alone is insufficient.
- AC2: WFC latent continuation, deterministic seed policy, source selection and
  Hann overlap history persist across pulls. Exact ending clips only final output;
  chunk boundaries do not restart generation, loop a completed audition, reset
  effects or add silence. Existing saved model/source identities remain bound.
- AC3: Backpressure, pause, stop, exhaustion and finite solver/read failures have
  explicit ownership and cancellation semantics. No secret seed substitution;
  failed output remains identifiable. Receipts/provenance are streamed or bounded.
- AC4: PCM generation is independent of a single RIFF WAV's size limits. A host
  can consume chunks without first writing or reading the complete output.
  Any export path declares its format/segmentation limit before generation.
- AC5: Checked native boundary, chunk-partition/replay and failure tests plus a
  sustained throughput/memory run qualify the declared scope. Exercise clocks
  beyond 32-bit frame counts and duration-dependent resource growth. Distinguish
  a long-duration plan/clock test from actually rendering that complete duration.
  Streaming mechanics earn no inferred-style, structural or musical-quality claim.

**Blockers**

- [NS-5_continuity_02.md](DONE/NS-5_continuity_02.md)

**Dev Notes:**

- 2026-10-02, Big Boss: primary `TJournalAudioRenderStream` now emits borrowed
  PCM blocks with Int64 grain/output clocks and exact final clipping. Shared
  `GrainWindowWeight` replaces its duplicate Hann formula. Selection work bounds
  apply per pull rather than lifetime. `TJournalAudioSession` in the WFC adapter
  retains latent/selection/overlap history and fixed 128-grain solve chunks;
  its consumer owns format, verification, bounded receipts and cancellation.
  The finite worker uses this session and removes its temporary WAV/readback trim.
  Checked Win32/Win64 tests pass partition-identical PCM/provenance, short endings,
  beyond-32-bit clocks, maximum-rate stereo duration startup, lifecycle and
  source/output/reentry/solver failures, with zero heap leaks. Both targets pass
  68 real worker checks. Actual checked optimized Win64 runs render 120/7200
  seconds at 8 kHz mono in 875/52703 ms, with identical 571808-byte maximum live
  Pascal heap. No 24-hour render or musical-quality claim. Detailed evidence is
  under ignored `build/long-session/`; exact-revision CI remains before acceptance.
- 2026-10-02, Big Boss: current WFC continuation is already incremental, but
  the journal renderer binds its output to a finite PCM16 WAV writer, 32,768
  total grains and 128 million visits. Studio further bounds receipts at 6,000
  grains and retains a complete JSON grain map. Those Pythian-owned limits are
  not evidence of a missing generic WFC feature. Reuse the verified continuation
  and profile bindings while separating finite work per pull from total session length.
