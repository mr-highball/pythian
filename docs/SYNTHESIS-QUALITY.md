# Synthesis quality: accepted scope and remaining review

[Home](../README.md) · [Milestones](MILESTONES.md#fund-quality) ·
[Capability map](FUNDAMENTALS.md) · [Instruments](INSTRUMENTS.md) ·
[Sources](SOURCES.md) · [Modulation](MODULATION.md)

The current evidence verifies numerical behavior, scoped bandwidth and bounded
rendering on stable/development Win32 and stable Win64. It does not establish
listener approval, instrument realism, general genre learning or device deadlines.
This page consolidates the existing fundamentals outcome; it adds no percentage
allocation and does not replace the separate recorded-style acceptance gates.

| Path | Scope verified | Evidence and limits |
| --- | --- | --- |
| Saved stationary timbre | Three profiles; seven sampled MIDI keys 36..96; velocities 32/80/127; 8/16/44.1/48-kHz output; authored envelopes and two-octave glides | [264-condition reference](INSTRUMENTS.md#measured-instrument-quality-checkpoint--2026-09-19). Sampled keys are not every pitch, and this is stationary timbre. |
| Measured envelopes and layers | Three profiles including a further blend; one-frame, 25-ms and two-second gates; 8/22.05/48-kHz output; two notes with 1/2/16 zones each | [81-condition RMS/harmonic reference](INSTRUMENTS.md#measured-envelope-and-layer-checkpoint--2026-09-19). Up to 32 voices, overlap budgets and reader replay; no automatic range or loudness inference. |
| Instrument export | Explicit common gain and overload rejection before accepted outputs change | [FUND-EXPORT](INSTRUMENTS.md#measured-envelope-and-layer-checkpoint--2026-09-19). Floating headroom and low-level PCM saturation remain distinct from the consumer's rejection policy. |
| Sample loops and controls | Smooth authored stereo loop; one-octave pitch ramp with cutoff/pan/gain motion; 8/16/48-kHz output; early and later release | [Analytic transition and paired bandwidth evidence](SOURCES.md#sample-loop-and-automation-quality-checkpoint--2026-09-19). Discontinuous recorded loop endpoints and arbitrary fast automation are outside this result. |
| Streamed FM/PM conversion | 4-kHz carrier / 6-kHz modulator, FM deviation 10 kHz or PM index 3; native versus fourfold rendering and bounded downsampling | [Bessel/filter and folded-component evidence](MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19). Selected coherent bins, not a universal oversampling factor or all modulation settings. |
| Spectral trajectories | Bounded adjacent-bank interpolation, raw phase or normalized magnitude shape, source-bound saved blends and independent envelopes | [Source references](SOURCES.md#spectral-trajectory-checkpoint) and [saved-provider controls](WAVE-STYLE.md#saved-spectral-trajectories) pass on three targets. Recorded changing-pitch admission and listening remain open under [WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre). |

All these paths have generated auditions and explicit limits. Read-size replay
and cross-target WAV identity are checked only for the workloads recorded in
their evidence pages. The core stays independent of WFC and playback devices;
measured-style ownership remains in the companion adapter. The
[delivery checkpoint](PACKAGING.md#current-source-packages) verifies the dated source
snapshots and extracted consumers; newer core/adapter changes still need affected
delivery verification. Linux/remote CI remains unverified. Package
replay does not close the listening review below.

<a id="combined-workload-checkpoint"></a>
## Combined source, timing and effects workload — 2026-09-20

A native study now connects four source families in one 40-note passage:
polynomial saw, authored stereo sample sustain loops with sinc interpolation,
normalized three-knot spectral trajectories, and FM. Independent gain, pitch,
pan and biquad-cutoff curves accompany ADSR gates. Four input buses feed a shared
reverb return and master. There is no limiter, automatic gain repair or external
audio input. The sample factory owns its source after the input clip is freed.

The declared scope is 24-kHz stereo, 120 BPM for six quarters then 96 BPM for six,
a 0.2-second initial rest, and 11 seconds including releases and effect tail.
Forty notes are admitted across the passage, not forty simultaneous voices.
Source/factory/control definitions remain alive until their consumers finish.

The reference places public `TPlayingTone` instances directly at independently
calculated absolute frames and feeds the bus graph. Scheduled renders use the
same public source and effect implementations through `TScheduledSynth`,
`RenderScheduledFrames` and the streamed PCM16 writer, reading 1, 257 or 4096
frames at a time. This independently checks scheduling/placement and block
composition; it is not a second DSP implementation or a spectral alias oracle.

All scheduled Single samples equal the reference exactly. All twelve reference
and scheduled WAVs across checked stable/development Win32 and stable Win64 have
SHA256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`.
Every target reports zero unfreed memory blocks and no compiler warnings.

| Observation / acceptance | Result |
| --- | --- |
| Declared duration and initial silence | 264000 stereo frames; exact silence before frame 4800 |
| Export headroom without correction | Peak 0.212615907, below the predeclared 0.95 bound |
| Whole-passage RMS | 0.031678146 across both channels |
| Largest adjacent-sample difference | 0.070990345; diagnostic only, not a click/listening verdict |
| Final 0.2-second RMS | Below the predeclared 0.0001 bound; prints 0.000000000000 |
| End state | No scheduled voices or reserved voice work; cursor at frame 264000 |
| Declared work | Initial reserved voice work 10632; graph frame cost 145; scheduler capacity 40 |

The diagnostic retains the complete reference for comparison. The scheduled
output is written in bounded blocks; the largest request is 4096 stereo frames.
Checked, heap-traced four-render runs take roughly 28 seconds on the local host;
this includes reference/checking/allocation/file overhead and is not a device
deadline or cross-target performance comparison.

The existing native converter then reads the saved PCM16 mix at unity gain and
produces 44100- and 48000-Hz output. Both 257/4096-frame read sizes produce identical
bytes within each rate; independent native inspection confirms 485100 / 528000
frames, exactly 11 seconds. Peak levels are approximately 0.212952 / 0.212616.
This checks WAV decode, continuous conversion and streamed encoding on the mixed
consumer path. The converter's existing clipping rejection remains unchanged.

Policy, diagnostic Pascal source, source hashes, WAV hashes and terminal logs are
ignored under `build/combined-fundamentals/`. The mixed audition is
`win64/block-257.wav`; converted auditions are under the same target directory.
Only the two conversion consumers were additionally checked on stable Win64.
No maintained unit, format, fixture count or package changed.

No defect was identified by these declared numerical checks. Listening remains
unassessed; the audition is ready for observations on attacks, sample release,
spectral motion, layer balance and the final tail. This closes this combined
workload check, not the wider FUND-QUALITY listening/coverage outcome or automatic
WAV/style admission.

<a id="automation-work-checkpoint"></a>
## Automation work accounting follow-up — 2026-09-20

The [shared voice-work correction](SCHEDULING.md#automation-work-admission--2026-09-20)
now charges frequency, pitch, gain, pan and cutoff automation in addition to
source/envelope work. The combined workload above was rebuilt and rerun on
checked stable/development Win32 and stable Win64. All twelve direct/scheduled
WAVs retain the original SHA256 and sample measurements. The initial voice
reservation is now **11656**, replacing the historical 10632 above; graph work
remains 145. All three runs release their voices/work and report zero unfreed
blocks. The corrected reservation includes 1024 units previously omitted for
automation across the admitted notes.

The existing workload remains within its declared budgets. Scheduler admission,
atomic replacement and stream/offline rejection also have a regression that
failed before the correction. Evidence is under `build/automation-work/`.
This resolves a concrete FUND-CONTRACTS accounting gap without changing rendered
sound. The subsequent [contract review](FUNDAMENTALS.md#contract-review) closes
the supported-workload review; listening remains open.

## Thirty-second listener preview — 2026-09-20

`build/listener-preview-20260920/synthesis-30s.wav` presents the first 15 seconds
of `build/saved-trajectory-win64/measured.wav`, followed by the first 15 seconds
of its `timbre-edit.wav` counterpart. These are native synthesized performances
from the saved-provider audition: the melody timbre changes while the bass/chord
stems and MIDI remain fixed. This is a paired synthesis example, not an accepted
chillwave, stoner-rock or lofi model.

The native preview assembler uses the library WAV reader/writer, applies the same
12-times listening gain to both excerpts and 10-ms fades at their cut edges.
There is no compression or limiting. Output is exactly 1323000 stereo frames at
44100 Hz (30 seconds), PCM16; pre-encoding peak is 0.593627930 and RMS 0.143946596.
The saved duration/format check passes; checked stable Win64 reports no unfreed
blocks. SHA256: `9952e5fd009689dd766473796a273bfb096cbc85fd7887b2d9f625560155a6ec`.
Source, build and render logs remain beside the preview under ignored `build/`.

The preview was supplied for listener feedback. Observations remain pending;
its preparation earns no completion credit. Link any heard defect and timestamp
to FUND-QUALITY and the corresponding source/control contract. The wider audition
suite below remains necessary for coverage beyond these two excerpts.

## Listening review and next work

Use the existing 88-note measured performance under
`build/instrument-headroom-study/measured-long.wav` for sustained instrument
balance and release overlap. Use the linear/sinc motion pairs under
`build/loop-modulation-study/` for intro, sustain and tail behavior. The compact
`build/fm-stream-study/measured-comparison.wav` contrasts native and fourfold
FM/PM in that order. These are local generated artifacts.

The additional `build/timbre-trajectory-win64/recorded-midi.wav` applies three
measured spectra to the existing 45-note changing-key/tempo passage. Review its
within-note changes and joins without treating a passing harmonic residual as
listener acceptance. This earlier raw-mode audition retains source dynamics
within spectral motion.

The paired `build/timbre-shape-win64/recorded-midi.wav` now uses the same spectral
windows and notes with independently selected modeled cycle RMS. The
[shape/level checkpoint](SOURCES.md#magnitude-trajectory-checkpoint) verifies that
control numerically, including its pitch-cap limits. This is not perceptual
loudness matching; listening remains unassessed.

The [saved-provider audition](WAVE-STYLE.md#saved-trajectory-checkpoint--2026-09-19)
adds `build/saved-trajectory-win64/measured.wav`, `timbre-edit.wav` and
`envelope-edit.wav`: the same 88-note performance with independent melody edits.
Review spectral motion, attacks and level balance in the paired outputs. Numeric
stem/MIDI isolation is verified; no listening verdict is inferred from it.

### Finite listening matrix — NS-2_synthesis-quality_01

The following existing artifacts form the finite listening packet. They are
generated artifacts under ignored `build/`; paths and hashes identify the local
files used to define this matrix. No new render is needed to begin review. For
the large measured-instrument set, each profile/rate WAV contains the fixed
seven-key and three-velocity workload described in
[the measured-instrument checkpoint](INSTRUMENTS.md#measured-instrument-quality-checkpoint--2026-09-19).
That bounds this measured-timbre case to 12 stationary and 12 matched glide
files while covering all 3 profiles, MIDI keys
36/48/60/69/72/84/96, velocities 32/80/127 and rates 8000/16000/44100/48000 Hz.

| Listening case | Existing artifact(s) and identity | Matrix dimensions to review |
| --- | --- | --- |
| Measured stationary timbre, sampled pitch/velocity/rate | `build/instrument-quality-study/measured-profile{1,2,3}-{8000,16000,44100,48000}.wav` and matching `measured-profile{1,2,3}-{8000,16000,44100,48000}-glide.wav`; source recipe and individual outputs in `build/instrument-quality-study/measured.json`. Example `measured-profile1-8000.wav`, 215084 bytes, SHA-256 `ad5eccb0cc2cb12b610e41a2ccb0226fbe784af0ebc4c13821e82e6640ab7c5a`. | All 3 saved timbres × 7 sampled keys × 3 velocities × 4 output rates; quarter-second gates, 5-ms attack, 30-ms release; inspect pitch continuity and roughness in the 12 matched glide files. |
| Measured envelope, short/long gates, attacks, releases and overlap | `build/instrument-envelope-study/measured-profile{1,2,3}-{8000,22050,48000}.wav`; source profiles, cases and hashes in the study outputs. Example profile 1 at 8 kHz, 153612 bytes, SHA-256 `27c387e4964e9722ab251d0b5db72c98442909333b682ce4033ee233459e4bee`; profile 1 at 48 kHz, 921372 bytes, SHA-256 `4fc450fc79ee76aea3d014a27483df2161a653f9ba250d2d54e59e6c2b903728`. | Three profiles × 3 rates × gates of 1 frame, floor(rate/40) and 2 seconds × 1/2/16 overlapping zones. Review initial attack, held portion, note-off/release, and the two-note release overlap. |
| Sample-loop exits and interpolation | `build/loop-modulation-study/measured-q{0,1}-{8000,16000,48000}-g*.wav`; `q0`/`q1` are the linear/sinc pair. Example short-gate linear 8-kHz output, `measured-q0-8000-g40.wav`, 6604 bytes, SHA-256 `9722ed0d4f70c4d5f11f1b63feb4c99911650c7e3fb1fcf02f5cb446439bad2d`; long-tail sinc 48-kHz output, `measured-q1-48000-g9601.wav`, 76848 bytes, SHA-256 `624faa7765b4402fe8c4258831c6b5ed3a8f4712baa281a4215eb1faeb075372`. | Both interpolation modes at 8/16/48 kHz; short and long gates, loop sustain, early and late release exits, pitch motion and cutoff/pan/gain automation. Compare matched q0/q1 cases for clicks, pitch continuity and tail character. |
| Oscillator, wavetable trajectory, sample sustain and FM in context | `build/combined-fundamentals/win64/block-257.wav`, 1056044 bytes, SHA-256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`; parameter/source policy and deterministic replay are recorded above in [Combined source, timing and effects workload](#combined-workload-checkpoint). | One 40-note passage containing polynomial saw, authored stereo sample sustain loops, normalized three-knot spectral trajectory and FM; review note attacks/releases, timbre joins and the final effect tail. |
| FM/PM native versus oversampled | `build/fm-stream-study/measured-comparison.wav`, 393260 bytes, SHA-256 `fe16863a11afd1ef7cfad87d2d13dd8451aa72790e983c3dc15231f2f2e2e68d`. | Three seconds in order: FM native/fourfold, then PM native/fourfold, with 125-ms separators. Review roughness and level/timbre change; this is one declared modulation setting, not general alias immunity. |
| Recorded spectral motion and saved instrument edits | `build/timbre-trajectory-win64/recorded-midi.wav` (SHA-256 `25b95af36a8c3b76f2d59b773542bbcd4d645f064a56c118bb51175915bbd869`); `build/timbre-shape-win64/recorded-midi.wav` (SHA-256 `6d32b124a21c7aeb07d8d6e9a621654c0137d3c3d24854b71ee1472cee3878c4`); and paired `build/saved-trajectory-win64/{measured,timbre-edit,envelope-edit}.wav`. | Review changing-pitch spectral joins, separate modeled level motion, and the saved 88-note performance's melody timbre/envelope edits while bass/chords/MIDI remain fixed. The saved `timbre-edit.wav` hash is `37eba7675e627c4ee25154a6acfaa3687f7cf3c57f9418447c0f6888f4c32de1`; `envelope-edit.wav` is `34ca2f3c667f12d955ee00723f810eb88abda77124bd9550c2a99fed1ebbac4f`. |
| Supplied paired listener preview | `build/listener-preview-20260920/synthesis-30s.wav`, 5292044 bytes, SHA-256 `9952e5fd009689dd766473796a273bfb096cbc85fd7887b2d9f625560155a6ec`. | First 15 seconds of measured performance then 15 seconds of its timbre edit; compare attacks, melody/bass/chord balance and transition. |

The matrix is finite: listen to the listed whole artifacts and record timestamped
observations against the dimensions in the last column. The measured sets cover
only their sampled key, velocity, rate, gate, profile and zone combinations;
they do not qualify intermediate or arbitrary settings. No timestamped listening
observations or family verdicts have been recorded yet. Listening is not available
in this handoff, so clicks, unwanted aliasing, pitch continuity and release
behavior remain unassessed; this matrix closes only the task's first acceptance
criterion. The verdict and any before/after evidence remain open under
[NS-2_synthesis-quality_01](TODO/NS-2_synthesis-quality_01.md).

Review audible attacks, releases, joins, roughness and level balance on these
declared paths. Record the exact artifact and transition if a defect is heard,
then link it to [FUND-QUALITY](MILESTONES.md#fund-quality) and its affected consumer.
Numerical agreement does not replace this observation, and subjective preference
alone should not silently expand the engineering contract. No listening verdict
has been recorded for this combined set.

The next fundamentals result completes this listening review and fixes any
concrete audible defects it reveals within the [accepted capability/failure and
workload contract](FUNDAMENTALS.md#contract-review). Independent context, phrase and corpus
work remains ready in the [execution order](MILESTONES.md#execution-order-and-blocking-links).
If the declared coverage proves insufficient, revise that outcome's scope
explicitly rather than adding isolated feature counts or compatibility formats.
