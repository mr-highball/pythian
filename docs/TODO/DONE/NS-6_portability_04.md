# NS-6_portability_04 — Preserve exact musical clocks under pas2js

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Repair the primary timing representation boundary reached by shared synthesis.
An actual pre-repair pas2js probe at maximum positive Integer PPQ and 384-kHz
output, advancing one tick then the remaining ticks at maximum MIDI tempo, returned
the correct 6,442,450 frames but fractional history 1,202,590,841,552,000 instead
of 1,202,590,842,320,000. Intermediate tick-times-tempo multiplication exceeds
exact Number precision although the final counters and fraction fit it.

North star: NS-6. Outcome owner: SHARED-SYNTHESIS. Completion credit: 0 additional.
Execution status: accepted 2026-10-27; prerequisite discovered during
[synthesis portability](NS-6_portability_03.md). Deliverable: one primary exact
clock implementation with representation-aware integer operations and explicit
target counter limits. Closing evidence: exact native/pas2js clock/remainder
parity, atomic rejection and unchanged native full-Int64 behavior. Stop on
approximate timestamps, changed native timing, duplicated musical algorithms or
silently rounded admitted counters. Big Boss owns the repair/final judgment.

All three criteria pass on checked stable FPC 3.2.2 Win32/Win64 and actual
matched pas2js/Node. The primary clock retains its PPQ carry algorithm; a
pas2js-only integer representation helper divides exact base-2^16 tick-product
limbs. Native full-Int64 math remains. Target limits reject before accepted
state changes. No musical, actual-browser or WASM acceptance or extra credit.

**Acceptance Criteria:**

- AC1: Preserve exact PPQ fractional history and floor/ceiling frame conversion
  for supported shared inputs, including valid products above `2^53` whose
  results fit target limits. Keep native full-Int64 support. Reject unsupported
  pas2js counters/intermediate outputs explicitly before accepted state changes;
  disclose its `2^53-1` exact nonnegative counter limit.
- AC2: Exercise actual immutable and incremental clock consumers with changes,
  boundary rounding, snapshot/replay, inputs above 32 bits, largest PPQ and
  interior carry. Compare every emitted integer/state field exactly across
  checked native and actual pas2js, not with audio tolerances.
- AC3: Validate overflow/invalid snapshot preservation and synthesis frame-plan
  admission at the target integer boundary. Preserve existing native clock/music
  regressions and shared synthesis clocks without external inference or huge
  audio allocation. Neither Node execution nor tests imply browser/WASM support.

**Blockers**

- None. Verified native/pas2js toolchains are available; original failing probe
  remains in the dedicated E-drive evidence root.

**Dev Notes:**

- 2026-10-27, Big Boss acceptance: the original 384-kHz / maximum-PPQ witness
  now preserves fraction `1202590842320000` exactly with 6,442,450 frames.
  Native and actual pas2js compare seven measured state rows plus terminal
  PASS exactly, including >32-bit counters, tempo changes, floor/ceiling,
  restored replay and interior carry. Target-limit, invalid rational/snapshot,
  fractional/NaN JS snapshot and frame-plan/end-overflow rejection checks retain
  prior state/plans without allocating huge audio. Native above-2^53 support
  remains exercised. Native clock/music regressions pass; successful checked runs report
  zero leaks. The existing music fixture first received a directory instead of
  a MIDI filename and failed with temporary allocations unfreed; that invocation
  is retained and excluded. Corrected filename invocation passes with zero leaks.
- Big Boss owns the primary timing/synth admission repair. Spiegel owns the
  shared maintained fixture; Spike independently reviewed the integer bounds
  and ran 15 adversarial native/pas2js shared-range states with exact agreement.
  An initial adversarial case reached native-only output range; JS rejection is
  retained as an expected target-limit difference, not silently excluded parity.
  Bounds, guarded publication and borrowed/value ownership remain explicit.
- Test-development repairs: the first large-tick witness reached only
  `2^32-1`; its increment was corrected. A pas2js literal beyond its safe limit
  was replaced by an incremented boundary value for the rejection test. A test
  formatter initially used native-only DefaultFormatSettings; explicit matched
  target settings repaired compilation. These precede final frozen execution.
  One synthesis-comparator review finding was repaired in the linked task; no
  implementation task accumulated two failed formal QA submissions.
- Maintained [cross-target check](../../../tools/check-synthesis-portability.ps1)
  runs the same primary timing/synthesis consumers, exact integer comparator
  and empty/truncated rejection checks. Source tests also join the native build.
  Final root evidence: E-drive
  `build/synth-portability-20261027-boss/final-{win32,win64}/synthesis-portability/`;
  independent `runs/synth-portability-20261027-spike-clock-qa/` and
  `runs/timing-portability-20261027-spiegel/`. The earlier failing probe remains.
  [Timing contract](../../MIDI.md#shared-synthesis-and-exact-counter-limits)
  declares supported limits and synchronous execution. No source acquisition,
  inference experiment, browser, service replacement or WFC dependency edit.
- 2026-10-27, Big Boss: stopped expanding portability_03, recorded this distinct
  required gap and followed it as a genuine exact-clock prerequisite. The
  retained failure is `runs/synth-portability-20261027-boss/clock-probe-js-before.log`.
  The original native clock fixture itself uses native stderr/exit handling;
  its pas2js compiler failure is retained separately and is not the numerical
  reproduction. No musical scientific family or exposure counter was reopened.
