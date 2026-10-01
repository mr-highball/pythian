# Operator studio delivery scope

[Tasks](TODO/README.md) · [Milestones](MILESTONES.md) · [Work](WORK.md) ·
[Existing listening contract](FULL-OUTPUT-LISTENING.md)

The user's 2026-09-30 direction makes the web app a musical experiment workspace:
choose substantial training material, generate shorter auditions, classify and
compare them, then deliberately prepare the next batch. UI/UX is part of each
deliverable's acceptance, not polish deferred until after the backend.

## Operator flow

1. **Sources:** put WAV recordings in private collection folders, then refresh
   the library. Name a style corpus and select whole recordings or several
   passages, adding caller-defined classifications to each selection. Folder
   names organize browsing; classifications express the operator's judgments.
   Show selection count and duration, with ranges expressed in source time.
   Explore waveform and measured/candidate analysis overlays, then optionally
   audition an ordered effects rack and explicitly save a derived collection
   clip. Preserve original audio and source-family lineage through every version.
   Import a WAV or explicitly record a microphone into temporary preparation;
   inspect and listen before choosing Save to collection. Try the existing pitch
   tracker through MIDI download and synthesized playback, marked **Experimental**.
   Keep technical settings in optional details and save feedback on the exact run.
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

Local-use policy: no accounts, login screens or repeated confirmation prompts.
Keep automatic same-origin sessions, folder containment, input validation and
finite work limits. Preserve originals and source lineage. Browser microphone
permissions and secure-context requirements are platform constraints, not an
additional application approval flow. Add security machinery only for a concrete
local risk or an explicitly selected deployment requirement.

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
| [delivery_03](TODO/NS-6_delivery_03.md) | 10 | 3 | Final package and extracted workflow |
| [delivery_04](TODO/NS-6_delivery_04.md) | 12 | 8 | Independent complete-workflow reproduction |
| [studio_01 — DONE](TODO/DONE/NS-6_studio_01.md) | 0 | 4 | Durable intuitive project/source setup |
| [studio_02](TODO/DONE/NS-6_studio_02.md) | 0 | 2 | Actual bounded jobs and automatic audition queue |
| [studio_03](TODO/NS-6_studio_03.md) | 0 | 2 | Musical comparison and deliberate iteration |
| [studio_04](TODO/DONE/NS-6_studio_04.md) | 0 | 2 | Private collection discovery and classified corpora |
| [studio_05](TODO/DONE/NS-6_studio_05.md) | 0 | 2 | Layered effects preview and derived collection clips |
| [studio_06](TODO/DONE/NS-6_studio_06.md) | 0 | 2 | WAV import, microphone capture and analysis exploration |
| [studio_07](TODO/NS-6_studio_07.md) | 0 | 1 | Mixed-format corpus conversion with original lineage |
| **Total allocation at scoping** | **30** | **30** | **Scoping earned no credit** |

The added operator outcomes receive explicit weight from later verification
work. Those verification obligations remain required at reduced planning weight;
they do not disappear or move into the new tasks. Scoping left 49.40 accepted;
independent project/setup acceptance subsequently adds 4 NS-6 / 0.40 overall.
Private corpora, raw WFC jobs, effects and capture/exploration add 8 NS-6 / 0.80 overall.
The current ledger is **50.60 accepted / 49.40 remaining**, **45 open / 40 DONE**.
NS-6 is **43 accepted / 57 unearned** with nine open tasks. Goal weights are unchanged.
The later collection and effects requirements each reallocate one unearned point
from jobs and iteration; all original criteria remain. Scoping earns no acceptance.
Capture/exploration receives two additional unearned delivery_03 points with
all final packaging criteria preserved.
Mixed-format corpus preparation receives one further unearned delivery_03 point.
It follows the current review batch; matching-rate/channel generation remains
the declared supported route until conversion and original-frame maps pass.

The studio is a current NS-5 calibration enabler, attributed primarily to NS-6
usability. Actual calibration/control validity remains evaluation_01; complete
musical references remain evaluation_04; inference and many-hour style quality
keep their existing owners. Final packaging includes all seven studio outcomes.
Old source-marker and physical QA failures remain with authoring_02 and Big Boss;
new task identities do not reset those counters or reopen stopped science.

## Private collection library

The default durable drop folder is `local-audio/collections/`, excluded by the
root `.gitignore`. Create caller-named subfolders and place WAV recordings in
them. Keep this directory backed up with personal media; it is deliberately
outside disposable `build/`. Audio, private collection names and local indexes
are not source artifacts. Compressed audio is not yet a maintained import format.

[studio_04](TODO/DONE/NS-6_studio_04.md) owns app discovery, explicit refresh,
collection browsing and classified selections. Folder grouping never assigns a
scientific genre, training partition, license or musical truth. New recordings
start unassigned; existing catalog evaluation reservations remain enforced.
Original audio stays immutable once imported, and a changed file is a new source
identity. Old saved corpora retain their exact bytes/ranges and classifications.

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

A saved draft is explicitly not trained. At that checkpoint, actual source
audition and bounded asynchronous learning/generation remained in studio_02.
That later outcome now passes with the policy and evidence below. No musical or
physical-phone acceptance follows from project setup, and old inference/source/
comparator stop counters remain intact.

## Current Studio evidence — 2026-10-01

Private classified corpora, bounded raw WFC jobs, effects/derived clips and
import/capture/exploration are accepted through independent stable Win32/Win64
and desktop/narrow checks. The comparison/next-batch loop passes its engineering
checks; studio_03 still requires the operator's understandable-purpose,
audible-use and useful-feedback
verdict. Microphone controls were exercised with a generated browser device;
physical microphone quality and the phone listening path remain unverified.
See the [current work record](WORK.md) for source identities and exact scope.

## Connected Studio contracts

The service and browser use explicit actions. Saving a project, feedback or an
edited clip never silently enqueues training. Native worker execution is a
separate executable; the service and portable library compile without WFC.
The worker retains the actual companion WFC model and renders through its
Pythian audio adapter. The currently connected learning route is raw acoustic
recombination. Experimental pitch previews are a separate listening tool.

| Action | Native contract |
| --- | --- |
| Browse / refresh collections | `GET /api/studio/library`; enqueue `library_refresh` |
| Check / generate | `POST /api/studio/preflight`; `POST /api/studio/job` with `train_generate` |
| Inspect or cancel work | `GET /api/studio/jobs`, `GET /api/studio/job?id=ID`, `POST /api/studio/cancel` |
| Inspect / process a passage | Jobs `inspect_source`, `effect_preview`, then explicit `effect_save` |
| Import WAV / captured PCM WAV | `POST /api/studio/capture/start`, then offset-bound `capture/chunk` writes |
| Inspect / hear notes / save intake | Jobs `capture_inspect`, `capture_pitch`, `capture_save` |
| Discard temporary intake | `POST /api/studio/capture/discard`; cancel its active job first |
| Compare / respond / pin | `POST /api/studio/review`, `review/response`, `review/pin` |
| Prepare next batch | `GET /api/studio/review/next-batch?id=ID&sample=ALIAS`; does not enqueue |
| Save exploration feedback | `POST /api/studio/exploration-feedback`, bound to the completed job |

Jobs retain immutable requests and append-only state events beneath the private
catalog's `studio/` directory. Requests use stable identities so a lost response
can be reconciled. One worker runs per catalog, with at most 32 queued and 256
retained jobs. Work stops at ten minutes; cancellation terminates a child that
does not cooperate. Interrupted active jobs become failed rather than ready.
Completed source/model/audio hashes and original-frame lineage remain retained.
Partial seed outcomes remain visible; incomplete batches do not enter listening.

A corpus permits 64 nonoverlapping selections across 32 recordings, with up to
eight caller classifications per selection. Training uses every declared range
or rejects the workload: at most 500,000 feature observations and 32 GiB of unique
source bytes, with a 128 MiB logical allocation budget. Generation offers one to
three 20–40 second auditions, explicit seeds, source weights, palette size and
model order. Retained palette/candidate counts are distinct from analyzed source
coverage. Model reuse verifies the same source/policy identity. These limits
describe the current operator route, not completion of many-hour musical learning.

Effects process a selected passage of at most 30 seconds / two million frames.
The rack supports eight ordered, bypassable gain/filter/compressor/limiter stages.
Each preview starts with reset DSP state, produces stereo PCM16 at the original
rate and adds no tail or hidden limiter. The compressor uses a recorded 6 dB knee.
The result reports pre-encoding peak and clipped samples. Saving retains the
exact recipe and source family, including further derived versions.

Temporary intake lives under ignored `build/studio-capture/`, separate from the
durable collection. Up to eight inputs may be retained, each at most 128 MiB;
uploads use verified 16 KiB chunks. Analysis accepts mono/stereo WAV at 8–192 kHz
and initially inspects up to 30 seconds / two million frames. Microphone capture
records at most two minutes, encodes PCM WAV in the Pascal browser adapter and
does not monitor the microphone through the speakers. Stop/exit releases tracks.

The **Experimental** note preview runs the existing single-pitch tracker on up
to the first eight seconds of the selected channel, using native sinc conversion
to 8 kHz. It retains unknown/silent spans separately and exports pitched spans
through the existing MIDI codec. Caller BPM defines the MIDI clock, not an
inferred tempo. Playback uses the existing sine synthesizer with fixed velocity;
silence produces no fabricated notes. The original, exact analysis settings,
MIDI/audio hashes and explicit listening feedback remain attributable. The UI
keeps these details optional and permits trials on mixed material.

Listening comparisons retain versioned responses in the existing listening
journal. Blind assignments use opaque sample aliases and reveal only after the
first completed response; withdrawing feedback does not make exposed identities
blind again. Pins and next-batch ancestry preserve earlier audio and settings.
Mechanical browser answers establish engineering behavior only. The operator's
actual usefulness/musical verdict remains an explicit studio_03 acceptance gate.
