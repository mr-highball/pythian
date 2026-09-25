# NS-4_note-events_01 — Generate coordinated note events across parts

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-4)

**Description:**

Deliver a reusable Pascal WFC adapter for note events in multiple parts. Its
joint representation must preserve onset ownership, same-pitch retriggers,
simultaneous starts, individual note durations and inter-onset gaps. A
score-conditioned development source may demonstrate the adapter, but this
task does not claim WAV note extraction, a genre style or original composition
from recorded audio. The recorded workflow remains with
[NS-4_integration_01](../NS-4_integration_01.md). The original substantial
full-event render, its deterministic artifact evidence and listener verdict
are transferred in full to [NS-4_composition_01](NS-4_composition_01.md),
which also requires a positive coherence verdict. This task owns the bounded
exact event adapter and generation contract.

North star: NS-4. Outcome owner: WAV-04-INTEGRATION.
Completion credit: 1 NS-4 goal percentage point (0.15 overall points),
reallocated from the original unearned 4-point NS-4_integration_01. The
separate [composition checkpoint](NS-4_composition_01.md) owns the other
1 point from this task's former 2-point allocation; recorded integration
retains 2 points. These three allocations retain the same original 4 NS-4
points / 0.60 overall points; only this accepted 1 point has been earned.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [exact-score two-part control](../../WORK.md#substantial-generated-development-preview--2026-09-23),
[layer contracts](../../INDEPENDENT-VOICES.md),
[native note sequence](../../../src/pythian.music.pas),
[existing acoustic-event adapter](../../../adapters/wfc/pythian.wfc.events.pas).
The first private 1,024-cell pitch-set WFC diagnostic stopped at a 40,424-frame
  training-grid displacement before its solve. Its ignored
  `build/score-wfc-two-part/PLAN.md` and `RESULT.md` retain the fixed attempt.
  Salty Boi confirmed that consecutive Spring flute MIDI-79 rows at 4.110 s
  merge into one active-set gate, causing the exact 40,424-frame onset error.
Acoustic event symbols currently carry palette index, duration class and onset
flag, but no part identity or inter-onset delta; acoustic indices must not be
reinterpreted as MIDI pitches.

Completion evidence 2026-09-24: maintained
`adapters/wfc/pythian.wfc.note.events.pas` now encodes/decodes exact one-tick
joint onset bundles and sidecar clock/extent metadata. The focused Pascal
consumer covers two-part overlap, same-pitch retriggers, gaps, empty phrases,
all note fields, canonical token replay and failure preservation. Salty Boi's
independent checked FPC 3.2.2 Win32/Win64 QA passed with zero leaks, and the
test is wired into the WFC build path. The companion maintained
`pythian.wfc.note.events.generation` learns separated source sequences,
retains exact clock and part metadata, generates and decodes full joint event
paths transactionally, and rejects incompatible tempo or output extent.
Its frozen two-source order-2/seed-731 fixture produced six bundles and seven
gates with both parts active, one cross-part overlap, retrigger, rest and
unequal durations. The ordered `(onset,pitch,duration)` comparison differs
from source 0 by one tuple in each part and from source 1 by one bass tuple;
source 1's melody projection is an exact replay. Both complete source paths
therefore differ from the output, without claiming every part is new against
every source. The comparison also records canonical per-part SHA-256 hashes.
Focused checked FPC 3.2.2 Win32/Win64 compile/run output matched with zero
unfreed blocks; the Win32/Win64 run-log hashes are
`878f313e760048e7b450de30285c5e0920b70ee251d2f576f9d718eff4f0da06`
and `a4680442635d070faf3edef666d73d7dd36b055ab9fb89078d989fb784a41cb6`.
The focused command compiled `tests/pythian.tests.note.events.generation.lpr`
with checked `-B -gh -Sa -Cr -Co -Ci -gl` and the core/WFC source paths using
the verified Win32 `fpc.exe` and Win64 `ppcrossx64.exe`, then ran each target
executable. The consumer SHA-256 is
`3a5e81d65230267820b67ddc155d3afb60dd6532666dca11d824eae1b3cdfa44`.
Salty Boi independently passed this per-part comparison and the source
bindings. Exact per-part generated hashes are
`8119c16b2188e7f544e3faa713a8e67e289e7a4c4b5690299dee2400d5aa12bb`
and `ad8fec2773ea4fd64c6f64b7a3d6bbc187c5ff2916eb8e7346508c9fb0953d0f`.
The accepted result is an adapter and bounded source-free generation control,
not a substantial rendered passage, a coherent original composition or
recorded-WAV note learning.

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
**Blockers**

- [NS-4_layers_04.md](NS-4_layers_04.md)

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
- 2026-09-24 read-only adapter review: maintained
  `LearnJointNoteEventWfcModel` trains an open sequence over individual onset
  bundle tokens. `BuildPositionConstraints` only excludes a zero onset delta
  after the first position; the generation API carries no bar, chord or key
  context. The six internally mixed bars in the private authored control are
  therefore compatible with this contract, not evidence that the exact event
  codec changed notes. A future full-event coherence attempt needs an explicit
  source-bound context or grouping contract and prospective musical gates;
  changing sequence order alone would not enforce a one-chord-per-bar rule.
  This review changed no model, candidate or listening status.
- 2026-09-24 listener update: in a numbered review of the served feedback,
  the user reports no more popping and a more music-like result, but does not
  consider it a coherent song. They also hear better harmonization with some
  conflicting notes and beats. The precise mapping of their items 1 and 2 to
  the two served filenames is being confirmed; do not attribute a new harmony
  algorithm to the 5-ms release edit, which changed no pitch or event timing.
  Treat the pop concern as improved and the musical-coherence gate as open.
  No task credit or new candidate follows from this verdict alone.
- 2026-09-24 task-flow reassessment: the score-timed pitch candidate's listener
  checkpoint and the separate unconditioned full-event authored control are
  two nonclosing musical batches. The first improved after a release repair but
  still has reported note/beat conflicts; the second failed its independent
  within-bar harmony gate before listening. Stop both generation routes.
  The changed path is an explicit chord-context contract over exact event
  bundles. One frozen, source-free bar-local branching preflight under ignored
  `build/joint-event-context/` decides whether the existing authored corpus can
  support novel same-chord bars before changing a maintained API or rendering.
  A failed preflight stops that representation without order/source/gate retries.
- 2026-09-24 the frozen bar-local preflight passed its **minimal viability**
  gate, not a generated-song gate. Ticket Guy's checked Pascal Win32/Win64
  runs reproduced all three source token hashes, exactly replayed 48 local
  bars, and reported zero leaks. The order-2 open model had distinct/authored/
  novel complete paths C 3/3/0, Am 4/3/1, F 6/3/3, G 3/3/0. Both parts and
  overlap survive in the four novel paths, so two contexts meet the frozen
  gate. The available novelty is too narrow for the intended 16-bar passage:
  C and G can only replay authored bars; F's three new paths change bass but
  retain the authored melody; every source uses the same beat-onset grid.
  Chord-tone filtering also permits inversions without proving the chord root
  is sounded. Keep the preflight's PASS truthful, but stop this local exact-bar
  representation before a maintained API change or listening candidate.
  Next pursue separate harmony/rhythm/part choices with exact note-event
  ownership and a prospective substantial-novelty gate. No credit changes.
- 2026-09-24 independent QA narrowed that preflight's novelty claim further.
  Its frozen comparison was against authored bars **with the same chord
  context**. The sole Am-context novel path exactly repeats an authored C bar;
  one of the three F-context novel paths exactly repeats an authored Am bar.
  Against the union of all authored complete bars, only two F-context paths
  remain new, and both repeat the authored F melody while changing one bass
  note. The written same-context gate still passes, but it cannot support a
  claim of globally novel bars in two contexts or of new two-part melody.
  Keep the local-bar representation stopped with no listening or credit.
- 2026-09-24 one separately frozen source-free modular named-voice candidate
  under ignored `build/joint-voice-graph/` tried independent harmony, rhythm
  and part passes over 128 cells, with the exact two-part event codec as its
  output contract. Checked Win32/Win64 model and graph construction passed
  with zero leaks. The single fixed seed-1731 Win32 solve returned false before
  note-event gates or WAV rendering. Its first diagnostic printed invalid
  status/pass integers because a Pascal `Require` call formatted an output
  report in the same argument list as `TryGenerate`; argument evaluation order
  is unspecified. One frozen, audit-only same-seed replay separated those
  statements without changing model, seed or budget. It captured a pass-2
  adjacency contradiction and the configured 32 per-pass backtrack limit;
  it does not prove the graph unsatisfiable. No generated tokens, listening
  clip or task credit resulted. Stop this 128-cell modular candidate under
  its fixed budget rather than retuning it in place.
- 2026-09-24 the task-flow split transferred the original substantial
  full-event render/listener criterion in full to
  [NS-4_composition_01](NS-4_composition_01.md). This adapter task retains
  its three source-free codec, exact replay and bounded joint-generation
  criteria. The prior 30-second score-timed pitch clip and stopped private
  full-event candidates remain useful failure evidence, not acceptance of
  the distinct composition task.
