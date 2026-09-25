# NS-3_notes_06 — Bridge admitted note spans to saved WFC learning

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Deliver the reusable Pascal boundary that takes admitted monophonic note spans,
explicit silence/unknown intervals and source ownership into actual saved WFC
pitch/duration learning. This is a generic bridge, exercised with source-bound
published reference events so it can be accepted before automatic note
inference is accurate. It does not assert that those events were inferred from
audio or that the resulting music passes a listening test.

North star: NS-3. Outcome owner: WAV-03-PHRASES. Completion credit: 1 goal
percentage point (0.25 overall points), split from the original unearned 5
points of [NS-3_notes_03](../NS-3_notes_03.md). Credit is earned only when every
acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [phrase task](../NS-3_notes_03.md) · [WFC pitch adapter](../../../adapters/wfc/pythian.wfc.pitch.pas) · [native inference](NS-3_validation_02.md).

Accepted 2026-09-25: the maintained
[admitted pitch adapter](../../../adapters/wfc/pythian.wfc.admitted.pitch.pas)
and [focused fixture](../../../tests/pythian.tests.wfc.admitted.pitch.lpr)
pass checked FPC 3.2.2 Win32/Win64 with zero leaks. The fixture verifies
source/annotation ownership, original-frame-to-integer-millisecond conversion
at 16 and 44.1 kHz, exact 100-ms model token with 99/101-ms alternatives
absent, source/unknown/uncovered training splits, explicit silence, leading and
trailing excluded gaps, invalid input and 33-run refusal, canonical reload,
deterministic WFC solve and failed-output preservation. The evidence builder
is linear in its bounded output. A separately frozen Pascal integration
verified actual WAV and published Notes bytes from two development-exposed
URMP works, trained 22 independent runs with 23 pitch spans, saved/reloaded
the WFC model and source/policy evidence and solved two seed-731 tokens. Both
targets and repeat runs match exact model/evidence/token SHA-256 values
`c7602485034a094001d905887ab17cb914758861a86da31955ec18ccbf1cb2f2`,
`22eea1992a95107a2d965474d5b4c9fdcfde5b58511125560b79fc80cb2319ca`
and `162344203556a49ed158aaf2a17bc093af12daf6da1797a71e95942f77648c32`.
Salty Boi's final QA found no blocker. Exact private source identities,
commands and checked logs remain under ignored `build/admitted-wfc-bridge/`
and `build/admitted-note-bridge/`. Reference events are externally supplied;
no recorded note inference, acoustic rest, musical quality or listener verdict
is inferred from this bridge.

**Acceptance Criteria:**

- Accept bounded source-bound monophonic spans in original frame coordinates,
  retaining actual source hash/geometry, recording/group identity, kind, pitch,
  duration and explicit excluded intervals. Bind the separately supplied event
  packet's hash, annotation method and publisher authority; identity hashes do
  not by themselves establish acoustic correctness. Validate positive intervals,
  exact ordering, source extent, pitch range and ownership; reject malformed or
  overlapping evidence before a model is published. Reference events are
  identified as externally supplied, never as Pythian inference.
- Convert original start/end frames independently to a shared integer
  **millisecond** model clock using nearest rational rounding with ties upward;
  subtract endpoints for duration tokens and reject collapsed or oversized
  spans. Retain original frames/rates for evidence, and test equal elapsed
  durations across differing source rates and deterministic boundary rounding.
- Preserve silence as a supported interval and unknown/gaps as hard training
  boundaries. No WFC sample or transition crosses an unknown interval, group,
  recording or uncovered source region. Unknown is excluded from the learned
  token vocabulary and generated output; silence may remain a learnable token.
  A repeated weight never joins runs.
- Learn from at least two distinct source groups with the retained WFC adapter,
  serialize/reload the model and its source/policy evidence, and solve a bounded
  deterministic sequence. Show exact replay and which pitch/duration information
  was learned versus supplied by the caller; do not claim musical quality from
  machine checks.
- Pass checked stable FPC Win32/Win64 boundaries for valid sources, gaps,
  malformed/foreign source evidence, failure preservation and bounded work.
  Keep the portable core independent of WFC and all inference Pascal-owned.

**Blockers**

- [NS-3_validation_02.md](NS-3_validation_02.md)

**Dev Notes:**

- 2026-09-25 split after the accepted raw multi-recording observation stream
  exposed the missing semantic bridge. This task owns a reference-exercised,
  reusable learner contract; [NS-3_notes_03](../NS-3_notes_03.md) still owns
  passing automatic note admission on independent recordings and the actual
  inferred-event-to-generation result. No credit follows from defining this
  task or from raw salience alone.
