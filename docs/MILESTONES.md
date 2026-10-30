# Current milestones and effort-derived progress

[Goal](GOAL.md) · [Assessment](ASSESSMENT-2026-10-29.md) ·
[Task catalog](TODO/README.md) · [Workflow](TASKFLOW.MD) · [Work](WORK.md)

## North-star assessment

The 2026-10-29 goal is usable experimental instrumental synthesis through a rich,
editable WFC musical graph in Studio. Existing library instruments, musical
adapters and Studio infrastructure are implementation foundations. None of the
new integrated outcomes has yet met all its criteria.

**Current snapshot: 0 / 82 effort units accepted (0%); 12 open tasks.**
This is a scope-delivery estimate, not a musical-quality score. No arbitrary
per-task percentages or north-star weights apply.

| North star | Required outcome in this goal | Open effort | Accepted effort | Derived progress |
| --- | --- | ---: | ---: | ---: |
| [NS-1](#ns-1) | Preserve portable core independence | 0 | 0 | Baseline invariant; no standalone current task |
| [NS-2](#ns-2) | Explicit percussion and full sound-design controls | 12 | 0 | 0 / 12 |
| [NS-3](#ns-3) | Experimental recording-derived providers and growing style vocabulary | 15 | 0 | 0 / 15 |
| [NS-4](#ns-4) | Shared instrumental runtime, graph inspection and musical controls | 21 | 0 | 0 / 21 |
| [NS-5](#ns-5) | Evolving musical form and reusable selective blends/reblends | 15 | 0 | 0 / 15 |
| [NS-6](#ns-6) | Ordinary Studio generation, meaningful reviews and long instrumental sessions | 19 | 0 | 0 / 19 |
| **Total** | **12 current-goal tasks** | **82** | **0** | **0%** |

## First milestone: hear and change instrumental music in Studio

1. [Instrumental runtime](TODO/NS-4_instrumental-runtime_01.md), effort 7:
   actual coupled musical WFC passes drive existing Pythian instruments.
2. [Explicit percussion](TODO/NS-2_percussion_01.md), effort 6:
   drums have a real rhythmic role without pitched-harmony membership errors.
3. [Instrumental Studio](TODO/NS-6_instrumental-studio_01.md), effort 6:
   an ordinary native job produces bass, drums, harmony and lead; play/solo/mute,
   change musical settings and regenerate without a source-recording sound bank.

These 19 effort units constitute the first operator-facing milestone, with no
assumed acceptance. Authored/MIDI/operator input may bootstrap it. Formal WAV
inference accuracy, independent annotation and fixed corpus floors do not block it.

## Remaining delivery outcomes

<a id="ns-1"></a>
### NS-1 — Independent reusable foundation

Keep the accepted portable core, notices and public-library ownership boundary.
Every affected implementation protects this invariant; no synthetic baseline task
earns new effort. Existing code did not become unimplemented because scope changed.

<a id="ns-2"></a>
### NS-2 — Playable sound breadth

[Percussion](TODO/NS-2_percussion_01.md) and
[sound design](TODO/NS-2_sound-design_01.md) expose actual sources, envelopes,
automation, filters, routing and effects rather than inventing a parallel engine.

<a id="ns-3"></a>
### NS-3 — Recording-informed experimentation

[Experimental learning](TODO/NS-3_experimental-learning_01.md) connects available
analysis to editable musical proposals; [style vocabulary](TODO/NS-3_style-vocabulary_01.md)
uses coarse classifications and selected material across long private recordings.
Uncertainty is visible and correctable, not a reason to withhold audition.

<a id="ns-4"></a>
### NS-4 — Musical graph and synthesis together

[Runtime](TODO/NS-4_instrumental-runtime_01.md),
[graph workbench](TODO/NS-4_graph-workbench_01.md) and
[musical controls](TODO/NS-4_graph-controls_01.md) expose actual time/role domains,
passes/dependencies, locks/preferences, affect mappings and selective regeneration.

<a id="ns-5"></a>
### NS-5 — Music that develops and styles that remain reusable

[Musical form](TODO/NS-5_musical-form_01.md) adds editable phrase/section continuity,
variation and repetition. [Instrumental styles](TODO/NS-5_instrumental-styles_01.md)
save real provider/control/sound recipes and exercise selective blends and reblends.

<a id="ns-6"></a>
### NS-6 — A useful operator bridge

[Studio](TODO/NS-6_instrumental-studio_01.md),
[reviews](TODO/NS-6_synthesis-reviews_01.md) and
[instrumental streams](TODO/NS-6_instrumental-streams_01.md) deliver actual
experimental jobs, Original/Before/After feedback, inspectable results, efficient
long playback and mobile recovery. Reuse existing working UI and native transport.

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
Current scoped records: 12 open + 0 current DONE; legacy records: 53 retired +
97 historical DONE. No implementation, saved feedback or license is discarded.

100% means all required outcomes in this defined experimental goal are delivered
and reviewed. It cannot promise any style from any user with universal accuracy.
If listening exposes a required new gap, add it with an estimate before claiming
completion. Product implementation remains paused. The previous two-nonclosing-
batch threshold is carried in WORK; this reassessment changes the next selected
action to instrumental runtime, without inventing a closure or resetting history.