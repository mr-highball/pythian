# NS-6_json-identity_01 — Preserve Unicode musical choices across native JSON boundaries

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 3/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Saving the experimental musical-choice fixture with a Unicode note succeeds,
but its next save cannot reopen the immutable revision: the primary UTF-8 parser
rejects bytes after host string conversion. Repair the shared native JSON byte
boundaries exercised by project choices, job receipts and their HTTP transport.
Use the existing primary JSON/scalar/hash implementations. This is a concrete
prerequisite of [experimental learning AC2–4](../NS-3_experimental-learning_01.md),
not an invitation to audit unrelated long-running code or add a second codec.

Primary attribution: NS-6. Three effort units estimate the implementation and
consumer repair. Creating the task and diagnosing the defect earn no completion.

**Accepted outcome — 2026-10-30, Big Boss SOLO.** Native JSON byte boundaries
preserve actual UTF-8 through project revisions, job records, catalog/library
metadata and HTTP responses. The existing primary scalar parser and SHA-256
remain authoritative. Shared HashNativeText in pythian.tools.json replaces
duplicate native stream-hash implementations; StudioTextHash forwards to it.
Metadata remains UTF8String, while byte I/O and hashing use RawByteString.
No model preparation, inference or job launch was added to Save.

Stable FPC 3.2.2 Win32/Win64 pass 51 focused musical-choice/storage checks with
actual sharp-sign and CJK input, real stereo capture analysis, original receipts,
explicit accepted/corrected/manual/bypassed decisions, immutable retries, rejected
corrections, Unicode names/classifications and unchanged analysis/job records.
The actual fixed-slot loopback service passes 16 native HTTP checks for shell,
session acquisition, Unicode Save/reload/retry, source receipt and unchanged job
count. It is limited to eight requests and exits; no QA listener/worker/browser
or playback remains. Native project 106, job 113, discovery 68 and capture 80
regressions pass. Passing native heaps are clean.

Evidence, failed fixtures, source clocks, checked binary hashes and bounded
launcher are under musical-choices-20261030-boss in the dedicated E-drive roots.
This accepts the three-unit data repair, not the unfinished Studio editor,
proposal-driven generation or parent task's eight units. Operator data and the
stable deployment remain unchanged.

**Acceptance Criteria:**

- AC1: Operator musical choices, Unicode names/notes/classifications and source
  receipts retain their actual UTF-8 bytes across save, reload and immutable
  revision retry. Invalid input and failed writes preserve accepted state.
- AC2: Shared JSON hashing and job storage use the same original bytes rather
  than host text conversion. Actual source and operator lineage remain distinct;
  saving choices neither queues work nor learns a model.
- AC3: A native HTTP consumer receives and returns those choices without text
  corruption, with relevant project/job regressions passing. Preserve the failed
  fixture, use isolated output/service slots and leave operator data intact.

**Blockers**

- [Instrumental Studio — DONE](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Reproduction and native stack are preserved under
  musical-choices-20261030-boss in the dedicated E-drive build/tests/runs roots.
  The first fixture comparison mixed native fpjson UTF8String and host String;
  using TJSONStringType repairs that test boundary. The corrected fixture then
  demonstrates an actual saved revision failing the next read at check 15:
  ParseStudioProjectWrite → ReadObject → ReadProjectLocked → SaveStudioProject.
  A missing fixture catalog was separately repaired; native heaps remain clean.
- No source recording, operator project or deployed service was changed by this
  reproduction. Return to the existing Studio acceptance/editor batch after this
  prerequisite; its eight effort units remain open.
- The expanded source path reproduced the same bug in catalog publication.
  Catalog metadata and capture manifests now retain UTF8String values; project,
  job, library/discovery publication and HTTP output preserve original bytes.
  Existing ASCII consumers remain valid. No old corrupt document is rewritten.
- Fixture repairs are retained: missing fixture catalog, unsupported selection
  spelling (the existing contract is full/range), and explicit UTF-8 source-page
  declaration. Final checks assert the actual sharp-sign bytes, not just equal
  round trips of misdecoded constants.
- The unchanged 4096-record library-capacity tail was stopped after 391 synthetic
  records because Windows metadata I/O dominated this focused repair. The whole
  library fixture is not claimed passed. Actual Unicode source import/index
  identity and relevant project/job/discovery/capture consumers close this scope;
  its prior failure/cancellation checks and stop ledger remain preserved.
- Initial HTTP setup failures remain recorded: open-LAN mode correctly rejects
  loopback, and the first bounded fixture lacked a prepared inbox manifest.
  Reuse the Pascal-generated, hash-verified authored inbox and ordinary loopback
  session. Automatic approval review rejected one combined unbounded launch/test
  without a specific reason. The safer eight-request loopback batch was approved,
  passed, and closed its exact processes automatically.
- Real AC1–3 closure resets consecutive nonclosing batches to zero. Return to
  experimental-learning AC2–4; no additional operator review is needed for this
  internal storage repair.
- Final native checks also reject malformed UTF-8 from direct native callers.
  Shared job publication and project identity use the existing primary JSON
  writer, preserving valid-byte output while validating scalars before commit.
  The current parent-only recipe is stored truthfully: preflight rejects it
  until the instrumental runtime applies it, rather than silently ignoring it.
  Actual native HTTP was repeated against the final matched binaries and passed.
