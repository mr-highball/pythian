# NS-4_scoped-style-controls_01 — Preserve time-scoped controls in reusable styles

[Tasks](../README.md) · [Styles](../NS-5_instrumental-styles_01.md) · [Workflow](../../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 4/10
**Status:** Accepted — 2026-11-01
**Owner:** Big Boss (single agent)

**Description:**

Keep a passage's soft musical preferences and hard limits at their actual times
when saving/reusing a style and editing its score again. Before this change,
semantic styles retained only provider-wide preferences and sparse token locks;
the retained editor did not consume that complete style policy.
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

- [Positioned priors — DONE](NS-4_cell-priors_01.md).
- [Graph controls — DONE](NS-4_graph-controls_01.md).
- [Instrumental streams — DONE](NS-6_instrumental-streams_01.md).

**Dev Notes:**

- 2026-11-01, Big Boss: all criteria and prerequisites pass. Exact source
  bcf98d9c8bd49660ec65fe131f3312b62d80a53f passes complete
  [CI559](https://github.com/mr-highball/pythian/actions/runs/41368598698), including
  maintained integration and clean extracted core/WFC consumers (123/187 owned
  units; 137/317 content hashes). Downloaded artifacts match GitHub digests and
  both contained source ZIPs match their checked package logs. The previously
  qualified native/actual JS/Studio consumers exercise the actual policy path.
  Checked server, worker and 12 matching browser assets are deployed in the
  existing fixed slot. HTTPS, worker availability, all 23 saved jobs, 3 clips
  and 7,143 existing metadata hashes pass unchanged. Post-deployment desktop/
  390px reconnect, clip discovery and style guidance pass; 11 media elements are
  paused, owned tab14 is closed and viewport reset. QA service remains stopped.
  Evidence: E/runs/scoped-controls-qa01/{ci559,release01,deployed-browser-smoke.json}
  plus the native/JS packets below. Four effort units close; consecutive
  nonclosing count resets from2 to0 through this real closure. Musical usefulness
  and the separate ancestry/blend interface are not accepted by persistence.

- 2026-11-01, Big Boss: final frozen source passes complete native and actual
  JavaScript instrumental consumers (15,867,347 checks each), native playlist
  (7,392,406), generic styles/blends, retained editor (1,533) and native progress
  (43,584 checks/43,478 callbacks). Native heaps are clean. Preserve scope-n04's
  missing-example-fixture compile failure; scope-n04-extra01 adds those unchanged
  fixture inputs and passes the remaining consumers. Actual 390px Studio saves
  the passage style, reuses it at four seconds, edits another passage and restores
  the exact job. Primary inspection finds both scopes and unchanged learned models;
  no different-note fixture outcome is claimed as musical usefulness. All QA
  media are paused, its tab/service closed and the operator service/data unchanged.
  Publication/full-source qualification remain required before acceptance.
  The demonstrated six-node style → eight-node blend → rejected further blend
  is linked separately as [style ancestry](NS-5_style-ancestry_01.md); it does not
  invalidate scope save/reuse/edit or authorize unrelated implementation here.

- 2026-11-01, Big Boss: the shared policy and ordinary capture/reuse paths are
  implemented; acceptance remains pending full qualification. Primary scope
  checks now pass 3,025,506 actual JavaScript checks, including exact reload,
  soft/hard scope, immutable learning, provider-order binding, longer/shorter
  clocks, cancellation, further blends and retained partial/all-part edits with
  a drum lock. Scope identity is2e5c5b506c9a32df344d5b2f2907c638188654fafad0227a37fdccf877ccc147.
  Earlier native snapshot passes 1,008,570 scope checks and 7,392,406 actual
  playlist checks, including named passage-style reuse at a longer duration,
  independent mix/six-stem replay and unchanged models. Current frozen-source
  native qualification and isolated actual Studio QA are in progress; no task
  effort or counter reset yet. E/tests/scoped-policy-js06, scope-n03/scope-n04
  and E/runs/scoped-controls-qa01 retain source manifests and evidence.
  Preserve native01's missing internal declarations, native02's compile invalidated
  by a concurrent source edit, and JS01/02/03's fixture import, expected exception
  type and omitted byte-stream budget failures. Native03/04 use isolated frozen
  source copies so later work cannot invalidate a running compilation. The shared
  context projection replaces the old local implementation; no generic WFC gap
  or dependency edit is demonstrated.

- 2026-11-01, Big Boss: selected after the recorded two-batch reassessment.
  Criterion: a requested passage control can be saved as a style, reused and
  edited again without changing its scope or frozen learning. Deliver one
  detached provider/tick policy shared by initial streams and retained edits,
  its primary archive binding and ordinary Studio capture. Close with native
  and actual JavaScript position/seam/lock/reload/cancellation consumers, an
  actual Studio note-edit save/use flow and complete source qualification.
  Shorter performances reject scopes they cannot contain; longer performances
  extend the baseline without looping the control. Stop at a demonstrated
  prerequisite or these criteria, before unrelated blend UI. CI558 remains
  live for the preceding sound variant; do not cancel it with a new push.
  The inherited count remains 2 until a real criterion closes.

- 2026-11-01, Big Boss: found while connecting the parent style task's edited
  performance capture. `TSemanticProvider.Preferences` is global; the existing
  passage request is time-scoped. The primary retained-editor signatures also
  lack the complete saved provider policy. Reuse existing positioned priors,
  sparse constraints and primary stream/edit paths. This is a real note-style
  prerequisite, not a blocker to naming/reusing existing styles or saving sound
  recipes. No generic WFC gap is demonstrated. Adding four units grows scope;
  it earns no effort or nonclosing-counter reset.
