# NS-6_studio_04 — Build style corpora from a private collection library

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Give the sole operator a durable, Git-excluded folder for audio collections,
discover those recordings in the web app, and classify whole recordings or
multiple selected passages into a caller-defined style corpus. Collection
membership organizes files; it does not prove a genre or musical annotation.
See the [Studio scope](../../OPERATOR-STUDIO.md).

Execution status: accepted engineering outcome — 2026-10-01. Big Boss accepts
private collection discovery, original audition and analysis, classified whole
and disjoint ranges, and immutable corpus reload.
Closing evidence: independent browser
`build/salty-studio-browser-20261001/VERDICT.txt` and
`FINAL-BROWSER-IDENTITIES.json`, with retained native evidence under
`build/salty-studio-native-20261001/` (stable FPC 3.2.2 Win32/Win64 and
matched pas2js 3.3.1). Source and staged candidate identities are exactly those
recorded in the manifests; this is not a new published-revision or build claim.
This task's engineering work is complete; stop at this accepted scope. No musical or
scientific inference acceptance or duplicate credit follows.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: one unearned point each transfers from studio_02 and studio_03; their
original criteria remain required. No credit is earned by scoping.

**Acceptance Criteria:**

- AC1: Provide a durable private directory outside disposable build output,
  excluded from Git, with caller-named collection subdirectories. Discover WAV
  files through an explicit refresh without operator-authored manifests.
  Bound work and report unsupported, missing, changed and duplicate sources;
  reject traversal and linked paths outside the configured library root.
- AC2: Browse/search collections and recordings in the app, audition original
  audio with visible source time, and select whole recordings or multiple
  nonoverlapping passages. Show selection count and duration. Caller-defined
  classifications belong to the chosen whole/range, may differ between ranges,
  and are preserved independently of collection folder names.
  Provide a waveform, playhead and shaded range overlays, with labelled analysis
  tools that reveal actual supported library features such as signal levels and
  beat candidates. Keep measured values, uncertain proposals and operator labels
  visually distinct; unavailable analysis is explicit, never fabricated decoration.
- AC3: Save and reopen classified selections as immutable, revision-checked
  project corpora. Exact source hashes, original frame ranges, classifications
  and collection provenance survive reload and training-job preparation.
  Folder renames, rescans or changed bytes cannot silently rewrite old corpora.
- AC4: Default discovered sources to unassigned with honest unknown provenance
  and license status; require explicit development/training use before learning.
  Preserve existing catalog metadata and evaluation/source-group isolation.
  Private paths and media stay out of tracked examples and public payloads.
- AC5: Independently validate native discovery/persistence boundaries and actual
  desktop/narrow collection-to-corpus use, including failure/retry and stale
  source handling. Confirm Git ignores the real local collection directory.

**Blockers**

- [NS-6_studio_01.md](NS-6_studio_01.md)

**Dev Notes:**

- 2026-10-01, Neo: Ticket Guy's Pascal collection scanner retains available,
  missing and changed membership without rewriting prior catalog metadata.
  New sources remain unassigned with unknown private provenance/rights; duplicate
  files retain their original family, license and evaluation partition. Listing
  is metadata-only; refresh performs bounded native hash/copy/import work in the
  asynchronous worker. Cancellation checks occur between those whole-file calls,
  not within every importer/hash operation. Linked/nested paths and count/byte
  limits reject. Collection metadata is frozen into classified whole or disjoint
  passage selections, with source-level weights kept separate from range count.
- 2026-10-01, Neo: independent Salty native QA passes 176 discovery controls plus
  two real linked-path controls and 100 project controls on each stable target,
  all with zero leaks. Source freezes and results are in
  `build/studio-native-handoff/` and `build/salty-studio-native-20261001/`.
  Root's development desktop/narrow inspector streams the original, saves/reopens
  two separately classified ranges and displays actual analysis jobs. Independent
  final collection/search/range/overlay failure and reload checks remain pending.
  Raw feature measurements and beat candidates are distinct from caller labels
  and musical truth. Native submitted failures remain zero; no credit yet.

- 2026-09-30, Big Boss: user clarified that preparation starts with a private
  collection library, not manually prepared catalog manifests. This distinct
  intake/classification gap receives its own task before expanding studio_02.
  Existing project setup acceptance remains historical and valid; new multiple
  ranges/classifications and library discovery are accepted here. No QA
  submissions yet. Pascal-owned import uses existing catalog integrity rules.
- 2026-09-30, Big Boss: the operator requests visible library capabilities while
  selecting ranges. The range inspector owns progressive waveform/analysis tools
  and overlays using existing supported Pascal APIs. This does not authorize a
  new stopped beat/inference experiment or turn candidate timing into truth.

- 2026-10-01, final acceptance — Big Boss accepts this task's scoped engineering
  outcome after independent native and browser evidence. See
  `build/salty-studio-browser-20261001/VERDICT.txt` and
  `FINAL-BROWSER-IDENTITIES.json`, plus retained
  `build/salty-studio-native-20261001/` results on stable FPC 3.2.2 Win32/Win64
  and matched pas2js 3.3.1. The global verdict's sole pending cancellation-display
  case belongs to studio_02. Native submitted failures: 0; browser submitted
  failures: 0 for this batch. QA runner/oracle corrections remain privately
  preserved and are not production failures; historical counters are unchanged.
  Prior pending notes are historical. Recorded source/staged
  identities remain authoritative; no new published revision is claimed.
  Award only the existing task allocation; no musical/inference acceptance.
