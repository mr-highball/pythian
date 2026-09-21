# NS-3_validation_02 — Deliver a practical native inference execution path

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Remove the production execution barrier between promising WAV studies and the maintained Pascal library. Select a viable estimator strategy rather than mandating the current learned models or porting every experiment.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 5 goal percentage points (1.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../../BEAT-TRACKING.md) · [ANALYSIS-WAVE](../../ANALYSIS-WAVE.md).

Completed 2026-09-21: the maintained [optional Win64 observation adapter](../../NATIVE-INFERENCE.md)
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
Acceptance adds +5 NS-3 points (32% to 37%), +1.25 overall (61.4% to 62.65%).

**Acceptance Criteria:**

- Choose and record the production observation/backend strategy and its supported scope; retain Pascal ownership of maintained analysis/tools and keep optional external runtime dependencies out of the portable core.
- For any adopted model or runtime, complete license/notices, acquisition identity, export/preparation and arithmetic-fidelity evidence; for a different approach, provide equivalent reproducibility and reference evidence.
- Set and meet explicit processing-time, peak-memory and observation-density budgets on representative supported durations/rates/channels, including long-source implications; address the roughly 17 processing-seconds/audio-second scalar baseline.
- Enforce bounded batching, cancellation/failure behavior, changed-source/policy rejection and reproducible results through maintained native interfaces. A raised private-study cap is insufficient.
- Expose the selected measurement/admission boundary to native callers and show fidelity and cost on controlled and recorded development inputs. Subsequent provider tasks must recheck their own final accuracy and cost; this task does not preaccept them.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)
