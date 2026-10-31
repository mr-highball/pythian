# NS-4_graph-controls_01 — Coordinate musical dimensions and selective regeneration

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Accepted — 2026-10-31
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

- [Optional musical laboratory — DONE](NS-6_optional-lab_01.md) — restores the
  authored key/tempo/expression/affect consumer orphaned by the simple rewrite.

- [Streamed decision replay — DONE](NS-4_decision-replay_01.md) — ordinary
  playlist jobs now retain and replay their actual notes/providers without
  learning/solving. Sound and scoped passage follow-ups reuse these decisions.

- [NS-4_assignment-restore_01 — DONE](NS-4_assignment-restore_01.md) — preserve generated
  assignment ownership while reopening durable accepted sessions.
- [NS-6_instrumental-progress_01 — DONE](NS-6_instrumental-progress_01.md) —
  actual finite instrumental progress now shares bounded durable publication.
- [NS-6_sourcefree-draft_01 — DONE](NS-6_sourcefree-draft_01.md) — optional
  musical material now reopens correctly in authored and explicit-recipe drafts.
- [NS-4_instrumental-runtime_01](NS-4_instrumental-runtime_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss: AC1–AC4 now pass with the reachable optional laboratory
  at5e52f25 and the retained passage/sound consumers atf8e51a0. The laboratory
  closes the missing key/tempo/expression and editable affect consumer; actual
  authored paired audio and no-job helper checks supplement the portable shared
  control checks. Scope/lock/preferences and retained role/passage dependency
  changes preserve unrelated states and actual PCM as recorded below. Native
  signed settings and Before receipts retain real lineage; contradictions,
  Stop and previous-version recovery pass in ordinary desktop/390px Studio.
  The WFC-independent DTO repair1f548dd passes complete
  [CI529](https://github.com/mr-highball/pythian/actions/runs/41231955864).
  CI528's metadata-only build failure remains preserved. UI/native closing
  evidence is in `optional-lab-20261031-boss` and `studio-notes-20261031-boss`.
  Accept seven units only now that the optional consumer prerequisite passes;
  do not infer graph visualization, deeper sounds, form or universal learning.

- 2026-10-31, Big Boss: CI528 at f8e51a0 rejects the metadata-only catalog
  consumer: the note-edit JSON decoder exported a WFC edit record from the
  native config unit. The authenticated GitHub log and a fresh no-WFC project
  compilation reproduce the same missing-unit failure. Move DTO admission into
  the shared native settings owner, with a WFC-independent typed result; map it
  to the primary edit request only inside the native notes adapter. Do not add
  WFC paths to the metadata-only build to conceal the ownership error. Preserve
  CI528 and projects-no-wfc-build.log under optional-lab-20261031-boss. This is a
  repair of this parent's implementation, not a generic WFC gap or extra credit.

- 2026-10-31, Big Boss: the native/browser Change notes consumer is implemented
  and undergoing final ordinary Studio checks. One common follow-up renderer now
  handles sound edits and note edits, validates actual parent/root receipts and
  replays accepted decisions. Native playlist checks pass290 with the original
  recordings unavailable through child/rechild and sound/note combinations.
  Failure, stale parent, retry and cancellation preserve accepted parents; no
  source learning or accepted partial output is introduced.
  Full-range testing reproduced an artificial internal planning seam: the first
  implementation held original next-chunk states even inside the requested edit.
  Preserve passage-js24-internal-seam-repro.log. The repaired API separates source
  and candidate predecessors and holds the original next seam only outside scope.
  Native Win64 and actual pas2js pass180 checks: selected octave changes continue
  through two chunks, the other five actual PCM stems stay exact, and original
  model weights remain unchanged. The primary preference scope now addresses
  selected child passes correctly; no copied preference mutator remains in the
  editor. Existing replay387/percussion1119 checks pass on both targets with
  clean native heaps. A valid narrower unchanged output or an impossible learned
  pitch is not an implementation failure. No seed sweep or relaxed constraint
  is used to hide those results. The optional-laboratory blocker still prevents
  accepting this seven-unit task.
- 2026-10-31, Big Boss: AC2/AC4's actual durable consumer now passes. Ordinary
  Studio's one-minute parent accepts a full-range child over all15 planning
  chunks:70 of240 musical cells change, actual Lead/mix hashes differ, the model
  digest stays exact and learning_performed=false. Source job
  music-1793466408645-826933; child music-1793469596553-939666. Closing the QA tab
  during the job and reopening resumes that same accepted request. Native
  cancellation at80/240 cells (music-1793470012368-888489) accepts no output;
  Back to previous restores the completed child. An impossible Lead1 request
  (music-1793470115626-304795) displays the concise pitch conflict and preserves
  its parent. Desktop/390px Before/After mix, part playback and Original reference
  load without media errors. Playing one pauses the others; closing part/source
  playback tools pauses them. All QA audio is paused, the managed QA tab/service
  are closed and viewport reset. Proof images and logs live in the same packet.
  The slow E-drive fixture twice required explicit reconnect after submission
  timed out; no job was duplicated. Preserve that latency evidence and one
  transient Windows read-sharing error in qa-error07.log. This is not a speed or
  independent musical-quality claim. The usable consumer closes the batch's
  criteria and resets the carried consecutive nonclosing count from one to zero.
  AC1/AC3's reachable optional consumer remains blocked on the linked laboratory;
  no seven-unit parent acceptance or partial credit follows.

- 2026-10-31, Big Boss: bounded portable passage editor is implemented and checked;
  this is a partial implementation handoff, not AC2/AC4 acceptance. Reconstruct
  actual context, named voices/coverage and separate drum groups with primary
  builders, generated assignment snapshots, dependency closure and independent
  captures. Original models are borrowed unchanged. Held states, outside-range
  notes and both latent seams remain exact. Selected pitch bounds and existing
  root/activity preferences enter the graph; failure/cancellation returns no
  candidate. Initial streams and edits now share percussion frame projection;
  finite/stream/edit consumers share one percussion preference compiler.
  Native Win64 and actual pas2js pass154 focused checks, including real Lead/Hat
  changes, exact other five PCM stems, nine-provider context, partial ranges,
  outgoing conflicts, final cancellation and mismatched source rejection.
  Progress callback counts are separate from assertions. Existing replay387 and
  percussion1119 checks pass on both targets; native heaps are clean. The new
  fixture is in maintained native and optional WFC portability builds.
  Preserve failures in studio-notes-20261031-boss under E-drive runs: source
  guide continuation at cell16; missing imports; new graphs incorrectly wrapping;
  an overconstrained unchanged-seed expectation; an order-one test corpus that
  could not validate hold transitions; and a context test that pinned an
  incompatible authored rhythm. The repaired context fixture lets the actual
  upstream provider select its rhythm and verifies its original projections.
  A Kick-silencing test correctly found no existing Kick hits in its selected
  tail; the actual percussion change uses the present Hat part instead.
  Do not count earlier Node exit0 alone as passing: ad hoc runs now require an
  explicit PASS, and the maintained host propagates rtl.exitcode. Logs remain.
  Native parent/child/rechild publication and desktop/phone Change notes use
  are still required. Keep the normal three steps simple, reuse the score replay
  and native instrument binding, and do not reread sources or retrain. No effort
  units close. Consecutive nonclosing count is one; the next batch must deliver
  the ordinary native/browser consumer or reassess before further implementation.

- 2026-10-31, Big Boss: resume retained role/passage graph edits after the accepted
  saved-clip operator blocker. Ordinary stream journals bind actual provider
  models/states and cell clocks. A bounded edit must prove original provider paths,
  musical/context/drum relationships and both seams before publishing changed
  decisions. Keep unselected states and outside-range cells exact, preserve
  explicit domains and report contradictions. Reuse primary WFC builders,
  assignment ownership, projection functions and the existing score replayer;
  do not substitute a score transpose or start a new learning pass. Stop after
  actual native/browser parent/child use; no partial seven-unit credit.

- 2026-10-31, Big Boss: retained-score sound follow-ups now work in ordinary
  Studio. The optional Change sounds dialog queues a durable native
  instrumental_reperform job, uses the primary score replayer and shares initial
  generation's instrument recipe binding. Parent/root hashes, actual decisions,
  learning receipt, seed and length remain immutable. No source analysis or WFC
  solving runs; changed current playlist choices do not enter this explicit edit.
  Before/After, original reference and Back to previous version remain available.
  Child-of-child edits point directly to the original decision source.
  Native playlist checks pass255 with clean heap: unavailable original payloads,
  exact unaffected five-part PCM, changed bass, exact restoration of the original
  mix, idempotent retry, stale/no-op rejection, missing-note failure and unchanged
  parent records. Desktop and390px browser checks pass: normal Generate, one/two
  sound edits, exclusive playback, completion after page closure, recovery of the
  same job, actual running Stop and previous-version recovery. The minute-long
  UI pair changes only Bass/Harmony stems; Lead and all drums remain exact.
  Preserve the first native failure: an inferred four-character string-list
  element truncated gate_seconds/release_seconds/tone_hz/cutoff_hz field names.
  A typed String constant table fixes the decoder; the isolated probe and failed
  logs remain beside the repaired run in studio-sounds-20261031-boss on E.
  The primary replayer's receipt-extent accessor also compiles and passes the
  existing387 actual pas2js consumer checks. Checked service/worker and all twelve
  matched browser assets are deployed to the fixed stable slot. Sixteen operator
  jobs retain their terminal states. HTTP/LAN HTTPS return200; QA tab/service/
  workers are closed and all QA audio was paused before cleanup.
  No full parent criterion closes: AC2/AC4 still require role/passage/dependency
  regeneration. Consecutive nonclosing count is one. No partial effort accepted;
  accounting stays84/124. Next batch must close the remaining retained graph
  criterion or reassess before further implementation. Four oscillator choices
  do not accept the separate sound-design task. These are solo implementation
  checks, not independent QA or operator musical approval.

- 2026-10-31, Big Boss: selected actual retained-score Studio consumer. Add an
  optional Change sounds result dialog, a durable native replay job and explicit
  Original/Before/After. Parent decisions, seed, learning and unaffected parts
  remain exact; no current-playlist save/retraining gate and no implicit WFC
  solve. Reuse native instrument binding for initial generation and follow-ups.
  Validate actual parent/child/rechild, retry/failure/cancel and desktop/phone
  playback/reopen. Stop before role/passage graph changes; this parent remains
  open until every criterion passes. Packet: studio-sounds-20261031-boss on E.

- 2026-10-31, Big Boss: decision-replay prerequisite accepted after shared native/
  actual pas2js, exact changed-sound/unrelated-part checks and ordinary native
  saved-journal/mix/stem consumers pass. New playlist generations retain actual
  decisions; historical jobs without them do not acquire synthetic state. Next
  wire explicit sound-only follow-ups in the simple Generate result, retaining
  Original/Before/After and immutable parent lineage. Then implement role/passage
  graph changes through validated dependencies. Do not silently relearn/re-solve
  a retained-score sound edit or introduce a mandatory model-editor step.

- 2026-10-31, Big Boss: the current Library→Selection→Generate consumer streams
  every duration and retains no accepted timeline. Follow the linked bounded
  decision-replay prerequisite before wiring follow-ups. Finite plan snapshots
  alone would leave the operator's ordinary learned result unsupported. Preserve
  the existing retained-score/session work; no duplicate engine or compatibility
  shell is selected. The five-unit distinct prerequisite grows the denominator;
  this parent's seven-unit UI/control scope remains unchanged.

- 2026-10-30, Big Boss: Accepted ownership/session restoration now closes the
  demonstrated prerequisite. Actual models, committed controls and assignment
  states reopen without solving, then support ordinary selective regeneration.
  Instrument/context/percussion archive integration, Studio sound follow-ups and
  role/passage edits remain in this seven-unit parent; no partial parent credit.
- 2026-10-30, Big Boss: Durable Studio follow-up batch encountered a demonstrated
  generic restore prerequisite before further scope expansion; see the linked
  assignment-restore task. Plain Entry.Value restoration silently creates caller
  locks. The separate WFC branch is authorized/notified; vendor source stays
  untouched. Actual musical codecs and Studio behavior remain in this parent.
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
  the exact failed controls/seed. [Control semantics](../../MUSICAL-CONTROLS.md) document
  the guide's precedence and experimental mappings. AC2 and the retained-state/no
  model-reconstruction portion of AC4 remain open: every Generate constructs models.
  No seven-unit acceptance, model-cache hit or musical-quality approval is claimed.
- Preserve final unguided seed731/root60/activity40/velocity130 failure at
  harmony-voice pass3 (batch-1793400196578-896606882), and its predecessor before
  upstream activity correction. Explicitly choosing the guide with the same other
  settings completes; this does not prove the unguided conflict repaired. Follow
  its actual diagnostic display in [graph workbench](../NS-4_graph-workbench_01.md),
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
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
