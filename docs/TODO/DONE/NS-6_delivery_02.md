# NS-6_delivery_02 — Verify clean native targets and remote CI

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Close the remaining clean-checkout and declared target/CI evidence with real runs of the supported project.

North star: NS-6. Outcome owner: WAV-05-DELIVERY.
Completion credit: 14 goal percentage points (0.70 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../../PACKAGING.md) · [.github/workflows/native.yml](../../../.github/workflows/native.yml) · [PROJECT](../../../PROJECT.md).

Progress — 2026-09-20: [first remote checkpoint](../../PACKAGING.md#first-remote-checkpoint)
passed at source `0ecfe34997bca5b16c9fb22282fc62b1df03a491`, including Ubuntu
24.04/FPC 3.2.2 integration and both extracted consumers. Remote artifacts are
bound to the run; their bytes/warnings have not been locally inspected because
unauthenticated download returned 401.

Completion evidence prepared — 2026-09-20:
[frozen native checkpoint](../../NATIVE-CHECKPOINT.md) records clean detached source
`0ecfe34997bca5b16c9fb22282fc62b1df03a491`, exact publicly fetched WFC/Athena pins,
and first-run terminal success for the full maintained FPC 3.2.2 Win32 and Win64
builds plus all four freshly extracted core/companion consumer packages. Each
core closure contains 85 owned units; each companion closure contains 111 owned
units. ZIP inventories, hashes, complete notice/provenance identity, clean final
checkout/submodule status and generated-file hygiene are verified. Retained
Windows warnings originate in WFC/RTL, with no owned-source warning found. Logs,
package identities and remote run/artifact bindings are retained under ignored
`build/native-checkpoint-0ecfe34/`. The Linux artifact-content inspection limit
above remains explicit. The later active working tree is not covered by this
frozen run; final accepted-workflow revalidation remains delivery_03. The
completion review and accounting are recorded below.
Documentation validation: the existing native link checker passes 17 local links
across the checkpoint and task, and `git diff --check` passes. No additional suite
was started after collecting the required target/package evidence.

Completed 2026-09-21: final review checked all five criteria against terminal
results, actual retained ZIP hashes, inventories, dependency closure, notices and
remote run/artifact bindings. The declared native infrastructure scope passes;
no musical, listening or independent-use verdict is inferred. Accepted +14 NS-6
points (+0.70 overall), moving NS-6 from 58% to 72% and overall from 56.3% to
57.0%. Final accepted-workflow revalidation remains delivery_03. This task's
move, incoming links and completion ledgers are updated together.

**Acceptance Criteria:**

- Obtain authorized source availability and a usable Linux runner; record any external availability blocker explicitly rather than treating a workflow file as a successful run.
- Run the maintained build and extracted core/companion consumer checks on Ubuntu 24.04/FPC 3.2.2 and the declared native Windows targets, with exact source and companion revisions.
- Verify clean-checkout dependency closure, portable core independence, notices and generated-file hygiene; retain compiler warnings, failures and resolutions.
- Complete a terminal successful remote CI run for the available current source and bind its logs/artifacts to that revision; local-only execution does not satisfy remote CI.
- Keep final accepted-workflow revalidation in the following package task so this infrastructure result need not wait for musical development.

**Blockers**

- [NS-6_delivery_01.md](NS-6_delivery_01.md)

**Dev Notes:**

- Retained evidence limit: remote CI passed at the frozen source, but unauthenticated artifact download returned 401, so Linux artifact bytes/warnings were not locally inspected. Windows package inventories and extracted consumers were verified; see [native checkpoint](../../NATIVE-CHECKPOINT.md).

- Follow-up: [final workflow delivery](../NS-6_delivery_03.md) must qualify the later accepted source and complete workflow; this checkpoint does not cover subsequent changes.
