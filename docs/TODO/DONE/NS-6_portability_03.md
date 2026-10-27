# NS-6_portability_03 — Execute shared synthesis consumers under pas2js

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Remove native representation assumptions from the primary synthesis/music-render
closure so its existing algorithms and shared callbacks can actually execute
under pas2js. Discovered while validating
[offline rendering observability](NS-6_observability_03.md): the focused render
fixture imported `pythian.music.render`, which imported `pythian.instrument`;
its constructor used `FillChar(LCounts, SizeOf(LCounts), 0)`, rejected by pas2js.
This is a demonstrated consumer gap, not proof that every synth/grain path fails.

North star: NS-6. Outcome owner: SHARED-SYNTHESIS.
Completion credit: 0 additional. Existing musical, delivery and browser gates
remain with their owners. Do not fork the renderer or patch compiler/dependency
sources. This prerequisite does not prevent native observability acceptance.

Execution status: accepted 2026-10-27. Deliverable: an actually executable shared primary
synth/note/grain consumer under the matched pas2js toolchain. Closing evidence:
native/pas2js parity and abort/retry through that consumer. Stop on duplicated
rendering, changed native output or a compile-only portability claim.

All three criteria pass through the actual primary synth, instrument, note/chord
and grain consumer closure on checked stable FPC 3.2.2 Win32/Win64 and matched
pas2js/Node. Four authored cases compare all 162,542 emitted scalar samples at
the predeclared scaled tolerance, with exact geometry/clocks and same-target
replay. Independent QA passes. Required clock precision is repaired separately
below. No browser/WASM, every synthesis family, device or musical-quality claim;
zero additional credit.

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

- [Primary analysis portability — DONE](NS-6_portability_01.md).
- [Shared intake/text portability — DONE](NS-6_portability_02.md).
- [Exact shared musical clocks — DONE](NS-6_portability_04.md) — actual within-range
  fractional-history defect discovered during AC2; must pass before acceptance.

**Dev Notes:**

- 2026-10-27, Big Boss acceptance: Spike replaces instrument FillChar/SizeOf
  with portable explicit initialization of the same bounded zone-layer grid.
  Big Boss consolidates effects' unavailable MaxSingle reference into the
  existing primary IEEE-754 limit, preserving native math. No renderer/source
  algorithm, precursor source or compiler was forked. Native instrument and
  effects regressions pass, zero leaks. The original instrument compiler error
  and subsequent effects compiler error are retained.
- Spiegel's shared consumer exercises seeded frame tones (30,000 stereo
  frames), a chord (32,000 stereo frames), sinc grains with an internal gap and
  tail (35,000 mono frames), and an owned sample-source instrument (1,771 stereo
  frames). Invalid/layered-zone and detached source ownership, deterministic
  replay, callback parity/cadence, interior exception and retry pass. Existing
  render-progress consumer executes 187 checks on native and actual pas2js.
  The comparator requires four exact case geometries, every ordered sample,
  finite values and terminal PASS; empty/truncated identical logs reject.
  Float text uses an explicit decimal point. Native valid runs/comparisons
  report zero leaks. No full float32 bit-identity promise is inferred from the
  declared `1e-6 * max(1, abs(native), abs(pas2js))` numerical comparison.
- Spike's independent native/pas2js execution and source review pass. One
  comparator review finding was repaired: the first version could accept two
  empty identical logs. Actual complete consumer logs had passed, but that
  earlier comparator is not the maintained acceptance gate. A missing fixture
  import and a native-only formatter assumption were repaired before final
  frozen runs. No task reached two failed formal implementation submissions.
- During core assessment Big Boss reproduced an exact PPQ fractional-history
  failure, created [portability_04](NS-6_portability_04.md) and followed it before
  returning here. Both tasks retain their distinct evidence. Final maintained
  command passes on Win32/Win64 and actual Node, including the repaired clock,
  complete sample/state comparators and incomplete-log rejection. The command
  explicitly returns overall success after expected negative subprocesses.
  Native build registration and script parsing pass. Evidence remains in the
  dedicated E-drive `build/tests/runs/{synth,synthesis,timing}-portability-20261027-*`
  folders; final root outputs are under
  `build/synth-portability-20261027-boss/final-{win32,win64}/synthesis-portability/`.
  [Shared consumer guidance](../../MIDI.md#shared-synthesis-and-exact-counter-limits)
  records limits. No inference, private input, live audio, browser or deployment
  was needed; musical reference stops and credit remain unchanged.
- 2026-10-27, Big Boss selected all three criteria after rechecking NS-5's
  retained musical-reference gates. The previous turn closed offline native
  observability at `d3dc6b0`; delivery nonclosing count starts at 0, while
  scientific stops remain unchanged. Deliverable: the actual primary
  synth/instrument/note/chord/grain consumer executing on native and pas2js.
  Closing evidence: exact clocks/identities and same-target replay, cross-target
  per-sample comparison, malformed/ownership/seed and sparse-output boundaries,
  callback abort/cleanup/retry. Predeclared float comparison bound:
  `1e-6 * max(1, abs(native), abs(pas2js))`; integer/clock/identity fields are
  exact. Stop on duplicated synthesis, changed native math/output, tolerance
  relaxation or a compile-only result. Spike owns the instrument repair;
  Spiegel owns a new shared consumer fixture; Big Boss owns remaining primary
  representation repairs, maintained execution, integration and final judgment.
  No inference experiment, new source acquisition or musical credit is selected.
- 2026-10-27, Spiegel / Big Boss: matched pas2js compilation of
  `tests/pythian.tests.render.progress.lpr` stops at
  `src/pythian.instrument.pas:83` before JavaScript execution. No runtime or
  musical result is inferred. Big Boss records this linked gap and returns to
  the selected native observability task; no unrelated instrument edit is made
  in that batch. Preserve the failed compiler log under the dedicated E-drive
  `offline-progress-20261027-spiegel` build folder.
