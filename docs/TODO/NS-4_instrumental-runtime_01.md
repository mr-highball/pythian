# NS-4_instrumental-runtime_01 — Connect the musical graph to reusable instrumental synthesis

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

One primary Pascal entry point turns an actual coupled WFC musical plan into performed instrumental audio. Reuse named/mapped sessions, instrument planning, exact clocks, buses and the scheduler. The first example may use authored symbolic training material and operator context; label that origin. Stop on a hidden grain-render fallback or a second solver/renderer.

Primary attribution: NS-4. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Generate distinct bass, chord/harmony and lead parts through real dependent WFC passes, with explicit time, key/tempo, register, rhythm and instrument bindings. Start with existing supported graph contracts; expose actual graph dimensions, named passes, vocabularies and dependency edges in the result.
- AC2: Perform generated note events through Pythian source-free instrument voices and the primary effects/bus/scheduling path. The first consumer must render with source recordings unavailable; source audio is reference material, not its output sound bank.
- AC3: A changed seed or musical constraint changes a real plan; deterministic replay repeats it. Report contradictions with the involved pass/constraint and leave the previous playable result intact.
- AC4: Provide one maintained public-library caller and a bounded playable multi-part result. Check event timing, release tails, cleanup and changed-path native/portable behavior where that implementation is shared.

**Blockers**

- None. Existing implemented library APIs are the starting point; no new formal benchmark is a prerequisite.

**Dev Notes:**

- 2026-10-29, Big Boss: Existing pythian.wfc.voices, pythian.wfc.layers, pythian.wfc.duration.stream, pythian.instrument, pythian.music.render and pythian.schedule. The voices/layers demos already connect authored musical models to native sound.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
