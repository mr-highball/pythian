# NS-6_studio_05 — Audition layered effects and save derived collection clips

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Let an operator shape a selected original passage through an ordered effects
rack, hear the result during preparation, and deliberately add a new version to
the private collection. Reuse the library's existing DSP with bounded Pascal
rendering; preserve the source and the complete transformation recipe.

Execution status: accepted engineering outcome — 2026-10-01. Big Boss accepts
ordered and bypassable effects, current-range preview, replay, and explicit
derived-clip saving with retained lineage.
Closing evidence: independent browser
`build/salty-studio-browser-20261001/VERDICT.txt` and
`FINAL-BROWSER-IDENTITIES.json`, with retained native evidence under
`build/salty-studio-native-20261001/` (stable FPC 3.2.2 Win32/Win64 and
matched pas2js 3.3.1). Source and staged candidate identities are exactly those
recorded in the manifests; this is not a new published-revision or build claim.
This task's engineering work is complete; stop at this accepted scope. No musical or
scientific inference acceptance or duplicate credit follows.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: one unearned point each moves from studio_02/03; all original criteria
remain. No credit is earned by scoping or preview rendering alone.

**Acceptance Criteria:**

- AC1: Provide a labelled, keyboard/touch usable effects rack with supported
  parameter bounds, ordering and per-stage bypass. Audition original and processed
  audio from the selected range with clear progress, stale/error and ready states.
  Expose real supported DSP capabilities; never claim sample-accurate live
  processing when playback uses a newly rendered preview.
- AC2: Bound asynchronous render work and cancellation; preserve exact source
  hash/range, effect order/settings, output format, explicit tail policy and
  resulting audio hash. Replay produces the same result. Changed controls cannot
  play or save an older preview as if it represented the current rack.
- AC3: Save as new clip deliberately publishes a verified immutable derived WAV
  and recipe into a selected private collection. Preserve the original and
  prior versions. Duplicate submit/retry is idempotent and partial failure never
  creates a selectable incomplete asset.
- AC4: Derived media preserves its source-family identity, provenance and use
  restrictions, including across further effects versions. Training selection
  remains explicit; derivative variants never count as independent recordings
  or untouched evaluation. Generated-output lineage cannot become original truth.
- AC5: Independently validate native bounds/replay/lineage and the actual
  desktop/narrow select/effect/bypass/reorder/preview/save/reload path, including
  rapid edits, failure/retry, zero-effect and clipping/headroom behavior.

**Blockers**

- [NS-6_studio_04.md](NS-6_studio_04.md)

**Dev Notes:**

- 2026-10-01, Neo: Big Boss's native effect helper and worker extension use the
  existing gain, low/high-pass biquad, compressor and limiter in declared order,
  with bypass, source-rate Nyquist checks and exact bounded preview clocks.
  Explicit save retains verified WAV/recipe identity, original family/use and
  parent lineage, including subsequent derived versions; no automatic training
  or original replacement occurs. Short disjoint staging corrected a real
  Windows path-length failure during development. The new browser rack checks
  the live range/rack snapshot before playback or Save and invalidates stale
  previews; it presents actual background-job and clipping states.
- 2026-10-01, Neo: independent Salty native QA passes all 44 controls on stable
  Win32 and Win64 with zero leaks. Beyond replay/bypass/clipping/save/tamper
  boundaries, independent decoded-PCM projections verify filter attenuation;
  actual nonlinear output verifies gain/compressor and gain/limiter ordering,
  effective compressor knee, Nyquist rejection and child→parent→original lineage.
  Exact evidence is under `build/studio-effects-extension/` and
  `build/salty-studio-native-20261001/`. Root development preview/play/save passes;
  independent desktop/narrow rapid-edit, reorder, failure/retry and reload QA
  remains pending. Native submitted failures remain zero; no task/DSP double
  credit or independent-recording claim.

- 2026-09-30, Big Boss: user explicitly requests pre-applied and layered effects
  to create new collection material while preparing a corpus. Existing native
  effect-chain primitives supply the DSP; this task owns the operator surface,
  bounded rendering and derived-source integrity. No new DSP or inference
  algorithm is presumed necessary. No QA submissions yet.

- 2026-10-01, final acceptance — Big Boss accepts this task's scoped engineering
  outcome after independent native and browser evidence. See
  `build/salty-studio-browser-20261001/VERDICT.txt` and
  `FINAL-BROWSER-IDENTITIES.json`, plus retained
  `build/salty-studio-native-20261001/` results on stable FPC 3.2.2 Win32/Win64
  and matched pas2js 3.3.1. The global verdict's sole pending cancellation-display
  case belongs to studio_02. Native submitted failures: 0; browser submitted
  failures: 0 for this batch. QA runner/oracle corrections remain privately
  preserved and are not production failures; historical counters are unchanged.
  Prior pending notes are historical. Recorded source/staged
  identities remain authoritative; no new published revision is claimed.
  Award only the existing task allocation; no musical/inference acceptance.
