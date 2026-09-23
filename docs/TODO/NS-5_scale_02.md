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
- [NS-4_styles_02.md](DONE/NS-4_styles_02.md)
- [NS-3_notes_03.md](NS-3_notes_03.md)
- [NS-3_parts_03.md](NS-3_parts_03.md)
- [NS-3_harmony_01.md](NS-3_harmony_01.md)
- [NS-3_groove_01.md](NS-3_groove_01.md)
- [NS-3_timbre_02.md](NS-3_timbre_02.md)

**Dev Notes:**

- 2026-09-22 development input: three user-selected full mixes have more than
  32 declared chapters each. Current `pythian.learn journals` and the saved
  acoustic profile treat each range as a source, with a 32-source cap. A full
  boundary-safe learning run therefore needs bounded segment-to-source
  accounting and a replayable contribution map; increasing the limit alone is
  not an accepted fix. Exact source identities stay in ignored local records.
  This is already covered by the song-boundary and bounded-aggregation criteria
  above; no new task or completion credit is added.

- 2026-09-23 preparatory acoustic capacity: the journal profile now retains
  up to 4096 disjoint range rows while enforcing 32 unique physical WAV digests
  and the existing 65536 candidate-slot budget. Repeated WAV/cache pairs reuse
  verified handles; saved blend/reblend coalesces exact rows and preserves their
  multiplicities. A checked 33-range fixture and private 44/42/68-range full-mix
  development runs, each with a shared frozen vocabulary for multi-recording
  blends, passed. The three-profile blend has 154 distinct range rows; a further
  blend increases weighted samples without duplicating those rows. Saved
  three-source replay verified its explicit source bytes and rendered without
  caches or relearning. See the
  [work record](../WORK.md#bounded-full-mix-acoustic-learning--2026-09-23).
  This is acoustic mechanism evidence only. The semantic providers, independently
  verified song/unknown boundaries, recovery, selective invalidation and final
  workload budgets remain open; no criterion or credit is closed here.
