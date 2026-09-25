# NS-5_scale_02 — Deliver recoverable incremental semantic corpus training

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Run many-hour multi-recording learning and repeated reuse within declared budgets, with recovery and bounded source/model ancestry.

North star: NS-5. Outcome owner: CORPUS-SCALE.
Completion credit: 5 goal percentage points (1.00 overall points), after
assigning 1 of the original 6 unearned points to the independent
[admitted-event contribution journal](DONE/NS-5_scale_04.md). The original total
remains 6 NS-5 points / 1.20 overall points.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS-EVALUATION](../CORPUS-EVALUATION.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md) · [WAVE-STYLE](../WAVE-STYLE.md).

**Acceptance Criteria:**

- Pass the declared end-to-end workload budgets with actual multi-recording training, including the semantic providers required by the chosen evaluation scope.
- Demonstrate process interruption/restarted equivalence, source/policy mismatch rejection and reusable completed caches across the actual required semantic providers; failures cannot silently publish a complete-looking learned result. Consume the accepted source-bound contribution journal without counting its pitch-only replay twice.
- Handle incremental additions across the required semantic providers without duplicate parent-range contributions or invented transitions across recordings, songs or unknown spans. Preserve the accepted journal's source-bound pitch-duration behavior.
- Reconcile corpus growth and repeated blends with current source-count, ancestry-depth/node and model-state bounds (including 32 sources, depth 8, 63 nodes); implement justified bounded aggregation/compaction or explicit rejection with auditable contributions.
- Verify selective invalidation/retraining after vocabulary or admission-policy changes, retaining deterministic results and source/exposure lineage through saved reuse.

**Blockers**

- [NS-5_scale_01.md](NS-5_scale_01.md)
- [NS-5_scale_04.md — DONE](DONE/NS-5_scale_04.md)
- [NS-5_vocabulary_02.md](NS-5_vocabulary_02.md)
- [NS-4_styles_02.md](DONE/NS-4_styles_02.md)
- [NS-3_notes_03.md](NS-3_notes_03.md)
- [NS-3_parts_03.md](NS-3_parts_03.md)
- [NS-3_harmony_01.md](NS-3_harmony_01.md)
- [NS-3_groove_01.md](NS-3_groove_01.md)
- [NS-3_timbre_02.md](NS-3_timbre_02.md)

**Dev Notes:**

- 2026-09-25 task-flow split: the reusable, source-independent
  [admitted-event contribution journal](DONE/NS-5_scale_04.md) owns bounded
  pitch-duration append/idempotency/canonical reload and deterministic rebuild
  from original criteria 2 and 3. This task retains process-crash publication,
  reusable caches, every required semantic provider, many-hour budgets,
  ancestry bounds and policy/vocabulary invalidation. Original criteria 1,
  4 and 5 stay here; criteria 2 and 3 have the scoped journal prerequisite
  plus the full workflow checks here. The original +6 NS-5 / +1.20 overall
  unearned credit is redistributed +1/+5 NS-5 and +0.20/+1.00 overall;
  no credit follows from the split.

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

- 2026-09-23 preparatory publication repair: journal training, saved replay,
  blend and context attachment now require a fresh prefix, stage output in a
  reserved sibling directory and publish the report last. A caught publication
  failure attempts to remove only files moved by that invocation; a process interruption
  can leave visibly incomplete model/WAV or staging files for explicit recovery.
  A checked small WAV/cache fixture rejected existing and reserved prefixes
  without altering accepted bytes; fresh training from the same completed cache
  produced identical JSON/model/WAV on FPC 3.3.1 and 3.2.2 Win32, and replay
  matched the audition bytes. See [the publication contract](../ANALYSIS-WAVE.md#training-from-journals).
  Crash/restart equivalence, filesystem durability and the semantic workload
  remain unverified, so criterion 2 and task credit remain open. Continue via
  the semantic prerequisites, not more acoustic-only publication variants.

- 2026-09-23 same-batch repair: the fresh-prefix check initially ran only after
  training. It now runs before input loading in all four journal profile commands
  and again at publication. Stable FPC 3.2.2 compiled the change; existing
  outputs and occupied staging directories reject before an intentionally missing
  input is opened, while the accepted profile hashes remain unchanged. This
  prevents wasting a long run on an already occupied prefix; it does not change
  the open crash/restart or semantic acceptance boundaries above.
