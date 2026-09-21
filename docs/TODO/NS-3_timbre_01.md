# NS-3_timbre_01 — Admit evolving sound across pitch and dynamics

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Extend existing stationary/trajectory fitting into reliable recorded evolving sound, separating pitch movement, role leakage and true timbral change.

North star: NS-3. Outcome owner: WAV-03-TIMBRE.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SOURCES](../SOURCES.md) · [WAVE-STYLE](../WAVE-STYLE.md) · [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md).

**Acceptance Criteria:**

- Declare supported pitch/dynamic/role conditions, fit-error and unknown/rejection limits, with source-bound note-relative windows and phase policy.
- Use accepted event fundamentals and mixture ownership to distinguish changing pitch from changing spectral shape; retain original measurements and rejected fits.
- Pass controlled and separate-recording admission/fit comparisons across the declared pitch and dynamic range, including weak fundamentals and unsupported fits.
- Retain source, phase, normalization and measurement-policy identity through saved evidence; no plausible sounding fit may conceal an inaccurate admission.
- Expose the accepted evolving-sound provider through maintained native interfaces within declared memory/time limits.

**Blockers**

- [NS-3_notes_03.md](NS-3_notes_03.md)
- [NS-3_parts_03.md](NS-3_parts_03.md)

**Dev Notes:**

- Existing limitation: centered pitch support improved controlled glide fits but did not resolve recorded register ambiguity; the recorded A trajectory still missed the fixed fit-residual gate. A low harmonic residual can support the wrong octave. See [centered measurement](../PITCH.md#centered-timbre-measurement-checkpoint--2026-09-19).

- Follow-up: use accepted event fundamentals and role ownership to distinguish pitch motion from changing sound. Do not admit an attractive reconstruction by loosening fit thresholds.
