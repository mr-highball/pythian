# Operator studio delivery scope

[Tasks](TODO/README.md) · [Milestones](MILESTONES.md) · [Work](WORK.md) ·
[Existing listening contract](FULL-OUTPUT-LISTENING.md)

The user's 2026-09-30 direction makes the web app a musical experiment workspace:
choose substantial training material, generate shorter auditions, classify and
compare them, then deliberately prepare the next batch. UI/UX is part of each
deliverable's acceptance, not polish deferred until after the backend.

## Operator flow

1. **Sources:** name the style and describe the intended musical qualities;
   choose imported recordings, with full recordings as the default and optional
   ranges expressed in source time. Show selection count and duration.
2. **Prepare:** show the actual supported learning mode, material used/excluded,
   saved model and generation settings. Audition selected originals with a
   visible source-time playhead and range context. Keep training duration separate from
   audition length. Explain unsupported choices before work starts.
3. **Listen:** start with a small development batch of roughly 20–40-second
   auditions. Ask one clear musical question at a time, retain unsure/neither,
   and allow optional comments at the playhead. No routine frame annotation.
4. **Refine:** compare against earlier results, pin useful examples, deliberately
   change a supported control or source selection, and queue a traceable new batch.

Short auditions help development but do not replace full-duration continuity or
the current 120-second acceptance protocol. A prospective development policy
records its duration/count/seeds without relabeling those outputs as the fixed
acceptance packet. A small set of user ratings establishes preferences, not
automatically calibrated numerical limits or accurate source transcription.

## UI and evidence requirements

- Every screen states the current action and its completion state. Prefer
  concise labels, useful defaults and progressively disclosed detail to prose
  walls. Preserve keyboard focus, readable contrast, touch targets and mobile
  layout. Empty, busy, error, retry, conflict and saved states are product states.
- Distinguish imported/selected/actually used source duration. Never present
  raw long-file processing as learned notes, harmony or structure. Label raw
  acoustic recombination, reference-assisted notes and accepted inferred events
  according to what actually supplied the model.
- Classification is caller-specific and may use any style name. Separate style
  fit, preferred musical repetition, continuity and technical defects. A good
  style with bad joins must remain distinguishable from an off-style clean render.
- Preserve original assets, saved revisions and batch lineage. Saving a preference
  does not silently retrain or recycle generated material into source truth.
- Guided exploration may expose controls. Blind evaluation requires an actual
  masked assignment and a frozen policy, not just an A/B heading. Reviewed
  development material stays exposed; later independent evaluation stays separate.
- Keep all implementation/learning Pascal-owned and WFC orchestration outside the
  portable core. Reuse the existing catalog and listening event store. Protect
  the live operator catalog from authored QA responses and generated test assets.

## Allocation and ownership

Only unearned NS-6 points move. No accepted capability is withdrawn, no task is
completed by planning, and all original criteria in the donor tasks remain.

| Task | Previous NS-6 points | Current NS-6 points | Outcome |
| --- | ---: | ---: | --- |
| [authoring_02](TODO/NS-6_authoring_02.md) | 8 | 4 | Physical LAN/source operator qualification |
| [delivery_03](TODO/NS-6_delivery_03.md) | 10 | 6 | Final package and extracted workflow |
| [delivery_04](TODO/NS-6_delivery_04.md) | 12 | 8 | Independent complete-workflow reproduction |
| [studio_01 — DONE](TODO/DONE/NS-6_studio_01.md) | 0 | 4 | Durable intuitive project/source setup |
| [studio_02](TODO/NS-6_studio_02.md) | 0 | 4 | Actual bounded jobs and automatic audition queue |
| [studio_03](TODO/NS-6_studio_03.md) | 0 | 4 | Musical comparison and deliberate iteration |
| **Total allocation at scoping** | **30** | **30** | **Scoping earned no credit** |

The added operator outcomes receive explicit weight from later verification
work. Those verification obligations remain required at reduced planning weight;
they do not disappear or move into the new tasks. Scoping left 49.40 accepted;
independent project/setup acceptance subsequently adds 4 NS-6 / 0.40 overall.
The current ledger is **49.80 accepted / 50.20 remaining**, **45 open / 36 DONE**.
NS-6 is **35 accepted / 65 unearned** with nine open tasks. Goal weights are unchanged.

The studio is a current NS-5 calibration enabler, attributed primarily to NS-6
usability. Actual calibration/control validity remains evaluation_01; complete
musical references remain evaluation_04; inference and many-hour style quality
keep their existing owners. Final packaging includes all three studio outcomes.
Old source-marker and physical QA failures remain with authoring_02 and Big Boss;
new task identities do not reset those counters or reopen stopped science.

## Project setup contract

The native service exposes `GET /api/studio/sources`,
`GET /api/studio/projects`, `GET /api/studio/project?id=ID` and
`POST /api/studio/project` through the existing same-origin session boundary.
Project lists contain summaries; opening a project returns its source snapshot.
The `pythian.studio.project.write.v1` write carries a stable project ID,
`expected_revision`, project name, optional musical intent, requested learning
mode and 1–32 distinct imported recordings. Each selection is either the full
recording or an explicit half-open original-frame range. The UI presents ranges
as source time. Evaluation recordings remain unavailable for training selection.
Unassigned recordings can remain in a draft with that uncertainty intact;
actual job preflight must resolve their intended partition before learning.

Draft admission checks catalog metadata, byte length and WAV header geometry;
it does not hash or decode many hours of audio during an HTTP Save. Returned
source snapshots explicitly retain pending content verification, unknown song
boundaries and catalog-only exposure information. Actual verification and
learning admission belong to the asynchronous job preflight in studio_02.
The requested learning mode is intent, not proof of an available trained model.

Accepted revisions are immutable JSON documents under the catalog's
`studio/projects/ID/` directory. A stale differing write returns conflict;
an identical immediately preceding revision retry returns the already-saved
result. The store permits at most 256 projects and 100,000 revisions per project.
A process-wide lock and a cross-process `.write-lock` directory serialize writes.
An interrupted stage or leftover lock fails closed: stop every service/writer
using that catalog, preserve a backup of its Studio directory, and inspect the
accepted revisions before removing only the abandoned lock or stage. Never
remove either while a writer may still be active or delete an accepted revision
as a retry mechanism. Restart and reopen the saved project before continuing.

## First batch

Studio_01 is accepted on 2026-09-30 through two integrated components: the native
store/service boundary and the responsive operator page. Neo implemented new
Pascal store/tests; Ticket Guy implemented the Studio UI; Big Boss integrated
HTTP/builds and reviewed architecture/UI; Salty independently validated both.
Native checks pass 89 assertions on each checked Win32/Win64 target with zero
leaks. Actual browser desktop/390 selection, source-time edits, Save/fresh reload,
conflict/lost-response recovery, keyboard, empty/error states and navigation pass.
The first UI failure was repaired by explicitly marking later stages as coming
next. A final staging whitespace failure triggers the required second-failure
transfer to Big Boss, who repairs the formatting without changing behavior.
Exact QA cleanup is zero. Evidence and both failures remain in the
[accepted task](TODO/DONE/NS-6_studio_01.md) and ignored
`build/salty-studio-20260930/`.

A saved draft is explicitly not trained. Actual source audition and bounded
asynchronous learning/generation now follow in studio_02; the existing native
journal/WFC/model/render/listening APIs provide the starting path. Freeze the
supported mode, input/resource/output policy and stop condition before that
batch. No musical or physical-phone acceptance follows from project setup, and
old inference/source/comparator stop counters remain intact.
