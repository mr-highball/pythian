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
for each decision; an exact ID, source and frame span bind the response. A
declared type also has to match. A conflicting saved ID stays pending with an
`answer_conflict` for producer repair.

The native review transaction writes its committed answer to
`reviews/<source_sha256>/<revision>.json` under the durable catalog root.
These event files are the output record. They preserve the reviewer, source,
label ID, exact frames, type, value and review status. They are not generated
under disposable `build/` and should not be edited to clear a queue item.

`pythian.label.catalog queue CATALOG_DIR` returns JSON with two arrays:

| Array | Meaning |
| --- | --- |
| `items` | Waiting requests, including unanswered, uncertain, withdrawn or conflicting decisions. |
| `completed` | Exact requests whose latest committed decision is approved or rejected, including approved `unknown`. Each row includes `current_type`, `current_value` and `current_status`. |

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
