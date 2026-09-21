# NS-4_layers_04 — Handle changing duration and committed-stream edits

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Complete the timing/edit contract for generated durations and future musical changes while protecting already committed audio.

North star: NS-4. Outcome owner: WFC-LAYERS.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [LAYERS](../LAYERS.md) · [PERFORMANCE](../PERFORMANCE.md) · [SCHEDULING](../SCHEDULING.md) · [LEARNED-STREAMS](../LEARNED-STREAMS.md).

**Acceptance Criteria:**

- Define a supported staged or negotiated policy for durations selected during generation, including recalculated cumulative timing and dependent context coverage.
- Demonstrate key/tempo/rhythm/voice edits around changing-duration boundaries, including sounding holds, unknown spans, finite endpoints and unequal provider resolutions.
- Define and enforce the stream commitment boundary: emitted samples and committed note/effect state remain immutable, while supported future changes are scheduled explicitly.
- Verify rejected, conflicting or over-budget edits preserve the accepted future plan where promised; document terminal processing/I/O failures and recovery separately.
- Use actual WFC continuation/model identities and native scheduling contracts; a saved style is not misrepresented as a resumable stream checkpoint.

**Blockers**

- [NS-4_layers_03.md](DONE/NS-4_layers_03.md)
