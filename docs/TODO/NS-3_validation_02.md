# NS-3_validation_02 — Deliver a practical native inference execution path

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Remove the production execution barrier between promising WAV studies and the maintained Pascal library. Select a viable estimator strategy rather than mandating the current learned models or porting every experiment.

North star: NS-3. Outcome owner: WAV-VALIDATION.
Completion credit: 5 goal percentage points (1.25 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [BEAT-TRACKING](../BEAT-TRACKING.md) · [ANALYSIS-WAVE](../ANALYSIS-WAVE.md).

**Acceptance Criteria:**

- Choose and record the production observation/backend strategy and its supported scope; retain Pascal ownership of maintained analysis/tools and keep optional external runtime dependencies out of the portable core.
- For any adopted model or runtime, complete license/notices, acquisition identity, export/preparation and arithmetic-fidelity evidence; for a different approach, provide equivalent reproducibility and reference evidence.
- Set and meet explicit processing-time, peak-memory and observation-density budgets on representative supported durations/rates/channels, including long-source implications; address the roughly 17 processing-seconds/audio-second scalar baseline.
- Enforce bounded batching, cancellation/failure behavior, changed-source/policy rejection and reproducible results through maintained native interfaces. A raised private-study cap is insufficient.
- Expose the selected measurement/admission boundary to native callers and show fidelity and cost on controlled and recorded development inputs. Subsequent provider tasks must recheck their own final accuracy and cost; this task does not preaccept them.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

