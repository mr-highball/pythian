# Reusable synthesis sources

[Home](../README.md) · [DSP](DSP.md) · [Modulation](MODULATION.md) · [Work](WORK.md)

## One definition, independent voices

`pythian.source` separates a reusable immutable `TAudioSourceFactory` from
mutable `TAudioSource` playback instances. Factories must outlive their
instances. `CreateSource(SampleRate, Seed)` returns a fresh caller-owned
instance; constructors do not use a device, global clock or shared random state.

A source implements `ReadFrame(FrequencyHz, Left, Right): Boolean`.
Frequency is the nonnegative played pitch, strictly below output Nyquist.
Mono sources return equal channel values; stereo sources retain both channels.
True supplies one frame. False means natural exhaustion and returns zeros.
`Reset` restores initial phase/position/seed and release state.
`NoteOff` is idempotent and separate from amplitude release.
A source's definition determines whether note-off affects playback.

Factories provide `Channels`, `ValidateRange` and `FrameCost` for preflight.
These must be stable, side-effect-free queries. Custom factories must return
independent owned instances and uphold finite output and rejection/state
contracts. A factory must remain alive through source destruction.

| Factory | Source behavior |
| --- | --- |
| TWaveSourceFactory | Existing sine/triangle/saw/square/noise with explicit oscillator quality and seed |
| TAdditiveSourceFactory | Owned additive partial recipe; each instance owns its partial phases |
| TFmSourceFactory | FM or PM with fixed modulator/carrier ratio and explicit depth units |
| TWavetableSourceFactory | Precomputed harmonic-limited cycle tables with phase-continuous lookup |
| TSampleSourceFactory | Owned mono/stereo sample region, pitch conversion and explicit loop policy |

[Instrument zones](INSTRUMENTS.md) now select these existing factories/voices by
key and velocity, including explicit overlapping layers. Each selected voice still
creates an independent source through the same factory contract.

The waveform/additive/FM factories are in `pythian.source.oscillator`.
Wave defaults to polynomial quality. Additive copies and validates its recipe.
FM defines modulator Hz as played Hz times a ratio in 0..256; depth is Hz for
`fsmFrequency`, radians for `fsmPhase`. Existing oscillator bounds and
[modulation sideband limitations](MODULATION.md) still apply. These source
adapters do not implicitly oversample or infer envelopes for operator depth.
The underlying primitives remain usable for per-sample amplitude/index control.

## Shared tone renderer

Assign a factory to a voice initialized by `DefaultSynthVoice`:

```pascal
LFactory := TWavetableSourceFactory.Create([0.8, 0.2, 0.1], []);
try
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.SourceFactory := LFactory;
  { Set the tone's frame coordinates, frequency and velocity as usual. }
  LClip := RenderFrameTones(LTones, 48000);
  try
    SaveWavePcm16('voice.wav', LClip);
  finally
    LClip.Free;
  end;
finally
  LFactory.Free;
end;
```

Both seconds and exact-frame renderers borrow the factory, create/free one source
per note, and use existing pitch automation, ADSR or optional
[gated envelope curves](MODULATION.md#gated-envelope-curves), gain, cutoff and pan behavior.
The source operator's `--envelope` mode transfers measured RMS amplitude from an
explicit WAV region onto a sine source or imported MIDI notes. See
[measurement and admission](MODULATION.md#measured-amplitude-envelopes); this mode
does not infer timbre or physical note boundaries.
An explicit [biquad filter mode](EFFECTS.md) is also available per voice;
serial post-mix effect chains preserve state across consecutive clips.
Nil factory retains the existing Shape/OscillatorQuality implementation.
The source receives note-off before reading the first release frame:
the supplied integer gate for frame tones, or the ceiling of gate seconds times
sample rate for seconds tones. ADSR release-duration rounding retains the existing
floating-point seconds contract. A custom gated envelope instead adds its explicit
integer release length to that admitted gate.

Natural source exhaustion feeds zeros through the remaining filter/envelope
span; it does not shorten the requested tone or output extent.
Stereo has independent left/right filter history. Pan multiplies source left
by `cos((pan+1)*pi/4)` and source right by `sin((pan+1)*pi/4)`;
it does not downmix or crossfeed. Center pan attenuates each channel by sqrt(1/2),
as with the existing duplicated mono path.

Source frequency ranges, channel counts and work are checked before output
allocation. The existing 100-million render-visit budget now charges a
conservative source weight per frame: waveform 1, additive partial count,
FM 2, wavetable 4, linear sample 2*channels, sinc sample its maximum
tap count times channels. This is a bounded workload measure, not a count of
all processor instructions. Expensive sample sources can reach it sooner.
Output/event budgets are unchanged.

Factories, automation and gated envelope references also remain borrowed in tone records
returned by MIDI note planning. Keep them alive until those records are rendered.
Rebuild consumers for the new `TSynthVoice.SourceFactory` field.
No corpus, WFC, MIDI or source serialization format was changed.

## Sample regions and loops

`TSampleSourceFactory.Create(Clip, StartFrame, EndFrame, RootHz, Playback,
Quality, MaximumStep)` owns a detached copy of the nonempty half-open source
region [StartFrame, EndFrame). The original clip may then be freed.
The copied region retains its original rate and channels.

Played frequency maps to source-frame advancement:

`step = (playedHz/rootHz) * (sourceSampleRate/outputSampleRate)`.

RootHz must be positive and at most 384000. Configured MaximumStep is positive,
at most 64, and defaults to 8. It is both a pitch admission bound and a
conservative work estimate. Select an appropriate bound for the intended
pitch/rate range. A zero played frequency holds the current interpolated sample.
Positive fractional steps preserve interpolation; steps larger than the period
can wrap multiple times in one output frame. State uses a bounded floating
source position; cross-platform bit-identical long-run phase is not promised.

| Playback | End and note-off behavior |
| --- | --- |
| spOneShot | Stops at region end; note-off does not alter the source trajectory |
| spLoop | Wraps throughout the region; ignores note-off |
| spSustainLoop | Wraps while held; note-off completes the traversal from current position, then stops |

Sustain release from position zero therefore traverses a full region.
Reset restarts at region frame zero and reenables sustain looping.
The original constructor loops the copied region. The explicit interior-loop
constructor below adds an intro and tail. Ping-pong, reverse playback, crossfade
loops and automatic loop-point discovery remain separate work.

`sqLinear` uses two adjacent samples. A one-shot clamps its last neighbor;
loop playback wraps that neighbor to region start.
`sqSinc` uses the shared Blackman-windowed sinc kernel. It updates cutoff/support
for the current step without allocating, clamps taps for one-shots and wraps
**all** taps for loops, including taps before region start.
Released sustain loops retain periodic interpolation for their final traversal.

The extended sampler API exposes `TSampleBoundary = (sbClamp, sbWrap)` and
`SetSourceStep`; default clamp behavior and existing conversion output remain
unchanged. A rejected step preserves kernel configuration.
Changing pitch/filter bandwidth rapidly can produce extra sidebands or transients.
Periodic interpolation does not repair a discontinuity between chosen loop
endpoints; choose appropriate regions or apply envelopes.
A sinc kernel may overshoot and is not an ideal band limit.

## Interior sustain loops with an intro and tail

`TSampleSourceFactory.CreateLoopRegion(Clip, StartFrame, EndFrame, LoopStart,
LoopEnd, RootHz, Playback, Quality, MaximumStep)` copies the region once and
admits the nonempty half-open loop inside it. All supplied coordinates refer to
the original clip. Playback is `spSustainLoop` (default) or `spLoop`; both linear
and sinc interpolation are supported. The original constructor and its output
semantics remain unchanged.

Playback starts at the region's first frame, traverses its intro once, then
repeats the interior loop. Sustain note-off completes the current traversal and
continues into the region's tail without another wrap. Note-off during the intro
therefore plays the original region through once. At the exact start of a new
loop traversal, release completes that full traversal. `spLoop` ignores note-off.
Reset restores the intro and held state; separate voices own independent state.
The tail does not replace the voice's ADSR release: both apply, and a short
amplitude release can truncate audible sample content.

[pythian.sample.sequence](../src/pythian.sample.sequence.pas) provides the shared
borrowed-clip address mapping. Linear neighbors and every sinc tap follow the
same virtual intro/repetition/tail sequence. This preserves the first traversal's
intro even when the sinc radius spans several loop periods. Sinc uses the existing
kernel through `TSincSampler.CreateLoopSequence`; the sequence and clip must
outlive that sampler. No expanded audio or per-frame allocation is required.

While held, source position is rebased by complete loop periods only after the
maximum possible interpolation history has left the intro. That radius uses the
configured maximum step, so a later pitch increase does not reintroduce a false
intro. Released trajectories are not rebased. The standalone sequence bounds
virtual positions to 256 million frames; source playback stays bounded by source
length, loop length and maximum kernel support during an arbitrarily long hold.
This is a floating-position contract, not cross-platform long-run phase parity.

Centered sinc reads future trajectory samples. A note-off changes that future
trajectory immediately; no prediction, crossfade or click-free release guarantee
is implied. Loop-point continuity and suitable amplitude envelopes remain the
caller's responsibility. Linear/sinc source work estimates remain as before.

Checked FPC 3.2.2 and 3.3.1 i386-win32 fixtures verify detached stereo ownership,
intro/tail traversal, release at a loop boundary and during the intro, independent
voices, reset, pitch rejection, one-frame/multiple-wrap loops and zero-frequency
hold. A physically expanded PCM oracle matches every sinc sample exactly through
fractional playback, rebasing, a step increase from 0.5 to 8, and release at step
1.5. Existing source and resampling fixtures pass on both compilers.

`pythian.sample.loop.demo OUTPUT.wav` synthesizes an authored stereo sample and
compares one-shot playback at 0 seconds, interior sustain at 2 seconds and pitched
sustain at 4 seconds. Gates last 1.5 seconds; source attack/loop/tail durations are
0.1/0.1/0.3 seconds at root pitch. Native ADSR release is 0.8 seconds. The output is
75601 stereo frames at 12000 Hz (6.300083 seconds), with peaks 0.337097 / 0.334259.
Both compiler WAVs match SHA256
`ad37c35ac0c8a85d30273381b20e2409eca8ab455ffe9a2b7f41865aa714bd00`.
The user later heard the complete 0–6.3-second demo and said it sounded okay
at these authored one-shot and loop settings, without a fault time. This does
not qualify arbitrary loop points.
Logs/artifacts: `build/sample-loop-{stable,trunk}/`, `build/sample-loop-replay.log`.
The normal build includes the fixture and demo; full-suite/package refresh is
not claimed for this 60-core / 17-adapter checkpoint.

## Sample-loop and automation quality checkpoint — 2026-09-19

An authored stereo sample exercises the interior loop through `TFrameToneStream`
while frequency, cutoff, gain and pan change together. The 12000-Hz source has
600 intro frames, a 300-frame loop and a 1200-frame tail. Its left/right carriers
are 200/280 Hz, with half-cosine attack and tail amplitude and peak level 0.6.
Both carriers complete whole cycles across the loop; this is a deliberately
smooth join, not loop-point discovery from an arbitrary recording.

There are 18 paths: linear/sinc interpolation, output rates 8000, 16000 and
48000 Hz, and gates at 5 ms, 200 ms and one frame after 200 ms. Frequency ramps
200 to 400 Hz over an eighth of a second, then holds. Over the same interval,
cutoff moves from 0.1 to 0.3 times rate, pan from -0.5 to +0.5 and gain multiplier
from 0.5 to 1. Voice gain is 0.5, velocity 0.75, with a 5-ms attack, unity sustain
and 200-ms release. Maximum source step is 3. Early release traverses the original
intro/loop before the tail; later release finishes its current loop.

The reference sums the linear frequency ramp in closed form, derives the next
loop exit from unwrapped source position, and evaluates the analytic carriers
and amplitude. Separate one-pole filter, ADSR, pan and gain calculations predict
each stereo sample. Expected values do not use the sample address mapper,
interpolation kernel or automation/envelope evaluators. Explicit Double
intermediates keep reference arithmetic consistent across targets. Geometry and
every 127/2048-frame read replay are also checked.

| Interpolation | Maximum absolute reference error | Maximum relative RMS residual | Declared peak / RMS limits |
| --- | ---: | ---: | --- |
| Linear | 5.264e-4 | 1.810e-3 | 0.001 / 0.005 |
| Sinc | 7.688e-8 | 1.981e-7 | 0.0001 / 0.001 |

Maximum motion-output magnitude is 0.207756; logical frame-work reservation is
20 for linear and 838 for sinc. These are reservation values, not wall-clock
performance or real-time-device guarantees. All declared limits pass on checked
FPC 3.2.2 Win64, 3.2.2 Win32 and 3.3.1 Win32 without a renderer change.

A paired bandwidth control uses a periodic 12000-Hz source with 200-Hz and
4800-Hz components of amplitude 0.4. Playback at twice root pitch into 8000-Hz
output moves them to 400 and 9600 Hz. The latter folds to 1600 Hz without adequate
filtering. With gain 0.5, centered stereo pan and one-pole cutoff 3200 Hz,
coherent projection over 0.1–0.35 seconds measures:

| Interpolation | Folded 1600-Hz amplitude | Retained 400-Hz amplitude |
| --- | ---: | ---: |
| Linear negative control | 0.132888379 | 0.140762128 |
| Sinc | 3.088e-9 | 0.140762104 |

The retained component matches an independent one-pole magnitude calculation
within 0.1%. The negative control must exceed 0.05 and sinc must stay below 1e-5
at the folded frequency. These are measurements at one coherent bin, not a
broadband rejection specification or proof of arbitrary modulation safety.

A native audit recomputes all 20 audition hashes per target and confirms every
WAV is byte-identical across targets. Sources, reports and checked logs remain
ignored under `build/loop-modulation-{study,stable,trunk}/`.
`build/loop-modulation-study/study.lpr` runs as `study OUTPUT_PREFIX`; its
`summary.lpr` takes the three `measured` prefixes, Win64 first. Flags are
`-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools`, with separate unit/executable directories.
These local studies use core units and authored signals, with no source recording
or companion dependency.

This supplies scoped sample/automation evidence to
[FUND-QUALITY](MILESTONES.md#fund-quality). Discontinuous recorded loop endpoints,
arbitrary fast automation and nonlinear sidebands remain outside acceptance.
Next connect FM/PM sideband evidence to the actual source/stream and bounded
downsampling path, then review the combined auditions and remaining limits.
No listener approval, extra percentage credit, Linux result or refreshed package
is implied.

## Harmonic-limited wavetable construction

`TWavetableSourceFactory.Create(SineCoefficients, CosineCoefficients, TableSize)`
precomputes owning periodic tables. Coefficient index zero means harmonic one.
Missing coefficients are zero; there is no DC parameter.
There must be 1..128 harmonics, each finite coefficient with magnitude <=16.
TableSize is a power of two from 256 through 8192 (default 2048), and the
harmonic count must remain strictly below table Nyquist.

Construction sums the specified sine/cosine harmonics on an exact phase grid.
Tables have successively halved power-of-two harmonic caps, ending in an empty
zero table. At most nine tables and about 2.1 million harmonic/grid positions
are needed within the declared bounds. Input coefficient arrays are not retained.

At played frequency f > 0, define harmonic budget B = outputNyquist/f.
Choose the largest stored cap H <= B, then blend its table with the H/2 table
using weight `clamp(B/H - 1, 0, 1)` for the H table.
At low frequency the fullest table is retained; at zero the phase is held.
This crossfade meets the neighboring selection continuously and attenuates
upper partials conservatively before Nyquist, including the fundamental near
output Nyquist. Table reads use periodic linear interpolation and a continuous
phase accumulator.

The approach uses periodic lookup as described by Julius O. Smith III,
[*Wavetable Synthesis*](https://www.dsprelated.com/freebooks/sasp/Wavetable_Synthesis.html).
The construction limits and cap-crossfade policy are Pythian choices.
No external wavetable implementation was copied.

Stored harmonic limits do not eliminate interpolation images or modulation
sidebands. Coherent-grid measurements are specific evidence, not an ideal
band-limit guarantee. Automatic cycle detection remains an extension.

### Measured WAV-cycle recipes

`AnalyzeWavetableCycle(Clip, StartFrame, FrameCount, Channel, Harmonics)` returns
a detached `TWavetableCycleRecipe` with sine/cosine coefficients and measured
mean. The caller declares one half-open period of 3..8192 frames in one channel.
The selected frame count need not be a power of two. Harmonics must be 1..128
and strictly below the cycle's Nyquist (`2*Harmonics < FrameCount`). Pass the
returned coefficient arrays to the existing `TWavetableSourceFactory.Create`.
The source clip may then be released, and the factory owns its playback tables.

Analysis subtracts the measured mean, then projects each harmonic onto sine and
cosine with coefficient scale `2/FrameCount`. Index zero is harmonic one; signed
coefficients retain the selected starting phase. No window, normalization,
endpoint duplication or automatic phase alignment is applied. DC is reported
separately and excluded from playback. Coefficients exceeding the factory's
magnitude limit 16 reject without replacing the accepted recipe. Work is bounded
to 8192*128 harmonic/sample positions before ordinary table construction.

This is a caller-selected periodic waveform recipe. A poorly selected period
can introduce seam harmonics, and one cycle does not capture an instrument's
attack, noise or evolving timbre. It does not establish automatic timbre/style
extraction. Existing envelopes, instruments and pitch-dependent harmonic caps
remain independent reusable controls.

The native source demo reads only the selected frames through the bounded WAV
reader and reports the complete input SHA256 and selected coordinates:

```text
pythian.sources.demo OUTPUT.wav --cycle INPUT.wav START_FRAME FRAME_COUNT CHANNEL HARMONICS
pythian.sources.demo OUTPUT.wav --cycle INPUT.wav START_FRAME FRAME_COUNT CHANNEL HARMONICS --midi NOTES.mid
```

The first command plays eight authored notes over four seconds. The second uses
strict native MIDI note admission and the exact PPQ clock, binding the measured
waveform to every note through the existing tone renderer. Sub-frame/zero-length
notes reject instead of disappearing. MIDI velocity is retained; release is zero
so tails do not spill outside gates. It reports MIDI identity and rendered counts.
The fixed listening gain does not normalize the measured waveform. These are
operator auditions, not additional persisted style formats or General MIDI patches.

Checked stable/development Win32 and stable Win64 runs pass non-power-of-two
cycle, stereo selection, phase/amplitude, DC, detached ownership and failure
preservation checks in the existing source fixture. Its controlled cycle produces
a four-second audition, and the generated changing-key/tempo MIDI renders all
45 notes in 252000 stereo frames at 48000 Hz. The cached CC0 VSCO 2 CE flute's
explicit approximate cycle (frame 5000, 100 frames, channel 0, 32 harmonics)
also voices the recorded flute/bassoon second blend: five notes / 23350 frames.
The source attribution and pitch accuracy limits remain in [recorded evidence](PITCH.md#recorded-instrument-evidence).
This unnormalized quiet selection peaks at approximately 0.01205 in that audition.

Five fixture/audition/default WAVs match across those three compiler targets;
the preceding default source demo retains its bytes. Invalid cycle admission
preserves the prior output. Evidence: `build/cycle-source-{stable,trunk,win64}/`,
including `checks.log`, `midi-listen.log`, `recorded-listen.log` and stable
`replay.log`. The maintained recorded workflow passes on development Win32
(`build/cycle-source-trunk/recorded-workflow.log`, `recorded-status.log`), with
the same deferred bassoon-C pitch case. The normal build includes the controlled
cycle audition and generated-performance route. Full-suite/package refresh is
not claimed for this focused addition.

### Harmonic fitting across a WAV interval

`FitWavetableHarmonics(Clip, Start, Count, Channel, Harmonics, FrequencyHz)`
extends the same source unit and returns a detached `THarmonicFit`. Its recipe
feeds the existing wavetable factory or either endpoint of a waveform morph.
The caller supplies the fundamental; unlike cycle analysis, the selected interval
does not need an integer number of periods. No new serialized format is involved.

DC and sine/cosine coefficients are fitted jointly by streaming QR with Givens
rotations. Finite-window harmonics are not assumed orthogonal. This is a native
real harmonic least-squares model; the general projection principle is described
in Julius O. Smith's [sinusoidal amplitude and phase estimation](https://www.dsprelated.com/freebooks/sasp/Sinusoidal_Amplitude_Phase_Estimation.html).
No external implementation was copied. Phase zero is the interval's first frame;
the fitted constant is reported separately and excluded from the periodic source.

Bounds: 16..65536 frames, 1..128 harmonics strictly below source Nyquist, at least
four periods between the first and last samples, and more samples than fitted
terms. For `D = 2*Harmonics+1`, the work estimate `Count*(D*D+6*D)` must not exceed
134217728. The triangular factor uses `D*D` doubles; observations are consumed one
frame at a time. A diagonal at or below `sqrt(Count)*1e-8` rejects numerical rank
loss. Coefficient magnitudes must fit the existing factory limit of 16. Rejected
geometry, work, rank or coefficients preserve a previously assigned result.

The result includes measured AC RMS about the sample mean, full-interval residual
RMS against the fitted DC-plus-harmonics model, and their ratio. Constant input
has zero AC evidence and a defined ratio of zero; callers must check AC evidence
before admission. Noise, pitch drift, amplitude changes and omitted harmonics
contribute to residual. There is no automatic amplitude normalization, phase
alignment, envelope extraction or claim of an isolated instrument.

The native operator exposes both declared and measured frequency:

```text
pythian.sources.demo OUTPUT.wav --harmonics INPUT.wav START COUNT CHANNEL HARMONICS HZ|auto[:PITCH_FRAMES] MAX_RELATIVE_ERROR [--midi NOTES.mid]
```

`auto` uses the existing pitch estimator's default policy over `COUNT` frames;
`auto:4851` independently selects 4851 pitch frames starting at the same `START`.
Pitch windows retain their own 16..8192 bounds and minimum-frequency geometry.
The reader loads only the larger of the two intervals, rejecting missing coverage.
The fit itself uses exactly `COUNT` frames. Logs retain the source hash, frequency
measurement width/difference, fit diagnostics, coordinates, coefficients and MIDI
hash. AC RMS at or below the default pitch silence threshold, or error above the
caller-selected 0..1 limit, rejects before replacing audio. Output uses the existing
eight-note audition or every admitted MIDI note, with independent authored envelope
and gain. The frequency window and stationary fit window are separate controls.

Checked stable/development Win32 and stable Win64 source fixtures recover known
signed coefficients/DC over fractional periods, expose omitted harmonics and a
wrong fundamental through residual, reject rank/work/Nyquist failures, and verify
detached playback at another pitch. The controlled automatic estimate is
213.716224 Hz for an authored 213.7-Hz signal, with relative fit error 0.00838004.
Its generated changing-key/tempo audition retains 45 notes / 252000 stereo frames.

All six cached CC0 VSCO 2 CE staccato recordings fail the initial common policy
(start 5000, count 4851, channel 0, 32 harmonics, automatic frequency, error limit
0.25). Relative errors are flute A 0.7533, flute C 0.7414, clarinet D 0.8816,
clarinet A-sharp 0.7530, bassoon C 0.3371 and bassoon A 0.5695. These failures are
retained; the cutoff was not widened to admit them. Additional shorter flute
selections also fail. The selected bassoon C interval of 1500 frames at the same
start, with independent 4851-frame frequency measurement, fits at 130.916145 Hz
and relative error 0.04780484. This selection followed inspection of the failures;
it is not a blind-corpus success rate or an automatic stable-region selector.

That bassoon recipe voices the saved recorded second blend's five notes / 21600
stereo frames at 48000 Hz. The maintained recorded workflow verifies the actual
saved style, WFC voices, MIDI and independent controls before the timbre audition.
Source attribution remains in [recorded evidence](PITCH.md#recorded-instrument-evidence).
The original audition uses the harmonic recipe as an explicit rendering input.
The subsequent [saved timbre dimension](WAVE-STYLE.md#stationary-timbre-and-rendering)
retains these measurements and independent weights through repeated style blends.
It transfers stationary harmonic magnitudes, without a complete attack/decay model.

Evidence: `build/harmonic-fit-{stable,trunk,win64}/`, especially `source-run.log`,
`demo-run.log`, `controlled-midi.log` and `bassoon-auto.log`. Stable
`recorded-workflow.log` / `maintained-status.log` cover the maintained integration.
`replay.log` verifies 14 cross-target WAV comparisons plus two unchanged preceding
source auditions; `rejection-status.log` records preservation of accepted output.
Listening artifacts are `duration-harmonic-voice.wav` and `bassoon-auto.wav`.
Full-build/source ZIP evidence remains the preceding delivery checkpoint.

<a id="phase-harmonic-fitting"></a>
### Harmonic fitting along a declared phase path

`FitWavetableHarmonicsByPhase(Clip, Start, Channel, Harmonics, PhaseCycles)`
fits constant DC and harmonic coefficients while allowing the fundamental to
change within the interval. This shares the preceding streaming QR engine;
the stationary API retains its original frequency-based basis. Use this entry
point when the caller has an explicit phase path, such as a controlled glide or
vibrato. It does not estimate pitch or recover a phase path from audio.

Supply one finite, unwrapped fundamental phase value **in cycles for each source sample**.
The first entry must be zero, every entry must strictly increase, and the last
must be at least four cycles. Each adjacent increment must be strictly below
`0.5 / Harmonics`. The selected frame count is the array length. The preceding
16..65536 sample, 1..128 harmonic, independent-term, QR-work, rank and coefficient
bounds still apply. `PhaseHarmonicFitWork` exposes geometry/work admission before
fitting; it cannot establish numerical rank without the fit. These sampled bounds
do not prove the continuous-time bandwidth of an arbitrary modulated waveform.

The returned `THarmonicPhaseFit` owns a detached `Recipe` and reports `AcRms`,
`ResidualRms` and `RelativeError` with the same meaning as the stationary fit.
`MinimumHz` and `MaximumHz` are the minimum and maximum **adjacent phase increment
times sample rate**, not an inferred instantaneous-frequency confidence interval.
Constant input has zero AC evidence; a zero relative error does not admit a note.
Invalid source scope, phase geometry, work, rank or coefficients preserve a
previously assigned fit.

The clip and phase array are borrowed for the synchronous call. The result does
not retain the phase array, source identity, coordinates or measurement policy.
An evidence-owning caller must retain those separately for reproducibility.
`THarmonicPhaseFit` is deliberately distinct from stationary `THarmonicFit`:
do not relabel it with one nominal frequency and store it as stationary evidence
in a saved style. Automatic phase admission and persistence of that evidence
belong to [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre); no format was added.

The detached sine/cosine recipe feeds the existing `TWavetableSourceFactory`.
The source begins at phase zero; driving each frame with the next adjacent phase
increment times output rate reproduces the declared path at that rate. The fitted
DC remains separate and is excluded by the periodic source. Constant coefficients
along a moving phase are distinct from [spectral trajectories](#spectral-trajectory-checkpoint),
which explicitly vary the harmonic shape over time.

Checked stable/development Win32 and stable Win64 source fixtures recover known
coefficients from four 6400-frame, 8-kHz controls: constant 220 Hz, a 180..340-Hz
linear glide, 5-Hz vibrato spanning 215..225 Hz, and the vibrato at 0.001 amplitude
scale with unchanged DC. The weak fundamental, stronger second harmonic and
cosine third harmonic recover within `1e-7` absolute error. Relative fit error is
about `2.7e-8` for the first three and `1.85e-5` for the quiet control, where Single
sample precision matters. A stationary 220-Hz fit has relative error 0.9959 on
the glide and 0.9479 on vibrato; these controlled results explain why drift can
invalidate a stationary fit without implying the wrong register.

The fixture also checks constant-path parity, detached results, malformed phases,
source/channel bounds, four-cycle admission, rank loss and work rejection. Actual
wavetable playback follows the known phase path within `1e-5` absolute sample
error. All six fixture WAVs match across the three targets; heap tracing reports
zero leaks. Evidence: `build/phase-harmonic-{stable,trunk,win64}/`. The optional
third source-fixture argument writes `PREFIX-0.wav` through `PREFIX-3.wav` for
these four controls, without changing the first two existing output arguments.

Affected saved-style tests pass on checked stable Win64, including stationary
fits, saved spectral trajectories, envelopes, independent instrument controls and
second blends. The recorded trajectory reblend still produces five notes / 19845
frames through actual WFC, with WAV hash
`29c8d382d02fdba4928c313f8345389ffcd5d21daa22525846c7885d6ba34d75`.
These consumer checks report zero leaks under `build/phase-harmonic-consumers/`.
They establish compatibility of the shared fitter and sounding consumer, not
recorded changing-phase admission, listening approval or refreshed source packages.

A subsequent [development phase-integration probe](PHRASE-EVALUATION.md#changing-phase-checkpoint)
supplies per-window candidate frequencies from recordings. It improves many local
fits but retains register/coherence counterexamples and additional cycle-coverage
failures. That evidence does not promote an automatic phase provider into this
core API or the saved style contract.

### Controlled waveform morphing

`TWavetableSourceFactory.CreateMorph(FromRecipe, ToRecipe, Curve, TableSize)`
owns two harmonic-limited table banks and a clone of the existing immutable
automation curve. The curve must stay in 0..1: zero selects the first waveform,
one selects the second, and intermediate values linearly interpolate their
amplitudes. Recipes may have different harmonic counts; each bank applies its
own existing pitch-dependent harmonic cap before interpolation. Recipe means
remain excluded. Input arrays and the original curve may be released or changed
after construction.

Each playback instance shares one phase between its two banks and evaluates
the curve at its own zero-based output frame. Reset restores both clocks.
Note-off does not stop the curve; amplitude release remains the renderer's
independent envelope. Points, held controls and generated LFO curves all use
the existing automation contract. This is note-relative output timing, not
inferred musical-time modulation. The factory remains alive while its sources
play, as for other source factories.

Construction bounds remain 128 harmonics and 8192 table frames per bank. Playback
allocates no per-frame storage. Work admission includes both banks and control
evaluation. Invalid frequency or exhausted Int64 control clock rejects before
advancing either phase or control. Sources remain periodic; no natural sample
exhaustion is introduced. The ordinary single-bank constructor retains its output.

The source demo accepts two explicitly selected WAV cycles and an existing MIDI:

```text
pythian.sources.demo OUTPUT.wav --morph-cycle FROM.wav START COUNT CHANNEL HARMONICS TO.wav START COUNT CHANNEL HARMONICS MORPH_FRAMES --midi NOTES.mid
```

It moves from the first waveform to the second over the positive number of
output frames specified, then holds the second. Every note starts its own curve.
Output is 48000 Hz; 4800 frames means 100 ms. The report records both complete
source hashes, selected coordinates and measured DC, plus MIDI identity and note
count. Existing strict MIDI admission and zero release preserve all note gates.
Invalid source admission leaves an existing output intact.

This supports blending measured waveform content beneath independent musical
passes. Selected cycles retain their relative phases and original amplitudes;
cancellation or unequal loudness is possible. There is no automatic phase
alignment, normalization, spectral-envelope matching or inferred timbre trajectory.
Rapid control modulation can add sidebands despite each bank's harmonic limits.
This factory and its control are runtime definitions; no new persisted format
or claim of learned timbre in saved PYS profiles is introduced.

Existing native source fixtures check independent capped-source interpolation
with differing harmonic counts and changing pitch, detached recipe/curve ownership,
reset and independent instances, note-off behavior, cost admission and invalid
control/pitch preservation. Checked stable/development Win32 and stable Win64
also render identical controlled and recorded morph WAVs. The controlled output
uses the changing-key/tempo WFC MIDI: 45 notes / 252000 stereo frames. The recorded
flute/bassoon second blend uses five notes / 23350 frames. Doubling the morph
duration changes audio while retaining the same MIDI. Default source and prior
single-cycle auditions keep their exact bytes.

The recorded morph uses cached attributed VSCO 2 CE sources: the existing flute
selection and bassoon A at frame 5000, 200 frames, channel 0, 32 harmonics. These
are approximate caller-declared periods. See [recorded provenance and accuracy](PITCH.md#recorded-instrument-evidence).
Evidence: `build/morph-cycle-{stable,trunk,win64}/`, including source/demo build
logs, `controlled-run.log`, `recorded-run.log` and stable `replay.log`.
The stable `recorded-passage.wav` also applies both acoustic waveforms to the
45-note changing-key/tempo passage (5.25 seconds, peak approximately 0.05890);
`passage-run.log` and `passage-metrics.json` retain its inputs and measurements.
The maintained build includes the controlled morph, and the recorded workflow
includes the two-recording audition. Operator listening quality remains unassessed.
The full checked stable Win32 workflow passes (`full-build.log`, `full-status.log`);
its morph output matches the focused audition. The other targets have the
focused checks above, not fresh full-suite runs. Existing source ZIPs precede
this API addition.

<a id="spectral-trajectory-checkpoint"></a>
## Measured spectral trajectories — 2026-09-19

`TWavetableSourceFactory.CreateTrajectory(Recipes, Position, TableSize)` owns
2..32 harmonic table banks and clones the note-relative automation curve.
Position values range from zero to `Length(Recipes)-1`; a fractional index mixes
the adjacent banks with shared oscillator phase. Each bank keeps its own harmonic
caps. Only two banks are sampled per frame, including at the final endpoint.
The source reserves `14 + Position.Depth` logical frame work for three or more
banks; the existing two-bank morph retains its prior reservation and PCM behavior.
The factory must outlive its sources. Reset restores both phase and curve clock;
note-off leaves the trajectory clock running beneath the voice's release envelope.

Control frames use the eventual output sample rate. Callers supply compatible
phases and explicit timing, including held endpoints, reversals or jumps. Rapid
motion or discontinuous control can add sidebands/clicks; harmonic caps alone do
not guarantee a band-limited modulated result. No implicit gate stretching, phase
alignment, normalization or inference is performed. Construction preflights the
sum of table-frame/harmonic evaluations against 16777216 before building banks;
each recipe retains the existing coefficient and table-size limits.

The maintained source consumer exposes a bounded measured path:

```text
pythian.sources.demo OUTPUT.wav --trajectory INPUT.wav START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_RELATIVE_ERROR [--midi NOTES.mid]
```

Coordinates are source frames. The selected span is at most 65536 frames, with
2..32 complete windows and cumulative fitting work at most 134217728. Every
window uses the caller's same fixed fundamental, must contain four periods, and
must pass strict harmonic Nyquist, AC RMS at least 0.00001 and the explicit
relative-residual limit. Source hash, selection and per-window measurements are
printed before synthesis. Failed admission preserves an existing output; source
and output paths must differ. The generated clip is checked for PCM overload.

Each local fit's sine/cosine pair is rotated into coordinates referenced to the
selection's first frame. This removes the known phase shift between window
origins under the declared fixed pitch; it does not estimate pitch drift or align
unrelated recordings. Linear trajectory points lie at the window centers,
converted to 48000-Hz output frames by floor division. The nearest recipe holds
outside that interval. With no MIDI, three notes play at the declared frequency,
six semitones higher and an octave higher. Optional MIDI preserves the existing
strict note/gate import path. Time progression is independent of played pitch.

The coefficients retain measured amplitude; DC is omitted. This demonstration
does not isolate timbre from loudness, infer note boundaries, separate mixtures
or save a learned trajectory in a style. Applying another measured amplitude
envelope needs an explicit factoring policy to avoid counting dynamics twice.
That provider work is tracked by [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre).

Existing source fixtures now check three-bank analytic harmonics, knot crossings,
reverse jumps, detached inputs, reset/independent voices, rejected pitch without
clock movement, and invalid recipe/control/work admission. A separate native
audit authors three known spectra in non-phase-aligned WAV windows. The consumer's
fitted trajectory agrees with synthesis from those original coefficients within
one PCM16 unit (limit two); this checks the window-origin rotation independently
of the fitting path. Direct and 127/2048-frame streamed renders match every Single
sample over 58548 stereo frames; one-less-than-required work rejects.

The attributed bassoon C source already used in [recorded pitch](PITCH.md#recorded-instrument-evidence)
supplies three 272-frame windows, starts 907/1179/1451 at 8000 Hz, channel zero,
24 harmonics and declared 130.8 Hz. Residual/AC ratios are 0.058033, 0.115755 and
0.186260 against the unchanged 0.25 limit; AC RMS falls from 0.082170 to 0.040672.
The three-note audition has 28128 frames. Applying those spectra to the existing
45-note WFC-generated changing-key/tempo MIDI produces 252000 frames (5.25 seconds),
peak 0.072077. MIDI supplies the musical structure; the WAV windows supply the
evolving periodic content. This is rendering integration, not learned phrase or
saved-style acceptance.

Checked stable Win32/Win64 and development Win32 pass the source fixture, native
audit and consumer cases. The following WAV hashes match across all three:

| Audition | SHA-256 |
| --- | --- |
| Controlled trajectory | `ee4830ecbcab3e981f3a174a06877aae5f3a26847203514dad281dddffb6f6a0` |
| Recorded three-note trajectory | `3a17fcdc3f17a6cb38583c8cc3fb9bb577fb1cef7c8de4cc80ed85c21b5bc1af` |
| Recorded spectra with generated MIDI | `25b95af36a8c3b76f2d59b773542bbcd4d645f064a56c118bb51175915bbd869` |

The earlier controlled morph retains hash
`6125cc1471f6d0e241f75459c396684cddc32c1f277dea05eddb0bfdd3ccc91a`.
The existing saved-style/instrument fixture also passes on stable Win64; it does
not persist the new trajectory. Five failed consumer admissions preserve prior
WAV bytes, and an input/output alias rejects. The maintained build includes a
three-window smoke using its existing generated harmonic source; that exact
invocation passes on all three targets. No full-suite rerun is claimed here.

Evidence is ignored under `build/timbre-trajectory-{win64,stable,trunk}/`, including
`source-run.log`, `control-run.log`, `audit-run.log`, `stream-run.log`, recorded/MIDI
logs and WAVs. The independent native `audit.lpr` is in the Win64 directory;
compile it and the maintained fixture/consumer with `-B -Sa -Cr -Co -Ci -gl`,
`-Fusrc` and target-specific output directories. Run `audit PREFIX` to prepare
the control/reference, then `audit EXPECTED.wav ACTUAL.wav` to compare. Source,
consumer and audit builds have no warnings; the companion fixture retains its
existing dependency warnings. Listening, broader varying-pitch measurements,
saved trajectories and refreshed source packages remain open. No new format
branch, fixture count or percentage allocation is introduced.

<a id="magnitude-trajectory-checkpoint"></a>
## Independent spectral shape and modeled level — 2026-09-19

`FactorWavetableMagnitudes(Recipe)` returns a detached, nonnegative sine magnitude
recipe with unit cycle RMS and the original periodic model's cycle RMS. For
harmonic coefficients `s[h]`, `c[h]`, that level is
`sqrt(sum(s[h]^2 + c[h]^2) / 2)`. This is full-period harmonic energy, not the
measured window's AC RMS or perceptual loudness. Recorded phase and DC are absent
from the shape; the caller retains the original fit and its residual separately.
Scaling before squaring protects tiny representable inputs. Empty, silent,
nonfinite or out-of-contract recipes reject.

`TWavetableSourceFactory.CreateMagnitudeTrajectory(Recipes, Position, TargetRms,
TableSize)` factors 2..32 recipes and renders their evolving shape at an explicit
target full-model cycle RMS in `(0,16]`. Ownership, position controls and table
construction limits match `CreateTrajectory`. The raw constructor continues to
preserve signed coefficients, phase and level exactly as before.

Normalizing only the knots is insufficient. At a fixed halfway position between
two different single-harmonic shapes, linear interpolation has half the intended
mean-square level. The magnitude source corrects this throughout each segment,
using the precomputed full-period correlation of adjacent unit shapes:
`gain = TargetRms / sqrt((1-u)^2 + u^2 + 2*u*(1-u)*correlation)`.
Nonnegative shapes keep correlation in `[0,1]`, so the denominator cannot fall
below `sqrt(1/2)`. This avoids amplification near phase cancellation. Runtime
still reads two banks; correction reserves eight additional logical work units.

Normalization uses the complete model before pitch caps. It does not restore
energy removed by Nyquist attenuation, filters or envelopes. Cycle RMS at a
frozen control position is the contract; rapid motion can introduce modulation
sidebands and does not guarantee constant finite-window RMS or equal perceived
loudness. Independent gain/envelope controls can apply the retained modeled level
or another dynamic shape. No measured envelope is applied automatically.

The maintained consumer adds:

```text
pythian.sources.demo OUTPUT.wav --trajectory-shape INPUT.wav START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_RELATIVE_ERROR TARGET_RMS [--midi NOTES.mid]
```

It keeps the prior explicit-window/fixed-pitch admission and reports both measured
AC RMS and modeled cycle RMS at every knot. Magnitude mode discards recording
phase explicitly, so it needs no rotation between window origins. Controls use
the same output-frame window centers. Output headroom is checked after rendering;
the target is a source-model setting, not an output limiter or automatic gain.

The existing source fixture independently verifies signed/phase/DC factoring,
detached ownership, a `1e-200` coefficient, analytic moving shapes, shared-partial
correlation and silence/target rejection. A coherent midpoint control measures
0.2 RMS with correction versus `0.2/sqrt(2)` with normalized knots alone. At high
pitch the omitted harmonic still reduces RMS to `0.2/sqrt(2)`; it is not boosted
back. These are scoped numerical checks, not listener approval.

A native audit starts with three known spectra and a second WAV that independently
changes each segment's gain and carrier phase. Both measured paths match synthesis
from the original magnitude shapes within one PCM16 unit (limit two); they also
differ from each other by at most one unit. This is not an assertion of identical
input-variant bytes. Direct rendering and reads of 127/2048 frames replay all
58548 stereo frames exactly. The controlled stream's peak logical frame work is
39; a reservation of 38 rejects.

The previous bassoon windows retain their same fit admission. Their modeled
cycle RMS is 0.080160 / 0.063796 / 0.040018, distinct from finite-window AC RMS.
At target 0.08, the shape source renders three notes and the same 45-note,
252000-frame generated MIDI passage. The latter peaks at 0.099277. This shows
explicit timbre/level control through generation, not learned note ownership or
saved trajectory blending.

Checked stable Win32/Win64 and development Win32 pass the source fixture, audit,
consumer and exact maintained smoke invocation. Four new auditions match bytes
across targets: original control, gain/phase-variant control, recorded three-note
shape and recorded MIDI shape. The recorded MIDI SHA-256 is
`6d32b124a21c7aeb07d8d6e9a621654c0137d3c3d24854b71ee1472cee3878c4`;
the three-note shape is
`e64e4d2e0dd867706861cb3f2fbfecbefdfca06078d60da7a94eb3ede68be3f5`.
The prior raw three-note trajectory retains hash
`3a17fcdc3f17a6cb38583c8cc3fb9bb577fb1cef7c8de4cc80ed85c21b5bc1af`.
Zero/out-of-range/nonfinite target and rendered overload reject without replacing
an accepted WAV. Source/output aliases also reject.

Evidence, native audit, checked build/run logs and auditions are ignored under
`build/timbre-shape-{win64,stable,trunk}/`. Compile the maintained source fixture,
source consumer and `build/timbre-shape-win64/audit.lpr` with
`-B -Sa -Cr -Co -Ci -gl -Fusrc` and separate target output paths. The audit commands
remain `audit PREFIX` and `audit EXPECTED.wav ACTUAL.wav`. Builds have no warnings;
all runs are terminal. No new unit/fixture, format branch, full-suite or packaging
rerun, held-out result, listening approval or percentage credit is claimed.
The subsequent [saved-provider checkpoint](WAVE-STYLE.md#saved-spectral-trajectories)
preserves raw fits, timing and this explicit policy in the current style contract,
with repeated blends and independent envelope/timbre edits. Automatic varying-pitch
admission, event ownership and recorded/listening acceptance remain unresolved
under [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre).

## Precursor disposition and remaining lifecycle work

Phanes `phanes.audio.synth.pas` allocates a source for each scheduled note,
shares a one-second seeded noise buffer, and disconnects source/filter/gain/pan
nodes on end. The native source/factory distinction preserves reusable sample
data with independent playback, explicit natural end, and deterministic
per-note cleanup through caller ownership and renderer try/finally.

The browser's source-node cleanup is represented by Pascal object lifetime;
Pythian does not claim Web Audio sample parity. The existing seeded recurrence
is checked through the waveform source, and the sample factory can represent a
finite shared buffer. The new loop modes are Pythian extensions.

Phanes's active versus scheduled counts, voice limit and future-music cancellation
now have native contracts in [scheduled synthesis](SCHEDULING.md), sharing the
same per-note renderer. Music/effects buses and echo tails are implemented by
[bus routing](BUSES.md).
Reusable gain smoothing and master compression are now implemented in
[dynamics/effects](EFFECTS.md). Its source-end timing includes application
margins; those margins are not hardcoded into this library contract.
Offline rendering and scheduled playback share source/filter/envelope state
handling. Device callback integration and continuous streaming conversion
remain separate follow-on work.

## Verification and listening

Full build: `build/source-validation.log`, existing FPC 3.3.1 i386-win32
with `-B -Sa -Cr -Co -Ci -gl`. All 31 core units compile without vendor paths;
actual WFC checks, WAV learning and reconstruction also pass.
Final focused run: `build/source-focused-validation.log`, including direct
observation of exact note-off delivery and source destruction. One-shot
rate-conversion checks also pass in the full build.
No authored compiler warnings. Existing WFC unreachable-code warnings remain.

Checks cover seeded waveform parity, independent instances/reset, additive/FM
adapters, detached sample region after original destruction, stereo polarity,
fractional interpolation over loop boundaries, multi-wrap advancement,
idempotent sustain release, natural one-shot exhaustion, input/output rate
conversion, rejected pitch preserving position, periodic sinc filtering,
coefficient ownership, harmonic-cap analytic values, renderer stereo history,
note independence, release behavior, work rejection and output replay.
An independent probe source records three reads before a three-frame gate's
note-off and confirms destruction by the renderer while the factory remains alive.

At 32768 Hz with a 6000 Hz played pitch, the configured third harmonic would
fold from 18000 to 14768 Hz. The selected table omits it; a coherent 8192-frame
projection measures that alias amplitude at approximately 5.3e-11.
The permitted first/second harmonic values also match independent formulas.
This test uses exact table phase-grid positions.

The build emits `sources.wav` through `pythian.sources.demo OUTPUT.wav`:
five seconds, 240000 stereo frames at 48000 Hz. Each one-second section has two
notes, in order: polynomial saw, additive, phase modulation, wavetable,
stereo sampled percussion. All use the same tone renderer. The sample clip is
authored procedurally here; no external asset is required. The PM example uses
modest pitches/depth at its output rate and is not an oversampling demonstration.

WAV SHA256:
`1178a3df8b5f01b4f817c535a11e01f1a06b56a97a4855232bd62f01d9ee4760`.
Both PCM channel peaks are 0.3173522949; left/right RMS is
0.1013670086 / 0.1013633260. Measurements: `build/source-metrics.json`.
Legacy synthesis retains SHA256
`07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.
The user later heard the complete 0–5-second family demo and said it sounded
okay, without a fault time. This is bounded to the five authored sections;
other compiler/platform targets remain unverified for this demo.
