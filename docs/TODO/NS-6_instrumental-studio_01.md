# NS-6_instrumental-studio_01 — Make Studio generate and play a full instrumental experiment

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

Wire the shared instrumental runtime into Studio's real native jobs and Generate/Review flow. This is the first operator-facing milestone: play bass, drums, harmony and lead, change a setting, regenerate and compare. Stop on a raw-acoustic substitute or a demo disconnected from ordinary Studio projects.

Primary attribution: NS-6. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Offer an obvious instrumental experiment as the primary generation path. It works from editable starter musical material and operator settings before automatic WAV transcription is reliable. Describe generated versus authored/proposed inputs briefly.
- AC2: Use existing native job persistence, progress, cancellation and artifact publication. Successful jobs automatically appear in the existing review flow; page suspension must not kill a finite native job.
- AC3: Expose useful initial tempo/key, role/instrument, seed and output-length controls, plus mix playback and part mute/solo. Change one control and hear its actual backend effect.
- AC4: Execute the real desktop and narrow/mobile-facing browser path on isolated operator data, preserve existing projects/answers, and deliver the same fixed-slot local service with working next actions. The main render must remain playable without the reference mix present.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)
- [NS-2_percussion_01](NS-2_percussion_01.md)

**Dev Notes:**

- 2026-10-29, Big Boss: The current job validator explicitly permits only raw_acoustic. Existing import single-pitch preview is a separate sine/MIDI path. Preserve useful queue/job/UI machinery; replace the product's primary generation connection.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
