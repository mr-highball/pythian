# NS-6_portability_11 — Execute the actual duration synthesis consumer portably

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

The initial actual duration stream compile exposed unavailable `MaxSingle`
references in primary bus and scheduled clip rendering. Both paths now reuse
`pythian.ieee754.MaximumFiniteFloat32`, already consumed by effects, granular
rendering and resampling. The shared segment work did not cause these failures.
Keep the compiler, scalar representation and algorithms shared. Verify the full
consumer rather than stopping at a tiny compilation probe.

Execution status: **Accepted 2026-10-28** at exact source
`37ba12a9a59ba7ac0921d5e6ee59929745ebb2a2` after checked native Win32/Win64,
actual pas2js, clean extracted core/full packages and downstream
[CI476](https://github.com/mr-highball/pythian/actions/runs/40808920670).
Delivered: primary boundary reuse and executed duration rendering with future
edits, rollback, owned models and portable numerical evidence.
Closing evidence: original controls, frozen native PCM/plan identity, declared
cross-target comparison, scalar boundary controls, clean exact packages and CI.
Stop on changed musical/search/timing policy, weakened bounds, increased
comparison tolerance, dependency edits or an unrelated required gap.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS.
Completion credit: 0 additional. Parent
[retained operations04](../RETIRED/2026-10-29/NS-6_observability_04.md) needs this actual portable
duration consumer before its shared stream component can be qualified. Native
and ordinary chunk paths remain separately measurable. No musical credit follows.

**Acceptance Criteria:**

- AC1: Compile and execute the actual primary bus/scheduler/duration consumer
  closure on checked native Win32/Win64 and the verified pas2js compiler/RTL.
  Reuse the existing primary IEEE-754 boundary and repair any demonstrated
  reachable target representation issue in its owning implementation. Do not
  add alternative algorithms, a target-specific synthesis engine or a looser
  fallback.
- AC2: Preserve every existing duration fixture assertion: staged context,
  latent continuation, future edits, emitted-prefix/committed-note preservation,
  failure/retry, detached state, model ownership, terminal behavior and audio.
  Native shared/frozen replay must retain exact plan snapshots and every
  Double sample in the existing 70,000-frame stereo replay
  (`e91b9ab841bea4323bebd9af5927a82e2a62decad6b0f05bb4d802f836bc19af`,
  1,121,765 bytes including snapshots).
- AC3: Execute a common duration PCM/plan probe on native and actual pas2js.
  Before comparison, declare **1e-9 absolute per-channel sample tolerance**
  for the normalized musical fixture and exact equality for counts, clocks,
  notes, tokens, latent states and snapshots. Check every matched frame and
  channel; a compile, summary or hash of rounded aggregates is insufficient.
  No tolerance increase or narrowed subset after seeing a failure.
- AC4: Meaningfully exercise the actual bus render boundary at both finite
  Float32 extrema and just beyond them, plus relevant nonfinite/failure/reset
  behavior. Reuse the primary exact limit; do not preserve the native RTL's
  rounded overshoot as a compatibility contract. Ordinary native PCM, scalar
  codecs and supported core-only use must remain unchanged. Native exits have
  zero leaks.
- AC5: Publish the exact source on `hello-pythian`, pass maintained integration
  and clean extracted core/full consumer checks. Record actual native/pas2js
  execution separately from browser/device acceptance. All criteria and
  prerequisites must pass before moving this task to DONE.

**Blockers**

- [Primary synthesis portability — DONE](NS-6_portability_03.md).
- [Exact shared timing — DONE](NS-6_portability_04.md).
- [Shared streamed chord renderer — DONE](NS-6_portability_10.md).

**Dev Notes:**

- 2026-10-28, Big Boss: all AC1–5 and the three accepted prerequisites audited
  against exact source37ba12a, maintained fixtures and retained execution logs.
  CI476 succeeds: native16m29s, integration15m27s and extracted consumers38s.
  Both clean Win64 ZIPs pass actual extracted consumers and all inventory hashes:
  core107 owned/120 hashes, SHA256
  `d072679c39665a94211814dcfb423aa7388ac04fac78a3af46fb5b535beebeda`;
  full159/280, `bf256414b9fc1674da398d03b7a29f446fcaf0a01255354a03f42fd160f30725`.
  AC1 reuses the primary IEEE-754 boundary in both actual renderers; AC2 preserves
  all original duration assertions and exact frozen native PCM/plan bytes;
  AC3 compares every140000 channel sample and both exact plans at the unchanged
  predeclared1e-9 limit; AC4 exercises192 checks/48 scalar cases on all three
  targets, ordinary native regressions and zero native leaks. Actual pas2js
  execution is not browser/device responsiveness. No full duration/scheduler
  observation or musical acceptance follows. Parent04 remains open.
  Counts52 open/88 DONE/140 total, NS6 14 open;52.45/47.55 unchanged.
  This whole required task closes delivery nonclosing2→0; scientific stops and
  exposure counters remain. Earlier pending descriptions below are dated history.

- 2026-10-28, Big Boss: local duration gates now pass on checked Win32/Win64 and
  actual pas2js. Every one of70,000 stereo frames (140,000 channel samples) and
  both full plan snapshots is compared by a Pascal-owned probe. Maximum native64/
  pas2js error is4.58e-15; native64/native32 is6.01e-15, under the unchanged1e-9
  absolute limit. Counts/clocks/notes/tokens/states/snapshots match exactly.
  Post-fix native raw replay retains the frozen1,121,765bytes/SHAe91b9ab8...c19af.
  The maintained scalar fixture passes192checks/48 cases on all three targets:
  both renderers/channels, exact extrema, inside/outside, nonfinite and reset.
  Original bus/scheduler/duration controls and finite capture129850/52 pass;
  native exits have zero leaks. AC5 source/package/CI qualification remains.

- 2026-10-28, Big Boss: after repairing the bus reference, actual compilation
  exposes the same native-only constant in scheduled clip output. Both primary
  sites now consume pythian.ieee754.MaximumFiniteFloat32, with no duplicate
  limit or synthesis implementation. Actual pas2js then executes all original
  duration controls successfully. This is preliminary AC1 execution, not full
  task acceptance; native post-fix replay, scalar boundaries, the declared
  every-frame comparison and exact publication/consumer gates remain required.

- 2026-10-28, Big Boss: the shared sequence/stream component passes its original
  native controls and frozen three-seed sequence plus 70,000-frame duration
  replay. Actual pas2js executes the ordinary stream controls after removal of
  the fixture's unsupported StdErr/Halt failure wrapper, with all assertions
  retained. The subsequent actual duration compile rejects the existing
  primary bus MaxSingle reference. Preserve those compiler failures under the
  E-drive sequence-stream-progress-20261028-boss tests packet.
- This is a genuine primary consumer prerequisite, not a generic WFC defect.
  Delivery nonclosing1→2 at discovery. Mandatory reassessment keeps NS5's
  reference/context stops intact, selects this bounded missing consumer
  capability and forbids another instrumentation batch before reassessment.
  New task names, pauses and qualification records do not reset the count.
  The initial task definition implied no fix; later execution evidence above
  records the candidate and its still-required publication gates.
