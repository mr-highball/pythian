# NS-5_scale_02 — Deliver recoverable incremental semantic corpus training

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Run many-hour multi-recording learning and repeated reuse within declared budgets, with recovery and bounded source/model ancestry.

North star: NS-5. Outcome owner: CORPUS-SCALE.
Completion credit: 6 goal percentage points (1.20 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md) · [WAVE-STYLE](../WAVE-STYLE.md).

**Acceptance Criteria:**

- Pass the declared end-to-end workload budgets with actual multi-recording training, including the semantic providers required by the chosen evaluation scope.
- Demonstrate interrupted/restarted equivalence, source/policy mismatch rejection and reusable completed caches; failures cannot silently publish a complete-looking learned result.
- Handle incremental additions without duplicate parent-range contributions or invented transitions across recordings, songs or unknown spans.
- Reconcile corpus growth and repeated blends with current source-count, ancestry-depth/node and model-state bounds (including 32 sources, depth 8, 63 nodes); implement justified bounded aggregation/compaction or explicit rejection with auditable contributions.
- Verify selective invalidation/retraining after vocabulary or admission-policy changes, retaining deterministic results and source/exposure lineage through saved reuse.

**Blockers**

- [NS-5_scale_01.md](NS-5_scale_01.md)
- [NS-5_vocabulary_02.md](NS-5_vocabulary_02.md)
- [NS-4_styles_02.md](NS-4_styles_02.md)
- [NS-3_notes_03.md](NS-3_notes_03.md)
- [NS-3_parts_03.md](NS-3_parts_03.md)
- [NS-3_harmony_01.md](NS-3_harmony_01.md)
- [NS-3_groove_01.md](NS-3_groove_01.md)
- [NS-3_timbre_02.md](NS-3_timbre_02.md)
