# NS-4_note-events_01 — Generate coordinated note events across parts

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Deliver a reusable Pascal WFC adapter for note events in multiple parts. Its
joint representation must preserve onset ownership, same-pitch retriggers,
simultaneous starts, individual note durations and inter-onset gaps. A
score-conditioned development source may demonstrate the adapter, but this
task does not claim WAV note extraction, a genre style or original composition
from recorded audio. The recorded workflow remains with
[NS-4_integration_01](NS-4_integration_01.md).

North star: NS-4. Outcome owner: WAV-04-INTEGRATION.
Completion credit: 2 NS-4 goal percentage points (0.30 overall points),
reallocated from the original unearned 4-point NS-4_integration_01. The two
open tasks retain the same 4 NS-4 points / 0.60 overall points.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [exact-score two-part control](../WORK.md#substantial-generated-development-preview--2026-09-23),
[layer contracts](../INDEPENDENT-VOICES.md),
[native note sequence](../../src/pythian.music.pas),
[existing acoustic-event adapter](../../adapters/wfc/pythian.wfc.events.pas).
The first private 1,024-cell pitch-set WFC diagnostic stopped at a 40,424-frame
  training-grid displacement before its solve. Its ignored
  `build/score-wfc-two-part/PLAN.md` and `RESULT.md` retain the fixed attempt.
  Salty Boi confirmed that consecutive Spring flute MIDI-79 rows at 4.110 s
  merge into one active-set gate, causing the exact 40,424-frame onset error.
Acoustic event symbols currently carry palette index, duration class and onset
flag, but no part identity or inter-onset delta; acoustic indices must not be
reinterpreted as MIDI pitches.

Phase-one progress 2026-09-24: maintained
`adapters/wfc/pythian.wfc.note.events.pas` now encodes/decodes exact one-tick
joint onset bundles and sidecar clock/extent metadata. The focused Pascal
consumer covers two-part overlap, same-pitch retriggers, gaps, empty phrases,
all note fields, canonical token replay and failure preservation. Salty Boi's
independent checked FPC 3.2.2 Win32/Win64 QA passed with zero leaks, and the
test is wired into the WFC build path. This closes the source-free codec
substep, not the task: actual bounded WFC generation, a substantial two-part
render and listening checkpoint remain open. No task credit is earned yet.

**Acceptance Criteria:**

- Expose a maintained Pascal adapter under `adapters/wfc/` that accepts a
  bounded `TNoteSequence` with explicit two-part identities, tempo/PPQ and a
  declared event-time quantum. Canonicalize source gates by start, part,
  pitch and end. Encode joint onset bundles with part/pitch/duration plus
  explicit inter-bundle onset delta; preserve repeated same-pitch attacks as
  distinct gates and silence as a real time gap. Keep the portable root core
  independent of WFC.
- Round-trip exact source-free controls for simultaneous onset, unequal part
  durations, same-pitch retrigger, overlap and rest. Reject or expose any
  event quantization loss before WFC learning. Bound event count, simultaneous
  width, vocabulary, durations, deltas, model work and output extent; preserve
  deterministic failure and original source coordinates. Do not silently
  replace unknown recorded notes with authored event labels.
- Run actual joint WFC generation with fixed seed, order, budget and stop
  condition frozen before scoring a development example. Validate decoded
  `TNoteSequence` gates and both part identities, and distinguish an exact
  replay from new note choices by comparing ordered pitch/onset events in
  each part. Require nontrivial activity and simultaneous overlap so silence
  cannot satisfy novelty. One fixed candidate may use the already exposed
  first 30 seconds of Spring publisher Notes; protect untouched source groups.
- Render a substantial two-part native WAV through the accepted voice path
  when the fixed structural gates pass. Record source/model/token/WAV hashes,
  exact learned-versus-authored contributions, deterministic checked-target
  replay, focused failure preservation and Salty Boi QA. Obtain a listener
  verdict on pitch/timing coherence and preserve any failure honestly; this
  task establishes the adapter and bounded generated checkpoint, not the
  broader recorded-WAV or genre-quality acceptance.

**Blockers**

- [NS-4_layers_04.md](DONE/NS-4_layers_04.md)

**Dev Notes:**

- 2026-09-24 frozen dense pitch-set pilot: a one-shot private 1,024-cell
  score-conditioned joint WFC plan compiled but stopped before modeling or
  rendering because its decoded training grid displaced a score gate by
  40,424 frames against a fixed 15-ms limit. The sampled active-set encoding
  cannot represent retrigger ownership reliably; the confirmed row-7/8
  same-pitch transition is erased even before WFC learning. Do not change
  its grid, threshold, seed or order to make that attempt pass. The event-aware
  adapter is a different contract with onset/duration/delta ownership, not a renamed
  dense-grid experiment. See `build/score-wfc-two-part/RESULT.md` in ignored
  build artifacts.
