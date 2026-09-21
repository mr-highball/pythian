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

The [fixed development worksheet](../PART-EVALUATION.md#development-annotation-worksheet--2026-09-21)
now passes export, full byte replay and preservation QA. It supplies exact derived
excerpts, complete descriptive amplitude grids and raw symbolic performance
evidence, with acoustic/role labels still unknown. The
[maintained reference builder](../PART-REFERENCE.md) also passes both checked native
targets and a file-bound scoring roundtrip, allowing reviewed intervals and
uncertainty to become consistent center references without duplicate manual entry.

The [mixture reference and admission policy](../PART-MIXTURE-POLICY.md) now freezes
the initial supported scope, required scenarios and existing per-role gates.
QA accepts its separation of reference preparation, uncertain challenges and
independent learner acceptance; the policy does not supply missing annotations.

Remaining acceptance: representative frozen recording families; role and
acoustic-timing annotations on the prepared sources; demonstrated supported
mixture/cohort coverage under the frozen policy. The
[fixed worksheet review](../PART-EVALUATION.md#fixed-worksheet-review--2026-09-21)
now identifies candidate score functions, silent material, gate overlap and
unmodeled performance messages. Next resolve acoustic support on the fixed passage
and document scenario gaps before binding annotations. MIDI gates and candidate
functions remain symbolic aids; no partial credit is awarded.

The subsequent [fixed acoustic review](../PART-EVALUATION.md#fixed-acoustic-support-review--2026-09-21)
passes diagnostic QA and supports primary bass/chordal source-function annotations
over 3.25–7 seconds. It also exposes sub-octave components relative to nominal keys
in two sources and retained energy after key-off. Resolve acoustic register,
registration/layer semantics and boundaries before binding note truth; do not
copy MIDI pitches or apply an automatic octave correction. Complete ensemble
annotations, external scenario coverage and frozen evaluation families remain open.

The [original-to-trigger comparison](../PART-EVALUATION.md#original-to-trigger-bass-correspondence--2026-09-21)
now binds seven exact bass-event correspondences. Five shift by 12 semitones and
two by 24 under the declared range-fold/shift rule. This resolves a source mapping
question while preserving original-key versus acoustic-register differences;
acoustic boundaries and the other contributors remain unresolved. Use the
[reference pitch contract](../PART-REFERENCE.md#pitch-identity-in-an-acoustic-reference)
before entering note labels. No generic MIDI correction or new task is introduced.

**Acceptance Criteria:**

- Acquire and bind usable WAV stems and corresponding mixes with verified recording identities, offsets, gains and role annotations; keep related stems/mixes in one split.
- Cover bass, chordal and lead/other supported roles, simultaneous notes, crossings, masking, rests and uncertain ownership rather than labeling stereo channels as voices.
- Implement independent per-role note, timing, coverage, leakage and crossing measures with annotation uncertainty and frozen development/evaluation groups.
- Declare supported mixtures and acceptance thresholds before inspecting evaluation predictions; harmonic/percussive separation is not an instrument or role label.
- Store assets/manifests under ignored build output and document generic WAV scope plus accurate required provenance; publish a reproducible native scoring packet.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
