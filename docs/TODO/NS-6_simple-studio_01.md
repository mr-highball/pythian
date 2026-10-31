# NS-6_simple-studio_01 — Library → Selection → Generate

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Replace the operator's confusing Studio workflow with three clear steps. Browse
the local music folder and make a playlist; choose whole tracks or passages;
set output length and track influence, then Generate. Primary attribution: NS-6.
Keep private music, saved selections, answers, provenance and native jobs.
This is a new operator outcome, not retroactive credit for the earlier Studio.

**Acceptance Criteria:**

- AC1: Library is the starting screen. Search titles/tags and browse collections
  in a compact music list with play/pause and Add/Remove playlist actions. Folder
  access, adding files and microphone recording are obvious. Browsing uses metadata;
  it does not fetch or process entire recordings. No project/save/setup gate.
- AC2: Selection shows the playlist and its saved clips. Whole tracks are a clear
  default; choose one or several passages instead, audition them and see exactly
  what will teach Pythian. Preserve choices automatically without scroll-heavy
  forms or an accidental change of training inclusion when playing audio.
- AC3: Generate needs only duration and optional per-track learning influence.
  One action prepares sources, learns from the actual included music and performs
  new instrumental output. No mandatory manual proposal approval, labeling queue,
  model editor, engine choice or authored-only fallback. Use the linked corpus
  learning implementation; uncertain supported learning is simply Experimental.
- AC4: Show truthful preparation/learning/generation progress, cancellation and
  reconnecting native jobs. Play/pause/seek and save the result in the same step.
  Saving selections/feedback never silently trains. State actual duration limits;
  do not turn a long instrumental request into recorded fragments.
- AC5: Exercise the actual desktop and phone browser journey with multiple tracks,
  whole/range choices, import/record entry, weights and generated playback. Prove
  those controls reach the actual native learning/synthesis path. Keep optional
  help beside its control, with no navigation jump or competing/leftover audio.

**Blockers**

- [Style vocabulary](NS-3_style-vocabulary_01.md) — Generate must actually learn
  from the chosen playlist. Library/Selection implementation can proceed now.
- [Instrumental streams](NS-6_instrumental-streams_01.md) — requests beyond the
  honest finite plan limit need this path; basic short generation does not.

**Dev Notes:**

- 2026-10-30, Big Boss, actual Generate integration: the simple action saves its
  pending selection and starts the existing durable instrumental worker using
  the immutable playlist revision. Included whole/clip audio is measured through
  shared Pascal observation/proposal/corpus implementations; source influence
  changes training counts. No authored fallback or source-window renderer is
  used. The UI has phase progress, Stop, saved-request retry/reconnect, mix WAV
  playback/save and a real original excerpt. Duration survives reload; current
  choices are distinguished from an older completed run. Browser recovery keys
  are isolated by a path-free server catalog identity, repairing a real stale
  catalog startup failure. JSON/network failures are converted into visible
  retry states rather than unhandled JavaScript exceptions.
- Actual in-app browser checks at desktop and 390 pixels cover two recordings,
  one 0:50–1:05 clip plus a whole 75-second recording, auto-save-to-Generate,
  5:1 influence, native completion, synthesized/original playback, page reload
  reconnect, duration restoration and Stop. Record opens the short capture
  dialog directly; physical phone microphone capture is not newly qualified.
  Native playlist (45 checks) passes with clean heap, including cold/warm whole/range
  learning and the actual worker. Finite length is explicitly 2–30 seconds plus
  release tail; the linked long-generation task remains a prerequisite for
  broader durations. Keep this task open and accept no partial effort.
- Retain all repaired failures under E-drive musical-corpus-20261030-boss:
  Windows MAX_PATH staging, oversized frame read, missing reference metadata,
  stale browser catalog recovery, sparse single-seed JavaScript array creation,
  HTTP error parsing and transient stale-result/start/cancel UI. Shared short
  staging and explicit E-drive proposal cache roots replace implicit paths.
- Final browser checks also exercise visible media seeking, actual WAV download
  and byte identity, a disabled Generate button at zero included duration, and
  the older-result notice after selection changes. Native learning skips an
  excluded unavailable recording without removing its saved choices. The real
  default Library contains music-folder collections, excluding uncollected
  development fixtures. The fixed stable slot is deployed with the actual
  lofi/chillwave/stoner-rock collection list checked; no operator jobs were active
  during replacement. Keep all private recordings and historical responses intact.

- 2026-10-30, Big Boss: Operator explicitly replaces the current app workflow.
  Live browser inspection confirms the disconnect: collection inclusion is only
  reference context for ordinary instrumental jobs; manually accepted musical
  choices or an authored starter drive them. A new visual shell alone cannot
  accept this task. Reuse collection, original playback, range tools, capture,
  durable jobs and the primary Pascal implementations; remove the superseded
  main flow instead of preserving its confusing forms for compatibility.
- Batch criterion: pick local music into a simple persistent playlist and choose
  its training extent. Deliver the first two actual steps and their shared native
  contract; validate metadata-only browsing, source/range identity, persistence,
  playback and phone/desktop controls. Stop that batch at those usable criteria,
  then connect weighted corpus learning and instrumental Generate. No task effort
  is accepted until every criterion passes. The previous unfinished full-plan
  restoration batch closed no criterion before operator steering; carried
  consecutive nonclosing count is one, not reset by this new direction.
- 2026-10-30, Big Boss: AC2's saved-selection boundary passes in the actual
  in-app browser at desktop and 390-pixel phone width: two tracks, a full
  recording plus two disjoint clips (including 1:00–1:10), independent audition,
  whole/clip switching, weights 6:1, automatic revision saves and reopening the
  same choices. Original clocks remain exact. Native project128/playlist17 pass
  Win32/Win64 with clean heaps. Playlist saving performs no audio reads; an
  exclusively locked original and missing-source edits pass. Retained component
  recovery52/reference24 pass using dedicated test hosts instead of preserving
  obsolete mounts in product HTML. Repair the stale KiB/MiB assertion, not the
  truthful byte formatting. This closes one real criterion and resets the
  consecutive nonclosing count to zero; no task effort is accepted yet.
- Capture82 passes Win64, including a locked unrelated recording during save.
  Capture now uses primary selected-file preparation instead of rehashing the
  entire library. Actual browser import → inspect → library save passes;
  Record opens directly on the microphone control. Physical phone recording
  remains unverified in this batch. An import of already catalogued bytes keeps
  the first catalog title despite its newly requested display title; repair
  that remaining Library detail before AC1 acceptance.
- Generate is explicitly unavailable in this isolated preview; native admission
  also rejects sending a playlist into the older authored-only instrumental
  path. AC3–AC5 remain open. Next: actual weighted whole/range musical learning,
  then the minimal durable Generate/result flow. Stable Studio is untouched.
