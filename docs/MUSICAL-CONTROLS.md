# Musical controls

[Studio](OPERATOR-STUDIO.md) · [Instrumental runtime](INSTRUMENTAL.md) ·
[Current task](TODO/NS-4_graph-controls_01.md)

Ordinary Studio keeps Library → Selection → Generate. A completed retained track
offers optional Change sounds and Change notes actions. Change notes selects a
time range and musical parts, with optional pitch bounds, rhythmic activity and
chord/root choices. These are explicit operator choices, not an interpretation of
a free-text style label or a promise of a particular musical mood.

The older authored key/tempo/expression/affect form is currently unreachable from
the simple Studio entrypoint. Its library and job contracts remain implemented;
[optional musical laboratory](TODO/NS-6_optional-lab_01.md) restores an accessible
consumer. The mappings below describe those contracts, not a claim that every
control is currently displayed in ordinary Studio.

| Control | Actual effect |
| --- | --- |
| Tempo / key / accompaniment | Existing clock and authored material settings |
| Follow the authored guide | Pins the starter's harmony and joint rhythm |
| Let WFC choose | Releases that guide; available vocabulary and graph rules still apply |
| Lowest / highest MIDI pitch | Hard token bounds for Bass, Harmony or Lead; all tones of a chord must fit |
| Attack preference | Biases the upstream joint rhythm; positive favors attacks, negative favors holds/rests |
| Chord-root preference | Positive favors harmony containing the current key root; negative favors other harmony |
| Velocity | Performed note velocity in percent, rounded and saturated to 1–127 |
| Gate length | Shortens performed note gates in ticks; retains at least one tick |

Soft preferences multiply favored choice weights by
`1 + ceil(30 × abs(bias) / 100)` for bias−100..100; other choices retain weight1.
Active roles' activity increments are combined by ceiling mean into one bounded
rhythm weight; neutral roles do not dilute an explicit preference. The maximum31
lets harmony and joint-rhythm preferences compose to961 within the actual
joint-context limit1024. Activity is not counted again in downstream voices whose
actions the rhythm has already fixed. These weights cannot override a hard bound or
the guide. Therefore the guide can fix the very rhythm/harmony a preference
would otherwise change. Pitch bounds select from the existing vocabulary; they
do not transpose or invent notes. Incompatible choices fail explicitly.

These controls currently address the three pitched parts. Percussion keeps its
own explicit rhythm-dependent provider, velocity vocabulary and sound recipes.
Sounds/mix and saved sound starting points remain separate controls.

## Editable affect starting points

The authored helper's shared mapping sets control numbers; it does not generate
or learn. Its Studio entrypoint is part of the open optional-laboratory task:

- Energy0..100 → velocity50..150% (`50 + energy`).
- Density0..100 → attack bias−100..100 (`2 × (density − 50)`).
- Tension0..100 → chord-root bias+100..−100 (`2 × (50 − tension)`).

At50/50/50 those three mappings are neutral. They are Experimental hypotheses,
not measured affect or mood inference. Edit any mapped number afterwards. Only
the resulting actual controls enter the job recipe; the helper is not a hidden
preset or an extra solver pass. A job's details display the saved values.

## Shared implementation and scope

[pythian.music.controls](../src/pythian.music.controls.pas) owns portable values,
validation, affect mapping and detached note expression. Expression preserves
pitch, attacks, source indices and the tempo map. It does not edit accepted WFC
tokens. Shorter gates may shorten the final release tail; compare performances
on a common timeline rather than assuming equal file lengths.

[pythian.wfc.instrumental.controls](../adapters/wfc/pythian.wfc.instrumental.controls.pas)
compiles bounds/preferences against supplied models and intersects existing masks.
Its role order is the config's actual order, after harmony/rhythm. Empty outer
vectors mean no edits; neutral controls do not stage empty edits on every provider.
It reuses the primary layer foundation's detached mask copier, shared with named
sessions. No solver or learning engine
is duplicated, and source models/masks remain borrowed and unchanged.

Studio saves actual controls with request/plan/result lineage. Save queues no
generation. A new Generate learns from the selected sources and constructs models;
the explicit follow-ups below reuse the accepted models/score without learning.

The library now has [retained-score reperformance](INSTRUMENTAL.md#retain-the-score-while-changing-sound):
change selected pitched instruments/expressions while keeping the graph and other
parts exact, without constructing/learning/solving models. `CopyScore` exposes the
original gates and `CopyNotes` the performed gates. Studio Change sounds uses the
durable decision replayer to replace selected pitched instruments without changing
the score. The full expression interface remains a library capability pending
the optional laboratory consumer.

Named-voice and layer sessions now support [accepted-state snapshots](ACCEPTED-SESSIONS.md)
that preserve real model text, controls and generated-versus-locked ownership.
Restoring rebuilds configuration and checks the saved musical result without
learning or solving. Change notes reconstructs bounded graphs from verified saved
models and latent states, then solves only the requested dependency closure.
Unselected parts and cells outside the passage remain exact. Chord/rhythm changes
require explicit permission; pitch bounds select existing notes and cannot invent
or transpose a vocabulary. Drums can be selected separately. Expression remains
neutral during this graph edit.

Both follow-ups preserve Original reference, actual Before/After, source and
learning lineage, and a recoverable parent. They can themselves be edited again.
No changed solution is guaranteed: Studio reports a valid unchanged result, or a
visible conflict. Cancellation/failure publishes no accepted partial performance.
See [accepted sessions](ACCEPTED-SESSIONS.md#current-boundary) for chunk boundaries
and the limit on cross-chunk backtracking. Full graph visualization, broader sound
recipes and the optional authored laboratory remain distinct open tasks.
