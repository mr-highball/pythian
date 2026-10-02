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

Execution status: ready; Big Boss owns assessment and implementation for this
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

- 2026-10-02, Big Boss: current WFC continuation is already incremental, but
  the journal renderer binds its output to a finite PCM16 WAV writer, 32,768
  total grains and 128 million visits. Studio further bounds receipts at 6,000
  grains and retains a complete JSON grain map. Those Pythian-owned limits are
  not evidence of a missing generic WFC feature. Reuse the verified continuation
  and profile bindings while separating finite work per pull from total session length.
