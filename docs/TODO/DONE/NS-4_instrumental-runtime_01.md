# NS-4_instrumental-runtime_01 — Connect the musical graph to reusable instrumental synthesis

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

One primary Pascal entry point turns an actual coupled WFC musical plan into performed instrumental audio. Reuse named/mapped sessions, instrument planning, exact clocks, buses and the scheduler. The first example may use authored symbolic training material and operator context; label that origin. Stop on a hidden grain-render fallback or a second solver/renderer.

Primary attribution: NS-4. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Accepted runtime outcome — 2026-10-29, Big Boss SOLO.** The shared
[API](../../../adapters/wfc/pythian.wfc.instrumental.pas),
[reusable authored starter](../../../adapters/wfc/pythian.wfc.instrumental.starter.pas),
[public caller](../../../examples/pythian.example.instrumental.lpr) and
[guide](../../INSTRUMENTAL.md) deliver AC1–4. No Studio or recorded-learning
acceptance is implied.

- AC1: Actual named-voice generation has harmony, joint rhythm and three pitched
  parts, plus seven exact-coverage witnesses. The 64-cell caller reports twelve
  real 64 x 1 x 1 passes, actual dependency edges, public vocabularies/latent
  states, seed, PPQ/step and caller tonic/tempo. Starter harmony/rhythm is authored.
- AC2: Bass, harmony and lead use primary source-free instruments, native note
  projection, buses, filtered echo and scheduled synthesis. The maintained caller
  produces 852894 stereo frames at 44100 Hz (19.34 seconds, including release
  and an explicit three-second effect tail), without a WAV input or palette.
- AC3: An actual lead lock changes the note plan; tonic changes rendered audio
  and tempo changes duration. Repeated settings give identical WAV and graph
  sidecar bytes. Contradictory harmony/lead and final-ready cancellation preserve
  the prior plan; it remains playable after source material is disposed.
- AC4: Stable FPC 3.2.2 Win32/Win64 and actual pas2js execute the new fixture.
  Relevant native music-projection and named-voice regressions pass. Exact tempo,
  release tails, role routing, block/frame replay, failed admission and cleanup
  pass, with zero native heap leaks. The full extracted Win64 package runs the
  public caller; the new API fixture also runs against its extracted sources on
  pas2js. Generated output lives under the dedicated E-drive run folder.

Audio SHA256: 1b04120c0c6e0050681a9cc919c287babdab3276ff13e0240f5bae19a84830d7.
Evidence: instrumental-runtime-20261029-boss build/tests/runs folders under the
dedicated E-drive workspace. This closes the finite runtime capability and earns
7/82 effort units; it does not establish musical preference, learned instrument
roles, drum semantics, long-form quality or ordinary Studio integration.

**Acceptance Criteria:**

- AC1: Generate distinct bass, chord/harmony and lead parts through real dependent WFC passes, with explicit time, key/tempo, register, rhythm and instrument bindings. Start with existing supported graph contracts; expose actual graph dimensions, named passes, vocabularies and dependency edges in the result.
- AC2: Perform generated note events through Pythian source-free instrument voices and the primary effects/bus/scheduling path. The first consumer must render with source recordings unavailable; source audio is reference material, not its output sound bank.
- AC3: A changed seed or musical constraint changes a real plan; deterministic replay repeats it. Report contradictions with the involved pass/constraint and leave the previous playable result intact.
- AC4: Provide one maintained public-library caller and a bounded playable multi-part result. Check event timing, release tails, cleanup and changed-path native/portable behavior where that implementation is shared.

**Blockers**

- None. Existing implemented library APIs are the starting point; no new formal benchmark is a prerequisite.

**Dev Notes:**

- 2026-10-29, Big Boss: Preserved the unconstrained starter rejection and the first longer-caller rejection under the instrumental-runtime E-drive test run. The first starter returned no accepted free plan (its exact solver status was not logged in that initial assertion); the caller then exposed a genuinely unobserved C-to-C phrase-boundary attack. The repair supplies two actual eight-bar authored training phrases containing the required transitions and an explicitly authored harmony/rhythm guide. Voice choices remain real WFC. No solver retry, relaxed constraint, concatenated recording history or source-grain fallback was added.
- 2026-10-29, Big Boss: Native fixture imports initially omitted wfc_music_sequence; repaired before qualification. The separate old WFC/MIDI regression fixture cannot compile under pas2js because existing pythian.midi.export uses SizeOf. It remains a native regression; the new instrumental fixture executes on actual pas2js and does not depend on that export unit. This is not claimed as repaired MIDI portability or a new prerequisite. Native FPC emits a visibility-style warning for the intentionally private plan constructor; only the transactional factory publishes valid plans.

- 2026-10-29, Big Boss SOLO, first implementation batch after explicit resume: AC1–4. Deliver one transactional named-voice-to-instrument plan API, actual graph descriptions and a source-free maintained caller. Closing evidence is a bounded bass/harmony/lead WAV, deterministic replay, changed musical output, exact clock/release handling and failed-candidate preservation on native/pas2js. Stop at this finite runtime boundary; percussion and Studio remain separate tasks. The inherited nonclosing count remains two until a real criterion closes; the prior reset's reassessment changed the selected action.
- 2026-10-29, Big Boss: Existing pythian.wfc.voices, pythian.wfc.layers, pythian.wfc.duration.stream, pythian.instrument, pythian.music.render and pythian.schedule. The voices/layers demos already connect authored musical models to native sound.
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
