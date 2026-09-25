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

The native HTTP service and its waveform and region-audio endpoints, proposals,
review history, reviewed export, and pas2js interface remain work in the linked
tasks. Do not train from the source records alone.
