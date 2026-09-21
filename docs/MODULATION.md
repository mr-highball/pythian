# Automation, additive synthesis and modulation

[Home](../README.md) · [DSP](DSP.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

## Immutable frame curves

`pythian.automation` owns `TAutomationCurve`, constructed from a copied array
of 1..4096 `TAutomationPoint` records. A point has a nonnegative Int64
`Frame`, finite `Value` with magnitude at most 1e12, and an outgoing
`Transition`: `atHold`, `atLinear` or `atExponential`.
Frames must strictly increase; no sorting, duplicate merging or retiming occurs.

`ValueAt(Frame)` rejects negative coordinates, holds the first/last value
outside the point extent, and returns the stated value at every exact knot.
Between knots, hold retains the left endpoint; linear interpolates values;
exponential interpolates their logarithms and requires positive endpoints.
The final transition has no following segment and is ignored.
`CopyPoints` returns a detached array for point curves. `Minimum` and `Maximum` bound every
evaluated value, including interpolation rounding.

Curves express values in the caller's units. They do not infer sample rate,
tempo, beats or wall-clock time. A frequency fall lasting 0.15 seconds at
48000 Hz uses endpoints at frames 0 and 7200. Integer differences are taken
before floating conversion, preserving local interpolation near High(Int64).
Queries use binary search; there is no mutable playback cursor or hidden clock.

### Periodic and composed controls

`CreateLfo(PeriodFrames, Shape, PhaseFrames = 0)` supplies a reusable bipolar
[-1,1] sine or triangle curve. Both start at zero rising; phase is a forward
offset within the period. The period is an integer of at least four frames.
Modulo arithmetic preserves repeatable phase even near High(Int64), without
an accumulating cursor. The caller chooses the frame period and its rate/tempo
quantization; this is not an arbitrary fractional-Hz or beat-tracking API.

`CreateAffine(Source, Scale, Offset)` owns a clone and evaluates
`Offset + Scale * Source.ValueAt(Frame)`. Negative scales are supported;
cached bounds cover the whole excursion. Coefficients and output extrema have
magnitude at most 1e12. Definitions have a maximum depth of eight, including
the point/LFO leaf. There is no per-sample allocation.

For a 5 Hz sine at 24000 Hz, create a 4800-frame LFO, then derive independent
routes: scale 30, offset 0 for +/-30 cents vibrato; scale 0.35, offset 0.65 for
gain 0.30..1.00. A slower triangle can independently drive pan or cutoff.
Free the original LFO after constructing the derived curves.
`Clone` preserves any curve kind; `CopyPoints` rejects generated/composed
curves rather than approximating them with a finite point list.

These are native sound-realization controls beneath the
[layered style graph](LAYERED-STYLE.md). A future voice/style provider can supply
their parameters without depending on the renderer's implementation. Key/BPM
provider passes, tempo-synchronized global phase and reusable style profiles
still require their explicit musical-time contracts. Current automation always
uses note-relative frames and does not infer any of those properties.

`FrequencyWithCents(BaseHz, Cents)` computes `BaseHz * 2^(Cents/1200)`.
It accepts base 0..384000 Hz and +/-19200 cents. It does not clamp output
to a destination Nyquist frequency; the receiving oscillator/renderer validates it.

## Gated envelope curves

`pythian.envelope.TGateEnvelope` composes two immutable automation curves: a
held level relative to note-on, and a release multiplier relative to note-off.
Both curves stay in 0..1. A positive release has an explicit `ReleaseFrames`,
starts at one and reaches zero at that frame. A zero-frame release requires a
nil release curve and cuts immediately. Construction clones the curves.

For gate frame G, the level before G is `Held.ValueAt(frame)`. During release it
is `Held.ValueAt(G) * Release.ValueAt(frame - G)`; at G + ReleaseFrames it is zero.
Thus a short note interrupted during an attack, decay or later swell releases
from the level reached at its actual note-off. Evaluation subtracts coordinates
before testing the release extent, avoiding overflow near the Int64 limit.

Set `TSynthVoice.GateEnvelope` to opt in; nil uses the existing ADSR definition.
The custom envelope replaces ADSR, including its release duration. Gain, velocity,
gain automation, source note-off behavior, filtering and pan remain independent.
Seconds-based rendering quantizes the gate once and adds the exact custom tail.
Curves are in output frames: callers explicitly retime them for a different sample
rate or desired beat duration. No automatic stretching follows a changed gate.

Instrument zones and planned tone records borrow the envelope definition. Keep it
alive through planning and synchronous rendering. Each playing tone owns a clone;
after successful scheduler admission the original may be freed. Early release
uses the scheduler's actual gate frame; repeated release does not restart the tail.
Curve depth contributes to rendering/scheduling work admission. Voice duration,
absolute frame and offline sample bounds still apply.

The core instrument example combines a five-point attack/decay/swell/hold shape
and a two-segment release with an ADSR layer. Its optional MIDI input can audition
notes generated by the WFC companion through this same core-only instrument path:

```text
pythian.example.instrument OUTPUT.wav [NOTES.mid]
```

These runtime envelopes sit beneath the style/voice passes. The explicit-region
measurement below can supply their shape. Inferring note boundaries, associating
envelopes with voice roles, and saving/blending that evidence remain separate work.
This introduces no persisted artifact or historical format reader.

Checked FPC 3.2.2/3.3.1 Win32 and 3.2.2 Win64 pass independent stereo envelope
arithmetic, exact tails, seconds/frame agreement, early scheduled release after
freeing definitions, and duration/work rejection. The authored instrument renders
16 notes / 20 layers / 91728 frames; a MIDI audition of the recorded-style second
blend renders five notes / 19845 frames. Both WAVs match across all three targets.
The stable core workflow passes, six preceding ADSR WAVs retain their hashes, and
the rebuilt WFC saved-timbre path retains exact WAV/MIDI/preview output. Evidence:
`build/gate-envelope-{stable,trunk,win64}/` and the [work record](WORK.md).

## Measured amplitude envelopes

`TEnvelopeTrace.Create(Clip, StartFrame, FrameCount, Channel, WindowFrames)`
measures one explicit source region/channel in nonoverlapping rectangular windows.
Each point records `sqrt(sum(sample * sample) / validFrames)` at the integer center
of that window, relative to StartFrame. The final partial window excludes padding
from both its divisor and center. RMS includes DC and preserves source amplitude;
it is a coarse energy envelope, not an isolated instrument or analytic envelope.
The caller chooses resolution appropriate to the carrier periods and modulation.

The trace retains rate, selected coordinates, window width, peak RMS and detached
point values. `CopyRmsPoints` returns another detached copy. The source clip may
be freed immediately. Selection is bounded to 1048576 frames, windows to 4..65536
frames, and point counts to 2..4094. Work is linear in the selected frame count.
Silence can be measured but cannot become a normalized envelope.

`CreateGateEnvelope(GateFrame, OutputRate, MaximumTailRatio, MinimumRms = 1e-5)`
uses a caller-declared interior gate. It linearly interpolates measured RMS at
that gate, normalizes held levels by peak window RMS, and divides release values
by gate RMS. A release rising above its gate level rejects rather than being
clipped. Both peak and gate RMS must exceed MinimumRms; final-window RMS divided
by gate RMS must meet the declared 0..1 tail limit. Only then is a zero endpoint
added at the selected region's end. The limit bounds measured truncation level,
not perceptual audibility, source noise, transcription confidence or reconstruction
error. The first measured level extends back to frame zero; no attack is invented.

Retiming floors absolute source-frame coordinates into output frames, including
the gate and region end. Release coordinates subtract that mapped gate. Collapsed
knots reject explicitly; use a wider window or a suitable output rate. No tempo
stretching occurs. Shorter generated notes still use the held level reached at
their actual gate, followed by the measured relative release shape. The library
does not infer that an authored gate coincides with a recording's physical note-off.

The existing native source operator provides amplitude-only transfer onto a sine
source, at a declared gate and 440 Hz or over all admitted imported MIDI notes:

```text
pythian.sources.demo OUTPUT.wav --envelope INPUT.wav START COUNT GATE CHANNEL WINDOW MAX_TAIL_RATIO [--midi NOTES.mid]
```

It hashes the actual input, reads only the selected region into audio memory,
prints every raw RMS point and admission setting, and completes admission/rendering
before writing the WAV. The operator's default minimum RMS is 1e-5. Gate is relative
to START; all input coordinates/window sizes use source frames. Timbre, pitch and
instrument roles are not measured in this mode. No source-style envelope payload
or historical reader is introduced. [Saved styles](WAVE-STYLE.md#saved-measured-envelopes)
now retain these raw measurements and independent envelope weights. Core
`TEnvelopeTrace.CreateMeasured` validates loaded RMS geometry and values;
`TGateEnvelope.Blend` combines linear components without stretching time.

## Tone automation and precursor extraction

`TSynthVoice.Automation` carries five optional curves:

| Field | Meaning | Admitted range |
| --- | --- | --- |
| FrequencyHz | Absolute frequency, replacing tone frequency | 0 <= value < Nyquist |
| PitchCents | Applied to the selected base frequency | +/-19200 cents |
| GainMultiplier | Multiplies voice gain, velocity and the selected envelope | 0..16 |
| Pan | Absolute equal-power pan | -1..1 |
| CutoffHz | Absolute one-pole cutoff | 0 < value < Nyquist |

All coordinates are relative to note-on, continuing through the release tail.
Nil retains the existing tone/voice value. `DefaultSynthVoice` initializes
every curve reference to nil. Both seconds and exact-frame renderers support
these fields; initialize records with the factory and rebuild callers.

The synchronous renderer **borrows** immutable curves. Keep them alive until
rendering returns; sharing one curve across notes is supported.
`PlanNoteTones` also copies these references into its returned records,
so curves must survive subsequent rendering of that plan.
Playing tones own clones, including periodic and composed definitions. After
successful scheduler admission, callers may free their original curves; the
scheduled voice retains its copies. The renderer never frees caller-owned
definitions. No automation serialization format is introduced.

Preflight checks each full curve's extrema before output allocation.
Frequency and cents combine conservatively using their separate maxima;
correlated curves whose separate maxima exceed Nyquist can therefore reject
even if their simultaneous values would remain safe.
The existing sample/event/work limits remain in force. Failure leaves caller
clips and curves unchanged. Default voices retain byte-identical legacy output.

`TOnePoleFilter.SetCutoff` changes its coefficient while retaining history.
Rejected cutoff values preserve both coefficient and state. Automation changes
the coefficient at the specified sample; it adds no smoothing beyond the curve.
Abrupt gain, pan, frequency or cutoff changes can click and create sidebands.

Phanes `src/phanes.audio.synth.pas` schedules a 125 -> 42 Hz exponential
kick pitch fall over 0.15 seconds and a 600 -> 160 Hz exponential cutoff fall
over 0.25 seconds. Those general scheduling behaviors now have reusable native
curves; the demonstration uses both. The pitch-dependent detune concept maps
to the cents utility/curve. Phanes's fixed voice/style choices remain example
or application policies. Pythian's one-pole filter and ADSR do not claim
sample parity with Web Audio's biquad and scheduled gain implementation.

## Additive partials

`pythian.additive.TAdditiveOscillator` owns a copied array of 1..128 partials.
Each partial has `Ratio` in 0..256, signed `Gain` with magnitude <=16,
and `PhaseCycles` in [0,1). Noninteger ratios allow inharmonic sounds.

`Next(FundamentalHz)` emits the sum at current phases, then advances each phase
by `FundamentalHz * Ratio / SampleRate`. Fundamental frequency is nonnegative
and below Nyquist. Partials at or above Nyquist are omitted; their phases
continue advancing so re-entry retains integrated phase. `OmittedPartials`
reports the count for the last successful sample and resets to zero on Reset.
It counts frequency omissions even for zero-gain partials.

The overload `Next(FundamentalHz, GainMultipliers)` supports independent
partial envelopes or amplitude modulation. Empty means unity; otherwise the
array must match the partial count, with finite signed multipliers of magnitude
<=16. All inputs validate before any partial advances. The array is borrowed
for the call and not retained. No per-sample allocation is performed.

Reset restores the configured initial phases. Output is unnormalized and can
retain headroom above one (absolute bound 32768 with maximum configured gains
and multipliers). The caller applies envelopes, gain, mixing and encoding.
Omission bounds stationary partial frequencies; abrupt pitch changes, partial
re-entry and amplitude modulation can still create out-of-band energy.
There is no partial fade at the Nyquist boundary.

The sinusoidal-bank approach is described in Julius O. Smith III,
[*Spectral Audio Signal Processing: Additive Synthesis*](https://www.dsprelated.com/freebooks/sasp/Additive_Synthesis.html).
The owning API, input bounds and omission/state policy are Pythian's implementation;
no external oscillator code was copied.

## Phase and frequency modulation

`pythian.modulation.TPhaseOscillator` is a sine accumulator usable as a
carrier or bipolar LFO. `Next(FrequencyHz, PhaseOffsetRadians)` samples
`sin(2*pi*phase + offset)`, then advances phase. Signed frequencies permit
reverse and through-zero motion, with magnitude strictly below Nyquist.
Offsets have magnitude at most 1e6 radians and affect output only.
Reset takes a phase in [0,1) cycles. Input rejection preserves phase.

`TFmOscillator` has separate carrier/modulator sine phases:

- `NextFm(CarrierHz, ModulatorHz, DeviationHz)` emits the current carrier sine,
  then advances by `(CarrierHz + DeviationHz*sin(modulatorPhase))/SampleRate`.
  This is sampled linear frequency modulation; deviation is in Hz.
- `NextPm(CarrierHz, ModulatorHz, IndexRadians)` emits
  `sin(carrierPhase + IndexRadians*sin(modulatorPhase))`, then advances
  each unmodulated phase by its signed frequency. Index is in radians, with
  magnitude at most 64.

Both methods share state; switching methods is explicit and may click.
Reset validates both initial phases before changing either.
Carrier and modulator frequency magnitudes must be below Nyquist.
FM additionally requires `abs(carrier) + abs(deviation) < Nyquist`,
conservatively bounding every instantaneous frequency.
Negative instantaneous FM frequency is supported.

The PM sideband relationship to Bessel functions follows the elementary
sinusoidal model in Smith,
[*Frequency Modulation (FM) Synthesis*](https://www.dsprelated.com/freebooks/sasp/Frequency_Modulation_FM_Synthesis.html).
Pythian names the Hz-integration and radian-offset APIs separately: their
per-sample depth changes and phases are not interchangeable. No external FM
implementation was copied.

These input bounds do **not** band-limit modulation sidebands.
Increasing depth, fast automation, feedback or other nonlinear processing can
alias. Render at a suitably higher supported rate and use `ResampleClip`
to filter before reducing rate. Automation frame coordinates must scale with
that render rate. Fourfold oversampling is demonstrated and measured for one
fixture; it is not an alias-free guarantee for all admitted settings.
The bounded offline converter's work, duration and endpoint contracts still apply.

These reusable per-sample building blocks also have [shared source factories](SOURCES.md)
for the tone renderer, alongside wavetable/sample voices. The original modulation
demo composes primitives directly to demonstrate independent partial/index curves
and oversampling. Broader source-parameter routing remains open; native
[voice scheduling](SCHEDULING.md) and effect buses have separate contracts.

The later [sample/automation checkpoint](SOURCES.md#sample-loop-and-automation-quality-checkpoint--2026-09-19)
checks simultaneous pitch, cutoff, pan and gain motion through a sustain-loop
source and streaming renderer on three Windows targets. Its smooth-loop reference
and paired sample-bandwidth control do not establish FM/PM sideband safety.
The separate [streamed FM/PM checkpoint](#streamed-fmpm-bandwidth-checkpoint--2026-09-19)
records the actual source/stream/converter path and its declared limits.

## Verification and listening

Periodic-control evidence: checked FPC 3.2.2 and 3.3.1 i386-win32 runs under
`build/control-curves-{stable,trunk}/`. The new control fixture compares every
native and scheduled stereo sample against independently calculated per-frame
point curves; maximum difference is zero, including PCM16. It frees caller
curves before scheduled playback, checks depth/phase boundaries, and rejects a
pitch excursion whose later maximum crosses Nyquist. Existing modulation and
scheduler fixtures also pass. These are focused checks, not a new full-suite or
package verification checkpoint.

`pythian.control.curves.demo OUTPUT.wav` renders 288000 stereo frames at
24000 Hz: four three-second sections of the same 220 Hz saw voice, first plain,
then 5 Hz vibrato, 5 Hz tremolo, and 0.5 Hz triangle cutoff/pan motion. The output
uses native tone rendering and contains no recorded source music. The earlier
modulation demo below retains its recorded WAV hash. Listening quality beyond
these signal checks remains an operator judgement.
Both compiler outputs have SHA256
`801b0a6af642307c3b71bb6423f7cb9323a8c9f4302582d155552d5d3d651ee9`.

### Earlier additive/FM checkpoint

Existing FPC 3.3.1, i386-win32, checked flags `-B -Sa -Cr -Co -Ci -gl`.
Full build and WFC integration: `build/modulation-validation.log`.
Final independent-partial modulation checks: `build/modulation-focused-validation.log`.
Final demo compile/render: `build/modulation-demo.log`.
All 27 core units compile without vendor source paths in the build's core phase.
No authored warnings; existing WFC unreachable-code warnings remain.

Focused evidence covers immutable curve ownership, exact endpoints, hold/linear/
exponential interpolation, high Int64 frame differences, invalid candidates,
cents conversion, additive harmonic/inharmonic sums, partial omission and phase
re-entry, per-partial amplitude changes, failed-call state preservation, negative
instantaneous FM frequency, PM zero-index identity, cutoff-history preservation,
note-relative automation, moving pan, combined pitch rejection and render replay.

At 32768 Hz, a 4000 Hz carrier, 400 Hz modulator and PM index one produce
the following measured amplitudes over 8192 coherent samples. Independent
integer-order Bessel power series agree within 1e-9:

| Sideband order | Measured amplitude |
| --- | ---: |
| 0 | 0.7651976866 |
| +/-1 | 0.4400505857 |
| +/-2 | 0.1149034849 |
| +/-3 | 0.0195633540 |

A wider PM fixture (4000 Hz carrier, 6000 Hz modulator, index three) creates a
22000 Hz component that folds to 10768 Hz at 32768 Hz. Its measured amplitude
falls from 0.3090627231 to 0.0000000194 when synthesized at 131072 Hz and
sinc-filtered to 32768 Hz. The desired 10000 Hz sideband remains within 1e-5
of the independent J1(3) value. The roughly 144 dB difference describes this
single coherent bin, near floating/sample precision; it is not a broadband
converter or FM suppression specification.

The native command is `pythian.modulation.demo OUTPUT.wav`.
The build writes `modulation.wav`: 360000 stereo frames at 48000 Hz,
five consecutive 1.5-second sections:

| Time | Sound |
| --- | --- |
| 0.0 s | Three pitch-fall kicks |
| 1.5 s | Three saw bass notes with cutoff and pan automation |
| 3.0 s | Inharmonic additive tone, separate partial decays, 5 Hz vibrato |
| 4.5 s | Linear FM with falling deviation, rendered at 4x rate |
| 6.0 s | Phase modulation with falling index, rendered at 4x rate |

Final WAV SHA256:
`11899cde941b4b02981c57fa065b8023a2c2a5ce53004168169a47a26feb7338`.
PCM left/right peak 0.4398193359 / 0.3942260742;
RMS 0.1279702053 / 0.1242053451.
Measurements: `build/modulation-metrics.json`.
Legacy synthesis retains hash
`07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.
Operator listening quality, other compiler/platform targets and arbitrary
modulation-bandwidth safety are unverified.

## Streamed FM/PM bandwidth checkpoint — 2026-09-19

The [tone PCM reader](SCHEDULING.md#tone-streams-as-pcm-input) connects actual
`TFmSourceFactory` voices through `TFrameToneStream` to `TSincResampleStream`.
Four paths compare native 32768-Hz rendering against 131072-Hz rendering followed
by bounded conversion to 32768 Hz, for frequency and phase modulation. Carrier
is 4000 Hz and modulator ratio 1.5. FM deviation is 10000 Hz; PM index is 3.
Gain is 0.35, pan centered, one-pole cutoff 0.4 times render rate, attack 5 ms,
unity sustain, gate 0.5 seconds and release 0.125 seconds. Gates and envelopes
use the render rate; each output contains 20480 stereo frames.

An independent integer-order Bessel series predicts the wanted 10000-Hz sideband
and the third upper sideband at 22000 Hz, which folds to 10768 Hz at the base rate.
The reference includes the renderer's one-pole magnitude response and equal-power
pan/gain. For sampled frequency integration, the effective index is
`pi * deviation / (rate * sin(pi * modulator / rate))`, derived by summing the
sampled sine's phase increments. It is 1.762261210 at the base rate and 1.672425424
at fourfold rate here. PM remains index 3. These are different render-rate FM
signals, so matching their wanted amplitudes to one shared index would be wrong.

Coherent projection over output frames 4096..12287 gives:

| Mode / render rate | Wanted 10000-Hz amplitude | Independent reference | Folded 10768-Hz amplitude |
| --- | ---: | ---: | ---: |
| FM / native | 0.128159674 | 0.128159674 | 0.020438195 |
| FM / fourfold then sinc | 0.141037645 | 0.141037650 | 1.244e-9 |
| PM / native | 0.074844633 | 0.074844633 | 0.067534538 |
| PM / fourfold then sinc | 0.083020115 | 0.083020118 | 4.384e-9 |

All wanted/reference errors are below the declared absolute tolerance 1e-5.
Native folded amplitudes must exceed 0.01 and agree with their own Bessel/filter
references within 1e-5; converted folded amplitudes must stay below 1e-5.
These two coherent-bin controls do not establish broadband rejection, all depth
settings or arbitrary fast/time-varying modulation safety.

The pipeline retains one voice (logical frame-work reservation 18), at most a
2048-frame stereo reader block, 547 stereo converter-history frames and 547
cached Double weights. The high-rate PCM is never materialized as a complete
clip. A 127-frame reader with caching and a 2048-frame reader without caching
produce identical Single output. Independent duration checks confirm input and
output counts through EOF. This bounds storage for the selected pipeline; it
does not establish real-time scheduling deadlines.

Checked FPC 3.2.2 Win64, 3.2.2 Win32 and 3.3.1 Win32 all pass. The native audit
recomputes report/audio hashes and confirms all four WAVs are byte-identical
across targets. Sources, reports and logs are ignored under
`build/fm-stream-{study,stable,trunk}/`. The local `study.lpr` takes an output
prefix; `audit.lpr` takes the three `measured` prefixes, Win64 first. Checked
flags are `-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools`, with separate output directories.
The maintained scheduler fixture covers the reusable reader's boundaries.

`build/fm-stream-study/measured-comparison.wav` assembles a three-second audition:
FM native, FM fourfold, PM native, PM fourfold, each followed by 0.125 seconds of
silence. SHA256 is
`fe16863a11afd1ef7cfad87d2d13dd8451aa72790e983c3dc15231f2f2e2e68d`.
No listening approval is inferred. See the [quality summary](SYNTHESIS-QUALITY.md)
for the combined acceptance scope and remaining review.
