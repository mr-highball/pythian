# Fractional delay and stereo modulation

[Home](../README.md) · [Automation](MODULATION.md) ·
[Effect chains](EFFECTS.md) · [Bus routing](BUSES.md) · [Work](WORK.md)

## Reusable delay history

`pythian.delay.TFractionalDelayLine` separates nonmutating
`Read(DelayFrames)` from `Push(Input)`. Read before pushing the current
sample: a delay of one returns the immediately preceding sample. Multiple
reads can form independent taps before one push advances the line.

Construction allocates `MaximumFrames + 1` Double samples. Capacity is
1..3840000 frames; a read accepts a finite distance from one to the chosen
capacity. Initial history is zero. For distance `k + a`, integer `k`
and fraction `a`, the read is:

`(1-a) * history[n-k] + a * history[n-k-1]`

Integer reads return the stored value directly. Fractional reads use linear
interpolation, with no per-call allocation. Invalid input/read distances reject
before mutation. `Reset` clears all history and restores the write position.
There is no zero-delay/algebraic feedback path, resampling ratio, hidden time
smoothing or automatic tail calculation.

The existing `TDelay` now uses this shared line for its integer tap.
Its public dry-plus-wet and feedback recurrence remains unchanged, including
negative feedback support. Rebuild consumers after the class layout change.

## Stereo effect and control ownership

`pythian.delay.modulated.TModulatedDelayEffect` implements the existing
`TAudioEffect` interface, so it works in effect chains and their bus inserts.
Construction takes sample rate, `TModulatedDelaySettings`, and separate left
and right `TAutomationCurve` delay controls. Settings contain:

| Field | Contract |
| --- | --- |
| MaximumDelayFrames | 1..sampleRate*10; explicit capacity for each channel |
| Feedback | Finite signed value with absolute magnitude below one |
| DryGain | 0..16 |
| WetGain | 0..16 |

The entire minimum/maximum excursion of each curve must fit
`[1, MaximumDelayFrames]` before allocation. The effect owns clones of both
controls; caller definitions can be freed immediately after construction.
Point, periodic and affine-composed curves all use the existing automation
contract. Channel delay histories and controls are independent.

For each stereo channel, with its interpolated delayed sample `d`:

`stored[n] = input[n] + Feedback * d`

`output[n] = DryGain * input[n] + WetGain * d`

The curves use integer frames **since effect reset**, continuing across notes,
successive clips and explicit tail frames. They do not restart at note-on.
`ProcessedFrames` advances once per successful stereo call. `Reset` clears
both lines and restarts both curves at frame zero.

Inputs, feedback values and outputs must be finite and have magnitude at most
1e100. All reads/calculations validate before either line, the frame counter or
caller outputs change. A failed direct call is therefore retryable without reset;
in-place stereo arguments are supported. An enclosing chain still follows its
own failure rule: a failed stage poisons the chain because earlier stages may
already have advanced. Calls are sequential and not thread-safe.

Frame cost is a stable `6 + leftCurve.Depth + rightCurve.Depth` weight for the
existing render-work budget. This is an admission weight, not a CPU timing
guarantee. Delay storage is fixed at construction; processing allocates nothing.
Feed zeros for an explicit tail, or use `RenderEffectClip`'s tail argument.

## Chorus/flanger composition and limits

The same primitive supports longer moving delay taps for chorus and shorter
feedback taps for flanging. Their rates, ranges, stereo phase, feedback and mix
are caller policies; the effect does not embed a preset or a second LFO engine.
Use the existing sine/triangle curves and affine mapping to express delay frames.

Linear interpolation changes high-frequency response and is not an ideal
band-limited interpolator. Delay movement changes pitch and creates sidebands;
abrupt control changes may click. Admitted bounds do not promise alias-free
modulation, transparent pitch shifting or loudness matching. This effect does
not infer BPM or synchronize itself to a WFC provider; a musical layer must
explicitly map its timing to the chosen control curve.

## Verification and listening

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs are under
`build/delay-modulated-{stable,trunk}/`, with no vendor paths.
The focused fixture compares wrapped integer/fractional taps against an analytic
ramp and the legacy delay against an independent full-history recurrence.
The moving stereo effect matches an independently calculated absolute-history
reference within 3.89e-17. It also checks cloned control lifetime, a late right
output rejection preserving both histories/outputs/phase, full-excursion
admission, in-place calls, reset and exact whole-versus-split clip/tail samples.
Existing core and effect fixtures pass. The final focused fixture compilation
initializes its reference arrays explicitly and has no warnings.

`pythian.delay.modulated.demo OUTPUT.wav` renders one native six-note phrase
three times, with no recorded source music:

| Start | Sound |
| --- | --- |
| 0 seconds | Dry phrase |
| 4.5 seconds | 0.5 Hz chorus, 14..26 ms taps, quarter-cycle stereo offset |
| 9 seconds | 0.25 Hz flanger, 1..5 ms opposing taps, feedback 0.55 |

Each section includes an explicit half-second tail/silence allowance.
The result is 324000 stereo frames at 24000 Hz (13.5 seconds), with measured
pre-encoding peak 0.1629921645. The comparison is not loudness matched and
operator listening quality is not established by the numerical fixture.
Both compiler WAVs match byte-for-byte, SHA256:
`6e744c81c940ce9b36345eca464f778e0df8550568208c15f0d6ae14c622e69b`.
Direct comparison and hash: `build/delay-modulated-replay.log`.

The focused test and demo are integrated into the normal build. This adds one
core unit, bringing the current source count to 55 core units and 16 adapters.
Existing package ZIPs predate this change; no new full-suite/package result is
claimed.
