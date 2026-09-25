# NS-4_composition_02 — Compose with a WFC-selected harmony path

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Generate a substantial original two-part passage in which an actual Pascal-owned
WFC pass chooses the harmony path and the portable composer projects that path
into fresh note events. This closes the core WFC composition gap exposed by the
accepted [source-free composer](DONE/NS-4_composition_01.md), whose coherent
passages use seeded choices and authored rules but no WFC model. It does not
claim that the harmony was learned from a recording or that a personal genre
style has been learned.

North star: NS-4. Outcome owner: WAV-04-INTEGRATION, core WFC composition.
Completion credit: 1 NS-4 goal percentage point (0.15 overall points),
transferred from the unearned allocation of
[NS-4_integration_01](NS-4_integration_01.md). The recorded integration task
retains its full acceptance criteria and 1 NS-4 point. Total outstanding NS-4
credit remains 2 points (0.30 overall).
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [source-free composition](DONE/NS-4_composition_01.md),
[bounded WFC composition contract](../WFC-COMPOSITION.md),
[bounded WFC token generation](../../adapters/wfc/pythian.wfc.generation.pas),
and the stopped form-conditioned candidate recorded in the composition task's
Dev Notes. The earlier beat-tagged token path failed at its first WFC solve
because its initial tokens required a BOS state excluded by fragment extent.
This task uses untagged chord-function tokens and checks endpoint/path
reachability before a solve; it must not retune that stopped candidate.

**Acceptance Criteria:**

- Freeze exact first-party chord-source examples, their identities, the
  chord-function vocabulary, model order, boundary extent, form/cadence
  constraints, seed, solve budget, musical gates and stop conditions before
  scoring. Keep source-free examples separate from recorded style evidence.
  Report source-union comparisons, including complete progression and phrase
  copies; a changed seed alone is not novelty.
- Establish bounded Pascal reachability for the exact trained model and
  position constraints before solving. Require at least one complete legal
  16-bar path and at least one path outside the training progression union.
  Stop before WFC solve if either condition fails. Preserve actual WFC model,
  token, source and policy identities and distinguish solver failure from a
  musical rejection.
- Generate at least 30 seconds of two-part native audio from an actual WFC
  selected harmony path. The WFC-selected path must differ substantively from
  the fixed composer schedule and produce independently changed bass and
  melody events while retaining audible rests, overlap, recurrence and a
  resolved ending. Do not copy complete authored bars or use a published score
  as the generated song. Identify every authored form/rhythm/cadence rule and
  every WFC-owned choice in the report.
- Keep the portable composition API independent of WFC. Validate chord,
  note-gate and event ownership, and preserve the accepted seed-1731/2731
  source-free output bytes. Pass focused checked Win32/Win64 replay, bounded
  work, failure preservation and native audio checks; have Salty Boi review
  the completed implementation with the next eligible QA batch.
- Obtain the user's whole-passage verdict on melodic, harmonic and rhythmic
  coherence and whether the result sounds newly composed. Numeric and solver
  passes alone cannot close this musical criterion.

**Blockers**

- [NS-4_composition_01.md — DONE](DONE/NS-4_composition_01.md)
- [NS-4_note-events_01.md — DONE](DONE/NS-4_note-events_01.md)

**Dev Notes:**

- 2026-09-25 listener follow-up: the user heard `build/feedback/5.wav` and
  described the full passage as coherent in a simplistic way. They asked what
  it was trained on before judging whether it felt newly composed. The source
  is eight first-party 16-chord outlines, not a recorded song, multi-hour mix
  or NSynth. All eight outlines were rendered with the same Pascal composer
  and seed for direct comparison under ignored `build/feedback/source-01.wav`
  through `source-08.wav`; `source-chords.txt` contains the exact source text.
  These comparison renders are not eight additional review items. A listener
  novelty verdict is still pending, so criterion 5 and task credit remain open.
- 2026-09-25 a superseded single-task listening packet attempted source-free
  seed 731 before producing any new WAV and exposed a real A/return melody
  projection failure. The portable composer now retains the accepted greedy
  output for seeds 1731/2731 and uses bounded chord-degree projection search
  when that path would lose the projected A/return recall. Checked Win32/Win64
  seed-731 tests pass with 97 events, two degree adjustments and 67 of 100,000
  allowed search nodes; they check realized degrees, timing, cadence and replay.
  Salty Boi verified the two accepted seeds' exact event/PCM/WAV hashes and the
  maintained WFC caller path, with zero leaks. This repairs core reliability,
  produces no new listening item and grants no task credit. The user's next
  listening batch is cumulative across tasks, with `5.wav` still pending.
- 2026-09-25 task-flow gap: the accepted passage is source-free and musically
  reviewed, but its report explicitly has `LearnedWfc=False`; the remaining
  recorded integration cannot substitute for a core WFC-composed passage while
  recorded providers are blocked. The first bounded hypothesis is a chord-only
  WFC pass over untagged functions followed by the accepted form/event
  projector. This is distinct from the stopped beat-tagged and motif-token
  attempts. A reachability or source-novelty failure stops this route before
  a solve; do not respond with seed, order or token-tag sweeps.
- 2026-09-25 the first frozen chord-path development candidate passed its
  source/reachability gates and one WFC solve: eight complete first-party
  source paths, five tokens, 13 latent states, a novel 16-bar complete path
  and three changed bars versus the accepted fixed schedule. It projected
  through the Pascal caller-schedule API to 97 events, changing 8 bass and
  9 melody pitches while preserving event timing and track ownership. The
  35.56-second checked render has no clipping or note-end pop failure.
  Source-union phrase accounting is narrower: aligned phrases 1, 2 and 4
  exactly match a source phrase; only phrase 3 is novel. The bound source,
  policy, model, token and WAV hashes and Salty Boi's two-target QA are in
  ignored `build/wfc-chord-composition/RESULT.md`. The portable composer
  correctly reports the caller-supplied schedule's origin as unknown; its
  separate development producer was the Pascal WFC probe. The maintained WFC
  adapter and CLI now reproduce the same frozen identities from one Pascal
  command. No listener verdict exists. Do not accept the task or credit from
  this result alone.
- 2026-09-25 a maintained `pythian.tests.wfc.composition` regression now runs
  under the WFC build hook and pins the frozen source/model/token/event,
  reachability and 9/2/0/8 phrase-source identities. Its invalid-source case
  preserves every note gate and tempo change. Salty Boi's checked Win32/Win64
  replay passes with zero leaks. The listener criterion is still open.
