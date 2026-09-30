# NS-5_continuity_02 — Stream saved acoustic WFC beyond one solve

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-5)

**Description:**

Completion credit: 2 goal percentage points (0.40 overall points).
Current basis: [2026-09-29 outcome rebase](../../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Deliver a reusable, bounded Pascal continuation path for a saved, source-bound
acoustic WFC profile. The previous short journal replay stops at 1,024 grains and
materializes one whole render. A continuous multi-minute passage needs one
latent-state sequence, one source-selection history and one overlap-add audio
timeline across internal chunks. This is an engineering prerequisite for the
full musical [continuity verdict](../NS-5_continuity_01.md), not that verdict.

North star: NS-5. Outcome owner: WAV-04-CONTINUITY.
Historical allocation: 1 goal percentage point (0.20 overall points), reallocated
from the original 5 unearned points of NS-5_continuity_01. That task retains 4
points and all sustained quality, multi-source/seed and listening acceptance.
The pair retains the original 5 NS-5 points / 1.00 overall point; this split
creates no credit.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [saved acoustic journal](../../WAV-STUDIES.md) ·
[learning architecture](../../LAYERED-STYLE.md) ·
[`TLearnedSequenceStream`](../../../adapters/wfc/pythian.wfc.stream.pas) ·
[`TJournalCandidatePool`](../../../src/pythian.learning.selection.pas).

**Accepted 2026-09-28:** Maintained Pascal selection and Hann render streams
extend `pythian.learn replay-long` across actual WFC continuation chunks, while
reloading the saved acoustic profile and verifying every source WAV before and
after generation. The frozen three-recording development run produces 4,000
grains / 4,099,072 stereo PCM16 frames at 16 kHz (256.192 seconds) in 16
chunks. It records every selected original source frame and all 15 cross-chunk
joins. All three distinct source hashes are used (1,482/1,368/1,150 grains);
the WAV SHA-256 is
`9f55f8bcceb05255c8fa95bf2028705661728c9e13f311894e684c849e92d442`.
Checked stable FPC 3.2.2 Win32/Win64 and alternate output block sizes reproduce
exact selection and PCM bytes; focused state/rollback, frame/map, headroom and
failure tests pass. Independent Salty Boi QA rebuilt the CLI and verifier,
replayed the exact saved profile and confirmed the legacy short replay hash and
source identity. Focused component and verifier runs reported zero leaks;
rejections leave no accepted output pair.
The normal Win64 run took 41,833 ms with sampled 12,509,184-byte peak private
commit and 16,166,912-byte peak working set. The audition report is not a
reloadable learned profile. [Study and limitations](../../WAV-STUDIES.md#bounded-acoustic-continuation-checkpoint)
retain the exact inputs, source-switch measurement, last-bit floating report
nuance and ignored QA evidence. Sustained musical quality and listening remain
with [NS-5_continuity_01](../NS-5_continuity_01.md).

**Acceptance Criteria:**

- Expose a maintained Pascal path that reloads a saved acoustic profile,
  verifies every exact source WAV binding, and produces one continuous
  180–300-second WFC-selected PCM16 WAV from at least two distinct declared
  source recordings. Do not concatenate independent solves or independently
  rendered clips. Retain source/model/policy identities and the exact original
  source frames selected for every grain.
- Continue actual WFC latent state, weighted candidate-selection credits and
  bin rotation across internal chunks. Freeze a deterministic chunk/seed
  schedule and reject unsatisfiable continuation without publishing a partial
  success. Preserve segment/song boundaries and reject unavailable source
  windows or incompatible sample clocks.
- Stream normalized Hann overlap-add and PCM output with bounded memory/work,
  continuous frame count and no introduced chunk-boundary gap/click. Validate
  source headroom and output clipping; record cross-chunk joins, source use and
  repeated-window counts as measurements, not claims of musical quality.
- Save enough source/model/seed/chunk/selection evidence to replay from a
  reloaded profile. Checked Win32/Win64 native builds and two different output
  block sizes must reproduce exact selection and PCM bytes for the same fixed
  policy. Source mutation, invalid geometry, solver failure and interrupted
  publication must leave no accepted WAV/report pair.
- Publish the bounded API/consumer and concise resource measurements. Retain
  the existing short replay contract and its limits. Do not claim semantic
  provider admission, acceptable long-form continuity, genre fit or listener
  approval from this backend result.

**Blockers**

- [NS-5_corpus_01.md — DONE](NS-5_corpus_01.md)
- [NS-5_scale_03.md — DONE](NS-5_scale_03.md)

**Dev Notes:**

- 2026-09-28 task-flow reassessment: the existing journal replay verifies and
  reloads saved profiles but caps generation at 1,024 grains and renders one
  whole clip. Its selector resets credits/bin cursors per call; the renderer
  resets Hann overlap at every clip boundary. A stream must preserve all three
  states. NS-5_continuity_01 remains responsible for full multi-recording,
  multi-seed joins, repetition, diversity, sustained listening and repairs.

- 2026-09-28 the first eight-grain smoke stopped before generation because an
  A derivative did not match the saved profile's source hash. The exact
  `A-early.wav` binding was then used; no source identity was relaxed. An
  initial source-use count also conflated used profile rows with distinct WAVs.
  The corrected gate counts unique used source hashes and rejects a 180-second
  fixture using two ranges of one WAV while a second supplied WAV is unused.
  Independent QA accepted the repaired path. A separate saved model showed a
  last-bit raw floating `render_peak` report difference across native targets
  with identical PCM; the accepted exact PCM/selection contract is unaffected.
