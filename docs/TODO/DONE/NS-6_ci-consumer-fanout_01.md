# NS-6_ci-consumer-fanout_01 — Finish all delivery checks without serial timeout

[Tasks](../README.md) · [Styles](../NS-5_instrumental-styles_01.md) · [Work](../../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** Accepted — 2026-11-02
**Owner:** Big Boss (single agent)

**Description:**

CI563 passes the complete integration build in28m49s, then the extracted core
package, but its shared30minute job expires during WFC package verification.
This blocked the already implemented sound-tail correction and further review
delivery. Independent integration and extracted-package checks now run in
separate jobs at the same source, retaining30minutes per job and every consumer.
Primary attribution: NS-6; these are delivery units, not musical value.

Accepted source07c78d7 passes complete CI565: integration23m50s and both extracted
packages2m19s run independently. Downloaded artifact digests and all138/320
core/WFC content hashes match. The matching checked sound-tail runtime/UI is
deployed in the fixed stable slot with rollback and all7,143 existing metadata
files unchanged. E/runs/style-tail-ci565 and style-tail-release565 retain the
complete proof. No musical usefulness or parent style acceptance is inferred.

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

- [Native unit reuse — DONE](NS-6_native-reuse_01.md) — preserve its fresh
  option/source contexts; this failure does not demonstrate cache contamination.

**Dev Notes:**

- 2026-11-02, Big Boss: AC1–AC3 pass at
  [CI565](https://github.com/mr-highball/pythian/actions/runs/41416642216), source
  07c78d72902f839e2e95754ba9c468d7a3503972. Whole-workflow success, both jobs,
  package provenance and every content member are checked before deployment.
  All671 frozen inputs/416 native inputs match the checked8b9cc74 runtime; no
  unnecessary rebuild or changed code-generation options. Live PID43596 survives
  its exited hidden launcher. HTTPS serves11 exact static assets plus the
  intentionally rendered phone template. All23 jobs/3 clips/zero named styles
  and7,143 existing metadata hashes remain unchanged. No QA service/worker/audio
  remains. This real delivery closure resets count2→0 and accepts only two units.

- 2026-11-02, Big Boss: CI564/source a21e43d exposes a fresh-checkout setup
  defect: package log redirection fails before the first consumer because build
  is absent. Exact job125180334054/logs are retained under E/runs/style-tail-ci564.
  Explicit directory creation repairs the orchestration boundary. Counter2
  triggers reassessment: stop unrelated scope; verify that boundary and finish
  this same complete gate. No inferred musical failure or accepted effort.

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
