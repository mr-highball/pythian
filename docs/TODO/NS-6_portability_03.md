# NS-6_portability_03 — Execute shared synthesis consumers under pas2js

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Remove native representation assumptions from the primary synthesis/music-render
closure so its existing algorithms and shared callbacks can actually execute
under pas2js. Discovered while validating
[offline rendering observability](DONE/NS-6_observability_03.md): the focused render
fixture imports `pythian.music.render`, which imports `pythian.instrument`;
its constructor uses `FillChar(LCounts, SizeOf(LCounts), 0)`, rejected by pas2js.
This is a demonstrated consumer gap, not proof that every synth/grain path fails.

North star: NS-6. Outcome owner: SHARED-SYNTHESIS.
Completion credit: 0 additional. Existing musical, delivery and browser gates
remain with their owners. Do not fork the renderer or patch compiler/dependency
sources. This prerequisite does not prevent native observability acceptance.

Execution status: ready. Next deliverable: an actually executable shared primary
synth/note/grain consumer under the matched pas2js toolchain. Closing evidence:
native/pas2js parity and abort/retry through that consumer. Stop on duplicated
rendering, changed native output or a compile-only portability claim.

**Acceptance Criteria:**

- AC1: Compile the actual primary synth, note/chord and grain consumer closure
  with the matched pas2js compiler/RTL. Replace reachable native-only operations
  at their representation boundary in the primary implementation. Preserve
  instrument/source ownership, initialization and existing native behavior.
- AC2: Execute meaningful shared source/render fixtures on checked native FPC
  and pas2js, retaining malformed-input, deterministic seed, source ownership,
  note/chord/grain clock and sparse/trailing-output coverage. Declare numerical
  comparison tolerances before cross-target scoring; a compile pass is not parity.
- AC3: Execute callback counts, interior abort/cleanup and retry through those
  actual shared consumers. Document synchronous bulk calls honestly; neither
  Node execution nor timers alone establish browser responsiveness or WASM.

**Blockers**

- [Primary analysis portability — DONE](DONE/NS-6_portability_01.md).
- [Shared intake/text portability — DONE](DONE/NS-6_portability_02.md).

**Dev Notes:**

- 2026-10-27, Spiegel / Big Boss: matched pas2js compilation of
  `tests/pythian.tests.render.progress.lpr` stops at
  `src/pythian.instrument.pas:83` before JavaScript execution. No runtime or
  musical result is inferred. Big Boss records this linked gap and returns to
  the selected native observability task; no unrelated instrument edit is made
  in that batch. Preserve the failed compiler log under the dedicated E-drive
  `offline-progress-20261027-spiegel` build folder.
