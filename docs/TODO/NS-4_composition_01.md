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
