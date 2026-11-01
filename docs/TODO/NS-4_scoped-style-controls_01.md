# NS-4_scoped-style-controls_01 — Preserve time-scoped controls in reusable styles

[Tasks](README.md) · [Styles](NS-5_instrumental-styles_01.md) · [Workflow](../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 4/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Keep a passage's soft musical preferences and hard limits at their actual times
when saving/reusing a style and editing its score again. Existing positioned WFC
priors work, but semantic styles retain only provider-wide preferences and sparse
token locks; the retained editor does not consume that complete style policy.
Turning an excerpt's preference into a global weight or treating its generated
notes as new learned evidence would change the operator's meaning.

Primary NS-4 attribution. This is the serialized style/editor consumer gap,
distinct from the accepted generic positioned-prior solver. Native and pas2js
reuse the same primary domain/preference implementation; no new solver or blanket
inference benchmark is required. Sound-recipe-only saving can proceed separately.

**Acceptance Criteria:**

- AC1: A bounded, detached, serializable control recipe retains actual provider
  identity, musical time scope, separate positive preferences and hard domains.
  Source models, observed corpus, vocabulary and parent evidence stay immutable.
  Reject incompatible clocks, unknown tokens, conflicting hard inputs and invalid
  scope explicitly; do not silently globalize or drop controls.
- AC2: Initial streamed synthesis, retained passage edits and style reload use
  the same policy at actual positions, including lookahead and seams. Other
  providers/positions keep their policy, and preferences never relax hard locks.
  A changed requested duration has a declared scope policy rather than modulo
  repetition or truncation disguised as an unchanged recipe.
- AC3: Ordinary Studio can save/reuse a passage's requested controls as a style
  derivation with actual origins. An audition's stochastic notes remain a score,
  not automatic training or invented locks. Native and actual JS consumers plus
  a Studio Before/After check preserve lineage, cancellation and unrelated parts.

**Blockers**

- [Positioned priors — DONE](DONE/NS-4_cell-priors_01.md).
- [Graph controls — DONE](DONE/NS-4_graph-controls_01.md).
- [Instrumental streams — DONE](DONE/NS-6_instrumental-streams_01.md).

**Dev Notes:**

- 2026-11-01, Big Boss: found while connecting the parent style task's edited
  performance capture. `TSemanticProvider.Preferences` is global; the existing
  passage request is time-scoped. The primary retained-editor signatures also
  lack the complete saved provider policy. Reuse existing positioned priors,
  sparse constraints and primary stream/edit paths. This is a real note-style
  prerequisite, not a blocker to naming/reusing existing styles or saving sound
  recipes. No generic WFC gap is demonstrated. Adding four units grows scope;
  it earns no effort or nonclosing-counter reset.
