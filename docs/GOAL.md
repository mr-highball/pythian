# Current goal: experimental instrumental synthesis through WFC

Pythian's long-term ambition is a reusable Pascal synthesis library for any caller's musical style. The current goal is to make that ambition directly testable in Studio: generate bass, drums, harmony and lead through a rich, editable WFC musical graph, perform those decisions through Pythian instruments and effects, and let the operator hear, change and judge the result.

The operator's 2026-10-29 direction supersedes the previous benchmark-first delivery order and assigned percentage credits. [Implementation review](ASSESSMENT-2026-10-29.md) · [Tasks](TODO/README.md) · [Effort-derived progress](MILESTONES.md) · [Workflow](TASKFLOW.MD).

## What we are building

- **Real instrumental output.** Generated musical events drive Pythian oscillators/noise, wavetable, additive/FM/PM and layered instrument recipes, envelopes, modulation, filters, buses and effects. Source recordings teach or provide comparison context. A deliberately selected sampler instrument is explicit; assembling windows from a full training mix is not the primary output path.
- **The breadth of the musical graph.** Time is the primary horizontal axis; bass, percussion, harmony, lead and other roles are visible lanes. Context, pitch/register, rhythm/groove, expression, musical affect, sound and structure have explicit dependencies, domains and editable controls. Inspect actual dimensions, passes, vocabularies and constraints. Change the model layout or add a useful dimension/pass when listening exposes a need; do not fix a giant arbitrary grid in advance.
- **Studio as the experimental laboratory.** Choose musical material and instruments, generate, inspect the score/graph, hear the full mix or individual parts, change one or several dimensions, retain useful parts and regenerate the rest. Compare Original reference and synthesized Before/After, save optional notes and prepare the next deliberate experiment. Tabs, contextual help, touch-friendly tools and obvious next actions are core requirements.
- **Learning without waiting for a proof dossier.** Reuse available WAV analysis, authored symbolic examples, MIDI and operator-provided context to propose graph inputs. Expose uncertain/inaccurate proposals as Experimental and let the operator correct or bypass them. Reliable universal transcription, fully calibrated confidence, independent reference packets and fixed genre/corpus floors are not prerequisites to trying synthesis. Authored, measured, proposed and operator-selected inputs keep their actual origins.
- **Reusable styles and evolving music.** Learn from whole tracks or coarse selected passages across private collections; classifications must have an explicit musical/control effect. Save actual graph/provider and instrument recipes, blend dimensions from different styles, and reuse a blend in further blends. Explore phrases, sections, repetition and variation in sustained instrumental output rather than using short reconstruction clips as evidence.
- **Efficient, visible execution.** Native jobs survive phone backgrounding, have useful progress/cancellation and reconnect cleanly. Long generation uses bounded lookahead and streamed synthesis with continuous note/effect state. Duration, graph size and vocabulary are user-visible settings within honest practical limits.

## First useful milestone

Connect the existing musical graph and synthesis runtime, add explicit synthesized percussion, then wire that result into ordinary Studio generation. The operator can play bass + drums + harmony + lead, solo parts, change tempo/key/instruments or a musical constraint, regenerate and compare. Begin with editable authored/experimental material if WAV proposals are unavailable. A single sine-note preview or a raw-grain render cannot stand in for this outcome.

After that milestone, expose the graph workbench and deeper sound controls, connect experimental recording-derived providers and coarse corpus learning, and extend form, styles/blends and long instrumental playback. [The task dependency graph](TODO/README.md) defines the actual prerequisites; analytical qualification is not inserted as a blanket gate.

## How we decide what to build next

Before a batch, name the audible/operator criterion, usable deliverable, minimal relevant checks and stopping point. Keep replay information automatically: graph/schema, seed, musical plan, instruments, source/proposal choices and saved feedback. Listening determines which musical/model changes to try next. Tests protect data, clocks, ownership, failure handling and the implementation being exercised; they are not a substitute for trying music.

Keep poor outputs and genuine uncertainty. Saving feedback does not silently train or regenerate. Do not create more source microclip labeling, grain-continuity variants, broad callback audits, comparison frameworks or adoption paperwork unless a concrete instrumental experiment is blocked by that work.

## Boundaries and current status

All implementation, analysis, inference, codecs and maintained tools remain Pascal-owned and shared by native/pas2js consumers. Core-only use remains independent; WFC is integral to the complete product. Audio/musical adaptation stays here. A demonstrated generic WFC gap uses its separate local repository and a new branch, with notice to the user. Preserve source licenses, private recordings, operator answers and historical failures.

Big Boss works alone until the operator changes staffing. Work on hello-pythian in the existing repository; new build/test/cache/run output belongs under the dedicated E-drive workspace. Reuse fixed deployed review-service slots and existing minimal local security.

The operator resumed implementation solo after this goal/backlog reset. The two answered reconstruction reviews remain historical feedback; no more work on those reconstruction mechanisms is selected.

## Progress means effort delivered

Every active task has a 1–10 effort estimate. Completion is computed from completed effort divided by the total effort of open plus completed tasks in this goal. Adding tasks grows the denominator; partial work, planning and retired tickets earn no completion. The 97 historical accepted records remain reusable evidence but contribute no points to this new goal. The former 52.45% outcome-credit score is historical and is not comparable to this estimate-based scope indicator.

Completing this goal means delivering and reviewing the defined experimental synthesis workflow. The effort ratio is not a musical-quality, transcription-accuracy or ecosystem-adoption score.
