# NS-6_studio_20 — Measured learning progress

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Show actual progress while Studio checks recordings, analyzes selections, learns
sounds and patterns, and generates music. Reuse portable learning callbacks and
one presentation vocabulary for audition jobs and live preparation.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional
points; repairs the already credited generation usability outcome.

Selected batch: Big Boss solo. Deliverable: measured callbacks, bounded status
publication and accessible step progress. Closing evidence: deterministic native
callback/worker checks and actual narrow/desktop Codex Browser QA on authored
data. Stop on changed learning results, false completion, unbounded event growth,
lost cancellation, or interruption of an operator job.

Accepted 2026-10-03 by Big Boss under the operator's solo UX instruction.
Win64 journal parity/cancellation and 164 worker checks pass. Actual Codex Browser
checks observe source bytes, analysis windows and learning passes on a ten-minute
authored recording, plus live-preparation cancellation and narrow/desktop layout.
Evidence: `build/studio-progress/QA-VERDICT.md`, logs, browser observations and
fourteen frozen artifacts. Matched stable delivery preserves all 3,957 existing
operator JSON/JSONL records. No musical or physical-phone verdict is inferred.

**Acceptance Criteria:**

- AC1: Portable journal learning reports pass-local completed observations;
  callbacks can cancel and do not change learned output. Analysis, verification
  and finite rendering report measured units. Unmeasured work stays indeterminate.
- AC2: Job history, selected job and live preparation share short step names.
  Current-step progress bars explain learning passes; reuse, waiting, failure and
  cancellation are distinct from successful completion. No fabricated overall ETA.
- AC3: Status writes are throttled while cancellation remains responsive. Tests
  cover cold learning, reuse, terminal states and callback/replay boundaries.
- AC4: Validate with isolated authored data, deploy matched fixed-slot artifacts
  without interrupting operator work, preserve records and close owned QA audio.

**Blockers**

- [Accepted native generation](NS-6_studio_02.md).
- [Accepted Studio tabs](NS-6_studio_18.md).

**Dev Notes:**

- 2026-10-03, Big Boss: worker currently emits `learn_wfc_model` as 0/1 across
  sequence learning, candidate selection, profile checks and publication. The UI
  cannot infer progress from that placeholder. Implement measurement in the
  primary journal reader, retain WFC independence, and label unmeasured phases.

- Big Boss: source hash reads, analysis batches, pass-local journal reads and
  finite render frames now provide measured checkpoints. Unknown model checks
  remain indeterminate. Publication is throttled to two updates/second inside
  a pass; boundaries publish immediately and all callbacks check cancellation.
- Shared Pascal UI uses six short steps, distinguishes saved-model reuse and
  terminal states, and puts the selected job above collapsed history. Learning
  passes explicitly reset their own bar; there is no overall guessed percentage.
- Repaired the library callback signature after compiler evidence showed that
  adding optional parameters still changes a Pascal method-pointer type. A
  bounded bridge keeps the existing library callback and the shared job publisher.
- The requested broader audit is owned by
  [observability_01](../NS-6_observability_01.md). No extra credit. Nonclosing count: 0.
