# NS-6_delivery_01 — Define the supported consumer and distribution contract

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Set the final library support, API-stability and distribution requirements so delivery can be independently evaluated without inventing a release platform.

North star: NS-6. Outcome owner: DELIVERY-RELEASE.
Completion credit: 8 goal percentage points (0.40 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../../PACKAGING.md) · [FUNDAMENTALS](../../FUNDAMENTALS.md) · [PROJECT](../../../PROJECT.md) · [PROVENANCE](../../PROVENANCE.md).

Completed 2026-09-20: [supported consumer contract](../../CONSUMER-CONTRACT.md)
defines the stable native target matrix and scoped development-compiler evidence,
core/companion subsets, source API and current-format policy, public entry points,
ownership/time/error/replay obligations and required external inputs. Its six-step
independent-consumer checklist covers clean extraction/build, admitted loading,
layer controls, generation, reload, selective blend and further blend. Distribution
remains the maintainer-selected development snapshots on `hello-pythian`, with
complete notices/provenance and explicit unsupported scope. Existing source
interfaces, package instructions and topic contracts supply reference evidence;
no algorithm, artifact format or executable example is added. Final package runs
and an actual independent verdict remain in delivery_03 and delivery_04. This
contract does not claim either result or authorize publication by itself.
Documentation validation: the existing native link checker passes all 36 local
links in the contract and this task with zero errors; `git diff --check` passes.
The source/API and evidence-scope review introduces no executable changes, so no
unrelated build or listening suite was repeated. Integration reviewed the listed
style constructors, copied session ownership, target evidence, package inventory
and maintainer-selected snapshot policy against source checkpoint `0ecfe34` and
its linked contracts. Accepted +8 NS-6 points (+0.40 overall), moving NS-6 from
50% to 58% and overall completion from 55.9% to 56.3%. The task is now in DONE;
navigation, the work record and completion ledgers are updated together.

**Acceptance Criteria:**

- Declare the supported native compiler/target matrix, core versus companion subsets, API stability expectations and one-current-format policy.
- Document public entry points, ownership, time units, bounds, errors, deterministic replay and required source/model assets for the intended learned workflow.
- Define an independent-consumer success checklist: install/unpack, build without workspace paths, load admitted learning, control layers, generate and reload/blend reproducibly.
- Record the maintainer-selected distribution/release policy and full license/provenance obligations; no publication, root commit or external messaging is authorized by this task alone.
- Explicitly separate supported native use from unclaimed browser/engine/device deadlines, universal codecs and ecosystem adoption.

**Blockers**

- None. This task has no prerequisite task files; external inputs or decisions in its acceptance criteria still apply.

**Dev Notes:**

No failed approaches or follow-ups recorded yet.
