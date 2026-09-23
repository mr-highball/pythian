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
| Declared work | Initial reserved voice work 11656 after automation accounting; graph frame cost 145; scheduler capacity 40 |

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

### Combined-source listener copy — 2026-09-23

For the pending 11-second review, the maintained Pascal converter made
`build/listener-preview-20260923/combined-11s-gain3.wav` from the exact
`win64/block-257.wav` above. This is a listening-gain copy of the same native
synthesis, not a changed source or effect render. It is stereo PCM16 at 44,100
Hz, 485,100 frames, with one uniform 3-times gain; the measured peak before
encoding is 0.638884. The converter bound input SHA-256
`7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`
and output SHA-256
`02f158afa8ee2af3418237c37daf2d4be97ef5b96a676aadef6dcbfc3f47b913`.
The output file hash was checked independently. The copy and converter build
remain ignored under `build/`.

The authored passage starts after 0.2 seconds of silence. Saw, sample-loop and
FM notes begin together on each of twelve beats; the spectral-trajectory part
also enters at approximately 0.2, 1.7, 3.2 and 5.075 seconds. The beat spacing
changes at 3.2 seconds from 0.5 to 0.625 seconds. The last note starts at 6.325
seconds and the remaining duration contains releases and the effect tail. This
source-code map helps localize a reported problem, but the overlapping families
cannot establish individual-family approval from the mix. The finite matrix
below retains their separate listening cases. The user's subsequent broad
listening observation is recorded below.

### Eleven-second combined listener checkpoint — 2026-09-23

The user heard the complete, hash-identified
`build/listener-preview-20260923/combined-11s-gain3.wav` and reported that its
timing seemed to slow down in the middle, while the passage resembled music.
The perceived slowdown matches the authored switch at 3.2 seconds from 120 to
96 BPM (0.5 to 0.625 seconds between beats). The checked native plan and
sample-identical streamed renders already bind those frame placements; the
3-times-gain/44.1-kHz listening copy changes no beat timing. This observation
does not demonstrate an unexpected timing defect. It is a broad whole-passage
impression, not a timestamped verdict on attacks, releases, joins, balance,
spectral motion or the final tail. Separate source-family and processing
listening remains open, with no quality-task credit.

### Combined interaction coverage review — 2026-09-23

The existing artifacts cover the supported combined interactions selected for
the finite review; no additional render is needed for this declared scope.
Their local WAV hashes were rechecked against the identities below.

| Interaction to judge | Native evidence and listening scope |
| --- | --- |
| Simultaneous source families, automation, tempo change, bus return and final tail | Full 11-second `build/automation-work/win64/block-257.wav`, SHA-256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`; four families and four buses, with beat spacing changing at 3.2 s and release/effect tail after the last onset at 6.325 s. The 1/257/4096-frame scheduled and direct renders are sample-identical under the checked plan. |
| Sustained layered voices, overlap, saved sound edits and intact musical timing | Full `build/saved-trajectory-win64/measured.wav`, SHA-256 `cba63b4fd6678d7406994e83efe16e8acf7e819726bb8cce0746fad2b7555ab6`, plus `timbre-edit.wav`, SHA-256 `37eba7675e627c4ee25154a6acfaa3687f7cf3c57f9418447c0f6888f4c32de1`, and `envelope-edit.wav`, SHA-256 `34ca2f3c667f12d955ee00723f810eb88abda77124bd9550c2a99fed1ebbac4f`. The 88-note plan includes 1920-tick chord holds, reaches 12 overlapping voices and replays exactly across 127/2048-frame reads; its melody edits retain bass/chord stems and MIDI. |
| Processing/routing transitions and release history | The [finite processing matrix](#ns-2-synthesis-quality-02-matrix) includes dry/processed repeats, modulated delay, reverb, bus mute/return and a zero-fed effect tail, with fixed native levels. These cases can isolate an audible defect found in the combined mix. |
| Listener-copy relation to original synthesis | `build/listener-preview-20260923/combined-11s-gain3.wav`, SHA-256 `02f158afa8ee2af3418237c37daf2d4be97ef5b96a676aadef6dcbfc3f47b913`, is a 44.1-kHz conversion of the native 11-second mix with uniform 3× gain. The [30-second paired preview](#thirty-second-listener-preview--2026-09-20), SHA-256 `9952e5fd009689dd766473796a273bfb096cbc85fd7887b2d9f625560155a6ec`, joins two 15-second excerpts with common 12× gain and 10-ms cut-edge fades. Neither gain nor fade is an original synthesis change or an independently approved source family. |

This artifact and scope review meets the first criterion of
[NS-2_synthesis-quality_03](TODO/NS-2_synthesis-quality_03.md). The later
listener observation identifies the intended tempo change and a music-like
whole-passage impression; it does not judge attacks, holds, joins, balance,
spectral motion or tails. The separate source-family and processing matrices,
their verdicts, any demonstrated repairs and combined acceptance remain open.

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

### Combined numerical plan review — 2026-09-23

The current checked FPC 3.2.2 Win32 build reran the existing Pascal 40-note
combined workload. Direct placement and scheduled 1/257/4096-frame reads
produced the same 264000-frame stereo WAV, SHA-256
`7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`.
The declared 120-to-96-BPM frame placements, 4800-frame initial silence,
11-second duration, 0.212615907 peak against the 0.95 limit, final-tail limit,
11656 reserved voice work, 145 graph work and empty final schedule all passed.
The three fixed read sizes emitted identical bytes; the checked run reported
zero unfreed blocks. The original 10632 in the earlier table was a pre-correction
work reservation; the table now shows the current accepted value.

For the separate saved 88-note performance, the current Pascal stream-replay
check compared complete mix/stems and musical report fields against the
127/2048-frame replay with zero PCM error. A current timbre-edit control checked
actual MIDI bytes against the reported SHA-256
`939e81a74b97fedc64e012acccfd531160c2d5f77366854b48e3515d67dc3b3b`,
preserving bass/chord stems and MIDI while changing melody and mix. The
hash-bound baseline is 729281 stereo frames at 44100 Hz, 88 notes, 12 peak
voices, 795 peak frame-work units and 0.046263911 peak. Its maintained fixture
also checks each exported MIDI gate against its planned span endpoints. This
MIDI check belongs to that 88-note plan; the separate 40-note workload has no
MIDI artifact. Fresh checked logs and outputs are ignored under
`build/quality-plan-20260923/`. This closes the numerical timing, duration,
headroom and work-bound criterion of
[NS-2_synthesis-quality_03](TODO/NS-2_synthesis-quality_03.md); it does not
establish audible quality, family verdicts or a device deadline.

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

The user heard the full 30-second preview and described it as coherent overall
on 2026-09-23. This is a favorable whole-preview observation covering the
measured performance at 0–15 seconds and its timbre edit at 15–30 seconds;
it does not distinguish individual attacks, releases or source families, or
establish that no defect is audible. The wider audition suite below remains
necessary for those verdicts. Link any later heard defect and timestamp to
FUND-QUALITY and the corresponding source/control contract. No task credit
follows from this single observation.

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
| Short isolated source-family comparison | `build/3.2.2-i386-win32/sources.wav`, 960044 bytes, SHA-256 `1178a3df8b5f01b4f817c535a11e01f1a06b56a97a4855232bd62f01d9ee4760`. | Five one-second sections at 48 kHz: polynomial saw, additive, phase modulation, wavetable and authored stereo sampled percussion. Each section has two notes through the same renderer. This is a concise family check; the sampled-percussion source is authored and does not establish recorded-instrument realism. The user heard the full 0–5 s and said it sounded okay; no fault time was reported. |
| Isolated sample-loop note-off | `build/sample-loop-stable/sample-loop.wav`, 302448 bytes, SHA-256 `ad37c35ac0c8a85d30273381b20e2409eca8ab455ffe9a2b7f41865aa714bd00`. | At 12 kHz, compare 0–2 s one-shot, 2–4 s interior sustain and 4–6.3 s pitched sustain. Each gate is 1.5 s; inspect loop joins and releases against the preceding one-shot. This authored smooth-loop example does not qualify arbitrary sample loop points. The user heard the full 0–6.3 s and said it sounded okay; no fault time was reported. |
| Measured stationary timbre, sampled pitch/velocity/rate | `build/instrument-quality-study/measured-profile{1,2,3}-{8000,16000,44100,48000}.wav` and matching `measured-profile{1,2,3}-{8000,16000,44100,48000}-glide.wav`; source recipe and individual outputs in `build/instrument-quality-study/measured.json`. Example `measured-profile1-8000.wav`, 215084 bytes, SHA-256 `ad5eccb0cc2cb12b610e41a2ccb0226fbe784af0ebc4c13821e82e6640ab7c5a`. | All 3 saved timbres × 7 sampled keys × 3 velocities × 4 output rates; quarter-second gates, 5-ms attack, 30-ms release; inspect pitch continuity and roughness in the 12 matched glide files. |
| Measured envelope, short/long gates, attacks, releases and overlap | `build/instrument-envelope-study/measured-profile{1,2,3}-{8000,22050,48000}.wav`; source profiles, cases and hashes in the study outputs. Example profile 1 at 8 kHz, 153612 bytes, SHA-256 `27c387e4964e9722ab251d0b5db72c98442909333b682ce4033ee233459e4bee`; profile 1 at 48 kHz, 921372 bytes, SHA-256 `4fc450fc79ee76aea3d014a27483df2161a653f9ba250d2d54e59e6c2b903728`. | Three profiles × 3 rates × gates of 1 frame, floor(rate/40) and 2 seconds × 1/2/16 overlapping zones. Review initial attack, held portion, note-off/release, and the two-note release overlap. |
| Sample-loop exits and interpolation | `build/loop-modulation-study/measured-q{0,1}-{8000,16000,48000}-g*.wav`; `q0`/`q1` are the linear/sinc pair. Example short-gate linear 8-kHz output, `measured-q0-8000-g40.wav`, 6604 bytes, SHA-256 `9722ed0d4f70c4d5f11f1b63feb4c99911650c7e3fb1fcf02f5cb446439bad2d`; long-tail sinc 48-kHz output, `measured-q1-48000-g9601.wav`, 76848 bytes, SHA-256 `624faa7765b4402fe8c4258831c6b5ed3a8f4712baa281a4215eb1faeb075372`. | Both interpolation modes at 8/16/48 kHz; short and long gates, loop sustain, early and late release exits, pitch motion and cutoff/pan/gain automation. Compare matched q0/q1 cases for clicks, pitch continuity and tail character. |
| Oscillator, wavetable trajectory, sample sustain and FM in context | `build/combined-fundamentals/win64/block-257.wav`, 1056044 bytes, SHA-256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`; parameter/source policy and deterministic replay are recorded above in [Combined source, timing and effects workload](#combined-workload-checkpoint). | One 40-note passage containing polynomial saw, authored stereo sample sustain loops, normalized three-knot spectral trajectory and FM; review note attacks/releases, timbre joins and the final effect tail. |
| FM/PM native versus oversampled | `build/fm-stream-study/measured-comparison.wav`, 393260 bytes, SHA-256 `fe16863a11afd1ef7cfad87d2d13dd8451aa72790e983c3dc15231f2f2e2e68d`. | Three seconds in order: FM native/fourfold, then PM native/fourfold, with 125-ms separators. Review roughness and level/timbre change; this is one declared modulation setting, not general alias immunity. |
| Recorded spectral motion and saved instrument edits | `build/timbre-trajectory-win64/recorded-midi.wav` (SHA-256 `25b95af36a8c3b76f2d59b773542bbcd4d645f064a56c118bb51175915bbd869`); `build/timbre-shape-win64/recorded-midi.wav` (SHA-256 `6d32b124a21c7aeb07d8d6e9a621654c0137d3c3d24854b71ee1472cee3878c4`); and paired `build/saved-trajectory-win64/{measured,timbre-edit,envelope-edit}.wav`. | Review changing-pitch spectral joins, separate modeled level motion, and the saved 88-note performance's melody timbre/envelope edits while bass/chords/MIDI remain fixed. The saved `timbre-edit.wav` hash is `37eba7675e627c4ee25154a6acfaa3687f7cf3c57f9418447c0f6888f4c32de1`; `envelope-edit.wav` is `34ca2f3c667f12d955ee00723f810eb88abda77124bd9550c2a99fed1ebbac4f`. |
| Supplied paired listener preview | `build/listener-preview-20260920/synthesis-30s.wav`, 5292044 bytes, SHA-256 `9952e5fd009689dd766473796a273bfb096cbc85fd7887b2d9f625560155a6ec`. | First 15 seconds of measured performance then 15 seconds of its timbre edit; compare attacks, melody/bass/chord balance and transition. |

The matrix is finite. The user gave favorable full-window verdicts for the
0–5-second source-family demo, 0–6.3-second authored sample-loop demo, the
paired 0–30-second measured-performance preview, both 0–22-second measured
profile/glide packets and both 0–14.5-second envelope packets. The processing
review also found the recorded spectral pair good overall. The prompt for the
four measured packets named clicks, rough pitch changes, unwanted noise and
cut-off endings; the user said all four sounded good, with no fault time.
These are broad verdicts for the whole listed intervals, not separate
measurements of each note or proof that every artifact in the matrix was heard.
The accepted audible settings are the explicit examples at 8/48-kHz measured
rates, the 12-kHz authored loop, 48-kHz short source demo and the paired
performance preview. The 16/44.1-kHz static/glide, 22.05-kHz envelope and
8/16/48-kHz linear/sinc loop-motion cases retain numerical/replay evidence,
without separate listening approval. These sampled cases do not qualify
intermediate or arbitrary keys, velocities, rates, loop points or edits.
No source/articulation defect was demonstrated in the reviewed examples, so
there is no before/after source repair. The favorable verdict does not certify
realistic instruments, absence of every click or alias, or universal release
quality. The [bounded source acceptance](TODO/DONE/NS-2_synthesis-quality_01.md)
keeps those limits explicit.

### First isolated-source listening copy — 2026-09-23

For a bounded first family review, the existing measured-profile-1 stationary
case at 48 kHz has a 6.72-second listening copy under ignored
`build/listener-preview-20260923/measured-profile1-48k-gain12.wav`. The input
`build/instrument-quality-study/measured-profile1-48000.wav` has SHA-256
`5fe9c03db351e9fd30e99d9919a97cc67279920b7539d687038e3df47fbf37e7`.
The maintained Pascal converter used the same 48-kHz stereo rate and one uniform
12-times gain, retaining 322560 frames. Its PCM16 output SHA-256 is
`1dad450937cf046399fdb12448f1948750744c3adb1436711b447c6558be549a`;
measured pre-encoding peak is 0.409424, below clipping. The converter's report
is beside the copy. This is a louder review aid, not a changed instrument
render or an accepted operating range.

The source file sequences profile 1's seven sampled keys and three velocities
with quarter-second gates, 5-ms attack and 30-ms release. It can support a
first judgment on tone, pitch transitions, attack and release at this one
profile/rate. Other profiles, rates, glides, envelopes and sample loops remain
in the finite matrix above. The user subsequently described this complete
6.72-second copy as **smooth**. That is a positive, source-bound impression for
profile 1 at 48 kHz; no individual note time, pitch accuracy, aliasing,
short/long gate or sample-loop judgment was supplied. The remaining family
matrix and any final operating-range acceptance stay open, with no task credit.

### Measured-profile range listening packet — 2026-09-23

Four ignored review WAVs under `build/source-review-pack/` concatenate existing
native outputs at their original rates, with 0.2-second silent separators and
one uniform 12-times listening gain. There is no resampling, peak normalization
between sections, source rerender or limiter. The ignored Pascal `pack.lpr`
reads and hashes each input, requires matching rate/channel layout, rejects a
PCM-clipping result and saves the segment map beside each output. Stable FPC
3.2.2 Win32 compiled it with `-B -Sa -Cr -Co -Ci -gl -Fusrc -Futools`.

| Review WAV | Size / SHA-256 | Content and measured peak |
| --- | --- | --- |
| `measured-8k.wav` | 704044 bytes; `4e405cd81395e0c9433fdee65d98844640e65a59a3cbd261f5859636b4ed0a89` | 22.0 s at 8 kHz. Profiles 1/2/3 each have a 6.72-s stationary sequence followed by a 0.28-s pitch glide. Float peak 0.408691. |
| `measured-48k.wav` | 4224044 bytes; `7e829b66a0a6f06a92ea1417e9be828b0eb463ef555fe23b407df5f7b958d61c` | Same 22.0-s order at 48 kHz; float peak 0.409424. |
| `envelope-8k.wav` | 465436 bytes; `3e3ce94af102e7765b8d2728cf028332be54693c6a25a8d7a88475970ef52166` | 14.544 s at 8 kHz; profile 1 spans 0–4.799 s, profile 2 spans 4.999–9.545 s, profile 3 spans 9.745–14.544 s. Float peak 0.628418. |
| `envelope-48k.wav` | 2792156 bytes; `452cd15c7cea06155b9ecef5c266a9db602c800d24e0e873f12b04fdbf088577` | 14.542 s at 48 kHz; the same profile order and 0.2-s gaps; float peak 0.713013. |

Within either measured WAV, profile 1 is 0–7.2 s, profile 2 is 7.4–14.6 s
and profile 3 is 14.8–22.0 s; the glide occupies the last 0.28 s of each
profile's span. The profile outputs cover the seven sampled keys and three
velocities; the envelope outputs exercise the authored short/long gates and
release overlap. Exact input hashes and frame starts are in `measured-{8k,48k}-map.txt`
and `envelope-{8k,48k}-map.txt`. This is a concise listening aid at the low and
high rate endpoints. The user heard all four complete files and said they all
sounded good. No fault time was reported in response to the named click, pitch,
noise and ending checks. The 16/44.1-kHz static/glide and 22.05-kHz envelope files
retain numerical and native artifact evidence but have no separate listener
verdict.

<a id="ns-2-synthesis-quality-02-matrix"></a>
### Finite processing and routing matrix — NS-2_synthesis-quality_02

This matrix reuses existing rendered files; it creates no new comparison
renders. Keep the encoded level and order as supplied: do not peak-normalize or
turn up a quieter segment between comparisons. “Fixed level” here means the
documented source, voice, dry/wet, bus and master gains stay fixed within each
comparison. Several dry/processed examples are deliberately not loudness matched;
judge artifacts, spectral/control changes, stereo behavior and tails, not which
segment is louder. Exact sizes and SHA-256 values below identify the current
local WAVs.

| Review area | Existing WAV and identity | Fixed comparison and listening window |
| --- | --- | --- |
| FM/PM native and fourfold conversion | `build/fm-stream-study/measured-comparison.wav`, 393260 bytes, SHA-256 `fe16863a11afd1ef7cfad87d2d13dd8451aa72790e983c3dc15231f2f2e2e68d`. | 32768-Hz stereo output; each signal is 20480 frames (0.625 s) with 0.125-s separators. Listen 0–0.625 s FM native vs 0.75–1.375 s FM rendered at 131072 Hz then sinc converted; 1.5–2.125 s PM native vs 2.25–2.875 s PM fourfold/converted. Both use 4-kHz carrier, modulator ratio 1.5, FM deviation 10000 Hz or PM index 3, gain 0.35, centered pan, 5-ms attack, 0.5-s gate, 0.125-s release and one-pole cutoff 0.4 × render rate. Compare modulation texture/folded roughness; this is one declared setting, not broadband alias qualification. |
| LFO and gain/pan/cutoff automation | `build/3.2.2-i386-win32/control-curves.wav`, 1152044 bytes, SHA-256 `d8986a0ef3c66b3d11930fd8f0cd866415d55c37cc36f1d9242f0d9684c83ebb`. | Same 220-Hz saw voice in four 3-s segments at 24 kHz: 0–3 s plain reference, 3–6 s 5-Hz +/-15-cent vibrato, 6–9 s 5-Hz tremolo/gain, 9–12 s 0.5-Hz triangle cutoff and pan motion. Keep the file level unchanged; hear pitch, gain and stereo/filter movement against the plain segment. |
| Measured spectral motion and shape/level controls | `build/timbre-trajectory-win64/recorded-midi.wav`, SHA-256 `25b95af36a8c3b76f2d59b773542bbcd4d645f064a56c118bb51175915bbd869`; paired same-note/window `build/timbre-shape-win64/recorded-midi.wav`, SHA-256 `6d32b124a21c7aeb07d8d6e9a621654c0137d3c3d24854b71ee1472cee3878c4`. Each is 1008044 bytes. | Whole 5.25-s, 45-note passage at 48 kHz. Compare raw signed spectra retaining source dynamics with the same-window magnitude-shape trajectory using modeled cycle RMS. Do not normalize between them: the amplitude policy is the changed variable, and modeled cycle RMS is not perceived-loudness matching. Review pitch joins and tonal motion across the passage. |
| Saved timbre edit control | `build/saved-trajectory-win64/measured.wav`, SHA-256 `cba63b4fd6678d7406994e83efe16e8acf7e819726bb8cce0746fad2b7555ab6`; paired `timbre-edit.wav`, SHA-256 `37eba7675e627c4ee25154a6acfaa3687f7cf3c57f9418447c0f6888f4c32de1`. Both files are 2917168 bytes. | Same 88-note, 729281-frame stereo performance and complete MIDI; compare the full baseline/edit or the paired 0–15-s excerpts in `build/listener-preview-20260920/synthesis-30s.wav`. Timbre edit changes the melody provider while bass/chord stems and other bindings stay fixed. The preview applies the same 12× gain and 10-ms edge fades to both halves; no limiting. |
| Coupled gain, pan, cutoff and pitch movement on a looping sample | `build/loop-modulation-study/measured-q0-8000-g40.wav` (6604 bytes, SHA-256 `9722ed0d4f70c4d5f11f1b63feb4c99911650c7e3fb1fcf02f5cb446439bad2d`) and `measured-q1-8000-g40.wav` (6604 bytes, SHA-256 `4438129639eca51fc52a39c0840cb7ef3d37de5910f00deeb87a0c1eb769a4c3`); compare to the matching 16/48-kHz and `g3200`/`g3201`, `g9600`/`g9601` counterparts under the same directory. | Compare q0 linear with q1 sinc at the same output rate and gate: authored 12-kHz stereo sample with 300-frame loop, 200→400-Hz pitch ramp, 0.1→0.3×rate cutoff, -0.5→+0.5 pan, 0.5→1.0 gain multiplier, voice gain 0.5, velocity 0.75, 5-ms attack and 200-ms release. The fixed matrix spans 8/16/48 kHz, 5-ms, 200-ms and 200-ms-plus-one-frame gates. Review loop transitions and both early/late release exits; it is a smooth authored loop, not arbitrary recorded loop points. |
| Biquad filtering and dynamics | `build/3.2.2-i386-win32/effects.wav`, 1152044 bytes, SHA-256 `b70a06ffa11df7fc4d146c19d6b5296fd4e45d5832d880c9073ee35c02d77db1`. | Compare 0–3 s phrase with 3–6 s processed repeat at 48 kHz. The first phrase has per-note resonant biquads; the repeat adds smoothed gain, high-pass/high-shelf filtering, linked compression and a -1-dB sample limiter. Native fixed gains are retained; this pair is explicitly not loudness matched. Listen for filter/ringing character, compressor pumping, limiter roughness and stereo change without changing levels. |
| Stereo modulated delay | `build/3.2.2-i386-win32/modulated-delay.wav`, 1296044 bytes, SHA-256 `6e744c81c940ce9b36345eca464f778e0df8550568208c15f0d6ae14c622e69b`. | Same authored six-note phrase in 0–4.5 s dry, 4.5–9 s 0.5-Hz chorus (14–26-ms taps, quarter-cycle stereo offset), and 9–13.5 s 0.25-Hz flanger (1–5-ms opposing taps, feedback 0.55), with half-second tail allowance per section. Peak 0.1629921645. The comparison is not loudness matched; retain dry/wet gains and check movement, pitch wobble, stereo width and tail. |
| Reverb decay and stereo image | `build/3.2.2-i386-win32/reverb.wav`, 2016044 bytes, SHA-256 `681599cddf829429028db36b2e536f8c57a6dc4c0c51580524219903fda955a8`. | Same six-note triangle phrase at 24 kHz: 0–7 s dry, 7–14 s short 0.7-s nominal decay/damping 0.15, 14–21 s long 2.8-s nominal decay/damping 0.65. Processed cases retain dry gain 0.85/wet gain 0.5 and default delay/diffusion/width; compare decay, stereo width and the four-second tails. Not loudness matched (peak 0.1616458446). |
| Bus/routing mute, return and continuing tail | `build/3.2.2-i386-win32/buses.wav`, 1152044 bytes, SHA-256 `a9ff4f72f18cfb45c7a7af5190368a802a55638a2b1d1dffb12702873fbcc198`. | At 48 kHz: 0–2 s music plus 375-ms filtered echo; 2–3 s music return fades while effects remain audible at 2.5 s; 3–4 s music and continuing echo return with another effects burst at 3.5 s; 4–6 s zero-fed echo tail. Fixed music/effects gains 0.7/0.4, 35/15-ms smoothing, linked master compressor and -1-dB sample limiter; no normalization. Compare the audible pre-mute, mute and return passages. The separate unmuted fixture is a numerical history reference, not an audition WAV. Listen for preserved echo history, dry/effect separation and tail continuity. |
| Integrated automated sources, filters, effects and routing | `build/combined-fundamentals/win64/reference.wav` and `block-257.wav`, each 1056044 bytes and SHA-256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`. | Whole 11-s, 24-kHz stereo 40-note passage; audition the scheduled block-257 mix and use `reference.wav` as the same-sample direct-placement replay reference. It combines saw, looping sample, spectral trajectory, FM, gain/pitch/pan/cutoff automation, four buses and shared reverb. The exact sample identity checks placement/block composition only; it is not an independent DSP or perceptual-quality oracle. |

The user judged the original 12-second control comparison good overall but
described its 3–6-second vibrato as too wide. The [narrower before/after audition](MODULATION.md#listener-directed-vibrato-narrowing--2026-09-23)
changes only that authored pitch range from +/-30 to +/-15 cents; the 5-Hz rate
and other nine seconds are unchanged. After hearing both, the user said the
revised version seems better. The row above is now the preferred demo rendering;
the prior hash remains bound to the preserved before copy. No core automation
defect or final processing verdict is inferred from this preference.

After hearing the complete six-second `effects.wav` row above, the user said
"effects sounds good." This is a favorable whole-clip verdict for the original
0–3-second phrase and processed 3–6-second repeat at the bound file identity.
It includes no fault time or separate judgment on stereo motion, reverb/echo
tails or routing transitions. Those cases remain open.

After the finite processing packet, the user said the presented listening
examples sounded good, except that the high-pitched `measured-comparison.wav`
gave no clear listening target. This is a favorable broad impression for the
presented spectral pair, modulated delay, reverb and bus examples, without
individual fault times or a distinct spatial-motion description. The user
confirmed listening through stereo speakers, so that broad verdict includes
the presented stereo output, effect tails and bus transitions as heard in the
complete clips. It does not establish a separate localization or channel-balance
measurement. The FM/PM
high-carrier comparison remains perceptually uncertain; its numerical
[bandwidth gate](MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19)
is separate. The existing lower-pitched modulation demo was then heard as much
better and good overall, including its 4.5–7.5-second FM/PM portion. This gives
the supported FM/PM sound an audible positive example without turning the
high-carrier stress file into a pleasant musical audition.

This is the accepted finite processing/routing coverage packet for
[NS-2_synthesis-quality_02](TODO/DONE/NS-2_synthesis-quality_02.md). Relevant limits
are attached to each comparison: single-setting FM/PM bandwidth, authored smooth
sample loop, preset native levels, documented filter/dynamics settings, explicit
tail lengths, and one declared bus topology. No level correction is allowed to
hide an audible fault. The later 11-second mixed-passage comment identifies the
planned slowdown and music-like impression. The broad packet verdict above has
no fault times or detailed spatial description; acceptance is limited to the
declared rendered settings, native levels and stereo-speaker review. The only
reported processing objection was the too-wide authored vibrato in seconds 3–6;
its +/-15-cent revision was preferred, with no other PCM changes. Numerical
bandwidth, headroom and exact partition/replay checks remain linked from the
component documents. The high-carrier folded band is not perceptually approved.

Review audible attacks, releases, joins, roughness and level balance on these
declared paths. Record the exact artifact and transition if a defect is heard,
then link it to [FUND-QUALITY](MILESTONES.md#fund-quality) and its affected consumer.
Numerical agreement does not replace this observation, and subjective preference
alone should not silently expand the engineering contract. The broad 11-second
review does not approve the individual processing cases in this set.

The remaining fundamentals work accepts source/articulation and combined
listening under the [capability/failure and workload contract](FUNDAMENTALS.md#contract-review).
Independent context, phrase and corpus
work remains ready in the [execution order](MILESTONES.md#execution-order-and-blocking-links).
If the declared coverage proves insufficient, revise that outcome's scope
explicitly rather than adding isolated feature counts or compatibility formats.
