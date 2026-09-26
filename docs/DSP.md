# Oscillators and sample-rate conversion

[Home](../README.md) · [Architecture](ARCHITECTURE.md) · [Work](WORK.md)

## Oscillator quality

`TOscillator.Create(SampleRate, Seed, oqPolynomial)` applies polynomial
discontinuity corrections to saw and square waves, and integrated corrections
to triangle corners. Sine and seeded noise keep their existing definitions.
Frequency is finite, nonnegative and strictly below Nyquist. Reset restores
phase zero and the supplied seed. Rejected frequencies do not advance state.

The default constructor and `DefaultSynthVoice` retain `oqNaive` for existing
replay. Select the new path explicitly in a rendered voice:

```pascal
LVoice := DefaultSynthVoice;
LVoice.Shape := wsSaw;
LVoice.OscillatorQuality := oqPolynomial;
```

Both seconds and exact-frame tone renderers carry that setting. Rebuild callers:
`TSynthVoice` has a new field. Initialize records with their default factory.
The extracted WFC fixed-point oscillator remains a separate contract.

For phase `t` and increment `d = frequency/sampleRate`, the step residual is
`2x-x²-1` when `x=t/d < 1`, and `x²+2x+1` when
`x=(t-1)/d > -1`; it is zero elsewhere. Subtract it at the saw reset;
add it at the square rising edge and subtract at its falling edge.
The ramp residual is `d(1-|x|)³/3` within one increment of a corner.
The triangle's half-slope jumps are +4 at phase zero and -4 at phase one-half.
At zero frequency corrections are disabled, retaining the frozen-phase values.

This is a two-sample polynomial approximation, with remaining alias energy and
high-frequency harmonic attenuation. Abrupt frequency/shape changes, reset,
amplitude modulation and nonlinear downstream effects can introduce additional
aliasing. The API accepts per-sample frequencies, but stationary-tone results
do not prove arbitrary audio-rate modulation quality. There is no oversampling
or hard-sync correction in this implementation.

The mathematical approach follows integrated discontinuity correction;
see Esqueda, Välimäki and Bilbao,
[*Rounding Corners with BLAMP*, DAFx-16](https://www.dafx.de/paper-archive/2016/dafxpapers/18-DAFx-16_paper_33-PN.pdf).
Pythian derives its shorter cubic residual by integrating its quadratic step
residual; it does not implement the paper's four-point correction or claim
the paper's measured performance. No source code was copied from the paper.

## Clip conversion and reusable sampling

`ResampleClip(Source, OutputRate)` borrows an immutable mono/stereo clip and
returns a detached, caller-owned clip at the requested rate. Frame count is
`ceil(sourceFrames * outputRate / sourceRate)`, using integer arithmetic.
Output frame zero is source frame zero. Each position is calculated from its
integer frame index, avoiding cumulative fractional-step drift.

Equal rates return an exact copy. For changed rates, a centered sinc filter uses
a Blackman window. In source-frame units:

- Step `s = sourceRate/outputRate`; normalized cutoff `c = 0.94/max(1,s)`.
- Radius `r = ceil(64/c)`; support is strictly within `|distance| < r`.
- Weight is `c*sinc(c*distance)` times
  `0.42 + 0.5*cos(pi*distance/r) + 0.08*cos(2*pi*distance/r)`.
- Weights normalize by their sum for unity DC gain at each fractional phase.

The cutoff is 94% of the lower Nyquist frequency. Finite support gives a
transition band and residual stopband energy. Samples outside the source extend
the nearest endpoint; this is an explicit boundary condition, not recovered
audio. Centered access adds no timestamp shift to offline output, but requires
future samples and is not a causal streaming converter. Filter ringing and
peaks above source peaks are possible. No peak normalization or clipping occurs
until PCM encoding. Results exceeding finite Single headroom reject.

`TSincSampler` exposes the same kernel to sample instruments. It borrows a
nonempty source for its lifetime; source step is fixed at construction.
`ReadFrame(Position, Left, Right)` accepts finite positions in
`[0, source.FrameCount)`. Mono returns the same result in both outputs.
Callers determine positions; anti-alias protection assumes the configured step
matches their playback progression. Step zero is admitted as a fixed
interpolated position with the full-rate low-pass kernel.

This implementation follows the windowed-sinc reconstruction and lower-rate
cutoff principle described in Julius O. Smith III,
[*Physical Audio Signal Processing: Windowed Sinc Interpolation*](https://www.dsprelated.com/freebooks/pasp/Windowed_Sinc_Interpolation.html).
The Blackman window, support, endpoint extension, budgets and API are Pythian
choices; no external implementation is included.

## Granular playback

The sampler also supports periodic tap wrapping and explicit step updates for
[pitched sample voices](SOURCES.md). Clamp remains its default boundary, and
the offline clip conversion contract above is unchanged.

Set `DefaultGrainRenderOptions(...).Interpolation` through a local record:

```pascal
LOptions := DefaultGrainRenderOptions(48000, 2);
LOptions.Interpolation := giSinc;
LClip := RenderGrains(LSources, LGrains, LOptions);
```

`giLinear` remains the default. `giSinc` applies the shared sampler for
nonzero rates other than one. Rate one is exact source copying; rate zero
holds the exact source sample. Existing source/output coordinates, same-format
requirements, gain, windows and overlap normalization still apply.
The filter may read surrounding source frames outside the grain's nominal
center positions, up to its support radius, clamped at the whole clip boundary.
No playback-rate smoothing is implied between grains.

Rebuild callers for the new `TGrainRenderOptions.Interpolation` field.
Saved corpus and WFC model formats are unchanged. Current archive/remix tools
continue their existing unit-rate path and token/source mappings.

## Bounds and failure

Source/output formats retain the core's 1..384000 Hz and mono/stereo limits.
Changed-rate conversion supports downsampling through 64 source frames per
output frame; larger ratios reject. Upsampling is bounded by output size and
work. `PlanResample` checks before allocation: at most 64 million scalar
samples and 250 million conservative tap/channel visits.
An empty clip converts to an empty clip within the same format/ratio rules.
Both plan outputs clear on rejected input.

`SincTapBudget` reports `2*radius+1` per frame/channel, including skipped
support endpoints. At step 64 this is 8717. Granular rendering charges these
taps against its existing 64-million visit limit, and retains its existing
rate 0..8 restriction. These are bounded offline APIs; long recordings can
exceed the work limit. Use the streaming converter below to retain history
without a whole-clip allocation. Splitting recordings into independent clips
does not provide the same boundary behavior.

The native `pythian.convert INPUT.wav OUTPUT.wav SAMPLE_RATE` tool now uses
bounded WAVE reads, continuous conversion and streamed PCM16 RIFF/RF64 output.
`--gain VALUE` applies one nonnegative gain across channels and time. Alternatively,
`--peak CEILING` scans the converted peak first and only attenuates, never boosts;
the ceiling must be greater than zero and at most one. Default gain is one.
Any remaining sample outside unity rejects before replacing an accepted output.
`--block-frames N` selects 1..65536 frames (default 4096), without resetting
filter history at read boundaries. Temporary output consumes disk proportional
to output duration; memory does not grow with recording length.

The JSON report on stdout records hashes, formats, exact frame counts, raw and
resampled peaks, gain, output peak before PCM16, audio passes and buffer sizes.
The source is hashed before and after conversion. Complete validation and staged
encoding precede destination replacement; a physical I/O failure during the final
copy has no atomic rollback guarantee. The same expanded input/output filename
rejects; different filesystem aliases are not detected by that filename check.

## Continuous conversion

[pythian.resample.stream](../src/pythian.resample.stream.pas) adds
`TPcmFrameReader` and `TSincResampleStream`. A reader declares fixed source rate
and mono/stereo format. Each `ReadFrame` supplies one finite frame in Single
range, or False for permanent end-of-input. False never means temporary
starvation. The reader remains borrowed and must outlive the converter.

[pythian.wave.resample](../src/pythian.wave.resample.pas) supplies `TWavePcmReader`,
which borrows a `TWaveFrameReader` at its current frame and preserves finite float
samples outside unity. Its consumed peak does not normalize the input. The borrowed
reader/source must remain stable; a changed frame position poisons the adapter.
`StreamResampleFrameCount` computes the exact Int64 ceiling without multiplying
the entire input count by a sample rate; unrepresentable counts reject.

The converter pulls only enough future input for the next centered sinc frame.
It rounds input into the native Single PCM representation and retains a ring of
`2*radius+1` frames plus endpoint values. Maximum history is 8717 frames at
step 64, independent of recording duration. Equal rates use a one-frame ring
and exact Single identity, with no sinc filtering or lookahead. Mono mirrors
the left sample. Right input is unused for mono.

The optional constructor budget `AKernelCacheWeights` defaults to 65536 Double
coefficients (512 KiB plus bounded per-phase sums). Repeating rational phases use
an exact coefficient table only when the entire table fits that budget; zero
disables caching, and an oversized table falls back to on-demand evaluation.
`KernelCacheWeights` and `KernelCachePhases` expose the actual allocation. A
48000-to-16000 stream caches one phase of 411 weights. The table preserves filter
support, coefficient values and accumulation order; it changes computation and
storage, not the measurement policy or format version. The conversion report
includes both allocation counts.

`ReadFrame(var Left, Right)` returns one converted frame or False when fully
drained. It preserves both output arguments on False or exception. Source time
zero maps to output time zero, and output count is exactly
`ceil(inputFrames*outputRate/inputRate)`. At real EOF, the nearest endpoint
extends through the existing filter support; no extra timestamp padding or
filter tail is appended. Empty input has empty output. Repeated drained reads
remain False without consuming input.

Source position uses an Int64 whole-frame index and integer remainder modulo
output rate. Only the bounded fraction enters floating point, avoiding growing
floating-point phase and accumulated step drift. Guards reserve enough index
headroom for filter support and the next source step, and reject before count
overflow. Input and output frame counters are exposed separately. Input count
means confirmed accepted frames; a failing reader may consume more internally.
The [full-source filtering checkpoint](WAV-STUDIES.md#native-rate-scale-checkpoint)
verifies a 2h17m stereo 48000-to-16000 conversion on checked stable Win64, including
exact frame counts and offline PCM probes beyond 2 GiB source offsets. It does not
establish every long-duration ratio or full-source cross-platform parity.

`LookaheadFrames` is source-frame lookahead, not output padding. At 48000 to
44100 Hz it is 75 source frames; the ring contains 151 frames. A host must supply
that input before the corresponding output is available. A scheduled source's
already consumed input, including lookahead, belongs to its committed history;
device callbacks and live edits must account for it. This synchronous pull API
does not provide a nonblocking device adapter or a real-time deadline guarantee.

Reader errors, nonfinite/out-of-range PCM, output overflow and reentrancy poison
the converter because already consumed input cannot be rewound. Later reads
reject without further input calls. A reader cannot hide reentrancy by catching
the nested exception. Recovery requires a new pipeline with an explicitly
chosen input position; there is no implicit reset or source rewind.

The shared `SincKernelWeight` evaluator now serves offline and streaming sinc
sampling. Stream output is independent of input block boundaries. Agreement
with offline conversion is checked within floating-point position rounding;
bit identity between those two position calculations is not the public contract.
The stream has bounded work per output frame but no whole-recording visit limit;
callers control how many frames to request. Rates remain fixed for its lifetime.
Version: `StreamResampleVersion = 1`.

Checked stable/development Win32 and stable Win64 fixtures compare cached and
uncached streams with exact Double equality before PCM conversion. They also
exercise an oversized 16000-to-16001 phase table falling back to uncached work,
alongside the existing signal, endpoint, read-boundary and failure checks.
Evidence: `build/native-rate-{stable,trunk,win64}/fixture*.log`.

The native scheduling demo accepts an optional output rate:

```text
pythian.schedule.demo OUTPUT.wav [OUTPUT_RATE]
```

It generates at 48000 Hz and feeds the converter directly into the sequential
WAV writer in blocks of at most 1024 frames. The demonstrated 44100 Hz output
contains 308700 stereo frames (seven seconds), with no full intermediate clip.
Phrase edits and release times use the original source-frame clock. The default
48000 Hz output and existing offline sinc conversion remain byte-identical.

Focused evidence: `build/resample-stream-focused.log`, plus the final fixture
in `build/resample-stream-full.log`. Cases cover input-block identity through
repeated ring wraps, stereo polarity, exact ceiling duration, empty/one-frame
input, DC endpoint extension, identity rate, ratio 64, 44100/48000 rational
conversion, independent 1 kHz pass-band phase/amplitude and 9 kHz rejection at
48000 to 16000 Hz. Reader failure, invalid PCM and swallowed reentrancy preserve
unpublished output and stop future consumption. No vendor paths are needed.

The seven-second listening artifact is
`build/3.3.1-i386-win32/scheduled-stream-44100.wav`, SHA256
`1f3113cf558d27d4d55a345ab5f93408b3d91537b7db3f073a2f5b0b2787e564`.
Left/right PCM peaks are 0.196106/0.246185 and RMS 0.035445/0.031020.
Logs: `build/resample-stream-demo.log`, `build/resample-stream-metrics.json` and
`build/resample-stream-audio-regression.log`. Operator listening is unverified.

## Verification and listening

Existing FPC 3.3.1, i386-win32, with `-B -Sa -Cr -Co -Ci -gl`.
The full build passes in `build/dsp-validation.log`, including the independent
core phase without vendor search paths and all actual WFC fixtures.
Additional renderer-option, empty-input and budget boundaries pass in
`build/dsp-focused-validation.log`. No authored compiler warnings;
existing WFC unreachable-code warnings remain.

The oscillator fixture uses 8192 coherent samples at 32768 Hz. It subtracts
analytically permitted harmonic-bin power from total power, then normalizes
the remainder by measured fundamental power. This prevents reducing every
frequency equally from passing as alias suppression.

| Shape | 3988 Hz alias-power reduction | 12316 Hz alias-power reduction |
| --- | ---: | ---: |
| Triangle | 13.474 dB | 34.607 dB |
| Saw | 18.635 dB | 20.597 dB |
| Square | 16.648 dB | 36.254 dB |

At 48000 -> 16000 Hz, amplitude-0.5 sine tests exclude endpoint transients:

| Input frequency | Output interior RMS | RMS error against unfiltered phase reference |
| --- | ---: | ---: |
| 1000 Hz | 0.353553360 | 0.000000032 |
| 7000 Hz | 0.353569650 | 0.000016259 |
| 9000 Hz | 0.000001119 | Intentionally suppressed |
| 18000 Hz | 0.000000003 | Intentionally suppressed |

A 12000 -> 48000 Hz 1 kHz test has maximum interior sample error 0.000001837.
Other checks cover opposite-polarity stereo, centered impulse symmetry at the
exact 44100 -> 48000 anchor 2205 -> 2400, ceiling duration, DC endpoint extension,
empty clips, detached identity conversion, replay, failed plans, maximum
supported ratio and tap budget, filtered grain playback and tone quality
propagation. These are specific signal checks, not a complete converter
response specification or a cross-platform parity claim.

The build produces `dsp-comparison.wav`: six seconds of mono at 48000 Hz.
Every segment is 0.75 seconds, with fades and a short silent gap:

| Time | Content |
| --- | --- |
| 0.00 / 0.75 s | Triangle sweep, naive / polynomial |
| 1.50 / 2.25 s | Saw sweep, naive / polynomial |
| 3.00 / 3.75 s | Square sweep, naive / polynomial |
| 4.50 / 5.25 s | 3x grain playback, linear / sinc |

Sweeps run 400..10000 Hz. The last pair starts from 1 kHz plus 18 kHz:
the desired 3 kHz remains; the 18 kHz source should be removed before it
aliases to 6 kHz during 3x playback. Sweeps are listening examples; only the
stationary tests above establish quantified oscillator suppression.

Comparison SHA256:
`8266bad83950fb44070fd48df013d0ad2f04c498fcb4128d6bc617a1c593bbf0`.
Measured PCM peak 0.4267883301, RMS 0.2351485454.
The converted `dsp-comparison-44100.wav` has 264600 frames and SHA256
`b59194106b9763482b4fed4b553bd469ba17229966cdedcff91a4733334efcf0`.
The legacy `synthesis.wav` hash remains
`07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.
Operator listening quality and other compiler/platform targets are unverified.
