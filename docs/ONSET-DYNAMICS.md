# Measured onset dynamics in reusable styles

[Home](../README.md) · [WAV styles](WAVE-STYLE.md) · [Named passes](LAYERS.md#named-sessions-and-selective-regeneration) · [Work](WORK.md)

Saved WAV styles can retain measured attack intensity as well as onset presence.
Actual WFC learns their joint history from independent weighted source samples.
Generated intensity controls native voice velocities through an explicit mapping;
an intensity-only edit preserves accepted key, tempo and onset state.

This measures aggregate recording energy near admitted onsets. It does not isolate
voices, recover MIDI velocity, measure perceived loudness or infer note durations.
Pitches, voicings, relative voice balance and one-cell gates remain authored.

## Native measurement and admission

[pythian.onset.dynamics](../src/pythian.onset.dynamics.pas) is independent of WFC.
`MeasureOnsetDynamics(Clip, Frames, WindowFrames)` measures forward windows at
strictly increasing source frames. The final window is shortened at EOF. RMS uses
mean squared sample energy across both channels before taking the square root;
opposite stereo phases do not cancel. Measurements retain headroom above unity.
The operator chooses `max(1, sample_rate div 50)` frames, approximately 20 ms.

`TOnsetDynamics` retains a window size and aligned Double RMS values. A zero window
with an empty array explicitly means unavailable. Bounds are 65536 onsets,
1..65536 frames per measured window and 16777216 declared sample visits. Values
must be finite, nonnegative and within the source Single sample range. Bad input
does not publish a replacement result.

`OnsetIntensityPattern(Admission, Measurements)` uses the maximum RMS among
**accepted** onsets in that source as reference. Rejected points do not influence
the reference or populate cells. Ratios `[0, 1/4]`, `(1/4, 1/2]`, `(1/2, 3/4]`
and `(3/4, 1]` become bands 1..4. An accepted zero measurement belongs to band 1;
an all-zero accepted reference rejects. Token 0 means no admitted onset, not
measured source silence. These are relative amplitude bands, not decibel or
percentile bins. The versioned policy intentionally removes overall source level.

## Saved learning and repeated blends

```text
pythian.style learn-dynamics CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys [PROVENANCE]
pythian.style blend LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_WEIGHT RIGHT_WEIGHT OUTPUT.pys
pythian.style inspect INPUT.pys OUTPUT.json
```

Existing context/WAV hash and onset-report contracts apply. Each source retains
raw RMS for every selected onset, including points later rejected by grid
admission, plus its window and measurement version. Inspection exposes those
values beside source coordinates and admission decisions.

`CopyRhythmModel` still returns the marginal onset model. `CopyIntensityModel`
returns an actual joint onset/intensity model: `pythian.rhythm.intensity.v1.0`
means no onset; suffixes 1..4 identify onset bands. Model order, source repetition
weights and independent sample boundaries match the rhythm model. Longer
recordings still contribute more observations. Observed timing/intensity history
is retained instead of independently generating arbitrary combinations.

`HasDynamics`, `IntensityPatternAt` and detached `EvidenceAt` measurements expose
the capability. Positive-weight sources must agree on its availability; unknown
measurements are never silently replaced with authored intensity. An inactive
zero-weight parent may have a different capability and retains its full ancestry.
A measured derived profile can be saved, loaded and blended again.

The current PYST format represents intensity with an optional source capability.
When present, measurement policy/window and aligned RMS values follow source
onset coordinates. The joint-model field is empty when active sources have no
dynamics. Source and derived nodes use one format regardless of their capabilities.
The decoder replays admission and weighted models, validating canonical bytes and
digests. Earlier developmental encodings are retired and regenerated from evidence;
there is no historical compatibility reader.
It does not reopen audio to remeasure it; hashes bind integrity, not authenticity.

## Pass dependencies and native realization

```text
pythian.voices.demo OUTPUT.wav --style PROFILE.pys [--rhythm-locks PATTERN] [--intensity-locks PATTERN] --verify
```

Enriched profiles build four named context passes: key, tempo, onsets and intensity.
The intensity model consumes onset presence through a complete WFC projection and
can negotiate an initial compatible onset path within existing budgets. After
acceptance, onset edits regenerate `[2, 3]`; intensity-only edits regenerate `[3]`
while retaining exact states of `[0, 1, 2]`. An incompatible intensity pin reports
contradiction instead of rewriting a preserved onset.

Masks contain exactly 64 cells: rhythm `x`, `.`, `?`; intensity `0`..`4`, `?`.
Question marks leave positions unconstrained. Both masks may be supplied in either
order after the profile option. A pin can resample other unlocked intensities
throughout the finite pass; it is not an instruction to change only one output cell.

The dependent five-pass voice stack is rebuilt. Each authored tone's velocity
becomes `max(1, authored_velocity * band div 4)`. Voice-specific token domains
enforce these velocities while existing harmony/rhythm/path constraints govern
pitch choices. This is finite hierarchical generation, not a single graph across
multiple resolutions or extraction of independent recorded voices.

## Verification scope

Native fixtures use opposite-phase stereo PCM to check RMS, shortened EOF windows,
exact band boundaries and exclusion of rejected measurements from the reference.
They compare a repeated blend's actual joint model against three manually specified
weighted samples, verify detached measurements, saved reload, modified
valid-digest rejection and unknown capability handling. Existing onset-only checks
remain in the same maintained fixture.

Recorded checks learn Pixel Sprinter and Opening Theme, save a first blend and
combine that saved result with Pixel again, yielding source repetition weights
2:1. Recordings, onset reports, declared source clocks and explicit C-major output
context are those in [WAV styles](WAVE-STYLE.md#recorded-evidence). An intensity-only
edit retains onset timing and changes native audio; a rhythm edit regenerates
dependent intensity. The output checker binds saved models, pins and WAV/MIDI
hashes, and checks every tone's velocity against the intensity mapping. Both checked
FPC versions pass companion preview/MIDI parity and native MIDI round-trip on
i386-win32.

Evidence: `build/style-dynamics-{stable,trunk}/`. This advances measured performance
behavior and granular controls. Learned pitches/roles, richer run scopes, automatic
timing admission and larger musical structure remain open.

Twenty-one profile/inspection/audio/fixture files match byte-for-byte across the
two compilers; five previous onset-only output/inspection files retain their bytes.
At that historical checkpoint, four onset-only fixture archives also retained
their previous bytes. The current format consolidation supersedes those archive
bytes; this is no longer a compatibility requirement.
An intensity pin incompatible with preserved onset presence leaves all four prior
output files intact. A controlled native WAV also passes measurement, learning,
generation and output checks equivalent to the added maintained build commands.
Comparisons: `build/style-dynamics-replay.log`. Full-suite/package refresh and
additional targets are not claimed for the current 62-core / 18-adapter tree.
