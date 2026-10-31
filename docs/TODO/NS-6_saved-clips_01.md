# NS-6_saved-clips_01 — Independent saved clip audio and source lineage

[Tasks](README.md) · [Milestones](../MILESTONES.md) · [Studio](../OPERATOR-STUDIO.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** In progress
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

- 2026-10-31, Big Boss: explicitly requested while repairing
  [Generate activity — DONE](DONE/NS-6_generation-activity_01.md). Existing ranges remain
  metadata-only and SourceHash prepares a complete library entry before learning
  the selection. Implement independent clips rather than treating better labels
  as the I/O repair. Use one primary lossless range-copy implementation; avoid
  a new one-off reader or forced PCM16 conversion. Do not claim an unverified
  parent payload hash as a newly measured full-file identity. Return to
  [graph controls](NS-4_graph-controls_01.md) after this operator blocker.
