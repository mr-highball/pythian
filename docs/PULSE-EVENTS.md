# Learning from tracked pulse intervals

[Home](../README.md) · [Event learning](EVENT-LEARNING.md) ·
[Local tracking](BEAT-TRACKING.md) · [Work](WORK.md)

Pulse mode connects the local tracker to the actual WFC event learner. It learns
acoustic/duration/onset symbols from admitted recorded intervals, then reconstructs
selected intervals at their original playback rate. Each continuous admitted
run is an independent training sample. A source gap never becomes an observed
transition merely because two admitted intervals occur on opposite sides of it.

## Native admission

[pythian.pulse.events](../src/pythian.pulse.events.pas) exposes
`PlanPulseEvents(track, observations, sourceFrames, options)`.
The track and observations must describe the same recording; source hashing
belongs to the caller. The core validates ordered source observations, finite
positive weights, track array shapes, selected period bounds, complete contiguous
raw window ownership, strictly ordered raw/aligned points, and exact unique
observation identity for aligned points. Unaligned points must retain their raw
position. It does not rerun the tracker or certify caller-supplied hypotheses.

The returned `TPulseEventPlan` owns detached arrays:

- `Bounds` retains every final pulse position. Adjacent bounds define candidate
  source intervals; no prefix, suffix or endpoint is invented.
- `Decisions` records one result per candidate interval.
- `RunIndices` is -1 for excluded intervals, otherwise a dense chronological
  sample index. `RunCount` and `SelectedCount` describe admitted data.

Decisions are applied in this order:

1. `path_break`: any missing candidate window or restarted path after the left
   point's owner, through and including the right point's owner.
2. `uncertain_join`: any flagged raw join across that same window range.
3. `duration_ratio`: the final aligned interval length, divided by the mean
   selected period of its two owners, is outside the configured range.
4. `unaligned_endpoint`: an endpoint has no source observation, when required.
5. `selected`: the interval is admitted.

Windows without output points still participate in the path/join checks. An
initial restart flag does not exclude intervals wholly within that window.
The final duration check is distinct from the track's raw seam diagnostics.

Defaults are period ratio 0.5..1.5 inclusive and both endpoints aligned.
Caller-configurable minimum ratio is 0.25..1, maximum is 1..2, and
`RequireAlignedEndpoints=False` explicitly permits predicted endpoints.
The command uses defaults. The core accepts at most 4097 points (4096 intervals),
512 windows and 8192 observations. Empty or single-point tracks yield no training
intervals. Prefix counts make admission linear in observations, points and windows;
invalid calls leave a previously assigned plan unchanged. Version is
`PulseEventVersion=1`.

## Operator workflow

```text
pythian.event.remix INPUT.pyac SOURCE.wav ONSETS.json OUTPUT.wav SEED EVENTS [PALETTE_SIZE] --pulses
```

This optional mode takes an onset report from `pythian.onsets`, paired by exact
source hash and format with the WAV and measured archive. It does not consume a
beat report or rerun FFT/onset detection. It fits local grids from admitted onset
locations, weighting each by the square root of its positive energy rise normalized
to the largest weight. Default grid and tracking policies match
`pythian.beats --track`.

At least three admitted intervals are required; shorter runs can still be present.
The tool measures all candidate spans against stored acoustic features but trains
the palette only on admitted spans. Excluded spans have empty source tokens and
cannot be selected for output. Admitted symbols are split with
`PartitionAcousticEvents` before actual order-2 WFC corpus learning.
A requested fragment can be unsatisfiable, including when admitted runs provide
insufficient history. Existing solver limits and failure behavior apply.

Original event selection, exact-duration rendering, inside-edge fades, input
collision rejection and separate WAV/model/JSON publication remain in use.
The pulse sidecar contract is `pythian.pulse.remix.v1`; canonical event tokens
and WFC text contracts are unchanged. It retains the entire source onset report,
all grid/tracking/admission policies, normalized observations and original location
indices, local candidate grids, raw and final pulse positions, adjustments and
window owners, interval decisions and run indices, source attribution, hashes
and exact generated interval mapping.

```powershell
./build/3.2.2-i386-win32/pythian.event.remix.exe build/corpus/shared.pyac build/corpus/pixel-sprinter.wav build/corpus/pixel-onsets-fine.json build/corpus/pixel-pulses.wav 731 64 --pulses
```

## Evidence and limits

The [native fixture](../tests/pythian.tests.pulse.events.lpr) checks gaps, skipped
window flags, final aligned duration failures despite clean raw seams, endpoint
policy, retained source identities, detached results and failure preservation.
Its WFC mode has a negative control: flattening two runs teaches an artificial
A,A,B transition, while the actual separately trained order-2 model rejects it.
An invalid run that resumes across an exclusion also rejects.

Checked FPC 3.2.2 and 3.3.1 i386-win32 builds and focused fixtures pass. The
[published-output checker](../tests/pythian.tests.events.output.lpr) reconstructs
the admission/palette/model, checks report and source identities, proves a latent
WFC path without solving, rejects excluded selected events, and independently
compares every PCM sample with its source and edge gain. Admission replay shares
production routines; the adversarial fixture covers their boundary behavior.
This is not an independent beat estimator.

With seed 731, palette limit 8 and 64 generated events:

| Source | Candidate/admitted intervals | Training runs | Joint tokens / states | Output frames | Contiguous links |
| --- | --- | --- | --- | --- | --- |
| Pixel Sprinter | 79 / 79 | 1 | 36 / 71 | 1207932 | 28 / 63 |
| Opening Theme | 129 / 112 | 11 | 59 / 105 | 3537868 | 30 / 63 |

Both outputs are 44100 Hz stereo, approximately 27.39 and 80.22 seconds.
WAV, JSON and model bytes replay exactly across compilers. Files are
`build/corpus/pixel-pulses.wav` and `opening-pulses.wav`, each with JSON and
WFC text companions. SHA256 values:

- Pixel: `2d87f6dc7cd5e76459f88c88bee92482497e5fd07d4f500736108f40e148b086`.
- Opening: `43b87906ae00430270144c685adadea558843a8baf4a343d130189be0ccbbbce`.

Logs: `build/pulse-events-stable-final.log`,
`build/pulse-events-development-final.log`, `build/pulse-opening-stable.log`,
`build/pulse-replay.log`. Native inspections are
`build/pixel-pulses-inspect.json` and `build/opening-pulses-inspect.json`.
The original onset-event Pixel outputs and tracked audition/report remain
byte-identical (`build/pulse-regression.log`). A wrong-source onset report
preserves all three existing outputs (`build/pulse-rejection.log`).

The normal build includes core/WFC fixtures and a controlled tempo-change WAV
smoke. That smoke learns 23 intervals and generates 16 events / 352787 stereo
frames, with all samples checked (`build/pulse-smoke.log`). It uses Pythian's
existing synthesized percussion recording as source. This checkpoint does not
claim a full-suite rerun or refreshed source ZIP at that checkpoint. The subsequent
[package verification](PACKAGING.md#current-fifty-unit-package-checkpoint) now
reproduces Pixel pulse audio, JSON and WFC model bytes using extracted sources,
with the complete output checker passing.

Pulse admission is not calibrated confidence, beat correctness, meter, downbeat
or phrase inference. Source alignment cannot resolve half/double-time ambiguity.
The learned model may still repeat, drift or produce poor musical transitions.
These files rearrange attributed recordings; they are not newly synthesized
instrumental compositions. Annotated music evaluation, operator listening,
learned phrase development and continuous event
rendering remain open. The [shared event corpus](EVENT-CORPUS.md) now combines
admitted runs across recordings while retaining each source and gap boundary.
[Recorded-event archives](EVENT-ARCHIVE.md) now preserve those accepted definitions
and admit saved model counts without rerunning tracking or learning.
