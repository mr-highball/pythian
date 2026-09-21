# Reusable WAV styles and independent musical dimensions

[Home](../README.md) · [Milestones](MILESTONES.md) · [Context profiles](CONTEXT-PROFILES.md) ·
[Independent voices](INDEPENDENT-VOICES.md) · [Work](WORK.md)

The native workflow now learns a reusable onset-presence model from a recording,
saves it together with selected key/tempo context, combines rhythm evidence from
other recordings with explicit weights, and reuses the saved derived style in
another blend and audible generation. Actual WFC passes coordinate the result.

Use the shared [provider descriptions](GRID-STYLE.md#provider-descriptions) or
`pythian.style providers` to inspect supported choices, dependencies and timing
before selecting locks/preferences.

Pitch can be selected or weighted independently from the rhythm/intensity
provider, retaining both sets of measurements and complete derivation ancestry.
Optional stationary harmonic timbre now has a third independent source-weight
vector and feeds native synthesis after the musical passes have solved.
Measured amplitude envelopes add a fourth independent vector beneath those passes.

The onset model learns **when admitted onsets occur on an admitted musical grid**.
Optional [measured onset dynamics](ONSET-DYNAMICS.md) adds joint timing/intensity
history, versioned RMS evidence and intensity-only edits preserving onset state.
It does not isolate instruments, transcribe notes or learn complete voice roles.
The voice operator supplies authored pitches, voicings and one-cell gates under
the generated onset pattern. It reports that division explicitly.

The optional [pitch capability](PITCH.md#saved-pitch-styles-and-layer-control)
adds measured absolute melody from declared monophonic sources to this same saved
blend workflow. It retains source pitch measurements and a separate WFC pitch
history, with a named pitch control; accompaniment and gate lengths remain authored.

## Saved generation preferences

The current `TWaveStyleProfile` implements `CreatePreferred(Parent, Preferences)`,
`CopyGenerationPreferences` and `HasGenerationPreferences`. A preferred derivation
owns a detached complete replacement of the seven provider lists: key, tempo,
performance (joint pitch/duration), rhythm, intensity, pitch and pitch/rhythm.
It retains parent identity, source evidence, training weights and learned counts.
This extends the current style contract; it adds no historical format reader.

Each list accepts unique known tokens with integer multipliers 1..1024, up to
1024 entries, subject to the existing model and ancestry limits. The actual solve
also applies the [runtime weight/work bounds](LAYERS.md#generation-preferences).
Missing capabilities, unknown tokens and invalid multipliers reject. Copy the
settings, edit the desired list and derive a new profile; an empty list clears
that provider. Preferences influence choices, not exact output proportions.

Blends inherit key/tempo settings from their selected parents. Rhythm/intensity
settings follow active rhythm contributors, performance/pitch follow active pitch
contributors, and joint pitch/rhythm follows parents active in both. Ordered
unions retain one copy of equal settings; conflicting multipliers reject until
the caller clears or aligns them. Multipliers are not training-source weights.

The native style operator exposes `prefer INPUT.pys PROVIDER TOKEN MULTIPLIER
OUTPUT.pys` and `clear-preferences INPUT.pys PROVIDER OUTPUT.pys`; `inspect`
reports `generation_preferences`. CLI provider names are `key`, `tempo`,
`performance`, `rhythm`, `intensity`, `pitch` and `pitch-rhythm`.

The duration API/operator consume key, tempo and performance settings and reject
grid-model settings. The grid voice operator wires the other providers and rejects
performance settings; joint pitch/rhythm requires coupled mode. Persisting a valid
preference does not prove that every requested generation scope can solve.

Retained checks under ignored `build/style-preferences/` pass saved ownership,
canonical reload, unchanged counts, selected parents and further blends on checked
stable Win32/Win64 and development Win32, with zero reported fixture leaks. A
stable Win64 duration render changes with the preference, replays exactly and
returns to baseline WAV bytes when cleared. The later grid checkpoint below closes
the earlier grid-consumer evidence gap. General role controls and recorded
semantic acceptance remain under [layers](MILESTONES.md#wfc-layers) and
[integration](MILESTONES.md#wav-04-integration).

### Grid preference consumer checkpoint — 2026-09-20

The earlier coupled-grid request fails identically without preferences. Its
`phase-source-duration` profile cannot supply the requested 64-cell joint path;
the consumer now reports the unsatisfiable `pitch-rhythm` provider and the native
path-analysis issue after generation fails. It does not infer generatable length
from longest observed runs, relax the model or manufacture a path. Other bounded
negotiation failures retain their existing handling.

The operator now returns failure after leaving its exception handler, releasing
the exception object before process exit. The rejected request exits 1, publishes
no WAV and reports zero leaks on checked stable Win32/Win64 and development Win32.
The prior three-block exception allocation is resolved. Each generated context
pass also records its exact ordered `generation_preferences` beside its unchanged
model, tokens and states in the current JSON report.

A regenerated current-format native monophonic WAV fixture provides a satisfiable
coupled path. Saved settings favor joint MIDI 60/no-onset by 16, MIDI 60 by 8,
and empty onset/intensity tokens by 4. They survive a blend and a further blend
with the same source; active dimensions remain independently represented. Stable
Win64 generates 64 cells / 705600 stereo frames / 120 notes. Preference audio
differs from baseline and replays exactly, including JSON. Every provider's model
text is unchanged, and independent key/tempo tokens and latent states remain exact.

An additional hard pitch lock at cell 0 to MIDI 62 overrides the soft preference.
Actual coupled regeneration preserves key/tempo and the observed pitch/onset/
intensity relationships; native PCM and MIDI round-trip verification pass. The
existing output fixture now checks that each saved setting reaches the correct
provider, alongside actual model paths, realized notes, dynamics and artifact
hashes. Its `preference-controls BEFORE.wav AFTER.wav` mode checks unchanged
training models, preserved base context and changed audio. These output/isolation
checks pass on all three targets against the Win64 renders; cross-target rendering
is not newly claimed. Existing dependency/RTL warnings remain, with none from the
changed owned files.

Evidence is ignored under `build/grid-preference-consumer/`; style identity after
reblend is `77151c6b57c5597221b4897d6db147807767956baeca4e8b828a6e2c573c220c`.
WAV SHA256: baseline `43ff098437fd9bb00b32dea6799abe49d538c71c909618e03f543bef878a4a6b`,
preferred/replay `f3f32e96c9f25978cdcd5e1cf1945b3f69a13e99279fcbec49255b43dde0cbf8`,
hard-locked `c55f33651e7131fbf345804d73095a7905261ec0720d253357af77cc8b3e40f9`.
The existing 64-cell demo scope is preserved. No listening verdict, genre-quality
admission, new historical-format reader or refreshed package is claimed.

## Saved measured envelopes

`TRhythmStyleEvidence.Envelope` retains selected source coordinates/channel,
rectangular RMS window width, raw RMS points, a declared gate, minimum RMS,
maximum final-window/gate RMS ratio and descriptive policy. Zero FrameCount means
unavailable. The source shares its WAV identity with the other dimensions.
`learn-envelope` hashes the actual recording and verifies its geometry before
measurement; source creation and decoding use the core `TEnvelopeTrace`
geometry/admission checks. Loading does not reopen the WAV or independently prove
that the claimed measurements are accurate. See [measurement limits](MODULATION.md#measured-amplitude-envelopes).

`CreateBlendLayers` now accepts two optional final coefficients,
`LeftEnvelopeWeight, RightEnvelopeWeight`. Explicit 0..64 values select or mix
envelope evidence independently of rhythm, pitch and timbre; both zero omit it.
Omitting both parameters follows rhythm weights when any selected parent has
envelope evidence, otherwise omits the dimension. Both default sentinels are -1;
one default and one explicit value rejects. Every positive parent weight requires
admitted envelope evidence. Source coalescing, GCD normalization, source/depth/node
bounds and conflicting-evidence rejection apply to this fourth vector too.

`HasEnvelope`, `EnvelopeWeightAt` and `CopyGateEnvelope(OutputRate)` expose the
dimension. CopyGateEnvelope retimes each source into output-frame coordinates,
then averages peak-normalized held levels and gate-relative release shapes
independently at the exact union of linear knots. Held endpoints remain held;
each release is zero after its own endpoint. The result ends at the longest
active release. There is no duration stretching or cancellation from recording
phase. Multiplying these two blended components is deliberately different from
averaging already-rendered notes: held shape and release response are separate
controls. Source amplitude remains in raw RMS evidence; envelope normalization
does not change independently selected stationary-timbre amplitudes.

The core `TGateEnvelope.Blend` supports 1..32 sources with integer weights 0..64,
positive releases and linear point curves. At most 4096 knots per component are
admitted; an oversized union or collapsed retiming rejects before audio output.
Returned envelopes own their curves and outlive the profile. Callers can assign
different profiles' envelopes to individual native voices; the fixture verifies
that changing one binding preserves an independent voice after profiles are freed.

```text
pythian.style learn-envelope SOURCE_STYLE.pys SOURCE.wav START COUNT GATE CHANNEL WINDOW MAX_TAIL_RATIO OUTPUT.pys
pythian.style blend-layers LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH LEFT_TIMBRE RIGHT_TIMBRE LEFT_ENVELOPE RIGHT_ENVELOPE OUTPUT.pys
```

Measurement augments a source leaf before blending, preserving context and all
other evidence. Inspect prints raw RMS points, source weights and policy. The
voice operator uses the saved envelope for all three authored voice roles, with
independent timbre, gain, filter and pan. That shared assignment is an operator
policy, not inferred source-voice ownership. Duration-mode articulation still
suppresses tails in measured unknown/silent spans, so its final extent follows
the musical plan rather than the longest instrument tail.

The current PYST source capability and blend coefficients include envelopes.
Superseded development blends must be regenerated. No envelope archive, historical
reader, migration chain or additional WFC solver was added. Broader instrument
binding, voice-role learning and time-varying timbre remain milestone work.

## Stationary timbre and rendering

`TRhythmStyleEvidence.Timbre` optionally retains a selected source interval/channel,
the supplied or measured fundamental, fitted signed coefficients/DC, AC and
residual RMS, relative error, admission limits and descriptive measurement policy.
`FrameCount = 0` means unavailable. Source creation checks the common
`HarmonicFitWork` geometry, source extent, finite coefficients, maximum harmonic
magnitude 16 and the declared AC/error admission. The RMS ratio must be consistent.
Source WAV identity is shared with the source's other measurements. The operator
hashes the actual WAV and checks its geometry before attaching a measured fit.

The profile retains measured evidence, not source PCM. Loading validates bounded
geometry, diagnostics, canonical bytes and hashes; it does not remeasure WAVs or
prove instrument identity. The stationary fit and its limits are documented in
[harmonic fitting](SOURCES.md#harmonic-fitting-across-a-wav-interval).

`CreateBlendLayers(Left, Right, KeySide, TempoSide, LeftRhythm, RightRhythm,
LeftPitch, RightPitch, LeftTimbre, RightTimbre)` adds explicit independent timbre
coefficients in 0..64. Both zero omit timbre. A positive coefficient requires
admitted timbre on that parent. Existing convenience blends follow their rhythm
coefficients when any selected parent has timbre; use this explicit constructor
when availability differs or timbre should come from another source.

Each vector is independently coalesced and reduced by its greatest common divisor.
`SourceCount` is the union of active rhythm, pitch, timbre and envelope sources; a recording
can contribute only timbre. Conflicting measurement metadata for the same WAV
still rejects. Repeated blends retain complete parents, source weights and the
existing depth/node/source limits. The current archive stores the additional
capability and blend coefficients. Superseded development blend archives must
be regenerated; no historical reader or separate timbre file format was added.

`HasTimbre`, `TimbreWeightAt` and `CopyTimbreRecipe` expose the result. For each
harmonic, the recipe takes the weighted mean of each source's magnitude
`sqrt(sine*sine + cosine*cosine)`. Unmeasured higher harmonics contribute zero.
All result phases use positive sine, and DC is zero. This avoids cancellation
between unrelated recording phases. It deliberately transfers harmonic shape
and amplitude, not original phase, loudness normalization, a note envelope or
time-varying timbre. Returned recipe/evidence arrays are detached; source and
morph factories remain independent native consumers.

```text
pythian.style learn-timbre SOURCE_STYLE.pys SOURCE.wav START COUNT CHANNEL HARMONICS HZ|auto[:PITCH_FRAMES] MAX_ERROR OUTPUT.pys
pythian.style blend-layers LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH LEFT_TIMBRE RIGHT_TIMBRE OUTPUT.pys
```

`learn-timbre` augments a single source profile before blending. It retains that
profile's context, rhythm/pitch evidence and model order. `auto` uses the default
periodic estimator; `auto:N` gives it an independent width at the same start and
channel. The policy records that width and normalized difference. The separate
fit interval and error limit remain explicit. `inspect` reports availability,
weights, measurement settings and all fitted coefficients.

The voice operator consumes active saved timbre automatically. Its final stereo
render applies the same saved recipe to all three synthesis voices, retaining
their authored envelopes, filters, gains and pans. WFC key/tempo/performance and
dependent voice models, state paths and MIDI remain independent. The reference
preview keeps its original WFC oscillators; metadata distinguishes that preview
from the measured-timbre stereo render. This static synthesis dimension does not
claim a learned sequence of timbre states or inferred bass/chord/melody timbres.

## Saved spectral trajectories

The current PYST contract also retains a source-bound `TimbreTrajectory`: a
caller-declared note origin and 2..32 complete harmonic fits. Each knot retains
its WAV interval, channel, fixed frequency, admission thresholds, raw sine/cosine
coefficients, DC, measured AC RMS and residual. A source has either stationary
timbre or a trajectory. No historical reader or additional format is introduced.

```text
pythian.style learn-trajectory SOURCE_STYLE.pys SOURCE.wav ORIGIN START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_ERROR OUTPUT.pys
```

The command augments a single-source profile, verifies WAV identity and requires
every window to pass the declared fixed-pitch fit admission. Origin must be at or
before the first window. Channels and frequency must agree across knots; centers
must increase, and cumulative harmonic-fit work is bounded at 134217728. It does
not infer events, changing pitch or a new dynamics envelope. Existing independent
envelope evidence remains available. Failed admission preserves existing output.

`HasTimbreTrajectory` reports active trajectory contributions.
`CopyTimbreFactory(OutputRate, TrajectoryRms = 0.1)` returns an owned detached
factory. Static-only styles retain their existing magnitude/amplitude behavior.
When any selected source evolves, all selected sources, including stationary
parents, contribute unit-RMS harmonic magnitude shapes; raw phase/DC and level
remain evidence, rather than rendering controls. The explicit target RMS applies
to the complete periodic model, with pitch-cap attenuation preserved. It is not
perceptual loudness normalization or a finite-window RMS guarantee.

For each source, window centers relative to its declared origin map to output
frames by flooring their exact half-frame coordinates. Collapsed source knots
reject. The factory takes the union of these times, capped at 32 without silent
decimation. At each union knot it interpolates and normalizes each source's shape,
then combines the shapes using existing timbre weights. Between union knots the
result uses normalized linear magnitude interpolation and endpoint holds. This
declared union-knot policy is not an exact continuous average of independently
normalized parent curves. Further blends recompute from raw source evidence and
accumulated weights. `CopyTimbreRecipe` rejects evolving styles instead of
flattening them. Envelopes remain independently selected by the instrument.

### Saved trajectory checkpoint — 2026-09-19

Checked stable Win32/Win64 and development Win32 pass saved round-trip, detached
ownership, independent weighting and further-blend fixtures. An independent
two-source reference verifies differing knot times and union interpolation;
32-knot admission, a 34-knot union rejection, collapsed timing and changed
frequency cover the relevant limits. Actual WFC generation also passes.

The existing attributed bassoon C WAV supplies three 272-frame windows starting
at 907, 1179 and 1451, origin 0, channel 0, 24 harmonics and 130.8 Hz. Relative
errors are approximately 0.0580 / 0.1158 / 0.1863 against the declared 0.25 limit.
A saved blend and further blend combine this trajectory with the previously
admitted stationary A spectrum, retaining separate envelope selection. An
88-note, 729281-frame stereo performance reaches 12 voices / 795 frame-work units.
127/2048-frame replay is exact. Paired melody timbre and envelope edits each
change that stem and the mix while preserving bass/chord stems, the other binding
and complete MIDI. This verifies control isolation, not inferred role ownership.

The A three-window trajectory remains **unadmitted**: its third residual is
0.253358 at the independently measured 219.80006634936694 Hz, above 0.25. The
earlier nominal 220-Hz attempt also failed (0.250989). The failed command preserves
an existing archive; no window is dropped or threshold relaxed. The mixed-source
audition uses A's admitted stationary evidence, not a successful A trajectory.

Relearned Win32 and Win64 archives differ in raw floating-point fit evidence and
therefore identity. Both decode canonically on the other target; same-target
round-trip is exact. The baseline, both edits and WFC-generated WAV bytes match
across all three targets. The baseline SHA256 is
`cba63b4fd6678d7406994e83efe16e8acf7e819726bb8cce0746fad2b7555ab6`.
Evidence and auditions are ignored under `build/saved-trajectory-{win64,stable,trunk}/`.
The focused build compiles `pythian.tests.wave.style`, `pythian.style`,
`pythian.instrument.style` and `pythian.voices.demo` with
`-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools -Fuadapters/wfc -Fuvendor/wfc/src`, using
separate unit/executable directories per target. The maintained build already
runs the extended style fixture. Its new archive is `PREFIX-trajectory.pys`.
The paired consumer checks are:

```text
pythian.tests.wave.style instrument-replay measured.wav replay.wav
pythian.tests.wave.style instrument-controls measured.wav envelope-edit.wav
pythian.tests.wave.style instrument-timbre-controls measured.wav timbre-edit.wav
pythian.voices.demo generated.wav --style reblend.pys --duration-spans 3 --verify
```

No cross-target relearning identity, changing-pitch admission, listening approval
or general style-quality result is claimed. Remaining work and downstream gates
are linked in [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre).

The subsequent [centered pitch study](PITCH.md#centered-timbre-measurement-checkpoint--2026-09-19)
improves spectral fitting on controlled glides/vibrato by aligning measurement
support. It also retains octave ambiguity and the failed third A window. This
measurement primitive does not change the fixed-frequency saved learner or admit
automatic variable-pitch trajectories; register/event policy remains prerequisite.

## Native rhythm admission

[pythian.rhythm.admission](../src/pythian.rhythm.admission.pas) maps strictly
ordered, previously selected source onset frames onto a validated finite source
grid. `TMusicGridFrames` in `pythian.music.grid.frames` maps the complete tempo
history, source frame offset and PPQ scope to immutable frame boundaries. Rhythm
and pitch-cell measurement use this same geometry, including changing tempo.
The constant-clock overload delegates to that implementation after calculating
its complete-source scope. No origin is a verified downbeat; incomplete and
sub-frame grids reject.

The nearest floor-frame grid boundary wins; equal distances choose the earlier
boundary. An onset outside the complete-cell scope, beyond the caller's maximum
error, or colliding with an already accepted cell retains its explicit decision.
All input coordinates, selected cells and signed frame errors remain available.
The output pattern uses `x` for an admitted onset and `.` for no admitted onset.
An empty cell does not establish silence, a held note or an isolated voice rest.
Bad input preserves a previously assigned result.

## Saved profile and weights

[pythian.wfc.style](../adapters/wfc/pythian.wfc.style.pas) owns context, rhythm
evidence, admissions, relative source weights and an actual order-1..4 WFC model.
A source profile records WAV identity/geometry/attribution, onset-report hash,
analysis window/hop/silence threshold, onset version, selected source frames,
initial tempo/start tick, frame offset, finite cell count, explicit tempo changes,
quantization tolerance and admission policy. Its source clock must match one
tempo provider's WAV hash, physical origin, scope and every complete cell's tempo.
Changes inside a context cell reject; callers must refine the grid explicitly.
Key context may have been explicitly selected from another provider; that context
archive retains its own complete lineage.

`CreateStyleSourceClock` and `CreateStyleSourceGrid` return owned clock/geometry
objects. Empty `SourceClock` with zero `SourceCellCount` is the native convenience
form for a complete constant-clock source; otherwise the caller supplies the
finite count and full tempo history. `SourceFrameOffset` identifies the physical
source frame at clock tick zero. Source clock arrays are copied when evidence
is returned or blended. The operator builds its clock from admitted cell tempos;
for a nonzero start tick it uses the initial tempo before that tick. Native
callers with different earlier history must provide it explicitly.

`CreateBlend(Left, Right, KeySide, TempoSide, LeftWeight, RightWeight)` selects
context dimensions from side 0 or 1 and applies common source coefficients to
rhythm and available pitch. If positive-weight parents disagree on active pitch,
use explicit dimension selection instead of silently filling missing evidence.

`CreateBlendDimensions(Left, Right, KeySide, TempoSide, LeftRhythm, RightRhythm,
LeftPitch, RightPitch)` supplies independent coefficients. Rhythm and observed
joint intensity remain together; pitch can come from different sources.
Coefficients are integers 0..64, with at least one positive rhythm coefficient.
Both pitch coefficients zero explicitly omit pitch. A positive pitch coefficient
requires that parent to have an active pitch model. Intensity availability must
agree among positive rhythm contributors only.

Repeated compatible source evidence is coalesced, its weights added within each
dimension, then each vector is reduced by its own greatest common divisor.
A repeated WAV with conflicting
measurement/admission metadata rejects instead of silently treating it as more
evidence. A source with zero weight in all three dimensions remains only in parent
ancestry. A source with zero weight in one dimension does not train that model.
`RhythmWeightAt` and `PitchWeightAt` expose the distinct effective weights;
`SourceCount` covers the union of active dimension sources.

Each normalized source weight repeats that source's entire pattern as an
independent actual WFC training sample. Recordings are never concatenated.
Thus 1:1 means equal repetition coefficients, not equal total influence when
source lengths differ. It is not a soft output quota or a guarantee that one
short generated phrase has the weighted mean density. The separate key/tempo
models are selected, not weighted or joined with inferred joint observations.

Profiles require equal PPQ, step and rhythm model order before blending. Limits
are 32 active sources, normalized weights 0..64, 65536 weighted observation cells
per dimension,
32 MiB archives, depth 8 and 63 parent appearances. Complete ordered parents are
embedded, including repeated appearances; a derived profile can be used again.
`CopyContext`, `CopyRhythmModel`, `EvidenceAt`, `AdmissionAt` and `Encode` return
detached owned values. Original parents may be released after construction.

The current binary `PYST` archive has a source or blend node under one format
identifier. Source nodes embed the context archive, a capability mask, complete
rhythm evidence and optional intensity, cell-pitch, dense-duration, stationary-timbre,
envelope and spectral-trajectory measurements. Blend nodes embed both parents, context-side selections
and separate rhythm/pitch/timbre/envelope coefficients. Every node stores
canonical onset, optional intensity, optional pitch, optional paired
pitch/rhythm and optional duration model fields plus a SHA256
payload trailer. Absent capabilities have empty model fields. Decoding checks bounded ancestry and
digests, replays native quantization and bounded weighted WFC learning, and
requires exact model/canonical archive agreement. It does not repeat FFT or onset
detection. Saved reports/WAVs remain external; their hashes are identities, not
authenticity or measurement-accuracy proofs. Descriptive policies are not executed.

This is a fresh-library development format. The current source payload includes
frame offset, finite cell count and tempo changes. Regenerate superseded
development artifacts from source evidence; only the current reader is retained.
Subsets such as onset-only or
pitch-without-intensity are capabilities of the current format, not separate
versions. See the [development format policy](../PROJECT.md#development-format-policy).

`HasPitchRhythm` identifies observed same-cell pitch/onset/intensity history when
the normalized rhythm and pitch source vectors agree. `CopyPitchRhythmModel`
returns its detached actual WFC model. Unknown pitch gaps split samples; different
source vectors leave this capability unavailable. The explicit `--coupled-pitch`
voice mode projects this provider into the separate consumer passes and edits
their dependency closure. See [pitch controls](PITCH.md#saved-pitch-styles-and-layer-control).

`HasDuration` requires dense evidence for every positive pitch contributor.
The existing pitch weights govern the joint pitch/kind/duration model. Each
source's measured intervals are intersected with its admitted scope and mapped
through its full clock to PPQ tick durations before learning. Different source
tempos, offsets, sample rates and measurement hops can therefore share the
profile's explicit PPQ timebase. `CopyDurationModel`, `CopyDurationTrack`,
`CopyTimedDurationSpans` and `DurationTicksPerQuarter` expose the model, raw
evidence and normalized timing. Other style
capabilities remain available if duration coverage is incomplete. The
[saved duration operator](PITCH.md#saved-duration-styles) generates through named
key/tempo/performance passes and supports selective duration edits plus independent
tempo selection. Earlier development PYST files need regeneration after this
optional model/evidence extension; the project retains one current format.

`DurationArticulateOnsets` explicitly assigns admitted source onsets to known
monophonic pitch spans before duration learning. It is an optional source
capability in this same format; raw windows and source coordinates are retained.
Independent rhythm-grid quantization does not replace the onset's physical
timing. The policy and resulting joint duration model survive weighted repeated
blending. [Onset-assisted duration](PITCH.md#explicit-onset-assisted-duration)
describes scope, uncertainty, failure behavior and the controlled listening pair.

## Operator workflow

```text
pythian.style learn CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys [PROVENANCE]
pythian.style blend LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_WEIGHT RIGHT_WEIGHT OUTPUT.pys
pythian.style blend-dimensions LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH OUTPUT.pys
pythian.style inspect INPUT.pys OUTPUT.json
pythian.voices.demo OUTPUT.wav [SEED [SEGMENT_CELLS]] --style INPUT.pys [--rhythm-locks PATTERN] [--verify]
```

Learning uses an existing [admitted source context](WAVE-CONTEXT-ADMISSION.md)
and [source onset report](ONSETS.md). It verifies the actual WAV hash against
context and report, applies default native onset-event selection, then the
explicit grid-error tolerance. The report hash is computed from the exact bytes
parsed. Inspection exposes all source weights, patterns and per-onset decisions.

For example, `blend-dimensions RHYTHM.pys NOTES.pys 0 0 1 0 0 1 SELECTED.pys`
takes context and rhythm/intensity from the left parent and pitch from the right.
Then `blend-dimensions SELECTED.pys MORE-NOTES.pys 0 0 1 0 1 2 RESULT.pys`
preserves the selected rhythm while combining pitch histories with coefficients
1:2. These are weighted training samples, not per-note source quotas. The saved
result retains both complete parents and can itself become another blend input.

The independent-dimension workflow passes on both checked compilers with a
controlled rhythm source and with Pixel Sprinter's measured onset/intensity
evidence. High, low and reblended pitch variants preserve the exact key/tempo/
onset/intensity provider states and change audible melody. The recorded variants
each contain 58 attacks / 290 notes; both pitch-source WAVs have independently
checked note references. Thirty-eight current artifacts match across compilers.
Evidence and listening files are in `build/style-dimensions-recorded-{stable,trunk}/`
and `build/style-dimensions-verified-{stable,trunk}/`; comparison log:
`build/style-dimensions-replay.log`.

The operator supplies authored per-voice bass/chord pitch-class constraints so
the measured melody can satisfy exact harmony coverage within the existing
planning budget. Compatible voicings remain available. This is an explicit
accompaniment policy, not learned accompaniment or inferred pitch/onset coupling.
Individual writes are non-atomic; input paths are protected and validation occurs
before writing output.

The voice consumer requires PPQ 480 / step 240, a known constant major or natural-
minor key and 64 output cells. It copies the three saved key/tempo/rhythm models,
releases the profile and generates through three actual WFC passes. Rhythm locks
are exactly 64 characters: `x` requires an onset, `.` requires an empty cell and
`?` leaves it free. Contradictions and search budgets reject explicitly. A named
layer session first accepts the unpinned key/tempo/onset result, then applies the
mask through actual WFC selective onset regeneration. Key and tempo retain their
accepted latent states. Pinned reports include the actual active/root indices and
baseline onset pattern.

The consumer then rebuilds the existing five-pass harmony/rhythm/bass/chord/melody
stack under the generated pattern. Each `x` triggers the authored bass, full
triad and melody for one cell; each `.` becomes an arranged rest. These gates and
shared voice attacks are realization policy, not inferred source note durations
or measured polyphonic relationships. The full planned score is streamed with
actual voice/path validation, native synthesis and MIDI export. Context and
rhythm use the same PPQ cell resolution; no analysis-hop-to-beat shortcut occurs.

This is hierarchical generation followed by rebuilding affected voices. It does
not provide a general semantic dependency cache or reverse negotiation from a
voice failure into context. Existing no-style voice commands retain their output.

## Local source clocks through voice generation

The maintained workflow selects a known key independently of the tracked
120-to-100 BPM source clock, admits its measured rhythm/intensity, blends it with
the independently aligned C-major phrase and reuses that result in a second
blend. Each source retains its own frame offset, start tick, finite scope and
tempo map. The saved result drives 32 attacks / 160 notes in 776097 stereo frames.
The native output check explicitly requires changing generated tempo, in addition
to the existing source/model binding, voice, audio and MIDI checks.

The cached Pixel Sprinter source contributes 128 admitted onsets on its 158-cell
tracked grid. A recorded/controlled weighted second blend, selecting the
controlled changing tempo and an independently declared C-major key, produces
47 attacks / 235 notes in the same 776097-frame clock. Stable Win32 renders and
verifies the result; development Win32 cross-loads it and passes the native
changing-clock output checks. This is learned onset/intensity behavior with
authored voice pitches and roles, not polyphonic transcription or annotated beat
accuracy. Its source attribution is unchanged.

The [changing-clock pitch fixture](PITCH.md#cells-on-a-changing-source-clock)
separately verifies known note content, silence and source-clock binding. Its
independent fragment output is valid but does not preserve the whole source
tempo trajectory. Dense duration normalization is now supported as described below;
whole-scope centered-pitch generation from these short gapped sources remains open.

Evidence: `build/local-style-trunk/workflow.log`,
`build/local-style-stable/recorded-workflow.log`,
`build/local-style-trunk/recorded-replay.log` and
`build/local-grid-{stable,trunk}-win64/checks.log`. The source-grid unit remains
in the standalone core; WFC models and style persistence remain in the adapter.

## Measured phrase performance and tempo control

The maintained build combines selected beat context with the existing dense
pitch/duration learner. Its `phase-source` and `phase-shifted` fixtures contain
the same native C-major phrase, with a 1000-frame leading shift in the latter.
Both sources retain their independently admitted origin and 120-BPM context.
`learn-duration` retains whole-source hop measurements. The operator accepts
`--window-frames N` to select dense analysis width independently of hop,
source clock and onset articulation. The actual width survives the existing
duration evidence field and mixed-window second blends. The two duration-only
options may appear in either order before optional final provenance. Centered
pitch cells retain their separate geometry. See the [recorded width comparison](PITCH.md#explicit-analysis-width-on-the-recorded-sources)
for the accuracy/resolution tradeoff and remaining channel ambiguity.
The learned duration model uses the intersection with the selected source scope,
normalized to PPQ ticks.

The build learns both duration styles, blends them 2:1, then blends that result
again with the shifted source. `pythian.voices.demo --duration-spans 32 --verify`
loads the saved result and runs actual key, tempo and performance providers,
followed by five dependent voice passes. The result contains 50 notes in
214803 stereo frames. Measured melody pitch and performance spans drive the
passage; bass/chord pitches and voice roles remain authored. This preceding
checkpoint used authored timbre; the optional stationary dimension above now
supports measured harmonic shape while retaining authored envelopes and mixing.

For an independent clock control, `admit-beats` explicitly selects rank one
from the original recording, the 240-BPM metrical alternative. A further blend
selects this source's tempo while assigning its rhythm/pitch weights zero and
retaining the preceding key and performance. The same 32 spans and 50 notes
then occupy 107401 frames. Native comparisons require identical key and
performance provider output and logical voice frames, the selected clock ratio,
and changed WAV/MIDI bytes. Each rendering separately passes exact MIDI gate,
preview/stereo and audible/unknown/silence checks. Selecting the alternative
is an operator decision, not a claim that 240 BPM is the recording's true beat.

The exact maintained block passes checked FPC 3.2.2 and 3.3.1 on Win32; sixteen
profile/style/audio/MIDI/report files match. Current evidence and listening files
are in `build/phrase-performance-{current,trunk}/`, especially
`phase-duration-reblend.wav`, `phase-duration-fast.wav` and `workflow.log`.
This extends the existing integrated style milestone without introducing a new
format or solver. Centered pitch-cell summaries expose uncertain gaps; choosing
the duration path does not relabel those gaps as measured rests or make an
unsupported long fixed-cell request succeed.

## Recorded evidence

See also the controlled [measured phrase performance](#measured-phrase-performance-and-tempo-control)
workflow, which connects selected pulse context to dense duration learning.

The attributable [Pixel Sprinter and Opening Theme recordings](WAV-LEARNING.md#published-recording-evidence)
use existing fine onset reports. Pixel uses its source-declared 140 BPM rounded
to 428571 microseconds/quarter. Opening uses a **caller-declared 500000-microsecond
analysis clock**, not an estimated tempo. Both use a 2205-frame (50 ms) maximum
grid error. Pixel contributes 144 accepted grid onsets over 160 cells from 348
selected source onsets; Opening contributes 240 / 360 from 901 selected onsets.
All other quantization decisions remain inspectable.

For controlled audible comparison, all outputs select the same native C-major
key provider and Pixel tempo provider. Pixel's original unknown key is not
reclassified as C major; the key is an explicit independent selection. Opening's
rhythm-only selection retains that same context with zero Pixel rhythm weight.

| Output, seed 731 | Rhythm repetition weights: Pixel / Opening | Generated attacks | Native notes |
| --- | --- | --- | --- |
| Pixel behavior | 1 / 0 | 58 | 290 |
| Opening behavior, same context | 0 / 1 | 38 | 190 |
| Saved first blend | 1 / 1 | 47 | 235 |
| Saved blend combined again with Pixel | 2 / 1 | 46 | 230 |
| Second blend with cell 8 pinned empty | 2 / 1 | 47 | 235 |

The second blend's weighted training contains 160 + 160 + 360 cells in three
separate samples. Its archive has two active sources, depth 4 and seven parent
appearances. The changed short generated densities are not monotonic weight
estimates; they are individual constrained stochastic outputs.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs reproduce 29 style/report/audio files
byte-for-byte. Native output checks bind the saved model and profile, verify
each attack/rest against all three realized voices and every WAV/MIDI hash, and
prove unchanged key/tempo models, tokens and latent states across the controlled
variants. Actual companion preview PCM/MIDI parity and native MIDI round-trip
pass. All previews span 604799 frames at 44100 Hz. Stereo release tails depend on
the final attacks: 604799 or 610091 frames.

Native fixtures separately compare weighted model counts against three manually
specified independent samples, test quantization ties/errors/collisions, detached
ownership, second derivation after releasing parents, malformed valid-digest
blends and ancestry bounds. A contradictory rhythm pin preserves all four prior
output files. Eight default/context-only voice artifacts retain their earlier
bytes. A controlled native WAV also passes fresh onset measurement, learning,
saved generation and output checking.

Logs and listening outputs: `build/wave-style-{stable,trunk}/`; replay ledger:
`build/wave-style-replay.log`. The maintained build includes the native fixture
and controlled WAV workflow. This is focused evidence for 61 core / 18 adapter
units; full-suite, package refresh, new targets and listening approval are not
claimed.

This establishes a reusable, weighted onset-style workflow through audible
generation and further derivation. Broader style coverage remains open: admitted
gap/run scopes beyond whole-recording onset patterns, measured voice roles and
articulation, joint acoustic/voice behavior, automatic tempo/key admission,
modulation and general per-layer editing. Keep those gaps visible when assessing
the larger milestone or overall goal.

## Selective edit evidence

The subsequent named-session checkpoint consumes the same saved second blend.
Its unpinned 46-attack phrase is accepted first; pinning zero-based cell 8 empty
then produces 47 attacks through actual WFC selective regeneration. The actual
active scope is `[2]` (onsets). Key/tempo models, tokens, latent states and the
output tempo map remain identical; the dependent authored voice stack is rebuilt.
The native output checker verifies the pin, saved model, realized voice actions,
actual WAV/MIDI hashes and that the edit started from the compared baseline.

Both checked compiler versions pass baseline/edited rendering with companion
preview/MIDI parity and native MIDI round-trip. This advances the control mechanism;
it does not add learned pitches, voice roles or general voice-stack regeneration.
Logs and listening outputs: `build/layer-session-{stable,trunk}/`.
Eight output files match across compilers; twelve unpinned/default/context output
files retain preceding bytes. A contradictory selective edit preserves all four
prior outputs. Comparisons: `build/layer-session-replay.log`.

## Dense duration normalization on source clocks

Saved duration styles now use PPQ ticks as their common model unit. Raw dense
measurements retain their physical frame boundaries and original hop settings;
`TPitchTrack.TimedSpans` performs the separate musical admission. It intersects
each pitch/silence/unknown interval with the explicit source range and maps its
endpoints through the full tempo history and physical source offset. Boundaries
use the first tick whose floor frame reaches the measured frame. Endpoints are
rounded cumulatively, so adjacent spans stay contiguous across tempo changes.
Unmeasured edges are excluded. Intervals that collapse below PPQ resolution
reject; no merging of unknowns or invented silence repairs them.

The native normalized learner repeats each source independently according to
its weight. The standalone raw-track learner remains useful for physical-time
models without an admitted musical clock; its units are measurement hops and
its callers must still supply a shared hop timebase. These are two input
adapters, not historical style formats. Current PYS files retain source evidence
and validate their saved normalized model by replay. Superseded development
duration profiles must be regenerated; no compatibility reader was added.

The maintained `local-duration` workflow learns the changing harmonic source
(offset 97, 500000→600000 microseconds per quarter), blends it with the constant
phrase, saves a second blend, and generates 32 performance spans through the
three providers and five voice passes. A separately selected tempo provider
changes playback timing while preserving performance and voice states. The
voice operator supports an [independent finite tempo scope](INDEPENDENT-VOICES.md#independent-tempo-scope-for-measured-performance)
and tempo changes inside sounding spans. Its [independent key scope](INDEPENDENT-VOICES.md#independent-key-scope-for-measured-performance)
maps new authored accompaniment attacks while preserving sounding pitches and
absolute measured melody. The modulation fixture uses caller-authored key
evidence, explicitly separate from the retained source measurements.
Duration locks in saved-style operators are now `CELL:TICKS`. Inspection reports
both original frame spans and admitted tick spans.

Core checks independently calculate rational boundaries across a tempo change,
nonzero source offset and clipped scope, including collapse rejection and source
preservation. The changing-source style check also verifies every persisted dense
interval against independent piecewise arithmetic.
The complete checked FPC 3.2.2 Win32 build passes in
`build/duration-clock/full-stable.log`. The maintained 32-span second blend
produces 45 notes / 198450 frames; independent faster tempo selection produces
99225 frames with identical performance and voice states. Eight focused
style/audio/MIDI/report artifacts match development Win32 exactly
(`build/duration-clock-trunk/replay.log`). Stable Win64 cross-loads and verifies
the saved generated voices (`build/duration-clock-win64/checks.log`).
The additional 80/160-frame hop check exercises the normalized corpus adapter;
the existing style rule against conflicting measurements for the same source
hash remains in force.

## Independent measured instruments

The companion [instrument adapter](../adapters/wfc/pythian.wfc.instrument.pas)
composes saved sound dimensions with native keyboard/velocity zones.
`TStyleInstrumentZone` contains a core `TInstrumentZone` and independently selected
`Timbre` and `Envelope` profiles. A nil selection preserves the corresponding
authored voice dimension; a non-nil profile without that evidence rejects.
Overlapping zones layer in caller order using the core instrument contract.
Every declared key is validated at construction, including source/filter and
automation limits; this wrapper does not silently narrow the supported range.

`TStyleInstrument.Create(Zones, SampleRate, TrajectoryRms = 0.1)` owns measured wavetable factories,
clones all five automation curves, and copies either the selected measured or
authored gated envelope. Profiles and authored curves/envelopes can be freed
after construction. A caller-supplied source factory without a timbre override
remains borrowed; the abstract factory contract has no clone operation. Keep
that factory and the style instrument alive until their plans and playback end.
Playing wavetable sources borrow the instrument's tables. Frame controls use the
construction rate; `PlanStyleNoteTones` rejects missing or differently rated
bindings and uses the existing explicit table indexed by `TNoteGate.Voice`.
Timbre/envelope identities remain available separately per zone. No additional
archive or historical reader is introduced.

The native [consumer](../tools/pythian.instrument.style.lpr) accepts:

```text
pythian.instrument.style OUTPUT.wav NOTES.mid BASS_TIMBRE.pys BASS_ENVELOPE.pys CHORD_TIMBRE.pys CHORD_ENVELOPE.pys MELODY_TIMBRE.pys MELODY_ENVELOPE.pys [--block-frames 1..2048] [--output-gain 0..1]
```

Use `-` for an authored dimension. MIDI channels 0, 1 and 2 explicitly select
bass, chords and melody across tracks; other channels reject. The library itself
does not assign semantic roles. The consumer fixes output at 44100 Hz, frees all
profiles before planning, preserves the original MIDI bytes, and writes a mixed
WAV plus `.bass.wav`, `.chords.wav`, `.melody.wav`, `.mid` and `.json` suffixes.
The report retains actual input/output hashes, note coordinates, separate style
identities and authored gain/pan/cutoff. Natural release tails may overlap rests;
this audition does not use the voice operator's 44-frame articulation policy.
The consumer now uses [bounded tone streams](SCHEDULING.md#bounded-tone-streams)
and the sequential WAV writer. Complete encoded files are staged before accepted
outputs open; synthesis failures preserve those outputs and remove temporary
files. Publication I/O is not transactional across the output set. Reports also
retain read size, mixing policy, measured peak and peak voice/frame-work counts.

`--output-gain` defaults to 1 and applies the same explicit attenuation to the
mixed output and every stem, after floating-point mixing and before PCM encoding.
It preserves per-role balance, notes and saved profiles. Either option order is
accepted; repeated options reject. The report records `output_gain`, the output
policy and peaks after gain. Any stem or mixed sample above unity rejects before
accepted outputs are replaced; lower the output gain explicitly and retry. There
is no automatic normalization. The core float renderer still preserves headroom,
and the low-level PCM16 codec retains its documented saturation contract.

The [envelope/layer checkpoint](INSTRUMENTS.md#measured-envelope-and-layer-checkpoint--2026-09-19)
includes the reproduced export overload, early and late rejection with all six
outputs preserved, explicit attenuation, and unchanged sustained measured audio.

The maintained [recorded workflow](../tools/recorded-pitch.ps1) accepts a three-span
performance through actual WFC key/tempo/performance and dependent voice passes,
then consumes its MIDI. Bass uses the recorded C timbre/envelope, chords use A,
and melody uses the saved second blend. Editing only the melody envelope to A
changes that stem and the mix while bass/chord WAV bytes, all timbre bindings and
complete MIDI bytes remain identical. Both variants contain five notes and
37370 stereo frames, including natural tails. This demonstrates explicit bindings,
not instrument ownership inferred from a mixed recording.

Evidence is in `build/style-instrument-{stable,trunk,win64}/`: checked profile
fixtures include detached construction, independent key/velocity zones, overlaps,
failure cleanup, rate rejection and exact comparison to a separately assembled
source. Recorded stem controls pass on all three targets; 24 mixed/stem WAV,
MIDI and JSON comparisons are byte-identical. Invalid profiles, path collisions
and excessive workloads preserve accepted outputs. The full maintained
recorded workflow passes stable Win32; current source packages remain older.

The earlier offline 100-million-visit failure on a longer authored WFC passage
is resolved by streaming: 88 notes / 791022 frames now render, with at most 12
voices. Envelope-only edits preserve sounding bass/chord stems and complete MIDI;
127/2048-frame reads replay exactly. The maintained recorded workflow regenerates
a separate sustained audition using admitted context and authored phrase training.
Stream evidence is in `build/instrument-stream-{stable,trunk,win64}/`, including
48 byte-identical cross-target artifacts and a late mixed-stream admission
failure that preserves all six accepted outputs after individual stems rendered.
The preceding short offline output differs by at most one PCM16 step because
scheduled mixing accumulates Double values before converting each sample.

This isolated-note style still cannot satisfy a requested 32-span duration prefix.
Recorded phrase learning remains open; longer sound playback does not establish
learned phrase or instrument-role behavior.

## Stationary timbre evidence checkpoint

The extended native style fixture fits controlled phase-opposed waveforms, checks
weighted magnitudes against known coefficients, keeps a source active only for
timbre, saves/reloads a second derivation after releasing parents, and verifies
detached arrays, explicit omission and admission failures. The actual rhythm
model remains exact under independent timbre weighting.

The maintained controlled workflow measures two WAV intervals, blends timbre with
independent rhythm/pitch weights, saves a second derivation, and selectively changes
the resulting recipe. Both variants contain 32 performance spans, 75 MIDI notes
and 192937 stereo frames at 44100 Hz. The actual provider/voice states, models,
MIDI and reference preview remain exact; final stereo audio changes.

The recorded workflow uses the existing attributed VSCO 2 CE bassoon C and A
sources converted to 8000 Hz. At source frame 907, a 272-frame fit and independent
880-frame frequency window admit 24 and 16 harmonics respectively under the same
0.25 error limit. Frequencies are 130.918415 and 219.800066 Hz; relative errors
are 0.04797157 and 0.15076701. These are explicitly selected short stationary
intervals, not whole-instrument accuracy results. Both measurements survive
weighted blending and a second derivation. Baseline timbre weights are C:A = 2:1;
the edit selects A alone while retaining C's measured musical behavior. Each
variant produces five notes and 19845 stereo frames. The derived profile has
two sources, depth three and five ancestry nodes.

Checked stable/development Win32 and stable Win64 pass source/style fixtures,
the maintained controlled block, saved recorded-profile cross-loading and voice
controls. The full maintained recorded workflow passes stable Win32. Independent
MIDI re-rendering reconstructs the recorded output exactly and the controlled
output within one PCM16 step. MIDI can reorder simultaneous notes; the renderer
accumulates tones into Single samples, so order can affect final quantization.
This tolerance is separate from deterministic replay: all 24 compared generated
WAV/MIDI/preview artifacts match across targets. No authored compiler warnings
were found; existing dependency/compiler warnings remain.

Evidence: `build/style-timbre-{stable,trunk,win64}/`, especially `core-run.log`,
`style-run.log`, `controlled-workflow.log`, `recorded-*-check.log`,
`recorded-controls.log` and `final-status.log`. Stable `recorded-workflow.log`
and `recorded-status.log` cover the maintained recorded path; `replay.log`
records byte comparisons and `rejection-status.log` records preserved accepted
profiles after wrong-source/error-policy failures. Recorded profile identity:
`405da829a283c3c61b3f1d18dd86b098fb6bdedcb6763ce61bd367b677de0aca`.
Recorded baseline WAV SHA256:
`ec9e9e79ef4502c5e2960e9d276b68a82270300136717fd5aaec27f52fe09002`.

Full ordinary-build and packaged-source evidence remain earlier checkpoints.
The timbre contract supports measured stationary shape and repeated controlled
blending. Evolving envelopes, automatic stable-region selection, calibrated
broader recording admission and separate learned voice timbres remain open.
