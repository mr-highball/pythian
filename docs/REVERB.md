# Stereo reverberation

[Home](../README.md) · [Effects](EFFECTS.md) · [Delay storage](MODULATED-DELAY.md) ·
[Provenance](PROVENANCE.md) · [Work](WORK.md)

`TReverbEffect` in [pythian.reverb](../src/pythian.reverb.pas) provides a native
stereo reverberator through the existing effect-chain and bus interfaces. It owns
four parallel damped feedback combs and two serial allpass diffusers per channel.
All delay histories reuse `TFractionalDelayLine`; there is no second renderer
or external effect dependency.

## Controls

`DefaultReverbSettings(SampleRate)` supplies an authored starting point.
Construct `TReverbEffect.Create(SampleRate, Settings)` and transfer it to an
owning `TEffectChain.Add`, or process it directly and free it yourself.
Settings are copied at construction, with no subsequent mutation API.

| Setting | Meaning and limits |
| --- | --- |
| `CombFrames[Channel, Index]` | Four independent integer delays per channel; 1..max(1, sampleRate div 2) |
| `DiffuserFrames[Channel, Index]` | Two independent integer delays per channel, same bound |
| `DecaySeconds` | Nominal undamped-comb 60 dB decay target, 0.05..30 seconds; default 1.5 |
| `Damping` | One-pole feedback coefficient, 0..0.99; default 0.35. Higher values attenuate high-frequency feedback more |
| `Diffusion` | Allpass feedback coefficient, -0.9..0.9; default 0.6 |
| `DryGain`, `WetGain` | Independent linear gains, each 0..16; defaults 1 and 0.3 |
| `Width` | Wet-output mix, 0..1; default 1. Zero gives equal wet channels; one preserves separate channel outputs |

All scalar settings must be finite. The sample-rate contract remains 1..384000.
Default left comb delays are 29.7, 37.1, 41.1 and 43.7 ms; the right adds 1.3 ms.
Left diffusers are 5.1 and 1.7 ms; the right adds 0.4 ms. Each is rounded to the
nearest integer frame with a minimum of one. Very low rates can collapse distinct
delays; these are starting settings, not perceptual quality guarantees.

Channels have independent input excitation and feedback histories. Stereo input
is not summed before processing. Width cross-mixes the finished wet signals:
own-channel weight `(1 + width)/2`, opposite-channel weight `(1 - width)/2`.
Dry channels remain separate. With width one, a left-only input has no right
wet output. The effect-chain mono-input duplication remains unchanged.

## Signal and state contract

For a comb delay `M`, feedback is `f = 10^(-3*M/(sampleRate*DecaySeconds))`.
Read delayed input `q`, compute damping state `s = (1-d)*q + d*sPrevious`,
then store `input + f*s`. The four delayed outputs are averaged.
For each diffuser, read delayed state `q`, compute `v = input + g*q`,
emit `q - g*v`, and store `v`. At diffusion zero a diffuser is a pure delay.
The serial allpass stages add their own tail; damping changes the comb decay
by frequency. The requested decay is not an exact measured RT60 for the complete
network or a promise to reproduce a physical room.

This follows the established parallel-comb/serial-allpass family described in
Julius O. Smith's [Schroeder reverberators](https://www.dsprelated.com/freebooks/pasp/Schroeder_Reverberators.html).
Feedback damping uses the unity-DC one-pole described in his
[lowpass-feedback comb treatment](https://www.dsprelated.com/freebooks/pasp/Lowpass_Feedback_Comb_Filter.html).
The implementation uses true Schroeder allpasses, not Freeverb's approximate
diffuser. The code, stereo policy and starting parameters are authored here;
no Freeverb/STK source or preset tables are copied.

Per-frame processing allocates no memory. All candidate states and both outputs
are validated before any delay advances. Direct rejection preserves both outputs
and histories, so a valid frame can be retried. Inputs, intermediate states and
outputs must be finite with magnitude at most `MaximumDynamicsMagnitude`
(1e100). In-place input/output variables are supported. There are no callbacks;
callers serialize access. An enclosing chain still follows its own poisoned
state contract if an effect fails after earlier stages have advanced.

Constructor allocation is bounded to twelve delay buffers. At the maximum
sample rate and maximum permitted delays, sample storage is 18432096 bytes,
plus objects and fixed state. `FrameCost` is 40 for existing aggregate work
admission. It is a work weight, not a measured execution-time or device deadline.

`Reset` clears every delay and damping state. Consecutive calls and clips keep
their history. Feed zeros or supply explicit `RenderEffectClip` tail frames to
render decay. No automatic tail cutoff, normalization, limiter, predelay or
early-reflection room model is added. Long/high-feedback settings can amplify
content; callers choose headroom and existing gain/dynamics stages as needed.

## Listening and evidence

Run `pythian.reverb.demo OUTPUT.wav` after building. It renders a native
six-note triangle phrase three times in 21 seconds at stereo 24000 Hz:

| Start | Segment |
| --- | --- |
| 0 s | Dry phrase, followed by silence |
| 7 s | 0.7 s nominal decay, damping 0.15 |
| 14 s | 2.8 s nominal decay, damping 0.65 |

Each section reserves four seconds after its three-second source. The processed
sections use dry gain 0.85 and wet gain 0.5, with default delays/diffusion/width.
The comparison is not loudness matched. Peak is 0.1616458446; the short and long
four-second tails have RMS 0.0000095719 and 0.0012619076 respectively.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass:

- An independent full-history transfer-function recurrence for both channels,
  including damping, negative diffusion and width mixing. Maximum absolute
  sample error is 5.5511151231257827e-17 on both compilers.
- An analytic sparse impulse response: initial delay 15 frames, echoes every
  ten frames, and amplitude 0.001 after the specified 100 ms comb decay.
- Full-width channel isolation, zero-width equal wet output, copied settings,
  reset, in-place processing, invalid delay rejection and a late right-channel
  failure that preserves the entire stereo state and assigned outputs.
- Whole-clip versus 37/164-frame partitions with 150 tail frames, exact sample
  equality, plus the existing filter/dynamics/effect-chain regression fixture.

Both demo WAVs contain 504000 stereo frames and compare byte-for-byte.
SHA256: `681599cddf829429028db36b2e536f8c57a6dc4c0c51580524219903fda955a8`.
Logs/artifacts: `build/reverb-{stable,trunk}/` and `build/reverb-replay.log`.
The focused builds have no warnings. The normal build includes the fixture
and demo; this checkpoint does not claim a full-suite run or package refresh.
Signal tests and deterministic PCM alone do not establish subjective quality.
The later [bounded stereo-speaker review](SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
judged the complete declared reverb example good overall, without a separate
spatial-motion or decay-time description.
