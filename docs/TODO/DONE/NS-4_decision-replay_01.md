# NS-4_decision-replay_01 — Retain and replay the music actually performed

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Ordinary playlist generation now uses bounded streamed synthesis. It retains
models/settings but discards performed decisions. Before Studio can retain notes
while changing sound or selectively regenerate a passage, retain the actual
musical timeline without keeping an hours-long graph/score in RAM. Primary
attribution: NS-4. This is a demonstrated prerequisite of graph-controls, not
another inference/benchmark gate or a second synthesis engine. Accepted2026-10-31
after shared native/pas2js replay and the actual native playlist worker's saved
mix/stems pass. Studio follow-up controls remain in graph-controls.

**Acceptance Criteria:**

- AC1: Expose detached bounded decisions from the actual instrumental stream:
  exact source-free chord actions/pitches/velocities, cell/frame positions and
  real context/pitched/percussion provider tokens and latent states. Preserve
  continuation holds and the partial final cell. Failed/cancelled capture must
  not publish an accepted timeline.
- AC2: A primary portable checksummed codec and sequential journal retain those
  records with explicit bounds, original ordering and continuity validation.
  Reject truncation, corruption, malformed clocks/parts and discontinuities.
  Native/pas2js consumers share the implementation; filesystem I/O is native.
- AC3: Replay retained frames through the existing primary instrument stream,
  without learning, models or WFC solving. Exact replay reproduces actual mix
  and stems across different pull sizes; an instrument edit changes that part
  while retaining the score and unrelated parts. Keep memory bounded by one
  segment and normal synthesis lookahead.
- AC4: Ordinary native playlist generation saves the journal and its bound
  completion metadata with actual job/settings/model lineage. Exercise that
  native consumer and replay its actual saved decisions. Partial/failed jobs
  cannot present the journal as a completed result. Studio follow-up controls
  remain in the parent graph-controls task.

**Blockers**

- [Instrumental streams — DONE](NS-6_instrumental-streams_01.md).
- [Style vocabulary — DONE](NS-3_style-vocabulary_01.md).

**Dev Notes:**

- 2026-10-31, Big Boss, AC1–AC4 accepted. The actual WFC stream emits detached
  bounded context/H/R/pitched/percussion token/state rows with the exact performed
  chord cells, predecessor and fractional/clipped frame clock. Admission consumes
  that same primary projection; the earlier second projection loop is removed.
  Primary music.decisions owns UTF-8/checksummed chunks and sequential journal
  continuity. Primary music.replay performs those cells through the existing
  instrument stream, without any model/learner/WFC import. Memory is bounded by
  a chunk and active synthesis state; duration increases disk storage only.
- Final native and actual pas2js: decision codec35, actual instrumental replay387.
  Canonical supplementary-Unicode payload hashes match across targets. Every saved
  provider state projects to its actual source-model token. Mix and all six parts
  replay exactly on each target across different pull sizes; changing the bass
  instrument changes bass/master while five unedited parts remain exact. Journal
  bytes stay unchanged. Holds, clipped last cells, invalid extents, corruption,
  truncated input, cancellation/reentry and partial writes are exercised. Existing
  native instrumental-stream4043522 checks pass, including bounded long admission.
- Actual native playlist/worker215 passes with clean heap: ordinary generation
  saves decisions into the configured generated-artifact store, completes an
  immutable job/settings/model receipt, then opens/hashes its saved file and
  replays exact mix and six stem WAV hashes through the primary replayer. Partial
  receipts and changed byte counts reject. Duplicate publication verifies/reuses
  identical immutable content after flushing its file. New metadata is small; no duration-sized
  JSON score is introduced. Native service/worker delivery binaries compile.
  All native heaps are clean. No operator responses or source audio were changed.
- Preserve initial duplicate interface/implementation chord import and missing
  test pitch-kind/bus imports in their compile logs. The unqualified default
  authored fixture fails its actual graph at the first segment; no seed sweep or
  solver relaxation repairs that musical request. Replay checks use the existing
  explicit authored motif fixture instead. A test initially assumed the JS2^53
  bound on native Int64; it now tests the primary target's actual timing limit.
  An initial native ASCII-prefix/Unicode concatenation changed the fixture's
  scalar bytes; direct canonical scalar input gives matching native/JS bytes,
  with no product transcoding workaround. All failure evidence remains under
  decision-replay-20261031-boss on E. This is Big Boss's solo verification.
- This closes the distinct prerequisite, not the parent task or a musical-quality
  verdict. Retained provider rows are observations, not arbitrary graph-injection
  authority. Studio sound-only follow-ups and scoped regeneration are next in
  [graph-controls](../NS-4_graph-controls_01.md); no further infrastructure audit
  is selected. New journals are not fabricated for historical jobs. Full hour/
  24hour journal renders and physical phone capture are not newly qualified.

- 2026-10-31, Big Boss: inspection confirms PlanSegment discards each temporary
  accepted voice segment; RunStudioPlaylistStream saves model/settings JSON only.
  Finite TInstrumentalPlan.Reperform and accepted-session records cannot restore
  this ordinary long-stream consumer. Retain actual decisions here, rather than
  silently solving the old models again and calling that retention. Deliver the
  bounded portable channel/journal/replayer and real worker consumer. Check exact
  same-target PCM/stems, holds, different pulls, changed sound, failure and actual
  native/pas2js codecs. Stop before adding Studio follow-up UI or changing graph
  decisions. Packet: decision-replay-20261031-boss under E-drive roots. New scope
  adds5 units;79/124 is63.71%, with7 open and16 current DONE. Prior batch closed
  real criteria; consecutive nonclosing count starts at zero.
