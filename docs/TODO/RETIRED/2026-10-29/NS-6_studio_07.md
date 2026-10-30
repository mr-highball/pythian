> **Retired — 2026-10-29.** Historical unfinished ticket; no current effort or acceptance. See [disposition/replacement](README.md) and the [active goal](../../../GOAL.md). The original body below is historical, not an implementation instruction.

# NS-6_studio_07 — Train mixed-format corpora with original-clock lineage

[Task index](legacy-catalog.md) · [Task flow](../../../history/TASKFLOW-2026-10-29.md) · [North star](../../../history/MILESTONES-2026-10-29.md#ns-6)

**Description:**

Let a saved Studio corpus combine supported recordings with different sample
rates or mono/stereo layouts through bounded native preparation before actual
raw-acoustic WFC learning. Preserve original recordings, classifications,
source-family identity and exact selected original-clock ranges. Reuse existing
[streamed conversion](../../../DSP.md) rather than add a new DSP algorithm or claim
musical inference acceptance.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [delivery_03](NS-6_delivery_03.md),
which retains every packaging/extraction criterion. Accepted credit is unchanged.
This owns connected corpus preparation; it earns no second core-resampler credit.

Execution status (2026-10-27): explicit mixed-format preparation is implemented
in the native job and shared Studio settings paths. AC3/AC4's immutable identity,
actual WFC consumption, saved reuse and publication checks pass on authored
44.1-kHz stereo / 48-kHz mono inputs. AC1/AC2's native preflight, resource,
mapping, progress and interruption checks pass. Actual desktop/narrow interaction
and the complete recorded workload qualification in AC5 remain open; this task
stays open and its one point remains unearned.

Batch criterion: preserve original-clock lineage while converting selected
ranges and consuming them in actual WFC learning. Deliverable: one declared
clock/layout/volume recipe, bounded native conversion and saved-model finite/live
consumers. Closing evidence: immutable mappings/identities, deterministic
conversion/reuse and actual mixed-format generation. Stop on an unverifiable
mapping, source replacement, hidden exclusion/conversion, lost family/use
restriction or an unsupported resource requirement. Numerical acceptance is
scoped to the checked authored workload, not musical learning or many-hour scale.

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

- [NS-6_studio_04.md](../../DONE/NS-6_studio_04.md)
- [NS-6_studio_02.md](../../DONE/NS-6_studio_02.md)

**Dev Notes:**

- 2026-10-27, Big Boss / Spike / Spiegel: Spike owns the primary bounded range
  reader, native preparation unit and fixture; Spiegel owns jobs/preflight,
  Studio settings and recovery checks; Big Boss owns worker/reference/progress
  integration, build registration, deployment and final judgment. No WFC source
  change or generic WFC gap was demonstrated. All implementation remains Pascal.
  The existing centered sinc resampler and PCM16 writer are reused. Range reads
  enforce selected endpoints; no outside passage samples or extra filter tail
  enter the derivative. Mono duplicates, stereo averages after filtering, and
  explicit uniform volume precedes PCM16 quantization. Over-scale audio rejects
  with a request to lower preparation volume; it is not silently clipped.
- AC3/AC4 engineering evidence: original source hashes, ranges, classifications,
  family, partition, weight, provenance and use restrictions remain bound.
  Evaluation sources stay excluded. Atomic verified recipe/WAV pairs use a
  content-addressed cache; cold and warm receipts match. Configuration changes
  produce new training identities, and corrupt cached audio fails before model
  reuse or output publication. Prepared grain coordinates retain exact rational
  original positions, explicitly described as filter-footprint centers. Listening
  references still play original-clock ranges, with preparation context attached.
- Checked FPC 3.2.2: preparation 37,651 assertions on Win64 and Win32; independent
  Win64 execution and the existing streaming-resampler numerical regression
  pass. Native jobs pass 87 checks. Actual mixed raw-acoustic WFC learning consumes
  four disjoint ranges from authored 44.1-kHz stereo and 48-kHz mono sources,
  saves/reloads the model and renders exactly 20 seconds at 48-kHz stereo.
  Complete bounded live PCM matches the finite output byte for byte. The final
  root mixed fixture passes 1,126 checks; independent execution passes 1,135
  (live polling affects assertion counts). All report zero leaks. Original
  same-format worker/library regressions pass 376 checks. The changed pas2js
  recovery/settings consumer passes 40 DOM checks; live policy passes 21; all
  four web programs compile. These are not visual or physical-phone evidence.
- Development repairs/evidence: preparation estimates were consolidated into
  one native plan; a first jobs run used PATH FPC 3.3.1 and was replaced by an
  explicit checked 3.2.2 run. A deep E-drive test cwd exceeded Windows path limits
  in retained library staging; the failure is retained and the complete fixture
  passes from the short E-drive service cwd. Big Boss corrected an early progress
  statement made before that fixture finished. The preflight main paragraph now
  shows format/storage, while expandable Preparation details contains per-source
  times/geometry and filter costs. Preparation audio errors reach job history
  without exposing unrelated I/O failures. No formal implementation QA submission
  failed in this batch; both helpers independently checked the other components.
  Evidence: dedicated E-drive `build/tests/runs/studio-{mixed,preparation}-20261027-*`
  logs, manifests and immutable fixture outputs; no private media or answers
  were used in these checks.
- The final matched service/worker and twelve web assets are deployed to the
  fixed stable slot. Guarded restart found no active/pending job, all fourteen
  hashes and the served Studio script match, and LAN HTTPS returns 200. All
  5,951 existing private JSON/JSONL hashes are unchanged. The short E-drive cwd
  and explicit `PYTHIAN_STUDIO_PREPARED_CACHE` keep new staging/cache on E;
  no QA browser, worker or playback remains. Independent focused record review
  confirms unchanged 53 open/57 DONE and 52.45 credited; the task remains open.
- Remaining stop: in-app browser inventory is empty and creating an `iab` tab
  reports unavailable. No tab, browser playback or screenshot was produced.
  AC5 desktop/narrow preflight-to-listening and recorded workload qualification
  remain required. No automatic retraining, semantic-inference acceptance,
  sustained musical verdict or milestone credit follows from these checks.
- 2026-10-01, Neo / Big Boss: current same-clock raw jobs remain unchanged.
  The accepted [corpus_05](../../DONE/NS-5_corpus_05.md) explicitly rejects resampling
  and downmix parent mappings. [Corpus_06](NS-5_corpus_06.md) consumes that intake;
  [scale_02](NS-5_scale_02.md) owns complete semantic workload/recovery;
  [integration_01](NS-4_integration_01.md) owns accepted recorded semantic
  providers. None supplies this operator-owned conversion/mapping consumer.
  The new task makes the required gap explicit without weakening those criteria,
  reopening scientific stops or awarding credit. Native submitted failures start
  at zero for this unimplemented outcome; existing task failures remain intact.
