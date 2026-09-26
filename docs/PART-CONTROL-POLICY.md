# Authored part control policy

The native tool `tools/pythian.part.controls.lpr` generates a reproducible stem,
mix, annotation and scoring control packet from maintained source alone. Run it
from the repository root with `--controls` for arithmetic controls, or supply a
new output directory beneath `build/role-controls/`:

```powershell
./build/part-controls/pythian.part.controls.exe --controls
./build/part-controls/pythian.part.controls.exe build/role-controls/example
```

Compile with the existing FPC toolchain, unit paths `src` and `tools`, and isolated
unit/output directories. The output directory must not already exist. Inputs are
this policy, the [timing policy](PART-CONTROL-TIMING-POLICY.md), the tool source and
the maintained native units. No external assets, model or optional runtime are
required. Generated audio remains ignored build output.

## Authored source

The source is 12 seconds of mono audio at 16000 Hz: 192000 frames. Four persistent
roles are declared by construction: bass, chordal, lead and other. Their identities
are not inferred from instrument labels, channels or pitch order.

Each event uses the owned fixed triangle oscillator, starting at phase zero, with
5 ms attack and release inside its half-open gate. There are no nonzero samples
outside the gate. Quantization and the envelope can shorten the nonzero sample
extent relative to the nominal gate; these are separate reported quantities.

| Role | Interval in seconds | MIDI pitches | Amplitude per event |
| --- | --- | --- | --- |
| bass | [0.5, 2) | 48 | 0.10 |
| bass | [3, 5) | 45 | 0.08 |
| bass | [6, 8) | 48 | 0.10 |
| bass | [9, 10) | 43 | 0.08 |
| chordal | [0.5, 2) | 60, 64, 67 | 0.025 |
| chordal | [3, 5) | 57, 60, 64 | 0.025 |
| chordal | [6, 8) | 60, 64, 67 | 0.05 |
| lead | [0.5, 1.25) | 76 | 0.05 |
| lead | [1.25, 2) | 64 | 0.05 |
| lead | [3, 4) | 69 | 0.04 |
| lead | [3.5, 4.5) | 69 | 0.04 |
| lead | [6, 8) | 64 | 0.001 |
| other | [0.5, 1.25) | 64 | 0.05 |
| other | [1.25, 2) | 76 | 0.05 |
| other | [9, 10) | 72 | 0.04 |

The 21 events include simultaneous three-note chords, a declared lead/other pitch
order reversal, two overlapping lead events at the same pitch, complete rests and
a quiet lead coincident with chordal pitch 64. The latter has an authored per-note
amplitude ratio of 50. The tool requires nonzero quiet-stem energy and total
chordal energy exceeding it by 100 times in that interval. This is an energy
control, not a listening verdict or evidence of identifiable acoustic ownership.

## Exact stored mixture

Sum event contributions within each role in Double precision, reject clipping,
then quantize each stem once to PCM16. Store and reopen each stem using owned WAV
APIs. Sum the decoded integer samples at unity gain and zero offset, rejecting any
sum outside [-32768, 32767]. Encode and reopen the mix, checking every sample
against that integer sum. Check that every stem is zero outside its gate union.
The packet records nonzero extents, counts and artifact hashes.

## Frame controls and ancestry

The frame reference covers all 1200 centers at `80 + 160 * i`. Known roles contain
the exact pitch-set union of active authored gates; an empty known set is rest.
At [9, 10) seconds, the reference deliberately withholds lead/other ownership:
both roles are ambiguous and pitch 72 is unassigned. The full construction score
retains the actual owner separately. Same-pitch event multiplicity remains in
that score and is evaluated by the separate timing controls.

The source score and reference are written before their scripted predictions.
The six `EvaluatePartCells` controls are:

| Control | Expected result |
| --- | --- |
| Perfect scorable reference | Correct pitch/center counts 650, 1650, 500, 150 by role; no extras or misses; one correct crossing |
| Drop pitch 64 from the first chord | 150 missed chordal entries |
| Swap lead/other after the crossing | One wrong crossing; 75 unique wrong-owner lead entries and 75 ambiguous wrong-owner other entries |
| Add bass pitch 55 in the initial rest | 50 false entries in rest |
| Abstain on the quiet lead | 200 missed lead entries |
| Assign the uncertain pitch 72 to other | 100 admitted but unscorable entries |

Crossing endpoints are the declared centers 12080 and 28080. They establish an
endpoint pitch-order reversal, not continuous inferred identity.

The generic manifest records actual shared-score ancestry. Stems derive from the
score, the mix from stored stems, and references and scripted predictions share
the authored source/score. Results bind their references and predictions. The
packet is not an independent estimator evaluation or a recording-admission case.
Its observation layout uses the current part-note-set API; its wrapper is an
explicit authored control format.

## Replay and limits

Each packet is bounded to 30 seconds of execution, 256 MiB private memory and
8 MiB of artifacts. The tool checks elapsed time and output size; the execution
supervisor measures private memory. Failures use normal cleanup and existing
output directories are rejected before writes. Independent arithmetic controls
cover half-LSB quantization, signed integer summation and the envelope boundary.

Two fresh runs from unchanged source must reproduce all audio, score, reference,
prediction and verification artifacts exactly. The manifest's elapsed time is
observational and need not match. Policy and renderer hash changes necessarily
change provenance-bearing artifacts; they do not change the frozen authored
score or audio semantics. This packet supplies constructed controls under
NS-3_parts_01, not complete external role-accuracy or timing acceptance.
