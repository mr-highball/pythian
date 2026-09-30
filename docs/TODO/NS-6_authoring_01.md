# NS-6_authoring_01 — Deliver the Pascal editor and producer queue contract

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Build the operator-facing web application for the
[native annotation catalog](DONE/NS-3_labeling_01.md). The browser application is
authored in Pascal and compiled with pas2js; the native Pascal service owns
inference, WAV streaming, durable files and review commits. HTML/CSS may
provide structure and presentation, but no maintained JavaScript implementation
or third-party inference runtime is introduced.

North star: NS-6. Outcome owner: WAV-05-AUTHORING.
Completion credit: 8 goal percentage points (0.80 overall points).
Current complete-goal allocation, 2026-09-29, with NS-6 weighted at 10 overall points,
under the user's authorization
to rebalance without preserving historical point allocations. All existing
acceptance criteria remain required; this plan revision earns no acceptance.
Allocation rationale: The durable typed editor and producer-readable queue are a reusable operator contract across recorded-learning tasks.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [consumer contract](../CONSUMER-CONTRACT.md) ·
[current beat audition](../BEAT-GRIDS.md) · [review queue contract](../REVIEW-QUEUE.md) ·
[task-flow listening allocation](../TASKFLOW.MD) ·
[stable LAN service procedure](../LAN-REVIEW-SERVICE.md).

Execution status: open; recorded editor/queue checks exist, but the complete
split contract still needs current-source independent QA. Next deliverable:
freeze and verify checklist 1–3 and 6–9 with a copied catalog. Closing evidence:
source/assets and toolchain identities, exact typed-answer/review/replay results
and durable worker reports. Stop at an unverified owned criterion and record
its failing boundary; physical/operator acceptance stays in authoring_02.

**Acceptance Criteria:**

### Editor and producer acceptance; original checklist numbering

The original checklist keeps its stable numbers. This task owns points 1–3
and 6–9 below; [NS-6_authoring_02](NS-6_authoring_02.md) owns points 4, 5 and 10.
Existing checked boxes retain recorded evidence, but final acceptance still
requires current-source independent QA of this complete editor/queue contract.
The split does not grant credit or convert partial evidence into acceptance.

- [x] **1. Pascal ownership:** Stable Win32/Win64 native and pas2js builds pass;
  maintained import, analysis, inference, WAV serving and review writes stay in
  Pascal, with generated files confined to ignored `build/` and no third-party
  inference runtime.
- [x] **2. Source intake:** Import a prepared multi-recording/multi-track packet
  in one action into a durable catalog outside `build/`; show original source
  hash, provenance, duration, clock, group, partition and analyzer version.
  Reject bad/mismatched assets without partial labels, and open a multi-hour
  recording without loading the full WAV into browser memory.
- [x] **3. Worker-to-operator queue:** A Pascal producer publishes exact,
  source-bound requests for distinct tasks with stable IDs, question, vocabulary
  and answer geometry. Invalid replacement leaves the old queue intact. The
  operator sees only waiting requests, clear progress and an honest empty
  state; the producer can read completed, unknown, rejected and conflicting
  outcomes from a durable Pascal report without interpreting screenshots.
- [x] **6. Source timeline:** Navigate, zoom and seek exact source frames
  across short and multi-hour WAVs with waveform levels, source time, reviewed
  labels and separate proposals. Align stems only when their manifest shares a
  clock. Desktop keyboard and narrow touch controls can select, move and
  inspect the requested region without changing its source identity.
- [x] **7. Backlog label coverage:** Support guided presence and pitch-free
  attack/continuation/release/rest/noise decisions, note pitch/onset/end and
  part or role spans, beat/downbeat points, local key/tempo/meter/harmony spans
  with reviewed `no_key` separate from `unknown`,
  phrase/section boundaries, pulse omissions/distractors/clock gaps and
  competing phase/rate evidence needed by the open NS-3/NS-5 tasks. Include
  task-declared groove traits (accent, swing, syncopation, microtiming and
  articulation) with role/velocity relationships, and motif repetition,
  variation and section transitions where a task requests them. Exact,
  one-frame point and contained-span answers retain request identity; validate
  each producer-declared vocabulary and link target before treating a value as
  selected truth. Keep unsupported relationships and unknown/ambiguous answers
  explicit rather than fitting them into a generic free-text label.
- [x] **8. Review controls and blindness:** Create, approve, reject, correct,
  move, resize, split, merge and undo/redo labels with visible staged versus
  saved state. Pythian proposals remain distinct from operator judgments;
  a request to reject a proposal binds its exact `proposal_id`, while blind
  evaluation hides proposals until an independent review. Bulk import never
  bulk-approves labels or silently changes group/partition.
- [x] **9. Durable feedback loop:** A selected answer makes exactly one
  revision-checked review event, leaves the waiting queue, advances to the next
  request and survives reload/restart. Failed checks, conflicts and lost
  responses retain the choice and avoid duplicate events. The worker reads the
  revised frames/value/status; export and clean-catalog re-import preserve
  source identity, history, proposal provenance and selected versus unknown
  separation. Record explicit task ownership for whole-mix preference and
  generated-output listening packets: those task-declared decisions need a
  producer-readable response, and a 30-second source label must never be
  counted as a full-duration or paired listening review.

The review contract is shared by the open source-evidence tasks. Producers
declare the exact question and finite choices; these mappings do not claim that
the underlying musical inference or reference labels already exist.

| Manual decision needed by open tasks | Queue representation |
| --- | --- |
| NS-3 note presence, attack, continuation, tail, rest, pitched note and part ownership | `presence`, `activity`, `note` with optional pitch and part vocabularies, `part_role`, `source_role` |
| NS-3 beat level, downbeat, missing or distracting pulses and clock gaps | One-frame `beat`/`downbeat`; `ext.pulse_evidence` with fixed phase/rate candidate links |
| NS-3 local tonal context and harmonic change | `key`, `tempo`, `meter`, `harmony` spans with explicit unknown or ambiguous values; `key:no_key` is a reviewed non-tonal verdict |
| NS-3 groove and cross-role rhythmic evidence | `ext.groove_trait` with task-declared traits and source-local role/velocity links |
| NS-3 evolving sound and envelope boundaries | Source-bound `activity` attack/continuation/release windows and note-relative decisions; paired generated-sound listening remains a separate output review |
| NS-5 recurring motifs, phrase and section organization | `phrase`, `section`, `ext.motif_relation` with fixed same-source targets |
| NS-5 source-local preference assignment | `style_preference` only for a task-declared source-local decision; a short window does not establish whole-mix fit |
| NS-5 full-mix personal reference fit and recording-edition correspondence | [NS-5_evaluation_04](NS-5_evaluation_04.md) owns whole-mix evidence and the verified source/cut correspondence; use a durable whole-asset or paired listening decision, never a short `style_preference` label as a substitute |
| NS-5 sustained generated-output quality and continuity | [NS-5_continuity_01](NS-5_continuity_01.md) owns timestamped bad-passage judgments; [NS-5_evaluation_03 — DONE](DONE/NS-5_evaluation_03.md) owns the reusable full-output response packet, and [NS-5_evaluation_02](NS-5_evaluation_02.md) owns actual 120-second style verdicts |
| NS-3 and NS-4 generated-sound comparisons | [NS-3_timbre_02](NS-3_timbre_02.md) owns paired reference/learned attack, motion, release and identity judgments; [NS-4_integration_01](NS-4_integration_01.md) owns synthesis-path listening. Both require task-bound responses distinct from source labels |
| NS-5 paired edits and style traits | [NS-5_evaluation_03 — DONE](DONE/NS-5_evaluation_03.md) owns paired playback and saved comments/scores; [NS-5_evaluation_02](NS-5_evaluation_02.md) owns actual seed-731 edited outputs and reviewer-grounded trait comparisons |

### Retained original detailed criteria and owner map

The six detailed bullets below are retained verbatim to preserve the complete
pre-split contract. Number them D1–D6 in their existing order. Ownership is:

| Original detailed criterion | Acceptance owner |
| --- | --- |
| D1 owned application, inbox/intake and identity | authoring_01 points 1–3 |
| D2 source-clock timeline, bounded levels/audio streaming | authoring_01 points 2 and 6; original/cue seek, loop and audible playback belongs to authoring_02 point 5 |
| D3 label types, exact edits, queue completion, conflicts and durable replay | authoring_01 points 7–9 |
| D4 assistance/blindness and group isolation | authoring_01 point 8 |
| D5 local/LAN binding, credentials/session/Host/Origin, audio URL and actual physical use | authoring_02 points 4–5; queue publishing, clear work/empty state and producer report remain authoring_01 points 3 and 9; timeline controls/long-source navigation remain point 6 |
| D6 complete import/propose/listen/correct/unknown/reload/export/re-import and final QA | authoring_02 point 10 |

Only the portions owned by authoring_01 are its closing criteria; the other
portions remain mandatory closing criteria in authoring_02. Every original
sentence is accounted for, including physical listening, failures and final QA.

- Compile a Pythian-owned Pascal/pas2js browser application that lists the
  prepared inbox and durable catalog, imports all available tracks as one
  operator action, and shows source identity, provenance, duration, group,
  import/review state and analyzer version. Keep generated JavaScript under
  ignored `build/`; keep the portable native library independent of browser
  and HTTP APIs.
- Show a zoomable, navigable, multi-track waveform timeline with source-frame
  accurate labels and Pythian proposals in visibly different lanes/states.
  Align multiple stems only when their manifest declares the same source clock;
  otherwise give each recording its own timeline.
  Stream waveform levels and audio regions from the native service; opening a
  multi-hour WAV must not fetch or decode the full file in browser memory.
  Let the operator seek, loop and listen to the original region and available
  Pythian cue audition from the same timeline.
- Let the operator create, approve, reject, move and resize labels, edit
  category/value/pitch/part as appropriate, split or merge spans, mark
  uncertainty, undo/redo and navigate efficiently by keyboard or touch.
  Cover guided presence and pitch-independent activity decisions, exact
  beat/downbeat markers, and typed source-local key, tempo, meter and harmony
  spans. Preserve explicit unknown and ambiguous answers outside selected
  training labels. Let a prepared request use an exact answer, a one-frame
  beat/downbeat point inside its listening region, or a contained span while
  retaining request identity. Validate a moved beat marker and a corrected
  context span through queue completion, durable export and re-import.
  Display exact source times/frames and save/reload every change with visible
  conflict and failed-save handling. Do not make bulk import equivalent to
  bulk label approval.
- Provide assisted training review and a blind evaluation mode. In the blind
  mode, hide model suggestions until the operator commits an independent
  label; never include an unreviewed suggestion as a selected or unknown
  training label. A linked suggestion may remain in the reviewed packet as
  separately marked provenance for a review decision; downstream learners
  must consume only approved selected/unknown labels, and independent
  evaluation references must reject proposal-linked labels.
  Show the training/development/evaluation group assignment and export status
  without letting a review action silently move material across groups.
- Serve locally by default with an explicit opt-in for private-LAN/mobile
  use. The operator's LAN workflow must connect without an access-key form or
  credential entry. Bind only to an explicitly selected private LAN address;
  retain same-origin and Host/Origin checks, acquire a session token silently,
  and require it for state-changing requests. Do not put a token in audio URLs.
  Provide a validated Pascal producer command to publish prepared requests
  against imported sources without discarding the existing queue on failure.
  Show only curated review requests as operator work, each with its exact source
  region and question. Derive pending and completed requests from the durable
  review journal; a committed answer must leave the active queue, advance the
  operator to the next request, and remain visible to the producer through a
  Pascal queue report. Show an honest empty state when none is assigned. Keep
  catalog setup and detailed authoring tools available without putting them in
  the basic listen/review path. Make audio load, readiness, playback and errors
  visible beside the player on a narrow screen.
  Exercise the actual desktop and narrow mobile
  browser paths, including
  playback, zoom, edit handles and long-source navigation. Make the UI usable
  for the user's larger cross-task listening batches without repeatedly
  requesting routine third-party microclip judgments.
- Demonstrate end-to-end on a prepared multi-track packet: import, run Pascal
  proposals, listen, correct at least one wrong suggestion, retain an unknown,
  reload, export and re-import the reviewed packet. Salty Boi owns final QA of
  the actual browser and native service path. The operator workflow may be
  accepted without treating its example labels as musical ground truth.

**Blockers**

- [NS-3_labeling_01.md — DONE](DONE/NS-3_labeling_01.md)

**Dev Notes:**

- 2026-09-29 current complete-goal credit basis: this task owns 8 NS-6
  goal points (+0.80 overall) by deliverable value. Nine open NS-6
  tasks allocate 85 goal points (+8.50 overall); the accepted contract and
  native checkpoint allocate 15 goal points (+1.50 overall), with zero baseline.
  Lifecycle support and actual ecosystem adoption are now explicit required
  outcomes. Earlier point amounts and conserved split totals are historical,
  superseded by this user-directed scope reassessment. Criteria and evidence
  requirements remain intact; planning earns no acceptance.


- 2026-09-29 bounded next deliverable: freeze the editor/queue source and copied
  catalog fixture; independent QA checks all seven owned checklist points,
  typed-answer replay and durable producer feedback. Closing evidence records
  source/assets, toolchain, request/review identities, exact replay results and
  the complete owner map. Stop if any owned criterion is unverified; record
  its concrete failing boundary instead of extending unrelated UI features.
  Final physical/operator QA continues in authoring_02. Earlier Dev Notes
  remain historical and do not override this ownership split.

- 2026-09-29 QA process and firewall repair: repeated Defender prompts came
  from checked native servers executed directly under changing dated `build/`
  paths; a browser QA session also left metronome playback and many Brave
  child processes. The fixed stable LAN executable remains unchanged, and a
  new fixed `build/label-service/qa/` staging slot now handles isolated QA.
  Stale QA server/browser processes were closed while the normal Brave window
  and live LAN service stayed open. The exact-path QA firewall rule still
  requires a one-time elevated install; until then, no isolated server is
  launched. Criterion 4's stable live path remains satisfied, criterion 5's
  physical-phone verdict remains open, and credit is unchanged. See
  [work](../WORK-HISTORY.md#fixed-qa-runtime-path-and-browser-cleanup--2026-09-29).
- 2026-09-29 phone Save 431 repair: the operator's selected `both_audible`
  answer was blocked by a 64 KiB request-header rejection during the
  listening-queue preflight, before any review write. Token-authenticated API
  fetches now omit unrelated browser cookies while session setup still stores
  the path-scoped media cookie. The native Pascal cap is bounded at 256 KiB
  with byte-count-only 431 diagnostics. Salty Boi's independent Win32/Win64
  and copied-catalog 390 px QA passed 70/200 KiB accepted headers, 280 KiB
  rejection, token/Origin/media guards, exact Range, one no-ID Save, reload
  and same-answer no-op; no live test write occurred. This advances criterion 9's phone
  save path; physical-phone confirmation and task credit remain open. See
  [work](../WORK-HISTORY.md#phone-save-request-header-repair--2026-09-29).
- 2026-09-29 no-entry listening review repair: the phone exposed an empty
  Reviewer ID field that blocked Save. The pas2js listening form now supplies
  the fixed `operator` role without an input, retaining the native journal's
  nonempty reviewer contract. An unchanged historical response with another
  reviewer is treated as a no-op by answer content, while changed corrections
  record the new role. The pas2js build and independent Salty Boi copied-catalog
  390 px QA passed new Save, queue advance, reload, legacy no-op and changed
  correction with exactly the expected POST counts and native reviewer values;
  no test answer touched the live catalog. This repairs the operator path within criterion 9;
  the physical-phone audio criterion 5 and task credit remain open. See
  [work](../WORK-HISTORY.md#listening-reviews-without-reviewer-entry--2026-09-29).
- 2026-09-28 mobile queue/playback repair: the source page's
  source-only `0 waiting · 4 completed` had obscured two pending full-output
  listening reviews. The pas2js home now reports the combined waiting total
  with separate source/listening counts, independent unavailable states and
  clear routes; the listening page leads with the selected review, keeps the
  reviewer ID across packet advances, focuses the next task, and puts packet
  internals under details. The empty source editor stays hidden until a track
  is selected. Isolated old-versus-new native probes
  reproduced sender-slot exhaustion after four abandoned media clients
  (fifth Range 503→206) and a valid 20 KiB Cookie exceeding the former
  16 KiB header limit (431→206 under a bounded 64 KiB limit). Checked Win32/
  Win64 builds and a throttled 390 px browser on the exact original/cue passed
  these focused paths; the phone's exact request bytes remain unknown.
  Salty Boi's fresh copied-catalog desktop/390px Pascal/CDP pass confirmed
  combined counts, no login/overflow, WAV error/retry and playback clock,
  two saved answers with reviewer carry-forward and focus, and persistence
  after reload. The native raw-socket pass covered 128-byte Range, large
  valid/invalid headers and four abandoned senders followed by another 206;
  evidence and screenshots are under ignored `build/salty-review-ux-final/`.
  The checked Win64 binary SHA-256 `d300bea996a349091aea2277b09b20b20a28d546794f70ace7618a2507f4f027`
  and six matching browser assets were staged at the fixed LAN path. Host
  read-only verification returned source 0/4, listening 2/0, both pages 200
  and a 128-byte generated-cue Range 206 using the session cookie. No test
  answer touched the live operator catalog. The physical-phone
  verdict and criterion 5 remain open;
  no task or milestone credit changes. See
  [work](../WORK-HISTORY.md#review-queue-clarity-and-listening-media-recovery--2026-09-28).
- 2026-09-28 LAN connection/performance repair: a cold 1.56 GB source check
  blocked the former single-request HTTP loop while the listener had no
  connection timeout. The Pascal service now runs listening media verification
  and cold listening-review Saves in bounded workers, retaining hash-before-
  bytes, exact queue identity and revision checks. Checked Win32/Win64 builds,
  tampered-media 422/no-audio, exact 206, duplicate Save, stale 409 and a
  no-read media client passed isolated tests. Concurrent session/queue reads
  stayed at 0–16 ms during 39–59-second cold Saves. Both pas2js pages show
  elapsed waits and a 10-second session Retry; source WAV progress uses actual
  received bytes and full-output audio calls its measured value buffered
  duration. A Pascal Edge/CDP run observed an intermediate 1% transfer,
  decode, cleared progress, blocked-session Retry, and a delayed 12-second
  stale session that did not overwrite the successful retry. Salty Boi QA
  passed this batch. The fixed-path live service now runs checked Win64 SHA
  `579ad33e02759890ab873750fd6ac9251c7dca80f34fc0314673da57a08f80a8`;
  LAN root/session/queues returned in 13–79 ms on the host, and all six served
  assets match the compiled stage. This advances criterion 5's connection,
  retry and download evidence but does not close its physical-phone and other
  listening boundaries, criterion 10, this task, or milestone credit. The
  native response-wide media deadline is one hour; a slow client can occupy
  one of four sender slots until then. See [work](../WORK-HISTORY.md#lan-review-connection-and-transfer-responsiveness--2026-09-28).
- 2026-09-28 multi-source listening provenance repair: the waiting guarded
  4:16 Pythian render was produced from three ordered WAVs, while its first
  published packet named only the first source. The Pascal v1 contract now
  accepts a 2–32-item ordered `source_sha256s` array for generated/edited
  assets, with the existing singular hash first; source/reference and legacy
  single-source normalization stay unchanged. Pascal native Win32/Win64 and
  independent Salty Boi QA passed generated/edited roundtrip, eight rejected
  replacement cases, unchanged queue on failure and byte-identical export/
  replay. pas2js shows a compact source count. The fixed-path LAN service was
  rebuilt and restarted at port 18097, then the unreviewed live guarded packet
  was replaced with its complete ordered C/A/B source set. Both requests are
  still waiting, with zero completed; the phone-cue packet hash is unchanged.
  Independent read-only 390px Brave QA on the deployed page showed
  `16000 Hz · 3 source recordings`, decoded and played the 256.192-second
  guarded WAV, then sought and played at 240 seconds. It had no password
  prompt, JavaScript error, review POST or horizontal overflow; the queue SHA
  and guarded request revision 0 were unchanged. This repair neither counts
  as physical-phone playback nor closes checklist point 5 or the task.
- 2026-09-28 physical-phone checkpoint: the operator confirmed audible
  playback of both 0.5-second and 5-second original regions, successful Save
  on all three remaining MAESTRO requests, and no new Windows Defender alert
  after the fixed-path launch. The native source queue now has zero waiting
  and four completed exact requests; each source has two approved review
  events, and Salty Boi independently audited their identities, values and
  frames. This closes checklist points 4 and 10 together with the earlier
  isolated full-flow QA. Point 5 and task credit remain open until a physical
  phone audibly plays a bounded longer original region and a real Pascal
  Pythian beat cue. A separate, source-bound pair
  `ns6_phone_cue_20260928` (request SHA-256
  `3d8d53ed7659fc18e9a7ad93d6955743dfba4dc14f6846c4f68848c88cf06095`)
  passed isolated desktop and 390px browser playback QA. Its first player is
  the 20-second original Berg WAV with a declared first-10-second range; the
  second is an exact 10-second Pascal-rendered beat cue from an explicitly
  unreviewed QA candidate. Both decoded and advanced without a browser error
  or Save POST. Native `listen-stage` and `listen-publish` then placed this one
  packet in the live catalog's separate listening queue: one waiting, zero
  completed. Live HTTP HEAD returned 200 for both assets; the source queue
  manifest and its four review events remained unchanged. A physical-phone
  audibility and Save verdict is pending as cross-task manual queue item 7.
  Salty Boi then repeated the read-only 390px playback check against the live
  LAN service: both players decoded and advanced, the original's first-10-
  second seek worked, the cue streamed with HTTP 206, and there were no Save
  POSTs, browser errors, horizontal overflow or source-review changes. The
  isolated catalog accepted a synthetic `qa-probe` answer to this exact pair,
  advanced to zero waiting/one completed, and produced a valid one-event
  Pascal listening export. That QA verdict is confined to the isolated
  catalog and is not an acoustic judgment or live operator response.
- 2026-09-28 stable-LAN deployment checkpoint: the user installed the
  fixed-program Private/LocalSubnet/TCP 18097 inbound rule, and root verified
  its scope with `netsh`. Root stopped the old PID 6796 and launched the
  checked stable executable (SHA-256
  `c819a9a3bc7da94f148ec2c0f144fb1778ab45b57118e9fccbe459578706dca0`)
  as PID 16976 on `review-host.invalid:18097`. `GET /`, `GET /api/session` and
  `GET /listen.html` returned HTTP 200; the source WAV GET returned HTTP 200
  and an 882,044-byte RIFF body; Host/Origin rejection returned HTTP 403.
  The durable queue hash
  stayed `e55190cd2fa5be39fc5abb7c4e765a3c99eb82ea3cda474c32dbe5ecd8bc4c8b`
  with three waiting, one completed and one existing review event unchanged.
  Salty Boi independently checked the same PID/rule, GET endpoints and native
  queue against that hash. A live half-second WAV GET returned HTTP 200 with
  88,244 bytes. Pascal CDP headless Brave at 1280px and emulated 390px opened
  the first waiting Berg [5,10) s request; Play original fetched exact frames
  220500–441000, decoded 5.0 s and advanced the playback clock by
  0.184/0.165 s respectively, with zero POSTs, JavaScript errors or horizontal
  overflow. See `build/live-stable-browser-qa/desktop.log` and `mobile.log`.
  At this read-only deployment checkpoint, physical Android playback/Save and
  repeat Windows Defender behavior were still unverified. The subsequent
  physical-phone checkpoint above supplies those results.
- 2026-09-28 independent Salty Boi QA passed a fresh two-group workflow in
  `<durable-qa-catalog>/flow5`, outside disposable
  `build/` and outside the live catalog. The browser decoded original/cue WAV,
  corrected a deliberately wrong proposal point from frame 6213 to 8784,
  saved an explicit `unknown` on the second source, advanced to 0 waiting /
  2 completed, and retained that state after browser reload and native-service
  restart. Native history showed one bound revision per source; selected and
  unknown exports remained separate and clean re-import/re-export was
  byte-identical at SHA-256
  `9abbd75332b12793f563258250fff3c9aaeec72cbf216412b88cdc8adb0ad23f`.
  Together with the prior five-hour timeline, split/merge, undo/redo, blind,
  conflict and error/retry checks and current 28-facet Win32/Win64 matrix,
  this closes engineering checklist points 1–3 and 6–9. Points 4, 5 and 10
  remain open for the current build's physical LAN phone playback/Save path;
  headless decoded audio does not prove a human heard sound. No live test
  answer or task credit was added. The independently checked build is live at
  `http://review-host.invalid:18097/` with read-only HTTP 200 page/session/queue/
  exact-audio probes and unchanged catalog queue hash/event count. Automatic
  approval review rejected deletion of the ignored 1.56-GB QA copy as
  `blocked by policy`, so it remains until the operator can remove it.
- 2026-09-28 the physical phone played the Berg 5–10 s WAV to its displayed
  end, but its selected `audible` answer failed the queue pre-check before any
  new review event. A bounded ten-point acceptance gate now covers the whole
  operator/worker loop and all known manual-label needs; no boxes or task
  credit are closed. The socket reader initially split at leading CRLFs before
  the parser could process them; independent Salty Boi QA found this and
  passed the corrected native/pas2js batch on a copied catalog, including
  browser retry and lost-response deduplication. The repaired no-key service
  is live at port 18097 with its catalog unchanged, but a physical-phone Save
  is still unverified. A 1.56-GB source hash took 98.6 s, exposing a separate
  repeated-Save cost for multi-hour queues. Structured vocabularies/links and
  guarded long-source verification remain in progress; see
  [work](../WORK-HISTORY.md#physical-phone-save-failure-parser-repair-and-authoring-gate--2026-09-28).
- 2026-09-28 a second physical Brave WAV failure showed HTTP 400 on the first
  waiting question. The exact live audio region served a byte-identical Pascal
  render on the host; the prior phone request was not captured. The native
  service now returns/logs bounded parser failure reasons, and the Pascal/
  pas2js player exposes the response reason with Retry. Salty Boi's isolated
  real-Brave QA passed mobile/desktop playback (including 0.5 s), forced 400,
  blocked and slow fetch recovery, exactly one saved review with queue advance
  and reload, and byte-identical reviewed-packet export/import replay. The
  updated no-key LAN service is live, but the physical-phone retry is still
  needed to identify or clear its specific failure; do not count the user's
  inaudibility remark as a reviewed label. See [work](../WORK-HISTORY.md#phone-wav-http-400-diagnostics-and-isolated-replay--2026-09-28).
- 2026-09-28 the physical Brave WAV failure prompted a bounded end-to-end
  browser/service batch. The native route served the exact 882,044-byte WAV
  on the host; the phone failure bytes remain unknown. The Pascal/pas2js UI
  now shows an indeterminate loading bar for connection, catalog, queue and
  WAV fetches, clears it after errors and offers visible Retry. The open
  task's source-label scope now covers guided activity, typed key/tempo/meter/
  harmony values and `exact`/`point`/`contained` queue geometry. Checked
  Win32/Win64 native publication, review, export and re-import pass on isolated
  sources. Ticket Guy's 390-pixel Brave checks passed the editor paths;
  Salty Boi independently replayed actual WAV playback, exact and guided
  answers, marker placement/correction, contained key review, reload and
  export/re-import on isolated catalogs at 390/1280 pixels. The live no-key
  service now serves byte-matching assets at `review-host.invalid:18097`; the
  durable manifest and one review event did not change. The user's physical
  phone check remains manual item 2. This engineering QA does not close the
  complete operator task or add milestone credit; see [work](../WORK-HISTORY.md#lan-review-flow-and-backlog-labeling-support--2026-09-28).
- 2026-09-27 a physical Brave page showed the workbench shell but remained on
  `Connecting to local service…`. The host's live listener, page, bundled JS,
  session endpoint, private Wi-Fi address and local-subnet firewall rule were
  healthy when checked; the phone's failed request was not captured. A real
  Brave reproduction blocked only `/api/session` and showed that its raw fetch
  `TypeError` bypassed the Pascal-only exception handler, leaving an unhandled
  rejection and the original text. The pas2js startup now catches raw rejection,
  displays a connection error after failure or ten seconds, and offers Retry
  with stale-attempt protection. This is recovery for the reproduced failure,
  not proof of physical-phone reachability. The existing manual tool review
  remains pending and no task credit follows. Independent isolated 390-pixel
  browser QA passed failed-fetch recovery, ten-second timeout/Retry and a late
  first response after successful retry, with zero review POSTs; 1280-pixel
  normal startup had no horizontal overflow. The served no-key LAN page now
  carries byte-matching checked `app.js`, and its queue remains three waiting /
  one completed. The phone's actual connection verdict is still required.
- 2026-09-27 the operator identified that a saved answer remained in the
  prepared-request list with Save disabled, obscuring the workbench's queue
  purpose. The native Pascal report now derives waiting and completed rows from
  exact durable review events. A validated `queue-publish` command lets the
  producer replace the request manifest; `queue` lets it read outcomes. The
  pas2js page counts both states, opens the first waiting request and advances
  after a final answer. The request manifest is input and review event JSON is
  output; no second label store was added. The physical-phone check remains
  manual review item 2; no authoring task or milestone credit follows from this
  slice alone. Independent isolated 390-pixel browser QA passed failed-save
  retention, one-event advancement, uncertain pending, generic approval and
  all-done. Win32/Win64 native reports matched the API; valid publication
  succeeded and invalid publication preserved the old manifest. The checked
  no-key service is live at `review-host.invalid:18097`, reporting three waiting and
  Berg `rest/approved` as the one completed request. Physical-phone review of
  this revised queue remains pending.
- 2026-09-27 a physical Brave Save showed `Request check HTTP 400`, but the
  exact `rest` answer for the Berg opening had already been durably saved as
  review revision 1 at 15:11:19. A later request check failed before another
  write. The native queue now reports the exact saved value/status. The
  Pascal/pas2js guided panel displays that answer, blocks duplicate
  same-value Saves, distinguishes corrections and preserves the selected
  choice after an HTTP or network failure. The phone's failed request bytes
  remain unknown; fresh GET succeeds, so this is a state/recovery repair and
  not a claim that every future parser 400 is eliminated. The operator's
  firewall rule is installed for Private/local-subnet TCP port 18097. The
  physical-phone workflow remains manual queue item 2 pending; no task credit
  follows from this repair alone. Checked stable Win32/Win64 native hosts
  compiled; Salty Boi's independent isolated 390-pixel browser QA passed
  fresh/no-autosave, saved same-value/no-POST, HTTP 400 selection recovery,
  and one-POST revision-checked correction. Its numeric payload extractor was
  invalid; the accepted event revisions establish the save outcome. The
  checked no-key Win64 service is live at `review-host.invalid:18097`; the queue
  reports `rest/approved` for Berg and no second Berg review, and served
  `app.js`, HTML and CSS hashes match the staged bytes. Physical-phone replay
  of the revised page is still unverified.
- 2026-09-27 the operator's physical Brave screenshot showed that a presence
  question instructed `rest` while the nearby generic editor exposed only
  review statuses. The Pascal/pas2js workbench now puts three unselected
  answer choices beside playback: instrument audible, no instrument anywhere
  (`rest`), and cannot tell (`unknown`). Explicit Save revalidates the exact
  current queue question/source/frames/type/ID before the native
  revision-checked transaction; approved `unknown` exports as an unknown
  label. The detailed editor remains for other types. Salty Boi's isolated
  390-pixel Edge QA passed all three mappings, no autosave, direct 0.5-second
  Play original, double-click lock, HTTP 500 retry, changed-question rejection
  before POST, unknown export and the retained note editor. A final harness
  counter check after navigation failed because its probe was not reinstalled;
  the relevant browser actions had passed. The checked assets are live at
  `review-host.invalid:18097`; HTTP hashes match, no-key session opened, and four
  clarified requests loaded. The original opening WAV is very quiet and the
  user's report that it sounded silent does not establish an acoustic rest or
  complete physical Brave playback review. Item 2 remains pending, with
  cross-task manual queue 5/20 and no new task credit.
- 2026-09-27 Salty Boi's current-source audit accepted criteria 1 and 2 at
  their declared Pascal browser/native-service scope. The retained checked
  five-track same-clock fixture covers one-action import, source identity,
  provenance, duration, group, proposal version and aligned versus separate
  timelines. Retained real-browser checks cover zoom, reviewed/proposal lanes,
  bounded reads, seek, loop and cue audition; a separate check navigated within
  a five-hour source. The recent guided-request changes do not alter those
  underlying routes. This is an engineering signoff, not physical-phone
  usability or acoustic-label acceptance. The full task and its credit remain
  open on criterion 5's queued Brave verdict. An optional fresh current-build
  criterion-6 replay verified two-track import on the intended isolated
  service, then stopped when that test service reached its configured
  20-request cap. A preceding harness run used stale ports and is invalid.
  No product failure or full fresh export/re-import result follows; the
  previously accepted end-to-end workflow and current focused Save/queue
  checks remain the criterion-6 evidence. Automatic approval rejected removal
  of the stale isolated browser profile with `blocked by policy`; a new
  untouched profile was used without retrying deletion.
- 2026-09-27 four source-bound presence requests were staged in the live
  catalog after the direct-MAESTRO source gate. The existing physical-phone
  item 2 now names a prepared 5–10 s request for playback because the prior
  empty-queue wording became stale; its ID and pending state remain the same.
  Items 3–6 are separate acoustic judgments. The cross-task manual queue is
  5/20, and neither the browser nor queue import selected a label.
- 2026-09-27 guided `Record answer` candidate for selected prepared requests:
  Pascal queue validation accepts an optional explicit label type and checks
  the exact source-local current label ID without a whole-source 2048-label
  page. A conflicting ID disables only its request. The pas2js form prefills
  request ID, exact frames and available type, while starting with a blank
  answer/proposal and uncertain status; operator approval and explicit Save
  remain necessary before a selected training label exists. Focused FPC 3.2.2
  Win32/Win64 builds, a Pascal queue fixture including >2048 saved labels, and
  pas2js 3.3.1 compilation passed. Salty Boi's independent native queue check
  and ~0.7-second isolated HTTP read of four requests passed with 2050 saved
  events. Browser replay showed saved history, a blank uncertain new draft,
  no autosave and explicit revision advancement. It also found the guided
  action stayed disabled after Save because the UI updated it before clearing
  the asynchronous save lock. Ticket Guy repaired that transition; his isolated
  Pascal CDP check passed delayed success and failed-POST paths. Salty Boi
  independently rebuilt pas2js and confirmed disabled-during-Save,
  re-enabled-after-success/failure, revision 2053 to 2054 on successful Save,
  and no revision change after failed POST. This focused browser pass did not
  recheck 390px layout, physical-phone playback, Approved-state interaction,
  missing-type UI validation, conflict display or blind-proposal hiding;
  source/native and earlier browser evidence retain their separate scopes.
  The checked assets are live on `review-host.invalid:18097` as process 18564;
  page/app returned HTTP 200, silent session opened, three catalog tracks and
  zero assigned requests loaded, and tokenless catalog read returned 403. The
  one physical-phone playback/usability
  verdict remains queued at 1/20; this candidate earns no criterion credit yet.
- 2026-09-27 the user's physical Brave session reached the no-key LAN page, so
  the access-key barrier was removed. Its `Load this region` control left the
  player at `0:00 / 0:00` with no visible local outcome, and the page exposed
  import, hashes and the full label editor ahead of the review path. This is a
  failed operator usability verdict for criterion 5, not acceptance or task
  credit. The deployed repair makes playback the primary action,
  reports fetch/player status beside it, folds utility controls, and adds a
  bounded Pascal review-request route and exact-region selection. A native
  check of a current 10-second source region returned complete non-silent PCM16
  stereo WAV. The prior pas2js handler rethrew native rejected fetch/play
  promises, allowing a silent zero-duration failure; the repair reports those
  beside the player. Physical Brave playback remains to be rechecked.
  Salty Boi's isolated 390px browser QA clicked a prepared request, opened
  its exact 0–441000-frame region, and observed a 10.0-second player advancing
  past 0.30 seconds with visible Playing feedback. Empty and malformed queue
  states, no key prompt, zero horizontal overflow, blind proposal hiding and
  no automatic review save also passed. Evidence is under ignored
  `build/label-workbench/ux-qa-20260927/`; this does not replace the physical
  Brave verdict. The checked service is live on `review-host.invalid:18097` as
  process 15936; authorized queue is empty, catalog has three sources, and
  page/app return HTTP 200. A post-repair physical phone check is queued as
  the sole pending cross-task review item (1/20).
  Review requests are prompts, not accepted labels. The assistant prepares
  source evidence and requests only specific judgments needed for open tasks;
  the operator's reviewed decisions alone enter the training catalog.
- 2026-09-26 explicit no-key private-LAN implementation and focused final QA:
  `serve-app-open` binds a selected private IPv4 address, skips operator access
  keys, silently serves a session token and requires it for catalog reads and
  mutations. The pas2js page starts with the login form hidden and opens the
  catalog automatically; the existing keyed mode remains available. Checked
  FPC 3.2.2 Win32/Win64 and pas2js 3.3.1 builds passed. Salty Boi accepted
  isolated open/keyed HTTP checks and a desktop Edge render without a login
  prompt; spoofed Host/Origin and tokenless calls were rejected. The live
  `review-host.invalid:18097` service returned HTTP 200 for page/app/session and
  authorized catalog, and HTTP 403 for tokenless catalog. Evidence is under
  ignored `build/label-open-smoke/` and `build/label-workbench/live-open/`.
  Fresh narrow visual capture and actual physical-phone reachability/playback,
  zoom, edit and long-source navigation remain unverified, so criterion 5 and
  the task's then-allocated +0.20 overall credit stayed open (historical amount). Windows Private firewall is
  `BlockInbound,AllowOutbound`; this shell cannot inspect or add its rules.
- 2026-09-26 user correction supersedes the earlier access-key requirement:
  the LAN workbench must open without any operator-entered credential. A saved
  key per browser origin did not satisfy this. The open-LAN mode must still
  bind only to an explicit private address and retain the request-origin and
  mutation-token safeguards above. The existing queued phone review is stale
  until this mode is built and served; it remains one pending cross-task item,
  not acceptance evidence or task credit.
- 2026-09-26 the user counts the physical-phone operator workflow as one
  pending item in the cross-task manual review queue, currently 1/20. Its
  exact URL, actions and decision are in ignored
  `build/manual-review-queue/queue.tsv`. Queueing does not supply the phone
  verdict or close criterion 5; continue other tasks until the queue fills or
  genuine dependencies require this review sooner.
- 2026-09-26 live LAN readiness check: the current host serves the saved-key
  reconnect assets on `review-host.invalid:18097` and its Wi-Fi profile is Private.
  No explicit port-18097 inbound rule exists; a Private/local-subnet TCP rule
  request was denied by the unelevated Windows shell, so no rule was added.
  This does not prove the phone cannot connect. Physical-phone reconnect,
  playback, zoom, edit and long-source navigation still require an actual
  operator check before criterion 5 or task credit can close.
- 2026-09-26 criteria 1 and 2 now have focused browser evidence. The selected
  track shows its short/full source SHA-256, import and review state, and the
  proposal analyzer name and numeric version when available; an evaluation
  revision-zero UI state hides proposals and makes no proposal read. An
  ignored Pascal-prepared five-track fixture at
  `build/label-workbench/same-clock-qa-v2/` contains three verified equal-rate
  stems with one declared source clock, an unrelated equal-rate stem with no
  clock, and an unrelated piano recording. Native import accepted all five.
  Edge showed only the two matching peer stems beside the selected track,
  preserving the exact source-frame axis, bounded waveform and review reads,
  and same-clock view on source switching. Unrelated tracks reset to their own
  timelines. An 18-step zoom reached one frame with one bin; a shorter peer
  clipped at its own end and shaded the remaining shared window. Read-only
  reviewed-label and Pythian-proposal bands now appear on each peer, while
  edits stay on the selected track. A controlled browser overlay fixture
  verified distinct review/proposal pixels, exact 0–160000-frame peer reads,
  and no proposal request for a blind evaluation peer. Salty Boi independently
  checked the desktop and 390px layouts, source identity, alignment, zoom and
  blind guard. The overlay fixture is synthetic rendering evidence, not an
  acoustic-label or proposal-quality claim. Physical-phone use remains open;
  this task earns no credit yet.
- 2026-09-26 criterion 4 clarifies the existing reviewed-packet contract:
  `linked_proposals` retains audit provenance for explicit reviews, while
  `selected_labels` and `unknown_labels` alone supply approved training
  values. The native WFC adapter reads those two reviewed arrays; the
  independent presence-reference builder also rejects proposal-linked
  labels. This clarification preserves the prohibition on unreviewed
  suggestions becoming training or independent reference evidence. Salty
  Boi's broader criterion audit found no physical-phone LAN result, so
  criterion 5 remains open.
- 2026-09-26 a fresh two-track Edge workflow under ignored
  `build/label-workbench/end-to-end-20260926-attempt5/` imported verified
  development WAVs, advanced both original and Pythian cue playback clocks
  after trusted clicks, rejected a Pascal beat proposal with its identity,
  saved an approved C4 note with piano part, moved and resized it by pointer,
  and reloaded its exact 66150–176400 source frames. A second track saved an
  approved presence `unknown`. Browser export/re-import produced two tracks,
  one selected label, one unknown and five review events; native re-export
  was byte-identical to the downloaded packet. A separate isolated run saved
  and replayed an `uncertain` decision. During this workflow, a stale Save
  control surfaced while a new source loaded. The Pascal/pas2js page now
  locks Save through every asynchronous current-label refresh and guards
  direct Save calls; a deliberately delayed same-source navigation passed.
  Salty Boi accepted the focused code and browser workflow QA for criteria
  3 and 6, together with the earlier split/merge, undo/redo, keyboard,
  touch and conflict evidence. Example review values are workflow fixtures,
  not acoustic ground truth or proof of beat quality. The larger task still
  has remaining criteria; no completion credit is claimed.
- 2026-09-26 the pas2js workbench now stages per-source undo and redo as
  explicit append-only restoring review events, with bounded browser-local
  pointers that survive reload. Keyboard left/right navigates source windows,
  up/down selects labels, and Ctrl/Cmd+Z and redo shortcuts stage the matching
  action. A stale server revision pauses local history; the operator must
  cancel the unsaved event and explicitly clear stale pointers. Ticket Guy's
  checked pas2js build and real Edge desktop/390px run saved revision 1,
  reloaded, saved undo at 2, reloaded, saved redo at 3, then observed an
  external revision 4 and a rejected stale undo at 409 with no revision 5.
  Salty Boi accepted the exact browser behavior and inspected both layouts.
  The live `review-host.invalid:18097` host serves the updated page and app asset.
  This closes the keyboard and staged undo/redo portion of criterion 3; its
  complete criterion and the larger workbench task remain under audit, with
  no credit yet.
- 2026-09-26 the pas2js editor now stages exact-frame split and compatible
  adjacent/overlapping merge review events. Each event requires a separate
  explicit Save; the visible queue blocks navigation while pending, and
  cancellation preserves already saved events. A post-save lock remains set
  through the asynchronous label refresh so rapid repeat clicks cannot reuse
  a stale revision. Checked pas2js build and actual desktop/narrow browser
  logs cover boundary rejection, exact halves, semantic mismatch, staged
  cancellation and 49 blocked clicks during a delayed refresh with exactly
  one revision advance. Salty Boi accepted the code and browser behavior;
  ignored 1280px and 390px screenshots show the new controls without clipping.
  The compound operation remains non-atomic because the catalog commits one
  review event per request. The
  larger authoring task remains open; no task credit.
- 2026-09-26 the native Pascal LAN host now persists its access key in the
  catalog root's private `.access-key` file. First LAN startup uses the
  configured environment key or generates one; later startups reuse the same
  file. The existing pas2js page saves an accepted key per browser origin and
  reconnects without a new prompt. Checked stable Win32/Win64 host builds
  pass; an isolated Win64 LAN host returned 403/200/403 for wrong/correct/no
  key both before and after restart, writing the file only on first start.
  Follow-up ACL review found inherited local-user access on the first draft.
  The Pascal host now restricts the empty file before writing and restricts
  existing files before reading. Checked Win32/Win64 LAN starts produced
  protected ACLs with only OWNER RIGHTS and SYSTEM full control; a legacy
  broad test file was restricted on restart before serving requests.
  The live `review-host.invalid:18097` process now runs this binary against the
  durable catalog. A separate-port first start created the key file and
  returned 403/200 for wrong/correct keys. The live host reused that file
  without rewriting it, returned 403/200 for wrong/correct keys and served
  the page. The former environment key was not recorded, so existing browsers
  may need one final entry during this transition; subsequent visits to the
  same origin reconnect automatically. New browser origins still require one
  initial entry. Salty Boi reviewed the existing browser fixture and
  desktop/390px captures for accepted-key storage, reload reconnect and
  Forget. That fixture predates the live key transition; the current key has
  not been entered in a browser during QA. Physical-phone operator QA remains
  open; no task credit.
- 2026-09-25 the workbench can select a saved beat-grid hypothesis and load a
  short native Pascal cue overlay in the same bounded player as the original
  WAV. It draws the selected grid on the waveform, keeps cue access behind the
  blind-review gate, and does not commit a label during playback. Checked
  stable Win32/Win64 and pas2js builds pass. Salty Boi's isolated native and
  real Edge QA verified candidate switching, original geometry, mobile seek,
  loop, blind and empty-candidate guards, and unchanged review files. The
  active LAN process is still the prior native build, so its page
  hides the cue button while the tested preview is staged separately. The
  larger authoring task and physical-phone review remain open; no credit.
- 2026-09-25 the workbench now jumps to an absolute source second, pages its
  bounded waveform, loads at most 30 seconds of original WAV, seeks within
  that audio from the waveform, and loops the loaded region. Its inbox marks
  verified assets already present in the catalog and disables repeat import.
  A real Edge run navigated a five-hour catalog source to its middle and final
  ten seconds, loaded audio at both, sought within the middle playback and
  via mobile touch at the end, and checked the loop and unchanged review
  revision. The emulated 390px mobile
  player/waveform view was inspected. The live LAN page serves the same durable
  three-track catalog. Cue audition, physical-phone reachability, split/merge,
  persisted undo/redo, keyboard navigation and final QA remain open; no task
  credit is claimed.
- 2026-09-25 LAN login now remembers an accepted access key in this browser's
  origin-scoped local storage and silently requests a new session on reload.
  A visible **Forget this device** control removes that key and clears the
  page session. The service still requires a token on catalog and audio calls.
  A real LAN-bound Edge run checked login, stored key, reload/reconnect,
  forget, and the fresh login prompt after another reload. Desktop 1280px and
  emulated mobile 390px top-of-page screenshots were inspected. Physical-phone
  access and final operator QA remain open; no task credit is claimed.
- 2026-09-25 the reviewed waveform lane now drafts a new interval or moves
  and resizes an existing label with pointer events. It updates the editor but
  never saves without the explicit review action; a new draft clears inherited
  label identity/value and starts uncertain. A Pascal-authored Edge CDP check
  used desktop 1280px and emulated mobile 390px layouts to create, resize and
  move spans with unchanged catalog revision. A touch gesture also drafted a
  span on the taller mobile waveform. One artificial touch-created unknown
  review was saved and reloaded at revision 4 in the ignored loopback catalog.
  Screenshots are under ignored `build/label-workbench/`. The live LAN host
  serves the changed assets. This advances direct timeline editing, not
  split/merge, undo/redo, cue audition, physical-phone validation or the full
  authoring task; no credit is claimed.
- 2026-09-25 user selected a Pascal/pas2js web workbench for authoring the
  missing recorded labels. The pinned WFC static server used by Phanes is a
  useful preview reference; catalog writes and large-WAV serving require the
  Pythian-owned native service above. This task does not imply browser-side
  execution of the maintained inference engine or completion of any recorded
  learning accuracy gate.
- 2026-09-25 first browser slice: `tools/label-workbench/app.lpr` compiles
  with the checked pas2js 3.3.1 toolchain; its generated JavaScript and staged
  HTML/CSS stay under ignored `build/label-workbench/www/`. The page lists the
  inbox and catalog, imports in one action, navigates bounded source-frame
  waveform pages, fetches authenticated 10-second original WAV regions into
  temporary blob URLs, and shows unreviewed beat proposals apart from reviewed
  labels. An operator can commit a review with visible revision/conflict status.
  Evaluation proposal controls and reads are hidden. A fresh Edge browser
  smoke path selected an imported track, loaded audio, displayed eight Pascal
  candidates, and saved/reloaded a presence review at revision 1 in a copied
  ignored catalog. Desktop 1280px and narrow 500px browser screenshots were
  inspected. A separate browser path logged into the explicitly bound LAN
  service through the access-key form and loaded the catalog; a physical phone
  and firewall traversal remain unverified. This slice does not yet provide
  seek/loop cue audition, edit handles, split/merge, undo/redo, blind reveal,
  browser export/re-import, or the complete multi-hour/mobile workflow. No
  completion credit is claimed.
- 2026-09-25 follow-on browser slice: evaluation suggestions remain hidden
  while source review revision is zero, then become available after a native
  independent review; the server enforces the same gate for direct requests.
  The page now downloads the authenticated reviewed JSON packet as a blob
  without putting its session token in the URL. A real Edge CDP run loaded an
  evaluation source, original audio and eight unreviewed candidates, saved a
  later review, and downloaded a 4,341-byte packet. The Pascal packet reader
  verified that browser download at SHA-256
  `3977eadca0c47b9925aef11948411cd50d00f52d9d6367b40addbe936c6d73fd`:
  two tracks, two selected labels, one unknown, four history events. The new
  export section was inspected at desktop 1280px and emulated mobile 390px.
  This is a source-level blind gate; per-reviewer blind sessions, direct
  timeline editing, cue audition, undo/redo, replay import and physical phone
  checks remain open. No completion credit.
- The page now accepts a reviewed JSON file and uploads it to the authenticated
  Pascal replay route. A real Edge browser selected the 21,224-byte fixture,
  submitted it on the LAN-bound page at `review-host.invalid:18097` and displayed
  `Packet duplicate: 2 tracks.`; the native HTTP
  route separately restored that packet into a fresh imported catalog. The
  control and result were inspected at 1280px desktop and 390px emulated mobile
  widths in ignored build screenshots. The new matching native/browser preview
  is bound to `review-host.invalid:18097` with an ignored test catalog; the older
  port 18096 remains an older native host. No physical phone or durable-root
  review is inferred. Timeline editing, cue audition, undo/redo and final
  operator QA remain open; no completion credit.
