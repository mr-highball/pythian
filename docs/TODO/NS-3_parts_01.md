# NS-3_parts_01 — Prepare attributed stems and mixture evaluation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Create an executable evaluation packet for simultaneous notes and musical role ownership before developing mixture attribution.

North star: NS-3. Outcome owner: WAV-03-PARTS.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SEPARATION](../SEPARATION.md) · [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

Current increment: [simultaneous role-set evaluation](../PART-EVALUATION.md)
adds portable per-role pitch-set, leakage and crossing-endpoint measures plus
the existing source-bound operator path. Final checked stable Win32/Win64 QA
passes. The first external synthetic development preflight passes mechanical
checks but fails fixed stored-stem summation qualification: peak 13 LSB with
433 frames beyond the declared 11-LSB candidate bound. It remains diagnostic:
verified stem/mix preparation, actual role
annotations, interval timing, representative cases and frozen acceptance groups
are still required before this task earns credit.

Next increment: [overlapping-note timing](../OVERLAPPING-NOTES.md) implements
unrestricted per-role event assignment with separate onset/full-note errors and
explicit reference uncertainty. A small authored stem/mix packet exercises exact
stored-sample reconstruction, declared roles, masking, crossings and scripted
frame/event predictions. Final checked Win32/Win64 interval QA and native packet
verification/replay pass; see [controlled evidence](../PART-EVALUATION.md#authored-stem-mix-controls--2026-09-21).
Publishing the complete reproducible
packet and frozen representative evaluation groups remains part of this task;
scripted controls do not provide independent inference evidence.

**Acceptance Criteria:**

- Acquire and bind usable WAV stems and corresponding mixes with verified recording identities, offsets, gains and role annotations; keep related stems/mixes in one split.
- Cover bass, chordal and lead/other supported roles, simultaneous notes, crossings, masking, rests and uncertain ownership rather than labeling stereo channels as voices.
- Implement independent per-role note, timing, coverage, leakage and crossing measures with annotation uncertainty and frozen development/evaluation groups.
- Declare supported mixtures and acceptance thresholds before inspecting evaluation predictions; harmonic/percussive separation is not an instrument or role label.
- Store assets/manifests under ignored build output and document generic WAV scope plus accurate required provenance; publish a reproducible native scoring packet.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
