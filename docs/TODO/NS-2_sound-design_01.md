# NS-2_sound-design_01 — Expose the synthesis library as editable instrument and effect recipes

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Make the library's sound capabilities usable in the instrumental experiment. Use shared recipes and controls rather than isolated browser approximations. Stop on a control that has no audible backend effect.

Primary attribution: NS-2. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Provide a browsable, extensible instrument recipe catalog covering oscillator/noise, wavetable, additive and FM/PM capabilities, layered key/velocity zones, envelopes and modulation. Optional explicit sampler instruments are instruments, not hidden full-mix reconstruction.
- AC2: Route per-part filter, gain/pan, dynamics, delay/reverb and other implemented effect capabilities through primary library code. Show available, connected and unsupported capabilities honestly; no requirement to enable every processor in one piece.
- AC3: Allow editable recipes, scoped audition and saved patches in Studio through the same public-library contracts. Timbre/effect edits can reuse the musical plan, with dry/processed and isolated/mix comparison and controlled output levels.
- AC4: Preserve factory/envelope ownership, deterministic replay and release/effect history in the changed consumer. Show missing extension needs as concrete library gaps rather than duplicate adapter DSP.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)
- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: TSynthVoice, TInstrument, TStyleInstrument, source factories, automation, effects and buses are already implemented and exercised by native callers.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
