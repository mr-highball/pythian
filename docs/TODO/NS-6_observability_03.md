# NS-6_observability_03 — Offline rendering and separation checkpoints

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Extend the remaining whole-clip DSP entry points with progress from their primary
engines. Separation permits two billion planned work visits, and whole-note/grain
render helpers can hide substantial work even though stream consumers have clocks.
North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Next deliverable: measured separation passes and bulk rendering callbacks, with
CLI forwarding. Closing evidence: output parity and cancellation in each expensive
pass. Stop on a second renderer, per-sample callbacks or changed audio.

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

- [Shared callbacks and audit — DONE](DONE/NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-03, Big Boss: `THarmonicPercussive.Create` has full spectrogram and
  median passes without callbacks; `RenderNoteSequence` delegates to whole-clip
  `RenderFrameTones`. Existing streaming clocks do not instrument these bulk APIs.
  See [audit](../OBSERVABILITY.md). These paths remain open, not certified short.
