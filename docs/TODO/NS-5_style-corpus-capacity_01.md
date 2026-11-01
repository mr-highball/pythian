# NS-5_style-corpus-capacity_01 - Save the complete supported musical corpus as a reusable style

[Active tasks](README.md) · [Styles](NS-5_instrumental-styles_01.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 4/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Make instrumental style persistence handle the actual source/run/observation
capacities already supported by the musical corpus producer. A long playlist
must not generate successfully and then encounter an unrelated small-fixture
archive ceiling. Preserve exact admitted observations, models, source clocks,
coverage/origins and independent blend controls without rereading source PCM.

Primary attribution: NS-5. This is newly demonstrated integration work beyond
the prior estimate: the producer admits64 sources,1024 runs and65536 weighted
observations, while the inherited semantic path admits32 sources,256 runs and
at most4096 observations with an additional observation-count-squared estimate.
These are structural/work limits, not inference-quality or musical acceptance
gates. The existing seven-unit parent task keeps its original outcome/estimate;
this distinct capacity outcome adds four units to current scope.

**Acceptance Criteria:**

- AC1: Capture/save/reload a complete supported instrumental corpus at the
  producer's source/run/observation capacities, under explicit byte/memory/work
  bounds. Keep all nine actual providers, every admitted contribution, source
  influence, gaps, original clocks, proposal origins and primary sound/form
  recipes. Never silently trim or substitute evidence to make an archive fit.
- AC2: Reuse the shared learner and existing progress/cancellation contract.
  Bound actual validation/relearning work without rejecting valid repetitive
  corpora solely through an observation-count-squared heuristic. Unsupported
  complex/oversized input must stop with a useful limit and preserve prior data.
  Selective blends/further blends retain explicit supported capacity limits and
  correct repeated-evidence accounting.
- AC3: Native and actual pas2js consumers exercise large complete snapshots,
  long-recording original coordinates, actual model/weight identities, detached
  ownership, cancellation/retry and generated mix/stem replay. Include an actual
  ordinary corpus boundary; short synthesized output may inspect a long learned
  corpus without allocating a duration-sized score or loading source PCM.
- AC4: Wire the ordinary native generation consumer to retain a complete style
  candidate from its actual corpus, using the same boundary. Verify the artifact
  and saved model/origin identities through an ordinary native playlist job.
  An optional style snapshot outside a supported byte/work limit cannot destroy
  or misreport an otherwise completed song; retain a useful unavailable reason.
  The parent task owns the later Studio save/blend controls and operator review.
  No new benchmark, microclip-labeling, transcription-confidence or genre gate.

**Blockers**

- [Coarse corpus providers](DONE/NS-3_style-vocabulary_01.md)
- [Primary sound recipes](DONE/NS-2_sound-design_01.md)
- [Ordinary instrumental jobs](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-11-01, Big Boss: discovered while preparing the real Studio consumer of
  the new nine-provider snapshots/blends. Evidence is the live constants in
  `pythian.wfc.musical.corpus`, its ordinary playlist caller's65536 budget, and
  semantic DefinitionIO/ValidateDefinition/RelearnBlend limits. This is a real
  mismatch with an accepted producer; small source/reblend fixtures do not prove
  long-corpus saving. Select only after current repaired source's exact CI553
  finishes and the two-nonclosing-batch reassessment recorded in WORK. Build on
  the actual implemented parent APIs without introducing a task dependency cycle
  or a second archive/renderer. Keep outputs under the dedicated E workspace.
