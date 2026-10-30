# Musical controls

[Studio](OPERATOR-STUDIO.md) · [Instrumental runtime](INSTRUMENTAL.md) ·
[Current task](TODO/NS-4_graph-controls_01.md)

Generate → Musical controls exposes actual pitched-role constraints and performance
settings. These are explicit operator choices. They do not infer the meaning of a
free-text style label or promise a particular musical mood.

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

The optional helper sets visible numbers; it does not generate or learn:

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
It reuses the named session's detached mask copier. No solver or learning engine
is duplicated, and source models/masks remain borrowed and unchanged.

Studio saves the actual controls with request/plan/result lineage. Save and the
affect helper queue no work. Each explicit Generate still constructs models;
this slice does not yet retain an accepted score, selectively regenerate a role
or avoid model construction. Those requirements keep the linked task open.
