# Experimental musical form

[Instrumental runtime](INSTRUMENTAL.md) · [Current task](TODO/NS-5_musical-form_01.md)

The shared library accepts an explicit caller-authored section/phrase arrangement.
It generates instrumental decisions through actual WFC providers and performs them
through one continuous Pythian stream. This is a library capability under active
development. Studio arrangement controls, saved form recipes, section audition,
per-section energy/density and targeted form regeneration are still required.

## Explicit musical inputs

[pythian.music.form](../src/pythian.music.form.pas) is portable and independent of
WFC, devices and browser APIs. A `TMusicForm` contains ordered `TMusicFormPhrase`
records:

| Field | Meaning |
| --- | --- |
| Section / Name | Caller-supplied section and phrase names, not inferred structural labels |
| Cells | Phrase length in the stream's musical quantum; default240ticks at480PPQ means eighth notes |
| RepeatFrom | Earlier phrase index, or−1 for newly generated material |
| Keep | Actual provider names whose public musical choices must recur |

Lengths may differ; a retained phrase has the same length as its source. A repeat
must explicitly retain at least one provider. Names must exist in the producer's
provider layout. The cursor owns detached inputs, validates sequential cell/frame
clocks and refuses changed retained choices. Source latent indices remain
provenance; they are never installed as authoritative future solver states.

The plan permits up to4096 phrases of1–256cells each. Only later-referenced
phrases are cached: at most1024cells and2MiB of canonical UTF-8 token/name data.
No duration-sized PCM or complete score is retained by the form cursor. The
ordinary stream's time, voice, work and model-state limits also apply.

## Actual WFC and performance behavior

Pass the form as the final argument to `TInstrumentalMusicStream.Create`, after
the optional decision sink. Omitting it preserves the existing stream path.

```pascal
SetLength(LForm, 3);
LForm[0].Section := 'Verse';
LForm[0].Name := 'A';
LForm[0].Cells := 64;
LForm[0].RepeatFrom := -1;
LForm[1].Section := 'Contrast';
LForm[1].Name := 'B';
LForm[1].Cells := 64;
LForm[1].RepeatFrom := -1;
LForm[2].Section := 'Return';
LForm[2].Name := 'A variation';
LForm[2].Cells := 64;
LForm[2].RepeatFrom := 0;
SetLength(LForm[2].Keep, 2);
LForm[2].Keep[0] := 'lead';
LForm[2].Keep[1] := 'hat';
```

Retained harmony, rhythm and pitched-role choices enter the existing named-voice
graph's token domains. Drum choices enter their actual rhythm-conditioned
sequence domains. Context uses the primary musical projection to honor matching
locks, including the rhythms permitted by retained drum events. Each producer
generates and independently validates its new latent path against its real
predecessor. Other providers remain generated; no captured note/PCM block is
pasted over a different accompaniment.

Instrumental solve windows divide the declared phrase lengths. Context and drum
passes can plan up to256cells, also bounded by their state budget, to fit known
upcoming returns before committing a contrast. Planning stops when a needed
source motif must first finish. Unknown future motifs are never invented.
`ContextLookaheadCells` exposes that limit; `PlannedCells` includes the actual
already-fixed context/drum lookahead. Future edits cannot overwrite it.

The primary instrument scheduler, oscillator/filter/envelope state and effects
continue across every phrase. A repeated musical motif need not have identical
PCM: its instruments perform again within that continuous sound/effect history.
The decision sink retains the actual newly generated states and musical cells.

## Rejection and current limits

An arbitrary captured phrase is not necessarily a loop. The maintained fixture's
adjacent A-return/A-variation request rejects because the captured Hat motif cannot
close into itself. A separate primary cyclic graph confirms that contradiction.
The same models/seed can generate the explicit five-section A/B/A-return/bridge/
A-variation arrangement. Keep rejected material; do not silently change a seed,
remove a retained part or invent a transition to claim success.

Planning is bounded and conditional, with no cross-group/global backtracking
guarantee. A separate no-context authored-guide probe with8/16cell phrases fails
at cell16. Its native/pas2js request and failure are retained under
`musical-form-20261031-boss`; investigate it before accepting the full form task.
The verified sustained form consumer currently supplies an explicit authored
musical-context model. This is not recording-derived structure learning, proof
that all arrangements fit, or a musical-quality verdict.
