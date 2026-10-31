# Current milestones and effort-derived progress

[Goal](GOAL.md) · [Assessment](ASSESSMENT-2026-10-29.md) ·
[Task catalog](TODO/README.md) · [Workflow](TASKFLOW.MD) · [Work](WORK.md)

## North-star assessment

The 2026-10-29 goal is usable experimental instrumental synthesis through a rich,
editable WFC musical graph in Studio. Existing library instruments, musical
adapters and Studio infrastructure are implementation foundations. The finite
instrumental runtime, explicit percussion and finite Studio generation have met
their criteria, including the discovered live-cancellation prerequisite.

**Current snapshot: 44 / 102 effort units accepted (43.14%); nine open, ten current-goal DONE.**
This is a scope-delivery estimate, not a musical-quality score. No arbitrary
per-task percentages or north-star weights apply.

| North star | Required outcome in this goal | Open effort | Accepted effort | Derived progress |
| --- | --- | ---: | ---: | ---: |
| [NS-1](#ns-1) | Preserve portable core independence | 0 | 0 | Baseline invariant; no standalone current task |
| [NS-2](#ns-2) | Explicit percussion and full sound-design controls | 6 | 6 | 6 / 12 |
| [NS-3](#ns-3) | Experimental recording-derived providers and growing style vocabulary | 7 | 8 | 8 / 15 |
| [NS-4](#ns-4) | Shared instrumental runtime, joint context, motif coupling, graph inspection and musical controls | 17 | 16 | 16 / 33 |
| [NS-5](#ns-5) | Evolving musical form and reusable selective blends/reblends | 15 | 0 | 0 / 15 |
| [NS-6](#ns-6) | Ordinary Studio generation, meaningful reviews, cancellation, faithful JSON and long instrumental sessions | 13 | 14 | 14 / 27 |
| **Total** | **19 current-goal tasks** | **58** | **44** | **43.14%** |

## First milestone: hear and change instrumental music in Studio

1. [Instrumental runtime — DONE](TODO/DONE/NS-4_instrumental-runtime_01.md), effort 7:
   actual coupled musical WFC passes drive existing Pythian instruments; source-free caller delivered.
2. [Explicit percussion — DONE](TODO/DONE/NS-2_percussion_01.md), effort 6:
   drums have a real rhythmic role without pitched-harmony membership errors.
3. [Live-job cancellation — DONE](TODO/DONE/NS-6_job-cancellation_01.md), effort 2:
   repair the concrete busy-writer Cancel rejection exposed by this Studio batch.
4. [Instrumental Studio — DONE](TODO/DONE/NS-6_instrumental-studio_01.md), effort 6:
   an ordinary native job produces bass, drums, harmony and lead; play/solo/mute,
   change musical settings and regenerate without a source-recording sound bank.

These 21 effort units constitute the delivered first operator-facing milestone:
all 21 accepted. Actual source-free instrumental generation, settings, mix/stems,
feedback and a tempo-change experiment pass through Studio. This is an authored
starter, not recording-derived style learning or musical-quality acceptance. Formal WAV
inference accuracy, independent annotation and fixed corpus floors do not block it.

## Remaining delivery outcomes

<a id="ns-1"></a>
### NS-1 — Independent reusable foundation

Keep the accepted portable core, notices and public-library ownership boundary.
Every affected implementation protects this invariant; no synthetic baseline task
earns new effort. Existing code did not become unimplemented because scope changed.

<a id="ns-2"></a>
### NS-2 — Playable sound breadth

[Percussion](TODO/DONE/NS-2_percussion_01.md) and
[sound design](TODO/NS-2_sound-design_01.md) expose actual sources, envelopes,
automation, filters, routing and effects rather than inventing a parallel engine.

<a id="ns-3"></a>
### NS-3 — Recording-informed experimentation

[Experimental learning](TODO/DONE/NS-3_experimental-learning_01.md) connects available
analysis to editable musical proposals; [style vocabulary](TODO/NS-3_style-vocabulary_01.md)
uses coarse classifications and selected material across long private recordings.
Uncertainty is visible and correctable, not a reason to withhold audition.
Experimental learning is accepted: contextual accept/correct/manual/bypass
choices drive actual symbolic providers and instrument cutoff/sustain, with
Original references and saved correction/feedback lineage. Observations remain
bounded Experimental proposals, not automatic source-instrument identification
or whole-corpus learning. Style vocabulary remains open.

<a id="ns-4"></a>
### NS-4 — Musical graph and synthesis together

[Runtime](TODO/DONE/NS-4_instrumental-runtime_01.md),
[joint context](TODO/DONE/NS-4_joint-context_01.md),
[graph workbench](TODO/NS-4_graph-workbench_01.md) and
[musical controls](TODO/NS-4_graph-controls_01.md) expose actual time/role domains,
passes/dependencies, locks/preferences, affect mappings and selective regeneration.
The current runtime also retains accepted graph/score decisions during atomic
pitched instrument/expression edits. Durable Studio follow-ups and role/passage
graph regeneration are still required; this partial slice earns no accepted units.
The [motif-coupling prerequisite](TODO/DONE/NS-4_motif-coupling_01.md) is accepted:
full symbolic context choices decide harmony, rhythm and one explicit selected
part together; the other pitched parts remain independently generated, followed
by percussion. Actual graph summaries expose three conditional groups and the
driven-role input. Proof/vocabulary-dependent examples have17 or20 passes; there
is no cross-group backtracking or universal success claim. Its five units close
the demonstrated melody/role repair; no recording-style or musical-quality credit
follows. Experimental learning also supplies explicit instrument cutoff/sustain
mapping; deeper recipes and graph controls retain their own tasks.

<a id="ns-5"></a>
### NS-5 — Music that develops and styles that remain reusable

[Musical form](TODO/NS-5_musical-form_01.md) adds editable phrase/section continuity,
variation and repetition. [Instrumental styles](TODO/NS-5_instrumental-styles_01.md)
save real provider/control/sound recipes and exercise selective blends and reblends.

<a id="ns-6"></a>
### NS-6 — A useful operator bridge

[Studio](TODO/DONE/NS-6_instrumental-studio_01.md),
[reviews](TODO/NS-6_synthesis-reviews_01.md) and
[instrumental streams](TODO/NS-6_instrumental-streams_01.md) deliver actual
experimental jobs, Original/Before/After feedback, inspectable results, efficient
long playback and mobile recovery. Reuse existing working UI and native transport.
[JSON identity](TODO/DONE/NS-6_json-identity_01.md) repairs the demonstrated musical
choice save/reopen prerequisite. Its three implementation units are accepted after
native storage and actual HTTP checks; the parent experimental editor is now accepted.
[Source-free draft reopening](TODO/DONE/NS-6_sourcefree-draft_01.md) repairs the
optional-recipe browser prerequisite. [Instrumental progress](TODO/DONE/NS-6_instrumental-progress_01.md)
is accepted after bounded cross-phase publication, unchanged native consumers,
live cancellation and the actual HTTP worker. Musical controls now expose pitch
bounds, upstream activity, expression and editable affect mappings in Studio;
the parent remains open for selective regeneration and retained model/score work.

## Completion accounting

[Task metadata](TODO/README.md) owns estimates. For the current Goal tag,
`100 × sum(DONE effort) / sum(TODO + DONE effort)` gives the overall percentage.
Additions increase the denominator. No partial work, planning, report, retired
ticket or historical component earns new acceptance. Recompute this snapshot and
the task index together whenever scope/estimates/status change.

The 53 former open tasks are [retired/replaced](TODO/RETIRED/2026-10-29/README.md),
not accepted. All 97 historical DONE records and their evidence remain separate;
none has the current Goal tag. The former 52.45% weighted outcome-credit ledger is
[historical](history/MILESTONES-2026-10-29.md), not a baseline in the new formula.
Current scoped records: 9 open + 10 current DONE; legacy records: 53 retired +
97 historical DONE (107 total DONE files). No implementation, saved feedback or license is discarded.

100% means all required outcomes in this defined experimental goal are delivered
and reviewed. It cannot promise any style from any user with universal accuracy.
If listening exposes a required new gap, add it with an estimate before claiming
completion. Implementation has resumed solo. The first runtime batch closes real
criteria and changes the carried nonclosing count from two to zero; WORK records
the event. Percussion, Studio and its concrete cancellation repair also close
their criteria. The first real instrumental review is waiting for the operator;
graph editing, deeper sound controls, corpus vocabulary, form/styles and streams remain open.
