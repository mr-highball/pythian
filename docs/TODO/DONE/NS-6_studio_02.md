# NS-6_studio_02 — Run bounded training and audition batches from the web

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Connect a saved operator project to actual supported Pascal/WFC training and
generation, then automatically publish its completed audio to the existing
listening queue. Training material and output duration are separate controls.
Reuse models when their source/policy identity is unchanged; make work, failure
and retained results visible. See the [studio scope](../../OPERATOR-STUDIO.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: [2026-09-30 operator allocation](../../OPERATOR-STUDIO.md#allocation-and-ownership).
This earns orchestration/usability credit only, not recorded inference, many-hour
semantic learning, musical style quality or a second WFC-mechanism credit.

Execution status: accepted engineering outcome — 2026-10-01. Big Boss accepts
AC1–5: audible corpus preparation, actual asynchronous raw-acoustic Pascal/WFC
learning, saved-model reuse, deterministic short auditions, complete listening
publication and durable cancellation/recovery. Closing evidence is the frozen
independent `build/salty-studio-browser-20261001/VERDICT.txt` (SHA256
`4567f24567692b5b5ba542bc5a76af4809e882c00abbfeb40572fa2aef186cae`),
`FINAL-BROWSER-IDENTITIES.json` and native evidence under
`build/salty-studio-native-20261001/`, using stable FPC 3.2.2 Win32/Win64 and
matched pas2js 3.3.1. Exact staged service/worker/asset identities remain those
recorded in the freeze manifests. The actual cancellation and read-only reopen
are retained in `cancellation/` and `cancellation-readback/` under that browser
evidence root. The non-Windows supervisor import correction is separately
recorded in `build/studio-supervisor-unix-import/`; Linux compilation remains a
CI check. Stop at this accepted raw-acoustic scope; musical usefulness and
inferred/reference-event learning retain their separate acceptance.

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

- [NS-6_studio_01.md](NS-6_studio_01.md)
- [NS-6_studio_04.md](NS-6_studio_04.md)
- [NS-5_evaluation_03.md](NS-5_evaluation_03.md)

**Dev Notes:**

- 2026-10-01, Big Boss: the first published Studio revision `35a49b7` failed
  [Linux CI](https://github.com/mr-highball/pythian/actions/runs/36818040705)
  because the supervisor used undeclared `ESrch` in its non-Windows branch.
  Neo owns the bounded `ESysESRCH` repair, verified against FPC 3.2.2 sources.
  Fresh checked Win32/Win64 compile checks pass; no Windows statement or live
  review asset changes. Evidence and exact identities are retained in
  `build/studio-supervisor-errno-repair/REPAIR.json`. Count this as implementation
  CI failure **1** for this task; preserve the earlier zero-failure Windows and
  browser results as scoped history. Salty's same-batch correction review and
  exact repaired-revision Linux CI remain required before final handoff. The
  accepted Windows engineering outcome and its credit do not imply a Linux
  pass or musical acceptance. A second failed implementation submission
  transfers implementation and evidence to Big Boss under the task workflow.

- 2026-10-01, Neo: Big Boss accepts all five criteria after Salty's final
  engineering PASS. Retained native tests prove two projects and an actual
  changed-source batch, model reload/replay, source rejection, partial-seed
  evidence, publication idempotence and owned-worker recovery. Independent
  desktop/narrow controls prove actual generation/listening, unsupported mixed
  clocks, source/next-batch changes, retry and cancellation. One real submission
  and one Cancel POST produce durable event 2 `cancelled_before_start`; read-only
  reopen/refresh retains the state with zero extra POSTs. All QA processes,
  workers, listeners and audio are cleaned up. Native/browser implementation
  submissions have zero failures. The latest-project-name and middle-dot
  encoding oracle mistakes are retained in ignored QA evidence and corrected
  without changing catalog history or production behavior. The Unix-only uses
  repair retains its old source/hash and compile proof separately; Windows
  staged runtime semantics are unchanged and no Linux runtime pass is claimed.
  This closes job engineering, with no musical or stopped-science credit.

- 2026-10-01, Neo: the maintained jobs/supervisor/worker now execute the raw
  acoustic path from an immutable classified project revision, verify original
  source bytes and geometry, save/reload the WFC model, render exact 20–40-second
  auditions and atomically append their listening requests. Metadata preflight
  claims no used audio; worker receipts retain actual analyzed coverage,
  retained palette/candidate counts, explicit unassigned admission, source
  weights, seeds and ancestry. Full grain-origin ledgers remain in immutable
  per-seed receipts with hashes/counts in compact job results. Failed or cancelled
  batches retain every seed outcome and never report incomplete publication as
  completed. Runtime is capped at 600 seconds, with a declared 128 MiB logical
  allocation budget rather than process-memory isolation; the native preflight
  exposes source, feature, queue and output-work limits.
- 2026-10-01, Neo: independent Salty native QA passes stable FPC 3.2.2 Win32 and
  Win64: jobs 31, actual worker 48 and owned-child supervisor 19 checks per target,
  all with zero leaks. The current native freeze and logs are retained under
  `build/studio-native-handoff/` and `build/salty-studio-native-20261001/`.
  Development repaired an empty-weight UI bug caused by an undefined JavaScript
  property cast to Boolean, using an own-property check; shortened GUID-only
  sibling stages avoid Windows path overflow without changing source/model
  identities. Same-project next-batch edits retain parent lineage and exact
  supplied seeds while invalidating preflight. These were integration corrections,
  not final QA rejections. Native submitted failures remain zero; complete
  desktop/narrow asynchronous and recovery QA is pending. No task credit or
  musical acceptance is awarded.

- 2026-09-30, Big Boss: a second unearned point transfers to the user's explicit
  effects preparation outcome [studio_05](NS-6_studio_05.md). All job criteria
  remain; effects are optional corpus preparation, not a job execution blocker.

- 2026-09-30, Big Boss: the user's private collection-to-corpus requirement is
  owned by [studio_04](NS-6_studio_04.md), a required intake prerequisite. One
  unearned NS-6 point transfers there; all job criteria above remain required.

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
