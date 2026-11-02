# NS-6_synthesis-reviews_01 — Make Studio the listening and model-refinement workbench

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Use Studio to test whether the graph/synthesis concept works and which dimension should change next. Preserve the existing answer store and historical reconstruction feedback. Stop on another unexplained review queue or exhaustive manual microclip labeling.

Primary attribution: NS-6. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Queue actual synthesized experiments with one concise question, visible changed graph/controls, optional notes and Save/Next. Provide Original reference, Before/After, full mix and stems/part solo with synchronized useful seeking.
- AC2: Offer clear tabs/steps, contextual modal help and next actions on desktop and phone. Keep reference playback and generated instrumentation distinct; no hidden autoplay or competing audio.
- AC3: Saving binds feedback to the exact musical plan, graph/schema, seed, instrument recipes and source/proposal choices. It never silently retrains. A deliberate next experiment can reuse the accepted parts and expose the intended change.
- AC4: Read the actual saved response and record the concrete design decision it supports. Retire old raw-reconstruction experiments from new work while retaining their audio, answers and history.

**Blockers**

- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)
- [Complete CI fanout](NS-6_ci-consumer-fanout_01.md) — actual prerequisite to
  publishing/deploying further review changes after CI563's serial timeout

**Dev Notes:**

- Big Boss, current form QA: native player Pause stops audio but the section
  announcement can still say `Playing A return.` AC2 should synchronize that
  short status with the actual player state. The retained phone screenshot and
  DOM media clock are in the E-drive projected-domains packet. This cosmetic
  follow-up does not block the completed original unguided musical job.

- 2026-11-01, Big Boss: reuse the current form experiment and prepared-listening
  factory. Native Unicode review publication/response/replay is repaired under
  [listening UTF-8](DONE/NS-6_listening-utf8_01.md), not a new comparison framework.
  The390px saved-note view keeps exact Unicode, but its narrow Remove button
  wraps one word over several lines. AC2 should give that note action enough
  width. This does not block the current question or justify another broad audit.

- 2026-10-29, Big Boss: Current listening projection, prepared comparisons, review lineage, navigation, source playback and saved responses are reusable. Current answers concern reconstruction only and do not establish instrumental feasibility.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
