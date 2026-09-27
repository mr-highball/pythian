# NS-6_authoring_01 — Deliver the pas2js audio-label workbench

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Build the operator-facing web application for the
[native annotation catalog](DONE/NS-3_labeling_01.md). The browser application is
authored in Pascal and compiled with pas2js; the native Pascal service owns
inference, WAV streaming, durable files and review commits. HTML/CSS may
provide structure and presentation, but no maintained JavaScript implementation
or third-party inference runtime is introduced.

North star: NS-6. Outcome owner: WAV-05-AUTHORING.
Completion credit: 4 goal percentage points (0.20 overall points), assigned
from the 12 unearned points of [NS-6_delivery_03](NS-6_delivery_03.md). Final
workflow packaging retains 8 points and its original acceptance criteria;
the two tasks preserve the original 12-point total with no new credit.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [consumer contract](../CONSUMER-CONTRACT.md) ·
[current beat audition](../BEAT-GRIDS.md) · [task-flow listening allocation](../TASKFLOW.MD).

**Acceptance Criteria:**

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
  Show only curated review requests as operator work, each with its exact source
  region and question; show an honest empty state when none is assigned. Keep
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
  `192.168.12.109:18097`; HTTP hashes match, no-key session opened, and four
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
  The checked assets are live on `192.168.12.109:18097` as process 18564;
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
  Brave verdict. The checked service is live on `192.168.12.109:18097` as
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
  `192.168.12.109:18097` service returned HTTP 200 for page/app/session and
  authorized catalog, and HTTP 403 for tokenless catalog. Evidence is under
  ignored `build/label-open-smoke/` and `build/label-workbench/live-open/`.
  Fresh narrow visual capture and actual physical-phone reachability/playback,
  zoom, edit and long-source navigation remain unverified, so criterion 5 and
  the task's +0.20 overall credit stay open. Windows Private firewall is
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
  reconnect assets on `192.168.12.109:18097` and its Wi-Fi profile is Private.
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
  The live `192.168.12.109:18097` host serves the updated page and app asset.
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
  The live `192.168.12.109:18097` process now runs this binary against the
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
  submitted it on the LAN-bound page at `192.168.12.109:18097` and displayed
  `Packet duplicate: 2 tracks.`; the native HTTP
  route separately restored that packet into a fresh imported catalog. The
  control and result were inspected at 1280px desktop and 390px emulated mobile
  widths in ignored build screenshots. The new matching native/browser preview
  is bound to `192.168.12.109:18097` with an ignored test catalog; the older
  port 18096 remains an older native host. No physical phone or durable-root
  review is inferred. Timeline editing, cue audition, undo/redo and final
  operator QA remain open; no completion credit.
