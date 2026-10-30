# Active tasks: experimental instrumental synthesis

[Goal](../GOAL.md) · [Assessment](../ASSESSMENT-2026-10-29.md) ·
[Milestones](../MILESTONES.md) · [Task flow](../TASKFLOW.MD) · [Work](../WORK.md)

**11 open tasks · 82 total effort units · 1 current-goal DONE · 7 / 82 accepted (8.54%).**
Effort is relative complexity on a 1–10 scale, not assigned musical credit.
The operator has resumed implementation solo. The shared instrumental runtime
is accepted; explicit percussion is next. Ordinary Studio integration follows.

## First operator-facing milestone

| Task | Effort | Actual prerequisites |
| --- | ---: | --- |
| [NS-4_instrumental-runtime_01 — DONE](DONE/NS-4_instrumental-runtime_01.md) — shared musical WFC → instruments | 7 | Accepted; source-free public caller |
| [NS-2_percussion_01](NS-2_percussion_01.md) — synthesized drum role | 6 | Instrumental runtime accepted; ready |
| [NS-6_instrumental-studio_01](NS-6_instrumental-studio_01.md) — ordinary Studio instrumental jobs | 6 | Runtime + percussion |

Together these 19 units deliver bass, drums, harmony and lead in Studio with
real musical controls and playback. Authored/operator/MIDI inputs are sufficient
to start; uncertain WAV proposals can follow without a benchmark-first gate.
Seven units are accepted; 12 remain in this milestone. No more raw-grain
continuity experiments are selected.

## Complete current scope

| Task | Effort | Actual prerequisites |
| --- | ---: | --- |
| [NS-2_sound-design_01](NS-2_sound-design_01.md) — reusable instrument/effects recipes | 6 | Runtime + instrumental Studio |
| [NS-4_graph-workbench_01](NS-4_graph-workbench_01.md) — inspect and edit actual graph | 7 | Instrumental Studio |
| [NS-4_graph-controls_01](NS-4_graph-controls_01.md) — dimensions, affect and selective regeneration | 7 | Runtime |
| [NS-3_experimental-learning_01](NS-3_experimental-learning_01.md) — WAV proposals into musical providers | 8 | Runtime + instrumental Studio |
| [NS-3_style-vocabulary_01](NS-3_style-vocabulary_01.md) — coarse long-recording corpus learning | 7 | Experimental learning |
| [NS-5_musical-form_01](NS-5_musical-form_01.md) — phrases, sections and useful variation | 8 | Graph controls + instrumental Studio |
| [NS-5_instrumental-styles_01](NS-5_instrumental-styles_01.md) — saved styles, selective blend and reblend | 7 | Style vocabulary + graph controls + sound design + instrumental Studio |
| [NS-6_synthesis-reviews_01](NS-6_synthesis-reviews_01.md) — one useful question with Original/Before/After | 5 | Instrumental Studio |
| [NS-6_instrumental-streams_01](NS-6_instrumental-streams_01.md) — efficient long instrumental jobs | 8 | Instrumental Studio |

The two tables together are all 12 current-goal tasks (11 open, one DONE),
totaling 82 units: 75 open and 7 accepted. Subtotals:
NS-2 12, NS-3 15, NS-4 21, NS-5 15, NS-6 19. NS-1 remains a preserved core
independence invariant, not an invented new baseline task.

The first milestone owns priority, not convenience. Later tasks have explicit
real dependencies; their row order does not create extra prerequisite gates.
When a required capability is missing, make a linked task and rebalance current
effort before scope grows.

## How the percentage changes

All current-goal tasks declare Goal `instrumental-exploration-2026-10-29`, integer
Effort, Status, primary north-star attribution, criteria, blockers and final Dev
Notes. For this Goal, percentage is
`100 × accepted DONE effort / (open effort + accepted DONE effort)`.
Read it from task metadata and update this derived snapshot and milestones after
every addition, reestimate, retirement, reopening or accepted move. There is no
separate percentage allocation. An added task increases the denominator; partial
work, tests and planning earn no units. See [estimate rules](../TASKFLOW.MD#effort-and-derived-completion).

## Historical scope and replacements

[All 53 former open tasks](RETIRED/2026-10-29/README.md) have left the active queue,
with a per-ticket disposition and useful scope mapped to the new outcomes. Their
original criteria, failures and links remain historical evidence. None moved to
DONE; formal benchmark-first, raw reconstruction and external-adoption obligations
do not silently remain entry gates under new filenames.

[97 historical DONE records](DONE/README.md) preserve accepted implementations,
licenses and evidence. They have no current Goal tag and earn no units in this
new delivery estimate. Their old percentage-credit ledger is historical. The
[previous catalog](RETIRED/2026-10-29/legacy-catalog.md) is retained for traceability.
