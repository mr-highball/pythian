# NS-3_context_03 — Qualify local-key and unknown reference intervals

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver a reusable, source-bound recorded reference packet for local key,
changes, no-key and ambiguous intervals before evaluating automatic admission.
Researcher whole-loop labels and score-level gaps alone cannot supply all of
these acoustic interval labels. This task owns reference qualification; the
key decision and its measured accuracy remain in
[NS-3_context_01](NS-3_context_01.md).

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Completion credit: 1 goal percentage point (0.25 overall points), split from
the original 4 points of NS-3_context_01. Credit is earned only when every
acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [local-key reference study](../TONAL.md#local-key-reference-candidate) ·
[authored negative screen](../TONAL.md#authored-tonal-negative-screen--2026-09-23) ·
[recorded percussion screen](../TONAL.md#percussion-only-recording-screen--2026-09-23) ·
[stopped loop qualification](../TONAL.md#loop-level-reference-qualification-stop--2026-09-23).

**Acceptance Criteria:**

- Bind accessible recorded audio, source editions, authors/performers, notices,
  licenses, exact bytes and annotation methods for at least two distinct tonal
  recording groups and two distinct no-key or ambiguous recording groups.
  Verify that each selected annotation refers to the acquired recording; a
  title, uploader tag, automatic pre-analysis or unverified score transfer is
  insufficient.
- Publish reviewed source-clock intervals for stable supported keys, genuine
  key changes and no-key/ambiguous regions. Retain alternate annotators,
  disagreements, transitional spans, timing uncertainty and unsupported modes.
  Do not relabel annotation gaps, percussion-only descriptions or a loop-level
  key as an expert local-key verdict without interval evidence.
- Freeze development and independent evaluation roles by recording/composition
  group before any admission scoring. Preserve source exposures and prevent a
  repeated performance, derivative or adjacent excerpt from crossing groups.
- Supply a Pascal reader/checker that reproduces interval and label boundaries,
  source identities, coordinate mappings and group isolation from the acquired
  assets. Keep media and generated output under ignored `build/`; tracked
  provenance and policy must allow another checkout to reacquire them.
- Show that the packet can score supported key, unknown and change behavior
  separately with coverage denominators. The packet itself selects no key
  algorithm or confidence threshold and earns no inference-accuracy credit.
- Complete the description's **acoustic no-key** coverage with reviewed,
  source-clock non-tonal intervals in at least one development and one
  independent recording/composition group. Bind each interval to the exact
  recorded audio and a time-local annotation/review method, preserve the same
  role isolation, and add a separate non-tonal false-admission denominator.
  A whole-track tag, percussion description, local-key annotation gap or
  classifier output alone cannot establish this reference truth.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-23 separate packet scorer: the [frozen policy and Pascal tool](../TONAL.md#separate-packet-denominators--2026-09-23)
  score supported-key frames, abstention on three-annotator conflict frames,
  and agreed changes with independent integer denominators. Four exact report
  hashes gate inputs. Stable checked Win32/Win64 source-free controls and
  synthetic all-unknown runs on all four original groups pass, including
  zero-denominator availability and source-frame conservation. Wrong-source,
  gap and unbound-report inputs reject; all checked runs have zero unfreed
  blocks. **Criterion 5 is met for the packet's annotated ambiguity target.**
  This closes a criterion after the previous qualification batch; no task
  credit moves because criterion 6, explicit from the task description and
  [downstream non-tonal requirement](NS-3_context_01.md), remains open.
  MTG-Jamendo's three-annotator tonal/atonal labels are whole-track labels,
  so they are a possible source screen, not accepted local no-key intervals.
- 2026-09-23 direct ambiguity qualification: the [exact audio-annotator
  conflict intervals](../TONAL.md#audio-annotator-conflict-intervals--2026-09-23)
  in D911-02 and D911-16 provide two distinct composition groups with all
  three source-matched audio labels present and discordant. Five half-open
  spans total 152,145 and 84,231 frames; a checked Pascal audit verified
  their labels/coordinates in byte-identical fresh development reports.
  This completes criteria 1 and 2 for the task's **ambiguous** alternative,
  alongside the already published stable supported keys and D911-16 change.
  It does not establish acoustic no-key truth. Criterion 5 alone remains open;
  no task or milestone credit changes.
- 2026-09-23 reserved interval replay: the [Pascal packet checker](../TONAL.md#reserved-interval-coordinate-replay--2026-09-23)
  now reads the two hash-bound evaluation WAV/annotation groups under the
  frozen roles and reproduces all source-frame label boundaries, coverage
  classes and score-ann2 mappings. D911-05 required an explicit 360-second
  bound; its 6,050,816-frame source and D911-19's 1,563,648-frame source pass.
  Evaluation reports are byte identical on stable checked Win32/Win64; the
  development refactor reproduces both prior reports byte for byte. All runs
  report zero unfreed blocks; occupied evaluation output rejects before writing.
  **Criterion 4 is met.** Unlabelled intervals
  remain unverified as no-key; the D911-19 disagreement is unresolved acoustic
  interpretation. Criterion 5's separate scoring denominators and the full
  task's no-key/ambiguous reference qualification remain open; no credit moves.
- 2026-09-23 reserved identity and role batch: [D911-05/19 original HU33
  entries](../TONAL.md#reserved-evaluation-identities--2026-09-23) were selected
  under a frozen ignored policy and extracted by checked Pascal code from the
  exact publisher archive. All 13 entry lengths and SHA-256 values were bound
  without parsing labels, decoding audio or running inference. The maintained
  Pascal checker enforces nonoverlapping whole-composition roles and distinct
  WAV identities; stable Win32/Win64 controls and evaluation verification pass
  with zero unfreed blocks. **Criterion 3 is met before admission scoring.**
  This closes a criterion after the prior nonclosing batch. Criteria 4's
  evaluation interval/coordinate reproduction and 5's separate coverage
  denominators remain open; no task or milestone credit changes.
- 2026-09-23 maintained reader batch: the [tracked Pascal checker](../TONAL.md#reproducible-pascal-reference-checker)
  now rebuilds the two development sources' complete annotation partitions
  and score-ann2 ambiguity transfer from exact original assets. Checked stable
  Win32/Win64 outputs and replay match byte for byte; the previous hash-bound
  partitions match, and one-byte source-notice corruption and occupied report
  names reject before output. The checker presently accepts only the two
  development compositions, so held-out group isolation and packet scoring
  denominators remain unverified. This is one nonclosing batch after criteria
  1/2 closure; criterion 4 and task credit remain open. Its Pascal selective
  extractor also verified the full publisher archive identity, all 13 chosen
  entry hashes and byte-identical reports from a fresh extraction.
- 2026-09-23 development interval packet: [two exact HU33 composition groups](../TONAL.md#bound-development-local-key-intervals--2026-09-23)
  now bind singer/pianist, composition, archive edition, notices, original WAV
  and all annotator/score CSV hashes and the publisher's transfer method.
  Both groups have tonal and ann2 score-transferred ambiguous intervals;
  D911-16 also has a unanimous D-minor to D-major change at frame 1,761,795.
  All selected stable, transitional, ambiguous and alternate-label spans are
  published. Checked Pascal QA verified current source bytes, 18 spans and
  source-clock partition coverage; the score/audio mapping replayed unchanged.
  **Criteria 1 and 2 are met for this development packet.** The reserved
  independent recordings have not been qualified or scored. Criteria 3–5
  remain open: enforce roles in a maintained Pascal packet checker, reacquire
  and bind independent groups, then show separate coverage denominators. No
  task credit is earned before the whole task passes.
- 2026-09-23 group-role freeze: [D911-05 and D911-19](../TONAL.md#local-key-reference-group-roles--2026-09-23)
  are reserved by entire composition for independent evaluation before their
  audio or local-key contents are opened. D911-02/16 remain development-exposed;
  all FSLD annotations were screened, so no FSLD loop is held out. Metadata
  supports a second distinct percussion capture but no timed no-key label.
  This is a second nonclosing packet batch: exact reserved source identities,
  reviewed interval packet and enforcing Pascal checker remain open. Stop
  further source screens at the task-flow reassessment checkpoint.
- 2026-09-23 development ambiguity qualification: a [frozen Pascal
  score/audio check](../TONAL.md#score-transferred-ambiguity-check--2026-09-23)
  matched the selected Winterreise ann2 score rows to their already bound HU33
  audio rows at one fixed transposition per composition. Three D911-02 and one
  D911-16 interior gaps map to exact source frames. By the publisher's ann2
  policy these are score-transferred ambiguous/no-key judgments, not verified
  acoustic non-tonality or consensus unknown. Ann1/ann3 labels and disagreements
  remain explicit. The selected sources are development-exposed; no held-out
  composition, key estimator or acceptance threshold was opened. This is one
  nonclosing batch after the reference split: the full positive/no-key/change
  source packet, independent groups and checker criteria remain open.
- 2026-09-23 split rationale: two nonclosing local-key batches exposed a
  distinct reference gap. One performed drum cadence has only source-level
  percussion description. A later frozen four-loop screen found multiple
  researcher labels and selectively extracted exact WAVs, but one intended
  positive's uploader filename claims a conflicting root; all loop labels are
  whole-clip, with automatic pre-analysis suggestions. The packet stopped
  before key scoring. See the [source record](../TONAL.md#loop-level-reference-qualification-stop--2026-09-23).
  This task owns the independently useful source/interval packet; context_01
  retains all decision, calibration, unknown-coverage and independent-accuracy
  obligations. Original unearned credit is redistributed 1+3, with no points
  earned by creating this task.
