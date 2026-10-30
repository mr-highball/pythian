# Studio: instrumental experiment workspace

[Current goal](GOAL.md) · [Implementation assessment](ASSESSMENT-2026-10-29.md) ·
[Tasks](TODO/README.md) · [LAN setup](LAN-REVIEW-SERVICE.md) · [Work](WORK.md)

## Current capability and the gap

Studio already has private collections, explicit training inclusion, whole-track
and passage selection, waveform/range controls, recording/import, analysis and
Experimental pitch/MIDI preview, effects, persistent native jobs and listening
feedback. The primary generation route is now **Synthesized instruments ·
Experimental**: authored symbolic material drives actual WFC musical passes and
Pythian instruments. It does not read or chop up a reference recording.

The finite mode has tempo/key, seed, 1–32 four-beat bars, three pitched oscillator
choices and six part levels. Native jobs persist a full mix, six stems and the
actual sixteen-pass/two-group graph summary and symbolic plan. Play the mix or
use synchronized mute/solo; successful jobs enter the existing listening queue
and can be selected for Studio feedback. Reviewed settings restore for a new
deliberate experiment. [Instrumental Studio](TODO/DONE/NS-6_instrumental-studio_01.md)
records acceptance and limits. Its foundations are the
[shared runtime](TODO/DONE/NS-4_instrumental-runtime_01.md) and
[explicit percussion](TODO/DONE/NS-2_percussion_01.md).

Start with Project → name → Save draft → Generate → Check setup → Generate
instruments → Jobs. Recordings are optional references in this mode; waveform
analysis and reliable recording-derived providers are not silently implied.
The legacy recorded-fragment experiment remains explicit in old projects.
Graph editing, richer sound recipes and efficient long instrumental streams are
remaining tasks, rather than claims made by this finite starter.

## Intended operator loop

1. **Sources:** browse private recordings or import/record; include whole tracks
   or coarse passages and give useful classifications. Hear originals directly.
   Clearly show what is included, analyzed, excluded and actually used.
2. **Generate:** use editable starter musical material or available recording
   proposals, pick instruments/roles/context and generate an instrumental job.
   Uncertain proposals are Experimental and may be corrected or bypassed.
3. **Inspect:** see actual time/role mappings, dimensions, named passes,
   vocabularies and constraints. Hear mix/solo parts; change context, rhythm,
   pitch/register, expression, sound or affect mappings; retain useful parts.
4. **Review:** hear Original reference and synthesized Before/After, answer one
   clear question with optional notes, then Save/Next. Explicitly queue the next
   experiment; saving feedback never silently retrains.

The [graph workbench](TODO/NS-4_graph-workbench_01.md) and
[controls](TODO/NS-4_graph-controls_01.md) expose real backend behavior.
[Reviews](TODO/NS-6_synthesis-reviews_01.md) bind answers to exact plans/settings
and a development decision. [Long instrumental jobs](TODO/NS-6_instrumental-streams_01.md)
extend bounded native streaming, truthful progress and mobile reconnect.

## UI and execution requirements

Favor tabs and contained steps over a long scroll. Keep useful playback near the
selected material, preserve unsaved edits, and use contextual modal help without
jumping the page. Give each busy, empty, error and saved state an obvious next
action. Use concise Experimental labels instead of proof disclaimers.

WAVs remain in ignored private collection folders; the existing catalog and
source-family lineage are reused. Discovery lists metadata and preparation runs
only for selected use. Saving derived effects audio preserves the original.
Browser microphone permissions/secure context remain platform requirements.

Use native durable jobs so phone backgrounding does not terminate generation.
Keep learning/preparation/output duration distinct and use bounded audio
lookahead, held-note/envelope/effect state and user-selected output length.
A duration setting or render speed is not evidence of musical continuity.

Keep implementation and inference Pascal-owned, share primary library logic and
reuse existing UI/service/job/answer contracts. Do not build a second solver,
renderer, observation store or generic review framework.

Local use needs no login/accounts or repeated approval flow. Retain automatic
same-origin sessions, folder containment, input checks, explicit recording and
bounded work/cancellation. Protect live operator data from authored QA inputs.
Actual changed browser interactions require desktop/narrow checks; do not claim
physical phone validation from emulation.

## Historical scope

The [previous Studio scope](history/OPERATOR-STUDIO-2026-10-29.md), its percentage
allocation and old benchmark-first prerequisites are historical. The
[retirement map](TODO/RETIRED/2026-10-29/README.md) assigns useful unfinished scope
to new tasks. Existing accepted features and failed cases remain evidence; none
is automatically new-goal acceptance. [Effort-based accounting](TASKFLOW.MD#effort-and-derived-completion)
replaces assigned percentages. The operator has resumed implementation solo.
