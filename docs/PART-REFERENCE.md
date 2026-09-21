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

### Pitch identity in an acoustic reference

For the initial WAV packet, an event's integer `note` identifies its supported
musical fundamental in the existing equal-tempered MIDI coordinate system
(A4 = 440 Hz). It is not necessarily the key sent to the source renderer. The
builder validates the supplied coordinate, not its acoustic interpretation.
Retain the following distinctions in the hash-bound annotation evidence:

| Evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Original score key/event | Declared symbolic intent and source identity | The actual sounding register or acoustic endpoints |
| Separated MIDI key/event | The recorded renderer trigger and symbolic gate | Identity with the original key or waveform fundamental |
| Verified event transformation | Correspondence under a declared source rule, clocks and velocity | A universal inverse mapping, renderer history or acoustic truth |
| Isolated waveform support | Observed spectral/temporal evidence on the bound samples | A complete note set from its strongest peak alone |
| Reviewed acoustic note/role | The annotation justified over its declared supported scope | Unreviewed notes, other contributors or independent acceptance |

An octave-different component is not automatically an extra musical note or an
estimator error. A source may use register mapping or layered timbre; conversely,
a prominent harmonic need not be the fundamental. Preserve alternatives where
the note interpretation is unresolved. Never select the reference register to
agree with predictions, copy a renderer key by default, or apply a dataset-wide
octave correction after observing a few cases.

Source correspondence must be decided without using pitch agreement to choose
the matching source: use declared track/channel/program identity and exact
event-time/velocity evidence first, retaining ties, omissions and uncertainty.
If clocks or endpoints fail a predeclared comparison, report that mismatch;
do not fit an offset or widen a tolerance to certify correspondence. Any actual
source transformation remains in provenance rather than modifying the source.

The [fixed acoustic review](PART-EVALUATION.md#fixed-acoustic-support-review--2026-09-21)
demonstrates why these distinctions matter. A bass source has components beneath
its nominal keys; an organ source retains sub-octave components with an unresolved
registration interpretation. The subsequent
[verified bass correspondence](PART-EVALUATION.md#original-to-trigger-bass-correspondence--2026-09-21)
finds both 43 and 31 mapping to trigger 55; neither a universal inverse nor the
separate organ case is qualified. Keep uncertain event intervals/regions excluded under
the existing scorer, and retain any supported source-function annotation without
claiming complete role pitch sets.

These rules clarify the existing reference meaning. They add no format version,
automatic correction, acceptance threshold, dependency or completion criterion.
The editing input below stays unchanged; richer original/trigger/acoustic evidence
belongs in the bound annotation record, not competing meanings of `note`.

### Stored-signal endpoints

For an isolated reviewed event, a reference may explicitly use the first stored
nonzero sample and one past the last stored nonzero sample as half-open endpoints.
Record that convention and the source preparation: quantization can shorten
support, and a release can extend beyond the symbolic key gate. This convention
does not measure perceptual duration or recover the unquantized waveform.

Retain maximal exact-zero runs and the rule used to group support across shorter
gaps. A zero crossing is not an event boundary; even a sustained zero run does
not by itself establish pitch, role or a new musical event. Use separate acoustic
identity and source-correspondence evidence. Joined tails, multiple plausible
contributors and observation edges leave individual endpoints unresolved.

A reference for one isolated stem describes only that source's contribution.
It cannot certify the full mixture's role pitch set, silence or ownership when
other contributors are unreviewed. Keep the complete source-event ledger beside
the editing input, including events that cannot be represented as known intervals.
Their regions stay uncertain rather than becoming inferred rests. Exporting a
valid incomplete reference does not establish complete-reference accuracy.

### Command and editing input

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

## Assembled development reference cases

The [accepted development packet](PART-EVALUATION.md#assembled-external-development-cases--2026-09-21)
uses this builder and the maintained `pythian.evaluate CASE.json` operator without
a new reference or case format. Its manifest SHA256 is
`8a43ce9a433df6bddd00d98bea302601907a87d9cf5f4aa9a3d8ac03fa78c4c3`.
The frozen source-local reference retains one reviewed bass event, all 800 centers,
three source-local rests and explicit unknown regions. The complete contributor
inventory prevents that isolated contribution from becoming a complete mixture
reference; all four mixture-role references remain unknown.

`bass-copy-case.json`, `bass-omit-case.json` and `mix-contribution-case.json` bundle
all relative scoring inputs, including annotation/scoring policies and exposure
ledgers. Their scripted predictions explicitly depend on the reference evidence.
Copying the folder preserves scoring; the maintained CLI was verified from an
outside-repository working directory. Exit zero establishes a valid report, not
passing metrics or independent acceptance. All three metric/independence verdicts
remain false, including the copied note's numerically exact match.

The accompanying preparation, worksheet and spectral/view manifests preserve
upstream identities. Their full-length source files and raw spectra are external
provenance inputs, not implicitly bundled reconstruction assets. All ten excerpt
stems, the exact derived mix and complete source notices are included unchanged.
Repository units remain the compilation dependency for the copied implementation
snapshots. The packet README gives the distinction and reproduction commands;
[scoring commands and measured results](PART-EVALUATION.md#assembled-external-development-cases--2026-09-21)
are documented alongside the current coverage audit.

This accepts policy application to the assembled incomplete development cases
(AC4). It neither fills the remaining external annotation/scenario gaps nor
qualifies a reserved evaluation family. The external-packet task remains open
without additional completion credit.

## Verification

Final checked stable Win32/Win64 builder and complete file fixtures pass with
zero leaks. The changed CLI also passes: a generated ten-center reference retains
the expected two lead and six chordal timing matches through the current scorer.
Authored controls exercise complete grids, half-open endpoints, chords, repeated
pitches, uncertainty, known gaps, unassigned ownership, input/result preservation
and contradictory regions/IDs. Wrong draft identity, WAV clock and omitted initial
grid points reject. Commands and source identities remain in `build/qa-batch-18/`.
These checks accept reference construction, not external acoustic or role truth.
