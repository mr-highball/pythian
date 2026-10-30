# NS-2_percussion_01 — Add explicit percussion roles and synthesized drum instruments

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Make kick, snare and hi-hat/percussive roles first-class musical decisions using existing noise/oscillator sources, envelopes, automation and filters. Audio/percussion adaptation belongs in Pythian. Stop if percussion is silently treated as a pitched chord member.

Primary attribution: NS-2. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Provide reusable editable synthesized kick, snare and hat recipes with gate/release, level and routing controls; do not require clips cut from a training mix.
- AC2: Represent percussion events and their relationship to the shared time/rhythm graph explicitly. Harmonic coverage and voice-leading constraints must apply only to the roles they describe.
- AC3: Generate drums together with bass, harmony and lead through the instrumental runtime. Drum-pattern or density edits preserve locked unrelated parts and keep the shared clock.
- AC4: Supply audible isolated and combined examples, meaningful silence/overlap/control checks, and a clear unsupported-case diagnostic. Operator feedback may reject the sound without preventing experimental access.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: Core wsNoise/oscillator voices, TVoiceAutomation, TGateEnvelope, TInstrument and buses exist. The current named-voice contract is pitch/harmony oriented; a percussion semantic mapping must be explicit.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
