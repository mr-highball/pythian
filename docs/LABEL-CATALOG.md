# Prepared WAV catalog import

[Work record](WORK.md) · [Native catalog task](TODO/NS-3_labeling_01.md) ·
[Browser workbench task](TODO/NS-6_authoring_01.md)

The catalog stores original WAVs, source metadata, separate Pascal proposals,
explicit operator review events, and a reviewed export packet. A prepared
inbox or a proposal alone never becomes a reviewed training label.

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
& 'build/<target>/pythian.label.catalog.exe' inbox 'D:\path\to\inbox'
& 'build/<target>/pythian.label.catalog.exe' waveform 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME BINS
& 'build/<target>/pythian.label.catalog.exe' audio 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME 'D:\path\to\region.wav'
& 'build/<target>/pythian.label.catalog.exe' review 'D:\path\to\catalog' 'D:\path\to\transaction.json'
& 'build/<target>/pythian.label.catalog.exe' history 'D:\path\to\catalog' SOURCE_SHA256 FIRST_REVISION COUNT
& 'build/<target>/pythian.label.catalog.exe' current 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME COUNT
& 'build/<target>/pythian.label.catalog.exe' propose-beats 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME
& 'build/<target>/pythian.label.catalog.exe' proposals 'D:\path\to\catalog' SOURCE_SHA256 START_FRAME END_FRAME
& 'build/<target>/pythian.label.catalog.exe' export 'D:\path\to\catalog' 'D:\path\to\reviewed.json'
& 'build/<target>/pythian.label.catalog.exe' inspect-export 'D:\path\to\reviewed.json'
& 'build/<target>/pythian.label.catalog.exe' import-reviewed 'D:\path\to\fresh-catalog' 'D:\path\to\reviewed.json'
& 'build/<target>/pythian.label.catalog.exe' serve 'D:\path\to\inbox' 'D:\path\to\catalog' 18085
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

`inbox` previews the bounded prepared manifest with per-row
`prepared_unverified`, `missing` or `invalid` status. It does not hash the WAV,
resolve a catalog partition conflict or import a track; `import` performs those
checks. `proposals` reads a previously published source/window packet without
rerunning inference. It checks the packet's source, policy, evidence frames and
candidate identities before returning them or accepting a linked review.

`export` writes one version-1, `pythian.reviewed-catalog.v1` packet without
source audio. Each source carries its original SHA-256, geometry, group,
partition, provenance, license and full numbered review history. Its
`linked_proposals` array carries only the stored, unreviewed proposal packets
referenced by that source's review history. The reader checks every referenced
candidate ID against the linked packet and rejects missing or changed evidence.
The `selected_labels` array contains only current approved labels for an assigned
training, development or evaluation group. Approved `presence=unknown` labels
go into `unknown_labels` instead. Uncertain, rejected and withdrawn decisions
remain in history, outside the selected set. The writer verifies every source
WAV hash and rejects a group crossing partitions before publishing. It refuses
to overwrite an existing packet and stages the bounded, at-most-64-MiB output.
The report gives the packet SHA-256. `inspect-export` uses the Pascal packet
reader to replay history, check group separation and selected-label meaning,
and report counts. A consumer can call `ReadReviewedCatalogPacket` directly.
This current single-file limit may require sharding for larger catalogs;
training-tool integration remains open.

The Pascal evaluation tool can turn a packet's independently reviewed presence
spans into a source-bound evaluation reference:

```powershell
& 'build/<target>/pythian.evaluate.exe' --build-reviewed-presence-reference 'D:\path\to\plan.json' 'D:\path\to\reviewed.json' 'D:\path\to\original.wav' > 'D:\path\to\presence-reference.json'
```

The version-1 `pythian-reviewed-presence-reference-plan` contains
`packet_sha256`, `source_sha256`, `source_group`, `partition`, `part`,
`preparation_sha256`, `scoring_policy_sha256`, `annotation_policy_sha256`,
`first_frame`, `end_frame`, `first_center` and `hop_frames`. The plan must bind
the actual evaluator policy and preparation files used by its case. The builder
checks packet/source bytes and group assignment, rejects proposal-linked
presence as an independent reference, and emits a bounded center grid. Reviewed
`audible` becomes vocabulary index zero, reviewed `rest` stays rest, missing or
explicit unknown spans stay unknown, and overlapping labels are ambiguous.
At least one center must have reviewed audible/rest evidence. A partial grid
requires `reference_complete=false` in the evaluation case; the reference
alone does not establish acoustic truth or independence. Keep the packet hash
in the case's evidence ledger or equivalent provenance record.

`import-reviewed` replays a validated packet into a catalog that already owns
the exact original WAVs and source records. It verifies each WAV hash and all
source metadata before writing. It stages linked proposal packets and numbered
review events, publishes proposals first, then reviews, and refuses to replace
a different review tree. Repeating an identical replay reports `duplicate`.
An interruption between the two directory publications can leave unreviewed
proposal evidence; retrying the same packet can finish the review publication.
The command does not turn unreviewed proposals into selected labels.

These commands exercise storage and schema, not an operator-approved corpus.
No review event is produced automatically during source import. Full browser
editing remains open.

The first native HTTP host has fixed routes for session, prepared inbox,
catalog, stored proposals, waveform, current labels, history, region audio,
import, review, beat proposals and the reviewed packet download. It
binds only the specified loopback or private LAN IPv4 address, never all
interfaces. The inbox and catalog roots are process arguments, not URL paths.
`GET /api/session` provides a local loopback token. LAN mode requires a secret
of at least 16 characters in `PYTHIAN_CATALOG_ACCESS_KEY`; clients submit it
as JSON to `POST /api/session` and send the returned `X-Pythian-Token` header
on every subsequent request. The access key and token must stay out of URLs.
LAN HTTP is not encrypted, so use only a trusted local network. `serve-app`
serves the Pascal/pas2js page on the same origin with an access-key form.
`GET /api/export` sends the same bounded, deterministic, audio-free packet as
the native CLI. Evaluation proposal reads and generation return 403 until the
first approved or uncertain, proposal-free review commits for that source;
the CLI follows the same rule. Proposal-linked first reviews are rejected. Do not
train from source records, proposals or test review events alone.
`POST /api/import-reviewed` accepts a JSON packet of at most 64 MiB after the
same session-token check. It validates and replays into the configured catalog
using the CLI's source-hash and conflict rules. The browser's file picker sends
the packet; the original WAVs must already be imported into that catalog.

For explicit LAN binding, set the secret in the server process before startup:

```powershell
$env:PYTHIAN_CATALOG_ACCESS_KEY = Read-Host 'Catalog access key (16+ characters)'
& 'build/<target>/pythian.label.catalog.exe' serve 'D:\path\to\inbox' 'D:\path\to\catalog' '<LAN_IPV4>' 18085
```

The browser workbench is built with
`powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-label-workbench.ps1`.
Start it on the chosen interface with the same secret:

```powershell
& 'build/<target>/pythian.label.catalog.exe' serve-app 'D:\path\to\inbox' 'D:\path\to\catalog' 'build\label-workbench\www' '<LAN_IPV4>' 18095
```

Open `http://<LAN_IPV4>:18095/` and enter the secret in the page. The server
accepts only three named static assets and keeps catalog routes behind its
session token. After a successful LAN login, the Pascal browser app saves the
access key in this browser's local storage for that origin and automatically
requests a new session on later visits. Use **Forget this device** to remove
the saved key and clear the current page session. This convenience is for a
trusted device on a trusted LAN: browser storage holds the key as readable
text, and LAN HTTP is unencrypted. Clearing browser site data also removes it;
changing the host address or port creates a different browser origin and
requires entering the key again. The bind address must belong to the host,
such as its Wi-Fi address. A local firewall may need to allow the chosen port
before a phone can connect. The current browser slice supports bounded source
listening, basic review, source-level blind reveal, reviewed packet download
and re-import.
Full authoring controls remain open in
[NS-6_authoring_01](TODO/NS-6_authoring_01.md). Store a real operator catalog
outside `build/`; the catalog under `build/label-catalog/` is a test fixture.
