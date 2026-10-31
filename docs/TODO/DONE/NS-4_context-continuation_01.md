# NS-4_context-continuation_01 — Keep supported learned contexts continuing across long output

[Tasks](../README.md) · [Long consumer](NS-6_instrumental-streams_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Accepted — 2026-10-31
**Owner:** Big Boss (single agent)

**Description:**

Repair the demonstrated prerequisite exposed by the actual learned playlist
stream. A two-minute native/browser result succeeds, but an hour-scale request
reaches an unsupported context frontier at cell656. Primary attribution: NS-4.
Distinguish a legitimately finite provider from avoidable planning dead ends.
Keep learned transitions, origins, bounded lookahead and continuous instruments.

**Acceptance Criteria:**

- AC1: Retain and deterministically reproduce the actual failed provider/seed.
  Establish whether reachable continuing paths exist, including terminal branches
  and recurrent support. Do not select seed variants until one happens to pass.
- AC2: Where continuation is supported, the shared stream avoids unsupported
  nonfinal exits under explicit bounded policy. Unsupported requests fail with
  actionable evidence. Do not silently reset audio, fabricate learned edges or
  substitute original-mix fragments. Preserve cancellation/replay/ownership.
- AC3: Put demonstrated generic sequence/stream capability in the separate local
  WFC repository on a new branch, with operator notice and upstream/downstream
  checks. Audio/musical policy remains in Pythian; do not patch vendor sources.
- AC4: Validate the retained failure and finite/recurrent boundaries through
  native and actual pas2js consumers, then the actual long playlist job. Keep
  provider/seed/policy and failure lineage; no universal infinite-solvability or
  musical-quality claim follows.

**Blockers**

- [Instrumental runtime — accepted](NS-4_instrumental-runtime_01.md)
- [Experimental learning — accepted](NS-3_experimental-learning_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss, accepted AC1–4: the original fourteen-state context
  has twelve states with reachable cyclic support and two terminal states.
  The exact retained model and seed2066483829 reproduce the old failure at
  cell656; the new policy validates14400cells and completes the same hour job.
  No seed search, invented edge, source-audio loop or whole-duration allocation.
  Generic continuation capacity and version2 segment endpoints live in the
  separate WFC branch `codex/pythian-sequence-continuation`, commit7b3c0a5.
  The operator was notified; no dependency source was patched in this checkout.
  All five [WFC CI62 jobs](https://github.com/mr-highball/wfc/actions/runs/41189435399)
  and [Pythian CI519](https://github.com/mr-highball/pythian/actions/runs/41189774156)
  pass. Native/actual pas2js retained-path, finite/recurrent boundary and
  cancellation/publication checks pass; the actual browser plays and seeks the
  3601second mix. Evidence: `sequence-continuation-20261031-boss` and
  `studio-long-20261031-boss` under the dedicated E-drive roots.
  Preserve upstream CI60/61 failures: missing diagnostic label and stale
  versioned demo/MIDI expectations were repaired while PCM/MIDI content goldens
  remained intact. This is structural continuation support, not a guarantee
  against arbitrary future constraints or a musical-quality acceptance.

- 2026-10-31, Big Boss: `studio-long-20261031-boss` retains the hour-request
  failure and requested stream/model metadata in the isolated native catalog.
  The same browser journey already produced120seconds plus a1second tail:
  30 windows, six stems, exact downloaded bytes and successful reopen/seek.
  The hour trial failed at context cell656; no further seed trial is selected.
  First diagnose model support and the generic segment-exit contract. Follow
  the cross-repository procedure only after demonstrating a generic WFC gap.
