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

The native service, bounded waveform and region-audio endpoints, proposals,
review history, reviewed export, and pas2js interface remain work in the linked
tasks. Do not train from the source records alone.
