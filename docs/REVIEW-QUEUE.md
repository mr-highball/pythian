# Operator review queue

[Work](WORK.md) · [Authoring task](TODO/NS-6_authoring_01.md) ·
[Catalog task](TODO/DONE/NS-3_labeling_01.md)

The producer prepares a JSON request file after its source WAVs are imported,
then publishes it with:

```text
pythian.label.catalog queue-publish CATALOG_DIR REQUESTS.json
```

This validates every request against the imported catalog, writes a staged file
in the catalog root, and replaces `review-queue.json` only after validation.
An invalid batch leaves the previous manifest intact. The manifest is an input
list, not a label store. The native service validates it again on each read
against the imported source hashes, sample clocks and frame bounds. The Pascal
workbench shows only its pending requests. No user answer is written into the
manifest.

The manifest has `version: 1` and an `items` array of at most 256 requests.
Each item has a stable `id`, imported `source_sha256`, integer `start_frame`
and `end_frame`, and a specific `question`. `label_type` and short `title` are
optional. An interval is source-local and at most 30 seconds. Use a unique ID
for each decision; its source and request region bind the response. The
optional `answer_geometry` chooses how the saved label may use that region:

| Geometry | Saved label rule |
| --- | --- |
| `exact` (default) | Label start/end must equal the requested start/end. Use for presence and activity questions. |
| `point` | A `beat` or `downbeat` label is one source frame anywhere inside the requested region. Use when the operator must adjust a proposed marker. |
| `contained` | A declared span-type label may start/end anywhere inside the requested region. Use for key, tempo, meter, harmony, note or phrase boundary review. |

A declared type still has to match. A conflicting saved ID stays pending with
an `answer_conflict` for producer repair. The queue report includes
`current_start_frame` and `current_end_frame` for completed answers, so the
producer can consume the operator's corrected marker or span.

Use `presence` for the three choices `audible`, `rest`, and `unknown`.
Use `activity` when a pitch-independent source review must distinguish
`attack`, `continuation`, `release_tail`, `rest`, `noise_only`, and `unknown`.
The guided browser choices save one exact answer without requiring a MIDI pitch.
The detailed editor also accepts these source-bound types and values:

| Type | Value | Geometry |
| --- | --- | --- |
| `beat`, `downbeat` | Task-declared marker value | One source frame, `[frame, frame + 1)`, is the precise marker convention. |
| `key` | `C:major`, `F#:minor`, another declared root:mode, `no_key`, `unknown`, or `ambiguous` | Local tonal span; `no_key` is a positive reviewed non-tonal verdict, while `unknown` means the key could not be judged. Preserve gaps as separate unknown spans. |
| `tempo` | Decimal BPM such as `87.5`, `unknown`, or `ambiguous` | Clock segment; use consecutive segments for changes. |
| `meter` | Numerator/denominator such as `4/4` or `7/8`, `unknown`, or `ambiguous` | Meter segment; use `downbeat` for a measured anchor. |
| `harmony` | `G:dominant7`, another declared root:quality, `unknown`, or `ambiguous` | Chord span or change boundary. |

Root spellings are A–G with an optional `#` or `b`; mode and quality names are
lowercase letters, digits or underscores and must be declared by the producing
task. Tempo is a positive decimal BPM from 0.1 to 1000 with at most six decimal
places. Meter numerators are 1–64 and denominators are powers of two through
64. These label types preserve exact half-open source frames. `unknown` and
`ambiguous` approved decisions for these types export under `unknown_labels`,
not selected training labels. Do not infer key, tempo, chord identity or an
audible attack from the value format alone; the operator question must specify
the evidence and vocabulary to review.

The native review transaction writes its committed answer to
`reviews/<source_sha256>/<revision>.json` under the durable catalog root.
These event files are the output record. They preserve the reviewer, source,
label ID, exact frames, type, value and review status. They are not generated
under disposable `build/` and should not be edited to clear a queue item.

`pythian.label.catalog queue CATALOG_DIR` returns JSON with two arrays:

| Array | Meaning |
| --- | --- |
| `items` | Waiting requests, including unanswered, uncertain, withdrawn or conflicting decisions. |
| `completed` | Requests whose latest committed decision is approved or rejected, including approved `unknown`. Each row includes `current_type`, `current_value`, `current_status`, `current_start_frame` and `current_end_frame`. |

`GET /api/review-queue` returns the same result to the browser after its
silent session handshake. A successful answer leaves `items` and enters
`completed` on the next read; the page advances to the next pending request.
The request manifest stays stable so the producer can audit the original
question. If a completed review is later withdrawn, it becomes pending again.
Rejected and unknown outcomes remain visible as such. Queue completion alone
does not turn a decision into a selected training label; reviewed exports keep
approved unknowns separate from selected labels.

The agent checks the Pascal `queue` report during task work to learn which
requests were answered, then reads the matching durable event or reviewed
catalog export before using a label. This is a pull-based feedback loop: the
service does not send a message to an idle agent when an operator saves an
answer. The current manifest may be replaced for a new batch after its
outcomes are accounted for; older review events remain in the catalog. No
database or separate completion cache is required.

## Task-declared structured answers

New tasks that need a finite answer vocabulary or a relationship use a
`version: 2` queue manifest. Existing version-1 manifests and review events
remain readable and retain their old packet bytes. A version-2 manifest may
also carry older simple requests; only an item with `answer_spec` is a
structured request. Its `label_type` and `answer_geometry` are explicit.

```json
{
  "version": 2,
  "items": [{
    "id": "local-key-001",
    "source_sha256": "<imported-source-hash>",
    "start_frame": 0,
    "end_frame": 48000,
    "question": "Which declared local key best fits this exact span?",
    "label_type": "key",
    "answer_geometry": "exact",
    "answer_spec": {
      "facet": "key",
      "vocabulary": ["C:major", "A:minor", "unknown"],
      "links": [],
      "proposal_id": ""
    }
  }]
}
```

The Pascal publisher validates the entire batch before replacing the old
manifest. Every structured item declares 2–32 unique values, including
`unknown`; built-in label values still obey their type's syntax. A note may
declare `pitch_midi_values` (0–127). A `part_vocabulary` limits the `part`
field; without it, the only permitted part is empty. The existing exact,
one-frame point and contained-span geometry rules still apply. The server
returns a canonical `request_sha256` and `answer_spec` with each pending or
completed item, so a browser can show only the task's offered values.

`ext.groove_trait` declares accent, swing, syncopation, microtiming,
articulation, role or velocity relationships. `ext.motif_relation` declares
repetition, variation or section transitions. `ext.pulse_evidence` declares
omission, distractor, clock gap or competing phase/rate evidence. Each uses
`extension_version: 2` in its saved change. A fixed `links` entry names its
role, same source hash, kind (`label` or `proposal`) and target ID. Label
links also pin target type and revision. Relationship and phase/rate facets
require their specified links. A `proposal_id` binds a request to the exact
candidate it asks about; the producer cannot turn a generic rejection into
an unbound proposal verdict. Cross-source relationships are not admitted
without an independently verified shared clock and group policy. Before an
evaluation source has its first independent review, publication rejects a
request that names or links to a Pythian proposal, so the question itself
cannot reveal the blind suggestion.

A structured Save sends a version-2 transaction with `request_id` and
`request_sha256` as well as the normal source hash, expected revision,
reviewer and change. The native reviewer re-reads the published request,
checks the complete source/question/spec hash, answer vocabulary, geometry,
part/pitch constraints and fixed links, then copies the canonical request into
the immutable event. A changed request, withdrawn link target or stale
revision cannot silently become selected truth. Once a label has a structured
request, a version-1 edit cannot replace it or erase its request ancestry; a
correction needs the same published request and its current hash. The worker's
Pascal `queue` report gives the exact current frames, value, status and request
hash; reviewed export keeps approved `unknown`/`ambiguous` values outside
`selected_labels`
and rejects a selected relationship whose pinned target later disappears or
changes. Version-1-only exports retain their original bytes; mixed histories
use packet version 2 and clean replay checks those bytes.

This source-label queue remains bounded to 30-second source regions. The
separate [style listening packet](TODO/NS-5_evaluation_02.md) owns continuous
120-second generated outputs, paired comparisons, timestamped comments and
0–3 trait scores; its saved reviewer response must feed the same producer
before a full-duration listening case is counted.
