# Task flow

[Milestones](MILESTONES.md) · [Open tasks](TODO/README.md) ·
[Done tasks](TODO/DONE/README.md) · [Work record](WORK.md)

## Scope and source of truth

Apply Athena's [shared Task flow standard](../vendor/athena/docs/task-flow.md).
This file records Pythian's adopted paths, scope, acceptance allocation and
user-directed execution choices; the shared standard owns the general lifecycle.

The current direction and evidence audit are in the
[2026-09-29 reassessment](REBALANCE-2026-09-29.md) and
[codebase assessment](CODEBASE-ASSESSMENT.md). They revise the backlog, not
product acceptance. Personal chillwave, stoner rock and lofi labels are internal
fixtures; library contracts and final gates accept caller-defined styles.

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

The user's later listening allocation is more specific: put routine recorded
dataset labeling on source quality, publisher documentation, and independently
supported evidence. Do not queue more source-audio microclips for the user as
the default route to a benchmark. Keep unsupported exact-window claims
`unknown` and the corresponding acceptance criterion open. Ask the user to
judge substantial **Pythian-synthesized outputs**, where their musical hearing
can shape the library, rather than repeatedly judging third-party recordings.

Accumulate a cross-task **manual review queue**. Substantial, individually useful
manual decisions count, including Pythian-synthesized listening checkpoints and
operator/tool reviews; the LAN workbench's physical-phone workflow is one item. Give each
item its task, exact artifact or URL, and the decision needed. Do not pad the
queue with seed variants, paired edits or separate steps of one review. Notify
the user when 20 items are pending in total, or earlier if every independently
workable task is genuinely blocked and a queued review can unblock progress.
Keep numbered WAVs and the queue ledger under ignored `build/`; remove reviewed
feedback files after recording the verdict. Continue independent engineering
and task selection while review is pending. Queueing an item is neither its
acceptance nor earned task credit.

The user may initiate catalog authoring at any time; the 20-item threshold
governs our review notifications, not access to the new operator workbench. Keep
Pythian's unreviewed proposals separate from operator-approved labels and
hide proposals during blind evaluation review. Store the reviewed catalog in
a durable user-configured root outside disposable `build/`; explicit exports
must preserve source identity and group isolation. See the
[Pascal catalog](TODO/DONE/NS-3_labeling_01.md) and
[pas2js workbench](TODO/DONE/NS-6_authoring_01.md) tasks.

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

Execution status: ready, dependency-blocked, external/reference-blocked, or stopped investigation.
Next deliverable: criterion advanced and a usable API/consumer/result.
Closing evidence and stop condition: exact required outputs and when to stop.
Primary attribution: one owning north star; secondary contributions receive no duplicate credit.

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

The user's 2026-09-30 [operator Studio direction](OPERATOR-STUDIO.md) selects
project/source setup -> actual training/audition jobs -> musical comparison and
deliberate iteration as the next NS-5 calibration enabler, with primary NS-6
credit. UI/UX is an acceptance boundary in every slice. Use short development
auditions under an explicit policy without replacing the fixed final packet.
The old blanket operator deferral does not prohibit this named consumer;
unexplained source-marker QA and stopped scientific variants remain unselected.

1. Read the selected task, its current topic evidence and the work record. Check
   that each file under **Blockers** is accepted in DONE. A draft implementation,
   a passing isolated test or an active task does not satisfy a blocker.
2. Select one current task under the prioritized outcome package. Being ready
   is not by itself a reason to switch to a convenient infrastructure task.
   Record external needs such as listening judgments, verified sources, a runner
   or independently reproduced use explicitly; do not invent approval or results.
3. Define the next observable result and reuse existing verified tools/evidence.
   Use the current authorized team below. Implement maintained behavior in Pascal and use
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

The catalog is the current declared scope, subject to evidence-backed reassessment. Unsupported browser/device APIs,
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

The user-authorized **2026-09-29 complete-goal allocations**, updated after
independent caller-intake, minimal package, caller-provider, editor/queue and
Studio source/jobs/effects/capture acceptance through **2026-10-01**, give:

| Goal | Accepted baseline | Overall weight | Accepted DONE points | Open points |
| --- | ---: | ---: | ---: | ---: |
| NS-1 | 100 | 5 | 0 | 0 |
| NS-2 | 70 | 25 | 20 | 10 |
| NS-3 | 10 | 25 | 15 | 75 |
| NS-4 | 20 | 15 | 45 | 35 |
| NS-5 | 0 | 20 | 14 | 86 |
| NS-6 | 0 | 10 | 43 | 57 |

`Goal completion = baseline + sum(accepted DONE task credits for that goal)`.
`Overall completion = sum(goal completion * goal weight / 100)`.
Current goal completions are **100/90/25/65/14/43**; weights are
**5/25/25/15/20/10**. Therefore current accepted scope is **50.60 weighted
points**, with **49.40 remaining**. The rebase records newly explicit caller
extension, maintained support and adoption requirements; it earns no acceptance.
For example, accepting `NS-3_notes_01` adds 7 points within NS-3 and 1.75 overall
point. Record the arithmetic on every completion; preserve the current accepted
ledger until an actual task closes or a documented reassessment withdraws credit. These allocations are transparent planning
judgments about scope, not measured engineering precision or effort estimates.

The [operator Studio allocation](OPERATOR-STUDIO.md#allocation-and-ownership)
redistributes 15 unearned NS-6 points across seven outcomes, including collection,
effects, capture and mixed-format preparation, without awarding acceptance.
Studio setup acceptance adds 4 NS-6 / 0.40 overall; private corpora, bounded raw
WFC jobs, effects and capture/exploration add 8 NS-6 / 0.80 overall. The catalog
contains **45 open / 40 accepted tasks**, NS-6 **43/57**, overall **50.60/49.40**. All
original donor criteria remain required alongside the new operator outcomes.

Task credits, not file counts, drive completion. Partial implementation,
experiments, more tests, hours collected and this initial task authoring earn no
automatic credit. Do not retroactively apply the new credits to capability
already included in the baseline. A completed parent outcome earns no extra
points on top of its tasks.

For routine splits, redistribute unearned credit and record the allocation so
each goal still totals 100. The user may authorize a complete outcome rebase,
as on 2026-09-29; change baseline and accepted/open weights explicitly in
MILESTONES, every affected task and both ledgers with a capability rationale.
Preserve evidence, distinguish weight changes from new acceptance, and retire
the previous basis. Adding files never creates completion. A scope expansion or
disproved capability also requires an explicit reassessment. Moving a
reopened task back to TODO removes its accepted credit; recalculate all totals.
No task may close with an unspecified allocation or unsupported completion claim.

Group the roadmap into meaningful outcome packages. The former ten-overall-point
package preference does not size work batches or delay a useful small result;
use the concrete delivery order in the current reassessment. Individual tasks
and batches close independently without inflating credit. No final 100% claim is valid while any required task or acceptance
evidence remains unresolved.

## Delegated validation and publication

### Cross-repository WFC gaps

WFC is required for the complete Pythian composition/synthesis outcome; a
core-only build is the independent foundation, not a substitute for that outcome.
Use the [architecture ownership map](ARCHITECTURE.md#core-and-wfc-symbiosis).

- Keep audio DSP, musical/provider vocabulary, clocks, note/sound mapping,
  uncertainty, evidence and style-specific integration in Pythian.
- Before calling a gap upstream, isolate a domain-independent failing
  reproduction against the pinned WFC contract and inspect the separate local
  WFC checkout for an existing fix. A Pythian wrapper restriction is not
  automatically a missing generic solver feature.
- For a demonstrated WFC-core gap, read that repository's current guidance and
  work record, inspect its branch/worktree, and create a new `codex/pythian-<gap>`
  branch from the appropriate reviewed revision in the separate repository.
  Tell the user the concrete gap, upstream owner and branch before edits.
  The user's instruction authorizes that route; do not edit `vendor/wfc/`
  or silently use unrelated upstream work.
- Implement and validate the generic fix there with bounded Pascal regressions,
  preserving replay, budgets and unrelated clients. Keep audio-specific behavior
  in Pythian. Link the upstream issue/branch/commit from the owning Pythian task;
  create a distinct coordination prerequisite if needed, with no duplicate credit.
- Integrate a reviewed upstream commit through an explicit Pythian gitlink
  update and affected core-isolation/adapter/consumer checks. Keep source and
  license provenance. Upstream branch work does not by itself close the
  downstream Pythian criterion or authorize merging another repository's branch.

The 2026-09-29 boundary audit found no demonstrated generic failing contract,
so no WFC branch or dependency change was made in this reassessment.

### Current team

The user's 2026-09-29 configuration and subsequent team/model revisions
supersede all earlier assignments, junior permission and QA failure limits.

| Role | Configuration | Ownership |
| --- | --- | --- |
| Big Boss (main) | GPT-6 Sol, Ultra | Chief oversight, hardest assessment/final judgment, scope/architecture decisions, delegating bounded authority and mandatory repair after worker failures |
| Ticket Guy | GPT-6.1 Sol, Medium | Bounded implementation work assigned by Big Boss, no task-count cap |
| Ticket Guy Neo | GPT-6.1 Sol, Ultra | Complex/costly work and audits/integration/coordination delegated by Big Boss; may assign bounded disjoint work to existing Ticket Guy and coordinate Salty Boi |
| Salty Boi | GPT-6.1 Sol, Low (requested Light) | Final QA; no implementation code; may create actionable backlog tasks |

These are requested role settings, not permission to misreport the host's
actual model. Record an unavailable setting rather than silently substitute.
Only these three helpers are authorized in addition to Big Boss. Big Boss retains
chief oversight and the hardest assessment/final judgment. Neo receives
complex/costly work or operational coordination
by Big Boss's explicit judgment and may delegate within the existing team using
bounded exclusive ownership. Neo cannot spawn additional helpers, overlap
assignments or act as a substitute for Big Boss's
repair required after two failed worker implementation QA submissions.
Every assignment names exclusive files, concrete acceptance, closing evidence
and stop condition. Do not overlap ownership. Big Boss may reassign
preserved work explicitly; a model replacement does not reset task history.
Call out the handoff when Big Boss takes over a task, keeping the prior evidence
and counters attached to its current owner.

Start a fresh QA batch only when at least **two tasks or components** are ready.
For this documentation reassessment, capability/NS-6 review and backlog/workflow
reconciliation are distinct components; neither creates product milestone credit.
Combine impact-appropriate checks. Corrections and completion-record verification
belong to the same batch, without rerunning unaffected suites. A current criterion
defect blocks acceptance; unrelated discoveries become linked tasks.

Track implementation QA submissions separately for each task assigned to
Ticket Guy or Ticket Guy Neo.
A blocking implementation or required-evidence defect makes one failed submission,
regardless of its number of findings. Repeating an unchanged finding adds no
submission; runner outages do not count. A correctly implemented experiment's
scientific rejection is separate from implementation failure and still counts
as a nonclosing work batch where no criterion closes.

After **two failed QA submissions for the same task of either Ticket Guy**, stop worker
edits and transfer its implementation, task and complete failure evidence to the
Big Boss for repair. Preserve files and failed approaches. Give Ticket Guy
another ready task with disjoint ownership; do not add a helper or reset counters.
Do not route the failed task through Neo to avoid transfer to Big Boss.
Record transfer and replacement in WORK.md. QA retains final validation.

The two-nonclosing-batch checkpoint and the separate twenty-unsuccessful-attempt
scientific cap above both remain in force. Neither a new agent, renamed experiment,
task split nor this reassessment erases prior counts or reauthorizes a stopped
source/threshold family. Record at handoff: criteria closed/still open,
consecutive nonclosing batches (or at least two when older records only establish
the threshold), failed implementation submissions, current owner and unblock
condition. Historical cumulative counts that cannot be reconstructed are
unknown, never invented as zero.

There is no dedicated senior/junior review rotation. Earlier rotation descriptions
and model assignments in the dated work record are historical only.

After validation and integrated completion records, Salty Boi commits and pushes
the reviewed scope to `origin/hello-pythian`. Verify branch, remote, staged paths
and published commit; use a normal push. Exclude generated/private artifacts,
unrelated work and dependency source. Report failed validation/publication.
Publication authority does not authorize implementation edits by QA.

For browser/service QA, follow the fixed executable slots, firewall prerequisites,
isolated profile and exact process cleanup in [LAN procedure](LAN-REVIEW-SERVICE.md).
A documentation-only batch does not need a service, browser or audio session.
