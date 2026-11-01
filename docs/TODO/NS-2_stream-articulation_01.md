# NS-2_stream-articulation_01 — Explicit note articulation in persistent synthesis

[Tasks](README.md) · [Studio consolidation](NS-6_generation-unification_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 4/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Extend the primary Pascal stream and decision journal with an explicit supported
articulation contract. Primary attribution: NS-2. Finite note shortening uses a
known complete note length; an open generated hold has no such length yet.
Preserve that distinction instead of silently treating a cell as a whole note.
This is the actual prerequisite to removing Studio's finite performance path.

**Acceptance Criteria:**

- AC1: Define and implement bounded note-gate decisions for supported streamed
  generation. Explain how a complete duration becomes known before shortening
  its gate, including holds across planning prefixes. Reject unsupported unknown
  spans explicitly; do not silently truncate, reinterpret or buffer whole tracks.
- AC2: The primary portable scheduler/performance and versioned decision journal
  preserve exact release timing, neutral replay, rest/hold behavior, tail state,
  ownership and cancellation. Saved decisions replay actual gates without solving.
- AC3: Native/actual pas2js consumers demonstrate shorter articulation and neutral
  output. Ordinary saved Studio controls keep their intended audible effect when
  the linked consolidation removes the finite path. Complete relevant checks pass.

**Blockers**

- [Retained decisions — DONE](DONE/NS-4_decision-replay_01.md)
- [Musical controls — DONE](DONE/NS-4_graph-controls_01.md)

**Dev Notes:**

- 2026-11-01, Big Boss: consolidation candidate01 completes ordinary four-second
  generation, replay and hard-pitch/strength changes, then the existing saved
  75%-gate experiment fails. Both the decision validator and primary stream
  deliberately require100% gate for unknown held-note spans; journal v2 stores
  velocity only. Preserve this correct rejection. The full candidate/hashes,
  native clean-heap failure and actual pas2js rejection remain under the E-drive
  projected-domains packet. Counter2 triggered reassessment; consolidation is
  stopped before deployment. Restore its unpublished attempt, fix the independent
  finite context-mask collision for current musical qualification, and select
  this prerequisite explicitly before another consolidation attempt.
