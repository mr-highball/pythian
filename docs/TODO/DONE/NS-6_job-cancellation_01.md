# NS-6_job-cancellation_01 — Accept Cancel during live progress writes

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Close the concrete prerequisite exposed by the instrumental Studio browser test:
Cancel twice rejected with a busy job-writer error while an ordinary finite
instrumental job continued to render. Preserve the shared atomic job journal,
terminal states and owned locks. This is a bounded cancellation repair, not a
general callback or observability audit. Primary attribution: NS-6.

**Accepted outcome — 2026-10-30, Big Boss SOLO.** AC1–3 pass.
Cancellation alone may wait ten seconds for the shared atomic writer, within
the app's existing fifteen-second request bound. Ordinary writers keep their
two-second policy. No lock stealing, journal bypass, fabricated terminal state
or manual marker injection was introduced.

The maintained two-process fixture holds a real writer for three seconds,
then verifies cancellation after that owner releases it. An unavailable writer
still rejects within thirteen seconds, leaves its lock/state intact, and
accepts explicit retry after release. All 113 job lifecycle checks pass with a
clean native heap. The actual 390-pixel app cancelled a running 256-cell
instrumental job through the repaired endpoint; its terminal state is cancelled
and no listening request for that attempt was published. Previously completed
audio and saved answers remain present.

Evidence: instrumental-studio-20261030-boss tests/cancel-fixture-run.log,
narrow-cancel-passed.png, browser-cancel-queue.json and isolated catalog receipts.
The first failed two-second cancellation responses remain recorded. A Pascal
diagnostic using the same public CancelStudioJob API safely stopped the earlier
QA job; the final acceptance used the actual app, not that helper.
**Acceptance Criteria:**

- AC1: A live writer held beyond the former two-second wait can release normally and permit cancellation within the browser request deadline, without stealing its lock or fabricating worker completion.
- AC2: A genuinely unavailable writer still rejects within a finite bound, preserving job state; explicit retry works after its owner releases.
- AC3: Cancel a running instrumental job through the actual narrow-screen app, observe its terminal cancellation and prevent listening publication from that cancelled attempt. Preserve existing completed audio/answers.

**Blockers**

- None. Repair the primary Studio job writer boundary; no WFC or inference change.

**Dev Notes:**

- 2026-10-30, Big Boss: AC1–3 batch. Extend only the cancellation writer wait within the existing 15-second browser request bound; exercise real process contention and stale-owner rejection, then the actual running instrumental Cancel path. Stop if the writer cannot be acquired within that bound or state/lock ownership changes. Starting nonclosing count: zero; this real prerequisite interrupts the still-open instrumental Studio batch.
- Reproduction: isolated native job batch-1793337812213-515716510; two app cancellation responses reported “Studio job writer remains busy” and left cancel_requested false while instrumental_render advanced. Evidence: instrumental-studio-20261030-boss QA catalog and browser checks under the dedicated E workspace. Do not copy these QA responses into the operator catalog.
