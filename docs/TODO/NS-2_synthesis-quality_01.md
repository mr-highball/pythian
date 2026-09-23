# NS-2_synthesis-quality_01 — Accept source and articulation quality

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-2)

**Description:**

Accept the audible behavior of the supported oscillator, wavetable, sample and measured-instrument paths. Existing numerical checks are baseline evidence; use their auditions and the supplied listener preview to identify concrete source/articulation defects.

North star: NS-2. Outcome owner: FUND-QUALITY.
Completion credit: 8 goal percentage points (2.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md) · [FUNDAMENTALS](../FUNDAMENTALS.md) · [SOURCES](../SOURCES.md) · [INSTRUMENTS](../INSTRUMENTS.md).

**Acceptance Criteria:**

- Define a finite listening matrix covering the supported source families, sampled pitch/velocity/rate ranges, short and long gates, attacks, releases and sample-loop exits; map it to existing artifacts before creating new renders.
- Record actual timestamped listening observations and a verdict for each covered family, including clicks, unwanted aliasing, pitch continuity and release behavior. A waveform metric or silence from the reviewer is not approval.
- Resolve demonstrated defects within this scope and attach before/after auditions plus the relevant signal, boundary and deterministic-replay evidence; if none are found, record that outcome.
- State the accepted operating ranges and remaining unsupported cases explicitly. Do not claim realistic instruments, arbitrary automation or universal alias freedom.
- Retain source/parameter/output identities and link the acceptance record from SYNTHESIS-QUALITY.md; all criteria and TASKFLOW completion requirements are satisfied.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

- Follow-up: reuse the existing source auditions and [paired preview](../SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20) to complete the finite listening matrix. Family-specific feedback remains pending; no audible defect or broad approval is inferred from numerical checks or the whole-preview verdict.
- 2026-09-22 batch: completed the first acceptance criterion by mapping a finite matrix to existing generated WAVs and recording local SHA-256 identities where available in [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01). No additional renders were created. Closing evidence for this criterion is the documented mapping of oscillator/wavetable/sample/measured paths and sampled pitch, velocity, rate, gate, attack, release and loop-exit cases. Stop here: actual listening and timestamped family verdicts remain open because listening was unavailable during this handoff; no quality result is inferred.
- 2026-09-23 listener checkpoint: the user confirmed hearing the complete, hash-identified [30-second paired preview](../SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20) and called it coherent overall. This is a whole-piece observation for the two measured-performance excerpts, not the required family-specific timestamped verdict on clicks, aliasing, pitch continuity and release. Those checks, defect disposition and operating-range acceptance remain open; no credit changes.
