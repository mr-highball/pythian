# NS-6_studio_02 — Run bounded training and audition batches from the web

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Connect a saved operator project to actual supported Pascal/WFC training and
generation, then automatically publish its completed audio to the existing
listening queue. Training material and output duration are separate controls.
Reuse models when their source/policy identity is unchanged; make work, failure
and retained results visible. See the [studio scope](../OPERATOR-STUDIO.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 4 goal percentage points (0.40 overall points).
Basis: [2026-09-30 operator allocation](../OPERATOR-STUDIO.md#allocation-and-ownership).
This earns orchestration/usability credit only, not recorded inference, many-hour
semantic learning, musical style quality or a second WFC-mechanism credit.

Execution status: follows studio_01. Next batch must connect one supported real
learning mode and bounded generation path end to end, before adding more modes.
Freeze its input/resource/selection/output policy before running. Closing evidence:
actual selected-source-to-model-to-WAV provenance, responsive job control, durable
terminal state and automatic listening publication. Stop at unsupported evidence
or workload; no silent source truncation, fake progress or seed substitution.

**Acceptance Criteria:**

- AC1: Configure and enqueue bounded training/generation from a saved immutable
  project revision. Display supported mode, selected versus used duration,
  exclusions and resource bounds before submission. Resolve any unassigned
  source partition explicitly before learning; saving a draft cannot silently
  classify an independent evaluation recording as training material.
  Let the operator audition
  selected original material with a visible source-time playhead, seek controls
  and range context; text-only ranges cannot be the final preparation experience.
  Raw acoustic recombination,
  externally supplied note references and automatically inferred musical events
  must have distinct truthful labels and prerequisites; unavailable inference
  cannot silently fall back to supplied reference notes.
- AC2: Keep source selection/weights, training/model identity, generation seed,
  output duration/count and renderer settings distinct. Support short development
  auditions with deterministic recorded seeds and replay; preserve the separate
  fixed acceptance packet. Reusing a model must verify its dependencies; a changed
  corpus/policy produces a new version rather than modifying prior evidence.
- AC3: Run actual Pascal/WFC work asynchronously without blocking review/session
  requests. Show queued/running/completed/failed/cancelled states, truthful stage
  progress and actionable failures. Bound concurrency, runtime, memory/output
  work and queue size. Explicit cancellation and interrupted-service recovery
  preserve completed artifacts and never report an incomplete model as ready.
- AC4: Verify completed models/audio and publish complete declared outputs into
  the maintained listening contract exactly once. Retain source, model, policy,
  parameters, seeds, learning mode and project/batch ancestry. Partial failures
  remain visible and retry creates or reconciles explicit identities without
  replacing accepted audio or cherry-picking failed seeds out of the record.
- AC5: Validate the actual select/train/reload/generate/listen path, two distinct
  operator projects and a changed-source batch; include wrong/stale assets,
  oversize/unsupported input, cancellation, restart, retry and duplicate-submit
  controls. Independently inspect desktop/narrow job states and responsiveness.
  No musical acceptance is inferred from job completion.

**Blockers**

- [NS-6_studio_01.md](DONE/NS-6_studio_01.md)
- [NS-5_evaluation_03.md](DONE/NS-5_evaluation_03.md)

**Dev Notes:**

- 2026-09-30, Big Boss: source beat-proposal jobs are not training/generation
  jobs. This is the missing operator orchestration responsibility identified
  in the current HTTP route audit. It does not reopen stopped note, presence,
  context or continuity experiments. Every selected backend keeps its own
  supported scope and budgets; any distinct missing backend capability receives
  its owning linked prerequisite before scope expands. No QA submissions yet.
- 2026-09-30, Big Boss: preparation includes hearing the selected source and
  understanding its time range. Studio_01 delivers durable selection first;
  studio_02 owns the connected audible preflight, so the user's earlier lack of
  marker/time context cannot persist into the actual training submission flow.
- 2026-09-30, Neo / Big Boss readiness assessment: the existing raw path runs
  `AnalyzeWaveBatch` -> bound feature journals -> `TJournalTrainingReader` ->
  `TAcousticPalette.CreateFromReader` / `LearnJournalAcousticModel` -> saved WFC
  model plus `TJournalModelProfile` -> `TryGenerateAcousticSequence` ->
  candidate selection / `TJournalWaveRenderStream` -> `StageListeningAsset` /
  `PublishListeningQueue`. The maintained consumer is
  `tools/pythian.tools.journal.learning.pas`; its first audition fixes 128 grains
  and seed 731, so it is not yet the configurable job contract required here.
  Add the bounded job interface and declared parameters around those real APIs.
  Keep source-time selections bound to original feature ranges. Unknown song
  spans are excluded by `CorpusIntakePlan.TrainingRanges`; raw journal-segment
  experiments must retain their unknowns rather than claim that corpus admission
  passed. This was a read-only readiness check, not another learning experiment
  or acceptance result.
- 2026-09-30, Big Boss: report analyzed source coverage separately from the
  retained raw palette/candidate count. More analyzed audio does not by itself
  establish more retained musical variety. Longer training selection and shorter
  audition duration remain independent controls, and operator listening provides
  the style-usefulness verdict rather than the processed-duration counter.
