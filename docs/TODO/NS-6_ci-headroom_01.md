# NS-6_ci-headroom_01 — Complete native delivery with honest timeout headroom

[Tasks](README.md) · [Recording ideas](NS-3_experimental-learning_01.md) · [Work](../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** In progress
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

- [Complete CI fanout — DONE](DONE/NS-6_ci-consumer-fanout_01.md): retain independent
  package qualification and all checks; no further orchestration split is needed
  to change this resource budget.

**Dev Notes:**

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
