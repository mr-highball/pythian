# NS-4_graph-workbench_01 — Show and edit the real time-by-role WFC graph in Studio

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Provide a musical graph workbench whose display and controls describe the actual backend model. Time is the primary horizontal axis; roles/voices are visible lanes. Named passes and any additional axes have explicit meaning. Stop on an attractive visualization disconnected from the executed graph.

Primary attribution: NS-4. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Display actual dimensions per graph/pass, time units, musical role mapping, model vocabulary/state counts, boundaries and dependency edges for the selected generation. Distinguish graph dimensions, passes, solver chunks and audio buffers.
- AC2: Inspect context, rhythm, harmony and part choices at a selected passage, with plain-language constraints and explanations for contradictory or unavailable choices. Use progressive detail so mobile use remains practical.
- AC3: Edit time ranges, add/remove supported roles and change their models or domain constraints. The resulting request must reach the primary graph API and the saved artifact must reproduce the displayed plan.
- AC4: Provide waveform/audio plus a note/event or piano-roll view, synchronized passage playback and per-part audition. Verify actual desktop/narrow interactions and recovery without losing edits.

**Blockers**

- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Retain the concrete unguided authored conflict from
  [musical controls](NS-4_graph-controls_01.md): seed731, root preference60,
  per-role activity40/velocity130, eight cells, C major. Actual harmony-voice pass3
  rejects in batch-1793400196578-896606882. Studio now reports the conflict and
  restores exact controls; do not call choosing the guide a repair of unguided
  generation. Use this preserved case for AC2's actual pass/choice diagnostics.
- 2026-10-29, Big Boss: The musical adapters already expose named providers, contracts, model text, captured states, constraints and selective solve reports. Current voice passes use aligned N x 1 x 1 graphs; changing the visual layout alone is not a new solver dimension.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
