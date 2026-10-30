# NS-4_graph-controls_01 — Coordinate musical dimensions and selective regeneration

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Expose coordinated context, pitch/register, rhythm/groove, articulation, dynamics, timbre/effects and operator-defined musical affect through real graph/control relationships. Use additional axes or passes where useful; grow the schema from audible needs rather than a fixed giant grid.

Primary attribution: NS-4. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Provide explicit dependencies and controls for key/tempo, harmonic choices, role pitch/register, rhythmic activity and expression. Define how each control constrains a pass, changes a preference, or maps to synthesis automation.
- AC2: Support hard locks, soft preferences and scoped regeneration of a role, passage or dependent closure. A user can retain drums while changing harmony/lead, or retain the score while changing sound, when dependencies permit.
- AC3: Represent coarse affect controls such as energy, density or tension by editable documented mappings. Do not pretend a label is automatically understood or scientifically inferred.
- AC4: Demonstrate paired actual instrumental outputs and preserved unrelated accepted states. Report contradictions visibly, allow revision, and avoid silently relaxing a user constraint or retraining when only generation settings change.

**Blockers**

- [NS-6_instrumental-progress_01 — DONE](DONE/NS-6_instrumental-progress_01.md) —
  actual finite instrumental progress now shares bounded durable publication.
- [NS-6_sourcefree-draft_01 — DONE](DONE/NS-6_sourcefree-draft_01.md) — optional
  musical material now reopens correctly in authored and explicit-recipe drafts.
- [NS-4_instrumental-runtime_01](DONE/NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Retained-score runtime slice implemented as the atomic
  TInstrumentalPlan.Reperform operation and detached CopyScore. Initial generation
  and edits now share primary PlanNoteVoiceTones; the adapter's copied per-role
  score loop is removed. Selected-order seeds preserve the prior per-part planner
  and are independent of unrelated gates. New sound/expression planning does not
  construct, learn or solve models. Actual six-part, multi-part, restoration,
  noncompounding expression, observer/reentry, early/late cancellation and later
  instrument-rejection cases pass128 on Win32/Win64/actual pas2js, with clean native
  heaps. Models/tokens/states and unselected PCM stay exact. A player constructed
  before an edit retains its original performance. Existing control208 and context
  material1439 checks pass on all three targets; native runtime74472 passes on both.
  Actual before/after WAVs remain synthetic QA evidence under retained-score-20261030-boss
  in E-drive runs, not published operator reviews. Ordinary native Studio checks
  pass56 on both targets, including actual running cancellation. AC2/AC4 remain
  incomplete until durable Studio
  use and actual role/passage/dependency regeneration pass. No effort units earned.
- Preserve the first native old-player assertion failure: it compared scheduler
  Double values directly with stored Single PCM. The corrected check stores both
  through the same sample type and demands exact equality; no epsilon or audio
  mismatch is hidden. Preserve the pas2js compiler rejection of a literal fractional
  Integer test assignment; that unrepresentable test was removed. Public role/index
  guards still reject nonwhole runtime values. Initial failure logs live beside the
  corrected target logs. Solo validation is not independent QA or listening approval.
  The existing core instrument fixture also passes native and actual pas2js without
  vendor unit paths after its native-only StdErr/Halt exception exit is made
  conditional. That test-harness compilation failure is preserved; no product
  semantics or fixture expectations are relaxed.
  No full criterion closes in this bounded runtime batch; the carried consecutive
  nonclosing count is now one. The full seven-unit task stays open without split
  credit. Next batch must deliver the ordinary Studio follow-up and retained graph
  regeneration; if it also fails to close a criterion, reassess before another batch.
- 2026-10-30, Big Boss: Next bounded AC2/AC4 batch delivers retained-score
  reperformance through the primary instrumental runtime. Replace one or several
  pitched instruments/expressions without learning or solving; preserve accepted
  graph decisions and unchanged parts. Stage the complete performance before
  committing, including readiness callbacks. Closing checks: actual six-part PCM,
  exact tokens/states/other parts, noncompounding expression, failure/cancellation
  preservation and shared native/pas2js behavior. Stop after the public API and
  actual audio consumer. Durable Studio restoration and role/passage graph
  regeneration remain required follow-on work in this task, not implied acceptance.
  Previous batch is progress and closes two concrete prerequisites; carried
  consecutive nonclosing count starts at zero.
- 2026-10-30, Big Boss: The AC1/AC3 slice is implemented through ordinary Studio.
  Shared controls pass26 and the actual instrumental consumer passes208 on Win32,
  Win64 and actual pas2js, with clean native heaps. The same-seed authored density
  pair performs1 versus8 attacks and different PCM; six-part checks cover pitch
  bounds, expression, unchanged other-part audio on a common padded timeline and
  unchanged accepted WFC tokens under expression. The actual joint-context consumer
  admits paired maximum preferences961. Studio native checks pass56 on both targets;
  final HTTP guide/root/activity/velocity receipts, page-close completion, playback,
  solo, Stop and desktop/narrow layout pass. The helper invalidates checked settings
  without queuing work. Explicit hard conflicts and unguided graph failure reopen
  the exact failed controls/seed. [Control semantics](../MUSICAL-CONTROLS.md) document
  the guide's precedence and experimental mappings. AC2 and the retained-state/no
  model-reconstruction portion of AC4 remain open: every Generate constructs models.
  No seven-unit acceptance, model-cache hit or musical-quality approval is claimed.
- Preserve final unguided seed731/root60/activity40/velocity130 failure at
  harmony-voice pass3 (batch-1793400196578-896606882), and its predecessor before
  upstream activity correction. Explicitly choosing the guide with the same other
  settings completes; this does not prove the unguided conflict repaired. Follow
  its actual diagnostic display in [graph workbench](NS-4_graph-workbench_01.md),
  rather than sweeping seeds or silently pinning it. No generic WFC defect is
  established. Preserve the initial missing test-unit import compiler failure too.
- Actual pas2js checks caught a record alias: validation with a for-in local then
  assigning that same local modified the last caller control. Indexed validation
  removes the alias; caller controls and score are unchanged. Shorter expression
  gates legitimately shorten a release tail; compare unrelated PCM on the same
  padded timeline rather than requiring identical output extents. Both failures
  remain under graph-controls-20261030-boss in E-drive evidence. Browser harness
  observation timeouts did not resubmit work: inspect the durable job first. The
  final POST endpoint is /api/studio/job, not /api/studio/jobs. CDP was reconnected
  to the same browser after an observer reset; no new browser/profile was started.
- Source review caught an ineffective placement: changing only voice attack weights
  cannot steer a rhythm provider that has already fixed those actions. Activity now
  weights the upstream joint-rhythm vocabulary, using a bounded mean of active role
  preferences; it is not counted again downstream. The focused authored sparse/dense
  pair must change actual note attacks and PCM with the same seed, supplementing
  the six-part checks. Empty vocabulary cannot acquire new rhythms from a label.
- The affect helper changes input values programmatically, so it must emit the
  normal settings-change event. Otherwise an already checked setup could submit
  old settings while displaying new values. Final browser QA must cover Check
  setup → apply helper → Generate disabled until a fresh Check, with no job queued.
- 2026-10-30, Big Boss: The initial1+abs(bias) curve admits individual weights101
  but rejects legal simultaneous root/selected-role UI controls in actual joint
  context (combined10201 exceeds1024). The added real context consumer reproduces
  EAudio; preserve joint-bias-before-run.log. Use the explicit documented1..31
  curve instead (maximum paired961), with actual context-admission checks on native
  and pas2js. This changes the new unpublished mapping, not an upstream WFC limit;
  no generic solver fix or silent dropping of a requested preference is introduced.
- 2026-10-30, Big Boss: Select AC1/AC3 control semantics and their actual Studio
  consumer first. Deliver explicit hard pitch bounds, soft attack/tonic preferences,
  velocity/gate expression and editable coarse affect mappings; preserve the authored
  guide as an explicit choice rather than hiding its fixed rhythm/harmony. Reuse
  primary note/percussion performance and actual WFC masks/preferences, with no
  replacement solver or implicit retraining. Closing evidence: checked native and
  actual pas2js shared semantics, real paired native outputs and saved UI choices,
  visible conflicts and desktop/narrow interaction. Stop after this bounded control
  path; follow retained score/role/passage regeneration in the next slice. The complete
  task and its seven units stay open until all criteria pass. Prior batch closes
  experimental learning; the consecutive nonclosing count starts at zero.
- 2026-10-29, Big Boss: TLearnedLayerSession/TNamedVoiceSession preferences, masks, provider replacement and dependency closure already exist. Add domain mappings and expose them through one shared consumer.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
