# NS-4_layers_02 — Enforce provider timing, role and vocabulary compatibility

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-4)

**Description:**

Make semantic provider substitution and composition explicit across roles, pitch references and unequal time resolutions.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [LAYERS](../../LAYERS.md) · [LAYERED-STYLE](../../LAYERED-STYLE.md) · [MUSIC-CONTEXT](../../MUSIC-CONTEXT.md).

Completed 2026-09-21: the [provider contract and replacement APIs](../../INDEPENDENT-VOICES.md#provider-compatibility-and-replacement)
bind canonical vocabulary, explicit role or ordered joint roles, pitch basis,
musical domain, PPQ, source clock, scope and unknown semantics. Incompatible
contracts reject before publication; exact declared source conversions retain
original measurements. Named replacement uses an owned candidate WFC graph and
collective proof, preserving unrelated accepted states and pending edits.
The mapped wrapper reuses existing uniform/fixed-partition broadcast, start-tick,
whole-span, gap and endpoint rules. Relative-key and acoustic-palette semantics
remain explicitly unsupported; recording authenticity is not inferred.

Final checked stable FPC 3.2.2 Win32/Win64 fixtures pass replacement, rejection,
source ownership and mapping controls. Three demo scenarios per target reproduce
all 24 target-matched WAV/preview/MIDI/JSON artifacts from the accepted voice
baseline, with no unfreed blocks. Evidence and tested source identities are in
`build/qa-batch-03/`; commands and replay logs are under
`build/provider-compatibility/`. All five criteria pass. Accepted +4 NS-4 points
(+0.60 overall), moving NS-4 from 76% to 80% and overall from 58.4% to 59.0%.
No musical inference, genre or listening acceptance is claimed.

**Acceptance Criteria:**

- Declare required inputs/outputs, role identity, absolute/relative pitch basis, PPQ/source clocks, scope and unknown semantics for each supported provider.
- Support or explicitly reject incompatible vocabularies, roles, key references, palettes, PPQ resolutions and source-to-musical-time mappings before accepted state changes.
- Use existing uniform-grid and fixed-partition mappings for broadcasts, start-tick and whole-span relationships; preserve gap, endpoint and coverage rules.
- Demonstrate compatible provider replacement rebuilds the necessary dependencies while retaining unrelated states, and incompatible replacement preserves the accepted result with a useful diagnostic.
- Keep original measurements and any explicit conversions recoverable; matching display names or numeric token indices do not establish semantic compatibility.

**Blockers**

- [NS-4_layers_01.md](NS-4_layers_01.md)
