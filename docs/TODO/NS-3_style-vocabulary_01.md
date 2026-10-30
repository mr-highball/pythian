# NS-3_style-vocabulary_01 — Learn reusable musical vocabularies from coarse classified corpora

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Teach from whole tracks or coarse passages across private collections without exhaustive annotation. Build musical/provider vocabularies that can drive instruments, with incremental additions and honest coverage. Stop on treating feature buckets or file processing alone as learned musical roles.

Primary attribution: NS-3. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Choose included recordings/ranges and caller classifications, then explicitly learn or update supported provider vocabularies. Explain which role/context/trait each source or operator choice actually contributes.
- AC2: Keep recording/run boundaries, unknown regions, original source timing and distinct training weights/generation preferences. New recordings and vocabulary rebuilds must not silently reinterpret existing token IDs or duplicate ancestry.
- AC3: Reuse bounded journal/intake/cache machinery for longer and multiple recordings; show included, processed, excluded and model-used duration separately. Support cancellation/reuse and name practical model/resource limits.
- AC4: Use the resulting saved providers in actual multi-part instrumental generation. Demonstrate a musically audible effect of an operator classification or corpus/model edit, and preserve unsupported mappings as explicit gaps.

**Blockers**

- [NS-3_experimental-learning_01](DONE/NS-3_experimental-learning_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Experimental learning is accepted; its bounded source-linked
  pitch/context and explicit cutoff/sustain recipes remove this prerequisite.
  Coarse whole-corpus vocabulary work remains unimplemented and earns no partial effort.
- 2026-10-29, Big Boss: Private corpus intake, classifications, journal storage, semantic styles, contribution accounting and saved model contracts exist. Raw-acoustic classifications currently affect identity rather than musical meaning; this task supplies actual mappings.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
