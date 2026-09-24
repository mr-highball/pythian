# NS-4_composition_01 — Generate a coherent original passage

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Generate a substantial, source-free two-part native passage whose harmony,
melody and rhythm work together as music. This is a core composition checkpoint,
independent of the user's three personal style tests and of recorded-WAV note
learning. It is distinct from the bounded note-event adapter demonstration in
[NS-4_note-events_01](DONE/NS-4_note-events_01.md): the adapter proves exact
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
overall points. Composition and integration retain 3 open NS-4 points.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [note-event adapter](DONE/NS-4_note-events_01.md),
[named voice contracts](../INDEPENDENT-VOICES.md),
[work record](../WORK.md). The score-timed pitch clip was judged more musical
and free of audible pops after its release repair, but still not a coherent
song. The private unconditioned full-event clip failed its authored harmony
gate. The local bar representation produced only two globally novel F-context
bars that retained the authored melody; a separate 128-cell modular candidate
stopped at its fixed per-pass backtrack limit before rendering. None is an
accepted composition result.

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
  runs as well as independently changed melody and bass material. Constrain
  notes to their declared harmonic context while preserving intentional
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

- [NS-4_note-events_01.md — DONE](DONE/NS-4_note-events_01.md)

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
