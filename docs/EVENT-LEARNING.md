# Learning and reconstructing measured source events

[Home](../README.md) · [Onset timing](ONSETS.md) · [Passages](PASSAGES.md) ·
[WAV learning](WAV-LEARNING.md) · [Work](WORK.md)

This path learns transitions between recorded intervals delimited by admitted
onset estimates. Each WFC token retains an acoustic class, a measured duration
class and whether the interval starts at an admitted onset. Generation selects
only source intervals matching all three fields, then renders their original
stereo samples and exact durations. The default uses onset intervals without a
beat grid. Optional [pulse mode](PULSE-EVENTS.md) instead admits intervals from
the local tracker. Neither mode stretches source audio.

It reuses the existing passage aggregation/rendering code and actual WFC sequence
learner. Fine onset indices are never used as indices into the wider acoustic
feature grid: source-frame boundaries connect those two measurement resolutions.

The [shared event corpus](EVENT-CORPUS.md) now pools admitted measurements across
recordings into one vocabulary while retaining independent song/run samples.
Its native operator renders selected members with exact source coordinates.

## Native boundary plan

[pythian.onset.events](../src/pythian.onset.events.pas) supplies
`DefaultOnsetEventOptions(sampleRate)` and `PlanOnsetEvents`. The default minimum
interval is approximately 10 ms, at least one frame. Clipped-context and
search-boundary estimates are excluded by default; callers can explicitly allow
either flag. The caller retains responsibility for source identity and the quality
of the supplied onset estimates.

The detached `TOnsetEventPlan` contains:

- `Bounds`: strictly increasing source positions, including zero and the exact
  source end. These can be passed directly to `MeasurePassages` and `RenderPassages`.
- `LocationIndices`: the original candidate row for each interior boundary;
  synthetic source endpoints use -1.
- `Decisions`: one reason for every supplied candidate, including unresolved,
  clipped context, search boundary, near endpoint, too close, duplicate or selected.

Source/window geometry is validated before planning. Eligible candidates are
stably sorted by frame and original index. Equal-frame candidates retain the
first eligible row. Chronological selection retains the earliest point at least
`MinimumFrames` from the previous boundary. Points closer than that minimum to
either source endpoint are excluded. A source shorter than the minimum still
produces one complete interval. Excluded candidates do not remove source audio:
their surrounding samples remain inside the retained intervals.

The input cap is 65536 locations and the output cap is 4096 intervals. Sorting
uses bounded temporary arrays and O(n log n) work. Invalid geometry or too many
selected intervals rejects without publishing a replacement plan. Version:
`OnsetEventVersion = 1`.

## Companion token contract

[pythian.wfc.events](../adapters/wfc/pythian.wfc.events.pas) defines
`TAcousticEventSymbol` with `AcousticIndex`, `DurationClass` and `StartsAtOnset`.
`AcousticEventSymbol` maps a positive source-frame duration to its nearest positive
duration quantum, with half ties rounded upward. Actual audio durations remain
unchanged. For example, 150 frames with a 100-frame quantum produces class 2.

Canonical tokens have the form `pythian.event.v1.A.D.O`, where A is an acoustic
palette index in 0..31, D is a duration class in 1..4096, and O is 0 or 1. Parsing
rejects noncanonical spellings such as leading zeros. A sample whose synthetic
start is not an admitted onset uses O=0; interior admitted boundaries use O=1.

`LearnAcousticEventModel` sends these observed joint symbols directly to WFC's
`LearnSequenceModelCorpus`. It supports orders 1..4, 1..4096 nonempty sequences
and at most 65536 total observations. Every sequence must use one shared palette,
sample rate and duration quantum; that context remains caller-owned metadata.
The palette is borrowed and training arrays are not retained. Separate recordings
remain separate samples; no cross-file transition is introduced.

`PartitionAcousticEvents(symbols, runIndices)` builds those separate sequences
from chronological interval symbols. A run index of -1 excludes an interval;
nonnegative run indices must be dense and ordered, and cannot resume after a
gap or a different run. Empty admission returns an empty corpus, which the
learner rejects. Excluded symbols are not read or validated. Returned samples
own their arrays. This additive helper retains the existing token/model contract.

Generation uses the existing `TryGenerateTokenSequence` adapter and actual WFC
constraint/solve semantics. Unknown constraint tokens are invalid requests; known
tokens can cause a contradiction at incompatible positions. Solver failure
preserves prior output. Version: `WfcEventAdapterVersion = 1`.

## Native workflow

```text
pythian.event.remix INPUT.pyac SOURCE.wav ONSETS.json OUTPUT.wav SEED EVENTS [PALETTE_SIZE] [--pulses]
```

Use a measured corpus archive and a report produced by `pythian.onsets`. The tool
matches exact WAV hashes and formats across the archive, decoded source and onset
report. It checks the report's declared feature/window geometry, retains its full
contents and exact hash, and does not rerun the onset analysis. These checks bind
the report to a source; they do not independently prove its onset accuracy.

The default boundary policy requires at least two admitted interior onsets.
`MeasurePassages` aggregates the existing archived acoustic features over each
new interval, weighting each feature's hop coverage. Those descriptors remain
window estimates, especially for intervals shorter than the archive's FFT window.
The existing acoustic palette is retrained on these aggregates, with default
limit 8 classes. Duration quantum is approximately 20 ms (`sampleRate div 50`,
at least one frame). The actual event model is learned at order 2.

The request generates 1..1024 events as a WFC fragment, subject to the existing
262144 state/cell budget and 256 backtracks. A fragment has no observed-start/end
or phrase-cadence requirement. A requested length can be unsatisfiable; the tool
does not silently relax the model or increase the budget.

Source selection prefers the next chronological interval when it matches the
generated joint token; otherwise it chooses a matching member deterministically
from seed and output position. The passage renderer retains original sample rate,
channels and exact selected interval lengths. Approximately 1 ms fades lie inside
jump edges and output endpoints. Contiguous source neighbors retain unchanged
samples across their join. Changing the number of generated events can change
total output duration; no fixed-duration or tempo guarantee is implied.

The output WAV has a JSON sidecar and the actual model in `.wfcs` text. Metadata
retains source attribution, archive/report/model/output hashes, full onset report,
every candidate decision, palette centers, source symbols, selected source/output
intervals, duration quantum, fade policy, seed and solver versions. The corpus
archive's old learned attachment is not used or changed. All analysis, solving
and rendering precede publication. Files are written separately, so a filesystem
failure can leave a partial output set.

Example using the attributed corpus:

```powershell
./build/3.2.2-i386-win32/pythian.event.remix.exe build/corpus/shared.pyac build/corpus/pixel-sprinter.wav build/corpus/pixel-onsets-fine.json build/corpus/pixel-events.wav 731 128
```

## Evidence and limits

The [focused fixture](../tests/pythian.tests.events.lpr) checks unsorted candidates,
stable duplicate selection, every exclusion reason, original row identity,
explicit edge-policy opt-in, invalid-call preservation and exact stereo coverage
through unequal intervals. Its WFC mode checks canonical symbols, duration rounding,
observed acoustic/duration correlation, a complete alternating generated path,
contradiction preservation and detached learned-model ownership.

The [published-output checker](../tests/pythian.tests.events.output.lpr) verifies
input identities, candidate decisions, interval/class mapping, exact actual learned
model text and every selected source duration. It independently checks reachability
through WFC latent states without invoking the solver, then compares every decoded
PCM sample with its source sample and independently calculated edge gain, allowing
PCM16 quantization and intermediate Single rounding.

Both attributed recordings were learned and rendered with seed 731, 128 requested
events, palette limit 8 and 44100 Hz stereo output:

| Recording | Source intervals | Joint tokens | WFC states | Output frames | Duration | Contiguous source links |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Pixel Sprinter | 349 | 77 | 245 | 547459 | 12.414 s | 46 / 127 |
| Opening Theme | 902 | 76 | 456 | 520358 | 11.800 s | 17 / 127 |

Pixel output SHA256:
`20332ee09c5808a13d91b7143a70d450f903472987b87f3baed5b9e0aa7c60fd`.
Opening output SHA256:
`3cc168926ab187fcb598599b973f787699c8c590155530ddf4b699ad275688dd`.
Files: `build/corpus/pixel-events.wav`, `build/corpus/opening-events.wav`, with
their `.json` and `.wfcs` companions. Native inspection reports are
`build/pixel-events-inspect.json` and `build/opening-events-inspect.json`.

Final checked builds and fixture/Pixel output verification pass on FPC 3.2.2 and
3.3.1 i386-win32: `build/event-stable-final.log` and
`build/event-development-final.log`. Existing upstream compiler warnings remain;
no new owned-source warning is retained. Pixel WAV, JSON and model text are
byte-identical across compilers (`build/event-replay.log`). A wrong-source onset
report rejects with all three prior outputs unchanged (`build/event-rejection.log`).
Opening's complete output check is in `build/opening-events.log`.

The normal build includes the native/WFC fixtures and a 16-event synthesis-source
smoke plus its output checker. That smoke passes in `build/event-smoke.log`:
31 source intervals, 15 joint tokens, 23 WFC states and 176252 stereo frames.
No full-suite rerun is claimed for this additive path. The subsequent
[package checkpoint](PACKAGING.md#earlier-onsetevent-package-checkpoint) compiles
the current units and reproduces the Pixel workflow from extracted sources.

This establishes event-level WAV learning and source reconstruction through the
actual companion contract. Operator musical-quality review, annotated real-music
onset/beat accuracy, phrase development and continuous unbounded rendering remain
open. [Saved recorded-event admission](EVENT-ARCHIVE.md) and multi-recording tooling are now
available through the [shared event corpus](EVENT-CORPUS.md).
The original hop-based archives/remixes and source-declared bar path retain their
existing contracts; these event fragments do not replace those distinct workflows.
