# NS-6_native-reuse_01 — Complete native qualification within its existing budget

[Tasks](README.md) · [Unguided form](NS-4_unguided-form_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 3/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Remove redundant complete recompilation between native consumers while retaining
fresh invocation state and isolated compiler-option contexts. Primary attribution:
NS-6. Actual CI546 passes the integration build in27m25s, then hits the existing
30-minute deadline during extracted-package qualification. This blocks the
instrumental repair's deployment. Keep the budget and all consumer checks.

**Acceptance Criteria:**

- AC1: A fresh unit context belongs to one build invocation, compiler target,
  code-generation/conditional options and source search scope. Reuse only inside
  that context. Checked/unoptimized, optimized and conditional-test units cannot
  contaminate each other; a subsequent invocation does not consume stale PPUs.
- AC2: Native build/package orchestration uses the shared context policy without
  dropping consumers, assertions or extracted-package isolation. Compiler errors
  remain failures. Verify actual repeated consumer builds and option separation.
- AC3: Complete maintained integration and extracted consumers pass in CI under
  the unchanged30-minute job limit. Preserve the original timeout and source/log
  identities. No acceptance follows from a partial or cancelled pipeline.

**Blockers**

- [Scalar fixture](NS-6_scalar-fixture_01.md) — the Windows full-build oracle
  constructs invalid expected bytes even under the original forced rebuild.

- The accepted upstream build-reuse procedure is precedent, not a new
  dependency-source change; this task owns Pythian's orchestration only.

**Dev Notes:**

- 2026-11-01, Big Boss: CI546/run41292465280 at75cdd0e is terminal cancelled,
  09:17:24–09:47:29 UTC. Integration passes09:17:40–09:45:05; package verification
  is cancelled at09:47:24 before completion. The remote branch still equals75cdd0e
  and no newer run supersedes it. Both build argument sets force `-B` for every
  program against persistent output directories. Select fresh per-invocation,
  option-separated unit reuse instead of extending time, dropping checks or
  rerunning unchanged. Current gate batch is nonclosing1; the earlier original
  musical AC1/AC2 closure remains recorded. Stop at complete consumer/CI proof or
  preserve a new distinct failure and reassess. Big Boss owns the repair solo.
- 2026-11-01, Big Boss: AC1 closes against the real compiler: compatible warm
  compilation reuses the unit; defines, optimization, ordered search paths and
  the input's automatic source directory remain isolated. A fresh invocation
  rebuilds even a changed/backdated source. Compiler failure and foreign source
  PPUs reject. This contract assumes fixed sources/compiler configuration inside
  the serial invocation, not a cross-run cache. All249 integration compile sites
  and20 package compile sites remain, plus their original target probes. Scripts
  parse. The extracted core package passes; full native/WFC checks and CI remain
  open. Evidence: E/native-reuse-20261101-boss. No completed effort is claimed.
