# NS-6_clip-library_01 — Browse reusable clips under their parent tracks

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 3/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Expose already saved independent clips across playlists. Library track cards
show clip counts and a preview/selection modal. Selection makes parent/child
membership obvious and collapses children while the whole track teaches.
Primary attribution: NS-6. Reuse existing clip receipts, range identity and player.

**Acceptance Criteria:**

- AC1: Metadata-only discovery finds independent saved clips across playlists,
  retaining original parent identity/range and available labels. Missing or invalid
  receipts are reported honestly; no source/full-track reads while listing.
- AC2: Library has a per-track clip-count button and modal with individual preview
  and adding existing clips to the current playlist without copying audio.
- AC3: Selection supports clear child clip inclusion, creating/editing/removing
  choices, with whole-track selection collapsing child rows. Saved clips remain
  reusable after removing them from a playlist. Reload and actual desktop/phone
  checks protect inclusion and parent/child lineage.

**Blockers**

- [Independent clip files — DONE](DONE/NS-6_saved-clips_01.md).

**Dev Notes:**

- 2026-10-31, Big Boss: the final phone check found a stored child was disabled
  in the clip browser while Whole track dominated it. The browser now distinguishes
  membership from actual learning inclusion; Use this clip releases whole-track
  selection directly. Full pas2js build07 and the actual390px consumer pass.
  This changes browser presentation only; native code remains8a88eac under CI540.
  Two older operator ranges were restored through ordinary Studio into a separate
  recovery playlist, retaining exact frames/labels and the original projects.
  Both independent files are ready; recovery created only clip-save jobs, no
  training/generation. Local lineage receipts retain the actual current collection
  origins without claiming full-parent content equivalence.
- 2026-10-31, Big Boss: native35 checks pass with a clean heap. Metadata discovery
  works with the parent unavailable and clip PCM exclusively locked; missing
  audio reports a clip error rather than substituting the parent. Existing
  receipt/range identity, lossless storage and clip-only learning remain covered.
  Actual browser Library lists three saved clips from other playlists. Previews
  load independent audio, adding two clips preserves ranges/labels, and selecting
  Whole track collapses children without losing their individual choices. Modal
  close pauses preview audio. Final phone/reopen and CI/deployment gates remain.
- 2026-10-31, Big Boss: actual operator clip receipt is ready (independent audio
  and source metadata retained). The current and earlier saved playlists differ:
  Library cannot browse the earlier playlist's clip. Repair discoverability,
  not recreate audio or infer data loss. Existing private choices remain intact.
