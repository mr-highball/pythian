# NS-3_experimental-learning_01 — Turn available WAV analysis into editable musical graph proposals

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** Accepted — 2026-10-30
**Owner:** Big Boss (single agent)

**Description:**

Use the existing key/tempo/onset/pitch/dynamics/timbre analyses to propose musical providers for instrumental generation. Experimental access does not depend on a completed accuracy benchmark. Keep source, proposal and operator decisions distinct. Stop on hidden substitution of source grains for synthesized parts.

AC1–4 pass through the ordinary native jobs and desktop/390-pixel Studio paths.
The contextual editor accepts, corrects, bypasses or manually supplies tempo,
key, per-channel pitch cells and part assignment. Selected motifs drive actual
symbolic WFC context/voice providers and six synthesized parts, with authored
accompaniment. Original excerpts retain their source coordinates and provenance.
Sources are never the performed training-mix grains.

The Sound step explicitly applies measured brightness/dynamics starting points
to one pitched part, or accepts manual/corrected cutoff and sustain controls.
Shared portable application changes the real instrument voice; jobs retain the
recipe, applied values and original analysis digest. Apply, Save and feedback
never queue learning/generation. Explicit Generate builds models and renders the
requested experiment; matching model hashes do not imply a cache hit. Known runs
are explicitly repeated motifs, not learned continuity across unknown regions.

These are bounded Experimental hypotheses: spectral/beat windows up to30 seconds,
per-channel pitch over the first8 seconds, eighth-note quantization, and an
editable heuristic sound mapping. No mixed-WAV separation, automatic source
instrument identification, whole-corpus style learning, musical-quality verdict
or physical-phone validation is claimed. Broader sound recipes, vocabulary,
graph controls, form, styles and long sessions keep their separate tasks.

Primary attribution: NS-3. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Analyze an operator-selected recording/range or imported/microphone input using existing Pascal implementations. Present available tempo/key, rhythmic, pitch/event and sound observations with concise Experimental labeling and alternatives where available.
- AC2: In Studio, allow the operator to accept, correct, bypass or manually supply context and part assignments. Unsupported polyphonic separation must remain visible; authored seeds or manual choices can still drive a full instrumental experiment.
- AC3: Map selected proposals into real semantic provider vocabularies, constraints and instrument/automation settings. Produce synthesized comparisons against explicit original reference playback; retain original coordinates and the actual settings used.
- AC4: Saving corrections/feedback preserves lineage without silent training. Explicit Learn or Regenerate changes only the requested learning/model or generation scope. Keep known failed observations as evidence, not claims of established accuracy.

**Blockers**

- [NS-4_motif-coupling_01 — DONE](NS-4_motif-coupling_01.md) — real selected-role
  context coupling repairs the actual richer Studio manual melody and variants.

- [NS-6_json-identity_01 — DONE](NS-6_json-identity_01.md) — native Unicode
  musical choices and source/job receipts now preserve actual operator bytes.

- [NS-4_joint-context_01 — DONE](NS-4_joint-context_01.md) — paired context
  resolves the demonstrated AC3 motif prerequisite; Studio mapping is accepted above.

- [NS-4_instrumental-runtime_01](NS-4_instrumental-runtime_01.md)
- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Remaining AC3/AC4 accepted. Shared primary
  pythian.music.sound proposes bounded cutoff/sustain and applies them to actual
  voices. Win32/Win64 and actual pas2js pass47 shared observation/sound checks;
  final native choice/lineage checks pass59 on each native target with clean heaps.
  The full ordinary source/manual generation matrix passes99 on Win32 and checked
  optimized Win64. Real selected-part PCM changes, unrelated part PCM remains
  identical, bypass restores the preceding performance, and Original source
  offsets/receipts survive. The five optimized source jobs take7–13 seconds on
  this workstation with the original600-second limit. Preserve the unoptimized
  Win64 failure below; no universal timing or unoptimized-build pass is claimed.
- The maintained build compiles the ordinary worker and this full generation
  consumer with `-O2` while keeping its assertions/range/overflow/I/O checks and
  original budgets. A fresh `-B -O2` consumer rebuild also passes99 with clean heaps,
  including the final canonical integer/proposal-origin guards. Other consumers'
  build flags are unchanged; new remote CI is still pending publication.
- Actual desktop/390-pixel UI checks cover accept/edit/bypass/manual, saved reload,
  numeric controls, no horizontal overflow, and accepting sound without changing
  edited tempo/key/part/notes. Save leaves jobs identical. An ordinary optimized
  worker completes after the page closes; reopening plays/solos six parts, shows
  actual applied settings and switches between Original/synthesized playback
  with mutual pause. A marked automated QA unknown response and timestamped note
  save without changing jobs. Its stored request binds exact audio/model/material/
  parameter hashes to the immutable source/recipe job. Playback was muted; this
  is not operator listening approval or independent QA. Final manual-origin Save
  also passes the matched service/assets. Evidence is under
  musical-sound-20261030-boss in the dedicated E-drive roots; no QA data is promoted
  into the operator catalog. No WFC source, branch or pin changed.
- Repairs/failures: preserve the native extreme-value Min/Max overload failure;
  explicit bounded branches avoid narrowing a finite Double before rounding.
  Compare stored Double values when checking untouched voices across Win32's
  extended precision. Preserve the initial missing-output-directory and argument
  launcher errors; they are harness setup failures. Browser navigation timeouts
  were reobserved against the live service, without a restart; closing owned old
  tabs stopped competing polling. The primary-stage locator needed its actual
  tab ID, optional notes needed their collapsed details opened, and a test-local
  URL needed a declared binding. These were repaired harness actions. Final UI
  copy is shorter, technical mapping is local help, and missing proposals remain
  manual rather than falsely corrected observations. Integral sound numbers have
  one canonical JSON identity. Complete task acceptance adds8 units and keeps
  consecutive nonclosing batches at zero.

- 2026-10-30, Big Boss: The full Win32 source/sound matrix passes99 checks with
  clean heaps. Accepted and corrected sound change real PCM, an untouched part
  stays byte-identical, bypass restores the exact preceding performance and the
  symbolic model vocabulary is unchanged. Each explicit Generate still constructs
  its models; matching hashes are not a cache/reuse or no-learning-work claim.
  The unoptimized checked Win64 run times out at the unchanged600-second limit
  on its third four-second render. Retain its requests, events, partial WAVs and
  clean-heap failure under musical-sound-20261030-boss. Timing places most delay
  before rendering; do not infer an audio-control or WFC algorithm defect yet.
  Qualify the same full matrix in the normal optimized checked Win64 build with
  the same inputs and budget. If it remains blocked, create the specific linked
  runtime prerequisite before expanding scope; no raised limits or smaller test.

- 2026-10-30, Big Boss: Select remaining AC3 and its AC4 lineage checks. Audible
  criterion: deliberately accept, correct or bypass a recording's Experimental
  brightness/dynamics starting point and hear the chosen synthesized part change.
  Deliver a shared portable proposal-to-voice recipe: measured centroid proposes
  low-pass cutoff and quiet/peak window RMS proposes envelope sustain, with visible
  mappings and editable part/values. These are explicit heuristic starting points,
  not source-instrument identification or envelope reconstruction. Native jobs
  retain the selected recipe, actual applied values and Original coordinates.
  Minimal checks: portable/native/pas2js mapping and invalid/silent boundaries,
  native source-bound save/correction identity and actual audio change with fixed
  notes/seed, desktop/narrow accept/edit/bypass/Save/Generate. Stop after the
  complete existing task criteria; broader sound recipes/catalog, time-varying
  automation, corpus learning and graph workbench retain their separate tasks.
  Consecutive nonclosing count starts zero after the accepted coupling repair.

- 2026-10-30, Big Boss: Motif coupling passes its complete criteria: 1438 shared
  native32/native64/actual pas2js checks,43 actual native generation checks on both
  targets and ordinary desktop/narrow edit/save/generate paths. Original reference
  coordinates and corrected output remain real. Re-audit the remaining AC3 sound/
  dynamics mapping rather than automatically accepting8 units for this repair.
  Deeper sound catalog controls retain their separate task; no blanket prerequisite
  or new effort is added for work already required here.

- 2026-10-30, Big Boss: AC2 and the finite-job AC4 correction/feedback behavior
  pass the actual desktop/390-pixel Studio path: manual notes, source proposals,
  explicit part assignment, corrected tempo, bypassed key/pitch, Save/reload and
  Escape cancellation. Source and analysis identities remain unchanged; job
  history is identical after Save and a clearly marked automated QA feedback
  response. The contextual editor preserves location and keeps its navigation
  visible. Controlled source-derived synthesis and Original/Synthesized playback
  also pass; the linked richer motif failure keeps AC3 and the whole task open.
  No eight-unit partial effort is accepted. Real criterion closure leaves the
  consecutive nonclosing count at zero; follow the demonstrated prerequisite.
- Relevant native evidence: Win32/Win64 35 generation checks with clean heaps;
  Win64 51 choice-storage, 41 instrumental and 113 job regressions pass. Matched
  actual pas2js/browser assets compile; desktop/narrow playback advances both
  original and synthesized clocks and switching pauses the other player. QA
  audio is muted; no physical-phone or musical-quality verdict is claimed.
- Repairs/failures: the first editor request sent an empty query value and then
  treated a missing DOM attribute as a job ID. Use an omitted query for manual
  defaults and hasAttribute for the analysis action; handle native text errors
  before parsing JSON. Preserve those screenshots/errors. A UI probe initially
  sought the collapsed Analyze control; another sought an answer before playing
  both assets. Correct the QA actions without bypassing those controls. An early
  feedback-count snapshot raced the asynchronous save; a subsequent fresh read
  confirms one completed QA response. The richer graph contradiction remains.
- Final read-through repairs a lineage edge: changing tempo while retaining
  pitch cells, or reusing saved bypassed cells, marks that pitch input corrected.
  The targeted narrow-browser reuse/save case passes with the real native binding
  validator and unchanged job history. It cannot silently relabel edited cells as
  accepted analysis. Final QA assets match; all owned processes/audio are closed.

- 2026-10-30, Big Boss: A real browser manual-melody job demonstrates the linked
  motif-coupling prerequisite. Valid paired H/R and independent projected input
  solves do not guarantee a named-voice solution. Preserve that failure; do not
  raise search limits or count the controlled motif as general coverage. The
  source-derived native consumer still passes35 checks. The editor's desktop and
  narrow save/reload paths pass for manual and analyzed material; AC3/task remain
  open and no effort is accepted.

- 2026-10-30, Big Boss: Resume AC2–4 after the accepted data repair. Deliver
  ordinary native jobs that consume saved musical choices, a touch-friendly
  contextual editor, and explicit Original/synthesized playback. Closing evidence:
  actual changed motif/model/audio, source clocks and durable reference, unchanged
  jobs on Save, and desktop/narrow edit/save/reload/generate/listen paths. Stop at
  this task's complete operator workflow; broader corpus/form/blends remain in
  their existing tasks. Current consecutive nonclosing count is zero.

- 2026-10-30, Big Boss: The linked JSON-identity repair is accepted through
  Win32/Win64 51-check storage consumers and a 16-check actual native HTTP batch.
  The parent draft has a canonical source-bound musical recipe, immutable project
  persistence and a metadata preparation endpoint. Saving choices preserves the
  original analysis, source clock/license, corrections and no-hidden-learning
  behavior. UI controls, proposal-driven ordinary generation and Original
  comparison still remain; no parent effort is accepted. The draft source-title
  limit now matches the catalog's 256-byte limit. Until the runtime consumes the
  saved recipe, instrumental preflight explicitly rejects musical_material
  projects instead of silently using the starter; remove that temporary guard
  and replace its negative check when actual native recipe generation is wired.

- 2026-10-30, Big Boss: The joint-context prerequisite is accepted after native
  Win32/Win64, actual pas2js and relevant extracted consumers. Six-part motifs
  solve at the original search limits; corrected material changes synthesized
  output and the authored control is byte-identical to a fresh preceding-revision
  build. Its real criterion closure resets the nonclosing count to zero. Resume
  the existing AC2–4 Studio batch; no partial parent effort is credited.

- 2026-10-30, Big Boss: The first AC2–4 prototype closes no new criterion.
  Quantization/provider preparation exists, but two bounded free-generation
  attempts exhaust pass backtracking at harmony-voice (32 and1024). Follow the
  linked joint-context prerequisite, preserve the failed runs, and do not replace
  learned constraints with pinned output or keep increasing search limits.
  Consecutive nonclosing batches: one, carried into that prerequisite.

- 2026-10-30, Big Boss: AC2–4 batch selected after AC1/CI504 passed. Deliver
  saved accept/correct/bypass/manual choices, explicit part assignment, source-bound
  proposal-to-provider synthesis and Original comparison through ordinary Studio.
  Primary quantized patterns preserve unknown/silent distinctions; editable accepted
  runs may become explicitly repeatable motifs with authored accompaniment, never
  claims of automatically separated instruments or learned cross-gap continuity.
  Minimal closing checks: native/actual pas2js pattern and provider replay/boundaries,
  actual native jobs with different accepted/corrected material and source provenance,
  desktop/narrow save/reload/generate/compare with no silent generation from Save.
  Stop at that complete task outcome; long corpus vocabulary/form/style blending
  remains in its linked downstream tasks. Consecutive nonclosing count starts zero.

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
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
