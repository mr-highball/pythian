# NS-5_evaluation_03 — Deliver reusable full-output listening packets

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Give Pascal producers a durable operator decision loop for complete source or
generated audio and fixed paired comparisons. This is a reusable listening
contract, separate from the source-frame annotation labels in
[NS-6_authoring_01](NS-6_authoring_01.md). It can carry whole-mix preference and
recording-correspondence questions for [NS-5_evaluation_01](NS-5_evaluation_01.md),
timestamped continuity observations for [NS-5_continuity_01](NS-5_continuity_01.md),
learned-versus-reference sound comparisons for [NS-3_timbre_02](NS-3_timbre_02.md),
synthesis-path observations for [NS-4_integration_01](NS-4_integration_01.md),
and the 120-second and paired style packet in
[NS-5_evaluation_02](NS-5_evaluation_02.md). Each owning task still supplies its
musical evidence and earns its own listening verdict.

North star: NS-5. Outcome owner: STYLE-EVAL.
Completion credit: 2 goal percentage points (0.40 overall points), reassigned
from the original 4 unearned NS-5 points of NS-5_evaluation_02. That task retains
2 points (0.40 overall); the combined allocation remains 4 points (0.80
overall). Credit is earned only when every acceptance criterion and the
task-flow completion requirements pass.

Starting evidence: the accepted Pascal reviewed-WAV catalog in
[NS-3_labeling_01](DONE/NS-3_labeling_01.md), the current source workbench,
and the fixed [style listening protocol](../CORPUS-EVALUATION.md#generation-controls-and-listening-packet).
The source workbench currently prepares bounded audio regions in memory and
records source-local label events; neither is a full-output listening response.

**Acceptance Criteria:**

- Define one versioned Pascal packet for a single complete asset or a fixed
  pair. Bind each request to a stable task/request ID, question, exact asset
  hashes and geometry, source or generated provenance, declared listening
  positions, finite answer choices and optional 0–3 rubric dimensions. Bind
  generated outputs to source/model/policy/parameter/split/seed identities where
  applicable. A correspondence packet must retain separately verified
  recording/edition/cut evidence; a listener's resemblance judgment alone is
  not an authenticated source match.
- Serve only packet-declared assets through bounded same-origin streaming with
  correct byte-range responses. Support continuous playback and seeking across
  the complete 120-second output and longer whole assets without allocating
  the entire WAV in server or browser memory. Reject stale hashes, undeclared
  paths, malformed ranges and unsupported media before presenting a review.
- Extend the Pascal/pas2js workbench with a simple single or paired listening
  flow: show task and asset identity, fixed listening plan, continuous playback,
  explicit finite choices, optional 0–3 trait scores, timestamped comments and
  unknown/uncertain answers. Keep choices unselected until the operator acts;
  playback alone is not a verdict. Preserve source-label authoring and its
  export bytes separately.
- Save one explicit, revision-checked listening event with request/packet hash,
  selected choices, score or unknown per declared dimension, asset-frame comment
  positions and decision status. Preserve pending/completed history, conflicts,
  failed Save and lost-response retry without duplicate events. Provide a
  Pascal producer report and deterministic export/re-import that return the
  actual reviewer response and asset ancestry; no signal metric or browser
  clock may manufacture a listening score.
- Pass focused checked Win32/Win64 Pascal validation and replay, including
  wrong-asset, changed-packet, invalid-vocabulary, range, revision and retry
  failures. Independently exercise real desktop and narrow-browser single,
  paired and complete 120-second playback, seek, comments, Save/reload and
  producer readback on isolated authored assets. This engineering QA may use
  declared test answers; it does not claim a real style, source-correspondence,
  continuity, timbre or synthesis listening verdict.

**Blockers**

- None. The reusable contract and authored QA assets are executable before the
  style-specific providers, personal reference judgments or physical-phone
  source-label check. Existing accepted catalog and native delivery are reused
  as starting evidence, not prerequisites to re-earn.

**Dev Notes:**

- 2026-09-28 task-flow split: source-local annotations cannot carry sustained
  generated-output or whole-mix decisions. NS-5_evaluation_02 owns actual
  style-specific comparisons and reviewer scores after this packet is accepted;
  this task owns only the reusable transport, decision, replay and worker-readback
  capability. No listening result or completion credit follows from creating
  the task.
