# NS-3_validation_02 — Deliver a practical native inference execution path

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Remove the production execution barrier between promising WAV studies and the maintained Pascal library. Select a viable estimator strategy rather than mandating the current learned models or porting every experiment.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 5 goal percentage points (1.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../BEAT-TRACKING.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md).

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
rejected for recorded specificity; the spectral hypothesis is attempt 2 only
when its fixed evidence is scored. The two nonclosing work batches triggered
the separate Athena progress reassessment recorded in [WORK](../WORK.md#periodic-support-recorded-stop-point--2026-09-22).

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
[historical native qualification](../NATIVE-INFERENCE.md#qualification--2026-09-21).
This violated the existing fourth criterion. Its repair and deterministic
transition regression remained within that task, with unchanged budgets and
retained numerical/resource evidence. Review was not a failed QA submission.
The task's +5 NS-3 / +1.25 overall credit was withdrawn until the focused final
QA above restored acceptance; dependent tasks remained blocked in that interval.

Historical initial completion, before reopening: on 2026-09-21 the maintained
[former optional Win64 observation adapter](../NATIVE-INFERENCE.md)
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

- Choose and record a Pascal-only production observation/backend strategy and its supported scope. All new executable inference, including experimental probes, and maintained analysis/tools must use Pascal-owned code with FPC/RTL; no external inference runtime or foreign-language model implementation is an optional path.
- Preserve model and precursor provenance/notices where derived work is retained. Bind any selected Pascal estimator, preparation and reference evidence to exact policy/source identities; no former external-runtime result is inherited as its numerical or cost qualification.
- Set and meet explicit processing-time, peak-memory and observation-density budgets on representative supported durations/rates/channels, including long-source implications; address the roughly 17 processing-seconds/audio-second scalar baseline.
- Enforce bounded batching, cancellation/failure behavior, changed-source/policy rejection and reproducible results through maintained native interfaces. A raised private-study cap is insufficient.
- Expose the selected measurement/admission boundary to native callers and show fidelity and cost on controlled and recorded development inputs. Subsequent provider tasks must recheck their own final accuracy and cost; this task does not preaccept them.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- Repaired setup issue: the first hour submission failed near setup with insufficient phase diagnostics. Overlapping verified source/runtime initialization and joining both before observation passed within unchanged limits; the original failure count remains one.

- Repaired race: separate phase/timestamp reads could combine a stale setup timestamp with the observing phase and kill a healthy worker. An atomic combined snapshot and coordinated transition checks restored acceptance in the former runtime path. See [historical qualification](../NATIVE-INFERENCE.md#qualification--2026-09-21).

- Follow-ups remain [semantic scale](NS-5_scale_01.md) and [final target delivery](NS-6_delivery_03.md). Raw salience/AC RMS are not admitted notes or calibrated musical confidence.

- 2026-09-22 architecture change: the user requires Pascal only, without the previously accepted TensorFlow C runtime exception. The historical execution and race repairs remain valid for their old scope but are stopped as a supported backend. Requalify a Pascal-only producer against the unchanged processing, resource, ownership and recorded-input criteria before restoring credit or unblocking downstream work.

- 2026-09-22 native checkpoint: the Pascal periodic-support backend and WAV consumer pass the bounded controls above. Keep the task open for recorded fidelity and full duration/failure qualification; do not extrapolate the 3,000-window probe into an accepted hour cost. The Win32 backend compiles and runs, while the supervised consumer is currently Win64.

- 2026-09-22 recorded reassessment: two batches did not establish the producer acceptance: the first built the Pascal candidate and the second exposed broad support on recorded notes and rests. Stop the absolute-correlation strategy and use a different, explicitly sparse spectral hypothesis under the fixed gate above. The earlier top-12 recall gate alone was non-discriminating. Keep all five criteria and zero task credit open until a replacement qualifies; do not run an hour for this rejected candidate.
