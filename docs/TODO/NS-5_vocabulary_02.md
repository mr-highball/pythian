# NS-5_vocabulary_02 — Support frozen vocabulary growth and explicit rebuilds

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-5)

**Description:**

Completion credit: 4 goal percentage points (0.80 overall points).
Current basis: [2026-09-29 outcome rebase](../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Execution status (2026-09-29): **Dependency-blocked**.
Next deliverable: Deliver incremental frozen-vocabulary additions and explicit rebuild behavior.
Closing evidence and stop condition: Deterministic addition/removal/overlap replay, stale-cache rejection and full affected-model rebinding. Stop if existing token meanings change implicitly.
Primary credit follows this task's north-star owner; downstream use earns no duplicate credit.
This reassessment closes no product criterion and preserves prior failures below.

Make incremental source additions reproducible without silently changing existing token meanings, weighting or evidence.

North star: NS-5. Outcome owner: WAV-04-VOCABULARY.
Historical allocation: 4 goal percentage points (0.80 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [CORPUS](../CORPUS.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md) · [CORPUS-EVALUATION](../CORPUS-EVALUATION.md).

**Acceptance Criteria:**

- Define when additions can use a frozen vocabulary and when coverage or schema changes require a rebuild; enforce measurable unknown/capacity limits.
- Demonstrate new recordings can be added without admitting evaluation observations into fitting or changing existing token identities implicitly.
- For required rebuilds, rebind affected models, source mappings, normalized representations and policies explicitly; reject stale caches/models/derived styles.
- Verify deterministic replay and auditable contribution accounting for additions, overlaps, removed/excluded ranges and repeated-source reuse.
- Keep one current contract per artifact and bounded failure behavior; historical format compatibility is not an alternative to an explicit rebuild policy.

**Blockers**

- [NS-5_vocabulary_01.md](NS-5_vocabulary_01.md)

**Dev Notes:**

No failed approaches or follow-ups recorded yet.
