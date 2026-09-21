# Musical timing in learned WAV generation

[Home](../README.md) · [Joint archives](JOINT-ARCHIVE.md) ·
[Output articulation](ARTICULATION.md) · [MIDI clocks](MIDI.md) · [Work](WORK.md)

## Two timing contracts

An explicit PPQ grid or MIDI sequence now drives both learned source selection
and final output gates. The [timing adapter](../adapters/wfc/pythian.wfc.timing.pas)
maps each positive-gain articulation gate's attack to the nearest generated
analysis-hop cell and constrains that cell to an observed onset candidate.
The actual WFC solver generates the paired sequence; the existing continuity
planner selects source windows that match both labels.

After overlap reconstruction, the articulation stage applies exact output
gates, including rests and inside-gate fades. These sample boundaries retain
the exact PPQ clock's tempo changes and rounding policy.

The alignment error measures the distance between the requested output frame
and the selected analysis-hop start. It does **not** measure the distance to a
true source transient or beat. Activity labels describe spectral-change
candidates over source windows. Transient localization, annotated source beat
accuracy and pitch-preserving time stretching remain separate work.
This generation path does not infer or silently assign source tempo. The separate
[beat-grid estimator](BEAT-GRIDS.md) now supplies ranked constant-period hypotheses;
the [local tracker](BEAT-TRACKING.md) adds changing-tempo paths and inspectable
source-onset adjustments. Neither automatically replaces these explicit PPQ/MIDI
constraints or supplies verified meter/downbeats.

## Reusable integer alignment

[pythian.alignment](../src/pythian.alignment.pas) exports
`AlignFeatureAnchors(frames, originFrame, hopFrames, cellCount, maximumErrorFrames)`.
It maps arbitrary absolute Int64 frame positions onto a uniform grid of
analysis-window starts. Each returned anchor contains:

| Field | Meaning |
| --- | --- |
| RequestedFrame | Exact input request, preserved in input order |
| Cell | Zero-based nearest analysis cell |
| AlignedFrame | originFrame + Cell * hopFrames |
| ErrorFrames | AlignedFrame - RequestedFrame, signed |

Nearest-cell ties go to the earlier cell. All arithmetic is integer, including
absolute positions above 2^53. Requests before the origin, beyond the nearest
available cell or outside tolerance reject. No clamping or partial acceptance
occurs. A detached candidate is published only after every request passes;
failure preserves a previously assigned result array.

The tolerance is explicit, inclusive and bounded by floor(hopFrames/2).
Hop must be positive, cell count is 1..65536 and there are at most 65536
anchors. The complete grid must fit nonnegative Int64 frames. Empty request
arrays are valid; input order and duplicates are retained. The mapper can also
be used with externally supplied source-clock anchors; it does not create
those annotations or infer their accuracy.

## WFC attack projection

`PlanJointAttacks(articulation, hopFrames, maximumErrorFrames)` returns a
`TJointAttackPlan` containing the required generated cell count, all positive-gain
attack anchors and actual `TJointConstraints`. The caller keeps the borrowed
articulation plan and uses the same sample rate as the corpus.

The generated extent is ceiling(outputFrames/hopFrames), bounded to 1..1024
cells by the existing generator. Model-state/cell and backtracking budgets
remain unchanged. The adapter does not increase work budgets to force a result.

Each distinct anchor cell gets an onset-only source-label lock, with any
acoustic token allowed. Simultaneous gate starts, such as a chord, share one
lock. Distinct requested starts landing on the same cell reject, even if both
were individually within tolerance. The adapter will not silently merge two
attacks. Zero-gain gates create no source lock.

Holds and rests add no source activity locks. Their exact amplitude behavior
comes from the output articulation plan. Muted cells still belong to the
generated learned sequence; they do not require observed quiet windows.
This allows output rests even in a corpus with no silence observations.

An unobserved required onset remains a WFC contradiction, and exhausted
backtracking remains a bounded-search failure. Neither condition relaxes
the timing request, changes the model or publishes output.

## Native grid and MIDI workflow

The [native timed remix tool](../tools/pythian.timed.remix.lpr) accepts a saved
joint archive and all source WAV files:

```text
pythian.timed.remix INPUT.pyac OUTPUT.wav SEED grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN MAX_ERROR_FRAMES SOURCE.wav...
pythian.timed.remix INPUT.pyac OUTPUT.wav SEED midi INPUT.mid MAX_ERROR_FRAMES SOURCE.wav...
```

Grid mode uses PPQ 480, an explicit tempo and the articulation pattern
`a` attack, `h` hold, `r` rest. It consumes the complete literal pattern,
without repetition. At 500000 microseconds per quarter and 240 grid ticks,
each character is an eighth note at 120 BPM. Leading holds and holds after
rests reject under the existing articulation contract.

MIDI mode uses the imported PPQ clock, tempo changes and all note gates with
the existing strict import policy. Unsupported performance controls and
ambiguous/dangling notes reject. MIDI pitch, program and channel do not choose
an instrument; velocity controls the shared output envelope. Simultaneous
notes can share an onset lock, but distinct attacks closer than the learned
grid can resolve may collide and reject. Sub-frame notes are omitted and counted.

Both modes use ceiling(rate/200) attack and ceiling(rate/100) release fades.
Library callers can build their own articulation plan with different fades.
Overlapping MIDI gates use the existing maximum-envelope composition.

The tool admits the stored paired model and activity policy without learning,
binds source files to exact archived SHA256 identities and retains their order
by those identities. Source order on the command line may change. The archive
and timed tools share [one source-binding helper](../tools/pythian.tools.sources.pas);
stored display names and provenance are never opened as paths.

Granular rendering includes the requested plan length, with zero-filled
uncovered regions if necessary, and the final articulation trims grain tails
to the exact plan extent. The output remains mono or stereo at the corpus rate.

The WAV sidecar binds archive, model and output hashes, complete activity policy,
source attribution and every selected grain coordinate. Its timing section
records the exact gates, anchor frames/cells/errors, tolerance, grid or MIDI
identity, fade lengths and policy versions. Source-window uncertainty is stated
explicitly. MIDI import omissions are counted. Sidecars remain inspection records,
not an automatic restoration or editable composition format.
Continuity weights/budgets, grain overlap normalization and interpolation are
also recorded, alongside the existing generator and solver versions.

All validation, generation, source selection, rendering and encoding finish
before publication. Rejected input, collision, contradiction or exhausted
search preserves previous output files. WAV/JSON writes remain non-atomic;
I/O failure during publication may leave a partial pair. Input and companion
sidecar path collisions reject.

## Verification

The [core fixture](../tests/pythian.tests.alignment.lpr) independently checks
signed anchor errors, exact large frames, earlier ties, odd hops, tolerance
failure preserving the previous mapping, empty requests and overflow rejection.

The [WFC fixture](../tests/pythian.tests.wfc.timing.lpr) checks coincident
attack deduplication, zero-gain omission, collision preservation, actual WFC
locks and contradiction without relaxation. Its optional recorded-music check
uses independently calculated grid positions, every stored source observation,
the output hash, all rest samples and fade endpoints.

The known four-attack example uses these requested and aligned frames:

| Requested frame | Analysis cell | Aligned frame | Error in frames |
| --- | --- | --- | --- |
| 0 | 0 | 0 | 0 |
| 44100 | 43 | 44032 | -68 |
| 88200 | 86 | 88064 | -136 |
| 132300 | 129 | 132096 | -204 |

Thus the largest grid quantization error is 204 frames, about 4.63 ms, within
the requested 512-frame tolerance. This is not a measured source-onset error.
The source analysis windows remain 4096 frames long.

```text
pythian.timed.remix build/corpus/shared-paired.pyac build/corpus/shared-timed.wav 731 grid 500000 240 ahrrahrrahrrahrr 512 build/corpus/pixel-sprinter.wav build/corpus/opening-theme.wav
pythian.tests.wfc.timing build/corpus/shared-paired.pyac build/corpus/shared-timed.wav.json build/corpus/shared-timed.wav
```

The output has 176400 stereo frames at 44100 Hz: four seconds, 173 learned
grains, four timed source-onset constraints and 88200 exact rest frames.
The inputs and their attribution are those of the [saved joint corpus](JOINT-ARCHIVE.md#verification).
Active-gate energy is nonzero. These checks establish the declared mapping and
output gates, not general musical quality or exact source transient placement.

On 2026-09-14, FPC 3.3.1-20634-gd7f522a561 for i386 Windows passed
`./tools/build.ps1`, including 39 core units without vendor paths, nine WFC
adapters, and both grid/MIDI timed-remix smokes. Log: `build/timing-validation.log`.
Core and WFC focused logs: `build/alignment-focused-validation.log` and
`build/timed-wfc-focused-validation.log`. Final tool rebuild with complete
render-policy metadata: `build/timed-remix-tool.log`; final recorded-music
check: `build/timed-published-validation.log`. No authored compiler warnings.

Four-second output SHA256:

`910e11e54ec89811e0259d76d37425ec77e0435bbebc939d7cd353f7dcca499b`

Left/right PCM peak is 0.8805541992/0.7541198730; RMS is
0.1465800718/0.1350023376. Metrics: `build/corpus/shared-timed-metrics.json`.
Generation log: `build/corpus/shared-timed.log`; metadata:
`build/corpus/shared-timed.wav.json`.

Reversing source arguments reproduces both WAV and metadata bytes:
`build/corpus/shared-timed-replay.log`. A zero-tolerance request and duplicate
source arguments each reject while preserving both previous output files:
`build/corpus/shared-timed-rejection.log`. The shared source-binding extraction
also preserves the earlier 512-grain saved-joint WAV exactly:
`build/source-helper-regression.log`.

The same real corpus renders the checked MIDI fixture through the final tool:
`build/corpus/shared-timed-midi.wav`, 29400 frames and one timed attack;
log: `build/corpus/shared-timed-midi.log`. This exercises actual MIDI import,
clock mapping, WFC constraint generation and output articulation.

Operator listening, annotated source beat/onset accuracy, broader recordings,
stable FPC 3.2.2 and other platforms remain unverified. The full project goal
remains open.

[Source onset localization](ONSETS.md) now provides optional PCM energy-rise
estimates inside the original candidate windows. The timed-remix adapter does not
yet use those estimates to move source anchors or change grain selection. Its
existing grid/error contract remains the applicable timing guarantee.
