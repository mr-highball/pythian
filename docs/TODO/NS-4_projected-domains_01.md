# NS-4_projected-domains_01 — Use known musical domains before choosing source passes

[Active tasks](README.md) · [Composition](NS-4_context-composition_01.md) · [Unguided form](NS-4_unguided-form_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Add bounded domain propagation for declared sequence projections so upstream
source choices can use known downstream restrictions before whole assignments
are rejected. Primary attribution: NS-4. Current negotiated passes correctly
report a search limit, but can spend that limit on source assignments already
excluded by a known target domain. This prevents the required retained-part form
experiment from completing. Reuse primary WFC propagation/state algorithms;
musical codecs and synthesis stay in Pythian. This extends the composition API's
search preparation, rather than replacing its graph, proof or stream engine.

**Acceptance Criteria:**

- AC1: The maintained upstream-only 64-cell `a`/`b` reproduction uses its known
  target support before source assignment. The formerly failing free case solves
  and independently proves with the same models, seed1704297163 and256/16 search
  limits. The existing explicit feasible witness remains valid.
- AC2: Shared primary logic propagates sound supported domains across declared
  projected relations and relevant sequence/boundary restrictions. Preserve
  admissible states, hard caller masks, actual latent histories, independent
  proof, ownership and cancellation. Do not add local Pythian support filters or
  a second propagation algorithm when the primary solver already owns one.
- AC3: The primary bounded stream sees full-window future restrictions before
  choosing upstream sources. Commit only the published shared prefix. Preserve
  explicit weights as preferences, trace/replay contracts and the unselected
  legacy path; never silently retry seeds, bind free voices or raise budgets.
  Report honest scope/limits for unsupported relation forms.
- AC4: Native/actual pas2js, relevant upstream CI and affected Pythian/extracted
  consumers pass at an explicit reviewed gitlink. The linked unguided task owns
  the full192-cell six-part musical render and ordinary Studio acceptance; no
  musical-quality credit follows solely from the generic preparation step.

**Blockers**

- [Verified shared composition](NS-4_context-composition_01.md) — repaired source
  80772b6 passes upstream CI66; downstream pin/frame-consumer qualification remains.

**Dev Notes:**

- 2026-11-01, Big Boss SOLO: the actual shared instrumental candidate passes its
  guided48-second/six-part control on native and actual pas2js, digest
  b6796894ad28666fb455d48a8c9224bc00cb284db6abc077cc9a07bd84750ece.
  Free generation still exhausts16 pass retries at cell64/lead pass4 on both
  targets, with unchanged192cells, sixteen-cell prefixes and256lookahead.
  Stop condition reached: no further model variants. The entire candidate,
  corrected performed-cell regression, source hashes and patch are preserved in
  the E `unguided-joint-20261101-boss/candidate01` packet. Patch SHA
  dfed7ddd9df8e303c4fcc19ccdb10bcce3fdb4245e413769d7b087437e2a581a.
- A separate WFC-only64cell probe on80772b6 uses a memoryless `a`/`b` source,
  constant C harmony/rhythm/voice models and a declared C-to-`a` relation. The
  free graph reaches status3/retries16/target0; the same graph with its known
  feasible source domain proves all64cells with zero retries. Heap is clean.
  This is a missing preparation capability, not an incorrect claim of unlimited
  bounded-search feasibility. The primary numeric solver has private
  InitializeDomains/Propagate operations but exposes only complete solve; inspect
  reuse/extraction there before implementing. Source/logs are retained in the
  same E packet. No Pythian unit is involved in this reproduction.
- The operator was informed before new upstream edits: use separate new branch
  `codex/pythian-projected-domains` from80772b6, preserving the original D-drive
  expansion checkout and the existing composition branch. Six units reflect
  primary propagation, shared-window/ownership and cross-target integration
  uncertainty. No acceptance or counter reset follows from task creation.
