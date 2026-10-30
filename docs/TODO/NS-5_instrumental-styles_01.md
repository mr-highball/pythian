# NS-5_instrumental-styles_01 — Save, blend and reblend usable instrumental graph styles

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Make a style a reusable musical graph plus sound/control recipe for any caller-defined label. Select and combine parents by musical dimension, then generate actual instruments. Stop on equating source-window resemblance or serialized model averaging with this outcome.

Primary attribution: NS-5. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Save/reload actual provider models, role/timing schema, musical controls, instrument/effect recipes and source/operator origins. A new caller-defined label requires no built-in genre enum or private code edit.
- AC2: Select or weight different parents for rhythm/drums, harmony/bass/lead, expression and sound. Generate from the blend, save it, and use it as a parent in a further blend without losing independent controls or ancestry.
- AC3: Demonstrate actual instrumental Before/After comparisons and targeted edits, with retained unrelated parts and actionable schema/constraint conflicts. Learning, preferences and hard locks remain separate.
- AC4: Support the chosen phrase/form extension when present; no automatic benchmark prerequisites or fixed three-genre corpus floors. Claim usefulness only from the actual operator review, not from successful reload or tests.

**Blockers**

- [NS-3_style-vocabulary_01](NS-3_style-vocabulary_01.md)
- [NS-4_graph-controls_01](NS-4_graph-controls_01.md)
- [NS-2_sound-design_01](NS-2_sound-design_01.md)
- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: TSemanticStyle, provider-specific blend weights, repeated-evidence accounting and generation sessions already exist. This task makes them a usable instrumental Studio workflow.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
