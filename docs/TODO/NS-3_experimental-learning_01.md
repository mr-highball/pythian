# NS-3_experimental-learning_01 — Turn available WAV analysis into editable musical graph proposals

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Use the existing key/tempo/onset/pitch/dynamics/timbre analyses to propose musical providers for instrumental generation. Experimental access does not depend on a completed accuracy benchmark. Keep source, proposal and operator decisions distinct. Stop on hidden substitution of source grains for synthesized parts.

Primary attribution: NS-3. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Analyze an operator-selected recording/range or imported/microphone input using existing Pascal implementations. Present available tempo/key, rhythmic, pitch/event and sound observations with concise Experimental labeling and alternatives where available.
- AC2: In Studio, allow the operator to accept, correct, bypass or manually supply context and part assignments. Unsupported polyphonic separation must remain visible; authored seeds or manual choices can still drive a full instrumental experiment.
- AC3: Map selected proposals into real semantic provider vocabularies, constraints and instrument/automation settings. Produce synthesized comparisons against explicit original reference playback; retain original coordinates and the actual settings used.
- AC4: Saving corrections/feedback preserves lineage without silent training. Explicit Learn or Regenerate changes only the requested learning/model or generation scope. Keep known failed observations as evidence, not claims of established accuracy.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)
- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: Monophonic pitch/duration, candidate beat/tonal/onset analysis, sound fitting, MIDI previews and semantic provider APIs exist. General reliable mixed-WAV notes/roles/form remain incomplete; they are experiments rather than prerequisites for first synthesis.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
