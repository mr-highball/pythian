# NS-4_graph-controls_01 — Coordinate musical dimensions and selective regeneration

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Expose coordinated context, pitch/register, rhythm/groove, articulation, dynamics, timbre/effects and operator-defined musical affect through real graph/control relationships. Use additional axes or passes where useful; grow the schema from audible needs rather than a fixed giant grid.

Primary attribution: NS-4. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Provide explicit dependencies and controls for key/tempo, harmonic choices, role pitch/register, rhythmic activity and expression. Define how each control constrains a pass, changes a preference, or maps to synthesis automation.
- AC2: Support hard locks, soft preferences and scoped regeneration of a role, passage or dependent closure. A user can retain drums while changing harmony/lead, or retain the score while changing sound, when dependencies permit.
- AC3: Represent coarse affect controls such as energy, density or tension by editable documented mappings. Do not pretend a label is automatically understood or scientifically inferred.
- AC4: Demonstrate paired actual instrumental outputs and preserved unrelated accepted states. Report contradictions visibly, allow revision, and avoid silently relaxing a user constraint or retraining when only generation settings change.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: TLearnedLayerSession/TNamedVoiceSession preferences, masks, provider replacement and dependency closure already exist. Add domain mappings and expose them through one shared consumer.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
