# NS-2_sound-design_01 — Expose the synthesis library as editable instrument and effect recipes

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Make the library's sound capabilities usable in the instrumental experiment. Use shared recipes and controls rather than isolated browser approximations. Stop on a control that has no audible backend effect.

Primary attribution: NS-2. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

Accepted 2026-11-01 at source538b0ad6991d542977b5b0798ae7f7836740fdac after
complete CI550/run41325451184, native and actual pas2js consumers, isolated
desktop/390px Studio edits and the checked fixed-slot deployment. The ordinary
retained-score jobs perform complete recipes through primary code; actual
Before/After mix and part playback, scoped changed stems, immutable setup Save/
reload without learning, source-preview effects and release-aware replay pass.
All23 saved jobs,3 clips and7,143 existing private metadata files are unchanged.
The deployed editor opens an actual older recording-informed score with its
original cutoff/sustain provenance. This accepts usable Experimental controls,
ownership and replay, not musical quality or source-instrument identification.
Studio explicitly reports its sampler resolver as unconnected; explicit sampler
ownership is exercised by the portable library consumer.

**Acceptance Criteria:**

- AC1: Provide a browsable, extensible instrument recipe catalog covering oscillator/noise, wavetable, additive and FM/PM capabilities, layered key/velocity zones, envelopes and modulation. Optional explicit sampler instruments are instruments, not hidden full-mix reconstruction.
- AC2: Route per-part filter, gain/pan, dynamics, delay/reverb and other implemented effect capabilities through primary library code. Show available, connected and unsupported capabilities honestly; no requirement to enable every processor in one piece.
- AC3: Allow editable recipes, scoped audition and saved patches in Studio through the same public-library contracts. Timbre/effect edits can reuse the musical plan, with dry/processed and isolated/mix comparison and controlled output levels.
- AC4: Preserve factory/envelope ownership, deterministic replay and release/effect history in the changed consumer. Show missing extension needs as concrete library gaps rather than duplicate adapter DSP.

**Blockers**

- [NS-4_instrumental-runtime_01](NS-4_instrumental-runtime_01.md)
- [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-11-01, Big Boss: complete exact-source CI550 and extracted packages pass.
  The fixed stable slot now serves the matching checked server/worker/twelve
  browser assets. HTTPS200, available worker, all three legacy sound API reads,
  actual390px saved-track editor opening and zero console errors pass. Existing
  jobs/clips and all7,143 metadata hashes match before/after browser verification.
  Owned QA/stable-check tabs are closed, viewport reset, zero QA processes and
  zero playing audio; only the normal stable service remains. AC1–4 and their
  prerequisites pass, closing8 effort units. Consecutive nonclosing count resets
  from1 to0 on this actual editor/audition delivery. All recorded failures remain.
  Packet: E/runs/sound-design-20261101-boss/release01 and live-sounds-mobile.jpg.

- 2026-11-01, Big Boss: local editor/audition qualification now passes. Native
  mix57643, actual pas2js mix57643, native score worker66 and separately invoked
  codec/store37 pass with clean native heaps. The fixed QA service completes two
  browser-created sound follow-ups with unchanged decision/model identities and
  only the edited stems changing. Mix/isolated playback, Unicode setup Save/
  reload without jobs, layered additive/PM/custom gate, moving wavetable,
  FM/vibrato/delay, master reverb and source-preview stereo balance are exercised.
  Mobile390px has no horizontal overflow. Numeric JSON presentation, captured
  preset selector and Add movement handler failures were repaired. Retain their
  evidence with sd-ui04/05 and the earlier interrupted/cancellation packets.
  This is solo qualification, not independent or operator musical approval.
  Complete current-source CI and stable retained-score/clip/data checks remain
  required before DONE; no partial effort is accepted. Packet:
  E/runs/sound-design-20261101-boss and E/tests/sd-{ui,js,patches}06.

- 2026-11-01, Big Boss: reestimated6→8 before acceptance. This is a substantial
  cross-layer delivery: detached source/automation/gate definitions, native
  persistence and retained-score realization, six part/master racks and a
  touch-friendly editor covering layers, source families and movement. The
  initial estimate understated that integration. Accepted work is unchanged;
  current goal effort becomes188, accepted138 (73.40%),50 open units. No partial
  sound-design effort is awarded. The batch still targets AC2/AC3, not new
  inference, transcription or musical-quality claims.
- 2026-11-01, Big Boss: backend b5e6905 is published and complete CI549/
  run41317718388 passes, including the full maintained source-effect consumer
  and new HTTP bindings. The interrupted Windows packet remains partial. The
  optional editor batch is now in progress, not accepted/deployed. It shares
  the source-preview rack controls and uses ordinary score follow-ups/players.
  Native sd-ui04 rejected a mistaken gain-smoothing argument used as pan.
  The repair adds primary stereo balance and exposes it in the shared catalog;
  it attenuates channels without mono folding or boost. sd-ui05 then revealed
  that the effect-difference assertion measured only the unchanged left side;
  the test now measures both channels. Preserve both failed receipts. Current
  sd-ui06 native and sd-js06 checks run against the repair. Consecutive nonclosing
  batch count remains1 until this actual editor/audition criterion is resolved.

- 2026-11-01, Big Boss: final shared-code native worker65 now passes in
  E/tests/sd-score03, including unchanged notes/models/unrelated stems, dry
  restoration, FM timbre and the real long release. Native/pas2js109 and53288,
  native codec/store37 and their clean heaps stand. The original cancellation
  failure remains; the focused same-executable smoke retry passes47. The full
  Windows source-effect run stopped without a completion receipt (no live
  process/handle); retain sd-shared03 as partial, not passed. Require complete
  maintained CI for source-effect and HTTP bindings before deployment. A direct
  native probe disproved lost GetLastError as the sharing-error explanation, so
  no speculative retry policy change was made. This backend component does not
  close a whole Studio criterion; current consecutive nonclosing count is1.
  Next deliver the actual optional editor/audition consumer, preserving the
  simple playlist flow; reassess before a third nonclosing batch.

- 2026-11-01, Big Boss: backend batch now routes detached full instrument
  definitions and ordered part/master racks through primary recipe realization.
  Source-clip and instrumental effects share one named-parameter JSON boundary
  and primary chain factory; bypass validates retained stages. Native and actual
  pas2js mix53288 and instrument109 checks pass, with clean native heaps. The
  played-key check admits a broad zone at a supported key and rejects an actual
  above-Nyquist key. Metadata now uses scalar text, including private Unicode
  patch names; native codec/store37 passes. Native worker65 in sd-scenes01
  renders actual retained-score gain/dry/FM edits: notes/model stay unchanged,
  unrelated stems match, and an eight-second release remains audible after the
  former one-second tail. This packet predates the final shared effect JSON
  consolidation; current-source consumer checks and full CI remain required.
  No UI editing, scoped audition or full AC2/AC3 acceptance is claimed yet.
  Sampler bindings remain an explicit unconnected Studio capability.
- 2026-11-01, Big Boss: repaired validation approaches remain recorded under
  E/tests/sound-design-20261101-boss and E/tests/sd-native01. Neutral default EQ
  and limiter settings cannot prove a changed sound; the mix test now uses
  deliberately nonneutral primary parameters. Actual pas2js rejected a const
  owned-effect parameter during cleanup; the ownership helper is repaired.
  Native compilation exposed the invalid frCeil enum spelling; frCeiling uses
  the primary clock. The broader sd-native02 instrumental run failed at a live
  cancellation event read with a Windows sharing violation, after earlier
  renders; its clean heap and failed log remain. A focused retry is a diagnostic,
  not replacement evidence for a complete passing consumer. Do not silently
  raise lock/deadline budgets or claim this failed run passed.

- 2026-11-01, Big Boss: next batch advances AC2 and the sound-only part of AC3.
  Deliver saved detached instrument definitions and ordered per-part effects
  through one primary stem/mix recipe, then reuse them in generation and retained
  score playback. Native/pas2js checks must show changed sound, unchanged notes,
  unaffected other stems, continued effect/release state and ownership. Studio
  presents these through optional sound controls; simple playlist generation
  stays intact. Close at the actual sound-edit/audition consumer, or preserve a
  distinct prerequisite rather than expand into new inference or DSP. The prior
  turn closed AC1's concrete library component and deployed the separate runtime;
  consecutive nonclosing count starts at0. CI548/run41300076778 at0cff683 is
  now terminal success, qualifying the published AC1 catalog. Do not describe it
  as qualifying the newer backend changes or as completing this whole task.

- 2026-11-01, Big Boss: AC1 now has a concrete portable library consumer.
  `instrument.recipe` owns detached recipes and primary realizations;
  `instrument.catalog` exposes eight authored, editable starting points covering
  all requested synthesis families, layers, ADSR/custom gates and modulation.
  Native107 and actual pas2js107 pass. Eight native WAV auditions are saved in
  E/sound-design-20261101-boss/recipe-auditions03; native heaps are clean. Replay,
  gain edits, nested input/export detachment, key/velocity layering, immediate
  release and explicit sampler ownership pass. The existing primary factories/
  renderer perform the sound; no DSP is duplicated. Maintained integration/
  portability orchestration now includes the fixture. This bounded component
  is separate from deployed worker75cdd0e and completed native-reuse CI547. Its
  source publication starts its own full CI; it does not update the worker. No task
  effort is accepted: AC2/AC3 and their actual Studio consumer remain unfinished.
  Stop the AC1 batch here; next scope is owned per-part recipe/effect realization
  and saved/edited patches in Studio, using these same public value contracts.

- 2026-11-01, Big Boss: selected as the actual prerequisite of NS-5 saved styles,
  while the separate unguided runtime finishes its published CI. First batch
  advances AC1: a primary portable, detached recipe/catalog builds real layered
  TInstrument resources for oscillator/noise, additive, wavetable and FM/PM,
  ADSR and modulation. Existing TWaveSourceFactory, TAdditiveSourceFactory and
  TFmSourceFactory already share source.oscillator; reuse them rather than invent
  new wrappers or DSP. TWavetableSourceFactory and the13-effect primary catalog/
  rack already exist too. The gap is reusable editable definitions, ownership and
  consumer wiring, not missing oscillators. Close this batch with native/actual
  pas2js instrument playback, detached ownership, replay and invalid-recipe
  boundaries; stop at the complete AC1 consumer or a distinct demonstrated gap.
  Studio editing, saved patches and effect routing remain explicit AC2/AC3 work;
  no effort is accepted by this assessment. Keep this source work separate from
  the frozen75cdd0e worker currently awaiting CI/deployment.

- 2026-10-29, Big Boss: TSynthVoice, TInstrument, TStyleInstrument, source factories, automation, effects and buses are already implemented and exercised by native callers.
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
