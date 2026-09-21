# NS-3_timbre_02 — Accept recorded envelopes and sound reconstruction

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Complete the recorded sound outcome with reliable envelope/event mapping and paired audible reconstruction of evolving timbre.

North star: NS-3. Outcome owner: WAV-03-TIMBRE.
Completion credit: 3 goal percentage points (0.75 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAVE-STYLE](../WAVE-STYLE.md) · [INSTRUMENTS](../INSTRUMENTS.md) · [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md).

**Acceptance Criteria:**

- Admit supported attack/sustain/release envelopes with note-relative timing, gates, source silence and uncertainty; keep envelope choice independent of timbre choice.
- Meet frozen envelope/fit criteria on independent recorded cases and reject unsupported event assignments rather than substituting authored values as learned.
- Generate paired learned-versus-reference sound across declared pitches/dynamics and record actual listening observations on attacks, motion, releases and identity.
- Verify saved reload and controlled timbre/envelope edits preserve unrelated musical events and independent sound settings.
- Resolve demonstrated fit/admission defects here and renderer defects under synthesis-quality tasks, with linked evidence and no duplicate completion credit.

**Blockers**

- [NS-3_timbre_01.md](NS-3_timbre_01.md)
- [NS-2_synthesis-quality_01.md](NS-2_synthesis-quality_01.md)

