# NS-3_validation_02 — Deliver a practical native inference execution path

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Remove the production execution barrier between promising WAV studies and the
maintained Pascal library. Integrate the selected Pascal observation backend
through a bounded, source-bound native WAV consumer.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 3 goal percentage points (0.75 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

The [selective observation producer](NS-3_validation_03.md) owns the first
2 of the original 5 unearned points. This task retains the remaining 3 for
the supported WAV consumer, source/policy binding, long-source cost,
supervision and publication. The two tasks together retain the original
5 NS-3 points (1.25 overall); this split changed no credit when created.
The later 20-attempt revision applied when the producer ledger was 4/20;
historical `/4` entries below retain the limit at those earlier stops.
The fifth Pascal producer passed its frozen synthetic, cost and source-bound
Spring gates and is [accepted](NS-3_validation_03.md) for its separate
+2 NS-3 points. This execution task was accepted on 2026-09-22 after focused
QA of the maintained 2048-sample WAV consumer, artifact identity, process
supervision, source and failure replay, and continuous-hour qualification.
It earns its assigned **+3 NS-3 goal points / +0.75 overall points**. The two
validation tasks together restore only their original +5 NS-3 points.

Completed short consumer batch 2026-09-22: replaced the rejected 1024-sample producer in
the current WAV request/worker with the accepted 2048-sample sparse peak
policy. Focused checked FPC 3.2.2 Win64/Win32 WAV geometry fixtures pass with
zero unfreed blocks, including exact 2048-sample windows, first-edge padding,
replay and changed-policy rejection. The checked Win64 supervised worker saves
both original Spring 30-second parts with the accepted estimator and policy,
scope `0..480000`, input support `0..481024`, first center 0, hop 160 and
channel 0. Each has 3000 centers; a separate label-blind Pascal PINF reader
matches **all 1,080,000 salience values** to the saved producer observation.
Flute takes 10,234 ms total, peak private 6,569,984 bytes, PINF SHA256
`903be589d250c39c0e834c88d50a39ef98ee976607d25e53398690253de63579`;
violin takes 10,203 ms, peak private 6,590,464 bytes, PINF SHA256
`bdb3fb708dcec66ad4d61a84a6cd446131950d40d8a64956ac377fbbfffb4dc0`.
Batch size 1 replays the flute artifact hash exactly from batch size 32.
Wrong-source SHA256 rejection and cancellation after at least 500 ms both
preserve the previously accepted flute artifact hash. The request fixture
rejects a changed policy. Source/reference identities and recorded scores
remain bound in the accepted producer task; this worker reads no Notes labels.

Six two-second 16/44.1/48-kHz × mono/stereo contract WAVs also pass a checked
supervised 1-second scope (`0..16000`, support `0..32000`, 100 centers); stereo
selects channel 1. The exact source and published PINF hashes are:

| Rate / channels | Source SHA256 | PINF SHA256 | Total ms / peak private bytes |
| --- | --- | --- | ---: |
| 16000 / 1 | `fe9222315d07010bbeb1ad1665eb30f21d93e62d8127e8c6e0894068f5407be6` | `075ce9a12ac479a0bccf4173c274a7e0ab34904454bac194eed72f7f17c2f7ef` | 375 / 6,578,176 |
| 16000 / 2 | `422f71598886b0edc34da21511708cd38b238e7b0dd65dd4593dfa7ba472cc0b` | `752b1aa79297199af7df40fa3cb778d88606231772402a8329ced8922c78cdc1` | 391 / 6,578,176 |
| 44100 / 1 | `f1479e301ea23fb06c02bf81d11c9dfc133cc5c4fc6f6067e9002ad33cecd274` | `6498d7be0e9de04d74268a80695585d896f37fb8ef25d3c2ccbd1dde6bcaf756` | 515 / 6,586,368 |
| 44100 / 2 | `dd4eb2de7d1f7dabd22e56995a42d7fc38728dafa41843276ff3a94aa981c25d` | `9176283c0f66522ba8d886f748285f1314039f88a1b3359ad1951c21b11c4cd4` | 547 / 6,586,368 |
| 48000 / 1 | `51b7cd7eb4f997ae0cc7b65b27a36c4ae3ebb0de98ce62b8986ba62f0ed8a824` | `77e2b2502aca4b296d551e57d3681c636099fabf48889c650be9580a8b4bff74` | 547 / 6,574,080 |
| 48000 / 2 | `567936b60319c77ed73d0f21921457bba8501f32c5179f7b63eeacd4dc400506` | `7ae1ec7769d1f6218b59e868c337b3debe7d2ea868a77543ce6afc8b04c4f382` | 547 / 6,582,272 |

Focused QA found no short-path defect. At this short-batch checkpoint,
criterion 1 and the short-source portion of criteria 4-5 passed while sustained
cost, hour replay and publication remained open. Exact ignored logs,
fixtures and artifacts are under `build/native-inference-wave/` and
`build/native-inference-next/`. The existing 30-second setup,
scope-plus-30-second total and 2-GiB worker-private budgets remain fixed.
Next bounded long-source batch: run the 48-kHz stereo five-minute fixture under
the 330-second/2-GiB limits and report observed cost, then run a source-bound
continuous-hour case only if the measured five-minute rate plausibly fits the
3,630-second/2-GiB limits. Stop at the first failed gate; no estimator or
recorded-score retuning. The hour must publish a verified, reproducible
360,000-observation artifact before remaining credit can be considered.

Long-source gate update 2026-09-22: the checked 48-kHz stereo five-minute
source SHA256 `7e305f5c7a195e3c0e8a1c8999a0d4bff4e57e281ec7b35cd0b562af623daafe`
publishes 30,000 observations in **137,719 ms**, with 1,218-ms cold/source
setup and 6,574,080-byte peak worker private memory; the supervisor process
reported zero unfreed heap blocks. Verified PINF SHA256 is
`7afabf5a08a8ccc2612c21f54409ca36cc57dcdc3a70dbe355d7ecdd8492d83b`.
The fixed 330-second and 2-GiB gate passes. A straight twelvefold time
extrapolation is 1,652,628 ms, below the 3,630,000-ms hour limit by
1,977,372 ms; this is a decision to attempt the hour, not hour qualification.
The next case uses the already verified 16-kHz stereo
`build/native-rate-scale/C-native16k.wav` source SHA256
`1efecef983467b81e87c9f1a92954ee0f3c9d001a801db06a7aa2fa2c8da5afc`,
scope `0..57600000`, input support `0..57601024`, center 0, hop 160 and
channel 1. Its source duration exceeds an hour, so the final window does not
gain artificial right-edge padding. Stop at the fixed 3,630-second/2-GiB gate
or any verification failure.

Continuous-hour result 2026-09-22: the checked stable Win64 supervised worker
published and fully verified **360,000** source-bound observations in
**1,247,313 ms** (20.79 minutes), including 11,062-ms cold/source setup,
worker completion, artifact validation and atomic publication. Peak worker
private memory was **6,582,272 bytes**; the supervisor process heap trace
reported zero unfreed blocks. The published 524,160,319-byte PINF SHA256 is
`bf63ebc3c7d989eed90ddf2f928e366c414bbd9286e741c2de7aa0609420f822`;
no `.pending` artifact remained. Both fixed limits pass with large margin.
The artifact reader validates complete extent/checksum and the exact source,
estimator, policy, channel, scope, support and observation-count identity.

Two independent checked supervised replays of the same source at
`28800000..29280000` and `57120000..57600000` each published 3000
observations under the same enclosing input support. A separate Pascal
`TInferenceFileReader` comparison verified every byte of each center, AC RMS
and 360-bin support record against the corresponding part of the hour artifact;
both pass, with zero unfreed blocks reported by their supervisors. The middle
PINF SHA256 is
`7e5c378a2bdcdb8825704fffa0d3b6425b4ebf6412c805834fa81d343f8e990d`
and the final PINF SHA256 is
`115d96344c5707736bb2db324983d51b8ff96196b752563d438eb590dfbbb609`.
These exact scoped replays establish deterministic nonzero seeking and final
window support; they are not a second full-hour execution. The 48-kHz
five-minute case and six short rate/channel cases provide the complementary
rate/channel cost evidence. All probes use owned Pascal and FPC/RTL, with no
external inference runtime. The rejected periodic-support backend and its
fixture are trimmed from the unmerged branch; their failure evidence remains
in Git history and the dated task record. Final focused QA found no criterion
gap, including the explicit raw-observation/admission boundary and the
unchanged-output failure and cancellation paths.

Starting evidence: [PHRASE-EVALUATION](../../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../../BEAT-TRACKING.md) · [ANALYSIS-WAVE](../../ANALYSIS-WAVE.md).

Reopened 2026-09-22 by the user's Pascal-only requirement. The previously
accepted implementation invokes a TensorFlow C runtime, so its backend strategy,
long-source qualification and native consumer no longer satisfy the supported
architecture. Preserve the prior numerical, resource and failure evidence as
historical evidence for that implementation, but withdraw the task's +5 NS-3
points (+1.25 overall) until a Pascal-only producer passes every criterion.
No TensorFlow, ONNX, HDF5 or other third-party execution runtime is part of the
replacement. Existing core Pascal measurements are starting evidence, not
automatic proof of the required long-source cost or recorded fidelity.

Recorded stop point 2026-09-22: the first Pascal periodic-support candidate
passed its synthetic and short consumer checks but failed the recorded
**specificity** question. Against hash-bound first-30-second Spring flute and
violin sources/references, a predeclared top-12 separated-candidate recall gate
passed at 1107/1125 (98.40%) and 1594/1594 (100%). A same-artifact density audit
shows why that gate was insufficient: on flute, an average 201.15/360 bins have
support >=0.5 at scored note centers and 203.38 at labeled rests; on violin the
averages are 87.45 and 198.73. Maximum support >=0.5 occurs at 925/926 flute
and 492/500 violin rest centers. Edges within 50 ms of reference notes are
excluded from both note and rest scoring. Reference labels entered only the
Pascal scorer after observations were saved. This broad absolute-correlation
response is not a selective recorded pitch or presence measurement. **Withdraw
the provisional first-criterion closure below**; the strategy is not selected
for production, and criterion 5 remains open despite high candidate recall.

The 30-second Win64 jobs completed in 2282/2313 ms with 3000 observations each;
a five-minute 48-kHz stereo channel-one case completed 30000 observations in
57797 ms, 1172 ms setup and 6578176 bytes peak private memory. These are
bounded cost observations for the rejected candidate, not transferred
qualification. The pending one-hour run was stopped when the specificity failure
was confirmed; it published no artifact or accepted hour result. No cancellation
gate is claimed from that stop. The next hypothesis is spectral harmonic support
using owned Pascal Fourier primitives. Before implementation, require both
>=80% top-12 reference-candidate recall and <=36 mean bins with support >=0.5
on each part's scored active and rest centers, while retaining the existing
duration/memory limits. If it fails, stop and reassess the observation geometry
instead of tuning thresholds on these same recordings. The existing five task
criteria own this replacement; no new task or credit is added at this point.
Attempt ledger under the user's four-attempt cap: 1/4 absolute autocorrelation
rejected for recorded specificity; the spectral hypothesis reached its fixed
synthetic stop gate and is recorded as attempt 2/4 below. The two nonclosing
work batches triggered
the separate Athena progress reassessment recorded in [WORK](../../WORK.md#periodic-support-recorded-stop-point--2026-09-22).

Exact recorded inputs and saved observations for this stopped candidate:

| Case | Source SHA256 | Reference Notes SHA256 | PINF SHA256 |
| --- | --- | --- | --- |
| Spring flute, 30 s, 16-kHz mono | `595d9a858fcecb0478692a806b961c967f6309de01e58821a4ce69de10fa5d30` | `70cbb79326ac89f10cdb4424d24aca0098d173dda632fdc30bfbc8eacc1f1c05` | `27196468886c66541a5fc2b38c9cd9e76448c140f8473b1d76b1324eb81a2b8d` |
| Spring violin, 30 s, 16-kHz mono | `bfa0c3038f58126730fa3e2ec4a6cd5740cfa18a12173f4bef6de54b01ca5e1a` | `711934ba728f02bff3906b590589efe7b0f621677f262ca1cb0ebdfc1ab15c09` | `ffba4d9431d0e9106b0d71a2849afc3351b5295a9a636f9ab9e5b768cb5f78da` |
| Five-minute 48-kHz stereo fixture, channel 1 | `7e305f5c7a195e3c0e8a1c8999a0d4bff4e57e281ec7b35cd0b562af623daafe` | none | `225c9fbe71335f56cf0b8f26ce02fb15273bcacff59e9f5af0f6c45b8f22a7b4` |

The Spring jobs used scope `0..480000`, waveform support `0..480512`, center 0,
hop 160 and batch 32; the five-minute fixture used scope/support `0..4800000`
with the same center/hop/batch. All source hashes are of the original WAVs, not
prepared excerpts. The Spring Notes files are scoring references only. The
ignored `build/native-inference-pascal/recorded-support.lpr` records the Pascal
scoring policy; the retained PINF files and exact command arguments permit a
fresh cost replay without accepting the old cost as a future backend guarantee.

Second hypothesis stop point 2026-09-22: a Pascal sparse harmonic spectrum
candidate using the owned 1024-point Fourier primitive compiled with checked
FPC 3.2.2 for Win64 and Win32, but failed its fixed controlled low-register
mixture check before recorded scoring. With 55-Hz amplitude 0.3 and 110-Hz
amplitude 0.2, support was 0.464351296 and 0.195154965 respectively; both
were required above 0.3. The Win64 run reported zero unfreed blocks. The
30-second throughput probe, Spring dual gate and hour implication were not
reached. This is a rejected hypothesis, not a selected backend or a completed
criterion. The prototype was removed from maintained paths to keep this
unmerged branch lean; its checked compiler and run logs remain under ignored
`build/native-inference-spectral/`. At 16 kHz, a 1024-point transform has
15.625-Hz spacing; overlap of a 55-Hz tone's harmonic and a separate 110-Hz
tone is an identifiability concern, so the next decision must test explicit
resolved peak evidence and harmonic ambiguity, rather than merely
retune the failed normalized harmonic sum. Attempt ledger: 2/4 hypotheses
rejected for a viable Pascal observation producer. No task credit changes.

Attempt 3 is a distinct, bounded longer-window peak-evidence hypothesis:
use a 2048-sample (128-ms) Pascal analysis window at 16 kHz, score resolved
local spectral peaks directly, and carry missing-fundamental support only from
explicit harmonic evidence. Before recorded scoring, require controlled 55-Hz
and 110-Hz tones, their 0.3/0.2-amplitude mixture (both supports >0.3),
110/165-Hz missing-55 ambiguity (>0.3), 220-Hz lower-octave ambiguity (>0.3),
silence/DC zero, finite 0..1 output and exact replay. The previously declared
Spring top-12 >=80% and mean >=0.5 density <=36/360 gates on both active and
rest centers remain unchanged, as do time/memory budgets. If synthetic
controls fail, stop before Spring; if the Spring gate fails, stop before an
hour run. This is not permission to tune on the same reference labels.

Third hypothesis stop point 2026-09-22: the 2048-sample peak-evidence prototype
compiled with checked FPC 3.2.2 for Win64 and Win32. It passed the 440-Hz tone
and exact replay controls, then failed the frozen 55+110-Hz mixture check:
support was 0.460238546 at 55 Hz and 0.203423500 at 110 Hz, below the required
0.3 at the latter. The failed Win64 run reported zero unfreed blocks. Later
synthetic controls, 3000-window throughput, Spring recordings and sustained
cost were not run. The rejected prototype is trimmed from maintained paths;
ignored `build/native-inference-peaks/` retains its checked logs. Attempt
ledger: 3/4 rejected Pascal producer hypotheses, no task credit. The spectral
and peak probes are two nonclosing batches since the previous reassessment;
stop estimator variations and split the independently useful observation
producer from the supervised long-source execution deliverable below. A
fourth attempt requires a new decision based on the failed controls, with its
evaluation policy and stop condition fixed before implementation.

Pascal producer checkpoint 2026-09-22: the maintained Win64 WAV consumer now
uses an owned, bounded 360-bin periodic-support estimator and no model/DLL asset
path. The request policy is
`periodic-support-raw-f32-16k1024-sinc-channel-v1`; the estimator identity is
`pythian-periodic-support-midi24-20cent-v1`. Bin centers cover MIDI 24..95.8,
and values are raw normalized periodic support, not note probabilities. The
existing source-bound preparation, staged artifact and supervised worker are
retained. The former adapter, acquisition procedure, lock and runtime fixture
were removed from maintained paths; their source/notices remain in Git history.
This initially appeared to close the first strategy/scope criterion for the
Win64 candidate. The recorded stop point above withdraws that provisional
conclusion; no task credit was earned.

Stable FPC 3.2.2 checked Win64 and Win32 backend fixtures pass tone, silence,
DC, missing-fundamental, octave ambiguity, invalid-input and replay controls,
with zero owned leaks. The 3,000-window backend probe takes 1,875 ms on Win64
and 6,406 ms on Win32; these are short isolated costs, not an hour estimate.
The checked Win64 WAV consumer emits 100 observations from a one-second 16-kHz
mono scope in 109 ms, and from a 48-kHz stereo channel-one scope in 235 ms;
the latter exercises owned resampling. Batch sizes 1 and 32 produce the exact
same artifact SHA256,
`75faa72f423232302d3e5c19ce2116d54eb9b5761e866fc40e1d7fa7013fe935`.
A wrong source hash fails without changing the accepted artifact. Full recorded
fidelity, all rate/channel cases, sustained-source cost, new-worker failure and
cancellation QA, and final target delivery remain open. These short runs earn
no further criterion or task credit.

## Historical qualification of the retired runtime

The following completion and reopening notes record the former adapter's
qualification only. Their credit statements describe the ledger at those
earlier dates; they do not restore current task credit.

Completed 2026-09-21 after progress-snapshot repair: final checked stable Win64
QA restores all five criteria, combining unchanged retained numerical/resource
evidence with the affected supervision checks. One aligned atomic word now owns
phase and full timestamp; one captured load supplies both supervisor values and
the terminal phase check. The coordinated second-mapping publisher regression
passes, as do seven subprocess cases for real stall, setup/total timeout, healthy
six-second transition, memory rejection and cancellation. Cancellation cases
finish in 266/265 ms, including the 200-ms request delay; all failures preserve
accepted output. The real-worker replay retains exact prior 48-kHz stereo
artifact bytes, with 44,187 ms total, 19,968 ms setup and 103,153,664-byte peak
private commitment. Both initialization failures and long-source setup
cancellation pass. All final logs report zero owned leaks. No budgets, model
arithmetic, waveform preparation, identity or artifact encoding changed, so the
successful hour and numerical matrix below remain valid without repetition.
Commands and frozen source identities: `build/native-inference/progress-repair-QA.md`
and `progress-repair-hashes.json`; final verdict/logs: `build/qa-batch-08/report.txt`
and `progress-repair-diagnostics.log` / `progress-repair-startup.log`.
This restores the original +5 NS-3 / +1.25 overall credit, returning to 37% and
62.65%; it creates no additional credit. Historical failed QA submissions remain
one. Review 04 is followed by this one accepted closure.

Historical reopening, now repaired: on 2026-09-21 the supervisor read the shared
progress timestamp before the phase, while the worker wrote the observing phase
before its timestamp. After setup exceeded the five-second stall limit, an
ordinary interleaving could combine the old startup timestamp with the new phase
and terminate a healthy worker as stalled. See the reviewed source paths in
[historical native qualification](../../NATIVE-INFERENCE.md#qualification--2026-09-21).
This violated the existing fourth criterion. Its repair and deterministic
transition regression remained within that task, with unchanged budgets and
retained numerical/resource evidence. Review was not a failed QA submission.
The task's +5 NS-3 / +1.25 overall credit was withdrawn until the focused final
QA above restored acceptance; dependent tasks remained blocked in that interval.

Historical initial completion, before reopening: on 2026-09-21 the maintained
[former optional Win64 observation adapter](../../NATIVE-INFERENCE.md)
and native consumer pass all five criteria on checked stable FPC 3.2.2. Pascal
owns preparation, graph assembly, identity, bounded delivery and supervision;
the pinned external CPU runtime remains outside the portable core/default builds.
The boundary emits raw salience and AC RMS, with no adoption of the failed note
policy or claim of calibrated musical accuracy.

Final QA retains twelve scalar controls, six rate/channel cases, exact batch
replay, both 2,997-row recorded comparisons, five-minute resampling and one
continuous-hour source. The hour produces 360,000 observations in 2,420,266 ms,
with 20,313 ms setup and 103,051,264 bytes peak worker private commitment, within
the frozen 3,630,000-ms/30,000-ms/2-GiB limits. Complete artifact verification and
publication pass. Controlled/recorded maximum activation differences are
3.58e-7 / 7.15256e-7, with unchanged peak-bin choices. Failure, cancellation,
source/policy rejection, atomic sink ownership and accepted-output preservation
pass; successful final runs report no owned leaks.

The first hour submission failed near the setup boundary; its generic error
did not establish the exact phase. The repair overlaps independently verified
source/runtime initialization and joins both before observing, with explicit
phase diagnostics and unchanged limits. Focused requalification and the single
second hour submission pass. Preserve the original failure and the historical
one-failure count; no second failed submission or ownership escalation occurred.

Commands, frozen implementation identities, host and terminal evidence are in
`build/native-inference/` and `build/qa-batch-08/`, especially
`submission2-hour-report.json` and `submission2-hour-heap.log`. Source identity is
`1efecef983467b81e87c9f1a92954ee0f3c9d001a801db06a7aa2fa2c8da5afc`;
model/runtime identities are pinned in the maintained asset manifest. The
reference/key studies earn no additional credit. Provider accuracy, many-hour
whole-pipeline workloads and final target-matrix delivery retain their own tasks.
The initial acceptance added +5 NS-3 points (32% to 37%) and +1.25 overall
(61.4% to 62.65%); reopening temporarily reversed that credit to 32% and 61.4%.
The accepted repair above restores the same allocation once.

**Acceptance Criteria:**

- Consume the accepted [Pascal-only observation backend](NS-3_validation_03.md) and its documented supported scope in the maintained WAV path. No external inference runtime or foreign-language model implementation is an optional path.
- Preserve model and precursor provenance/notices where derived work is retained. Bind the selected Pascal estimator, preparation and reference evidence to exact policy/source identities; no former external-runtime result is inherited as its numerical or cost qualification.
- Set and meet explicit processing-time, peak-memory and observation-density budgets on representative supported durations/rates/channels, including long-source implications; address the roughly 17 processing-seconds/audio-second scalar baseline.
- Enforce bounded batching, cancellation/failure behavior, changed-source/policy rejection and reproducible results through maintained native interfaces. A raised private-study cap is insufficient.
- Expose the selected measurement/admission boundary through the supervised native WAV consumer and reproduce its controlled and recorded development fidelity with source-bound artifacts and cost. Subsequent provider tasks must recheck their own final accuracy and cost; this task does not preaccept them.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)
- [NS-3_validation_03.md](NS-3_validation_03.md)

**Dev Notes:**

- Repaired setup issue: the first hour submission failed near setup with insufficient phase diagnostics. Overlapping verified source/runtime initialization and joining both before observation passed within unchanged limits; the original failure count remains one.

- Repaired race: separate phase/timestamp reads could combine a stale setup timestamp with the observing phase and kill a healthy worker. An atomic combined snapshot and coordinated transition checks restored acceptance in the former runtime path. See [historical qualification](../../NATIVE-INFERENCE.md#qualification--2026-09-21).

- Follow-ups remain [semantic scale](../NS-5_scale_01.md) and [final target delivery](../NS-6_delivery_03.md). Raw salience/AC RMS are not admitted notes or calibrated musical confidence.

- 2026-09-22 architecture change: the user requires Pascal only, without the previously accepted TensorFlow C runtime exception. The historical execution and race repairs remain valid for their old scope but are stopped as a supported backend. Requalify a Pascal-only producer against the unchanged processing, resource, ownership and recorded-input criteria before restoring credit or unblocking downstream work.

- 2026-09-22 native checkpoint: the Pascal periodic-support backend and WAV consumer pass the bounded controls above. Keep the task open for recorded fidelity and full duration/failure qualification; do not extrapolate the 3,000-window probe into an accepted hour cost. The Win32 backend compiles and runs, while the supervised consumer is currently Win64.

- 2026-09-22 recorded reassessment: two batches did not establish the producer acceptance: the first built the Pascal candidate and the second exposed broad support on recorded notes and rests. Stop the absolute-correlation strategy and use a different, explicitly sparse spectral hypothesis under the fixed gate above. The earlier top-12 recall gate alone was non-discriminating. Keep all five criteria and zero task credit open until a replacement qualifies; do not run an hour for this rejected candidate.
