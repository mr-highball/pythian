# NS-6_instrumental-streams_01 — Stream long instrumental generation with recoverable native jobs

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** In progress
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

- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)
- [NS-6_instrumental-artifacts_01 — DONE](DONE/NS-6_instrumental-artifacts_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss: delivered the [persistent primary/WFC stream and native
  consumer](../INSTRUMENTAL-STREAMS.md), including a120-second instrumental WAV
  plus real tail:30 bounded windows,608 drum hits and12 peak voices. Native and
  actual pas2js check holds/FX, replay, failed admission, one-shots, cancellation
  and24-hour clocks. All-role context keeps joint symbolic choices together;
  selected-role mode retains more freedom and its observed continuation failures.
  No original-mix grains or generic WFC change. The actual long Studio job,
  output/resource admission and browser/reconnect consumer remain unfinished;
  keep the task open with no partial effort. Failure details are in WORK.

- 2026-10-31, Big Boss: resumed the preserved source implementation after08e6be2.
  Deliver continuous primary instruments and a bounded WFC-frontier consumer;
  verify held notes/FX, pull replay, failed admission/cancel, pause/stop and24-hour
  clocks before exposing longer Studio duration. Keep callbacks in the existing
  cumulative workflow. Current evidence packet: instrumental-streams-20261031-boss
  in the dedicated E-drive roots. No accepted effort until all task gates pass.

- 2026-10-31, Big Boss: bounded primary instrument-stream implementation was
  parked in stash f57503d5bdd66b3edaa0871d74fcb7aa6df54dc6 for the operator's current
  progress defect. Do not pop the earlier unrelated full-plan archive stash.
  The [simple Studio](NS-6_simple-studio_01.md) repair persists actual cumulative
  selection/render counters separately from nested callbacks and exposes stable
  workflow phases. Reuse this contract when extending duration. No long output,
  complete streams task or partial effort is accepted by that repair.

- 2026-10-30, Big Boss, concrete short-consumer performance evidence: a native
  four-second playlist result advanced correctly but took minutes with low CPU.
  On this host,32 sequential16KiB writes took7ms while closing the small E-drive
  file took5,571ms. The primary WAV writer already uses blocks. Preserve these
  timings and the pre-change job; do not add a one-off writer or weaken endpoint
  protection on speculation. Shared rendering publication now backs off to four
  times measured durable-publication cost, capped at30seconds, and returns to
  its ordinary two-second cadence after a fast write. Every callback still
  checks cancellation; terminal transitions remain separate. Progress21 passes
  with clean heap, including slow/fast/backward clocks and the existing24-hour
  status-count simulation. This reduces avoidable event I/O; it does not claim
  to repair underlying storage latency or implement long instrumental playback.
  Carry the measured artifact/close cost into this task's actual long consumer;
  no broad unrelated performance/callback audit is selected.

- 2026-10-29, Big Boss: Core native scheduling and streamed instruments exist. Current hours-long Studio session is acoustic; duration editing is finite lookahead and does not itself implement indefinite musical extension.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
