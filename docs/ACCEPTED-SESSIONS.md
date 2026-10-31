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
consumers. They are not yet an on-disk instrumental archive or a Studio follow-up.
Instrument/percussion recipes, performed expression and job lineage still need
their own shared archive integration. Existing Studio jobs do not acquire missing
latent state indices retroactively. Ordinary Generate still constructs a new plan.

The generic assignment operation lives in the separate WFC branch
[`codex/pythian-accepted-assignments`](https://github.com/mr-highball/wfc/tree/codex/pythian-accepted-assignments),
commit `b04a9e4e26130c5e00ae0c7100dfc34be99576c4`.
Musical configuration, model text, independent musical validation and session
ownership remain Pythian adapter responsibilities. Core-only use has no WFC import.
