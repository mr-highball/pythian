# NS-4_layers_03 — Connect granular musical and sound controls

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Provide independent hard locks, choice preferences and sound/envelope controls at the semantic role level, below reusable base context.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [MODULATION](../MODULATION.md) · [WAVE-STYLE](../WAVE-STYLE.md) · [LAYERS](../LAYERS.md) · [INDEPENDENT-VOICES](../INDEPENDENT-VOICES.md).

**Acceptance Criteria:**

- Demonstrate independent key/BPM, rhythm, bass, chord/lead role, timbre and envelope controls through the public consumers; state the actual dependency closure for each edit.
- Keep source/training weights, generation preferences and hard constraints separate; conflicts and bounded failures cannot silently discard a requested control.
- Map supported pitch/gain/pan/cutoff and sound trajectories into explicit note-relative timing with declared hold/release behavior.
- Verify paired edits change only the intended role and actual dependents, preserving unrelated latent states and, where their sounding inputs are unchanged, exact audio.
- Ensure caller-owned control arrays/factories and captured results have explicit detached/borrowed lifetimes and useful unsupported-choice diagnostics.

**Blockers**

- [NS-4_layers_02.md](DONE/NS-4_layers_02.md)
