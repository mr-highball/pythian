# NS-6_ci-headroom_01 — Complete native delivery with honest timeout headroom

[Tasks](../README.md) · [Recording ideas](NS-3_experimental-learning_01.md) · [Work](../../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** Accepted — 2026-11-02
**Owner:** Big Boss (single agent)

**Description:**

CI568's native integration step lasts29m56s, with setup and cleanup taking the
job past30minutes. GitHub marks the whole job cancelled despite successful step
labels. All three downloaded artifact digests verify, but this is not complete
delivery. Preserve that failure and give native CI40minutes of bounded resource
headroom. Package CI retains30minutes. Keep every consumer, assertion, compiler
option and isolated context; add an unmistakable final build-completion marker.
This explicitly changes the CI565 task's historical30minute native resource
constraint after a demonstrated later timeout; it changes no musical criterion.
Primary attribution: NS-6, required delivery repair, not musical quality.

Accepted2026-11-02: complete CI569 succeeds at de3f185, including the final
completion marker and both extracted packages. All three artifact digests and
138/320 package content hashes verify. The same native implementation, with a
separately qualified pas2js handoff repair, is delivered through the existing
stable slot with rollback and all7,312 existing metadata hashes unchanged.

**Acceptance Criteria:**

- AC1: Native CI keeps all existing commands/checks and uses40minutes; packages
  keep30minutes. Emit completion only after the entire maintained build finishes.
  A cancelled/partial workflow remains a failed delivery gate, regardless of
  individual green steps or available artifacts.
- AC2: The full exact-source workflow passes native and extracted packages, with
  the completion marker and verified source/package identities. Deliver the
  matching recording-ideas runtime/UI through the fixed slot, preserving existing
  operator data and rollback. Preserve CI568 as cancelled evidence.

**Blockers**

- [Complete CI fanout — DONE](NS-6_ci-consumer-fanout_01.md): retain independent
  package qualification and all checks; no further orchestration split is needed
  to change this resource budget.

**Dev Notes:**

- 2026-11-02, Big Boss: AC1/AC2 pass. CI569 native125321864413 completes
  14:05:47–14:29:55 UTC, packages12532186458514:06:00–14:07:56, both successful.
  The final marker is present; all three artifact digests and both package source/
  content manifests verify. The unchanged native code and separately tested
  web09 handoff repair are live at PID67772 with rollback and all7,312 prior
  metadata hashes unchanged. All12 assets, HTTPS, worker availability and exited
  launcher verify; no QA listener/browser/audio remains. CI568's cancelled run,
  annotation and logs stay preserved. The prepared release's positional
  Select-String mistake was repaired before any service stop. Source identities
  and the focus-dependent UI failure remain explicit. Accept one delivery unit;
  no musical preference or native CI coverage of pas2js presentation is implied.

- 2026-11-02, Big Boss: source de3f185 is pushed with native40minutes and an
  explicit full-build completion marker checked by the workflow. Parse and
  command-inventory comparison pass: no existing build command changes. CI569
  is running; packages pass, native and deployment remain pending. Recording-
  ideas native/UI code and checked bytes remain c8443e0. This is the same active
  batch with count1, not an acceptance or another nonclosing batch.

- 2026-11-02, Big Boss: recording-ideas batch stops at this actual prerequisite;
  consecutive nonclosing count0→1. Its native59/110, project128, actual pas2js
  16/67/1439 and desktop/390px consumers pass; eight units remain open. The new
  one-unit task grows total effort216→217; accepted remains177. No local result
  or cancelled CI is presented as complete-source success.
- Next batch criterion: complete unchanged delivery checks without a deadline
  cancellation. Deliver native40minute headroom and a final completion marker.
  Evidence: complete exact-source CI, verified packages and matched deployment.
  Stop there or on a distinct actual failure; carry count1. A second nonclosing
  batch requires reassessment before another attempt, not another automatic limit
  increase. Private evidence: E/runs/recording-ideas-ci, including the GitHub
  annotation explicitly identifying the30minute limit and digest-checked logs.
