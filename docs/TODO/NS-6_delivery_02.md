# NS-6_delivery_02 — Verify clean native targets and remote CI

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Close the remaining clean-checkout and declared target/CI evidence with real runs of the supported project.

North star: NS-6. Outcome owner: WAV-05-DELIVERY.
Completion credit: 14 goal percentage points (0.70 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../PACKAGING.md) · [.github/workflows/native.yml](../../.github/workflows/native.yml) · [PROJECT](../../PROJECT.md).

Progress — 2026-09-20: [first remote checkpoint](../PACKAGING.md#first-remote-checkpoint)
passed at source `0ecfe34997bca5b16c9fb22282fc62b1df03a491`, including Ubuntu
24.04/FPC 3.2.2 integration and both extracted consumers. Remote artifacts are
bound to the run; their bytes/warnings have not been locally inspected because
unauthenticated download returned 401. The prerequisite and remaining declared
native-target/closure criteria still apply; this task remains TODO with no credit.

**Acceptance Criteria:**

- Obtain authorized source availability and a usable Linux runner; record any external availability blocker explicitly rather than treating a workflow file as a successful run.
- Run the maintained build and extracted core/companion consumer checks on Ubuntu 24.04/FPC 3.2.2 and the declared native Windows targets, with exact source and companion revisions.
- Verify clean-checkout dependency closure, portable core independence, notices and generated-file hygiene; retain compiler warnings, failures and resolutions.
- Complete a terminal successful remote CI run for the available current source and bind its logs/artifacts to that revision; local-only execution does not satisfy remote CI.
- Keep final accepted-workflow revalidation in the following package task so this infrastructure result need not wait for musical development.

**Blockers**

- [NS-6_delivery_01.md](DONE/NS-6_delivery_01.md)
