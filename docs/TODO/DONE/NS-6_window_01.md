# NS-6_window_01 — Share periodic Hann coefficients across actual consumers

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Primary analysis and harmonic/percussive separation contain the same periodic
Hann calculation. The source-qualified pitch frontend in
[notes01](../NS-3_notes_01.md) needs that convention too. Put the primitive in the
portable Fourier owner and route the existing consumers through it before
adding a third implementation. The grain Hann intentionally uses sample-centered
phase and remains a different operation.

Execution status: accepted on2026-10-29. The linked native physical-feasibility
candidate failed55Hz and is stopped; recorded scoring remains stopped.
Delivered: a documented periodic coefficient API and both real consumers using
it with unchanged numerical results.
Closing evidence and stop condition: frozen per-target native consumer replay,
independent analytic/boundary checks on native32/64 and actual pas2js, original
consumer regressions and an extracted core consumer. Stop on changed output;
repair the extraction instead of relaxing the replay contract.
Primary attribution: NS-6. Secondary use by NS-3 earns no duplicate credit.
North star: NS-6. Outcome owner: independently reusable portable library.
Completion credit: 0 goal percentage points (0.00 overall points).
Credit is earned only when every acceptance criterion and task-flow completion requirement passes.

Completion evidence2026-10-29, Big Boss solo verification: exact source
0956deeaea99875dea6bdc3e4ca792d3dd15155b passes
[CI480](https://github.com/mr-highball/pythian/actions/runs/40823976126/job/123282649160),
maintained integration18m20s and extracted consumers46s. All272688 analytic
coefficient/spectral/boundary checks and257 original portable analysis checks
execute on checked FPC3.2.2 Win32/Win64 and actual pas2js in Node. Original native
FFT/separation signal, stereo, ownership and rejection controls pass. Each
native target's complete283905-value2271240-byte pre-change actual-consumer
packet is retained exactly after extraction: native64
bba4d5405f039400237977f522e65f3ea0a1ec0eb9b53c8a6794da98e37e625a,
native32 9a00d7d499e26ee4d8115c67b1b241d0c39e9c252dd6785e41f337083ee73cae.
Clean exact Win64 core delivery verifies107 owned units/120 hashes, archive
b0f8a54f44990514e2eb6f0fb323808a2ed4a41631433059fd102a13ddf1fe04; the public
function also executes all272688 checks from ZIP-only sources. Native exits
report zero leaks. Primary implementation/real consumers, explicit periodic
phase, bounds and preserved sample-centered grain behavior satisfy AC1–4.
No whole-separation browser, physical Studio or model/musical acceptance claim.
Zero credit leaves52.45/47.55 unchanged; this is solo verification, not an
independent review. [Work record](../../WORK.md) retains context and return path.

**Acceptance Criteria:**

- Expose one primary portable periodic Hann coefficient function with documented
  phase, supported frame/count bounds and explicit invalid-input rejection.
  Do not substitute the distinct sample-centered grain convention.
- Analysis and separation use that primary function. Exact frozen pre-change
  native32 and native64 packets retain every analysis feature/band value and
  every separated output sample; preserve each target's original bytes.
- Independent known coefficients, periodic symmetry/DC spectral support and
  failure boundaries execute on checked native32/64 and actual pas2js. Original
  analysis/separation/Fourier regressions continue to pass, including actual
  portable analysis. No whole-separation browser support is implied.
- Qualify the public function through a clean extracted core consumer and the
  maintained published native/integration checks. Preserve complete notices,
  source evidence and failures. This does not qualify the candidate model or
  close a musical gate.

**Blockers**

- None; candidate source/physical/recorded gates remain owned by notes01.

**Dev Notes:**

- 2026-10-29, Big Boss: all272688 analytic/boundary checks and257 original
  portable analysis checks execute on checked native32/64 and actual pas2js.
  Original native FFT/separation controls pass. Pre/post actual-consumer packets
  retain all283905 values/2271240bytes per target exactly; source identities and
  hashes are in [the work record](../../WORK.md). All native exits report zero
  leaks. The clean exact0956dee core package verifies107 owned units/120 content
  hashes, ZIP SHA256
  b0f8a54f44990514e2eb6f0fb323808a2ed4a41631433059fd102a13ddf1fe04.
  The public function also passes272688 checks from ZIP-only sources, zero
  leaks. [CI480](https://github.com/mr-highball/pythian/actions/runs/40823976126)
  subsequently passes terminal-successful. These mechanical results earn no
  musical acceptance. The following metadata-only PowerShell record initially
  used true instead of $true; its repair regenerates metadata without repeating
  or erasing the passing extracted consumer.

- 2026-10-29, Big Boss: source inspection found identical periodic expressions
  in primary analysis/separation. The current grain Hann has a half-sample shift
  and is not an equivalent replacement. The linked candidate must consume the
  shared primitive; no generic window catalogue or inference framework is
  selected. New generated evidence stays under the project-owned E-drive roots.
