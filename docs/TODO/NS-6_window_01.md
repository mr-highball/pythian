# NS-6_window_01 — Share periodic Hann coefficients across actual consumers

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Primary analysis and harmonic/percussive separation contain the same periodic
Hann calculation. The source-qualified pitch frontend in
[notes01](NS-3_notes_01.md) needs that convention too. Put the primitive in the
portable Fourier owner and route the existing consumers through it before
adding a third implementation. The grain Hann intentionally uses sample-centered
phase and remains a different operation.

Execution status: local native/portable gates pass; exact published and extracted
consumer qualification remain. This is a prerequisite for the selected native
physical-feasibility candidate; recorded scoring remains stopped.
Next deliverable: a documented periodic coefficient API and both real consumers
using it with unchanged numerical results.
Closing evidence and stop condition: frozen per-target native consumer replay,
independent analytic/boundary checks on native32/64 and actual pas2js, original
consumer regressions and an extracted core consumer. Stop on changed output;
repair the extraction instead of relaxing the replay contract.
Primary attribution: NS-6. Secondary use by NS-3 earns no duplicate credit.
North star: NS-6. Outcome owner: independently reusable portable library.
Completion credit: 0 goal percentage points (0.00 overall points).
Credit is earned only when every acceptance criterion and task-flow completion requirement passes.

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
  hashes are in [the work record](../WORK.md). All native exits report zero
  leaks. Exact published/extracted qualification remains; no model execution or
  musical acceptance follows these mechanical results.

- 2026-10-29, Big Boss: source inspection found identical periodic expressions
  in primary analysis/separation. The current grain Hann has a half-sample shift
  and is not an equivalent replacement. The linked candidate must consume the
  shared primitive; no generic window catalogue or inference framework is
  selected. New generated evidence stays under the project-owned E-drive roots.
