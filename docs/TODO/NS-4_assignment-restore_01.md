# NS-4_assignment-restore_01 — Restore accepted graph ownership without solving again

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 3/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Preserve actual accepted graph assignments when a durable instrumental job is
reopened. Generated values must remain generated results, while real caller locks
stay locks. Setting public Entry.Value changes that ownership and blocks otherwise
valid regeneration. Add the generic non-solving contract in the separate WFC
repository; integrate it through the actual Pythian session consumers. Musical
codecs, sound recipes and Studio transport remain here. Primary attribution: NS-4.
This is a demonstrated prerequisite to graph controls, not another callback audit.

**Acceptance Criteria:**

- AC1: Generic WFC can capture and restore bounded assignments and their empty /
  generated / caller-lock ownership on a matching fresh graph without solving.
  Validate layout, values/domains and budgets before atomic publication. Observer
  cancellation and reentry cannot partially restore or change the source snapshot.
- AC2: Actual Pythian named-voice/layer restoration retains accepted models,
  tokens/states and controls. A restored session regenerates an authorized root
  with the existing solver while retaining unrelated accepted states; restoration
  itself does not learn or solve. Malformed snapshots fail visibly.
- AC3: Validate relevant native/actual pas2js contracts and consumers; preserve
  failure evidence and dependency notices. Link the separate branch/reviewed commit
  and explicitly update the gitlink after relevant upstream validation. Upstream
  success alone does not accept this downstream task or the parent musical outcome.

**Blockers**

- None. This blocks [graph controls](NS-4_graph-controls_01.md).

**Dev Notes:**

- 2026-10-30, Big Boss: Pinned WFC ownership-probe reproduces on a one-cell,
  two-value ordinary graph: original Generated=True; public-setter restoration
  Generated=False. The original accepts the opposite allowed value; the restored
  graph returns False because the value became a caller lock. This is independent
  of audio/music. Existing workspace journals replay history; no public ownership-
  preserving assignment restore exists at the accepted pin or local expansion.
  Source inspection confirms generated ownership is intentionally unit-private.
  Evidence: accepted-restore-20261030-boss under dedicated E-drive roots, including
  the Pascal probe/build/run with clean heap. The user has been informed before
  edits: separate branch codex/pythian-accepted-assignments from reviewed d4d30b1.
- Batch criterion/deliverable: faithfully reopen accepted musical state without
  re-solving it. Close this prerequisite with generic ownership tests and actual
  Pythian restored-regeneration consumers. Stop at that contract/integration, then
  return to durable instrumental sound follow-ups and the parent scope. Do not
  serialize pointer addresses, weaken caller locks or report replayed solving as
  state restoration. Carried consecutive nonclosing count is one; discovery or
  task creation does not reset it. No duplicate effort for the upstream branch.
