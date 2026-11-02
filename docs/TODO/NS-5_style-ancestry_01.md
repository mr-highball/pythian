# NS-5_style-ancestry_01 — Keep edited styles usable through further blends

[Tasks](README.md) · [Parent styles](NS-5_instrumental-styles_01.md) · [Workflow](../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Dependency-blocked
**Owner:** Big Boss (single agent)

**Description:**

A real Studio style containing a sound edit and two passage-control edits already
has six retained nodes. Blending it with its original succeeds at eight; using
that result in a further blend fails the fixed eight-node limit. Current trees
also count shared ancestors repeatedly and repeat complete model/evidence bytes.
This blocks the intended edit → save → blend → further blend workflow.

Primary NS-5 attribution. Deliver a bounded, self-contained ancestry representation
that supports actual edited inputs and the complete supported corpus. Reuse the
primary style codec, validation, factories and native storage. A larger arbitrary
node count alone does not resolve repeated evidence/payload growth. Ordinary
blend selection UI and musical usefulness remain the parent task's outcomes.

**Acceptance Criteria:**

- AC1: The preserved six-node edited Studio artifact can be selectively blended
  with its original, saved/reloaded and used in a further blend. Partially shared
  ancestry, requested controls, independent sound choices and actual origins
  remain intact; source models and observation weights do not silently change.
  Native and actual JavaScript consumers perform the resulting mix/parts.
- AC2: Shared ancestor/model/evidence payloads are retained once rather than
  recursively copied for each path. The complete supported corpus can follow
  the same edited-style composition workflow within declared node/depth/byte/work
  budgets. Corrupt/dangling/cyclic references reject, cancellation publishes no
  partial style, and caller input owners may be freed before playback. Do not
  flatten history, silently discard parents or introduce external file lookup
  into the portable decoder.
- AC3: Ordinary native saved-style jobs use the same representation and retain
  source/answer lineage without relearning. Resource-limit errors identify an
  actual budget and useful next action. Relevant extracted consumers and full
  source qualification pass; this does not accept the parent blend UI or musical
  preference by itself.

**Blockers**

- [Scoped style controls](NS-4_scoped-style-controls_01.md) — actual edited input/policy consumer, qualification in progress.
- [Complete corpus persistence — DONE](DONE/NS-5_style-corpus-capacity_01.md).

**Dev Notes:**

- 2026-11-01, Big Boss: discovered while inspecting actual scoped Studio QA
  artifacts. The first saved passage style has four nodes; the further edit has
  six and retains both tick scopes. The primary API then creates an eight-node
  blend with its original and rejects its further blend with
  `Semantic blend exceeds eight retained ancestry nodes`. The exact artifacts,
  read-only Pascal consumer, hashes, clean heap and failure remain under
  E/runs/scoped-controls-qa01/ancestry-proof*. This is a demonstrated Pythian
  semantic-style capacity gap, not a generic WFC solver gap. Linked before
  expanding implementation; finish scoped-control qualification first. Six units
  grow current scope from198 to204 without accepting effort or resetting the
  nonclosing count. The parent keeps its original seven-unit estimate.
