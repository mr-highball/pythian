# NS-3_experimental-learning_01 — Turn available WAV analysis into editable musical graph proposals

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Use the existing key/tempo/onset/pitch/dynamics/timbre analyses to propose musical providers for instrumental generation. Experimental access does not depend on a completed accuracy benchmark. Keep source, proposal and operator decisions distinct. Stop on hidden substitution of source grains for synthesized parts.

AC1 is delivered in the 2026-10-30 Big Boss batch: the ordinary recording and
import inspection jobs expose Experimental tempo candidates, all ranked tonal
alternatives, per-channel pitch spans and sound/dynamics measurements through
one shared Studio panel. Exact source ranges and shorter measured pitch extent
remain visible. Native and actual pas2js run 32 focused checks; the native capture
consumer passes 80 checks, including nonzero source offsets, and the existing
native pitch fixture passes with clean heaps. Isolated desktop/390-pixel Edge
checks exercise recording inspection, actual WAV upload/analysis, alternatives,
pitch details and unchanged generation settings. The retained import also
reopens through the final matched QA build. This is not physical-phone testing
or reliable mixed-recording transcription. AC2–4 remain open; no effort is accepted.

Primary attribution: NS-3. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Analyze an operator-selected recording/range or imported/microphone input using existing Pascal implementations. Present available tempo/key, rhythmic, pitch/event and sound observations with concise Experimental labeling and alternatives where available.
- AC2: In Studio, allow the operator to accept, correct, bypass or manually supply context and part assignments. Unsupported polyphonic separation must remain visible; authored seeds or manual choices can still drive a full instrumental experiment.
- AC3: Map selected proposals into real semantic provider vocabularies, constraints and instrument/automation settings. Produce synthesized comparisons against explicit original reference playback; retain original coordinates and the actual settings used.
- AC4: Saving corrections/feedback preserves lineage without silent training. Explicit Learn or Regenerate changes only the requested learning/model or generation scope. Keep known failed observations as evidence, not claims of established accuracy.

**Blockers**

- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)
- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Selected AC1 batch after runtime, percussion and Studio
  prerequisites passed (integrated CI503 green). Deliver bounded Experimental
  tonal alternatives, per-channel periodic-pitch spans and sound/dynamics
  observations in the existing recording/import/microphone analysis paths.
  Preserve source range and distinguish the eight-second pitch window from the
  up-to-thirty-second spectral/beat window. Closing evidence: core native/pas2js
  replay, silence/stereo/cancellation boundaries, actual desktop/narrow analysis
  paths. Stop at visible proposals; provider mappings, explicit acceptance and
  correction lineage (AC2–4) remain open. No task effort is accepted for this slice.

- 2026-10-29, Big Boss: Monophonic pitch/duration, candidate beat/tonal/onset analysis, sound fitting, MIDI previews and semantic provider APIs exist. General reliable mixed-WAV notes/roles/form remain incomplete; they are experiments rather than prerequisites for first synthesis.
- 2026-10-30, Big Boss: Evidence is under musical-proposals-20261030-boss in the
  dedicated E-drive build/tests/cache/runs roots. The new portable
  pythian.music.observations composes existing analysis, tonal, sinc resampling
  and pitch APIs; adapters only bind source coordinates/JSON and presentation.
  Native builds use stable FPC 3.2.2 Win64 with checked arithmetic and heap traces;
  actual pas2js runs the same portable fixture. The maintained native build and
  analysis-portability checks now include it.
- Repairs: the initial test incorrectly assumed pitch spans covered recording
  edges; preserve that failed run and expose actual measured boundaries instead.
  Short sources now use a shared primary PitchTrackRequiredFrames preflight and
  keep spectral observations when pitch is unavailable. An attempted pas2js run
  of the broader native/file-I/O pitch fixture exposed a byte-oriented FillChar
  reset in the primary region summarizer. Replace it with a portable typed reset
  and exercise that actual API in the portable fixture; the file-I/O fixture
  remains native. Remove the old duplicate import tempo wording. QA startup
  required an explicit empty inbox manifest; browser startup/navigation timeouts
  were reconciled against the live page, not treated as application failures or
  passed checks. No benchmark, new solver, provider admission or silent learning.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
