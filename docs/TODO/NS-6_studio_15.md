# NS-6_studio_15 — Expose existing delay and reverb through the shared effects catalog

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The core already owns `TModulatedDelayEffect` and `TReverbEffect`. Extend the
shared catalog and Studio rack to use them without reimplementing their DSP.
Choose meaningful controls for echo/modulated delay and reverb, with explicit
tail behavior when listening and saving a derived clip.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one further unearned delivery_04 point transfers here (5 → 4).
All independent reproduction criteria remain required. Scoping earns no credit.

Execution status: follows the selected filter/transport batch, Big Boss solo.
Next deliverable: usable time-based effects in the canonical rack, preserving
source/recipe lineage. Closing evidence: actual native impulse/continuation and
saved-tail checks plus mobile/desktop preview/save. Stop at a missing DSP
primitive; give the gap an owner rather than inventing a browser substitute.

**Acceptance Criteria:**

- AC1: Native and pas2js use the same catalog definitions for delay/modulation
  and reverb. Controls have useful names/defaults and only expose settings the
  existing core actually uses. Native creation calls those core implementations.
- AC2: Preview/save makes tail length and truncation explicit. Ordered/bypassed
  stages, reset semantics, work/memory limits and exact output duration remain
  enforced. A longer derived clip retains its original input range and recipe;
  appended tail frames never become claimed source frames.
- AC3: Native tests verify delayed/reverberant energy, deterministic reset,
  ordering and invalid settings. Browser checks cover adjustment, replay,
  preview invalidation, tail length and saved-clip playback on desktop/narrow UI.

**Blockers**

- [NS-6_studio_12.md](NS-6_studio_12.md)

**Dev Notes:**

- 2026-10-02, Big Boss: the operator's consolidation instruction prompted a
  wider core inventory. `src/pythian.delay.modulated.pas` and
  `src/pythian.reverb.pas` already implement the required effect classes. Their
  effect-state/tail contract is distinct from exposing six missing biquads;
  this linked task owns that gap without expanding the current acceptance batch.
