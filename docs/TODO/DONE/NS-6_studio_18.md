# NS-6_studio_18 — Keep Studio tasks and help in context

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Repair the scrolling-heavy Studio workflow identified by the operator. Present
real tabs with smaller steps inside, keep Save within reach, and show shared help
in a dismissible modal that preserves the invoking control and page position.
Use the existing Pascal presentation adapters and mounted tools; do not duplicate
learning, media, persistence or queue behavior.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 0 additional points. This repairs the usability of already
credited studio_01/17 outcomes; it does not create extra completion credit.
The real operator verdict in studio_03 remains independently required.

Selected batch: Big Boss solo, as requested by the user. Criterion advanced:
AC1/AC2 below. Deliverable: tabbed Studio and shared modal help. Closing evidence:
matched pas2js build plus actual desktop/narrow Codex Browser navigation,
keyboard, focus/scroll restoration and unchanged-state checks. Stop on lost edits,
hidden required controls, unsolicited media/jobs, or inability to return from help.

Accepted 2026-10-02 by Big Boss under the user's solo UX instruction. Source
`2725742130c1680ad774747483b077c6bcff7fb2` passes the matched pas2js build and actual
390px/1280px Codex Browser checks. Evidence: `build/studio-tabs/QA-VERDICT.md`,
`browser-checks.json`, screenshots and fourteen frozen artifact hashes. The
matched bundle is deployed in the fixed stable slot; all 3,943 existing operator
JSON hashes are unchanged. All owned tabs and QA processes are closed. No extra
credit; physical-phone and musical/operator verdicts remain separately open.

**Acceptance Criteria:**

- AC1: Sources, generation and review display one stage at a time. Sources have
  smaller project/library/passage/capture steps; auditions, long playback, jobs
  and settings have separate views. Review separates setup, feedback and history,
  with tabs for paired samples. Selection and next-batch actions reveal their
  actual destination. Save and current stage stay reachable without traversing
  unrelated stages. Switching tabs preserves unsaved fields, selections and
  mounted tool state. Tabs expose selection, panel associations and keyboard use.
- AC2: Help shared across all three pages opens as a modal, keeps background
  interaction out of its tab order, closes by visible button or Escape, and returns
  to the invoking control and scroll position. Reading never submits, saves,
  records or plays. Explicit Show me can reveal a nested tab/disclosure; missing
  prerequisites are explained. Narrow layouts have no horizontal overflow.
- AC3: Test against authored isolated data, preserve the real operator catalog,
  deploy matched assets to the fixed stable slot, and close all owned QA tabs and
  processes. Record limitations honestly; no physical-phone or musical verdict
  is inferred from browser mechanics.

**Blockers**

- [NS-6_studio_01.md](NS-6_studio_01.md)
- [NS-6_studio_17.md](NS-6_studio_17.md)

**Dev Notes:**

- 2026-10-02, Big Boss: the prior guide passed mechanics, but the operator's actual
  use exposed excessive scrolling and help jumping away from the task. This
  linked repair is mandatory; previous mechanical evidence does not override
  that feedback. No additional milestone percentage is allocated.
- The implementation follows WAI's [tabs](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/)
  and [modal dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) interaction
  patterns. Native dialog supplies modality; Pascal owns orchestration.

- Accepted checks include saved draft/range/classification readback, native
  audition completion, comparison history, paired answers preserved across tabs,
  next-batch routing, keyboard tabs, contextual modal return on all three pages,
  unavailable prerequisites, deep links and stopped source playback. No native
  algorithm changed; unrelated native suites were not rerun.
- Repaired missing-attribute tab selection, hidden-step Save errors and help
  return focus. A screenshot review moved generation setup into Settings and
  placed feedback Save in its own bar. Final desktop dimensions were explicitly
  checked after discovering an earlier screenshot still used the narrow view.
- The remaining [actual operator verdict](../NS-6_studio_03.md) must come from
  real use; this repair does not close it. Consecutive nonclosing count: 0.
