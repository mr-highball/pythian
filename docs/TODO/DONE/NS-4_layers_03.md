# NS-4_layers_03 — Connect granular musical and sound controls

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-4)

**Description:**

Provide independent hard locks, choice preferences and sound/envelope controls at the semantic role level, below reusable base context.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [MODULATION](../../MODULATION.md) · [WAVE-STYLE](../../WAVE-STYLE.md) · [LAYERS](../../LAYERS.md) · [INDEPENDENT-VOICES](../../INDEPENDENT-VOICES.md).

Completed 2026-09-21: public named-role preferences remain separate from training
weights and hard locks, with explicit dependency closures, detached control
arrays and preserved unrelated accepted states and pending edits. Note-relative
pitch, gain, pan, cutoff, timbre and envelope edits preserve unrelated rendered
stems. Existing key/BPM/rhythm and recorded-envelope consumer evidence completes
the declared control scope; this does not accept new recorded-timbre inference.
Final QA accepted all five criteria on checked stable Win32/Win64. Both maintained
voice fixtures and six demo runs pass without leaks; all 24 WAV/JSON/MIDI/preview
artifacts match target-specific baseline source `c130452`. A no-op timbre fixture
edit was corrected to a distinct waveform before acceptance; the first failure
is retained. Commands, criterion review and tested hashes are ignored under
`build/granular-controls/` and `build/qa-batch-04/`. Credit: +4 NS-4 / +0.60 overall.

**Acceptance Criteria:**

- Demonstrate independent key/BPM, rhythm, bass, chord/lead role, timbre and envelope controls through the public consumers; state the actual dependency closure for each edit.
- Keep source/training weights, generation preferences and hard constraints separate; conflicts and bounded failures cannot silently discard a requested control.
- Map supported pitch/gain/pan/cutoff and sound trajectories into explicit note-relative timing with declared hold/release behavior.
- Verify paired edits change only the intended role and actual dependents, preserving unrelated latent states and, where their sounding inputs are unchanged, exact audio.
- Ensure caller-owned control arrays/factories and captured results have explicit detached/borrowed lifetimes and useful unsupported-choice diagnostics.

**Blockers**

- [NS-4_layers_02.md](NS-4_layers_02.md)

**Dev Notes:**

- Repaired validation case: the first paired sound edit used an equivalent waveform and therefore did not demonstrate an audible-input change. It was corrected to a distinct waveform before acceptance; retain that failure alongside the final [granular-control evidence](../../INDEPENDENT-VOICES.md#granular-musical-and-sound-controls).

- Follow-up: these controls do not establish recorded-timbre inference; that remains with [evolving sound](../NS-3_timbre_01.md).
