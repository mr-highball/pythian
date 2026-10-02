# NS-6_studio_12 — Expose the implemented filter catalog in Studio

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Expose the six implemented biquad kinds absent from the operator effects rack:
band-pass, notch, all-pass, peaking EQ, low shelf and high shelf. Reuse the
Pascal DSP and explain useful controls; do not add display-only effects.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned delivery_03 point transfers here; every donor criterion remains.
Credit is earned only after all criteria and prerequisites pass.

Accepted 2026-10-02 by Big Boss under the explicit solo instruction. All ACs and
the prerequisite pass at code `1b9349c53cdeef7fa3195f824e52002ca56df6ea`:
checked Win32/Win64 native fixtures, matched pas2js and actual Codex-browser
desktop/390 px multi-filter preview/save/reload. Exact-revision
[Linux integration and extracted core/WFC packages](https://github.com/mr-highball/pythian/actions/runs/36970941681)
pass. Frozen artifact hashes, screenshots, repaired failure and the solo verdict
remain in ignored `build/studio-expansion/`. No musical or physical-phone verdict
is inferred. Earns 1 NS-6 / 0.10 overall point.

**Acceptance Criteria:**

- AC1: All eight native biquad kinds plus gain, compressor and limiter are
  selectable. Native request validation, job persistence and rendering agree on
  each kind, parameter range and Nyquist bound. Bypass never bypasses validation.
- AC2: Human names, short purpose hints and suitable parameter controls explain
  frequency, Q and EQ gain without requiring knowledge of serialized field IDs.
  Ordering, bypass, edits, preview and saved derived clips preserve the recipe
  and original-source lineage. Missing controls cannot silently take default values.
- AC3: Checked native tests distinguish the added DSP kinds, reject invalid
  parameters and verify replay; actual desktop/narrow browser checks exercise
  a multi-filter rack, preview invalidation and a saved clip. Preserve live audio.

**Blockers**

- [NS-6_studio_05.md](NS-6_studio_05.md)

**Dev Notes:**

- 2026-10-02, Big Boss: native and pas2js now consume
  `pythian.effects.catalog`; six missing filters call existing `TBiquadEffect`.
  Shelf Q is deliberately absent because the primary fixed-slope algorithm does
  not use it. Preview/save/reload, order, bypass and invalidation pass in the
  actual Codex browser at desktop and 390 px. Win32/Win64 checked effects pass
  104 cases, core effect suites pass with zero heap leaks. Frozen artifacts and
  the solo verdict are in ignored `build/studio-expansion/`. Await exact-code CI
  before completion. These are media mechanics, not a human listening verdict.
- The new upper-frequency fixture exposed an x87 intermediate precision
  mismatch on Win32. The primary biquad now supplies explicitly rounded Double
  frequency bounds to both DSP and catalog. Both targets pass after repair;
  failure fixture `effects-win32-run-04` and repaired run-05 are retained.
- Existing delay/reverb exposure and explicit tails belong to
  [studio_15](../NS-6_studio_15.md); native long generation belongs to
  [streaming_01](NS-4_streaming_01.md), not this filter task.
- 2026-10-02, Big Boss: phone feedback finds five choices despite eight native
  biquad kinds in `src/pythian.biquad.pas`. This is an operator exposure gap;
  no new DSP algorithm or WFC dependency is needed for these six additions.
