# NS-6_studio_13 — Unify source transport, zoom and preparation

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Make thirty seconds the initial view, with zoom, editable view length and a
whole-track overview. Group transport, position, view and selection controls
with accessible original glyphs. Clarify that adding a whole recording uses it
in the project; looking at a whole recording must not trigger corpus preparation.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: two unearned delivery_04 points transfer here; all its criteria remain.
Credit is earned only after all criteria and prerequisites pass.

Execution status: selected, Big Boss solo. Next deliverable: zoomable source
timeline and one visible preparation state shared by project admission,
analysis and effects. Closing evidence: full/late/custom views, bounded reads,
selection stability, preparation progress and recovery in desktop/narrow Codex
Browser. Stop if an overview reads full PCM or changes the selected corpus.
The accepted studio_11 AC1/AC2 contracts are the existing implementation basis;
its remaining full admission/recovery matrix is separately owned there.

**Acceptance Criteria:**

- AC1: Default thirty-second, zoom in/out, custom duration and whole-recording
  views work on long originals and prepared catalog sources. Waveform sampling
  has bounded work independent of the requested span, labeled honestly as sampled.
  Playing continues through bounded audio chunks, separate from visible span.
- AC2: A coherent keyboard/touch toolbar groups Play/Pause, exact source position,
  previous/next view, zoom and whole-track view. Glyphs have accessible names and
  selected state; mobile controls do not split into ambiguous isolated buttons.
  Viewing/seeking/zooming preserves explicit selection and playing/paused intent.
- AC3: Add passage / Add whole recording clearly describe project use. One
  preparation region explains the selected action, actual stage and retry/cancel;
  analysis/effects use that same prepared source. No redundant preparation is
  triggered by zoom, and full audio downloads are not required for an overview.
- AC4: Native sampled-read boundaries and desktop/narrow browser checks cover
  whole-track -> late zoom -> selection -> bounded playback, missing source,
  recovery and selected preparation. Keep source clock, identity and live data intact.

**Blockers**

- [NS-6_studio_04.md](DONE/NS-6_studio_04.md)
- [NS-6_studio_08.md](DONE/NS-6_studio_08.md)

**Dev Notes:**

- 2026-10-02, Big Boss: `TWaveFrameReader.ReadWaveform` replaces both service
  measurement/sampling loops; one serializer serves original/catalog routes.
  Native Win32/Win64 fixtures cover exact/sampled bounds and an 8 GB+ sparse
  RF64 overview using only 65,536 payload bytes. Discovery passes 68 checks per
  target; capture's existing exact-waveform consumer passes 53 Win64 checks.
- Actual desktop/390 px Codex-browser checks cover original and catalog paths,
  full/late/custom views, paused/playing intent, chunk continuation, two-second
  selections, missing source and retry. Explicit whole-recording admission
  reuses a matching completed preparation; viewing alone queues nothing.
  Saved whole-track project and processed clip reload successfully. Analysis
  from 9:45 measures 9:45–10:00 while retaining the full ten-minute overview.
  Frozen assets, screenshots and verdict are in ignored
  `build/studio-expansion/`; await exact-code CI before task completion.
  No physical-phone or musical-accuracy claim follows from viewport checks.
- 2026-10-02, Big Boss: collection waveform sampling already accepts a full
  extent with at most 256 windows of 64 frames. Studio fixes its visible span
  at thirty seconds; legacy catalog waveform handling must also be inspected.
  The earlier corrected seeking contract and failure evidence remain in studio_11.
