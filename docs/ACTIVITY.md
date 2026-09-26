# Acoustic activity and continuity

[Home](../README.md) · [Persisted corpora](CORPUS.md) ·
[WAV learning](WAV-LEARNING.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

## Activity on an explicit sample grid

`pythian.activity` classifies each saved analysis frame as silence, onset or
sustain. It uses measured RMS and normalized positive spectral flux. These
are offline onset candidates with analysis-window uncertainty; no tempo, beat
clock, source separation or MIDI-note transcription is inferred.

The default policy is version 1:

- Silence follows the analysis RMS threshold. Sound beginning at the source
  start or resuming after a silent frame is an onset candidate.
- Other onsets require positive flux at least the larger of 0.18 and 1.5 times
  the mean flux of the preceding 16 feature frames.
- The candidate must be the first maximum in a neighborhood of two frames on
  each side, and at least three feature frames after the last accepted onset.
- Segments split at onsets, silence changes or 128 feature frames. A maximum-
  length split remains sustain/silence; it does not invent an onset.

The library exposes and bounds each option. Complete source coverage and the
expected uniform feature grid are validated. The result owns its action,
strength and segment arrays. Strength is capped raw flux, not a probability;
a silence-resume candidate may have low flux.

A segment partitions source time from one feature start to the next boundary.
Its frame coordinates are exact stored coordinates, while an onset may lie
anywhere inside its overlapping analysis window. With the default 44100 Hz
corpus, the hop is about 23.22 ms and the window about 92.88 ms. Partial terminal
windows retain their valid length. Detected candidates can be early relative
to a physical attack because the analysis window extends forward.

```text
pythian.archive segments INPUT.pyac
```

This command prints JSON with the archive/source identities, policy parameters,
segment ranges, onset counts, flux and onset-window lengths. It also exports a
real WFC rhythm model as canonical text in `rhythm_model_text`. Redirect stdout
to a file for larger corpora. It derives activity from saved measurements and
does not run another FFT or rewrite the archive.

## Shared WFC rhythm vocabulary

WFC's music contract distinguishes rest, attack and hold. Phanes's precursor
MIDI corpus extractor derives onset masks from known note start ticks.
`pythian.wfc.activity` maps measured silence/onset/sustain onto the real WFC
rhythm cell constructors and codec.

`ProjectAcousticRhythm` returns actual `TWfcMusicRhythmCells`.
`LearnAcousticRhythmModel` feeds those encoded cells to WFC's native sequence
learner, keeping each recording a separate sample. Every input feature remains
one observation. A cell's duration is one analysis hop in source samples,
reported as `rhythm_quantum_source_frames`; it is not implicitly a beat or
musical tick.

The fixture compares these tokens with rhythm projected from an actual WFC
score, then checks native model serialization and source boundaries.
Generic WFC sequence APIs consume this rhythm model. The existing acoustic
generation adapter continues to expect palette tokens. The separate
[joint adapter](JOINT.md) now learns paired acoustic/activity observations and
intersects simultaneous locks; its reconstruction requires both recorded labels.
Alignment to an explicit MIDI tempo map remains follow-on work.

## Continuity-constrained reconstruction

`TCorpusGrainPlanner` in `pythian.continuity` consumes a saved corpus, its
borrowed source clips and a fixed requested token sequence. The caller must
keep clips alive and bind them to the recorded file hashes. Format, extent,
palette membership and output-grid coordinates are checked by the planner;
the native archive tool additionally verifies every input file hash.

The planner copies corpus measurements and activity. For each token it retains
up to 16 nearest-center seed candidates. At each output step it also considers
the exact forward source successor of every retained path when that successor
matches the requested token. This allows a continuous source passage to extend
beyond the fixed seed-candidate count.

A beam of eight paths limits work. Each candidate keeps its cheapest retained
predecessor; cost and stable source/frame order break ties. The search is
approximate and does not promise a global optimum or a lower cost than every
possible plan. It never substitutes a different token to obtain continuity.
The graph's token locks and WFC failure semantics remain upstream of this
reconstruction choice.

The version-1 additive cost uses these explicit defaults:

| Component | Definition | Weight |
| --- | --- | ---: |
| Center error | Mean squared difference across the 15 acoustic descriptor components | 1 |
| Seam error | Sum of squared sample differences divided by combined sample energy plus 1e-20 | 1 |
| Source jump | Next grain does not start exactly one hop later in the same source | 0.05 |
| Jump into sustain | A source jump enters a feature classified as sustain | 0.2 |

For noncontiguous grains, seam error samples at most 16 uniformly spaced
positions over the output overlap, across all channels. When there is no
overlap it compares the previous last sample with the next first sample.
Exact forward source neighbors have zero seam cost. The normalized seam metric
is mathematically 0..2; it measures sample agreement, not perceived quality.
The segment maximum length affects inspection partitions; selection uses the
onset/silence actions rather than treating arbitrary maximum-length splits as
attacks.

Options permit beams/candidate pools 1..32, probes 1..64 and nonnegative weights
up to 16. A request has at most 4096 grains and a conservative 64-million probe-
visit budget, plus the existing granular output sample bound. Work is rejected
before search when it exceeds those bounds. Failed planning clears its report
and publishes no new plan. Source audio, corpus data and caller tokens remain
unchanged.

`Evaluate` measures an existing compatible grain plan using the same options,
so a caller can compare the default nearest exemplar plan and a continuity
plan. It independently checks every selected grain against its requested token
and exact source/output coordinates.

## Native comparison

```text
pythian.archive remix-continuous INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES SOURCE.wav [SOURCE.wav ...]
```

This uses the same saved acoustic WFC model and generation request as `remix`.
The output sidecar adds all continuity/activity policy parameters and measured
reports for both the nearest baseline and the selected plan. Grain starts remain
on the original output hop grid. The final output duration can change when the
chosen terminal source window has a different valid length.

Ordinary `remix`, saved archive version 1 and the nearest-exemplar API retain
their existing behavior. Activity is a derived policy, not a silent archive
migration. Both plans still use rate-1 Hann grains and normalized overlap.

## Verification and recorded evidence

Checked FPC 3.3.1/i386 Windows logs: `build/activity-validation.log`,
`build/activity-core-build.log`, `build/activity-core-validation.log` and
`build/activity-wfc-validation.log`. The final tool build and segment export are
recorded in `build/activity-final-tool.log`.

Focused checks cover peak/plateau/refractory rules, silence resumption, exact
segment partitioning, forced splits, irregular grids and an isolated opposite-
polarity stereo impulse. A constant-signal fixture proves forward continuation
beyond a one-candidate pool, deterministic tie order, zero-cost continuity and
the independent normalized seam error of 2 for opposite constants. Invalid
tokens and oversized requests reject. Actual WFC fixtures verify score/rhythm
token identity, model round-trip and caller token locks through reconstruction.

The [two-recording archive](CORPUS.md#verification-and-current-limits) produced
189 onset candidates for Pixel Sprinter and 376 for Opening Theme with the
default policy, and a four-state rhythm model. These candidates have not been
annotated against musical ground truth.

For the same saved corpus, seed 731 and 512 requested acoustic tokens:

| Measurement | Nearest baseline | Continuity plan |
| --- | ---: | ---: |
| Contiguous links | 0 | 356 |
| Source jumps | 511 | 155 |
| Source switches | 28 | 28 |
| Jumps into sustain | 489 | 121 |
| Selected onset candidates | 22 | 53 |
| Mean center error | 0.001202 | 0.003805 |
| Mean normalized seam error | 1.110782 | 0.191083 |
| Weighted total cost | 691.575248 | 131.541504 |

The selected plan uses 149 Pixel Sprinter grains and 363 Opening Theme grains.
`build/corpus/shared-continuous.wav` contains 527360 stereo frames at 44100 Hz
(11.958 seconds). L/R peaks are 0.88171/0.75412 and RMS 0.18190/0.16963.
Output SHA256:
`1bf753cb7507f0df486b7138a027f9f2c4602992a58f7562ad96cea15bce72f7`.
A separate load with reversed WAV argument order reproduced that hash exactly.

The archive and prior nearest-baseline WAV hashes remained unchanged.
Detailed reports are `build/corpus/shared-continuity.log`,
`shared-continuity-metrics.json`, `shared-continuous.wav.json`, and
`shared-segments.json`. The [manifest](../tests/fixtures/wav-corpus.json) records
portable source and output identities.

These observations prove the measured sample-continuity improvement for this
request. RMS differs between the plans; operator listening remains unverified.
Window smearing, false/missed onsets, beat alignment, long-form organization,
joint rhythmic constraints and broader music coverage remain open.

Optional [source onset localization](ONSETS.md) now searches PCM inside each
candidate window and reports a separate energy-rise frame, unresolved status and
edge flags. The original labels and feature-grid timestamps remain unchanged.
Controlled cases distinguish improved point timing from missed candidate coverage
and constant-energy spectral changes; recorded-music accuracy remains unverified.
The separate onset timing preset now uses a finer sample-rate-aware grid and
recovers the controlled 60 ms percussion pairs. Its inspection tool can overlay
audible location cues for review. Default archive analysis and stored activity
policies retain their existing behavior; finer inspection does not rewrite them.
