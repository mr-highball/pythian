# NS-2_synthesis-quality_03 — Accept combined synthesis and streamed listening

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-2)

**Description:**

Finish the synthesis quality outcome by accepting the complete layered and streamed sounding path, including interactions that isolated source and effect checks cannot establish.

North star: NS-2. Outcome owner: FUND-QUALITY.
Completion credit: 6 goal percentage points (1.50 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [SYNTHESIS-QUALITY](../SYNTHESIS-QUALITY.md) · [FUNDAMENTALS](../FUNDAMENTALS.md) · [SCHEDULING](../SCHEDULING.md).

**Acceptance Criteria:**

- Review the existing combined workload and paired listener preview, then cover any missing supported layered/streamed interaction; distinguish original synthesis from any playback-only gain adjustment.
- Record actual verdicts on attacks/releases, joins, layer balance, spectral motion, tempo changes, uninterrupted holds and final tails, with explicit reviewer and artifact identities.
- Resolve demonstrated combined-path defects; verify deterministic offline/streamed replay and committed-prefix preservation for the changed paths.
- Confirm WAV/MIDI timing, output duration, headroom and declared voice/work bounds still match the accepted musical plan; no new real-time device guarantee is implied.
- Publish a synthesis-quality acceptance record covering the union of the three quality tasks, with no unresolved defect that invalidates the learned-style comparisons.

**Blockers**

- [NS-2_synthesis-quality_01.md](NS-2_synthesis-quality_01.md)
- [NS-2_synthesis-quality_02.md — DONE](DONE/NS-2_synthesis-quality_02.md)

**Dev Notes:**

- 2026-09-23 combined-source listener checkpoint: the user heard the exact
  [11-second listening copy](../SYNTHESIS-QUALITY.md#eleven-second-combined-listener-checkpoint--2026-09-23)
  and said the timing seemed to slow in the middle, while the passage resembled
  music. The planned beat interval changes at 3.2 seconds from 0.5 to 0.625
  seconds (120 to 96 BPM); checked native frame placement and the unchanged
  listening-copy identity support that interpretation. No unexpected timing
  defect is demonstrated. This is a broad review, not a verdict on attacks,
  releases, joins, balance, spectral motion or final tail. Criterion 2, the
  blocked family/processing reviews and task credit remain open.

- 2026-09-23 listener scope correction: the user heard the complete
  [30-second paired preview](../SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20)
  and called it coherent overall. Its shared listening gain and cut-edge
  fades remain distinct from original synthesis. The separate
  [11-second combined-source audition](../SYNTHESIS-QUALITY.md#combined-source-listener-copy--2026-09-23)
  has the later broad feedback recorded above. Neither whole-clip
  observation discharges the blocked family-specific listening or this task's
  attack/release, join and streamed-state verdicts; no criterion or credit
  changes. Do not ask for the already supplied 30-second whole-clip verdict
  again.

- 2026-09-23 numerical plan review: [current checked Pascal runs](../SYNTHESIS-QUALITY.md#combined-numerical-plan-review--2026-09-23) reconfirm the combined 40-note, 11-second WAV's exact tempo/frame placements, bounded 11656 voice work, 145 graph work, headroom, tail and identical 1/257/4096-frame output. A separate saved 88-note plan retains exact MIDI bytes/gates, 729281 WAV frames, 12 peak voices and 795 peak frame-work units through stream replay and a melody timbre edit. **Criterion 4 is met** for these declared plans. The 11-second and family-specific audible verdicts, any demonstrated-defect disposition and union acceptance remain open; the task is blocked by quality_01/02 and earns no completion credit. This criterion closure resets the consecutive nonclosing-batch count.

- 2026-09-23 scope review: the [finite combined interaction map](../SYNTHESIS-QUALITY.md#combined-interaction-coverage-review--2026-09-23) binds the native 11-second mix, complete 88-note sustained performance and existing processing cases to simultaneous sources, automation, tempo changes, held/overlapping notes, routing and final tails. Both gain-adjusted listener copies are identified separately from native synthesis; their hashes match current local files. No further render is needed for this declared scope. **Criterion 1 is met** as an artifact/coverage review, with criterion 2's actual timestamped listening still pending. No task credit moves; this criterion closure resets the nonclosing-batch count.
