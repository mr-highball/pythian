# NS-6_saved-clips_01 — Independent saved clip audio and source lineage

[Tasks](../README.md) · [Milestones](../../MILESTONES.md) · [Studio](../../OPERATOR-STUDIO.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Accepted — 2026-10-31
**Owner:** Big Boss (single agent)

**Description:**

Saving a passage must create independent audio linked to its original recording
and exact source-frame range. The current playlist stores range metadata and
reprepares/verifies the whole original track on each Generate. The operator's
short clip therefore causes gigabytes of unrelated reads. Preserve original
recordings and immutable project/feedback history while learning from clip files.
Primary attribution: NS-6; this directly unblocks practical coarse corpus learning.

**Acceptance Criteria:**

- AC1: Saving a clip automatically materializes its independent WAV with bounded
  shared Pascal I/O. Preserve source sample format and selected sample bytes;
  retain parent identity/metadata, exact half-open source range, clock, clip hash
  and license/provenance links. Labels remain linked without altering audio.
- AC2: Learning verifies and reads the selected clip files, without opening,
  hashing or copying the full parent again. Reuse identical saved clips. Preserve
  original-time ancestry, influence, classification and coverage in receipts.
- AC3: Clip creation has visible native progress, failure/cancellation and durable
  completion independent of the phone. Preserve old selections and migrate their
  clips when used; no synchronous full-track operation blocks draft saving.
- AC4: Reject missing/truncated/corrupt clip data or incomplete publication without
  silently substituting the parent or claiming success. A valid saved clip remains
  usable if its original recording is unavailable. Keep original comparison tied
  to the actual selected audio, with honest parent availability.
- AC5: Validate actual native save/learn/reuse, unrelated-byte avoidance and failure
  boundaries, plus desktop/phone clip creation and ordinary Generate/reconnect.
  Keep all audio/private metadata/generated output outside source control under
  the dedicated workstation workspace.

**Blockers:**

- None. Reuse the primary WAV reader/writer, existing source metadata contracts,
  durable native jobs and configured private storage. A new generic WFC feature
  is not required.

**Dev Notes:**

- 2026-10-31, Big Boss: AC1–AC5 pass. The primary WAV reader copies exact selected
  sample bytes through the shared RIFF/RF64 header and canonical native audio
  store. Metadata-only parent admission is explicit; independent WAV hashes are
  actual measured identities. Durable clip-save jobs enqueue after draft saving,
  reconcile repeat/retry requests, report progress and preserve accepted files.
  Ordinary learning materializes old ranges and thereafter opens only saved
  clips. Grouped track coverage/influence stays separate from physical clip
  hashes/local clocks; contributions retain original-time ancestry. Distinct
  excerpt origins can share identical audio without inventing a parent hash.
- Closing evidence: packet `saved-clips-20261031-boss` in dedicated E-drive roots.
  Portable reader 155,930 checks pass on Win64, Win32 and actual pas2js; existing
  native reader/stream checks pass. Musical corpus 379 checks pass native/pas2js;
  playlist 257 checks and native clip 32 checks pass with clean native heaps.
  Actual native save/learn/reference works with the original unavailable and no
  full-parent catalog copy. Missing accepted audio causes a retained failed job;
  corruption, cancellation before receipt publication and reuse boundaries pass.
  Full browser build/codec/progress checks pass. Desktop and 390px IAB consumers
  define/save/reopen/play/download clips, generate and reconnect with the original
  held offline, and expose the real source range. Raw download 96,068 bytes and
  HTTP 206 byte ranges match the clip receipt. Native HTTP signed save/reload and
  automatic clip queue also pass with a clean heap; transient job state is kept
  outside the signed snapshot. No musical-quality credit claimed.
- Failure evidence retained: `playlist01.log` exposed identical-audio excerpts
  needing distinct real ancestry; repaired with optional immutable source origin,
  consistent audio clocks and parent-coordinate receipts. `clips-c2.log` rejected
  a test-mutated canonical file identity even after its bytes were restored;
  preserve that integrity rule and use distinct passages in subsequent fixtures.
  Initial QA needed an empty fixture inbox manifest. A browser Stop arrived after
  clip completion; the completed result remained intact. The fixture separately
  verifies queued cancellation/idempotent retry and interior copy cancellation.
- Deployment: matching service/worker plus twelve browser assets in fixed stable
  slot; same LAN/TLS/storage/firewall, all 17 prior job states/revisions unchanged.
  Stable service `fe77ecb16c91266d3085187fce326e0102f6ae2c370da1052bd0160d26ed6532`,
  worker `211c0442435dadee043112a54072df2013caa2e66331bdc5961dbaed5cf6cca6`.
  Big Boss performed solo checks; QA used separate fixture roots and managed IAB
  tabs, without launching a separate native browser or changing user tabs.
  All seven QA audio elements are paused with looping disabled; managed QA tab
  and exact native QA service are closed, viewport reset, no QA worker remains.
  Clip work closes five effort units; graph controls remain the next open task.

- 2026-10-31, Big Boss: explicitly requested while repairing
  [Generate activity — DONE](NS-6_generation-activity_01.md). Existing ranges remain
  metadata-only and SourceHash prepares a complete library entry before learning
  the selection. Implement independent clips rather than treating better labels
  as the I/O repair. Use one primary lossless range-copy implementation; avoid
  a new one-off reader or forced PCM16 conversion. Do not claim an unverified
  parent payload hash as a newly measured full-file identity. Return to
  [graph controls](../NS-4_graph-controls_01.md) after this operator blocker.
