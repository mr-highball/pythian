# NS-6_instrumental-streams_01 — Stream long instrumental generation with recoverable native jobs

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Extend the instrumental path to flexible long output through bounded musical lookahead and native synthesis. Reuse core clocks/scheduler/buses and existing durable jobs. Stop on full-duration PCM allocation, silent note restarts at chunk boundaries or raw-acoustic fallback.

Primary attribution: NS-6. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Accept user durations including minutes and multi-hour/24-hour plans with explicit output format and bounded resource estimates. Keep graph/lookahead/PCM memory independent of total duration; distinguish planning chunks from musical form.
- AC2: Preserve clocks, held notes, envelopes, effect history and selected musical continuation across pulls; pause/stop/cancel and future edits have defined behavior. A failed/cancelled job leaves identifiable playable output or an actionable failure state.
- AC3: Finite native jobs survive mobile backgrounding and reconnect without duplicate submission. Display truthful phases/counters and cancellation; add callback coverage only where this consumer needs it.
- AC4: Verify short/long-plan boundaries, block-partition replay where promised, held-note/FX continuity, interruption/reopen and the actual browser playback path. Demonstrate a sustained instrumental review without requiring a 24-hour wall-clock test as an entry gate.

**Blockers**

- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: Core native scheduling and streamed instruments exist. Current hours-long Studio session is acoustic; duration editing is finite lookahead and does not itself implement indefinite musical extension.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
