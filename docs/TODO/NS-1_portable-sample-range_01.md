# NS-1_portable-sample-range_01 — Share the portable Single sample limit

[Tasks](README.md) · [Ancestry consumer](NS-5_style-ancestry_01.md) · [Workflow](../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

The actual JavaScript ancestry cancellation/caller-codec consumer cannot compile
because the primary synth stream uses `Math.MaxSingle`, absent from pas2js.
Pythian already owns the exact `MaximumFiniteFloat32` contract in
`pythian.ieee754`. Reuse it for the synth stream, resampling, separation and
onset-dynamics sample guards rather than retaining platform constants or a
second decimal ceiling. Primary NS-1 attribution; this is a demonstrated
portable consumer gap, not new credit for the existing core baseline.

**Acceptance Criteria:**

- AC1: Owned sample guards and their existing overflow fixtures use the primary
  IEEE limit. Native finite/overflow rejection behavior and failure ownership
  remain correct; no second sample-range implementation is added.
- AC2: Affected native consumers and the actual JavaScript ancestry progress/
  cancellation caller compile and pass, including its original exception and
  caller-registry ownership checks. Preserve the original MaxSingle failure.
- AC3: Complete source/extracted qualification and matching runtime deployment
  pass with the ancestry delivery. Tests retain appropriate heap checks; deployed
  workers use normal runtime flags rather than heap tracing.

**Blockers**

- None. This unblocks the actual JavaScript qualification of
  [shared style ancestry](NS-5_style-ancestry_01.md).

**Dev Notes:**

- 2026-11-01, Big Boss: AC1/AC2 local consumers pass. Four product units and
  their existing overflow fixtures now reuse the exact primary IEEE limit.
  Native08 wave/resample streams, separation, onset, effects and bus checks pass
  with clean heaps. Actual JS08 ancestry progress/caller-codec now compiles and
  passes52,150 checks/52,041 callbacks; focused graph/audio replay is unchanged.
  Extra actual JS effects/bus fixtures also pass after their native-only error
  entrypoints use portable WriteLn/ExitCode (native stderr retained); fresh
  native hosts pass too. Preserve JS08 StdErr and JS09 Halt compile logs; their
  assertion bodies remain intact. Evidence: E/tests/ancestry-native08,
  ancestry-js08, portable-range-js10 and portable-range-native10. Complete
  source/extracted qualification and matching runtime delivery remain AC3.
  No effort is accepted.

- 2026-11-01, Big Boss: linked before expanding scope. Native07 repairs the
  actual common ancestry hook and passes52,150 progress checks/52,041 callbacks.
  Actual JS07 then fails compiling `pythian.synth.stream` at its platform-only
  MaxSingle reference; log/source remain in E/tests/ancestry-js07. The existing
  primary IEEE unit already supplies the exact portable ceiling. Other owned
  uses and the handwritten onset ceiling are the same bounded consolidation.
  One effort unit grows scope204→205, without acceptance or a counter reset.
