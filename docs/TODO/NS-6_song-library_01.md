# NS-6_song-library_01 — Find, keep and stop generated music

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Give generated music a durable, obvious home in Studio. Save named songs to
named output playlists, replay earlier completed generations and download WAVs.
Keep active generation and Stop visible across navigation. Primary attribution:
NS-6. Reuse existing native jobs and audio artifacts; do not duplicate renders.

**Acceptance Criteria:**

- AC1: Completed instrumental mixes can be named and saved to an output playlist.
  Metadata survives reload and service restart, binds the exact completed job/audio,
  and retries do not create duplicate songs. Original jobs and answers remain.
- AC2: Songs lists saved music and recent completed generations, with playlist
  filtering, play/pause, opening the exact result and an obvious WAV download.
  Listing reads metadata only; audio loads when requested.
- AC3: Starting/running/stopping generation is visible from Library, Selection
  and Generate. Stop handles pending requests without silently starting them on
  refresh. Reload/reconnect restores the same native job rather than duplicating it.
- AC4: Simplify the unexplained header Lab entry into an optional, explained
  experiment action beside Generate. Exercise actual desktop/phone save/reopen,
  playback/download, navigation/Stop and reconnect; report any unconfirmed crash
  cause honestly. Maintain bounded native identity/storage failure checks.

**Blockers**

- [Connection admission](NS-6_connection-admission_01.md) — reproduced idle-socket starvation.
- [Simple Studio — DONE](DONE/NS-6_simple-studio_01.md).
- [Canonical artifacts — DONE](DONE/NS-6_instrumental-artifacts_01.md).

**Dev Notes:**

- 2026-10-31, Big Boss: native save/reopen/retry/rename and locked-audio listing
  pass10 checks with a clean heap. Actual desktop/390px jobs exercise Stop from
  Library followed immediately by reload (one cancelled job), then completion,
  naming/output playlist, replay, filter and exact WAV download. Saved metadata
  survives a service restart. Opening another result also restores its playlist
  context; a browser-found stale summary now redraws through the primary Studio
  path. Final matched assets, CI and approved-slot deployment remain gates.
  Preserve songs01's absent test artifact-root configuration and songs02's
  inferred short-string field-name truncation; the latter is repaired with a
  typed field-name array. No operator recording or answer was changed.
- 2026-10-31, Big Boss: operator could not find song saving or Stop and reported
  a connection failure after whole-track Generate/refresh. Stable server remains
  alive and has no new active worker; no server crash is yet reproduced. This
  task adds generated-music management, not duplicate credit for the existing
  learning/runtime. Pause the unfinished density batch without closing it or
  resetting its count; preserve its passed source and pending CI539.
