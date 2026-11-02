# NS-6_style-job-retry_01 — Reconnect to the same saved-style job

[Tasks](README.md) · [Style consumer](NS-5_instrumental-styles_01.md) · [Workflow](../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

An identical request for an existing named-style job raises a settings conflict.
The stored request includes native-added style_source metadata; the submitted
payload does not. Ordinary mobile retry/reconnect must return the already bound
job without learning again, reading models or silently accepting changed settings.
Primary NS-6 attribution. This is a demonstrated prerequisite of ordinary blend
jobs, not a general job-system rewrite.

**Acceptance Criteria:**

- AC1: Identical queued/completed named-style and blend requests return the same
  job and immutable request identity. No new event, generation or model read is
  performed. Changed style, musical weights, duration or seed still conflict.
- AC2: Maintained native consumers cover the exact failure and actual ordinary
  blend/reblend retries, with parent/Before lineage preserved. Relevant browser
  reconnect, complete source qualification and matching deployment pass with
  the style delivery. Preserve the original failure evidence.

**Blockers**

- None. This unblocks [ordinary selective styles](NS-5_instrumental-styles_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: full native ordinary playlist consumer passes9,408,521
  with a clean heap. Actual phone browser blend/further-blend/frozen reuse
  survives reload without another job; the HTTP submitted-payload retry returns
  already_queued, event7 and the same request hash/Before identity. A two-hour
  saved-style request cancels and reloads as cancelled. Evidence:
  E/runs/studio-blends-qa02/api-retry-pass.json and browser-*-job.json,
  E/tests/studio-blends-full05. AC2 still requires exact complete-source CI and
  matching live delivery. No effort is accepted yet.

- 2026-11-02, Big Boss: AC1 closes on actual queued/completed blend and named
  reblend requests. Native jobs03 passes2,016,094 checks with a clean heap:
  the same request/hash/event survives with model files exclusively locked;
  changed style, weights, seed and duration still conflict. The ordinary blend,
  save, further blend and frozen mix/six-part replay also pass with source audio
  exclusively locked. Server-added metadata is excluded only from retry payload
  comparison; stored records are untouched. Initial comparison events now use
  their actual comparison parent. E/tests/studio-blends-jobs03 retains the frozen
  inputs/logs. The isolated interrupted jobs02 request was hash-verified and
  relocated within that fixture's failure-evidence directory before retry;
  no production state was altered. This actual criterion resets count1→0.
  AC2 complete source/browser/deployment remains, so no task effort closes yet.

- 2026-11-02, Big Boss: linked before repair. The read-only Pascal proof under
  E/tests/style-job-retry-proof01 resubmits the actual completed named-style-0
  request from the isolated native fixture and reproduces EStudioConflict:
  Job identifier already binds different settings. No production data changes.
  Strip only server-added metadata for the existing submitted-payload comparison;
  retain the stored snapshot/hash and the normal changed-request rejection.
  The new blend admission also needs its actual comparison parent in the initial
  event rather than assuming an input parent_job_id. That new consumer failure
  remains in studio-blends-jobs02. One unit grows scope205→206 without accepting
  effort. Parent batch stops without closing a criterion; nonclosing count0→1.
  Follow this actual prerequisite, retaining the parent implementation for repair.
