# NS-6_studio_01 — Select and preserve an operator training project

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Give the sole operator a clear web entry point for a caller-named style project:
describe the musical intent, select imported recordings and optional source-time
ranges, understand the selection, and save/reopen it without losing work.
This is a reusable project contract, not accepted training or a musical verdict.
See the [studio scope and credit map](../../OPERATOR-STUDIO.md).

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 4 goal percentage points (0.40 overall points).
Basis: [2026-09-30 operator allocation](../../OPERATOR-STUDIO.md#allocation-and-ownership).
Primary credit is independently usable operator setup. NS-5 still owns actual
learning and style quality; consuming its APIs earns no duplicate credit.

Execution status: accepted 2026-09-30 after independent combined native/browser
QA and Big Boss's UI review. The maintained project store, HTTP boundary and
responsive source-selection page satisfy AC1–AC5. Checked native tests pass
89 assertions on each stable Win32/Win64 target with zero leaks; actual browser
selection, exact source-time Save/reload, conflict/lost-response recovery,
keyboard, empty/error states and desktop/narrow layout pass. No training run,
musical verdict or physical-phone qualification belongs to this acceptance.

**Acceptance Criteria:**

- AC1: Deliver a Pascal project contract and native service consumer binding a
  caller style name/intent to imported source identities and explicit original
  frame ranges. Reject unknown sources, invalid ranges, duplicate/conflicting
  selections and unsupported values before publishing a revision. Preserve
  unverified source/song/exposure facts; a selection does not approve labels.
  Draft creation checks metadata/header geometry with bounded work and clearly
  defers full content verification/admission to asynchronous training preflight.
- AC2: Provide a responsive, keyboard-usable Studio page with searchable source
  selection, full-recording defaults and optional time-range controls. Explain
  the current action in plain language; show selected unique time and recording
  count, empty states and actionable inline errors. Exact frames/IDs belong in
  details. No horizontal page overflow at a 390-pixel viewport.
- AC3: Save and reopen durable project revisions through the web service.
  Distinguish unsaved, saving, saved and conflicted state; preserve entered work
  after failed Save and reconcile an identical retry after a lost response.
  Concurrent or stale changes cannot silently overwrite accepted state.
- AC4: Show selected material separately from material actually used in a model.
  A draft reports not trained, not zero-quality or completed learning. Supported
  learning mode and unavailable next actions have honest explanations. Preserve
  the source-review and full-output listening routes and core independence.
- AC5: Independently validate native malformed/stale/retry/reload boundaries and
  real desktop/narrow browser selection, editing, Save and fresh-page reload.
  Check labels, focus, contrast/readability, touch targets and error recovery.
  Retain screenshots and scoped evidence; physical-phone qualification remains
  in authoring_02, not inferred from viewport emulation.

**Blockers**

- [NS-6_authoring_01.md](NS-6_authoring_01.md) — accepted.
- [NS-5_corpus_05.md](NS-5_corpus_05.md) — accepted.

**Dev Notes:**

- 2026-09-30, Big Boss: user selects operator-driven musical review and asks for
  intuitive, powerful web preparation. Existing imported-source browsing and
  listening responses do not implement project setup. Neo owns new store/tests;
  Ticket Guy owns new Studio UI files; Big Boss owns existing service/build
  integration. Prior authoring/comparator failures remain with Big Boss and are
  not reset by this new task. New task has no submitted QA failures. No acceptance
  or credit follows from scoping.
- 2026-09-30, Big Boss: pre-QA integration review found that normal catalog
  imports may be unassigned. Neo preserves that uncertainty in draft snapshots;
  training preflight remains studio_02's responsibility. Parser failures must
  produce sanitized validation errors, and native Windows filesystem calls
  require explicit unit qualification. Retained development traces are under
  ignored `build/studio-projects/` and `build/studio-integration-dev/`.
- 2026-09-30, Big Boss / Ticket Guy: development review also identified focus
  loss when deselecting a selected row hidden by the active search, and stale
  range validity after switching full/range modes. Both need actual browser
  regression checks in the first QA submission. UI compiler corrections and
  frozen source identities are retained under `build/studio-ui-dev/`. These
  development corrections are not failed final-QA submissions; acceptance
  remains with the [combined batch](../../WORK.md#current-priority-decision--2026-09-30).
- 2026-09-30, Big Boss / Salty: first submitted UI QA has one blocking clarity
  finding. The future Listen/Refine text says only that it follows generation,
  leaving the current absence of training/generated previews ambiguous. Retain
  the initial desktop/narrow screenshots and actual DOM under ignored
  `build/salty-studio-20260930/`. Ticket Guy owns a concise upcoming-stage copy
  repair after the remaining frozen checks; no new controls. UI failure count
  is one; Neo's native component has zero failed QA submissions. Focused copy
  verification may reuse unchanged functional/native evidence.
- 2026-09-30, Salty / Big Boss: final scoped acceptance passes all five criteria.
  Native source/range/parser/stale/retry/immutable-revision checks pass on both
  checked stable targets. Actual browser saves range 4000..12000 plus an unassigned
  full 16000-frame source, reopens exact selections on a fresh page, preserves
  edits through disconnect/422/409, reconciles a dropped actual POST response,
  and confirms the identical retry adds no revision. Evaluation is excluded;
  draft model/use state remains empty and pending verification.
  Keyboard Tab/Space, search/no-match, invalid-range/full/range, optional intent,
  required-name errors, source/listening navigation and nine assets/MIME pass.
  At the 390-pixel viewport, the scrollbar leaves client width 375; scroll width
  also equals 375 with no overflowing elements. Upcoming-stage copy is explicit.
  Screenshots, native/browser logs, final identities and cleanup evidence remain
  under ignored `build/salty-studio-20260930/`. Successful drivers are leak-free;
  exact QA browser/profile/listener cleanup is zero. Retained runner argument,
  native-confirm and empty-fixture setup errors are orchestration evidence, not
  product failures. The first repaired UI clarity failure is retained; native
  failures remain zero. The subsequent final-staging failure is recorded below.
  This closes one implementation batch and awards 4 NS-6 / 0.40 overall points;
  old source/science/comparator stop counters are unchanged. Actual jobs and
  source audition continue in [studio_02](../NS-6_studio_02.md), and musical
  feedback/iteration in [studio_03](../NS-6_studio_03.md).
- 2026-09-30, Big Boss: final staging finds whitespace-only blank lines 84/103
  in the new HTML; earlier unstaged checks had not included that untracked file.
  Count this as Ticket Guy's second failed UI submission under the user's strict
  transfer rule. Big Boss takes over the UI implementation and repairs those
  lines plus the missing terminal newline. Ticket Guy moves to the separate
  ready studio_02 UI-state planning assignment, with no implementation before
  its job contract freezes. Native failures remain zero. The validated HTML
  `72e34a9a...` and final `888f569d...` differ only in formatting; preserve both
  identities and the diff, and validate final staging without repeating browser
  behavior. Salty retains final QA/publication ownership. No criteria or credit
  are weakened by this repair.
