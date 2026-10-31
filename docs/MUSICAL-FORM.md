# Experimental musical form

[Instrumental runtime](INSTRUMENTAL.md) · [Current task](TODO/NS-5_musical-form_01.md)

The shared library accepts an explicit caller-authored section/phrase arrangement.
It generates instrumental decisions through actual WFC providers and performs them
through one continuous Pythian stream. This is a library capability under active
development. The optional Studio laboratory now saves editable arrangements,
generates them through the bounded performer and auditions exact sections.
Per-section energy changes actual instrument attack strength. Section density
and actual operator listening remain required.

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
| EnergyOffset | Explicit −50..50 performance hypothesis; zero is neutral. Maps through the primary affect contract to50..150% attack velocity |

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

Pass the form after the optional decision sink in `TInstrumentalMusicStream.Create`.
An optional final `TInstrumentalDomainProvider` supplies local masks for an
absolute, bounded future range. It is borrowed and must outlive the stream;
it must not reenter it. The authored starter's `GuideMasksRange` uses the same
primary guide at the requested absolute time. Omitting both preserves the
existing stream path.

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

Instrumental solve windows divide the declared phrase lengths. Context, voice
and drum passes can plan up to256cells, also bounded by their state budgets, to
fit known upcoming returns before committing a contrast. Planning stops when a
needed source motif must first finish. Unknown future motifs are never invented.

Voice planning uses the companion's primary bounded future-domain stream. The
whole temporary window honors available future context and known retained motifs,
then passes independent proof. Only the current solve prefix is published; its
provisional suffix is discarded. `VoiceLookaheadCells` exposes the configured
limit and `LastVoicePlanningCells` the actual window checked. An8cell returned
prefix can therefore be checked against a24cell guided plan without publishing
or retaining all24cells. Hard restrictions remain hard; the stream does not
change seeds or raise search budgets to recover.

Context/drum pending choices differ: they are already fixed until consumed.
`ContextLookaheadCells` exposes the context limit; `PlannedCells` includes the
actual fixed context/drum lookahead and returned voice prefix. Future edits
cannot overwrite that extent, but may change a merely provisional voice suffix.

The primary instrument scheduler, oscillator/filter/envelope state and effects
continue across every phrase. A repeated musical motif need not have identical
PCM: its instruments perform again within that continuous sound/effect history.
The decision sink retains the actual newly generated states and musical cells.

Form version2 adds section energy. It changes instrument performance, not the
logical model tokens: a stronger return can keep exactly the same notes/rhythm.
Only new attacks receive the section's velocity mapping. A note held across the
boundary keeps its original velocity, envelope, source and effect state. This
authored hypothesis is not a learned or calibrated mood measurement.

Decision record version2 stores one explicit velocity expression per role/cell
beside the original logical parts and actual provider states. Both the live
stream and primary journal replay consume those expressions. Bounded copy,
join, slice and targeted note edits retain them; sound changes reuse the exact
journal. Gate shortening of an open held note is explicitly unsupported.
The framed journal format remains version1 and receipts identify the maximum
`record_version`. Source-only record version1 retains its original canonical
bytes; saved historical performances remain readable.

## Rejection and current limits

Studio's **Lab → Structure** arranges named sections. Choose new material or
repeat an earlier section, then choose which providers to keep. Length is in
four-beat bars; a repeat uses its source length. Moving a source after its repeat
is invalid, and deleting a referenced source is refused. Invalid edits survive
reload without replacing the last accepted settings. The shared portable cursor
validates the native transport and browser editor.

Generated results expose **Hear section**, **Change this section** and
**Hear whole track** through the existing player and passage editor. Native
section frame boundaries determine playback and edit ranges. Form metadata,
actual models, seeds, instruments and decision journals remain on the ordinary
immutable job; sound changes replay it without learning or solving again.
No context model is invented for authored material that has none.

Current structured jobs require neutral global activity/chord preferences and
100% global note strength/length. Section energy is independently editable from
0 soft through50 neutral to100 strong. Pitch bounds, instruments and mix remain
editable. Section density remains open. Ordinary unstructured experiments retain
their existing expression/preference controls.

The actual Studio48second A/B/A consumer retains all eight requested providers
in its return; the primary journal reader verifies the actual tokens. Playback
seeks to32seconds and pauses at48seconds. A six-second unequal-section consumer
also saves/reopens, replays changed sounds and changes six actual Lead cells
without recordings. The longer return-section Lead edit originally failed at
cell144 after an earlier candidate chunk committed. The primary streamed passage
editor now checks known future accompaniment before publishing each original
journal prefix. That exact original request/seed completes and changes24 actual
Lead cells; all five unselected PCM stems remain identical. The failed child and
its original playable parent remain preserved. No seed sweep or relaxed Keep is
used. Full form acceptance remains open.

[`TInstrumentalPassageStream`](../adapters/wfc/pythian.wfc.instrumental.edit.stream.pas)
borrows immutable models and a fresh primary decision reader. It calls the same
finite musical graph editor over a bounded window, returns only the next original
journal chunk and discards provisional later choices. Kept future providers and
outside-range states remain hard constraints. The window is at most256cells,
further limited by actual model-state capacity; callers may lower that ceiling.
Read-ahead retains at most that window plus one original chunk. No complete song
score or PCM is allocated. The single-window primitive remains usable.

The portable decision library owns detached adjacent musical views and exact
slices, so native and pas2js share clocks, predecessor and provider-order checks.
Studio no longer contains a separate chunk-by-chunk musical edit loop. Returned
prefixes are detached; cancellation or rejection is terminal and cannot publish
a partial current prefix. A caller binds the complete source journal to an
accepted receipt and publishes only after the iterator completes. This is bounded
conditional proof, not full-duration/global backtracking or a guarantee that
every feasible request will be found. Conflicts remain visible and preserved.

An arbitrary captured phrase is not necessarily a loop. The maintained fixture's
adjacent A-return/A-variation request rejects because the captured Hat motif cannot
close into itself. A separate primary cyclic graph confirms that contradiction.
The same models/seed can generate the explicit five-section A/B/A-return/bridge/
A-variation arrangement. Keep rejected material; do not silently change a seed,
remove a retained part or invent a transition to claim success.

Planning is bounded and conditional, with no cross-group/global backtracking
guarantee. The retained no-context authored guide with8/16cell phrases exposed a
generic short-prefix dead end at cell16 despite a feasible complete24cell graph.
The original failures stay under `musical-form-20261031-boss`; the accepted
[future-domain repair](TODO/DONE/NS-4_future-domains_01.md) and exact consumer live
under `form-frontier-20261031-boss`. Upstream CI63 and downstream CI533/packages
pass. The sustained
form consumer supplies an explicit authored context; the unequal-phrase consumer
uses the original authored guide without a context provider. This is not
recording-derived structure learning, proof that all arrangements fit, or a
musical-quality verdict. Studio arrangement controls retain their own open task.
