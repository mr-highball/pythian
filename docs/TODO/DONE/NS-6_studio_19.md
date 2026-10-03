# NS-6_studio_19 — Explicit training choices and collection playback

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Make the collection distinguish recordings available to browse, saved passages,
and music included in the next generation. Preserve unchecked passages in the
project and offer quick playback without leaving Collection.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional
points; this repairs the already credited source/project usability outcome.

Selected batch: Big Boss solo. Deliverable: durable training choices and a shared
bounded collection player. Closing evidence: native project and generation
boundary checks plus desktop/narrow Codex Browser save/reload, whole/passage
switching and playback checks. Stop on lost passages, incorrect training input,
unbounded media fetching, or overlapping unintended audio.

Accepted 2026-10-03 by Big Boss under the operator's solo UX instruction. All
criteria pass native boundaries and actual Codex Browser checks. Evidence:
`build/studio-selection/QA-VERDICT.md`, project/worker logs, phone screenshot,
fourteen frozen hashes, deployment preservation and cleanup records. The matched
Win64 bundle is live in the stable slot.

**Acceptance Criteria:**

- AC1: Each whole recording and saved passage has an explicit include/exclude
  control. Choosing a whole recording excludes its passages without deleting
  them; choosing a passage excludes the whole recording. Checked passages must
  not overlap. Unchecked definitions and labels survive Save and reload.
- AC2: Collection and Generate clearly summarize the checked training music.
  Native jobs use only checked inputs; empty training sets cannot generate.
  Existing project selections remain included when loaded.
- AC3: Whole recordings and saved passages have inline play/pause and source-time
  feedback using the existing bounded player. Preview changes no training
  choices, passage playback respects its bounds, switching previews stops the old
  one, and late-passage previews request only bounded audio.
- AC4: Validate on isolated authored data, deploy matched artifacts in the fixed
  stable slot, preserve operator records, close owned QA tabs/processes and record
  remaining physical/operator limitations honestly.

**Blockers**

- [Accepted source/project setup](NS-6_studio_01.md).
- [Accepted Studio tabs](NS-6_studio_18.md).

**Dev Notes:**

- 2026-10-02, Big Boss: operator feedback exposes that the former source card is
  a browser entry while nested passages are implicitly training inputs. No
  durable exclusion state or inline collection playback exists. This is a
  required usability repair, with no new scientific acceptance credit.

- 2026-10-03, Big Boss: optional `parked_sources` preserves unchecked snapshots;
  shared native admission/validation avoids a parallel contract. `sources` remains
  the only job input. Old selections stay checked; old jobs/revisions remain intact.
- Win64 FPC 3.2.2 passes 106 project and 69 real worker checks. Worker fixtures
  retain an unchecked whole recording while training only checked passages;
  empty training is rejected. Actual browser QA selects five of six passages,
  switches whole/passage choices, saves/reloads and completes a 20-second audition
  from exactly five ranges / 30 seconds. Overlap feedback and keyboard focus pass.
- Actual 390px/1280px layouts, pause/resume, exclusive playback and a six-second
  late-passage request with exact endpoint stop pass. No console errors; all owned
  tabs and the QA service are closed, with zero active audio.
- Repaired temporary editor-script encoding damage before compilation; no original
  user work was lost. Initial default compiler checks were Win32; final validation
  and delivery explicitly use the verified Win64 compiler. Final viewport evidence
  checks actual dimensions after asynchronous browser resize.
- The restart guard rejected a trailing space in the old Windows process command.
  Its local comparison now trims surrounding whitespace while retaining exact
  executable/catalog and worker/job/network checks. The old process stayed running
  until that discrepancy was verified and repaired.
- All 3,943 existing operator JSON/JSONL hashes are unchanged. Read-only live
  verification shows the existing Lofi passage checked. No operator answer or
  musical verdict was submitted. [studio_03](../NS-6_studio_03.md) and
  [authoring_02](../NS-6_authoring_02.md) retain their physical/usefulness gates.
  No extra credit. Consecutive nonclosing count: 0.
