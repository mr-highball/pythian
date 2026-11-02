# NS-6_ci-consumer-fanout_01 — Finish all delivery checks without serial timeout

[Tasks](README.md) · [Styles](NS-5_instrumental-styles_01.md) · [Work](../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

CI563 passes the complete integration build in28m49s, then the extracted core
package, but its shared30minute job expires during WFC package verification.
This blocks the already implemented sound-tail correction and further review
delivery. Run independent integration and extracted-package checks in separate
jobs at the same source, retaining the existing30minute limit per job and every
consumer. Primary attribution: NS-6; these are delivery units, not musical value.

**Acceptance Criteria:**

- AC1: Complete integration and both extracted packages execute at the same
  pinned checkout in isolated jobs. Keep all commands, assertions, compiler
  options, source isolation, workflow permissions and30minute job limits.
- AC2: A complete published workflow passes both jobs and retains verified
  packages plus both sets of failure/consumer logs. Deployment requires success
  of the entire exact-source workflow; an early package artifact is insufficient.
- AC3: Verify downloaded package source identities/content and deliver the
  matching sound-tail runtime/UI through the existing fixed slot, preserving
  operator metadata and rollback. Retain CI563 and its partial package evidence.

**Blockers**

- [Native unit reuse — DONE](DONE/NS-6_native-reuse_01.md) — preserve its fresh
  option/source contexts; this failure does not demonstrate cache contamination.

**Dev Notes:**

- 2026-11-02, Big Boss: source8b9cc74, CI563/run41411531132 completes integration
  08:14:44–08:43:33 UTC. Extracted core124 owned units/138 hashes passes; the
  WFC package is cancelled at08:44:22 under the30minute job limit. Run conclusion
  is cancelled, not an assertion failure. E/runs/style-tail-ci563 retains the
  digest-checked logs and raw run logs. No package or deployment acceptance.
- Batch criterion: finish the actual complete delivery gate. Deliver separate
  unchanged native/package jobs; close with full exact-source CI, verified ZIPs
  and matching fixed-slot delivery. Stop at that gate or a distinct failure;
  do not change library algorithms, drop checks or extend the timeouts. Inherited
  nonclosing count1. Staged review source remains preserved on E while this real
  prerequisite is followed.
