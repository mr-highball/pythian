# NS-2_percussion_01 — Add explicit percussion roles and synthesized drum instruments

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Make kick, snare and hi-hat/percussive roles first-class musical decisions using existing noise/oscillator sources, envelopes, automation and filters. Audio/percussion adaptation belongs in Pythian. Stop if percussion is silently treated as a pitched chord member.

Primary attribution: NS-2. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Accepted percussion outcome — 2026-10-30, Big Boss SOLO.** The
[core recipes](../../../src/pythian.percussion.pas),
[percussion adapter](../../../adapters/wfc/pythian.wfc.percussion.pas),
[guide](../../PERCUSSION.md) and maintained isolated/combined callers meet AC1–4.

- AC1: Kick uses a falling sine; snare layers filtered noise and sine; closed
  hat uses high-pass noise. Editable gain, pan, gate/release, physical tone and
  cutoff reuse primary instruments, envelopes, automation, sources and filters.
  Portable core imports no WFC and requires no recorded clips.
- AC2: The original twelve pitched/proof passes remain unchanged. Four actual
  dependent passes add pinned accepted rhythm, kick, snare and hat. They form a
  second conditional graph, with explicit rhythm-input lineage and no joint
  cross-group backtracking. Drums are unpitched events, never harmony witnesses.
- AC3: The shared plan performs all six roles through native buses/scheduling and
  exact PPQ/tempo conversion. Drum enable, hit locks and preferences preserve
  pitched tokens/states. Contradictory rhythm/hit or disabled/hit locks reject;
  failed/cancelled candidates preserve the prior playable plan.
- AC4: Isolated two-second drum WAVs and a combined 19.34-second source-free
  caller are available. Final combined audio has 852894 stereo frames at
  44100 Hz, 16 passes and 2 kick/14 snare/64 hat hits for seed 731. The sparse
  kick is an observed authored starter result, not a density or quality promise.
  Exact replay passes. Core checks cover silence/release, gain and overlapping
  hits; combined fixtures retain pitched parts and remain bounded.

Stable native Win32/Win64 and actual pas2js pass 38419 core-only, 1119 WFC
percussion and 74472 existing runtime checks; native heaps are clean. The
isolated WFC fixture has 40 explicitly controlled hits and peak 0.391817014.
Extracted source packages verify 108 core / 163 full owned units and 122 / 288
content hashes respectively, executing native core and combined callers.
Actual pas2js also runs all three fixtures using only extracted library paths.
The original three-part WAV retains its previous bytes.

Final six-part WAV SHA256:
2073c04a8e6715fbcc159f8cb5ac662b933d75a03df823cd7b35cfc1ebb55f0c.
Core/full archive SHA256:
3f9cd5927c1878b7b270c4edc21ef1e44cfb4605c59b4228539d977c594827c3 /
1034d08cfc37ba0d1a281a0bd7c2b3884c2ab3d4d07ccc15e8d5028d7687e1c2.
Evidence is under percussion-20261030-boss in dedicated E-drive
build/tests/runs folders. This accepts reusable finite percussion, not operator
sound preference, recorded drum learning or ordinary Studio integration.
**Acceptance Criteria:**

- AC1: Provide reusable editable synthesized kick, snare and hat recipes with gate/release, level and routing controls; do not require clips cut from a training mix.
- AC2: Represent percussion events and their relationship to the shared time/rhythm graph explicitly. Harmonic coverage and voice-leading constraints must apply only to the roles they describe.
- AC3: Generate drums together with bass, harmony and lead through the instrumental runtime. Drum-pattern or density edits preserve locked unrelated parts and keep the shared clock.
- AC4: Supply audible isolated and combined examples, meaningful silence/overlap/control checks, and a clear unsupported-case diagnostic. Operator feedback may reject the sound without preventing experimental access.

**Blockers**

- [NS-4_instrumental-runtime_01](NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Repaired missing direct imports for primary time conversion and WFC token types. The 8-kHz isolated hat test rejected the initial one-pole high-pass recipe for weak output; the recipe now uses the existing primary biquad high-pass, with the original audibility/gain/overlap assertions retained. Failed logs remain under the percussion E-drive tests folder.
- 2026-10-30, Big Boss: Generic strict projection rules require at least one source alternative. The first disabled-part encoding used an empty alternative and correctly rejected. Disabled parts now use native all-rest hard masks, intersecting the caller's locks explicitly; a disabled hit lock rejects instead of being erased. Rhythm projections remain valid; no generic WFC change is needed. The first default rendered 2 kick/4 snare/64 hat hits over eight bars. The authored starter's hit preference is increased to 64 within the primary layer limit 1024; it is a soft preference, not a promised event density or a musical-quality claim.

- 2026-10-29, Big Boss SOLO, first percussion batch: AC1–4. Deliver reusable core kick/snare/hat instruments and a dependent generic WFC percussion group consuming the accepted pitched rhythm, then perform all parts through the instrumental runtime's native clock/buses/scheduler. Keep the two actual graph groups and pinned-input lineage explicit; no drum is a harmonic voice. Closing evidence includes isolated/mixed synthesized WAVs, silent/overlap/control cases, retained pitched states and native/pas2js consumers. Stop on a fake pitched-drum mapping or a proposed generic engine change; actual solver components already support this composition. Starting nonclosing count: zero after the runtime closure.
- 2026-10-29, Big Boss: Core wsNoise/oscillator voices, TVoiceAutomation, TGateEnvelope, TInstrument and buses exist. The current named-voice contract is pitch/harmony oriented; a percussion semantic mapping must be explicit.
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
