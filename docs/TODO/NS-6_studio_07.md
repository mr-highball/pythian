# NS-6_studio_07 — Train mixed-format corpora with original-clock lineage

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Let a saved Studio corpus combine supported recordings with different sample
rates or mono/stereo layouts through bounded native preparation before actual
raw-acoustic WFC learning. Preserve original recordings, classifications,
source-family identity and exact selected original-clock ranges. Reuse existing
[streamed conversion](../DSP.md) rather than add a new DSP algorithm or claim
musical inference acceptance.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [delivery_03](NS-6_delivery_03.md),
which retains every packaging/extraction criterion. Accepted credit is unchanged.
This owns connected corpus preparation; it earns no second core-resampler credit.

Execution status: ready future follow-up after accepted job/library engineering;
implementation is not selected in this batch. Current jobs reject mismatched
rates/channels. Next deliverable:
declared original-to-prepared clock/channel recipe, bounded asynchronous native
conversion and an actual mixed-format saved-model/WFC audition consumer.
Closing evidence: immutable mappings/identities, deterministic conversion and
saved reuse, real mixed 44.1/48-kHz stereo/mono generation, and independent
desktop/narrow preparation/reload checks. Stop on an unverifiable mapping,
source replacement, hidden exclusion/conversion, lost family/use restriction or
an unsupported resource requirement. No implementation or media run is selected
by this task record, and no criterion or credit is accepted.

**Acceptance Criteria:**

- AC1: Preflight a mixed-rate/channel saved project against a declared prepared
  clock/layout and supported native conversion policy. Show original versus
  prepared geometry and actual selected/used scopes. Keep weights and caller
  classifications source-bound; explicitly reject unsupported inputs without
  dropping recordings or silently changing partitions.
- AC2: Stream bounded asynchronous conversion with truthful progress,
  cancellation/recovery and runtime/memory/storage limits. Retain exact rational
  original-to-prepared frame mapping, declared rounding, filter/tail and channel
  policy, and measured headroom/clipping. No implicit musical time warp, fabricated
  silence or private external converter may substitute for the native path.
- AC3: Save immutable verified prepared identities and recipes bound to original
  bytes, metadata, frame ranges and policy. Preserve original source-family,
  provenance, license and exposure/use restrictions. Prepared variants are
  derivatives, never independent originals or untouched evaluation material;
  evaluation inputs remain excluded from training.
- AC4: Consume the prepared mappings in actual raw-acoustic WFC learning and
  generation, save/reload the model, and retain original plus prepared clock
  evidence in its receipt and listening publication. Verified reuse includes
  conversion configuration; changing that configuration creates a new identity
  without rewriting previous models, sources or classifications.
- AC5: Independently verify the complete mixed-format consumer using at least
  one 44.1-kHz stereo and one 48-kHz mono recording, disjoint original ranges,
  conversion/reload replay and exact short audition clocks. Include corrupt/stale
  source and recipe, bound/rounding, interruption, retry and duplicate-use cases.
  Exercise current desktop/narrow preflight through completed WFC/listening
  publication. Numerical/replay evidence does not imply musical acceptance.

**Blockers**

- [NS-6_studio_04.md](DONE/NS-6_studio_04.md)
- [NS-6_studio_02.md](DONE/NS-6_studio_02.md)

**Dev Notes:**

- 2026-10-01, Neo / Big Boss: current same-clock raw jobs remain unchanged.
  The accepted [corpus_05](DONE/NS-5_corpus_05.md) explicitly rejects resampling
  and downmix parent mappings. [Corpus_06](NS-5_corpus_06.md) consumes that intake;
  [scale_02](NS-5_scale_02.md) owns complete semantic workload/recovery;
  [integration_01](NS-4_integration_01.md) owns accepted recorded semantic
  providers. None supplies this operator-owned conversion/mapping consumer.
  The new task makes the required gap explicit without weakening those criteria,
  reopening scientific stops or awarding credit. Native submitted failures start
  at zero for this unimplemented outcome; existing task failures remain intact.
