# NS-3_validation_02 — Deliver a practical native inference execution path

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Remove the production execution barrier between promising WAV studies and the maintained Pascal library. Select a viable estimator strategy rather than mandating the current learned models or porting every experiment.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 5 goal percentage points (1.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../../BEAT-TRACKING.md) · [ANALYSIS-WAVE](../../ANALYSIS-WAVE.md).

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
[native qualification](../../NATIVE-INFERENCE.md#qualification--2026-09-21).
This violated the existing fourth criterion. Its repair and deterministic
transition regression remained within that task, with unchanged budgets and
retained numerical/resource evidence. Review was not a failed QA submission.
The task's +5 NS-3 / +1.25 overall credit was withdrawn until the focused final
QA above restored acceptance; dependent tasks remained blocked in that interval.

Historical initial completion, before reopening: on 2026-09-21 the maintained
[optional Win64 observation adapter](../../NATIVE-INFERENCE.md)
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

- Choose and record the production observation/backend strategy and its supported scope; retain Pascal ownership of maintained analysis/tools and keep optional external runtime dependencies out of the portable core.
- For any adopted model or runtime, complete license/notices, acquisition identity, export/preparation and arithmetic-fidelity evidence; for a different approach, provide equivalent reproducibility and reference evidence.
- Set and meet explicit processing-time, peak-memory and observation-density budgets on representative supported durations/rates/channels, including long-source implications; address the roughly 17 processing-seconds/audio-second scalar baseline.
- Enforce bounded batching, cancellation/failure behavior, changed-source/policy rejection and reproducible results through maintained native interfaces. A raised private-study cap is insufficient.
- Expose the selected measurement/admission boundary to native callers and show fidelity and cost on controlled and recorded development inputs. Subsequent provider tasks must recheck their own final accuracy and cost; this task does not preaccept them.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)

**Dev Notes:**

- Repaired setup issue: the first hour submission failed near setup with insufficient phase diagnostics. Overlapping verified source/runtime initialization and joining both before observation passed within unchanged limits; the original failure count remains one.

- Repaired race: separate phase/timestamp reads could combine a stale setup timestamp with the observing phase and kill a healthy worker. An atomic combined snapshot and coordinated transition checks restored acceptance. See [native qualification](../../NATIVE-INFERENCE.md#qualification--2026-09-21).

- Follow-ups remain [semantic scale](../NS-5_scale_01.md) and [final target delivery](../NS-6_delivery_03.md). Raw salience/AC RMS are not admitted notes or calibrated musical confidence.
