# NS-6_studio_24 — Recheck prepared replacements under the publication lock

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Prevent a newly prepared experiment from superseding a listening request answered
after preparation but before publication. The factory's revision-zero check is
not atomic with append/publication. Preserve existing historical experiments and
idempotent replay while checking new replacement identities under the same writer
lock as saved responses.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional.
Accepted 2026-10-27: Spike implemented one shared publication guard and the
maintained interleaving fixture. Checked FPC 3.2.2 Win32/Win64 runs, Spiegel's
independent checked Win64 run/source review and Big Boss's optimized checked
Win64 run pass with zero leaked blocks. Both entry points reject the changed
revision without altering queue/review bytes. Existing identical requests,
export/replay and valid retries pass. The fixed native service is deployed;
Big Boss owns integration and final judgment. Delivered one shared check for
append and replacement publication, without new formats or changed valid answers.
Closing evidence: deterministic prepare/answer/publish interleaving, rejected
write with unchanged queue/reviews, safe retry and historical read/export/replay.
Stop on a check outside the writer lock, rejected existing history, duplicate
validation implementations or a changed answer store.

**Acceptance Criteria:**

- AC1: Under the queue writer lock, reject a newly introduced or changed
  experiment replacement if its bound original has acquired a review revision.
  Apply the same primary rule to append and full-queue publication.
- AC2: Preserve exact existing experiment identities, completed history,
  export/replay and identical append retries. Do not apply a publication-only
  freshness requirement to historical reads or imports.
- AC3: Checked native Win32/Win64 fixtures reproduce preparation followed by
  a saved original answer, then rejected publication through both entry points.
  Verify exact queue/review preservation, ordinary unreviewed success, retry
  and cleanup with zero leaked blocks.

**Blockers**

- [Existing editor/queue contract — DONE](NS-6_authoring_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss: `VerifyFreshReplacements` runs under `queue.lock` in
  append and full publication. Identical existing experiment identities retain
  their historical meaning; normal reads and replay do not impose the new
  publication-only freshness condition. The first combined factory QA submission
  failed on this race; the repaired second submission passes. The two-failure
  implementation transfer threshold was not reached. Evidence stays under
  E-drive `runs/feedback-race-20261027-spike`,
  `runs/feedback-readiness-20261027-spiegel-qa` and
  `runs/feedback-readiness-20261027-boss`. This repair earns no musical credit.

- 2026-10-27, Big Boss: Spiegel's first combined review of
  [studio_03](../RETIRED/2026-10-29/NS-6_studio_03.md)'s single factory found that canonical hash and
  asset/range checks do not establish a current revision. The existing pair
  factory has the same gap. Preserve that finding and failure evidence; source
  assessment is not a claim of prior response loss. The planned atomic
  restoration of an absent historical ordinary request plus its prepared child
  avoids this specific interleaving but does not replace the general repair.
