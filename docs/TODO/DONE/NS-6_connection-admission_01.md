# NS-6_connection-admission_01 — Idle browser sockets cannot block Studio

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 2/10
**Status:** Accepted — 2026-11-01
**Owner:** Big Boss (single agent)

**Description:**

Repair the concrete refresh/reconnect prerequisite found during song/clip review.
The serialized server waits for first bytes on each accepted connection; browser
preconnections therefore delay unrelated requests. Primary attribution: NS-6.
Keep routing serialized and TLS/HTTP policies intact, with bounded admission.

**Acceptance Criteria:**

- AC1: Several idle connections cannot delay a ready Studio/session request until
  the browser times out. Accepted idle sockets have bounded count and expiry.
- AC2: Normal HTTP, configured HTTPS, native job reconnection/cancellation and
  actual desktop/phone-width browser paths continue to work. No new listeners, firewall
  approvals, certificate bypass or concurrent mutation of route state.
- AC3: Preserve the failing reproduction, exercise real socket admission through
  a maintained Pascal consumer, and verify service/process cleanup.

**Blockers**

- None. Required by [song management](NS-6_song-library_01.md) AC3–4.

**Dev Notes:**

- 2026-11-01, Big Boss: all criteria and prerequisites pass. Complete [CI540](https://github.com/mr-highball/pythian/actions/runs/41269241100)
  qualifies native backend8a88eac, including integration/extracted consumers.
  Full pas2js08 and actual desktop/390px consumers qualify browser3e42723.
  Fourteen deployed hashes match; native OS-trusted HTTPS133 passes with a clean
  heap. Native clip35/song10 (clean heaps) and HTTP admission103 retain their scoped
  evidence. Owned QA tabs/media and the QA service are closed. Existing operator
  projects, answers and recordings remain. Packet: studio-keep-20261031-boss on E.
  This accepts usability/storage/transport scope, not musical quality.

- 2026-10-31, Big Boss: bounded first-byte admission keeps32 raw sockets under
  the existing five-second deadline, then hands ready connections to unchanged
  serialized TLS/HTTP routing. The maintained Pascal client fails against the
  previous server, then passes103 checks against the repair: ready requests take
  15/16ms with4/40 idle sockets and expiry occurs without another request. Browser
  native Stop/reload, real generation and song save/reopen pass. HTTPS remains a
  final deployment check on the existing approved service. Automatic approval
  review rejected a new LAN QA bind without a reason; no bind/firewall/certificate
  change happened. The narrower loopback QA restart succeeded.
- 2026-10-31, Big Boss: isolated fixed-QA baseline responds200 in204ms. Four
  connected sockets sending no bytes make the next session request time out
  after8096ms. Evidence: studio-keep-20261031-boss/idle-before.json on E.
  This reproduces a server responsiveness defect, not a proven phone crash.
  Repair first-byte admission; do not add a broad observability/network audit.
