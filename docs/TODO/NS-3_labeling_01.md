# NS-3_labeling_01 — Build a durable Pascal audio-label catalog

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver the native Pascal source, proposal, review and export service for an
operator-authored WAV training/reference catalog. The agent prepares source
WAVs and an inbox manifest; the operator can import all available tracks into
a durable catalog. Pythian's inferred events are **unreviewed suggestions**,
never acoustic truth or training labels merely because they were generated.
The [pas2js workbench](NS-6_authoring_01.md) owns the operator interface.

North star: NS-3. Outcome owner: WAV-03-LABELING.
Completion credit: 2 goal percentage points (0.50 overall points), assigned
from the 4 unearned points of [NS-3_notes_03](NS-3_notes_03.md). That task retains
2 points and all of its original phrase and inferred-event criteria. The
accepted [WFC bridge](DONE/NS-3_notes_06.md) retains its earlier 1 point;
the original 5-point allocation is now 1 + 2 + 2, with no new credit.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [source-bound presence](../PRESENCE.md) · [beat reports](../BEAT-GRIDS.md) ·
[shared evaluation](../EVALUATION-OPERATOR.md) · [recorded source audit](NS-3_tempo_04.md).

**Acceptance Criteria:**

- Define a versioned, extensible label contract with original WAV SHA-256,
  sample rate, integer source-frame half-open spans, source/group identity,
  provenance/license, label type/value, reviewer, status and revision. Cover
  at least beats/downbeats, note spans/pitch, audible instrument/rest/unknown,
  part or source roles, phrase/section spans and user-defined style preferences;
  later label types may use versioned extensions. Keep
  Pythian proposals, operator-approved labels, rejected proposals and unknown
  intervals distinct. No inferred label is silently promoted to reviewed.
- Provide a native FPC inbox/import path for multiple agent-prepared WAVs and
  manifests. Hash and validate each original, deduplicate by identity, preserve
  durable source assets outside disposable `build/`, and expose bounded
  waveform summaries and region audio without loading a multi-hour recording
  into memory. The operator can import all prepared tracks in one action;
  unsupported WAV geometry fails per track without losing successful imports.
  A manifest may declare synchronized stems on one source clock, but unrelated
  recordings must never be silently aligned.
- Run only maintained Pascal analysis/inference to create optional proposals
  for supported label types, retaining analyzer/model/policy identity and
  source-frame evidence. Unsupported dimensions stay unproposed or `unknown`;
  do not execute TensorFlow, ONNX, HDF5 or other inference runtimes. Keep the
  portable `pythian` core independent of the service and browser.
- Persist review edits as an auditable, reversible history with bounded writes,
  revision/conflict checks, source-hash checks and failure-safe publication.
  Support approval, rejection, new labels, boundary/value edits and explicit
  uncertainty. The native API must allow a blind evaluation review that hides
  Pythian's proposals until the operator commits a label.
- Export a deterministic, versioned catalog packet consumable by Pascal
  training and evaluation tools: only reviewed labels enter the selected
  training/reference split, unknowns remain unknown, and source-group
  train/development/evaluation separation rejects leakage. Retain original
  source hashes, coordinates, review history and policy identity; replay and
  re-import the packet without changing its meaning. Do not write personal
  style-source labels into tracked corpus Markdown files. Do not bundle source
  audio in an export by default; carry usage/provenance restrictions explicitly.
- Expose a bounded local HTTP API for the workbench's inbox, catalog,
  waveform/audio regions, proposals, reviews and exports. Bind to loopback by
  default; any LAN access needs an explicit opt-in and access control. Restrict
  paths to the configured roots. Use the pinned WFC/Phanes Pascal static-server
  pattern only as a reference where useful; preserve copied notices and
  provenance, and do not edit dependency source in this checkout.
- Pass focused checked stable Win32/Win64 service, round-trip and failure
  checks, including multi-track import, duplicate/stale source, large-WAV
  bounded work, conflicting edit, rejected write and group-leak prevention.
  Exercise at least one real source-bound proposal-to-reviewed packet without
  claiming Pythian's suggestion is an acoustic label.

**Blockers**

- [NS-3_validation_01.md — DONE](DONE/NS-3_validation_01.md)
- [NS-3_validation_02.md — DONE](DONE/NS-3_validation_02.md)

**Dev Notes:**

- 2026-09-25 user-directed gap: publisher labels have not supplied a defensible
  generic same-recording instrument rest at the required exact windows. This
  catalog creates a controlled path for human-authored evidence and reusable
  training data. It does not itself supply a reviewed rest, a successful beat
  challenge, a corpus or task credit. Source files imported for authoring must
  be durable and separately accounted for so routine build cleanup cannot
  remove the catalog.
- The checked local pas2js and FPC development commands report 3.3.1. This
  establishes tool availability, not a passing application build; stable native
  server targets and actual browser behavior remain acceptance work.
- 2026-09-25 first import boundary: `tools/pythian.label.catalog.lpr` and
  `pythian.tools.annotations.catalog` accept one prepared multi-WAV manifest,
  stream SHA-256 and WAV geometry, copy verified originals into a separate
  catalog root, reject group/partition leakage, and replay records in sorted
  source-hash order. Import never creates a proposal or reviewed label. Checked
  stable FPC 3.2.2 Win32 and Win64 builds both imported two development-exposed
  30-second WAVs; repeat import returned two duplicates. A mixed failure packet
  returned one duplicate and three isolated failures (wrong hash, split
  partition, unsafe basename) while retaining the two valid records. Copied
  asset hashes matched the declared source hashes. Fixtures are ignored under
  `build/label-catalog/`; a real operator catalog must be placed outside build.
  [The importer contract](../LABEL-CATALOG.md) describes the prepared packet.
  The follow-on native region reader returns exact source-frame waveform bins
  (at most 2,048 bins across 8,388,608 frames) and writes a bounded 30-second,
  16-MiB PCM16 listening region without loading the whole source. Checked
  Win32/Win64 one-second waveform JSON hashes matched; a Win64 region encoded
  44,100 stereo frames in 176,444 bytes. Invalid bounds rejected and removed
  the staged output. HTTP delivery, actual long-source performance, proposals,
  review history, export and browser interactions remain open; no task credit.
- Checkpoint after the import and region batches: neither closed the whole
  multi-track import criterion. Finish that bounded criterion before adding
  review features. The next evidence is a real multi-hour source imported and
  paged, an unsupported WAV that fails beside valid tracks, and a stale source
  that cannot change an existing record.
- The bounded long-source check used a 1,559,617,614-byte, 389,904,384-frame
  stereo WAV at 48 kHz, alongside a valid short WAV and invalid RIFF. The
  two valid tracks imported while the invalid one failed in its own row. A
  zero-channel RIFF also failed beside a duplicate valid row; a changed copy
  failed hash validation without changing the two listed catalog records.
  Three 2,880,000-frame waveform pages at the start, middle and end each
  produced 300 contiguous, finite bins; an ignored Pascal verifier checked
  exact outer coordinates and a final one-second, 48,000-frame PCM16 region.
  Stable Win32 and Win64 hashes matched for the final page and region. A
  page beyond 8,388,608 frames rejected without reading it. The temporary
  large catalog copy remains in ignored `build/label-catalog/long-catalog/`:
  automatic approval review rejected both recursive cleanup and deletion of
  its exact WAV as "blocked by policy". Keep this visible for approved manual
  cleanup. Source import and paging are evidenced; actual durable-root
  configuration, HTTP consumption and every other criterion remain open.
- The next review-contract batch added immutable numbered review events with
  source hash, sample rate/group, provenance/license, label type/value, exact
  source-frame span, reviewer, status and revision. The Pascal validator covers
  beat/downbeat, note/pitch, presence, part/source role, phrase/section, user
  style preference and versioned extension forms. Checked stable Win32/Win64
  runs agreed on a create, moved uncertain edit and restored earlier label;
  a stale revision and out-of-range span published no event. A same-size
  tampered source failed its SHA-256 check with revision still zero. All reviews
  were artificial `operator-test` fixtures in ignored build catalogs, not
  acoustic judgments. Proposal existence, current-label projection, efficient
  multi-hour edit verification, blind mode, reviewed export, service and UI
  remain open. No criterion or task credit is claimed from this batch.
- Checkpoint after the long-source and review-history batches: neither closes a
  whole criterion. The next bounded deliverable changes from import/ledger
  plumbing to an operator-consumable current-label projection plus a separate
  native beat-proposal packet linked to source-frame evidence and analyzer
  policy. Validate proposal identity during review. If the existing bounded
  Pascal beat analyzer cannot produce a defensible packet, stop this proposal
  path rather than fabricating acoustic labels. Contract and proposal criteria
  remain open until the two paths are exercised together.
- A native source-bound packet now uses `MeasureWaveBeats` over at most
  30 seconds / 2,000,000 frames of an imported WAV. It stores onset observations,
  candidate pulse frames, analyzer/model/policy IDs and `unreviewed` state apart
  from reviews. A 15-second development-exposed piano crop produced 68
  observations and eight candidates. Checked stable Win32/Win64 candidate IDs,
  observation counts and candidate frame lists agreed; score/BPM differences
  were below eight printed decimals. Repeating publication on Win64 was
  idempotent. A one-second digital-zero control emitted zero observations and
  zero candidates. A nonexistent proposal ID was rejected before review publication;
  an artificial `operator-test` rejection linked a stored proposal and appeared
  next to a separately withdrawn note in the bounded current-label projection.
  These are mechanics, not evidence that any suggested beat or note is correct.
  Exact musical review, blind mode, efficient multi-hour review verification,
  deterministic reviewed export, HTTP service and pas2js UI remain open; no
  criterion or task credit is claimed.
- Next batch: bind the existing native catalog APIs to a loopback-only HTTP
  service with bounded request/response work, configured roots and source path
  containment. Validate real GET/POST requests, a rejected stale revision and
  no path escape before advancing the browser. Keep LAN unavailable until
  authentication exists.
