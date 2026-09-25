# NS-4_composition_01 — Generate a coherent original passage

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-4)

**Description:**

Generate a substantial, source-free two-part native passage whose harmony,
melody and rhythm work together as music. This is a core composition checkpoint,
independent of the user's three personal style tests and of recorded-WAV note
learning. It is distinct from the bounded note-event adapter demonstration in
[NS-4_note-events_01](NS-4_note-events_01.md): the adapter proves exact
joint-event ownership and generation, while this task requires a substantial
musically accepted render.
This task owns the original note-event task's substantial full-event render,
deterministic audio evidence and listening criterion in full; the adapter task
retains its codec, replay and bounded joint-generation criteria.

North star: NS-4. Outcome owner: WAV-04-INTEGRATION, core composition prerequisite.
Completion credit: 1 NS-4 goal percentage point (0.15 overall points),
reallocated from the original unearned 2-point note-event allocation. Together
with the now accepted note-event task's 1 point and recorded integration's
2 points, the three allocations preserve the original 4 goal points / 0.60
overall points. Recorded integration retains 2 open NS-4 points.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [note-event adapter](NS-4_note-events_01.md),
[named voice contracts](../../INDEPENDENT-VOICES.md),
[work record](../../WORK.md). The score-timed pitch clip was judged more musical
and free of audible pops after its release repair, but still not a coherent
song. The private unconditioned full-event clip failed its authored harmony
gate. The local bar representation produced only two globally novel F-context
bars that retained the authored melody; a separate 128-cell modular candidate
stopped at its fixed per-pass backtrack limit before rendering. None is an
accepted composition result.

**Completion evidence — 2026-09-24:** The maintained portable
[`pythian.music.compose`](../../../src/pythian.music.compose.pas) unit and
[`pythian.compose`](../../../tools/pythian.compose.lpr) consumer generate exact
owned 16-bar, 35.556-second two-part sequences and native stereo WAVs. The
frozen policy SHA-256 is
`1a6be0048cc9d4bb37ce9fb93ef56000b92e372bd78ec7743286ec421b0893d7`;
the accepted unit/CLI SHA-256s are
`c0c7cc134f16c892621df5d3ac97dae29c07deff110d6fa1db466ed51ead7b36`
and `a4289cfc78e6fa8bae00ddaf433a9586db35054f3308395bf90439ae0a6b6abb`.
No authored note/bar/phrase input exists: the source-phrase union is empty,
comparisons and copied-run results are N/A, and model/token hashes are N/A
because this is not a WFC solve. The report separates seeded choices from
authored form, chord and cadence rules.

Salty Boi compiled with checked FPC 3.2.2 `-B -Sa -Cr -Co -Ci -gh -gl` on
Win32/Win64, ran seeds 1731 and 2731 and fresh sibling replays, and verified
all 97/88 note gates in order against the frozen sequences. Event-ledger hashes
are `8e9d560b302fe7b4edff44400c6ff46ed020136340509fe1f2dd72bc4267baed`
and `33b39cd854446a18cbc019dd950362e58403233ad5e45af2201684a7ae3b479d`;
WAV hashes are `9d42725e7ad45e54a6377e380871bbd58efd90f4ef302d0bcefec027604fecc9`
and `2d69b38ae1653193cfa3d451db6812b0466c220278aac33a8afd8c2075f128b5`.
The WAVs match the exact clips reviewed by the user. Both targets and replays
returned zero leaks and identical event/WAV/report bytes; full-scale sample
count was zero. Every note end passed the focused 44-frame check, with maximum
adjacent jumps 0.001318542/0.001524473 below the declared 0.005 limit.
The 0.005 limit was added during focused QA, after the original freeze; no seed
or musical gate was retuned. Forced report-write failure preserved existing
output bytes and returned exit code 1 with zero leaks on both targets. The
consumer's build-hook invocation was exercised on both targets; the unrelated
full build suite was not rerun. Ignored details are in
`build/composition-maintained/QA-MANIFEST.md`. The user heard clip 3 as
coherent without stumbling, preferred clip 4, and judged clip 4 newly composed
rather than recognizable preauthored music. This accepts core source-free
composition only; recorded learning, WFC-composed passages and style fidelity
remain separate work.

**Acceptance Criteria:**

- Declare a source-bound harmony, meter, phrase and two-part event plan before
  generation. Its maintained Pascal implementation must produce an original
  passage of at least 30 seconds with changed onset, pitch and duration choices
  in both parts, audible rests and overlaps, and a recognizably organized
  beginning, development and ending. Do not replay a published score or stitch
  complete authored bars together and call the result original.
- Freeze the source identities, seed, model, budget, novelty comparison and
  musical gates before scoring. Compare complete generated phrases against the
  **union** of authored source phrases, across chord labels, and report copied
  runs as well as independently changed melody and bass material. For a truly
  source-free generator, audit its maintained implementation for the absence of
  authored note, bar and phrase inputs; report an empty source-phrase union and
  mark phrase comparison and copied-run results **not applicable**, not observed
  zero copies. Report its authored rules and independently seeded choices in
  both parts. Constrain notes to their declared harmonic context while
  preserving intentional
  non-chord tones with an explicit rule; validate attack/rest timing and
  section joins. A structure label alone does not pass these checks.
- Render with the accepted native two-part synthesis path and an exact owned
  note sequence **when the frozen structural gates pass**. Record exact
  source/model/token/event/WAV hashes and the learned-versus-authored
  contributions. Require deterministic checked Win32/Win64 replay, bounded
  resources, no invalid audio, no clipping or note-end pops in focused checks,
  focused failure preservation, and independent Salty Boi QA of the changed
  boundaries. Preserve failed candidates and stop conditions honestly without
  presenting them as passes.
- Obtain a whole-passage listener verdict on melodic, harmonic and rhythmic
  coherence from the user. Pass only when the user judges the generated passage
  coherent enough to count as music and can distinguish it from a replay of an
  authored piece. Keep style fidelity and recorded-source learning with their
  existing tasks; this checkpoint concerns core source-free generation.

**Blockers**

- [NS-4_note-events_01.md — DONE](NS-4_note-events_01.md)

**Dev Notes:**

- 2026-09-24 this task was created at the task-flow checkpoint after the
  stopped bar-local and modular source-free attempts. It gives the user's
  explicit coherence concern a positive acceptance gate without silently
  adding that gate to the narrower note-event adapter task. The recorded
  harmony/groove tasks and later style-structure task remain separate because
  they require evidence from recordings or sustained genre organization.
- 2026-09-24 one context-tagged continuous-stream source preflight under
  ignored `build/composition-segmented/` authored eight first-party four-bar
  controls, two for each A/A-prime/B/cadence role, at a 240-tick half-beat
  grid. Checked Win32/Win64 Pascal runs reproduced identical source, schedule,
  event and token ledgers with zero leaks. Each planned two-bar span has two
  raw authored choices in rhythm, bass and melody, but **actual WFC path
  reachability was not tested**. The 16-bar schedule introduces three
  unrepresented role-bound phrase joins: A G to A-prime C, A-prime G to B F,
  and B Am to cadence Am. G-to-F has no authored chord transition anywhere;
  G-to-C appears within B and Am persistence appears within bars, neither
  proving the required role-bound joins. One A-prime control also exactly
  duplicates an A control's 32-cell token path. Salty Boi independently
  confirmed these limits. Stop this continuous-frontier source set before
  model learning, solving or rendering; no candidate, listening or credit.
  A future phrase-boundary policy would need its own frozen source/novelty
  contract rather than filling this frozen set ad hoc.
- 2026-09-24 a separate read-only phrase-reset audit found that every one of
  the 12 outgoing/incoming authored control pairings at the three planned
  joins preserves half-open note gates: final notes end by the boundary and
  no boundary cell is a hold. Checked Win32/Win64 reports matched with zero
  leaks, and all seven frozen input hashes are verified after an audit-only
  binding repair. This establishes gate feasibility, not a learned transition
  or musical join. The same controls fail their declared role ranges at
  A-prime_v1 pitch 65 and B_v0/v1 pitches 65/67; the complete A_v1/A-prime_v0
  token-path duplicate also remains. No model, candidate or audio was run.
  Stop this source set. The task-flow checkpoint after two nonclosing source
  batches changes the next action to **one** independently qualified source
  set for explicit four-bar phrase resets, with frozen union-novelty and
  musical-join gates under ignored
  `build/composition-phrase-reset/QUALIFIED-SOURCE-PLAN.md`. If its source
  qualification or one candidate fails, stop authored phrase-WFC rather than
  revising sources or budgets in place. No task credit yet.
- 2026-09-24 the one new first-party phrase-reset source set initially reported
  qualification after
  repairing a checker that had counted every bar ending instead of only each
  phrase-final cell. The source-construction procedure and constants were
  unchanged; the first failed run wrote no source ledger, so direct byte
  identity to its in-memory controls is not claimed. Checked Win32/Win64
  Pascal ledgers match with zero leaks on the corrected run. All 16 complete
  H/R/bass/melody token paths are distinct; each role has four rhythm outlines
  and four melody contours. Ranges, at-most-12-semitone melody leaps (max 11),
  bass root/fifth, strong-beat chord tones, no crossing gate, final two-voice
  rest and C cadence passed the checks then implemented. Salty Boi verified the
  repair diff, but later model preparation exposed a missing source invariant:
  `cadence_v0` cells 27-28 and `cadence_v3` cells 28-29 contain an attack at
  pitch 36 followed by a hold at pitch 43. The event ledger retains pitch 36
  and therefore does not expose the frame-token inconsistency. The checker
  required an active gate before a hold but did not require the hold to retain
  its pitch. Retract the source-qualification PASS: this frozen source set is
  invalid and cannot authorize a candidate.
- 2026-09-24 frozen model preparation learned A, A-prime and B role models,
  then cadence bass graph validation correctly rejected seven compatible
  edges, all emitting that same attack-36 to hold-43 transition. Cadence
  melody passed. No candidate solve, generation, audio or listener verdict
  occurred. Saved preparation model files have an extra trailing line feed;
  failed preparation reported three heap blocks on an exception/Halt path,
  with vendor validation in the trace. Neither issue explains away the source
  defect. Under the frozen one-source/one-candidate stop condition, stop this
  authored phrase-WFC route without repairing or retuning the source set.
  Composition acceptance and its full credit remain open. A future source
  qualification must check exact hold-pitch continuity and event-ledger
  agreement with frame tokens before any model preparation.
- 2026-09-24 reassessment after the invalid-source stop: the earlier
  continuous-frontier screen and phrase-reset audit closed no composition
  criterion; the one subsequent frozen authored phrase-WFC source also failed
  before a candidate. The next bounded batch uses a different representation:
  learn short relative motif/transform choices with WFC, then project them
  through a separately fixed form, beat and chord grammar to exact two-part
  events. Freeze its policy before scoring, run one candidate, and stop on its
  first source, structural or musical gate failure without retuning. The
  original positive listener verdict remains required; this reassessment
  earns no credit.
- 2026-09-24 the frozen relative-motif attempt under ignored
  `build/composition-motif-grammar/` passed source preflight on checked
  Win32/Win64: four exact 64-token controls, all 16 motif IDs and 55
  order-2 branching contexts. Its one Win32 WFC solve returned a complete
  64-token path (SHA-256
  `8d660b724104ef4e8afbd4d99202297b4e55130cf631441b7e2867ab5df12ff3`).
  Projection then raised `Unknown motif ID` on the frozen final M11 rest
  token because the private descriptor omitted that case. No event ledger,
  WAV, Win64 candidate run or listener result exists. The exceptional exit
  reported two unfreed heap blocks. Salty Boi independently verified the
  source formula, frozen hashes, one solve and failure path. The ignored
  stop record initially misstated that no token artifact existed; it was
  corrected to preserve the complete token ledger. Stop this candidate
  under its predeclared no-rerun rule; do not count the implementation defect
  as musical rejection or award composition credit. The next work batch
  moves to an independent recorded core prerequisite while this task stays
  open for a future genuinely different composition policy.
- 2026-09-24 post-stop reassessment: the prior motif solve's complete,
  SHA-bound 64-token path remains available even though its private
  projector omitted M11. After an independent recorded-source path stopped,
  the next composition batch may replay **only those exact tokens** through
  a repaired Pascal projector, with no WFC solve, seed/source/model change
  or weakened musical gate. Freeze a fixed-token policy and code identity
  before projection. This is a bounded implementation repair and audible
  development check, not a rerun of the stopped stochastic candidate; keep
  its failed record intact. A structural failure still stops before audio.
  Any passing private WAV requires maintained integration, two-target QA
  and the user's whole-passage verdict before credit.
- 2026-09-24 the fixed-token replay verified the immutable 64-token output,
  repaired M11 as both-part rest and round-tripped 105 projected gates with
  no new WFC solve. The first source-union novelty gate then correctly failed:
  candidate phrase 0 exactly matches control 1 phrase 0, and candidate
  phrase 2 matches control 3 phrases 0, 1 and 2 after chord labels are
  stripped. Salty Boi independently verified these comparisons and the
  no-WAV/no-Win64 stop. The exceptional exit reported two unfreed blocks
  (76 bytes), so the frozen zero-leak resource gate also fails. This saved
  output is derivative at phrase level; do not render it or retry another
  seed/order on the same four-control corpus. The task remains open without
  musical acceptance or credit. A subsequent composition path needs a
  substantively richer source/structure contract and a newly frozen policy.
- 2026-09-24 read-only source audit after the copied-phrase stop: the maintained
  joint-event sequence learner retains exact two-part events but has no chord,
  bar or form context. The first-party voice and ensemble demos each contain
  only two four-bar controls with essentially fixed onset/rest skeletons;
  they are useful comparison controls, not a varied composition corpus. The
  stopped four-control motif corpus is likewise unavailable as a new training
  source. No existing checked-in symbolic source qualifies for this task's
  original 30-second result. Treat this audit as reassessment, not a new
  generation attempt or criterion pass. The next bounded implementation batch
  must first freeze a genuinely new first-party, multi-context two-part source
  and an explicit form/chord projection that can preserve a recurring theme,
  vary both parts and validate phrase-union novelty before rendering. Keep
  full published-score replay and variants of the stopped tiny corpus out of
  this batch. The user's paired listening feedback requires whole-passage
  coherence and fewer conflicting notes/beats; the improved pop behavior does
  not satisfy that musical gate.
- 2026-09-24 the newly authored form-conditioned source under ignored
  `build/composition-form-provider/` now passes its source-only gate after a
  separate, frozen formatting repair. The first checked Win32/Win64 run
  falsely reported internal PASS while FPC space-padded `%02d` token beats,
  ledger IDs and filenames; those bytes were disqualified before any model
  learning. A six-site explicit ASCII-digit repair changed no action tables,
  pairing or gates. Repaired checked runs and an independent Pascal byte
  verifier pass with zero leaks: 24 distinct canonical four-bar controls,
  37 branching order-2 contexts, and exact parity of all 26 source artifacts
  across targets. Salty Boi independently checked the hashes, source identity
  and old-to-new transformation. Source report SHA-256 is
  `6187d42ba66a116b0bc661528377d622612bb98eb6704227cf2c6f43213de68a`;
  ledger SHA-256 is
  `cf63db38d0aefb553697e396b0be6b9982e8aef3a4ded070758564abf7139a8a`.
  This closes no full acceptance criterion or credit. At the two-batch
  task-flow checkpoint, the source barrier is removed; the next bounded
  action is one separately frozen A/B WFC composition candidate under the
  existing form/chord/novelty policy, with no source or gate retune.
- 2026-09-24 the separately frozen form-conditioned candidate under ignored
  `build/composition-form-provider/` compiled on checked Win32/Win64. Salty Boi
  reviewed the Pascal gates, including a repaired result-level positional check,
  serialized event-ledger inversion and final report ordering. The qualified
  source hashes were bound before execution. Both targets' prepare-only runs
  produced byte-identical order-2/open model text (24 samples, 209 states,
  104 public tokens; SHA-256
  `f1e4906037e873048057ce24e0f92f026dae3e5ab30c8800498eafd7a89fd2be`),
  prepare report and candidate freeze template, with zero reported heap leaks.
  The one checked Win32 candidate stopped at its A solve with WFC
  `gssContradiction`, one pass and zero backtracks. It produced no candidate
  tokens, events or WAV; B and Win64 candidate were not run. Read-only review
  identifies an endpoint incompatibility: position-0 tokens are tagged
  `beat=00` and occur only with open-sample BOS history, while the frozen
  `wseFragment` extent requires an interior BOS-free starting state. This
  explains the immediate contradiction from the frozen semantics, although
  the stop file has no position trace. The masks correctly enforce same-beat
  source tokens; this is a representation/extent policy defect, not a solver
  result showing musical insufficiency. Freeze and stop this route without
  changing extent, tags, source, seed or budget. The source-only and candidate
  batches close no composition criterion; core task acceptance, whole-passage
  listening and credit remain open. A future candidate needs a genuinely
  different representation and an endpoint/path reachability preflight before
  its one solve; this note does not authorize an in-place retry.

- 2026-09-24 a genuinely different, source-free Pascal composition scaffold
  was frozen prospectively under ignored `build/composition-grammar-baseline/`
  with fixed seeds 1731/2731, form/chord/theme/contrast/cadence rules and
  structural/PCM/listening gates. It is a core-composition prerequisite and
  possible future WFC choice-provider scaffold, not learned WFC or recorded
  style learning. Salty Boi caught a final-report overwrite before execution;
  Ticket Guy repaired it and the action-slot lineage labels, then both checked
  targets compiled. The frozen Win32/Win64 runs and fresh replay directories
  exited zero with zero reported leaks. Both 35.556-second Pythian WAVs passed
  structural/PCM checks and exactly reproduced event, PCM and WAV bytes across
  targets and replays; the ignored `FREEZE.md`/`RESULT.md` retain identities,
  hashes and metrics. HFS feedback clips `3.wav` and `4.wav` now await the
  user's whole-passage verdict on timing, melody, harmony and originality.
  Numeric passes alone do not close this task or earn credit. No seed retune
  follows this fixed listener checkpoint.
- 2026-09-24 the user listened to both whole 35.556-second passages. They judged
  clip `3.wav` coherent with no stumbling, preferred clip `4.wav` overall, and
  judged clip 4 newly composed rather than a recognizable preauthored song.
  This closes the frozen pair's core musical listening gate at the stated scope.
  The ignored scaffold still needs a maintained Pascal library/consumer path,
  exact owned sequence and audio replay, and independent QA before task credit.
  It is not evidence of learned WFC composition or recorded style learning.
- 2026-09-24 the source-free route exposed a wording gap in criterion 2. An
  authored-source phrase comparison has no denominator when the maintained
  generator accepts no authored note/bar/phrase material. The criterion now
  states the empty-union audit and N/A result explicitly while retaining the
  prohibition on replaying complete authored music. The fixed two-seed result
  and the user's originality verdict remain bound; this clarification does
  not turn unperformed comparisons into a measured no-copy pass. Salty Boi's
  first maintained-CLI QA submission also found that a late report-write error
  overwrote an existing WAV and leaked blocks, and that global top jumps did
  not inspect note ends. Both defects require a focused repair and QA rerun;
  no credit is awarded yet.
- 2026-09-24 the maintained CLI repair stages and restores the WAV/report pair,
  returns normally on failure and checks all gate ends. Salty Boi's second
  focused QA submission passed checked Win32/Win64 replay, preserved sentinel
  output on report failure and accepted the empty-source N/A semantics. The
  first failed QA submission and unreviewed seed-1 smoke output remain
  development history, not acceptance evidence.
- 2026-09-25 the accepted source-free result and its original 1-point credit
  are unchanged. A distinct [WFC-selected harmony passage](NS-4_composition_02.md)
  now owns one of recorded integration's two unearned points; the historical
  statement above that integration retained two points describes this task's
  2026-09-24 completion state. The recorded workflow remains open with its
  full original criteria and one point.
