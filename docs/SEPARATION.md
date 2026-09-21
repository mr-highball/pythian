# Harmonic/percussive separation and shared Fourier transforms

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[WAV learning](WAV-LEARNING.md) · [Layered style](LAYERED-STYLE.md)

`pythian.separation.THarmonicPercussive` separates a native clip into harmonic
and percussive components for listening, remixing and subsequent analysis.
The source may be released after construction. The result owns two immutable
clips exposed as borrowed `Harmonic` and `Percussive` properties; free the result,
not those properties. Both outputs retain the exact source sample rate, channel
count and frame extent. The core has no WFC, file, device or external DSP dependency.

```pascal
Options := DefaultHarmonicPercussiveOptions;
Parts := THarmonicPercussive.Create(Source, Options);
try
  SaveWavePcm16('harmonic.wav', Parts.Harmonic);
  SaveWavePcm16('percussive.wav', Parts.Percussive);
finally
  Parts.Free;
end;
```

## Measurement and reconstruction contract

The implementation follows the median-filter and soft-mask approach described
by Derry FitzGerald in [Harmonic/Percussive Separation using Median Filtering,
DAFx 2010](https://dafx.de/paper-archive/2010/DAFx10/DerryFitzGerald_DAFx10_P15.pdf).
Median filtering across time emphasizes sustained spectral content; filtering
across frequency emphasizes broadband transients. Squared-median ratios provide
soft masks. This is spectral decomposition: pitched attacks can enter the
percussive component, while harmonic output can still contain several simultaneous
pitches. Neither component establishes an isolated instrument or voice role.

Pythian's explicit choices are:

- Centered periodic Hann windows, with zero padding beyond the physical source.
- One-sided RMS magnitude across channels for a shared stereo mask; each
  channel retains its own complex phase. Opposite-polarity stereo is supported.
- Odd median neighborhoods with nearest-frame/bin extension at spectrogram edges.
- Squared soft masks, scaled before squaring; both-zero medians split equally.
- Harmonic inverse STFT with sum-of-squared-window normalization. Percussive
  audio is the complementary source residual after harmonic Single conversion.
- Complete source-length outputs, with no added latency, gain normalization,
  clipping, source retiming or automatic monophonic admission.

`DefaultHarmonicPercussiveOptions` uses a 4096-frame window, 1024-frame hop and
independent 17-frame/17-bin medians. Window size accepts powers of two from 64 to
16384, hop accepts 1..window/2 and each median accepts odd lengths 3..63. These
choices affect temporal/frequency resolution and leakage; they are controls,
not universal instrument-separation settings. Processing is offline and uses
future context. No streaming/device callback contract is implied.

`PlanHarmonicPercussive` validates source geometry and preflights up to eight
million spectral cells and two billion estimated FFT/median work units. Sample
accumulators and result clips require additional bounded storage. The work count
is an admission metric, not a runtime or allocation guarantee. Rejected options,
budgets or output headroom leave a previously assigned result intact.

## Reusable Fourier primitive

`pythian.fourier.Fourier` exposes the existing native radix-two butterfly engine
for equal complex `TFourierValues` arrays of power-of-two size 2..65536. Forward
phase is negative and unscaled; `Fourier(Real, Imaginary, True)` uses positive
phase and divides by the length. The normal feature analyzer now uses this same
unit; its analysis geometry and policy are unchanged.

Transforms detach shared input buffers. Real/imaginary variables must be distinct,
although their original buffers may alias. Geometry, nonfinite values and a
conservative overflow bound validate before publishing either result. Candidate
buffers make this an allocating offline primitive, not an allocation-free audio
callback API. An independent direct complex DFT and inverse reconstruction check
the sign, scaling, alias ownership and failure behavior.

## Native operator and saved learning

```text
pythian.separate INPUT.wav OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES HARMONIC_MEDIAN_FRAMES PERCUSSIVE_MEDIAN_BINS]
```

The tool writes `-harmonic.wav`, `-percussive.wav` and `.json` with source/output
hashes, geometry, all options, method, native reconstruction error and component
RMS. WAV components are independently quantized to PCM16. The tool rejects
components outside PCM16 headroom before writing, while the core retains native
floating headroom. All outputs are constructed before individual file writes;
the three-file write is not atomic. No new saved-style format is introduced.

The maintained build learns onset/dynamics from the controlled percussive WAV,
then selects its rhythm and tempo alongside an explicitly authored C-major
context. A second blend adds another measured dynamics source before actual WFC
key/tempo/onset/intensity passes feed the existing voice stack. The provenance
records original-source and separation-report hashes. Context admission binds
the derived WAV itself; it does not pretend those bytes are the original recording.
Reloading a style validates its stored model/evidence, without rerunning separation
or verifying an external transformation report automatically.

## Evidence and limits

Checked FPC 3.2.2/3.3.1 Win32 and 3.2.2 Win64 pass the new native fixture,
maintained core/operator block, saved second-blend block and existing WAV/WFC
learning checks. The controlled mixture has a 440-Hz sine and periodic impulses
at 8000 Hz, with the right channel equal to minus half the left. Interior samples
1024..30975 measure 40.60 dB harmonic and 19.34 dB percussive signal/error against
independent source components. Native recombination over every frame, including
edges, differs by at most `2.99e-8`; silence and one-frame boundaries also pass.
This is a controlled reference, not a broad separation-accuracy benchmark.

The original CC0 Pixel Sprinter recording also separates at 44100 Hz into two
1512000-frame stereo components. Native reconstruction error is at most
`2.99e-8`; the independently encoded WAV sum differs by at most `3.06e-5`.
The original attribution and source hash remain in [recording provenance](WAV-LEARNING.md#published-recording-evidence).
There are no isolated reference stems for an accuracy score on this recording.

Controlled source/components and generated WAV/MIDI/preview files match across
the three targets (12 comparisons), as do both recorded components (four more).
Some Win64 measurement reports and bound style identities differ at floating
precision. Prior onset reports remain byte-identical to the previous executable
on the same target; Win32/Win64 report differences already existed before the
shared FFT extraction.

The maintained controlled style produces 64 cells / 160 notes / 705600 frames.
The recorded percussive style admits 154 onset cells, survives a second blend
with a native measured-dynamics source and produces 64 cells / 305 notes /
610091 audio frames. Actual WFC PCM, saved models and audio/MIDI hashes validate.
Pitches, voicings and one-cell gates remain authored in this audition; the learned
content is onset presence and aggregate dynamics. Instrument roles, polyphonic
note transcription and improved annotated beat/key accuracy remain open.
The saved recorded style also cross-loads on development Win32 and stable Win64;
WAV/MIDI/preview bytes match stable Win32 (six comparisons). Rejected median
options preserve both previously written component WAVs and the report.

Artifacts and logs are in `build/separation-{stable,trunk,win64}/`: the recorded
components are `pixel-harmonic.wav` and `pixel-percussive.wav`; stable `voices.wav`
is the generated recorded-style audition. `maintained-core.log`,
`maintained-style.log`, `learning-run.log`, `pixel-reconstruction.log`,
`recorded-style-check.log` and stable `replay.log` record the exercised scope.
Operator listening quality remains unassessed. The ordinary full suite and source
packages retain their preceding checkpoints; focused changed paths were run here.
