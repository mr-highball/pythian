# Preparing reviewed role references

[Role evaluation](PART-EVALUATION.md) · [Interval timing](OVERLAPPING-NOTES.md) ·
[File operator](EVALUATION-OPERATOR.md) · [Task](TODO/NS-3_parts_01.md)

`pythian.evaluation.reference.BuildPartReferenceCells` expands explicitly supplied
note intervals and complete annotation regions into the center cells consumed by
the existing role scorer. The caller enters reference truth once. The builder
does not transcribe WAV, read MIDI, infer roles or verify annotation independence.

## Native contract

Pass ordered role IDs, one `TPartNoteReference` per role, optional unassigned
intervals, source frame count, half-open scope, first center and hop. Each role
uses the existing `TEvaluationNotes` and `TEvaluationNoteRegions` types. Event IDs
are unique across roles and unassigned events. All events stay inside the source;
they may cross the evaluation scope's boundaries without being clipped.

Regions partition the whole scope. `value` explicitly asserts complete exact
notes, including gaps: active half-open events produce sorted pitch unions, and
empty known gaps become `rest` cells. An explicit `rest` rejects any intersecting
event, even between centers. Unknown, ambiguous and unsupported regions retain
their exact states and empty sets. Incomplete annotations must not be declared
complete merely to obtain rest labels. Unassigned intervals preserve explicitly
known pitches with unknown owners; uncertain role events are not automatically
copied there or credited to a role.

Repeated same-pitch events collapse only in center sets; original intervals and
IDs remain unchanged. Events crossing uncertainty can appear at known centers;
the interval scorer separately retains its whole-event uncertainty exclusion.
Centers are `first_center + n * hop < end_frame`, starting in the scope's first
hop. Every declared grid point is emitted. Scope `[100,900)`, first center 150
and hop 100 produce eight centers, 150 through 850. This is complete grid coverage,
not measurement at every audio frame.

Inputs are borrowed and unchanged; result cells own separate pitch arrays.
`EAudio` rejection preserves an earlier assigned result. Authoritative interval
validation is reused with empty predictions and zero matching allowance. Internal
validation results are not accuracy or acceptance claims.

Limits: 32 roles, 4096 combined events, 16384 regions per role, 262144 centers,
1048576 role/center cells, 50000000 event/center comparisons, 16777216 event/region
checks including combined ID validation, and 2097152 output pitch entries.
The interval scorer's limit of 256 selected events per pitch per role applies.
Scope is at most 10^12 frames within the existing 2^53-1 source-frame envelope.
This is bounded offline allocation, not a device callback interface.

## File consumer

```text
pythian.evaluate --build-part-reference DRAFT.json DRAFT_SHA256 SOURCE.wav
```

The current `pythian-evaluation-reference` JSON is returned on stdout only after
validation. The operator writes no files; shell redirection may create/truncate
its destination before the command runs.

| Exact draft field | Contract |
| --- | --- |
| `format` | `pythian-part-reference-draft` |
| `clock` | Current reference clock: source/preparation/scoring-policy hashes, sample rate, source frames, first/end frames |
| `annotation_policy_sha256` | Declared annotation policy's lowercase SHA256 |
| `first_center`, `hop_frames` | Integer coordinates in source frames |
| `timing` | Existing `role_id,regions,events` objects in scoring-vocabulary order |
| `unassigned_events` | `id,start_frame,end_frame,note` intervals with unknown owners; may be empty |
| `crossings` | Existing explicit crossing endpoints; may be empty |

This is one current editing input, not another persisted reference version or
historical reader. Output preserves clock, annotation policy, timing and crossings,
adding `observations`. Unassigned intervals supply center pitches only, with no
interval matching credit. Keep the hash-bound draft as annotation evidence.

The draft digest and WAV digest/geometry must match; source bytes are hashed again
after expansion while held open against ordinary writes. This checks identity
and clock, not acoustic truth or the contents of policies named only by hash.
Ordinary case evaluation still verifies its policy files, role order and ancestry.
Unexpected, duplicate or incorrectly typed fields reject, as do invalid crossings
on the generated grid. Crossing checks reuse the part scorer without publishing
a self-score as evidence. Additional file limits are 32768 role/center cells,
262144 pitch entries, 8 MiB documents and 1 GiB source WAV.

## Verification

Final checked stable Win32/Win64 builder and complete file fixtures pass with
zero leaks. The changed CLI also passes: a generated ten-center reference retains
the expected two lead and six chordal timing matches through the current scorer.
Authored controls exercise complete grids, half-open endpoints, chords, repeated
pitches, uncertainty, known gaps, unassigned ownership, input/result preservation
and contradictory regions/IDs. Wrong draft identity, WAV clock and omitted initial
grid points reject. Commands and source identities remain in `build/qa-batch-18/`.
These checks accept reference construction, not external acoustic or role truth.
