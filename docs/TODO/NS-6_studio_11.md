# NS-6_studio_11 — Browse collection metadata and prepare recordings only on use

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Make Refresh library a quick directory/metadata discovery operation. The
accepted [large-library refresh](DONE/NS-6_studio_09.md) removed redundant
copies, but still verifies every original twice and every existing catalog
recording once. Its byte counter describes server disk reads, not phone
downloads. Those reads do not belong to routine collection listing.

Separate discovery, bounded audition and verified corpus admission. The
operator can browse and hear a selected region before paying for full content
verification; adding a recording or passage prepares only that recording.
Keep existing saved corpora and their immutable source identities usable.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [delivery_03](NS-6_delivery_03.md),
which retains every final-package criterion at 2 NS-6 points. No accepted
credit is withdrawn or earned by this scope change.

Execution status: selected on 2026-10-01; OPEN. Big Boss owns the contract,
HTTP integration, accounting and final judgment. Neo owns native discovery,
selected preparation and job integration; Ticket Guy owns the disjoint browser
consumer. Salty Boi performs final independent QA once native and UI components
are ready. The preceding nonclosing-batch count was 1. AC1's native discovery
contract now passes independent checks and the actual collection proof below;
that criterion closure resets the count to 0, with no whole-task credit.

Batch deliverable: AC1–AC3 native behavior and AC4's integrated operator flow.
Closing evidence: bounded read counters/fixtures, native job and HTTP checks,
desktop/narrow consumer checks, preserved catalog identities and a timed
metadata-only discovery of the actual collection. Stop and reassess if discovery
still reads PCM payloads, a pending metadata identity reaches training as an
audio hash, an unrelated recording is prepared, data is lost, or a distinct
prerequisite emerges. Record execution gates separately from implementation
failures; do not infer actual listening from a screenshot or compilation.

**Acceptance Criteria:**

- AC1: Refresh discovers names, collections, sizes and bounded WAV-header
  geometry without full audio hashing, decoding, copying or importing. Persist
  a bounded metadata snapshot; listing and reconnect read that snapshot. Expose
  opaque entry/snapshot identities and honest availability/preparation states,
  never a metadata digest labeled as a source audio hash. Reject unsafe paths,
  retain the previous complete snapshot on failure and handle changed/missing
  entries. Prove payload-independent refresh work using a large-file control.
- AC2: Opening a discovered entry requests only its bounded visible waveform;
  Play reads/transfers only a requested bounded original region. No automatic
  full-media download or preparation occurs while listing. Resolve only indexed
  entries, recheck their metadata snapshot, bound ranges and preserve source
  time. This provisional preview is not scientific or corpus admission evidence.
- AC3: Explicit corpus use prepares only selected entries asynchronously with
  visible progress, cancellation and retry. Retain complete content-hash,
  header, family/partition and provenance validation before returning verified
  source identities to the existing project contract. Existing catalog sources
  can be reused without staging copies; new imports and changed originals get
  proper content identities. Same-size corruption must not pass because a
  filename, timestamp or length matched. Failure cannot replace a saved corpus.
- AC4: The browser presents collection names/durations immediately after
  discovery, preserves filters and drafts, merges known duplicate source cards
  without dropping their collection memberships,
  and makes preview, preparation and Add passage/whole recording understandable
  on desktop and narrow screens. Analysis/effects remain available through an
  explicit preparation path. Verify successful selected-only use plus stale,
  unavailable, failed and canceled recovery on an isolated small fixture.
  Independent QA covers native and browser boundaries together, preserves
  private live records and leaves no QA browser or looping audio. Portable
  integration and the actual collection metadata discovery are verified before
  full task acceptance; report any unexecuted browser/physical checks honestly.

**Blockers**

- [NS-6_studio_04.md](DONE/NS-6_studio_04.md)
- [NS-6_studio_09.md](DONE/NS-6_studio_09.md)

**Dev Notes:**

- 2026-10-01, Big Boss, AC1 accepted: independent bounded-read, identity,
  changed/missing/path/failure and snapshot checks pass on both Windows targets.
  A checked native CLI then discovered the actual three-recording collection
  (7,045,401,242 declared source bytes) in **109 ms**, reading **156 header bytes**,
  zero PCM bytes and importing/copying no audio. Snapshot readback was identical
  at the clock's 0 ms resolution. It used a fresh ignored catalog, never the
  live one, and launched no server/browser. Evidence is
  `build/studio-library-lazy/actual-metadata/`; its heap trace has zero leaks.
  The byte count measures parser reads, not physical storage traffic; elapsed
  time is one local run, not a phone or cold-cache benchmark. AC2–AC4 still need
  their HTTP/browser integration evidence. All 2,624 pre-existing live metadata
  hashes and five source size/time records remain unchanged. Full audio hashes
  were not recomputed. Whole-task credit remains zero; current completion 50.80.
- 2026-10-01, Salty Boi / Neo / Big Boss, limited engineering verdict:
  checked FPC 3.2.2 Win32 and Win64 independently pass discovery 55, focused
  jobs 13 and focused worker 18 assertions each, all with zero unfreed blocks.
  Neo's existing full-refresh regression retains 421 passing Win64 assertions.
  The discovery control intercepts reads against a 16 MiB WAV and rejects any
  PCM read; ordinary three-file discovery reads at most 132 header bytes.
  Selected preparation covers full hashes, same-size corruption, metadata
  mutation, cancellation/retry and preservation of unrelated membership.
  Nine native source identities and fourteen staged candidate artifacts match.
  Matched pas2js compilation and static UI/HTTP review pass; no concrete static
  defect was identified. Evidence: `build/salty-studio-library-lazy-20261001/`
  and `build/studio-library-lazy/`. These results do not prove browser behavior.
- 2026-10-01, Big Boss, execution gate: automatic approval review rejected
  the isolated fixed-slot native HTTP/normal trusted HTTPS QA launch before
  execution, reporting only `blocked by policy`. No server, client or browser
  ran from that rejected action, and no alternative launch retried it. Final
  QA listener/server/worker counts are zero; no QA audio was started. HTTP
  integration and desktop/narrow interaction remain unexecuted. The prepared
  candidate is a review checkpoint; the live stable service is unchanged.
  Studio_11 stays OPEN and earns no task credit. Independent implementation QA
  failures remain zero. The earlier developer retry test read `retry_of` from
  the wrong JSON level; correcting the test oracle did not repair production
  code and is not a failed independent implementation submission.
- 2026-10-01, Big Boss / Neo / Ticket Guy: the operator observed a
  multi-gigabyte Refresh counter. Read-only tracing found JSON job polling on
  the phone and full hash passes on the host. Studio_09's earlier acceptance
  remains valid for its narrower no-recopy outcome. This new task owns the
  distinct discovery/admission separation; it does not reset old task failure
  counters or count planning as product completion.
- 2026-10-01, Big Boss / Ticket Guy, development integration repairs before
  first independent QA: bind asynchronous preparation to its original draft
  and edited selection; a canceled recording's job ancestry cannot be reused
  for another entry. Merge verified aliases' collection memberships before
  removing duplicate cards. Inspect saved selections through a detached catalog
  row so changed/missing originals cannot replace their audible source or demand
  impossible preparation. Big Boss enabled the existing bounded `/api/audio`
  route's media-cookie authentication for the catalog-only player. Frontend
  compile/freeze evidence is in `build/studio-lazy-ui/`; the native HTTP client
  in `build/studio-library-lazy/` checks both media paths and corpus admission.
  These are pre-submission repairs, not failed independent QA submissions;
  the current task's submitted failure count remains zero.
