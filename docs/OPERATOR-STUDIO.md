# Studio: instrumental experiment workspace

[Current goal](GOAL.md) · [Implementation assessment](ASSESSMENT-2026-10-29.md) ·
[Tasks](TODO/README.md) · [LAN setup](LAN-REVIEW-SERVICE.md) · [Work](WORK.md)

## Current capability and the gap

Studio already has private collections, explicit training inclusion, whole-track
and passage selection, waveform/range controls, recording/import, analysis and
Experimental pitch/MIDI preview, effects, persistent native jobs and listening
feedback. The existing ordinary generation path is **raw acoustic recombination**.
It does not currently expose the full instrumental graph.

The [instrumental Studio task](TODO/NS-6_instrumental-studio_01.md) changes that
ordinary path to real musical WFC decisions played through Pythian instruments.
This is planned work, not a description of an already available mode. Its true
prerequisites are the [shared runtime](TODO/NS-4_instrumental-runtime_01.md) and
[explicit percussion](TODO/NS-2_percussion_01.md).

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
replaces assigned percentages. Implementation remains paused.