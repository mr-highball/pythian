# NS-6_authoring_01 — Deliver the pas2js audio-label workbench

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Build the operator-facing web application for the
[native annotation catalog](NS-3_labeling_01.md). The browser application is
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
  use. Exercise the actual desktop and narrow mobile browser paths, including
  playback, zoom, edit handles and long-source navigation. Make the UI usable
  for the user's larger cross-task listening batches without repeatedly
  requesting routine third-party microclip judgments.
- Demonstrate end-to-end on a prepared multi-track packet: import, run Pascal
  proposals, listen, correct at least one wrong suggestion, retain an unknown,
  reload, export and re-import the reviewed packet. Salty Boi owns final QA of
  the actual browser and native service path. The operator workflow may be
  accepted without treating its example labels as musical ground truth.

**Blockers**

- [NS-3_labeling_01.md](NS-3_labeling_01.md)

**Dev Notes:**

- 2026-09-25 user selected a Pascal/pas2js web workbench for authoring the
  missing recorded labels. The pinned WFC static server used by Phanes is a
  useful preview reference; catalog writes and large-WAV serving require the
  Pythian-owned native service above. This task does not imply browser-side
  execution of the maintained inference engine or completion of any recorded
  learning accuracy gate.
