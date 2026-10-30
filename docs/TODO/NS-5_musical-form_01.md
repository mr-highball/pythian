# NS-5_musical-form_01 — Generate evolving phrases, sections and useful variation

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Give instrumental generation musically meaningful repetition and development over time. Begin with editable authored/experimental phrase material, then allow learned proposals. Stop on renaming solver chunks as musical sections or copying an input arrangement as the generated result.

Primary attribution: NS-5. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Represent phrases, motifs, sections and transitions as explicit reusable graph/provider decisions. Permit operator arrangement and repetition/variation controls, including changing energy/density across sections.
- AC2: Connect structural decisions to bass, percussion, harmony and lead constraints on the shared timeline. Retain selected motifs or parts while varying dependent material, with clear boundary/hold semantics.
- AC3: Render a sustained multi-section instrumental piece and expose section audition and targeted regeneration in Studio. Retain weak passages and use actual operator listening to choose the next model change.
- AC4: Save/reload the structure and verify meaningful boundary, replay and continuation behavior. Existing authored long-form templates can bootstrap material, but must remain editable and correctly labeled.

**Blockers**

- [NS-4_graph-controls_01](NS-4_graph-controls_01.md)
- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: The core has an authored 144-bar two-part composition and musical scheduling, but semantic styles explicitly lack a phrase/form vocabulary. Build the missing representation and integration using existing primitives.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
