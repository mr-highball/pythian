# NS-6_instrumental-studio_01 — Make Studio generate and play a full instrumental experiment

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Wire the shared instrumental runtime into Studio's real native jobs and Generate/Review flow. This is the first operator-facing milestone: play bass, drums, harmony and lead, change a setting, regenerate and compare. Stop on a raw-acoustic substitute or a demo disconnected from ordinary Studio projects.

Primary attribution: NS-6. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Delivered outcome — 2026-10-30, Big Boss SOLO.** AC1–4 pass through the
ordinary Studio consumer and fixed-slot service.

- A saved instrumental project may contain no recordings. Tempo (40–240 BPM),
  key root, 1–32 four-beat bars, seed, three pitched oscillator choices and six
  mix levels control the primary instrumental runtime. Authored material is
  explicitly Experimental; no WAV learning or full-mix grain fallback occurs.
- Native jobs preserve requests, source/proposal origins, actual model/plan
  identities, progress and cancellation. The tested 64-cell job survived full
  page unload and returned a 392160-frame stereo mix at 24000 Hz (16.34 seconds),
  six stems and sixteen actual passes in two conditional graph groups.
- The browser plays synchronized stems with real mute/solo gains, pause/seek/
  stop and a complete native mix. A reviewed tempo-only change to 90 BPM
  retained its parent and produced 520160 frames. Native replay repeats exact
  audio; key and oscillator changes affect actual output.
- Successful jobs publish to the existing one-question listening queue and
  Studio review flow. A timed note/answer saved without generating another job;
  reviewed settings restored for the next deliberate experiment. Authored
  provenance does not invent a source-WAV hash or offer a nonexistent original.
- Actual desktop and 390-pixel browser checks pass on an isolated catalog/profile,
  including an empty-project save, contextual dialog help, no horizontal overflow,
  background/reconnect, feedback, settings restoration and running cancellation.
  The final native fixture passes 41 checks with zero heap leaks; relevant
  project (106), job lifecycle (113), and listening catalog regressions pass.
  These are solo checks, not independent review or musical preference acceptance.

The matched service/worker/twelve assets are deployed to the existing stable
slot, retaining the same address, Private profile, TLS identity and catalog.
Deployment preserved both prior projects, all eleven prior jobs and five saved
answers. One additional real operator project/job now provides the first
instrumental review; its six-part output completed with ten recorded events
and leaves one waiting review plus the original five completed answers.
No QA answers were copied into that catalog. QA listeners/workers and isolated
browser process trees are closed; playback was muted and explicitly stopped.

Evidence: instrumental-studio-20261030-boss build/tests/runs folders under the
dedicated E workspace, including native-final, browser screenshots/summaries,
background/tempo/cancellation receipts, operator before/after records and the
fourteen-asset deployment manifest. Deeper graph editing, WAV-derived providers,
richer recipes/styles and efficient long streams remain separate tasks. The
finite renderer currently performs the immutable plan afresh for mix/stems;
this is not a continuous long-session implementation.
**Acceptance Criteria:**

- AC1: Offer an obvious instrumental experiment as the primary generation path. It works from editable starter musical material and operator settings before automatic WAV transcription is reliable. Describe generated versus authored/proposed inputs briefly.
- AC2: Use existing native job persistence, progress, cancellation and artifact publication. Successful jobs automatically appear in the existing review flow; page suspension must not kill a finite native job.
- AC3: Expose useful initial tempo/key, role/instrument, seed and output-length controls, plus mix playback and part mute/solo. Change one control and hear its actual backend effect.
- AC4: Execute the real desktop and narrow/mobile-facing browser path on isolated operator data, preserve existing projects/answers, and deliver the same fixed-slot local service with working next actions. The main render must remain playable without the reference mix present.

**Blockers**

- [NS-6_job-cancellation_01](NS-6_job-cancellation_01.md) — concrete running Cancel failure found during browser acceptance.

- [NS-4_instrumental-runtime_01](NS-4_instrumental-runtime_01.md)
- [NS-2_percussion_01](NS-2_percussion_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss SOLO: AC1–4 batch. Deliver ordinary persisted instrumental jobs from the authored starter, initial tempo/key/seed/length/sound/level controls, native mix and six stems, automatic listening publication and desktop/narrow browser checks. Reuse existing job transport/progress/cancellation, graph planning and scheduler. Stop at this finite Studio boundary; graph editing, WAV learning and long streams remain separate tasks. Starting consecutive nonclosing count: zero.
- 2026-10-30, Big Boss: The first native integration forwarded every fine WFC phase through ordinary status publication, generating 749 durable events before the isolated fixture was stopped. Repaired by using the existing observed-audio progress gate; cancellation still checks every callback. A 200-event bound is now a fixture assertion. Failure evidence remains in instrumental-studio-20261030-boss tests/native-fixture-1. The repaired fixture passes 32 checks, including exact replay/key effect, six stems, authored provenance and queued cancellation, with zero heap leaks. First compiler errors (AddSend arguments and browser event-listener/enumerator bindings) are repaired and retained in compile logs.

- 2026-10-29, Big Boss: The current job validator explicitly permits only raw_acoustic. Existing import single-pitch preview is a separate sine/MIDI path. Preserve useful queue/job/UI machinery; replace the product's primary generation connection.
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
