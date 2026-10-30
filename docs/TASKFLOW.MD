# Task flow

[Goal](GOAL.md) · [Implementation assessment](ASSESSMENT-2026-10-29.md) ·
[Tasks](TODO/README.md) · [Milestones](MILESTONES.md) · [Work](WORK.md)

## Scope and source of truth

The [2026-10-29 goal](GOAL.md) selects experimental instrumental synthesis through
the full musical WFC graph, with Studio as the operator's proving ground.
The active task catalog defines deliverables; this workflow defines how they
are selected, accepted and counted. The former benchmark-first roadmap and its
assigned percentage credits are [historical](history/TASKFLOW-2026-10-29.md).

Use existing synthesis and musical graph implementations first. Authored/MIDI,
operator and uncertain WAV-derived inputs may bootstrap real instrumental output.
Show origins and Experimental status; do not assert reliable learning without
evidence. Formal reference/accuracy/adoption gates from older topic documents do
not block these experiments. Preserve actual failures, licenses and private data.

The operator explicitly resumed implementation solo after the 2026-10-29 reset.
Follow the current task order; the reset itself earned no acceptance.

## Naming and template

Active tasks live directly in `docs/TODO/`; accepted tasks move to `DONE/`
with the same basename. Superseded/cancelled tasks belong in `RETIRED/`, with
a disposition and replacement map. Retired is never accepted.

Use the next unused `NS-<goal>_<feature>_<xx>.md` name and one primary north-star
attribution. Every current-goal task follows this template:

```markdown
# NS-N_feature_01 — Concrete usable outcome

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Outcome, intended consumer, primary north-star attribution and scope boundary.
On acceptance, add dated evidence and practical limits here.

**Acceptance Criteria:**

- AC1: Observable capability and its relevant closing evidence.

**Blockers**

- None, or relative links to genuine prerequisite task files.

**Dev Notes:**

- Dated approaches, repaired issues, failures, owner/evidence links and follow-ups.
```

Use Ready, Dependency-blocked, In progress, Awaiting operator feedback, Accepted
or Retired as appropriate. Dev Notes is always the final section, including after
a DONE move. Notes do not hide failed criteria, authorize stopped investigations
or create implicit dependencies. Link rather than duplicate detailed logs.

## Effort and derived completion

Effort is an integer from 1 to 10 estimating relative implementation/integration
complexity and uncertainty. It is neither musical value nor a time commitment.

| Effort | Planning anchor |
| --- | --- |
| 1 | Tiny isolated change |
| 2–3 | Small bounded capability |
| 4–5 | Moderate implementation or integration |
| 6–7 | Substantial capability across existing components |
| 8–9 | Major cross-layer work or significant uncertainty; use bounded batches |
| 10 | Too large for implementation as one unit; split at usable outcomes first |

For goal `instrumental-exploration-2026-10-29`:

`completion = 100 × accepted effort / (open effort + accepted effort)`

Read Goal and Effort from current-goal tasks in TODO and DONE; accepted effort
comes only from DONE tasks whose complete criteria and prerequisites passed.
RETIRED and records with another/no Goal tag contribute nothing. At zero total
effort report unavailable, not 100%. Partial work earns no units.

A task added to current scope increases the denominator immediately. Reestimate
open work when scope/uncertainty changes, with the reason in Dev Notes. Freeze
accepted effort unless the task is reopened for an actual acceptance defect.
Do not reestimate completed work to improve a score. When splitting, preserve the
original scope and estimate, or explain any change; do not award split credit.

Recompute the catalog, milestone totals and north-star subtotals after every
addition, estimate change, retirement, reopening or completion. These are derived
snapshots of task metadata, not independently assigned weights. Historical DONE
records are reusable evidence but are not new-goal points. The former 52.45%
outcome-credit score is retired and cannot be compared to this ratio.

The ratio reports estimated scope delivered. It does not measure musical quality,
accuracy, reliability or ecosystem adoption. Claim 100% of this defined goal only
when every required task and acceptance gate is met; it is not a claim of
universal transcription or every possible synthesis technique.

## Select and execute

1. Read AGENTS, the current work handoff, assessment, selected task and relevant
   primary APIs. Select the least-delivered required musical outcome through its
   actual prerequisites. The first milestone is instrumental runtime, explicit
   percussion and ordinary Studio generation; convenient infrastructure is not
   a reason to change that order.
2. Check blockers against accepted task files. Historical component success is a
   starting implementation, not acceptance of a new consumer. Do useful upstream
   work without inventing formal benchmark prerequisites.
3. Before each batch name the criterion, usable deliverable, closing evidence and
   stop condition. Deliver maintained Pascal behavior through its actual caller.
4. Use proportional checks: changed core contracts/replay and relevant targets;
   changed UI through the actual desktop/narrow browser path; musical decisions
   through instrumental listening. Protect saved operator data and origins.
5. Keep one explicit musical question per review. Feedback retains graph, seed,
   instruments, source/proposal lineage and Before/After references. Saving never
   silently trains or regenerates. A failed musical hypothesis is useful evidence,
   not implementation success or automatic completion.

## Task size and investigation stop points

A batch is a bounded deliverable and its handoff, not a tool call or new report.
After **two consecutive batches without closing an acceptance criterion**, stop
and reassess before another batch. Record outcomes, why acceptance stalled and a
changed next action: finish a bounded usable slice, split at real deliverable
boundaries, or follow a demonstrated prerequisite. Do not split into reports.

Carry the counter across goals, pauses, agents, renamed experiments and task
moves. The reset inherited two from the previous observability sequence and
selected instrumental runtime instead of a third visibility expansion. The reset
earned no closure. The first resumed runtime batch later closed real criteria;
WORK records that event and the current consecutive count. Only such a closure
resets it.

Preserve the separate historical stop after 20 unsuccessful same-cause inference
attempts; no renamed threshold/source variant reauthorizes it. A new experiment
needs a different evidence-backed decision, a bounded cost and a stopping result.
Formal scientific rejection is distinct from an implementation defect.

## Discover a gap without losing the current task

Stop scope expansion, create the distinct linked task and update estimates,
catalog and milestones together. Return to the current deliverable unless the
gap genuinely blocks it; then link it as a prerequisite and follow dependency
order. Keep optional improvements out of Blockers. Never hide missing acceptance
in Dev Notes or add general audits to avoid a musical outcome.

## Complete, move and update accounting

Require every criterion and prerequisite to pass, with honest operator evidence
where specified. Record revision, caller, relevant target/check, result and
limits under Description; keep failures/follow-ups in final Dev Notes.

In one logical change move the accepted file to DONE, set Accepted, repair
incoming and internal links, recompute effort totals and record the changed
outcome/next deliverable in WORK. Reopening moves it back and removes its effort
from the numerator. Removing scope means Retired with a reason and replacements,
not DONE. Check links and arithmetic; do not rerun unrelated suites for a move.

## Delegated validation and publication

**Big Boss alone** under the operator's 2026-10-26 override until explicitly
changed. Do not start/resume helpers or describe solo checks/CI as independent QA.
Inactive staffing rules remain historical. Retain task failures and counters.

After proportionate validation, publish the integrated change on
`origin/hello-pythian`. Verify branch, remote, staged scope and published commit;
exclude generated/private artifacts and vendor source. A documentation-only
change may skip redundant CI after meaning, links, metadata and privacy checks.
Use the fixed service slots and isolated browser cleanup in the
[LAN procedure](LAN-REVIEW-SERVICE.md) for actual service/UI work.

### Cross-repository WFC gaps

Core-only use remains independent; WFC is integral to the full musical product.
Keep DSP, musical/provider vocabulary, clocks, sound mapping and uncertainty in
Pythian. Use the [ownership map](ARCHITECTURE.md#core-and-wfc-symbiosis).

- Isolate a domain-independent failing reproduction against pinned WFC. Inspect
  its separate local repository for an existing fix; a wrapper limitation is not
  automatically a generic solver defect.
- For a demonstrated generic gap, read that repository's guidance/work record,
  inspect its branch/worktree and create a new `codex/pythian-<gap>` branch from
  the appropriate reviewed revision. Inform the user of the gap, owner and branch
  before edits. Never patch `vendor/wfc/` or take unrelated upstream work.
- Implement/validate the generic fix there with bounded Pascal regressions.
  Link upstream branch/commit and any real coordination prerequisite from the
  Pythian task, without duplicate effort credit.
- Integrate a reviewed commit through an explicit gitlink update and affected
  core-isolation/adapter/consumer checks, preserving notices and provenance.
  Upstream success alone neither accepts the downstream criterion nor authorizes
  merging another repository's branch.

No new generic WFC gap was demonstrated by the 2026-10-29 assessment. Explicit
percussion and musical-domain mappings belong in Pythian.
