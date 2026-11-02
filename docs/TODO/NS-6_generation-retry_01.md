# NS-6_generation-retry_01 — Retry a failed generation from its visible result

[Tasks](README.md) · [Native identical retries](DONE/NS-6_style-job-retry_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

The current three-step Studio restores a failed saved-style result but offers
Generate music for the current selection, without an explicit retry of the failed
choices. Make recovery clear without opening hidden tools or rebuilding a blend.
Primary attribution: NS-6. Reuse the existing native retry and retained request.

**Acceptance Criteria:**

- AC1: A failed or cancelled generation visibly offers Retry these settings.
  Preserve its selected style/blend, seed, duration and immutable source choices;
  retain the old failure and bind the new attempt through existing retry lineage.
  A lost submission reconnects idempotently rather than creating duplicate jobs.
- AC2: Actual desktop/390px failure, retry, reload and cancellation show the
  intended run, useful progress and Stop. An explicit new generation remains a
  separate choice. Do not silently learn from the current playlist as a retry.

**Blockers**

- [Native identical saved-style retry — DONE](DONE/NS-6_style-job-retry_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: actual isolated current Studio restores the failed blend
  with its generic failure message and Back to previous version. It has no
  generation retry action; the current client retry writer is for clip saving.
  Native API admission of the exact failed blend succeeds independently. This
  is a distinct consumer recovery gap, not a reversal of native retry acceptance.
  E/runs/blend-projection-qa01 retains the native request/result and browser
  observations. Link before expanding scope; return to projection verification.
