# Active tasks: experimental instrumental synthesis

[Goal](../GOAL.md) · [Assessment](../ASSESSMENT-2026-10-29.md) ·
[Milestones](../MILESTONES.md) · [Task flow](../TASKFLOW.MD) · [Work](../WORK.md)

**9 open tasks · 91 total effort units · 6 current-goal DONE · 28 / 91 accepted (30.77%).**
Effort is relative complexity on a 1–10 scale, not assigned musical credit.
The operator has resumed implementation solo. The shared instrumental runtime
and explicit percussion are accepted. Finite instrumental Studio and its real
cancellation prerequisite are now accepted; the first operator review is waiting.
Experimental learning is in progress: its AC1 musical suggestions are exposed
through recording and import analysis. AC2–4 remain open; no partial effort is credited.
Its joint harmony/rhythm context prerequisite is accepted through the shared
runtime and native/actual pas2js consumers; Studio choice controls remain open.

## First operator-facing milestone

| Task | Effort | Actual prerequisites |
| --- | ---: | --- |
| [NS-4_instrumental-runtime_01 — DONE](DONE/NS-4_instrumental-runtime_01.md) — shared musical WFC → instruments | 7 | Accepted; source-free public caller |
| [NS-2_percussion_01 — DONE](DONE/NS-2_percussion_01.md) — synthesized drum role | 6 | Accepted; core recipes and conditional rhythmic graph |
| [NS-6_job-cancellation_01 — DONE](DONE/NS-6_job-cancellation_01.md) — Cancel during live progress writes | 2 | Accepted; actual app cancellation and owned-writer checks |
| [NS-6_instrumental-studio_01 — DONE](DONE/NS-6_instrumental-studio_01.md) — ordinary Studio instrumental jobs | 6 | Accepted; authored six-part jobs, controls, mix/solo/mute and feedback |

Together these 21 units deliver bass, drums, harmony and lead in Studio with
real musical controls and playback. Authored/operator/MIDI inputs are sufficient
to start; uncertain WAV proposals can follow without a benchmark-first gate.
All 21 units in this first milestone are accepted. Nine later tasks remain open. No more raw-grain
continuity experiments are selected.

## Complete current scope

| Task | Effort | Actual prerequisites |
| --- | ---: | --- |
| [NS-2_sound-design_01](NS-2_sound-design_01.md) — reusable instrument/effects recipes | 6 | Runtime + instrumental Studio |
| [NS-4_graph-workbench_01](NS-4_graph-workbench_01.md) — inspect and edit actual graph | 7 | Instrumental Studio |
| [NS-4_graph-controls_01](NS-4_graph-controls_01.md) — dimensions, affect and selective regeneration | 7 | Runtime |
| [NS-4_joint-context_01 — DONE](DONE/NS-4_joint-context_01.md) — retain harmony/rhythm coupling | 4 | Accepted; actual paired context and conditional six-part motif generation |
| [NS-3_experimental-learning_01](NS-3_experimental-learning_01.md) — WAV proposals into musical providers | 8 | Runtime + instrumental Studio + joint context for AC3 |
| [NS-3_style-vocabulary_01](NS-3_style-vocabulary_01.md) — coarse long-recording corpus learning | 7 | Experimental learning |
| [NS-5_musical-form_01](NS-5_musical-form_01.md) — phrases, sections and useful variation | 8 | Graph controls + instrumental Studio |
| [NS-5_instrumental-styles_01](NS-5_instrumental-styles_01.md) — saved styles, selective blend and reblend | 7 | Style vocabulary + graph controls + sound design + instrumental Studio |
| [NS-6_synthesis-reviews_01](NS-6_synthesis-reviews_01.md) — one useful question with Original/Before/After | 5 | Instrumental Studio |
| [NS-6_json-identity_01 — DONE](DONE/NS-6_json-identity_01.md) — preserve Unicode choices and JSON identities | 3 | Accepted; actual native save/reload/job and HTTP consumers |
| [NS-6_instrumental-streams_01](NS-6_instrumental-streams_01.md) — efficient long instrumental jobs | 8 | Instrumental Studio |

The two tables together are all 15 current-goal tasks (9 open, six DONE),
totaling 91 units: 63 open and 28 accepted. Subtotals:
NS-2 12, NS-3 15, NS-4 25, NS-5 15, NS-6 24. NS-1 remains a preserved core
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
