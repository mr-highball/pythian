# Synthesized percussion and rhythm-dependent WFC parts

[Instrumental runtime](INSTRUMENTAL.md) · [Task](TODO/DONE/NS-2_percussion_01.md) ·
[Instruments](INSTRUMENTS.md) · [Milestones](MILESTONES.md)

## Core recipes

The portable [percussion unit](../src/pythian.percussion.pas) provides kick,
snare and closed-hat recipes using the existing oscillator/noise sources,
automation, ADSR, filters and layered instrument planner. It has no WFC, browser,
media-file or playback-device dependency.

- Kick: sine body with a falling physical-frequency curve.
- Snare: band-pass noise plus a quieter sine body.
- Closed hat: short noise through the primary biquad high-pass.

TPercussionSettings exposes gain, pan, gate/release seconds, physical body
frequency and cutoff. Definitions own their curves and native instrument.
PlanHit uses exact frame positions, velocity and deterministic seeds. Overlapping
hits layer through the primary renderer. Recipes require at least 8000 Hz and
reject invalid/nonfinite controls; they never silently clip a requested setting.
PercussionKey returns explicit GM keys for zone selection/export, not membership
in a musical chord. The physical oscillator frequency is independently controlled.

The [core-only example](../examples/pythian.example.percussion.lpr) writes three
two-second WAVs with velocity-controlled hits:

~~~text
pythian.example.percussion OUTPUT_PREFIX
~~~

It starts no device playback. These are experimental sounds for listening and
editing, not claims about the instrument identity of a recording.

## Percussion graph

The [Pythian adapter](../adapters/wfc/pythian.wfc.percussion.pas) uses the existing
generic learned-layer session. Each unpitched model emits canonical rest or
hit:1..127 velocity tokens. Caller-declared projections say which accepted rhythm
tokens permit a hit. No drum is routed through pitched harmony membership,
register, voice-leading or coverage-witness rules.

One actual graph group first generates harmony/rhythm/voices. A second actual
group pins a cloned rhythm provider to the first group's accepted public tokens
and generates the drum parts. This is conditional generation on the retained
rhythm, not joint backtracking between the two graphs. If percussion cannot fit
that rhythm, the whole new candidate rejects; the previous plan remains intact.

The starter's 64-cell full mix has sixteen actual 64 x 1 x 1 passes:

| Graph group | Actual passes |
| --- | --- |
| 0 | Harmony, joint rhythm, bass, harmony voice, lead, seven exact-coverage witnesses |
| 1 | Pinned percussion rhythm input, kick, snare, closed hat |

CopyGraph uses one shared description implementation for named and generic
sessions. GroupIndex distinguishes executed graphs; InputSourcePassIndex records
the pinned-input lineage. That lineage is separate from actual solver dependency
indices. Within group 1, each drum depends only on its rhythm input.

Enabled=false constrains the model to rest at every cell. It requires a learned
rest path; an incompatible explicit hit lock rejects instead of being erased.
HitWeight is a soft multiplier within the primary 1..1024 limit, not a guaranteed
hit density. Each role has explicit model origin, controls, sound settings and bus.

## Shared instrumental performance

TryCreateInstrumentalPlan optionally accepts percussion definitions. Pitched
generation/proof stays unchanged; percussion consumes its accepted rhythm.
Both groups use the same PPQ, tempo map and frame clock. The resulting plan
performs every part through the same buses and scheduler.

CopyMusic and CopyNotes retain their pitched-score meaning. CopyPercussionHits
exposes unpitched events with cell, velocity, tick, frame and physical gate.
CopyPercussionPart retains sound/control metadata; CopyPassTokens, CopyPassStates
and CopyModel expose actual model output for either group.

Plans own their accepted percussion instruments and curves. Keep a plan alive
through player construction; playing tones clone those resources. Existing
caller-supplied pitched source factories keep their original borrowed lifetime.
Cancellation or failed graph/instrument admission cannot replace the previous plan.

The [instrumental caller](../examples/pythian.example.instrumental.lpr) enables
drums explicitly:

~~~text
pythian.example.instrumental OUTPUT.wav 64 731 120 0 --drums
~~~

Its JSON sidecar includes both graphs, input lineage, actual tokens/states,
percussion seed, generated hits and complete drum settings. The mix uses the
primary harmony-bus echo and a master limiter. Authored training/constraints are
declared; no recording is analyzed or reconstructed. Ordinary Studio integration
remains the next task.
