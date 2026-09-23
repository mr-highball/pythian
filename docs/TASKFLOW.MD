# Task flow

[Milestones](MILESTONES.md) · [Open tasks](TODO/README.md) ·
[Done tasks](TODO/DONE/README.md) · [Work record](WORK.md)

## Scope and source of truth

Apply Athena's [shared Task flow standard](../vendor/athena/docs/task-flow.md).
This file records Pythian's adopted paths, scope, acceptance allocation and
user-directed execution choices; the shared standard owns the general lifecycle.

The north-star goals and completion totals live in [MILESTONES.md](MILESTONES.md).
Individual task files in `docs/TODO/` own the remaining implementation and
acceptance criteria. Accepted tasks move to `docs/TODO/DONE/`. The
[task index](TODO/README.md) maps all tasks and credits to the north stars.
Topic documents hold supporting contracts/evidence; they are not another active
backlog. Historical “remaining” statements do not reopen a completed task without
checking the current evidence.

The initial catalog contained 49 open tasks and earned no completion credit.
On 2026-09-20 the user authorized execution, starting with the least-complete
north star (NS-5 at 25%). Follow actual prerequisite tasks when blocked, including
prerequisites in another north star, then return to the originating task.

The 2026-09-23 user clarification puts reusable core behavior ahead of the three
personal style tests. Continue to use their full mixes as development inputs,
but do not make a genre label or those recordings a prerequisite for the core's
basic function. Where a style-reference task needs detailed listening, defer it
after an honest checkpoint and work a ready core prerequisite. Invite the user
at substantial playable or design checkpoints, not for routine annotation.

NS-1's accepted extraction/independence baseline is already complete. Do not
manufacture historical DONE files or repeat completed work to populate folders.
Core independence, Pascal ownership, retained WFC boundaries, complete notices,
deterministic behavior and one current format per artifact remain invariants of
every applicable task. Review [PROJECT.md](../PROJECT.md) and Athena as required
by [AGENTS.md](../AGENTS.md).

## Naming and template

Use `NS-<goal>_<feature>_<xx>.md`, for example
`NS-3_notes_01.md`, `NS-3_notes_02.md`, `NS-3_notes_03.md`.
`NS-<goal>` refers to the exact north-star ID in the scorecard. Feature names use
lowercase words separated by hyphens. Use the same feature base for related
tasks and increment the two-digit suffix; use more digits after 99. Do not
reuse a number or renumber existing files after tasks move to DONE. The suffix
identifies a task, not a format version or an implicit prerequisite.

Every task uses this template. Additional evidence details belong within these
sections or in linked topic records, not in a second competing task definition.

```markdown
# NS-N_feature_01 — Concrete outcome

<Relative links to the task index, task flow and owning north-star anchor>

**Description:**

High-level outcome, present gap, and scope boundary.

North star: NS-N. Outcome owner: existing milestone outcome or an explicit new owner.
Completion credit: X goal percentage points (Y overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: links to current contracts, code or evidence.

**Acceptance Criteria:**

- Observable result, supported cases and independently checkable pass condition.
- Relevant failure/unknown, ownership, replay and integration requirements.
- Evidence needed to accept the result, including actual listening when applicable.

**Blockers**

- <Relative Markdown link to the prerequisite task file>

**Dev Notes:**

- <Dated failed approach or possible follow-up, with evidence and current disposition>
```

If no task prerequisite exists, use one bullet saying `None` and explain that
external inputs/decisions in the acceptance criteria still apply. Link directly
to task files, never just a milestone name. Keep filenames unchanged in DONE.
When a task moves, update its navigation/evidence links for the new directory.

Every task, including tasks in DONE, ends with **Dev Notes:**. Use this section
for approaches that did not work, repaired implementation issues worth retaining,
and possible follow-ups. State what was attempted, what the evidence showed and
whether the approach is stopped, repaired or still a candidate. Link detailed
evidence and any existing task that owns a follow-up; do not duplicate full logs.
If nothing is recorded, write `No failed approaches or follow-ups recorded yet.`
This means no notes have been recorded, not proof that every approach succeeded.

Keep acceptance evidence in Description and actual prerequisites in Blockers.
Dev Notes are not additional acceptance criteria or implicit dependencies, and
a possible follow-up does not authorize restarting a stopped investigation.
If a note reveals required work outside the current task, use the gap process
below to create/link its task immediately. Keep unresolved acceptance failures
open; notes cannot hide a blocker, reset investigation counters or grant credit.
Retain and update Dev Notes when a task moves to DONE.

## Select and execute

1. Read the selected task, its current topic evidence and the work record. Check
   that each file under **Blockers** is accepted in DONE. A draft implementation,
   a passing isolated test or an active task does not satisfy a blocker.
2. Select one current task under the prioritized outcome package. Being ready
   is not by itself a reason to switch to a convenient infrastructure task.
   Record external needs such as listening judgments, verified sources, a runner
   or independently reproduced use explicitly; do not invent approval or results.
3. Define the next observable result and reuse existing verified tools/evidence.
   Keep one primary agent. Implement maintained behavior in Pascal and use
   proportional validation of the changed boundary and consumer.
4. For inference experiments, declare the hypothesis, fixed evaluation policy,
   cost budget and stop/switch condition before scoring. Stop the same-cause
   experiment after 20 unsuccessful attempts. Diagnose why the approach has
   failed before authorizing any new hypothesis; a renamed or retuned variant
   does not reset the count. Protect untouched evaluation material. The
   20-attempt cap is the user's later 2026-09-22 project instruction; record
   each attempt and its discriminating result so this cannot become a cyclic
   search.
5. Keep accepted baseline behavior available. Compile/test/render passes do not
   imply musical, listening, genre or independent-consumer acceptance. Avoid
   repeated broad test/package refreshes until material changes require them.

Blockers are true prerequisites to executing the task's deliverable, not merely
related work. Put nonblocking coordination in the description or acceptance
criteria. Splitting preparation from acceptance is preferable to creating cycles
or requiring every downstream acceptance before useful upstream work can begin.
The index's dependency order is a valid order, not a requirement to serialize
every unrelated task or expand staffing.

## Task size and investigation stop points

Apply Athena's [task-size and progress checkpoints](../vendor/athena/docs/task-flow.md#task-size-and-progress-checkpoints),
now included in the merged shared standard. The following records this project's
adopted stop points and evidence expectations.

Before starting a work batch, name the task acceptance criterion it advances,
the concrete deliverable, the evidence that will close that criterion, and the
stop/switch condition. Prefer a usable API, integrated consumer, reference packet
or accepted result. A diagnostic is justified by the specific decision it must
resolve; writing another tool or collecting another report is not the outcome.

A batch is a bounded implementation/investigation deliverable and its handoff,
not an individual tool call. Track the count in the work record across turns,
agent handoffs and context changes; those transitions do not reset it.

After **two consecutive work batches without closing an acceptance criterion**,
stop the current investigation sequence and reassess before authorizing another
batch. Record the two results, why acceptance did not advance, and one of these
next actions in WORK.md and the owning task:

- Finish a bounded deliverable using the existing evidence and tools, with its
  remaining acceptance checks named explicitly.
- Split an oversized task into independently useful, verifiable deliverables.
  Map every original criterion to its new owner, preserve true dependencies,
  redistribute only the original unearned credit, and update the catalog and
  milestones in the same change. QA must assess any completed portion against
  its complete criteria before it moves to DONE.
- Follow a concrete prerequisite or record an external blocker and its unblock
  condition. Preserve failures and uncertainty; do not silently replace the goal
  with a smaller passing claim.

The reassessment must change the next action. Rephrasing the same investigation,
adding a diagnostic-only task, changing the tested window or renaming a failed
hypothesis does not reset the checkpoint. A further experiment needs a genuinely
different, evidence-backed decision path, a fixed budget and an explicit result
that will end it. Apply the 20-unsuccessful-attempt rule as well; neither
rule authorizes indefinite variations on a failed approach.

Split at deliverable boundaries, not by coding steps, agent assignments or number
of reports. Do not weaken acceptance, hide missing cases, create baseline-history
tasks or award points for analysis merely to make DONE activity visible. A scored
measurement API and a qualified external reference packet can be separate
deliverables; a new plot and its summary normally cannot. If research reveals a
distinct required capability, use the gap process below and return to the current
agreed scope.

At each batch handoff record criteria closed, criteria still open, current stop
point and next deliverable. Before starting another batch, check whether the
task remains consumable. Milestone progress must reflect accepted capability;
long-running research is reported honestly rather than becoming an endless
sequence of nominal progress updates. This checkpoint applies immediately to
active work, including investigations already underway.

## Discover a gap without losing the current task

When a gap requires another task, **stop the scope expansion immediately,
create the new task file using this template, then return to finish the current
task**. Do not silently add an indefinite investigation to the current task.

- Give the gap a concrete outcome, acceptance criteria, north-star owner,
  completion allocation and the next unused feature suffix.
- Add it to the index and milestone mapping immediately. Update affected tasks
  with their actual prerequisite links; do not create dependency cycles.
- If the new gap is follow-up work, keep it out of the current task's blockers
  and complete the current agreed scope.
- If it is genuinely necessary for the current acceptance criteria, add the new
  file to the current task's blockers and leave the current task open. Finish any
  independent current work, then resolve the prerequisite in dependency order.
  Do not mark a task DONE merely to follow the instruction to finish it.
- If a task's criteria were missed after closure, either reopen that task or
  create a clearly distinct follow-up and reassess the credited capability.

The initial list is exhaustive for the presently declared end state, not a claim
that development can reveal no new requirement. Unsupported browser/device APIs,
arbitrary codecs, every synthesis technique and universal transcription are not
automatically gaps. A new requirement needs a concrete connection to the goal.

## Complete, move and update percentages

A task is complete only when **all** its acceptance criteria pass and every
blocker is accepted. Add a dated completion-evidence paragraph under Description
with source/artifact identities, commands/targets, relevant results, real review
verdicts and limitations. Link detailed evidence instead of copying logs into
the task. Implementation/API tasks must be in maintained code and their intended
consumer; an ignored study alone is not delivery. Planning/protocol tasks must
meet their specified reference/executable checks, not just have prose written.

In the same logical completion change:

1. Move the task from `docs/TODO/` to `docs/TODO/DONE/` without changing its basename.
2. Update incoming blocker/index/milestone links and the moved task's relative
   navigation/evidence links. Keep completed prerequisite links as historical
   evidence; do not erase why a task was blocked.
3. Update the index's open/DONE state and the milestone outcome mapping, remove
   completed work from the active queue, and update the north-star percentages.
4. Record the accepted result, changed blocker and next outcome in WORK.md.
5. Check local links, prerequisites and credit arithmetic. Do not run unrelated
   algorithm suites for the documentation move.

The accepted baseline at this catalog's creation is:

| Goal | Baseline completion | Overall weight | Task points remaining within goal |
| --- | ---: | ---: | ---: |
| NS-1 | 100% | 10 | 0 |
| NS-2 | 80% | 25 | 20 |
| NS-3 | 30% | 25 | 70 |
| NS-4 | 70% | 15 | 30 |
| NS-5 | 25% | 20 | 75 |
| NS-6 | 50% | 5 | 50 |

`Goal completion = baseline + sum(accepted DONE task credits for that goal)`.
`Overall completion = sum(goal completion * goal weight / 100)`.
For example, accepting `NS-3_notes_01` adds 4 points within NS-3 and 1 overall
point. Record the arithmetic on every completion; keep the overall ledger at
55.5 until an actual task closes. These allocations are transparent planning
judgments about scope, not measured engineering precision or effort estimates.

Task credits, not file counts, drive completion. Partial implementation,
experiments, more tests, hours collected and this initial task authoring earn no
automatic credit. Do not retroactively apply the new credits to capability
already included in the baseline. A completed parent outcome earns no extra
points on top of its tasks.

When splitting or adding work within the same scope, redistribute only unearned
credit and record the old/new allocation so the goal still totals 100. Never
create free percentage points by adding files. A genuine scope expansion or
disproved accepted capability requires an explicit baseline/scope reassessment
in MILESTONES.md, with rationale and unchanged historical evidence. Moving a
reopened task back to TODO removes its accepted credit; recalculate all totals.
No task may close with an unspecified allocation or unsupported completion claim.

Group execution into meaningful outcome packages, normally at least ten overall
points as requested; individual tasks may be smaller. This is a planning rule,
not permission to inflate credit or postpone updates until a giant milestone
finishes. No final 100% claim is valid while any required task or acceptance
evidence remains unresolved.

## Delegated validation and publication

The user-authorized implementation helper may delegate small, noncritical or
routine subtasks to one junior helper. Only that implementation helper assigns
the junior's work. Give each assignment concrete acceptance criteria and isolated
file ownership; keep it independent of work underway elsewhere. The junior follows
the same project standards and task flow, reports through its delegator, and may
not delegate further. The user has lifted the implementation helper's task-count
cap; keep assignment history without treating it as a stopping limit. Respect
the execution environment's concurrency limits; authorization alone does not
create an available worker slot.

Under the user's current delegation, final validation belongs to the QA agent.
Start a fresh QA batch when at least two tasks are ready and combine relevant
checks. Completion-document follow-ups remain part of that same batch. The QA
agent may create task files for discovered gaps or deferred bugs; the primary
agent integrates dependencies and accounting. A defect that violates current
acceptance criteria still blocks acceptance.

Track failed QA submissions separately for each delegated task. A submission
fails when QA reports a blocking defect in its implementation or required
acceptance evidence. Multiple findings or target failures in the same submission
count as one failed submission; repeating an unchanged failure does not create
another attempt. Runner outages and other failures unrelated to the submitted
work do not count as implementation failures.

After the **twentieth failed QA submission for the same task**, stop helper
resubmissions and diagnose the repeated failure. Remove that task from the
implementation helper's queue and transfer it, its existing code and all failure
evidence to the primary agent. The primary agent owns the fixes and subsequent
QA handoffs. Preserve the implementation for repair; do not delete or reset it,
mark the task DONE, or award completion credit. Stop helper and junior edits to
that task before transferring file ownership.

Give the implementation helper a different ready task whose scope and files do
not conflict with the transferred work. Follow actual prerequisite links and
respect available worker slots. Record the failed submissions, ownership change
and replacement assignment in the work handoff. The task-count cap remains
lifted; this rule changes ownership after repeated QA failure, not staffing or
acceptance requirements. QA retains final validation and publication authority.

## Infrastructure review — dedicated cycle inactive

On 2026-09-21 the user removed the dedicated senior reviewer from the active
cycle. Do not trigger a review after two DONE tasks, replace QA with that role,
or make a dedicated review a prerequisite to the next batch. The primary agent
may perform the explicitly authorized current review and retain its findings.
Final testing and validated publication remain assigned to QA under the rules
above; removing the reviewer does not itself transfer those responsibilities.

The following records the former rotation for historical context and applies
again only if the user explicitly reinstates it.

After at least **two task files reach DONE following QA acceptance** since the
previous infrastructure review, hand the completed work to the user-authorized
senior reviewer. Count accepted tasks, not individual tests, partial studies or
unsuccessful submissions. The user requested an inaugural review on 2026-09-21
using the seven already completed tasks; subsequent cycles start from that review.
An explicit user-requested review may run before the two-task threshold. Record
that exception and, after the review completes, count the next two accepted task
closures from its reviewed checkpoint. Review activity itself earns no task
completion credit.

Before starting the reviewer, save the QA agent's current verdicts, failed-
submission counters, evidence locations and any live process handles, then stop
its active turn and release its worker slot. Do not restart a still-running
command or infer completion from the handoff. Respect the environment's thread
limit; the reviewer replaces QA during this interval.

Verify that the runner actually releases the retained session's slot: finishing
or interrupting a turn is not proof of session removal. If creation or resumption
is rejected by the thread limit and no session-removal operation is available,
retain the review handoff and report the scheduling blocker. Do not relabel an
implementation helper as the configured reviewer, claim the review occurred,
or reset the accepted-closure checkpoint. Resume the requested role rotation
when the runner permits it.

The reviewer examines the work in the context of the whole library and its
infrastructure: core/companion boundaries, data and time contracts, ownership,
source lineage, streaming, determinism, resource bounds and delivery. Trace
relevant interactions and report concrete defects with file/line evidence,
triggers, consequences and acceptance implications. Existing unresolved work
does not become a new defect merely because it remains unfinished.

The reviewer writes no implementation code. It may create actionable TODO files
using this workflow's template, naming and dependency rules. Avoid duplicate
tasks for defects already covered by an open task's acceptance criteria. Propose
credit redistribution or reassessment where needed; the primary agent integrates
the task graph and milestone accounting without creating free completion points.
This review is not another implementation QA submission and does not increment
the 20-failure ownership-transfer counter.

When the review finishes, retain its findings and task references, release the
reviewer's slot, restore the QA agent and resume the saved work. Record the
reviewed completion checkpoint so the next two-task trigger is unambiguous.
Final feature testing and validated publication remain QA's responsibility.

After the batch passes and its completion records are integrated, the QA agent
commits the validated changes as needed and pushes to `origin/hello-pythian` for
review. Verify the branch, remote, staged scope and published commit. Include the
accepted task moves and milestone updates; exclude generated/private artifacts
and unrelated work. Use a normal push. Report failed validation or publication
to the primary agent before treating the batch as published. Publication
authority does not authorize implementation changes by the QA agent.
