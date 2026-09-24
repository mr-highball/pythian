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
substep, not the task. A later maintained full-event WFC path and a private
30-second score-timed pitch render now pass engineering QA below; the listener
checkpoint remains open. No task credit is earned yet.

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
- 2026-09-24 source-bound feasibility inventory: the exposed first 30 seconds
  of Spring contain 187 joint onset bundles and 187 distinct exact event tokens.
  Their order-1 and order-2 exact-token contexts have no branching, so learning
  those full tokens would only reproduce source fragments. A separate, frozen
  private diagnostic tests WFC over part-and-pitch tokens while holding the
  score event slots fixed. This can establish new pitch choices and exact
  event preservation, but cannot establish new rhythm or composition from WAV.
  No solve, render or listening verdict exists from the inventory alone; see
  ignored `build/note-event-adapter/generation-analysis.log` and
  `GENERATION-PLAN.md`.
- 2026-09-24 one frozen part-constrained pitch WFC candidate passed its
  engineering gates: 187 retained score-timed slots, 78/96 flute and 65/91
  violin pitches changed, 135 cross-part overlaps, deterministic token replay,
  a 30-second stereo PCM16 WAV and zero heap leaks on checked Win64. The
  original result omitted the ordered generated token vector/event digests
  required by its plan, so Salty Boi withheld QA acceptance. One separately
  frozen **audit-only** same-seed reproduction matched the original token
  SHA-256 `270c29dd555bf8de450e1cf7a765d4c23d517fb42cd09b752270cac7099e0bfd`,
  persisted source/generated event ledgers, and left the original WAV unchanged.
  Salty Boi independently checked the ledgers, all non-pitch fields,
  PPQ/tempo/extent, token hashes and no-render replay path; engineering QA now
  passes. The generated WAV SHA-256 is
  `f6c3fc7ad9fc24822e4dc75f038fe74247e60f4e968f3ed88083eb2d6f89c4ee`.
  It uses published-score timing and authored synth controls; only part-specific
  pitches were WFC-selected. The listener heard an improvement over the earlier
  stumbling preview but reported popping during playback and notes that seemed
  to overlap. This is not a passing musical verdict, so no task credit is
  earned. A hash-bound read-only Pascal diagnostic found that both this WAV
  and the exact-score control have their ten largest adjacent-sample jumps
  exactly at overlapping note ends, while neither reaches PCM full scale.
  Salty Boi independently verified the measurement; this suggests a shared
  post-mix envelope issue but does not prove the heard pops' cause. One
  privately frozen 5-ms per-voice release trial followed. Private evidence
  remains under ignored `build/note-event-adapter/`.
- 2026-09-24 the single 5-ms release trial passed its fixed engineering gates
  without changing WFC pitches or event timing. The source-free overlap
  control showed per-voice decay and an unchanged continuing part; checked
  Win32/Win64 30-second PCM hashes matched with zero leaks. Mean maximum
  sample jump near 135 overlapping note ends fell 78.319% in the generated
  clip and 80.248% in the exact-score control, with no new top-ten jump at an
  overlapping end. Salty Boi independently passed QA. A pre-render hash
  transcription error and an interrupted slow diagnostic scan were repaired
  without changing the release policy or fixed gates. The new generated WAV
  SHA-256 is `82e2e1ad275fbb4517c37fa0b44dc8ff9b6926ae80b4aa29b506f87bd5a62c0a`;
  it is served as numbered mobile clip 2 for a whole-clip verdict on pops and
  musical overlap. No listener verdict or task credit is claimed yet.
- 2026-09-24 maintained `pythian.wfc.note.events.generation` now learns a
  bounded open-boundary corpus of exact joint event tokens, keeping each source
  separate and requiring identical part IDs, PPQ and tempo changes. It carries
  that source clock into generation, excludes zero-delta tokens after the first
  bundle, decodes all generated events through the exact codec, and preserves
  caller output on solve/decode failure. One source-free two-part order-2,
  seed-731 fixture generated a new six-bundle/seven-gate branch combination
  with simultaneous starts, retrigger, rest and unequal durations; same-seed
  replay matched, an incompatible tempo map was rejected, and an undersized
  output extent preserved the prior owned result. Salty Boi independently
  rebuilt and passed checked FPC 3.2.2 Win32/Win64 with zero leaks. The focused
  test is in the non-CoreOnly WFC build. The first two fixture designs were
  stopped because output length did not prove sample isolation; their outcomes
  and the repaired ownership leak are retained under ignored
  `build/note-event-adapter/maintained-generation-notes.txt`. This closes a
  maintained engineering substep, not listening or recorded-WAV acceptance;
  no task credit yet.
- 2026-09-24 one frozen source-free 32-second **full-event** candidate trained
  the maintained adapter on three authored two-part C/Am/F/G controls. It
  passed checked Win32/Win64 engineering QA: 64 decoded bundles, 15 complete
  bars different from each source, all three source variants used, exact
  token/WAV cross-target replay, 59/37 melody/bass gates, overlap and zero
  leaks. A focused PCM scan found its largest adjacent-frame change at the
  opening attack, not a listening verdict. The first index-relative musical
  audit found 30/59 melody and 20/37 bass notes outside the chord authored at
  that position; this alone could reflect coherent chord reordering. An
  audit-only exact-hash replay then compared each four-token bar against every
  source bar: 6/16 matched one exactly. Four of the ten unmatched bars retain
  their own beat-0 bass root and melody triad, while six mix melody and/or bass
  pitch classes outside that bar's inferred source triad. Salty Boi independently
  reproduced these counts on checked Win64 with zero leaks. The candidate
  passes structural rendering but fails this authored one-chord-per-bar control,
  so it remains private under ignored `build/joint-event-control/` with no
  listener verdict, recorded-learning claim or credit. Stop the unconditioned
  route. Wait for the separate Spring clip-2 listener verdict before another
  musical generation batch; if it fails, declare a context-aware hypothesis
  and fixed gates rather than retuning this scored candidate.
