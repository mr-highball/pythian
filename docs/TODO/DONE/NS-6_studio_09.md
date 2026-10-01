# NS-6_studio_09 — Refresh large existing collections without recopying media

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Make the operator's multi-hour private collection practical to discover and
refresh. The prior path staged complete copies even when catalog originals
already existed, repeated their verification, and shared a ten-minute generation
deadline. The actual collection contains approximately 7 GB across three mixes;
its first approximately 2 GB native import alone took several minutes. Avoid a
predictably over-budget refresh while retaining source identity and metadata.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [authoring_02](../NS-6_authoring_02.md),
which retains all physical-device and complete-workflow obligations.

Execution status: accepted by Big Boss on 2026-10-01. Existing originals use
verified reuse without full staging copies; collection work has an immutable
7,200-second bound separate from generation's 600 seconds. Checked native and
independent browser failure/cancellation/recovery checks pass. The actual three
mixes publish revision 2, three collections and five total catalog recordings.
Closing evidence is `build/studio-onboarding/actual-refresh-observation/`,
`build/salty-studio-refresh-20261001/FINAL-VERDICT.txt` and exact-revision
[Linux qualification](https://github.com/mr-highball/pythian/actions/runs/36832262007);
see the [accepted checkpoint](../../WORK.md#current-accepted-collection-and-navigation-checkpoint--2026-10-01).
Next deliverable is studio_03's separate operator verdict. Stop at changed
source identity or unsupported musical/physical-phone claims; this acceptance
qualifies collection engineering only.

**Acceptance Criteria:**

- AC1: Existing catalog sources take a verified reuse path without another full
  staging WAV. Preserve source bytes, metadata, family, partition, license and
  provenance. Same-size corruption and changed collection originals cannot pass
  through a filename, timestamp or length-only shortcut. New sources continue
  through the maintained import contract; aliases remain distinct memberships.
- AC2: Declare finite collection-refresh runtime and I/O bounds separately from
  short generation. Worker, supervisor, receipts and UI agree on those limits.
  Preserve cancellation, shutdown/recovery and prior published index on failure;
  allow cancellation checks during long verification and copying operations.
- AC3: Independently exercise existing/new/changed/duplicate/missing/corrupt
  sources, failure and cancellation/retry, on checked supported native targets.
  Verify no extra complete staging copies for existing sources and unchanged
  catalog metadata. Show truthful progress and retain a checkable job identity.
- AC4: Complete discovery of the actual three existing private mixes through the
  maintained native job path within its declared budget. Record bytes, elapsed
  time, revision, source/collection counts and preserved review history in
  ignored evidence. No private media or machine paths enter Git, and no operator
  musical or physical-phone verdict is inferred from this run.

**Blockers**

- [NS-6_studio_04.md](NS-6_studio_04.md)
- [NS-6_studio_02.md](NS-6_studio_02.md)

**Dev Notes:**

- 2026-10-01, Big Boss: running-refresh QA observed Cancel HTTP 422 while the
  job continued; that response body was not retained, so its exact cause remains
  unconfirmed. A deterministic independent-writer regression separately proves
  that the prior job lock immediately rejected cancellation during an ordinary
  live write. Big Boss owns the native job store and its bounded two-second
  acquisition repair; it never removes another writer's lock. New checked
  Win32/Win64 development runs pass 47 lifecycle assertions with zero parent/
  child leaks, including unchanged state after an unavailable-lock timeout.
  Independent qualification remains required. Preserve the original browser
  failure, the stopped QA fixture's interrupted library lock, and the failing
  old-policy regression under `build/studio-onboarding/native-cancel-repair/`.
  This native gap does not count as a second failure of Ticket Guy's UI repair.
- 2026-10-01, Big Boss / Neo: the first browser submission failed completion
  feedback. A completed job triggered the parent catalog reload; its following
  inventory check immediately replaced the terminal outcome with generic ready
  text. Ticket Guy owns preserving the known completed/failed/cancelled outcome
  through that reload and recovery, with one completion callback per observed
  job. Preserve the failure under `build/salty-studio-refresh-20261001/`; this is
  one UI implementation failure, distinct from the passing native checks and
  ongoing actual-corpus run. A second failed implementation submission transfers
  this repair to Big Boss. Do not infer latest history from arbitrary job IDs.
- 2026-10-01, Big Boss: found the large-source refresh gap while reconnecting the
  actual original catalog for studio_08. Source inspection shows full staging
  of every existing original, duplicate import verification and a final source
  rehash under a 600-second worker limit. Do not launch a knowingly unsuitable
  job or hand-edit the collection index. Existing import evidence remains under
  `build/studio-onboarding-corpus/`; native source qualification is still required.
  This linked prerequisite does not erase the navigation submission's first
  failed timeout/retry check or earlier transferred job-task failures.
- 2026-10-01, Big Boss: new refresh jobs declare a finite 7,200-second limit in
  their immutable request. Generation and existing historic requests keep their
  600-second limit. The worker, supervisor, preparation and job detail consume
  the same request-bound policy; replay transport excludes internal fields.
  This is a work bound, not a promise that every maximum-size library finishes.
  Existing-source verification still reads content three times; no timing or
  metadata-only cache substitutes for the actual final source check.

- 2026-10-01, Big Boss final acceptance: checked FPC 3.2.2 Win32/Win64 passes
  library 421, jobs 47, worker 50 and supervisor 19 assertions with zero leaks.
  Exact implementation `5666eb49af2a1293414bfd2ab3e855d48be1b281` passes
  [Linux native/package qualification](https://github.com/mr-highball/pythian/actions/runs/36832262007):
  projects 100, library 417, jobs 47, effects 44, capture 53, worker 50,
  supervisor 22 and reviews 47, with zero Studio leaks. Four additional Windows
  library assertions are platform-specific sparse-file setup checks. Extracted
  core/WFC consumers verify 98/146 owned units and 111/265 content hashes.
  Logs remain in `build/studio-onboarding/ci-5666eb4/logs/`.
  Independent browser verdict is `build/salty-studio-refresh-20261001/FINAL-VERDICT.txt`:
  actual running Cancel returns 200 and reaches cancelled; completed and failed
  outcomes persist through explicit Connect/inventory. A cancelled-Connect case
  was not executed and is not claimed. Candidate 5 deployment identities are
  retained in `build/studio-onboarding/DEPLOYED5.json`.
  Actual scan verifies 7,045,401,242 input bytes through three full logical
  content passes plus header work; 21,136,203,726 verification bytes are not
  measured physical disk traffic. Completion is bounded by observations at
  887.345–958.510 seconds, below 7,200. Revision 2 has three named collections,
  three existing originals, zero imports and five total catalog sources.
  All 22 readable prior records remain byte-identical; the active lock is
  excluded. No new-source staging events occur; the exact staging parent
  contains an older directory, so its emptiness is not claimed.
  Existing 1 NS-6 / 0.10 overall credit is awarded without a new build claim.
  The first UI failure, historical Cancel 422 with unretained body/unknown cause,
  independently reproduced native-lock regression and chief repair stay below.
  No musical learning, physical-phone or operator-listening verdict follows.
