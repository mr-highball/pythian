# NS-4_cell-priors_01 — Soft choice preferences at actual graph positions

[Tasks](../README.md) · [Musical form](../NS-5_musical-form_01.md) · [Workflow](../../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** Accepted — 2026-10-31
**Owner:** Big Boss (single agent)

**Description:**

Section density needs different positive rhythm-choice preferences inside one
bounded planning window, including future context/percussion choices that are
fixed before their section is performed. The previous WFC solver shared one
weight per value across all positions. Shortening the window loses known future
constraints; hard filtering or changing output volume does not implement the
existing soft musical-control contract.

Add the generic positioned-prior capability in the separate WFC repository,
then expose it through Pythian's primary sequence and voice preference adapters.
Primary NS-4 attribution. Six units estimate the additional solver, graph-input
and adapter integration, not Studio arrangement/density mapping already owned by
the eight-unit form task. No credit is earned by this assessment or reproduction.

**Acceptance Criteria:**

- AC1: Actual positions in one primary solve can have different positive soft
  choice weights. Selection, entropy, propagation/backtracking restoration and
  negotiation use the correct position's weights. Priors never relax hard
  domains, locks, paths or other constraints. Absent/neutral priors preserve
  existing deterministic default behavior.
- AC2: Provide bounded, detached, pass-scoped graph inputs with explicit
  validation, replacement/clear and lifecycle behavior. Reject invalid weights,
  coordinates, unknown values, unsafe arithmetic and mutation while running.
  Preserve accepted state and caller arrays on failure/cancellation. Retained
  assignment/input handling must not silently drop or reinterpret priors.
- AC3: Primary Pythian sequence and named-voice preference adapters consume
  positioned token preferences without modifying immutable source model weights
  or inventing latent keys. Demonstrate opposing preferences in a single bounded
  future-aware consumer, exact hard domains/frontiers, detached ownership,
  cancellation and native/actual pas2js replay.
- AC4: Implement generic behavior on the notified separate WFC branch, validate
  affected upstream native/pas2js/default consumers and CI, integrate its reviewed
  pin, and pass affected Pythian integration/extracted-consumer checks. Preserve
  core independence, licenses and the unrelated WFC checkout. No upstream merge,
  full musical-form acceptance or musical-quality verdict is implied.

**Blockers:**

- [Known future domains — DONE](NS-4_future-domains_01.md), reviewed base62c8597.

**Dev Notes:**

- 2026-10-31, Big Boss: AC1–AC4 are accepted at source72df5d3 after complete
  [Pythian CI537](https://github.com/mr-highball/pythian/actions/runs/41260246011)
  passes maintained integration and extracted core/WFC consumers. All five
  upstream CI64 jobs already pass. The fresh full Win64 ZIP verifies180 owned
  units and306 content hashes; its actual479-check consumer passes with a clean
  heap. Actual pas2js built solely from those extracted sources passes the same
  479 checks. Archive3ad94c6f and final receipts are in the dedicated
  `section-density-20261031-boss` packet. No source recordings, responses or
  private catalog data enter that source archive. Core-only consumer checks
  remain independent. No upstream branch was merged or vendor source edited.
  Six effort units close:105/146 (71.92%), six open,22 current DONE. This accepts
  actual graph/adapter capability, not section-density Studio mapping, full form,
  musical quality or universal style learning. Counter remains zero after its
  generic criteria closure. Return to the linked musical-form task.

- 2026-10-31, Big Boss: complete source72df5d3 is published on hello-pythian.
  [Native FPC CI537](https://github.com/mr-highball/pythian/actions/runs/41260246011)
  is running at that exact commit; all integration/extracted gates remain
  necessary before acceptance of the six units. The final local native/actual
  pas2js479 consumer and affected regression evidence are retained below.

- 2026-10-31, Big Boss: primary sequence segment/chunk and named-session
  consumers now use positioned public-token preferences. Local native/actual
  pas2js479 final checks pass with identical authored choices and a clean native heap:
  opposing positions, composition with global/existing weights, hard constraints,
  exact order-three frontiers, cancellation, detached arrays, accepted v2
  snapshots, selective regeneration and provider replacement. The shared mapper
  replaces the inferior named-voice weight loop and resolves only requested
  tokens for global preferences. The previous dense-vocabulary budget fixture
  therefore needed updating: sparse work now admits its real prefix; actual dense
  work still rejects at the unchanged limit and preserves prior output. Keep its
  original failed result. The legacy file-writing layer fixture is native-only;
  preserve its pas2js SaveToFile compilation rejection, not a claimed browser pass.
  Native layer/stream and native/pas2js shared-publication352890, named-publication
  407214 and accepted-snapshot15778 checks pass, with clean native heaps. Full
  downstream CI/extracted gates remain pending. Shared private planning hooks
  retain graph-owned rows without dangling scope owners. A real256-token sparse
  position case exposed unnecessary whole-vocabulary lookup; the primary selective
  mapper now resolves only the deduplicated requested-token union and admits the
  authored prefix at the unchanged budget. Preserve `position-sparse-js02` and
  the initial fixture type-import failure. Self-assigned nested copies detach.
  The first adapter fixture also used a nonexistent extent name and
  Generate on an already accepted session; corrected to the real extent and
  ordinary named regeneration. Both initial failures remain in the run packet.

- 2026-10-31, Big Boss: generic source448b2a3 is published on the notified
  separate `codex/pythian-cell-priors` branch; no merge or vendor edit. Actual
  native240 and pas2js276 new checks pass, including opposing priors, weighted
  entropy, restoration, inherited raw weights, hard constraints, retained inputs,
  cancellation and malformed host values. Native default741 and existing
  connectivity66 checks pass unchanged, with clean heaps. Full upstream CI64
  (41257225759) now passes all five jobs, including actual browser conformance.
  AC1/AC2's generic capability is delivered; downstream adapter/consumer
  acceptance remains open. Its reviewed448b2a3 pin is being integrated. Preserve the
  initial fixture declaration/private-method errors and pas2js chained-property
  syntax failure in `section-density-20261031-boss`; these were repaired locally.

- 2026-10-31, Big Boss: native and actual pas2js reproduce the domain-independent
  gap against the pinned primary numeric solver. Two unconstrained cells and
  two valid values with a deterministic middle ticket yield0,0 for global31:1
  and1,1 for global1:31. Requested independent rows31:1 and1:31 cannot be supplied:
  a four-entry row matrix rejects where a two-entry shared vector is required.
  This is a missing capability, not a defect in documented global weights or a
  musical contradiction. Native heap is clean. Preserve the initial fixture
  failure for omitted InitialFailureKinds and its corrected native/pas2js02
  results under `section-density-20261031-boss` in the dedicated E-drive roots.
- Separate local WFC `expansion`85d19fe has no positioned-prior implementation;
  its private attachments and existing worktrees are untouched. Notify the
  operator before edits on new branch `codex/pythian-cell-priors`, based on the
  reviewed pin. No dependency source is edited in Pythian's vendor checkout.
- Scope addition changes the denominator to146:99 accepted,47 open, seven open
  tasks and21 current-goal DONE (67.81%). Form's eight units remain unaccepted.
  Follow this actual density prerequisite while independent energy CI/stable
  integration remains pending; its reviewed WFC base is already accepted. The
  previous energy batch made progress; the carried
  consecutive nonclosing count remains one, not a new start.
