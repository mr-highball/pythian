# Full-output listening packets

This is the reusable operator response path for complete WAVs and fixed pairs.
It is separate from source-local label reviews. A producer declares the audio,
listening ranges, question, and finite answer dimensions; the operator hears the
assets and explicitly saves a response. Playback and signal measurements never
create an answer.

## Prepare and publish

Use the checked `pythian.label.catalog` executable for the target platform.
`CATALOG` is a private catalog root; `INBOX` contains prepared original WAVs.
The normal catalog import must already contain any asset with
`"storage":"source"`. Stage each new generated or other listening WAV by its
verified SHA-256 before publishing a request that names it.

```text
pythian.label.catalog import INBOX CATALOG
pythian.label.catalog listen-stage CATALOG generated.wav
pythian.label.catalog listen-publish CATALOG requests.json
pythian.label.catalog listen-report CATALOG
pythian.label.catalog listen-resolve CATALOG browser_pair_48k_120s generated
```

`listen-stage` returns the measured SHA-256, byte count, sample rate, channel
count, and frame count. Put those exact values into the request. The publisher
checks every declared source against its imported catalog record, checks the
actual WAV and provenance, canonicalizes the packet, and publishes it
atomically. `listen-report` returns pending `items`, `completed` requests,
counts, each canonical `request_sha256`, and the latest revision. Use that
reported request hash in a transaction; do not calculate one from hand-edited
JSON. A request can be `single` with one asset or `pair` with two assets.

Here is a compact **authored engineering fixture**, including a one-second
imported 48 kHz source and a 120-second 48 kHz generated WAV. The hashes and measurements
refer to that fixture; they are not a musical judgment or a template for a
real source match.

```json
{
  "version": 1,
  "items": [{
    "id": "browser_pair_48k_120s",
    "task_id": "NS-5_evaluation_03",
    "kind": "pair",
    "question": "Can you hear and seek both authored fixture tones?",
    "assets": [
      {
        "id": "reference", "storage": "source", "role": "reference",
        "sha256": "a547755b83b8f3111d7e9b419516759546651def19df9755d76980c9e27964e3",
        "bytes": 96044, "sample_rate": 48000, "channels": 1, "frames": 48000,
        "provenance": {
          "source_sha256": "a547755b83b8f3111d7e9b419516759546651def19df9755d76980c9e27964e3",
          "source_group": "listen_browser_qa_20260928", "clock_id": "qa_48000",
          "partition": "development"
        }
      },
      {
        "id": "generated", "storage": "listening", "role": "generated",
        "sha256": "621665f5abf49fb74767bba70fd9584b02780b39d7b7bed7c5653bb52ceeb18d",
        "bytes": 11520044, "sample_rate": 48000, "channels": 1, "frames": 5760000,
        "provenance": {
          "source_sha256": "a547755b83b8f3111d7e9b419516759546651def19df9755d76980c9e27964e3",
          "model_sha256": "087960d898d3ca0f3b45a9f6109b790bcdbdb9dbc9a05fdbba8bc11d4e04b714",
          "policy_sha256": "d71f22793676ad2df1e7545381a160937b7872d54334daf18c107e660c991cc5",
          "parameter_sha256": "0d19d0a366a2948bc6edbb01afa29dd275d79efeabd809f44ea7718462069370",
          "split": "development", "seed": 20260928
        }
      }
    ],
    "ranges": [
      {"asset_id": "reference", "start_frame": 0, "end_frame": 48000},
      {"asset_id": "generated", "start_frame": 0, "end_frame": 5760000}
    ],
    "answer_spec": {
      "choices": [{"id": "browser_playback", "values": ["yes", "no", "unknown"]}],
      "scores": [{"id": "playback_clarity"}]
    }
  }]
}
```

Every choice vocabulary must explicitly contain `unknown`; each submitted
response supplies a value for every declared choice and score. Scores are
integers 0–3 or the string `unknown`. Listening ranges use half-open asset
frames `[start_frame,end_frame)` and must fit the verified asset. Timestamped
comments must fall inside a declared range of their named asset. A generated
asset binds source, model, policy, parameters, split, and seed; that lineage
does not itself prove that an audio rendering corresponds to a particular
recording or edition. A correspondence task must retain its separate source
evidence. Listening intake conservatively rejects WAV sample rates below
8 kHz; the positive browser fixture is 48 kHz. Playback support at exactly
8 kHz has not been independently verified.

### Source correspondence packets

A producer that asks whether two assets correspond to the same source must
declare a paired request with `"purpose":"source_correspondence"` and add
`correspondence_evidence`. `subject_asset_id` names one of the request's two
declared assets. The three required references point to **distinct external
evidence records** for recording identity, edition identity, and the exact
cut. Each reference carries its own safe ID and SHA-256. For example, this
fixture-only fragment would be added to a paired request:

```json
"purpose": "source_correspondence",
"correspondence_evidence": {
  "subject_asset_id": "reference",
  "recording": {"evidence_id": "recording_audit", "evidence_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "edition": {"evidence_id": "edition_audit", "evidence_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
  "cut": {"evidence_id": "cut_audit", "evidence_sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}
}
```

Those three example hashes are syntactic test values, not verified evidence.
The publisher checks the request shape, distinct identities and hashes, and
that the subject asset is declared. It does **not** fetch or authenticate the
external evidence or prove the correspondence. The producer must keep and
independently verify the referenced records; the request, report, saved event,
and export retain their exact identities for later audit. Requests with no
correspondence purpose retain their previous canonical bytes and hashes.

## Listen and answer

Open `/listen.html` on the same origin as the local service. The page obtains a
session automatically, shows waiting and completed packets, streams each
declared WAV in the native audio player, and lets the operator seek across the
full asset. Range buttons seek to the declared listening positions. A comment
uses the chosen asset's current playhead, converted to that asset's frame. The
operator enters a reviewer ID, selects every answer, and clicks **Save
response**. Nothing is saved by opening, playing, seeking, or choosing an
answer. Completed packets can be reopened for an explicit correction.

The equivalent Pascal CLI transaction below uses the canonical hash returned
by `listen-report` for the exact fixture request above. It records an explicit
`unknown` choice and score; neither is inferred from omission.

```json
{
  "version": 1,
  "request_id": "browser_pair_48k_120s",
  "request_sha256": "3dbcbd93e534a893c1205874124fee65fa51cfc15e22b90c3046e4a04110baa1",
  "expected_revision": 0,
  "reviewer": "fixture_operator",
  "status": "submitted",
  "choices": [{"id": "browser_playback", "value": "unknown"}],
  "scores": [{"id": "playback_clarity", "value": "unknown"}],
  "comments": [{"asset_id": "generated", "frame": 2400000,
    "text": "Authored timestamp example"}]
}
```

```text
pythian.label.catalog listen-review CATALOG answer.json
pythian.label.catalog listen-report CATALOG
```

The first Save appends immutable revision 1. A correction uses the current
revision from `listen-report`. A stale revision with a different answer is
rejected; retrying the same response after a lost HTTP reply returns
`already_saved:true` without another event. A `submitted` response moves the
request to `completed`; `withdrawn` may omit answers and leaves it pending.
The report's `current_reviewer`, `current_status`, `current_choices`,
`current_scores`, and `current_comments` are producer-readable response data.

## Export and replay

```text
pythian.label.catalog listen-export CATALOG listening-packet.json
pythian.label.catalog listen-inspect-export listening-packet.json
pythian.label.catalog listen-import OTHER_CATALOG listening-packet.json
pythian.label.catalog listen-report OTHER_CATALOG
```

The export contains the canonical queue and immutable response history. Replay
requires a fresh listening queue and review storage in `OTHER_CATALOG`, with
the same already imported or staged WAV identities. It validates the packet,
assets, answer vocabulary, revisions, and response history before publishing.
Keep the source-label export and listening-packet export distinct.

The example answer above is an authored engineering test. Only a response
saved after a real operator listens to the intended audio is that operator's
verdict. A task-specific style, timbre, continuity, synthesis, or source
correspondence claim still needs its own reviewed evidence and acceptance.
