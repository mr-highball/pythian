# Reopen accepted musical sessions

[Musical controls](MUSICAL-CONTROLS.md) · [Named voices](INDEPENDENT-VOICES.md) ·
[Instrumental runtime](INSTRUMENTAL.md) ·
[Restoration task — DONE](TODO/DONE/NS-4_assignment-restore_01.md)

`TNamedVoiceSession` and `TLearnedLayerSession` expose `CopyAcceptedSnapshot`
and static `FromAcceptedSnapshot`. These Pascal records retain the actual
accepted graph assignments, canonical provider model text, committed controls,
configuration and dependencies. Generated choices remain generated choices;
caller locks remain locks. Setting public graph values would lose that distinction
and obstruct later regeneration.

The source must have an accepted result and no pending edits. Accept those edits
or retain them separately before taking a snapshot; export never silently drops
them. Returned nested arrays are detached. Model pointer fields are deliberately
nil: the records carry canonical model text rather than borrowed object addresses.
Restored sessions own their decoded/cloned models. The source session, its
original models and the snapshot can be released independently afterwards.

```pascal
Archive := Session.CopyAcceptedSnapshot(Progress);
Resumed := TNamedVoiceSession.FromAcceptedSnapshot(Archive, Progress);
try
  Music := Resumed.CopyAccepted;
  { Explicitly stage a supported edit, then use ordinary selective solving. }
  Resumed.SetConstraints('lead', NewLeadMask);
  if not Resumed.TryRegenerate(['lead'], 731, Music, Search, Proof, Progress) then
    raise EAudio.Create('The requested Lead choices do not fit');
finally
  Resumed.Free;
end;
```

The layer API has the same snapshot pair. Its snapshot includes projections,
scopes, tick partitions and preferences. Ordinary `TryRegenerate` still determines
the actual dependency closure. An unrelated accepted part stays exact; a dependent
part may need to change. A fresh explicit regeneration seed supplies its random
stream. These snapshots are not RNG checkpoints or proof that an arbitrary
caller-edited graph is musically valid.

## Work, validation and failure

Restoration decodes model text, constructs matching configuration and restores
assignments. It does **not** learn models or search for new notes. The existing
independent model/path/domain and musical/projection checks must pass before a
session is returned. Unknown values, wrong layouts/counts, incompatible controls,
unsupported versions and borrowed model pointers are rejected.

Model text and assignment text each have a separate 16,777,216 string-unit budget;
assignments also use the existing 262,144 state-cell limit. String units are an
in-process bound, not an encoded file-byte size. Normal provider, vocabulary,
projection and preparation budgets still apply. Snapshots currently use version1.

Progress callbacks are borrowed for each call. Copy/decode and structural restore
work are visible; phase counts are local work, not overall generation percentages.
Callbacks must not mutate/free inputs or reenter a source operation. Cancellation,
validation failure or a final readiness exception returns no partial session and
leaves the source intact. Ordinary solve/proof/publication behavior remains shared.

## Current boundary

These are portable typed Pascal records, exercised by native and actual pas2js
consumers. They are not an on-disk finite instrumental archive or a Studio follow-up.
Ordinary streamed playlist jobs now retain their actual provider tokens/latent
states and performed chord timeline in the separate primary
[decision journal/replayer](INSTRUMENTAL.md#retain-and-replay-a-performed-timeline).
That bounded score replays through instruments without learning or solving; it
does not itself restore a live editable graph. Studio's optional Change sounds
and Change notes actions use durable child jobs over that retained result.
Existing jobs without retained decisions do not acquire their
missing state indices retroactively. Ordinary Generate still makes new decisions.

The portable `pythian.wfc.instrumental.edit` adapter now reconstructs one bounded
decision chunk using the accepted immutable models, actual predecessor/successor
provider rows and the existing WFC builders. `TryEditInstrumentalPassageChunk`
proves the original paths, context projections, harmonic coverage and performed
parts before searching. Generated assignment ownership survives restoration.
The request selects ordered pitched/drum parts and an absolute sample-frame
passage; overlapping cells snap outward and report their actual bounds.
Unselected providers and outside-range cells retain exact latent states/tokens.
Pitch bounds constrain selected parts; explicit harmony/rhythm flags allow those
providers to change. Existing control compilation supplies soft root/activity
preferences. Expression stays neutral here; retained-score performance owns it.

Context, named voices/coverage and rhythm-conditioned drums keep the same ordered
groups as initial generation. Primary WFC dependency closure and independent
captures own solving and verification. `TInstrumentalPassageEdges` separates
the original neighboring chunks from the actual preceding edited chunk. Original
paths are proved against original neighbors; candidate paths continue from the
candidate predecessor. The next original seam is held only outside the requested
passage. Internal planning boundaries do not pin original choices inside it.
Some requests still have no valid continuation. False or an exception preserves
the caller's previous candidate; no constraint is silently removed. The adapter
does not promise every seed changes the notes, global backtracking across planning
chunks or a uniform draw over all group combinations.

This call borrows models and a synchronous progress callback. It performs no
learning/source-audio reads and returns no partial candidate after cancellation.
It does not authorize arbitrary stored observations: native consumers still must
bind the complete source journal and models to the accepted job receipt. The
native adapter verifies the parent/root model and journal hashes before editing,
stages bounded chunks and publishes only after the complete edit and render pass.
Change notes retains instruments, rendering randomness, source lineage and
learning receipts. Change sounds retains the accepted notes. Both can be followed
by further edits. A failed or cancelled child leaves its parent available.
Before/After and individual-part playback compare actual saved performances.
The [graph-controls task](TODO/DONE/NS-4_graph-controls_01.md) and its optional
authored/affect UI consumer are accepted. These operations do not imply musical
quality approval or universal edit solvability.

Studio now uses `TInstrumentalPassageStream` from
`pythian.wfc.instrumental.edit.stream`. It proves kept future accompaniment in a
bounded window through the same finite editor, then returns only the next
original journal prefix. Later selected choices remain provisional. The default
256cell ceiling is reduced by the actual model-state budget and can be lowered
by a caller; the reader retains at most one window plus one original chunk.
This repairs the retained48second authored source's original failed32..48second
Lead edit with its exact seed and controls. Unselected states and all five other
PCM stems remain exact. No duration-sized score, new solver, learning or source
audio scan is introduced. The full source journal still needs its accepted receipt.

The generic assignment operation lives in the separate WFC branch
[`codex/pythian-accepted-assignments`](https://github.com/mr-highball/wfc/tree/codex/pythian-accepted-assignments),
commit `b04a9e4e26130c5e00ae0c7100dfc34be99576c4`.
Musical configuration, model text, independent musical validation and session
ownership remain Pythian adapter responsibilities. Core-only use has no WFC import.
