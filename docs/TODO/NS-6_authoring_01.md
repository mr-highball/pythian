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
  label; never pass an unreviewed suggestion to the catalog's reviewed export.
  Show the training/development/evaluation group assignment and export status
  without letting a review action silently move material across groups.
- Serve locally by default with an explicit opt-in for authenticated LAN/mobile
  use. The browser must obtain its LAN session through an access-key form and
  send the session token on catalog and region-audio requests; it must not put
  the key or token in audio URLs. Exercise the actual desktop and narrow mobile
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
