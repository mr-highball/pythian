# NS-3_labeling_01 — Build a durable Pascal audio-label catalog

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Deliver the native Pascal source, proposal, review and export service for an
operator-authored WAV training/reference catalog. The agent prepares source
WAVs and an inbox manifest; the operator can import all available tracks into
a durable catalog. Pythian's inferred events are **unreviewed suggestions**,
never acoustic truth or training labels merely because they were generated.
The [pas2js workbench](../NS-6_authoring_01.md) owns the operator interface.

Accepted 2026-09-26: all seven native catalog criteria passed. The maintained
FPC service imports verified multi-WAV manifests into a separately configured
durable root, streams bounded waveform/audio pages, stores source-bound Pascal
proposals apart from reversible reviewed events, gates blind evaluation, and
exports an audio-free source/group-bound packet that replays unchanged. Checked
stable Win32/Win64 import, service, conflict, failure, large-WAV and packet
checks are recorded in [WORK](../../WORK.md#publisher-linked-note-packet-through-pascal-training--2026-09-26)
and the [catalog guide](../../LABEL-CATALOG.md). A real development-exposed
publisher-linked packet explicitly approved a physically supported downbeat
and rejected a Pythian beat-grid miss. A separate two-group training-path
packet carried two publisher key gates through fresh-catalog replay, the
Pascal reviewed-note adapter and saved WFC journal/model rebuild with identical
Win32/Win64 hashes. Salty Boi's final criterion audit found no native task
blocker. These examples do not establish independent evaluation, audible
note endings, a genre style or the separate browser workbench acceptance.
The task earns +2 NS-3 / +0.50 overall: NS-3 **43→45%**, total **70.20→70.70%**.

North star: NS-3. Outcome owner: WAV-03-LABELING.
Completion credit: 2 goal percentage points (0.50 overall points), assigned
from the 4 unearned points of [NS-3_notes_03](../NS-3_notes_03.md). That task retains
2 points and all of its original phrase and inferred-event criteria. The
accepted [WFC bridge](NS-3_notes_06.md) retains its earlier 1 point;
the original 5-point allocation is now 1 + 2 + 2, with no new credit.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [source-bound presence](../../PRESENCE.md) · [beat reports](../../BEAT-GRIDS.md) ·
[shared evaluation](../../EVALUATION-OPERATOR.md) · [recorded source audit](../NS-3_tempo_04.md).

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
  default; let the operator explicitly bind a private LAN IPv4 address and
  require an access key before LAN clients can read audio or edit labels.
  Restrict paths to the configured roots. Use the pinned WFC/Phanes Pascal static-server
  pattern only as a reference where useful; preserve copied notices and
  provenance, and do not edit dependency source in this checkout.
- Pass focused checked stable Win32/Win64 service, round-trip and failure
  checks, including multi-track import, duplicate/stale source, large-WAV
  bounded work, conflicting edit, rejected write and group-leak prevention.
  Exercise at least one real source-bound proposal-to-reviewed packet without
  claiming Pythian's suggestion is an acoustic label.

**Blockers**

- [NS-3_validation_01.md — DONE](NS-3_validation_01.md)
- [NS-3_validation_02.md — DONE](NS-3_validation_02.md)

**Dev Notes:**

- 2026-09-26 a separate development-exposed training-path packet now contains
  two approved publisher performance key gates from distinct original source
  groups, alongside the earlier explicit beat proposal rejection/downbeat.
  Fresh-catalog replay preserves the packet SHA-256; the Pascal WFC adapter
  admits only the approved pitch gates, and checked Win32/Win64 journal/model
  hashes match. The original development-partition packet is correctly refused
  for training. Key-off frames are not independently reviewed audible endings,
  and this is no held-out or genre acceptance. Salty Boi is auditing the whole
  native task against every criterion before completion accounting.
- 2026-09-25 a real, development-exposed publisher downbeat now passes through
  source-bound Pascal proposal, explicit curator approval/rejection and
  deterministic reviewed export. The first saved beat-grid candidate missed
  the physically supported publisher downbeat by 115.193 ms; the publisher
  event was approved without linking the proposal, and that candidate was
  explicitly rejected. A fresh source-matched catalog re-imported the packet
  and re-exported identical bytes after shortening a replay stage path that
  had exceeded the Windows file limit. Salty Boi's checked Win32/Win64 replay
  and wrong-source failure checks passed without stage residue or leaks. This
  is neither independent evaluation nor an operator listening verdict. The
  remaining catalog acceptance gates stay open; no credit claimed.
- 2026-09-25 the native service now has a bounded beat-cue audition route for
  one stored unreviewed candidate. It checks the source-bound packet and blind
  evaluation gate before rendering markers over the original audio; cue output
  is never a reviewed label. Stable Win32/Win64 builds and Salty Boi's focused
  route/browser QA pass; two candidate cues retained source geometry, rejected
  invalid/blind requests and left proposal/review files unchanged. This is
  operator support, not a real acoustic
  proposal-to-reviewed example or completion credit.
- 2026-09-25 the three user-selected complete mixes now reside in a durable
  catalog outside `build/`, with distinct development-exposed training groups.
  Native Win64 import verified three original and copied WAVs; reviewed packet
  export reverified the assets and inspected at three tracks with zero review
  events or selected labels. The same LAN service now points to this catalog.
  This exercises the durable import boundary with real multi-hour files, but
  their style names are user preference candidates, not reviewed timed labels
  or independent evaluation groups. Real proposal-to-reviewed evidence and
  other task criteria remain open; no credit is claimed.
- 2026-09-25 the reviewed packet now has a Pascal WFC training consumer:
  `ReadReviewedNoteSource` binds an original WAV hash and exact part to its
  training-split packet track, maps approved note/rest/unknown spans, and
  rejects overlap, absent audio and held-out partitions. An artificial
  three-track import/review/export fixture reached a two-group Pascal journal
  rebuild on checked Win32 and Win64; journal replay was exact. These
  artificial labels establish the consumer path, not acoustic truth or the
  remaining real proposal-to-reviewed evidence criterion. No task credit yet.
- 2026-09-25 focused criterion audit: the native HTTP criterion is met at
  its declared local-service scope. The maintained host exposes the specified
  bounded inbox/catalog, waveform/audio, proposal, review and export routes;
  it uses configured roots and a whitelist of static assets, binds loopback by
  default, and accepts an explicit private IPv4 with an access-key session
  before LAN data access. Prior checked Win32/Win64 request, conflict, path and
  token checks are recorded in WORK. Current `192.168.12.109:18097` returned
  the updated page, and its data route rejected an unauthenticated request.
  A separate phone and Windows firewall rule are NS-6 usability/deployment
  evidence, not claims made by this native HTTP criterion. Other catalog
  criteria, especially real reviewed source evidence and training consumption,
  remain open; no task credit is claimed.
- 2026-09-25 a Pascal evaluation consumer now builds a source-bound presence
  reference from the reviewed packet and original WAV. It retains unknown and
  ambiguous centers, refuses proposal-linked presence for independent reference,
  and supports the evaluator's exact `audible-presence` vocabulary. Checked
  stable Win32/Win64 builds and complete/partial reference gates passed. An
  artificial `operator-test` packet produced byte-identical references on both
  targets; this does not qualify acoustic truth, a real operator review or the
  broader training consumer. No completion credit is claimed.
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
  [The importer contract](../../LABEL-CATALOG.md) describes the prepared packet.
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
  no path escape before advancing the browser. The user then required mobile
  access on the local LAN. The first native host now accepts an explicit private
  IPv4 bind address; LAN mode requires a 16-character-or-longer environment
  access key and an authenticated session for all data endpoints. Checked stable
  Win32/Win64 builds passed. Real loopback requests returned catalog, bounded
  waveform/audio and current labels; wrong token returned 403 and stale review
  revision returned 409. A real request to 192.168.12.109 returned 403 without
  a token, 403 with a wrong access key, and 200 for login, catalog and audio
  with the issued token. LAN startup without a key failed. The attempted
  encoded traversal target returned 400 and a foreign Host header returned 403;
  neither addressed a configured root. A checked Win32 loopback host returned
  its session and two catalog tracks.
  Browser static serving, inbox/proposal reads, reviewed export, blind mode,
  mobile playback and independent QA remain open. No criterion or task credit.
- The first reviewed export packet is deterministic and audio-free, with source
  identity, group/partition, provenance/license, full numbered review events,
  selected current approvals and separate explicit unknowns. The Pascal reader
  replays history and rejects a changed selected label or split source group.
  A two-track ignored fixture with artificial `operator-test` edits yielded
  identical checked Win32/Win64 SHA-256
  `2842396cb78c6d7e6b337ab1211e6c013e4582559029e55628570b59f663498b`:
  three selected labels, one unknown, five review events. Case-distinct label
  IDs now survive both current projection and export. Existing output,
  conflicting group metadata and changed source byte count each rejected
  without new output or partial files. Win32 re-read the Win64 packet with the
  same hash and counts. This is schema/replay evidence, not musical review.
  The current 64-MiB single-file bound, destination-catalog replay, actual
  Pascal training/evaluation consumption and HTTP/browser export remain open.
  No criterion or task credit is claimed yet.
- The first **label-contract acceptance criterion is now evidenced** without
  acoustic claims. An ignored `operator-test` source packet committed beat,
  downbeat, note/pitch, presence audible/rest/unknown, part/source roles,
  phrase/section, style preference and a versioned `ext.test` label. Each event
  retained original source SHA-256, sample rate, source-frame span, group,
  rights, reviewer, status and revision. Publishing eight native beat
  suggestions left review revision at five and kept their status `unreviewed`;
  an explicit later rejection of one stored proposal reached revision 15.
  A checked Win64 export read by Win32 contained 12 selected approved labels,
  one separate unknown and 15 history events, with neither uncertain nor
  rejected status in the selected set. Its SHA-256 is
  `0fdcfd3ce1009f6402ae6bcbb0b44f2716056049b5fef7551648ae4203217722`.
  This closes the contract criterion only. All other acceptance criteria and
  task credit remain open; these synthetic judgments are not training truth.
- The authenticated native API now exposes `GET /api/inbox` with per-row
  unverified/missing/invalid preparation state and `GET /api/proposals` for one
  stored source/window packet. It never reruns inference on a read. It withholds
  proposal reads and generation for evaluation tracks until blind review is
  implemented. Checked stable Win32/Win64 builds passed. Real requests to
  `192.168.12.109` returned 403 without a token, 403 for a wrong access key,
  then two inbox tracks and eight `unreviewed` beat candidates with a valid
  session; a missing window returned 404. A checked Win32 host returned 403
  for both proposal operations with a temporarily evaluation-partitioned
  fixture. A changed stored candidate identity failed both read and review,
  leaving review revision 15. The fixture bytes were restored. Browser
  serving, blind review, HTTP export, durable deployment and mobile usability
  remain open; no additional criterion or task credit is claimed.
- The native host now serves only the three explicitly configured workbench
  assets (`index.html`, `app.js`, `style.css`) from a fixed build root on the
  same origin as its authenticated API. The `serve-app` command retains
  loopback by default and accepts an explicit private IPv4 address. A real
  browser loaded the assets and exercised catalog, waveform, original WAV,
  proposal and review routes against a copied two-track catalog. A separate
  `192.168.12.109:18095` listener returned 403 without a token and allowed
  browser access-key login and catalog load. The Windows firewall path from a
  separate physical device is not yet verified. Browser export/re-import,
  blind evaluation reveal, and durable operator-root deployment remain open;
  no new task criterion or credit is claimed.
- Blind evaluation is now source-gated in both HTTP and CLI proposal reads and
  generation. An evaluation source with zero reviews returns 403; a first
  review linked to a proposal or marked withdrawn/rejected cannot unlock it.
  A first independent approved `presence=unknown` review advanced an ignored
  fixture to revision 1; the same stored eight-candidate packet then remained
  `unreviewed` but became readable. A browser path loaded that evaluation
  source, played original audio, showed proposals only after the independent
  review and saved a later label. Checked stable Win32/Win64 builds passed.
  The gate is source-level; multiple independent reviewers on one source still
  need separate blind sessions if that becomes an evaluation requirement.
- `GET /api/export` now emits the full deterministic reviewed packet behind
  the normal LAN token check. A two-track ignored fixture returned two selected
  labels, one separate unknown and three history events. Its HTTP bytes and
  native CLI export had the identical SHA-256
  `a1a13279d03af78bb00d35de7097d9dae41a1ee2fb02f9845fec9cf937d7bb30`.
  On LAN, an unauthenticated export returned 403 and an authenticated export
  returned 200. A destination-catalog replay remains absent. The audio-free
  packet also does not carry definitions for proposal IDs referenced in review
  history, so replay must preserve that evidence or explicitly constrain the
  replay contract before the task can be accepted. No new completion credit.
- The current packet now includes only proposal packets cited by review history;
  the Pascal reader verifies every cited candidate ID. `import-reviewed`
  preflights the destination's source records and original WAV hashes, stages
  proposal and review evidence, publishes proposals before reviews, refuses a
  different existing history, and reports `duplicate` on identical replay.
  Checked stable FPC 3.2.2 Win32 and Win64 builds passed. A two-track,
  15-event artificial-review fixture restored one linked proposal packet into
  a freshly imported catalog. Re-export matched the input SHA-256 exactly:
  `de3493e2b01400dd86ca19e2bef7e1a181e341a8cdca2458e70192a6d5d072ca`.
  Repeat replay was a duplicate on both targets; Win64 rejected a one-track
  destination before writes. This establishes packet replay mechanics, not
  acoustic truth or training-tool consumption. No additional criterion or
  task credit is claimed.
- The authenticated HTTP host now accepts a reviewed packet upload of at most
  64 MiB and calls the same Pascal validator and replay path as the CLI. The
  parser keeps ordinary JSON edits at 16 KiB and checks the session token
  before allocating the larger upload body. A checked stable Win64 host
  restored the 21,224-byte two-track fixture into a fresh catalog, then its
  HTTP export matched the input bytes. Malformed `{}` returned 422; raw
  unauthenticated headers returned 403 and an over-64-MiB length returned 413.
  Checked stable Win32 compilation and duplicate replay also passed. The
  uploaded reviews remain artificial test events; actual training/evaluation
  consumption and other task criteria remain open, with no new credit.
