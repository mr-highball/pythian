# NS-4_layers_02 — Enforce provider timing, role and vocabulary compatibility

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Make semantic provider substitution and composition explicit across roles, pitch references and unequal time resolutions.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [LAYERS](../LAYERS.md) · [LAYERED-STYLE](../LAYERED-STYLE.md) · [MUSIC-CONTEXT](../MUSIC-CONTEXT.md).

**Acceptance Criteria:**

- Declare required inputs/outputs, role identity, absolute/relative pitch basis, PPQ/source clocks, scope and unknown semantics for each supported provider.
- Support or explicitly reject incompatible vocabularies, roles, key references, palettes, PPQ resolutions and source-to-musical-time mappings before accepted state changes.
- Use existing uniform-grid and fixed-partition mappings for broadcasts, start-tick and whole-span relationships; preserve gap, endpoint and coverage rules.
- Demonstrate compatible provider replacement rebuilds the necessary dependencies while retaining unrelated states, and incompatible replacement preserves the accepted result with a useful diagnostic.
- Keep original measurements and any explicit conversions recoverable; matching display names or numeric token indices do not establish semantic compatibility.

**Blockers**

- [NS-4_layers_01.md](NS-4_layers_01.md)

