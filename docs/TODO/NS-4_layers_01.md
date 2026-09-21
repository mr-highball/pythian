# NS-4_layers_01 — Deliver reusable named harmony and voice passes

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Move reusable harmony/rhythm/independent-voice coordination out of demo-only code into companion APIs using actual WFC passes and caller-declared role identities. This task includes resolving the interrupted, unvalidated harmony/rhythm/voice descriptor extension in pythian.wfc.providers.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 6 goal percentage points (0.90 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [GRID-STYLE](../GRID-STYLE.md) · [INDEPENDENT-VOICES](../INDEPENDENT-VOICES.md) · [LAYERS](../LAYERS.md) · [PRECURSOR-BOUNDARIES](../PRECURSOR-BOUNDARIES.md).

**Acceptance Criteria:**

- Inspect the paused provider extension against the last verified provider-description package; complete and validate it for this consumer or remove the unsupported draft. Do not count the unfinished edit as delivered.
- Expose owned models, typed choices and explicit role/pitch identities for harmony, rhythm and independent bass/chord/lead or other declared roles, without claiming those roles were inferred.
- Implement named role constraints and dependency-scoped regeneration through the existing WFC graph; retain exact unrelated accepted states and pending edits, and preserve accepted output on expected failures.
- Retain observed joint/collective harmony, rhythm, range and voice-pair constraints, including chords, holds, rests and unknown/unsupported inputs; no replacement solver or flattened all-voice vocabulary.
- Replace the demo's duplicated reusable planning code with the public API and verify deterministic musical/audio replay plus an independent caller that changes one role.
- Preserve the eight musical-layer bound or document a concrete consumer justification; account separately for any required bounded companion proof passes.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

