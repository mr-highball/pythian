# Implementation review for the synthesis-first reset — 2026-10-29

This assessment describes the reset at 072ba42. Later accepted runtime work is
recorded in [WORK](WORK.md), [milestones](MILESTONES.md) and the
[instrumental API guide](INSTRUMENTAL.md); dated gap statements below remain the reset snapshot.

[Goal](GOAL.md) · [Active tasks](TODO/README.md) · [Work](WORK.md)

Big Boss reviewed the primary implementations, their maintained callers and existing qualification records. This is a source/consumer assessment, not a fresh performance benchmark or a claim that the new Studio path already works. The library is substantially broader than the acoustic reconstruction path exposed by Studio.

| Area | Implemented and reusable | Gap for this goal |
| --- | --- | --- |
| Sound and instruments | [TSynthVoice](../src/pythian.synth.pas), oscillator/noise, wavetable/sample sources, additive and FM/PM, envelopes, automation, [key/velocity layered instruments](../src/pythian.instrument.pas) | Usable editable bass/lead/chord/percussion recipes and their Studio bindings; no need to replace the synthesis engine |
| Processing | Primary filters/dynamics, effect chains, delay/reverb, routing and buses; [capability map](FUNDAMENTALS.md) | Expose real per-part recipes/automation and audible comparisons through the instrumental consumer |
| Musical WFC | [Negotiated layers](../adapters/wfc/pythian.wfc.layers.pas), [named voices](../adapters/wfc/pythian.wfc.voices.pas), context, rhythm, harmony, ranges, pair policies, projections, locks/preferences and selective regeneration | Studio cannot currently create/control this complete musical plan; its visible graph must reflect actual execution |
| Existing instrumental callers | [Voices demo](../tools/pythian.voices.demo.lpr) already learns authored harmony/rhythm/bass/chord/melody models and realizes native audio/MIDI; [layer demo](../tools/pythian.layers.demo.lpr) does actual coupled generation | These are real starting implementations, not an end-to-end instrumental Studio mode or learned mixed-recording roles |
| Recording analysis | Beat/tempo/key candidates, onsets/intensity, monophonic pitch/gates, sound/harmonic/envelope analysis, import/MIDI/sine preview | Mixed-recording part attribution and trustworthy general automatic musical learning remain uneven/incomplete. Expose proposals and overrides for experimentation; do not require their formal acceptance first |
| Reusable style | [Semantic styles](../adapters/wfc/pythian.wfc.semantic.style.pas) and provider-specific blends/reblends, retained controls, sound bindings and source ancestry | A usable Studio editor/learning/generation loop on these actual providers; coarse classifications currently do not automatically mean musical instructions |
| Time and streaming | Exact musical clocks, note/instrument rendering, scheduler, [finite duration edits](../adapters/wfc/pythian.wfc.duration.stream.pas), bounded streamed ensemble callers | Current hours-long Studio audio is acoustic. Continuous flexible instrumental planning and browser playback still need integration |
| Structure and affect | Authored [144-bar composition](../src/pythian.music.compose.longform.pas), generic caller traits, musical preferences and automation | No general learned phrase/form vocabulary or automatic mood semantics. Build editable experimental mappings and structure providers |
| Studio | Collection/import/capture, waveform/range tools, effects, native jobs, review store, source reference and saved feedback | [Job admission](../tools/pythian.tools.studio.jobs.pas) currently allows only raw_acoustic for ordinary generation. [Pitch preview](../tools/pythian.tools.studio.pitch.pas) is a separate single-pitch sine/MIDI path. Neither exposes the full instrumental graph |

## Graph architecture findings

The existing independent-voice adapter creates aligned N x 1 x 1 named passes for harmony, joint rhythm actions and each pitched voice, plus small coverage witness passes when exact harmonic coverage is selected. Generic layer/mapped-provider APIs additionally support explicit time mappings, unequal grids and dependency projections. This is much richer than one acoustic-token pass, but it is not already an arbitrary editable time-by-role-by-parameter Studio lattice.

The generic WFC engine has spatial dimensions and multiple passes. A role lane can be a named pass displayed against time, or a true additional grid axis where its semantics and neighbor rules are useful. Pitch, tempo, affect and effects need explicit domains/mappings, not merely labels on an extra axis. The new workbench must show which representation is actually executed and let listening guide changes.

Percussion requires special attention: the current named-voice configuration carries pitch ranges, harmonic membership and pitch-class coverage. Drum events must not accidentally be treated as chord members. Existing noise/oscillator/envelope/filter primitives can synthesize drum sounds; their role vocabulary and coupled musical integration need an explicit Pythian contract. No generic WFC defect is demonstrated by this assessment, and no upstream branch change is selected.

## What the reviewed clips established

The 4:16 review used one acoustic WFC pass per 256-cell chunk, 16 sound categories/235 latent states, and recorded 4096-frame windows at 16 kHz. The two-minute pair used one pass per 128-cell chunk, 8 categories/47 states and 4096-frame windows at 48 kHz; its model learned only the selected 156.171-second passage. Both are order-two acoustic recombination. After's source-successor selection changes physical windows without changing the WFC token sequence.

The operator answered no to the old short-loop question and preferred After for fewer broken/jittery notes. These answers remain in the existing catalog. They do not establish instrumental composition; the user explicitly rejects spending further effort on those reconstruction mechanisms. Retain audio/answers and stop that lane.

## Delivery decision

Make an audible instrumental Studio experiment the first acceptance boundary. Reuse the existing musical/synthesis implementations and useful Studio scaffolding. Let authored or operator-supplied musical material bootstrap generation; experimentally derived WAV providers can be connected and corrected while their quality is investigated. Formal inference/reference/adoption requirements from the retired roadmap do not block this work.

A first successful loop needs the runtime, explicit percussion and Studio job/UI connection. The following tasks expose graph/control breadth, sound recipes, experimental learning/corpora, musical form, saved blends, meaningful reviews and efficient long instrumental sessions. Those are the 12 active tasks, totaling 82 relative effort units, not assigned completion percentages.

The [retirement map](TODO/RETIRED/2026-10-29/README.md) records all 53 former open tickets: useful portions map to the new outcomes; benchmark-first, raw-reconstruction, generic audit and external-adoption gates leave the active goal. Nothing moved to DONE. Historical accepted code/tests/licenses, private data and failure evidence remain. No product source, vendor source, deployment, training or audio generation changes in this reset.
