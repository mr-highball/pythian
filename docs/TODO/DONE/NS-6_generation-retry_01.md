# NS-6_generation-retry_01 — Retry a failed generation from its visible result

[Tasks](../README.md) · [Native identical retries](NS-6_style-job-retry_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** Accepted — 2026-11-02
**Owner:** Big Boss (single agent)

**Description:**

The three-step Studio now offers Retry these settings on failed/stopped runs.
It preserves the old request separately from current playlist Generate, using
the existing native retry lineage and durable transport. Primary attribution:
NS-6. Native admission and pas2js share the accepted instrumental write fields.

**Acceptance Criteria:**

- AC1: A failed or cancelled generation visibly offers Retry these settings.
  Preserve its selected style/blend, seed, duration and immutable source choices;
  retain the old failure and bind the new attempt through existing retry lineage.
  A lost submission reconnects idempotently rather than creating duplicate jobs.
- AC2: Actual desktop/390px failure, retry, reload and cancellation show the
  intended run, useful progress and Stop. An explicit new generation remains a
  separate choice. Do not silently learn from the current playlist as a retry.

**Blockers**

- [Native identical saved-style retry — DONE](NS-6_style-job-retry_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: AC1–2 and prerequisite pass. The shared Pascal tool
  schema excludes resolved worker inputs while preserving the original project
  revision/hash, style/blend, seed, length and musical/sound edits. Actual JS45,
  native jobs113/instrumental91 and full playlist9408558 checks pass with clean
  heaps. The actual native cancelled run retries8seconds at its original seed
  and revision despite newer selection0/40seconds. A deliberately lost response
  reconnects with the identical write/job; native completion, normal browser
  close/reopen, actual reload, mix/Original playback and Stop pass. Failed-screen
  presentation is simulated in QA; the retained actual live failed blend also
  shows Retry at desktop/390px without being submitted. Native failure-injection
  was blocked by automatic approval without a specific reason; that fixture was
  not run. No production generation or answer is submitted by QA.
  Complete CI570/sourcefa15d2b, verified artifacts/packages and matching eeb8bd7
  frontend delivery pass; all prior private data remain exact. Proof:
  E/runs/review-retry-recovery01, review-retry-failure01 and
  review-retry-release01. Preserve the old harness failures: copied file identity
  receipts correctly fail, and forced process termination can lose unflushed
  profile writes. The owned Pascal driver now requests normal Browser.close;
  actual normal reload/reopen passes without a product workaround. All isolated
  QA processes/audio close. No physical-phone, independent-review or musical
  preference verdict follows; count remains0 after complete criterion closure.

- 2026-11-02, Big Boss: same bounded bridge batch as review entry; count0 after
  real prior gate closure. Deliver Retry these settings from the retained failed/
  cancelled request, using the existing native retry lineage and idempotent
  submission/reconnect transport. Seed, source/style/blend, duration and settings
  stay frozen; current playlist Generate is separate. Close with actual desktop/
  390px failure/retry/reload/cancel/Stop and no duplicate jobs, plus matched UI
  delivery over qualified unchanged native code. Preserve the earlier failure.
  Stop on a missing required native contract; link that gap before expanding.

- 2026-11-02, Big Boss: actual isolated current Studio restores the failed blend
  with its generic failure message and Back to previous version. It has no
  generation retry action; the current client retry writer is for clip saving.
  Native API admission of the exact failed blend succeeds independently. This
  is a distinct consumer recovery gap, not a reversal of native retry acceptance.
  E/runs/blend-projection-qa01 retains the native request/result and browser
  observations. Link before expanding scope; return to projection verification.
