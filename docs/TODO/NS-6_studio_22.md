# NS-6_studio_22 — Compare generated music with its selected originals

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Let an operator hear the original training selections beside generated music
in Listening reviews and Studio comparisons. Show recording names and original
times from the saved generation, not the currently edited project. Reuse one
Pascal presentation component and the existing bounded native audio reader.
North star: NS-6; owner: OPERATOR-STUDIO. Zero additional credit: this repairs
the source-context requirement of [studio_03](NS-6_studio_03.md).

Selected batch: Big Boss solo. Deliverable: source references and explicit
original playback beside the generated player. Closing evidence: immutable
selection binding, bounded reads, blind-state tests and desktop/narrow playback.
Stop on wrong source/range, identity leakage before blind reveal, unbounded
original downloads, feedback loss or orphan playback. No synthesis tuning.

**Acceptance Criteria:**

- AC1: Both listening views show the saved generation's actual recording names
  and selected original ranges. Multiple sources/selections are selectable.
  Unsupported or missing provenance is explained; current project changes do
  not rewrite the reference and old listening requests remain valid.
- AC2: Explicit original playback can explore the selected range in bounded
  windows with original timestamps and useful seek/previous/next controls.
  Switching original/generated audio pauses the other. Loading a review fetches
  no original PCM; closing/changing the review stops and releases its playback.
  Use the primary WAV/region path, with no duplicate codec or whole-file fetch.
- AC3: Blind Studio comparisons reveal references only at their declared reveal
  point, with a brief explanation while hidden. Feedback Save/history and
  exact output binding remain intact; source controls never enqueue learning.
  New ordinary development comparisons show originals before feedback; blind
  mode is an explicit choice and existing blind sessions keep their contract.
- AC4: Native lineage/range/missing/blind checks and desktop/narrow browser
  playback/navigation checks pass. Deploy matching fixed-slot assets, preserve
  operator records and close owned QA browser/audio. Record any unavailable
  actual-browser evidence honestly and keep this task open until it passes.

**Blockers**

- [Saved raw generation](DONE/NS-6_studio_02.md).
- [Bounded source workspace](DONE/NS-6_studio_13.md).

**Dev Notes:**

- 2026-10-05, Big Boss: AC1–3 engineering checks pass. One shared Pascal
  reference component serves both review views; native lookup matches published
  WAV, model and request identity before exposing the saved finite job's
  source ranges. Missing/unsupported originals remain explicit. No current
  project fallback, full-original download or time-alignment claim.
- 61 native review/iteration checks pass with zero leaks, including exact
  source/range/name binding, edits after generation, missing files, bounded
  primary WAV reads and blind lookup denial/reveal. 24 Pascal DOM checks cover
  lazy reads, multiple choices, original clocks/seek, final-window clipping,
  mutual pause, retry, stale replies, cleanup and the explicit blind opt-in.
  The existing 20 recovery checks still pass. Isolated fixed-slot HTTP checks
  exercise both reference routes and original playback using the media cookie.
- Development repairs: use an explicitly typed string array for pending/completed
  queue names (the compiler truncated the inferred literal array), and read the
  immutable private request for its project snapshot (the public job payload
  deliberately omits it). Regression checks now exercise both boundaries.
- AC4 actual desktop/narrow browser playback remains open because the Codex
  browser connection is unavailable; DOM checks are not a browser verdict.
  No QA browser/audio was started. Checked evidence is retained under ignored
  `build/source-reference/`. No task movement or added credit is justified.
- The checked implementation is deployed for operator review. All fourteen
  frozen stable artifacts match, including the correctly substituted phone-setup
  response; all 5,948 preceding operator JSON/JSONL hashes are unchanged.
  Both ordinary and submitted Studio reference endpoints resolve the reported
  156.171-second original selection. A one-second request at its actual source
  offset returned 192,044 WAV bytes in 20 ms, not the complete original.
  The isolated fixed-slot QA process is closed. No generated QA audio played.

- 2026-10-05, Big Boss: operator can hear a generated audition but cannot
  conveniently compare it with its original training passage. Existing saved
  jobs already retain original clocks and ranges. This is a presentation and
  provenance lookup gap, not a request for guessed alignment between generated
  time and source time. Musical defects remain with
  [continuity_01](NS-5_continuity_01.md); navigation-origin reproduction remains
  with [authoring_02](NS-6_authoring_02.md).
