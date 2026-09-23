# Filters, dynamics and effect chains

[Home](../README.md) · [Sources](SOURCES.md) · [Modulation](MODULATION.md) ·
[Bus routing](BUSES.md) · [Work](WORK.md)

## Biquad filtering

`pythian.biquad` implements low-pass, high-pass, unity-center band-pass,
notch, all-pass, peaking EQ, low shelf and high shelf. `DesignBiquad` returns
normalized coefficients for
`y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]`.

`TBiquadSettings` contains Kind, FrequencyHz, Q and GainDb.
Frequency must lie from sampleRate*1e-5 through sampleRate*(0.5-1e-5), inclusive;
this reserves finite-precision margin near DC and Nyquist.
Q is 0.05..100, gain is -48..48 dB. Shelves use fixed slope S=1 and ignore Q;
gain affects peaking/shelves only. All fields still validate.
`DefaultBiquadSettings` is low-pass at 1800 Hz, Q=sqrt(1/2), zero EQ gain.

The coefficients follow Robert Bristow-Johnson's formulas in the W3C
[*Audio EQ Cookbook*](https://www.w3.org/TR/audio-eq-cookbook/).
Pythian independently implements the equations in Pascal, with its own bounds,
ownership and state handling. No external filter implementation was copied.

`TBiquadFilter.Create(SampleRate, Settings, Channels)` defaults to mono.
Use `Process` for mono or `ProcessStereo` for stereo.
Each channel has separate direct-form-I input/output history.
Both stereo candidates compute before either history commits.
`SetSettings` and `SetFrequency` preserve history on success; rejected settings
preserve coefficients and history. Reset clears both channels.

Normalized denominator coefficients must satisfy the strict real second-order
stability conditions `1+a1+a2>0`, `1-a1+a2>0`, `1-a2>0`.
These certify each static design, not arbitrary rapidly switched designs.
Input/output magnitude is bounded at 1e100 and must remain finite; rejected
processing preserves history. Resonance, automation and EQ boost can exceed
unity. Coefficient changes can click or create sidebands; no automatic
parameter smoothing or nonlinear saturation is inserted.

## Tone filtering

Set a voice initialized with `DefaultSynthVoice` to `FilterModel=vfmBiquad`.
Its `BiquadKind`, `BiquadQ`, `BiquadGainDb` and existing `CutoffHz`
select the design. Cutoff automation updates its frequency, retaining history.
The full automation extrema are checked against design bounds before rendering.

`vfmOnePole` remains the default and uses the existing `FilterKind`.
The shared source renderer supports either model and independent stereo history.
Rebuild consumers for the added voice fields. Default synthesis remains
byte-identical; no corpus/WFC serialization contract changes.

## Stereo dynamics

`TStereoCompressor` links channels by the maximum absolute input sample,
then applies one common gain. `ProcessSidechain` instead accepts a separate
nonnegative detector magnitude for ducking. It does not mix the sidechain into
the output. Every input validates before state commits.

For detector dB x, threshold T, ratio R and knee width W, let d=x-T and
s=1-1/R. Positive target reduction is:

| Region | Reduction in dB |
| --- | --- |
| d <= -W/2 | 0 |
| -W/2 < d < W/2, W > 0 | s*(d+W/2)^2/(2*W) |
| Above knee, or hard-knee compression region | s*d |

Detector magnitudes <=1e-15 use a -300 dB floor.
Attack is selected when target reduction exceeds the previous reduction;
otherwise release is selected. The one-pole recurrence is
`reduction = coefficient*previous + (1-coefficient)*target`, where
`coefficient = exp(-1/(sampleRate*timeSeconds))`.
Zero time is immediate; positive times below 1e-6 sample intervals round to
the same immediate coefficient. Output gain is
`10^((MakeupDb-reduction)/20)`.

Settings bounds are threshold -120..24 dB, ratio 1..100, knee 0..48 dB,
attack/release 0..60 seconds, and makeup -24..48 dB. Reset clears reduction.
Successful settings changes retain current reduction; rejected changes preserve
configuration and history. Input/output magnitude is bounded at 1e100.
`CompressorReductionDb` exposes the static curve for inspection.
`ReductionDb` reports smoothed reduction before makeup.

The feed-forward/log-domain design family is discussed by Giannoulis,
Massberg and Reiss in
[*Digital Dynamic Range Compressor Design—A Tutorial and Analysis*](https://aes2.org/publications/elibrary-page/?id=16354).
The specific peak detector, knee, smoothing and bounds above are Pythian's
documented policy, not a claim of exact reproduction of a published or browser
compressor implementation. No external compressor source was copied.

`DefaultCompressorSettings` retains Phanes's -14 dB threshold, 4:1 ratio,
5 ms attack and 150 ms release settings. Pythian chooses a 6 dB knee and
zero makeup. Times denote 63.2% one-pole response constants, not an arbitrary
settling percentage. Finite attack permits transient overshoot: the compressor
does not guarantee a peak ceiling.

`TStereoPeakLimiter` provides a separate zero-latency sample-peak ceiling.
Ceiling is -60..0 dBFS and release is 0..60 seconds.
Gain attacks immediately to the lesser of the required linked peak gain and
the recovered previous gain; recovery approaches unity exponentially in the
linear-gain domain. Reset restores unity gain. Both channels share gain,
including crossed in-place input/output calls.

This limiter has no lookahead, oversampling or intersample/true-peak guarantee.
It can distort strong transients. The ceiling applies to its floating output;
subsequent Single/PCM conversion rounds samples and can move a quantized peak
slightly above that numerical ceiling.

## Smoothed gain

`TGainSmoother` preserves Phanes's general target-gain behavior without a
device clock. Construct it with sample rate, initial gain and time constant;
targets are finite gains in 0..16, time is 0..60 seconds.
`SetTarget` retains the current gain; `Next` advances one sample interval
toward the target. Reset restores initial gain and initial target.

Phanes uses 35 ms for music gain and 15 ms for effects gain. Those choices can
now use one native primitive. The first Next after a target change represents
one elapsed sample interval; no Web Audio scheduling/sample-parity claim is made.

## Owning effect chains

`TEffectChain` is a serial stereo processor at one fixed sample rate.
It accepts up to 32 effects. `Add` takes ownership only on success, rejects
already-owned effects, and checks matching rate and a positive bounded frame cost.
Do not free effects after transferring them to a chain. Keep any retained
configuration reference alive only as long as the chain owns that effect.

Built-in adapters are `TBiquadEffect`, `TCompressorEffect`,
`TLimiterEffect` and `TGainEffect`. A custom `TAudioEffect` implements
Reset, Process and a stable FrameCost. Calls/configuration changes belong between
frames on one thread; the chain rejects recursive Add/Reset/Process calls.

Additional native stages include `TEchoEffect` for filtered feedback and
[`TModulatedDelayEffect`](MODULATED-DELAY.md) for fractional stereo delay.
The latter uses owned automation curves and shares its delay-history primitive
with the fixed native delay; chorus/flanger settings remain caller policies.

`Process` commits caller outputs only after all stages succeed.
If a stage fails, earlier stages may already have advanced: the chain becomes
Failed and refuses further processing until Reset succeeds for every stage.
Removing the original error condition alone does not make the chain reusable.
Invalid input caught before stages does not poison it. Reset restores each
stage's initial history; gain target commands must be reapplied as needed.

`RenderEffectClip(Source, Chain, TailFrames=0)` borrows both objects and
returns owned stereo output. Mono input is duplicated to the two channels.
It continues chain history instead of resetting it. Consecutive clips therefore
support continuous processing. Explicit tail frames feed zeros after the source;
there is no automatic IIR-tail or loudness normalization.

Preflight admits at most 64 million scalar output samples and 200 million
weighted frame visits before allocation/processing. A chain's weight is one
plus its stage weights (two for each biquad/compressor/limiter/gain stage,
six for filtered echo; modulated delay uses six plus both control-curve depths;
[stereo reverb](REVERB.md) uses forty for its parallel combs, diffusers and mix).
Format/size/work rejection preserves input and chain state.
Processing or output-construction failure after processing starts poisons the
chain; output overflow preserves the caller's previous clip assignment.
The serial chain also supplies each bus's processing path in the
[ordered bus graph](BUSES.md).

## Evidence and listening

Full build: `build/effects-validation.log`, existing FPC 3.3.1 i386-win32,
checked flags `-B -Sa -Cr -Co -Ci -gl`. All 34 core units compile without
vendor paths, and actual WFC learning/reconstruction checks pass.
Final failure/overflow/in-place checks: `build/effects-focused-validation.log`.
Final demo compile/render: `build/effects-demo.log`.
No authored warnings; existing WFC unreachable-code warnings remain.

For 8000 Hz sampling, 1000 Hz filter center, Q=sqrt(1/2) and +12 dB EQ gain,
all eight center-response measurements agree with independent expected values
within 1e-9:

| Filter | Center magnitude |
| --- | ---: |
| Low/high-pass | 0.7071067812 |
| Band/all-pass | 1 |
| Notch | 0 |
| Peaking | 3.9810717055 |
| Low/high shelf | 1.9952623150 |

Other checks establish DC and Nyquist gains for every type, an independent
quarter-rate impulse recurrence, reciprocal peaking boost/cut identity,
stereo/settings rejection preserving histories, and biquad use by the tone
renderer. Compressor fixtures cover static slope, knee endpoints/midpoint,
linked stereo, external sidechain, exact time-constant responses and invalid
input preservation. Limiter fixtures cover transient sample ceilings, gain
recovery and in-place channel output. Gain retargeting retains current state.

Chain fixtures cover ownership rejection, downstream poisoning, refusal before
Reset, whole-versus-split-clip sample identity with explicit tails, and Single
overflow preserving caller output. These are focused contract/signal checks,
not listening approval, cross-platform parity, a true-peak certification or
general switched-filter stability proof.

`pythian.effects.demo OUTPUT.wav` produces six seconds of stereo at 48000 Hz:
a three-second phrase with per-note resonant biquads, followed by a processed
repeat. The repeat uses smoothed gain, high-pass, high shelf, linked compression
and a -1 dB sample limiter. The comparison is **not loudness matched**.

| Left-channel float measurement | Dry | Processed |
| --- | ---: | ---: |
| Peak | 0.657144606 | 0.891250908 |
| RMS | 0.073900431 | 0.168556376 |

Final `effects.wav` has 288000 frames and SHA256
`b70a06ffa11df7fc4d146c19d6b5296fd4e45d5832d880c9073ee35c02d77db1`.
PCM peak in each channel is 0.8912658691 after quantization.
Combined-file metrics are in `build/effects-metrics.json`.
The later [bounded stereo-speaker review](SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
judged this complete dry/processed example good at its declared settings.
Legacy synthesis retains SHA256
`07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.

The later [bus checkpoint](BUSES.md) extracts Phanes's music/echo/effects
routing and filtered feedback delay. The [scheduler](SCHEDULING.md) now supplies
voice limits, future cancellation and replacement with committed voices/tails
preserved. [Continuous-history rate conversion](DSP.md#continuous-conversion) is
also implemented and checked.
Gate/expander and lookahead/true-peak dynamics are
additional extensions. The subsequent [Phanes removal audit](REFERENCE-REMOVAL.md)
has passed; extracted implementations and notices remain.
