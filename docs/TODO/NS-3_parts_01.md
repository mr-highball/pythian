# NS-3_parts_01 — Prepare attributed stems and mixture evaluation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Create an executable evaluation packet for simultaneous notes and musical role ownership before developing mixture attribution.

North star: NS-3. Outcome owner: WAV-03-PARTS.
Completion credit: 2 goal percentage points (0.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SEPARATION](../SEPARATION.md) · [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

Delivered components: [simultaneous role-set measures](../PART-EVALUATION.md),
[overlapping-note timing with source-bound file integration](../OVERLAPPING-NOTES.md#file-bound-role-timing)
and a [maintained reproducible control packet](../PART-EVALUATION.md#maintained-packet-operator).
Checked stable Win32/Win64 scoring QA passes; native packet reconstruction,
scripted frame/event controls, byte replay and overwrite preservation pass.
These implement diagnostic measurement and authored controls, not independent
mixture inference.

The [derived external development packet](../PART-EVALUATION.md#derived-external-development-packet--2026-09-21)
also passes every-frame scaled-stem and exact mix verification, byte replay and
preservation checks. It provides usable, separately identified reference audio
with explicit gain/quantization and unchanged sample coordinates. The original
publisher mix's 13-LSB residual/failed 11-LSB bound remains unqualified. A
prospective second recording reservation passes identity checks but remains
provisional; differing hashes do not prove unrelated families.

Remaining acceptance: representative frozen recording families; role and
acoustic-timing annotations on the prepared sources; supported mixture/cohort
coverage and its frozen acceptance thresholds. Next prepare the fixed 30-second
development worksheet across all stems, preserving symbolic performance events
separately from measured acoustic support. No partial credit is awarded.

**Acceptance Criteria:**

- Acquire and bind usable WAV stems and corresponding mixes with verified recording identities, offsets, gains and role annotations; keep related stems/mixes in one split.
- Cover bass, chordal and lead/other supported roles, simultaneous notes, crossings, masking, rests and uncertain ownership rather than labeling stereo channels as voices.
- Implement independent per-role note, timing, coverage, leakage and crossing measures with annotation uncertainty and frozen development/evaluation groups.
- Declare supported mixtures and acceptance thresholds before inspecting evaluation predictions; harmonic/percussive separation is not an instrument or role label.
- Store assets/manifests under ignored build output and document generic WAV scope plus accurate required provenance; publish a reproducible native scoring packet.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
