# NS-6_studio_21 — Recover background job status and finish long-source learning

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Repair the operator's generation failures: a fixed ten-minute limit rejects
admitted long recordings, checkpoint I/O may dominate work, and mobile suspension
can leave status polling stopped. Show selected training duration separately from
whole-file identity verification. North star: NS-6; owner: OPERATOR-STUDIO.
Zero additional completion credit for repairing the accepted learning/job path.

Selected batch: Big Boss solo. Deliverable: bounded, responsive native execution
and browser status recovery with clear scope. Closing evidence: checked native
runtime/cancellation/output tests, measured before/after overhead, isolated replay
of reported selections and actual browser reconnect. Stop on changed learned
output, silent training truncation, lost operator data or a generic WFC defect.

**Acceptance Criteria:**

- AC1: Diagnose the reported persisted failures and reduce demonstrated observer
  overhead without weakening source integrity or explicit cancellation. Admit
  long training with a declared finite budget shared by worker and supervisor.
- AC2: Finite jobs keep running without a browser; visibility/pageshow/network
  recovery refreshes status after a suspended or timed-out request, without
  duplicate submission. Explicit Stop remains authoritative. Live playback's
  separate connection contract is explained rather than confused with auditions.
- AC3: Preparation and job details distinguish selected training duration/extent,
  original bytes being checked, and requested output. Timeout/failure text is
  actionable and does not fall back to “Preparing music”.
- AC4: Meaningful native tests, representative recorded replay and actual browser
  desktop/narrow recovery checks pass. Deploy matched fixed-slot artifacts,
  preserve operator records and close owned QA browser/audio.

**Blockers**

- [Shared callback rollout](DONE/NS-6_observability_01.md).
- [Explicit training choices](DONE/NS-6_studio_19.md).

**Dev Notes:**

- 2026-10-05, Big Boss: AC1 execution repair, AC2 recovery contract and AC3 scope
  labels pass native/DOM checks; both recorded replays pass. AC4 remains open for
  actual browser validation. One combined worker/UI batch; no completion
  credit. Core analysis, hash and learned output algorithms are unchanged.
- The 32 MiB SHA checkpoint probe measured 844 ms without observation, 5,281 ms
  with a disk-backed cancellation check at every callback, and 875 ms with a
  100 ms host cadence. Actual large-file cancellation completed in 234 ms.
  Deadlines remain checked at every callback; final publication checks cancellation
  unconditionally. Review repaired deadline-before-cancellation ordering so an
  already-requested cancellation remains authoritative.
  An isolated one-second-budget fixture also records `runtime_budget` and no output;
  the longer production allowance does not disable timeout enforcement.
- Native results: 165 actual worker, 60 job lifecycle and 19 supervisor checks.
  Source-byte preflight deduplicates original files across selected ranges. New
  auditions declare 7,200 seconds; old immutable attempts retain 600 seconds.
  The short recorded passage completed cold learning and generated exactly the
  earlier accepted model/WAV hashes. This is replay equivalence, not a new
  musical quality verdict.
- Full-mix cold replay completed in 29m48s, covering all 389,904,384 selected
  frames / 380,766 observations and publishing one verified 960,000-frame
  (20-second) audition. No source truncation or model reuse. Both owned workers
  exited; the unused queued replay was cancelled. No QA browser/audio/service
  remains. The final fixed-slot deployment matches all fourteen frozen assets
  and preserves all 5,944 prior operator JSON/JSONL hashes.
- Maintained Pascal DOM checks cover stalled/rejected requests, visibility and
  page/network return, ignored stale replies, project switching, cleanup, explicit
  cancellation, no duplicate writes and distinct source/output scope: 20 checks.
  [Build runner](../../tools/build-studio-recovery-checks.ps1) uses an explicitly
  supplied jsdom module (checked with 29.1.1). Browser-sized layout, actual browser
  suspension and physical-phone behavior are not established by these tests.
- Codex Browser bootstrap fails before browser selection because its configured
  browser-service module points to an absent plugin build. No fallback browser,
  profile modification, audio playback or browser acceptance is claimed. The
  recovery evidence and exact failure are retained under ignored
  `build/studio-recovery/`. Big Boss retains ownership of the remaining check.
- 2026-10-04, Big Boss: both reported finite jobs ran for 600 seconds and failed
  with `runtime_budget`, with no recorded cancellation. Testing selected a full
  8,123-second stereo recording (1,559,617,614 bytes); Lofi selected 156.171 seconds
  from a 1,966,128,086-byte original. Lofi stopped in whole-file verification;
  Testing reached analysis. Browser refresh currently has no visibility recovery
  and a timed-out refresh can leave no future poll scheduled. Evidence belongs
  under ignored `build/studio-recovery/`; private identities stay outside Git.
