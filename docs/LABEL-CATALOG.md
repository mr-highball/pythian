# Prepared WAV catalog import

[Work record](WORK.md) · [Native catalog task](TODO/NS-3_labeling_01.md) ·
[Browser workbench task](TODO/NS-6_authoring_01.md)

This is the first native boundary of the label workbench. It stores source WAVs
and metadata only. It does not infer labels, mark audio as reviewed, or export
training data yet.

The agent prepares an inbox directory with WAV files and `manifest.json`:

```json
{
  "version": 1,
  "tracks": [
    {
      "file": "performance.wav",
      "sha256": "lowercase-64-character-sha256-of-the-prepared-wav",
      "title": "Performance title",
      "source_group": "recording-session-1",
      "partition": "unassigned",
      "provenance": "Where this exact WAV came from",
      "license": "Usage terms for this exact WAV",
      "clock_id": "optional-synchronized-stem-clock"
    }
  ]
}
```

`file` is a basename within the inbox. Each import checks the WAV hash and
supported format, then copies and verifies it in a separately configured
catalog root. The catalog root must be durable and **outside `build/`**. Import
the entire manifest with one command:

```powershell
& 'build/<target>/pythian.label.catalog.exe' import 'D:\path\to\inbox' 'D:\path\to\catalog'
& 'build/<target>/pythian.label.catalog.exe' list 'D:\path\to\catalog'
& 'build/<target>/pythian.label.catalog.exe' waveform 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME BINS
& 'build/<target>/pythian.label.catalog.exe' audio 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME 'D:\path\to\region.wav'
& 'build/<target>/pythian.label.catalog.exe' review 'D:\path\to\catalog' 'D:\path\to\transaction.json'
& 'build/<target>/pythian.label.catalog.exe' history 'D:\path\to\catalog' SOURCE_SHA256 FIRST_REVISION COUNT
& 'build/<target>/pythian.label.catalog.exe' current 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME COUNT
& 'build/<target>/pythian.label.catalog.exe' propose-beats 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME
```

The import report gives each track an `imported`, `duplicate`, or `failed`
status. One bad track does not discard successful tracks; any failed track makes
the process exit with code 1. A second import of the same packet reports
duplicates. The catalog stores each source under `sources/<sha256>.wav` and a
corresponding `tracks/<sha256>.json` record. Listing is sorted by source hash.

Partition is `training`, `development`, `evaluation`, or `unassigned`. Every
track in one `source_group` must have the same partition. `clock_id` is used
only for stems that truly share a source frame clock; unrelated recordings
leave it out and must never be aligned merely because their durations match.
Source group and partition are import metadata, not acoustic labels.

`waveform` returns per-bin minimum and maximum sample values across the
source's channels, with exact half-open source-frame bounds. Each call covers
at most 8,388,608 frames and 2,048 bins. The client can navigate a long source
in pages. `audio` emits an original-region PCM16 listening WAV for at most
30 seconds and 16 MiB; it stages the output before publication and refuses to
replace an existing file. Both read the source sequentially in bounded blocks.

`review` currently accepts one explicit label edit per transaction. The
transaction must name the original source hash, expected revision and reviewer.
Its `change` names a stable `label_id`, a half-open source-frame span, label
`type`, `value` and `status`:

```json
{
  "version": 1,
  "source_sha256": "lowercase-64-character-sha256-of-the-prepared-wav",
  "expected_revision": 0,
  "reviewer": "operator-id",
  "change": {
    "label_id": "note-1",
    "type": "note",
    "value": "C4",
    "status": "approved",
    "start_frame": 1000,
    "end_frame": 2000,
    "pitch_midi": 60,
    "part": "lead"
  }
}
```

Supported types are `beat`, `downbeat`, `note`, `presence`, `part_role`,
`source_role`, `phrase`, `section`, `style_preference`, and versioned `ext.*`
types. `presence` values are `audible`, `rest`, or `unknown`. Status is
`approved`, `uncertain`, `rejected`, or `withdrawn`. Rejection requires a
`proposal_id`. Reusing a `label_id` with the next expected revision edits its
state; restoring an earlier state is another auditable edit. Each successful
review is an immutable `reviews/<source hash>/<revision>.json` file. The
`history` command pages through those events. Source bytes are SHA-256 checked
before every current CLI edit, which is costly for multi-hour recordings; the
future persistent service needs a safely retained verification cache.

`current` projects the latest event for each label identity overlapping a
source-frame window, retaining `rejected`, `uncertain` and `withdrawn` states
visibly apart from `approved`. It is bounded to 2,048 returned labels per page;
it currently replays the whole source history for each request.

`propose-beats` analyzes a bounded source window with Pythian's native onset
and beat-grid path. It stores a separate packet under `proposals/<source hash>/`
with source-frame observations, candidate pulse frames, analyzer/model/policy
identity and an explicit `unreviewed` status. The window is at most 30 seconds
and 2,000,000 frames. These are pulse hypotheses; they do not identify
downbeats or establish a correct musical beat. A review that names a
`proposal_id` must now reference a candidate in the stored packet. Import and
proposal generation never write review events.

These commands exercise storage and schema, not an operator-approved corpus.
No review event is produced automatically during import. The CLI does not yet
export reviewed labels or provide blind evaluation and browser controls.

The native HTTP service and its waveform, region-audio, proposal and review
endpoints, reviewed export, and pas2js interface remain work in the linked
tasks. Do not train from source records, proposals or test review events alone.
