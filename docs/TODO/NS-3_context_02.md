# NS-3_context_02 — Persist automatic key and tempo context with overrides

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Complete reusable base context by combining independently admitted key and timing in the current saved context/style contracts.

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CONTEXT-PROFILES](../CONTEXT-PROFILES.md) · [WAVE-CONTEXT-ADMISSION](../WAVE-CONTEXT-ADMISSION.md) · [PERFORMANCE](../PERFORMANCE.md).

**Acceptance Criteria:**

- Create source-bound context profiles from accepted automatic local key and clock outputs; retain independent resolutions, gaps, changes and admission policies.
- Define unknown-tempo behavior explicitly through admission, persistence and generation; reject or expose unsupported rendering rather than silently treating unknown as a known BPM.
- Round-trip context and explicit caller overrides without losing measurement evidence or confusing selected values with inferred confidence.
- Demonstrate paired key/tempo edits and declared effects on new attacks, held notes and dependent layers, preserving unrelated accepted states.
- Pass a maintained native consumer on annotated changing-context recordings with accurate timing and practical cost.

**Blockers**

- [NS-3_context_01.md](NS-3_context_01.md)
- [NS-3_tempo_03.md](NS-3_tempo_03.md)

