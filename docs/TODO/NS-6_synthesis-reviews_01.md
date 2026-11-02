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
- [Complete CI fanout — DONE](DONE/NS-6_ci-consumer-fanout_01.md) — complete CI565
  and matching delivery close the serial-timeout prerequisite

**Dev Notes:**

- 2026-11-02, Big Boss: E/tests/synthesis-review-source02 stages a read-only
  exact performance/mix/part binding and listening controls without integrating
  it into the repository yet. Ordinary native suite02 passes9,408,558 with zero
  unfreed blocks. Actual QA retains the same15.708808second position and Bass
  selection across Before/After; the targeted sound change keeps all other five
  stem hashes exact. Explicit QA uncertainty and Unicode note at frame377011
  save/reload; all33 QA jobs remain unchanged. Original retains its independent
  clock, with no autoplay. No operator musical verdict is inferred.
- Source01's new fixture wrongly treated generated+Original as generated-only;
  preserve the correct rejection/clean heap. Source02 separates the exact voting
  WAV before using the existing prepared factory. CLI setup initially omitted
  the service's external artifact root; setting the same host root resolves it.
  Native models/audio are not missing. E/runs/synthesis-review-qa01 retains proof.
- Actual desktop/390px screenshots expose excessive navigation above the question
  and technical frame wording in notes. Finish AC2 before integration/publication:
  prioritize question/player, contextual queue/help and human time while retaining
  canonical frame metadata. QA tab23 closes, viewport resets, exact QA54348 stops
  and handle23502 is collected. User tab2 and production data are untouched.

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
