# NS-5_instrumental-styles_01 — Save, blend and reblend usable instrumental graph styles

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** In progress
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

- [NS-3_style-vocabulary_01](DONE/NS-3_style-vocabulary_01.md)
- [NS-4_graph-controls_01](DONE/NS-4_graph-controls_01.md)
- [NS-2_sound-design_01](DONE/NS-2_sound-design_01.md)
- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-11-01, Big Boss: AC1 now has an actual complete instrumental consumer.
  The v3 semantic archive retains nine corpus providers, clock/role schema,
  source and proposal origins, independent learning weights, preferences/locks,
  primary instrument/envelope/modulation and six-part/master effect recipes,
  expression, form and bounded stream settings. Capture uses the actual learner's
  admitted samples, not re-tokenized guesses or source PCM. Its observed-clock
  origin/rounding preserves fractional source phase across selected gaps.
  The owned replay uses the existing instrumental stream; it is not a second
  renderer. Native and actual pas2js full six-stem/model/decision replays pass
  after input/style destruction. Invalid clocks/buses/preferences, unsupported
  gate shortening, corruption and construction cancellation reject. Full local
  native/pas2js qualification passes; exact published CI must finish before
  closing AC1/count.
  No task effort is accepted. Explicit external sampler resolution, larger
  semantic evidence budgets, ordinary Studio saving, selective instrumental
  sound/expression parents and useful blends/reblends are not claimed by this
  component. Instrumental CreateBlend rejects explicitly until AC2 is connected.
  Evidence: E/tests/styles-binding-native03, styles-binding-js03 and
  E/runs/instrumental-styles-20261101-boss. Earlier missing output-directory,
  missing fixture import and PowerShell path-escape failures remain in the
  packet; no product workaround was inferred from those harness errors.

- 2026-11-01, Big Boss: bounded archive component passes native style/blend
  replay,23 unchanged original archive/sound artifacts,41,896 progress/
  cancellation checks with clean heaps, and both complete actual pas2js style/
  blend fixtures. The mixed Unicode source-group/domain archive has identical
  native/JS SHA25694547ac3b2bbbe2e14e3a2a135adbdf602b498a6c9afbb648f39c077b29b1e65.
  unicode02's failed fixture mixed scalar text with a native literal through the
  host code page; unicode03 uses scalar operands throughout and passes. Its
  failure/source snapshot remain. Native measurement-profile bytes and JS
  measurement-profile bytes are not claimed identical; within-target saved
  audio replay and all original native bytes pass. The primary byte stream now
  owns transfer/storage, with retained archive progress and no native pointer
  I/O. Maintained optional portability orchestration includes both fixtures.
  This is a required AC1 component, not full AC1: actual nine-provider corpus
  binding, complete instrument/mix/control recipes, style UI and blend/reblend
  consumers remain. No effort is accepted. Consecutive nonclosing count is1;
  next deliver the actual instrumental style binding or reassess after another
  nonclosing batch. Full source CI remains required after publication; stable
  sound-editor deployment is unchanged. Evidence: styles-before01,
  styles-native01, styles-js01, styles-unicode02/03 under E/tests.

- 2026-11-01, Big Boss: selected after sound-design acceptance; inherited
  consecutive nonclosing count0. AC1 batch first removes the known native-only
  semantic archive I/O through primary bounded byte streams and scalar text.
  Preserve native archive/model/sound identities and cancellation/ownership;
  exercise real saved-model generation on actual pas2js. The current corpus has
  nine providers while the older semantic archive admits eight; its explicit
  instrumental/context/percussion binding and full primary sound/control recipe
  attachment are still required before complete AC1 or task acceptance. Reuse
  the semantic contracts rather than introducing a parallel style renderer.
  Stop this bounded archive step at actual cross-target persistence/generation
  or a demonstrated next blocker. It earns no task effort by itself. Baseline
  and changed evidence belong under E/tests/styles-* and
  E/runs/instrumental-styles-20261101-boss; live Studio stays unchanged.

- 2026-11-01, Big Boss: the sound-design prerequisite is accepted after actual
  Studio editing/replay, complete CI550 and checked deployment. All listed
  prerequisites are now accepted; this task is Ready. Existing semantic models,
  vocabulary identities and primary instrument/mix recipes must be reused.
  Saving only a sound setup is not saving an actual graph style. No effort or
  usefulness is accepted by this readiness change.

- 2026-10-30, Big Boss: The new musical corpus and native semantic reblend now
  share weighted, sample-boundary-preserving learning. Native blend/progress
  regressions pass. An optional pas2js archive probe exposes the existing native
  TMemoryStream byte-buffer calls in semantic.style (first rejection at line254).
  Address that archive portability within this task's actual save/blend consumer;
  it does not block the portable musical-corpus model-text/runtime path. Do not
  describe the semantic archive as newly browser-qualified. Evidence:
  E-drive musical-corpus-20261030-boss/semantic.blend-js-compile.log.
- 2026-10-29, Big Boss: TSemanticStyle, provider-specific blend weights, repeated-evidence accounting and generation sessions already exist. This task makes them a usable instrumental Studio workflow.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
