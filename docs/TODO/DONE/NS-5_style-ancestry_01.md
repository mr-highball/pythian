# NS-5_style-ancestry_01 — Keep edited styles usable through further blends

[Tasks](../README.md) · [Parent styles](../NS-5_instrumental-styles_01.md) · [Workflow](../../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

A real Studio style containing a sound edit and two passage-control edits had
six retained nodes. Blending it with its original succeeded at eight; using
that result in a further blend failed the fixed eight-node limit. The old trees
also counted shared ancestors repeatedly and repeated complete model/evidence
bytes, blocking the intended edit → save → blend → further blend workflow.

The accepted V7 archive shares immutable nodes and payloads, retaining the actual
edited input through seven-node blend and eight-node reblend. Complete supported
corpus composition, bounded admission, cancellation and ordinary saved-style
generation pass. Old V4–V6 identities remain exact through bounded import.

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

- [Portable sample range — DONE](NS-1_portable-sample-range_01.md) — native/actual JS callers, complete CI561 and matching deployment pass.
- [Scoped style controls — DONE](NS-4_scoped-style-controls_01.md) — complete CI559, actual native/JS/Studio consumers and checked deployment.
- [Complete corpus persistence — DONE](NS-5_style-corpus-capacity_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: accepted; AC1/AC2 evidence below and AC3 now pass.
  Complete [CI561](https://github.com/mr-highball/pythian/actions/runs/41387074245)
  at0e16b99eb67a16267916656cdb325ff2d80687f2 passes integration and extracted
  core/WFC consumers. Both downloaded source ZIPs match their package digests.
  Complete Windows source06 heap-traced suite passes19,228,909 checks with zero unfreed blocks;
  final native08 repairs retain their targeted guard/callback checks.
  Actual JS full corpus passes2,690,223 and ordinary native jobs7,392,406.
  Desktop/390px Studio generates from the saved scoped style, retaining its exact
  archive identity, six parts and learning_performed=false; playback ends cleanly.
  Copied QA artifact/host-receipt relocation failures are preserved and repaired
  as fixture setup, without weakening product verification. Matching runtime02/
  web02 are deployed through the fixed stable slot with normal worker flags.
  LAN HTTPS and independent service lifetime pass; all23 jobs,3 clips and7,143
  existing metadata hashes remain unchanged. E/runs/ancestry-{ci561,qa01,release01}
  retain evidence. Six units close; ordinary selective blend UI and actual musical
  usefulness remain the [parent task](../NS-5_instrumental-styles_01.md).
  V7 bounds remain64 unique nodes/path64,32MiB archive/unique payload pool and
  explicit charged-work limits, not a claim of unlimited ancestry or process RAM.
  Preserve CI560's real callback failure, JS07/08/09 compile failures and the
  deliberately stopped superseded baselines; none is recast as a pass.

- 2026-11-01, Big Boss: AC2 mechanism now has complete native Linux and
  Windows normal-flag evidence (19,228,909 full instrumental checks each),
  actual JS06 full corpus (2,690,223), the same eight-node2,006,045-byte artifact
  6b775537 and detached mix/stems after freeing inputs. Native/actual JS08
  cancellation passes52,150 checks/52,041 callbacks, including final-node
  prepublication cancellation, exact exception identity, unchanged parents and
  retry. This closes AC2 evidence; AC3 complete source and deployed consumer
  still remain, with no task effort accepted. CI560 itself failed the missing
  common semantic_ancestry_node hook; the repair restores it and adds a late
  abort check without removing assertions. Its digest-verified logs are retained.
  JS07 separately exposed MaxSingle in the primary synth stream; the linked
  one-unit portable-range prerequisite owns that bounded repair. Native08
  affected guards/fixtures and actual JS08/portable-range-js10 consumers pass.
  Test-console StdErr/Halt assumptions are adapted to native stderr/portable
  WriteLn plus failure ExitCode, preserving every overflow assertion. No new
  algorithm or source-model changes are introduced.

- 2026-11-01, Big Boss: full-corpus JS04 baseline passes2,690,221 checks
  without reducing sources/rows; final native06 suite and actual JS06 corpus
  qualify the newer primary reader. Native ordinary jobs06 pass7,392,406 checks
  and clean heaps with locked originals/no learning. Core package06 verifies
  123 units/137 hashes. Preserve WFC package06 failure: a caller-codec fixture
  still expected6 parent occurrences instead of5 unique nodes. Only that
  expectation changes; registry admission/budget, lineage and audio checks
  remain. Fresh package07 and final corpus/source qualification are pending.
  No task effort is accepted or production data changed.

- 2026-11-01, Big Boss: AC1 closes on the actual preserved six-node Studio
  artifact through native and actual JavaScript mix/six-stem playback after
  freeing inputs:240,000 compared samples each, exact original/edited identities,
  first blend7 nodes/46,853 bytes/be2833f8 and further blend8/47,241/9bf4a338,
  exact intermediate parent and frozen models/scopes. Evidence:
  E/tests/ancestry-actual06. Native06/JS06 authored checks, immutable payload
  ownership,64/65-node boundary and no-relearning checks pass1,680,813 each.
  This real criterion resets nonclosing count1→0; no task effort is accepted.
  AC2 full-corpus and AC3 ordinary/source/extracted qualification remain.
  Native05 preserves an invalid new size-ratio assertion; real scopes/recipes
  cost bytes, so the repaired fixture checks exact shared storage directly.
  Current codec/learning separation and private immutable owner are implemented,
  not yet broadly qualified or deployed. The live corpus04 baselines remain
  valid work; snapshot06 also removes repeated structural-reader hashing.
  See [WORK](../../WORK.md) for exact handles and stop condition.

- 2026-11-01, Big Boss: corpus-focused actual JS now exposes a real prototype
  limit: the shared512MiB comparison budget is below the accumulated valid
  provider/ancestor validation work. Preserve ancestry-capacity-js03's terminal
  failure. After23 CPU minutes/~540MB on the same invalidated prototype, Big Boss
  stopped only the verified isolated native executable; its ownership/resource
  receipt and logs remain. This is not a native pass or a timeout-triggered retry.
  Do not reduce the corpus,
  drop evidence or treat this as musical rejection. Separate byte/preparation
  accounting from learning, preserve the existing per-provider producer capacities
  in the aggregate bound, and reuse already validated frozen models/evidence.
  The persistent immutable storage/cache repair above remains required. This is
  within AC2, not another ticket or accepted effort. This is one nonclosing batch;
  another requires reassessment before further implementation. No handoff or
  renamed storage experiment resets that count.

- 2026-11-01, Big Boss: first implementation slice repairs the preserved actual
  six-node input natively: first blend has7 unique nodes/46,853 bytes; further
  blend has8/47,241 bytes. Original V4–V6 identities, both scopes, frozen models
  and exact intermediate parent survive import/reload; heap is clean. The authored
  equivalent passes1,680,745 native/actual JS mix/six-stem checks after input
  owners are freed, with matching archive023fcb5d4864ce6d80927da0d8c729f50e6af24f179c29f5f7062e478d3efca7.
  Rehashed negative/forward/dangling references and cancellation reject. Generic
  style/blend and portable shared-work consumers pass. The prior codec-only
  extraction preserves all10 captured native fixture digests. Preserve native03's
  full-suite failure: an old tree-count assertion expected5 instead of4 unique
  nodes; current fixture is corrected, not broadly qualified. Corpus-focused
  native/JS consumers remain live; poll their retained exact handles.
  Evidence: E/tests/ancestry-codec-native01, ancestry-native02/03, ancestry-js03,
  ancestry-capacity-{native,js}03. No task effort is accepted or service changed.
  AC2 still needs persistent immutable payload sharing: current output pools
  repeated sections, but factory-owned definitions and per-encode hashing can
  repeat them in memory/work. Finish that primary ownership/cache binding and
  preserve the producer's existing per-model capacities when setting aggregate
  budgets. Ordinary native jobs and full source/extracted qualification remain.

- 2026-11-01, Big Boss: selected after the scoped task's actual closure;
  inherited nonclosing count0. Criterion: the preserved edited input and a complete
  supported corpus can blend, reload and blend again, retaining actual controls,
  sounds and source ancestry. Deliver the primary shared-node/payload archive
  through existing factories and ordinary saved-style jobs. Keep file hashes and
  parent identities truthful, bound unique nodes/depth/bytes/aggregate decoding
  work, and preserve current private artifacts through an explicit bounded import.
  Close with the actual failing input, native/actual JS mix/stem consumers,
  complete-corpus sharing, malformed-reference/cancellation checks, native jobs,
  relevant extracted packages and full source qualification. Stop at those gates
  or a demonstrated new prerequisite, before parent blend-selection UI. No credit
  follows from a serializer-only slice or a raised count ceiling.

- 2026-11-01, Big Boss: scoped controls now pass all qualification/deployment
  gates and are accepted. Both prerequisites are complete; this task is Ready.
  Read-only assessment confirms recursive parent bytes and archive-hash lineage
  are coupled. Sharing must preserve actual parent/model identities and bound
  aggregate decoding work; no implementation has begun or effort been accepted.

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
