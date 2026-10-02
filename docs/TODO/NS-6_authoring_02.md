# NS-6_authoring_02 — Verify physical LAN listening and final operator use

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Close the actual operator listening path and full end-to-end QA after the
editor/queue contract is accepted. The native Pascal service owns media,
sessions and durable commits; the Pascal/pas2js pages provide the operator UI.
A desktop or emulated narrow-screen pass does not substitute for an audible
physical-phone playback and successful Save on the selected private LAN.

North star: NS-6. Outcome owner: WAV-05-AUTHORING.
Completion credit: 1 goal percentage point (0.10 overall points).
Current allocation: [2026-09-30 operator rebalance](../OPERATOR-STUDIO.md#allocation-and-ownership), with NS-6 weighted at 10 overall points,
under the user's authorization
to rebalance without preserving historical point allocations. All existing
acceptance criteria remain required; this plan revision earns no acceptance.
Allocation rationale: Actual physical LAN listening and full operator QA establish usable, audible feedback rather than isolated UI mechanics.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [editor and queue](DONE/NS-6_authoring_01.md) ·
[LAN procedure](../LAN-REVIEW-SERVICE.md) · [review queue](../REVIEW-QUEUE.md) ·
[phone Save repair](../WORK-HISTORY.md#phone-save-request-header-repair--2026-09-29).

Execution status: **explicitly resumed for Big Boss's solo usability review;
open and unaccepted**. The 2026-10-01 request supersedes the earlier deferral
below and the usual delegated QA assignment for this batch. Big Boss performs
implementation and browser QA alone; physical-phone evidence remains required.

Prior scope and preserved history:
The user's later 2026-09-30 direction selects the
[Studio workflow](../OPERATOR-STUDIO.md), beginning with project/source setup.
Generated-listening usability and any required shared operator repair may advance
for that named consumer. This does not select another mechanical marker prompt
or infer physical-phone acceptance. All criteria below remain required.
Big Boss retains repair/integration after two blocked Neo driver submissions.
The first-use phone review exposes unclear question intent and marker/time
feedback; its old blanket workbench deferral is superseded by the Studio scope.
Its only direct downstream task is [final packaging](NS-6_delivery_03.md), also
blocked on full recorded integration and style/blend acceptance. Core synthesis,
WFC and the current NS-3/NS-5 reference/inference gates do not require this task.
Resume only when a concrete ready deliverable actually needs this operator path,
or the user explicitly reprioritizes it; preserve the final-delivery prerequisite.

Retained evidence: the repaired stale-audio reset passes independent negative
and positive desktop/narrow playback/retry QA. Fixed firewall rules and earlier
HTTP boundaries are verified. Long CLI/browser exports match; actual replay
published history but timed out before confirmation. The guarded-verification
repair passes checked Win32/Win64 regressions and independent long duplicate
recovery with exact re-export. Fresh stable-slot startup and both source/paired-listening
physical-phone paths remain open; authoring_01 is accepted. Partial checks earn
no task credit. On resumption, the next deliverable is a comprehensible operator
question/marker workflow followed by the combined physical LAN play/Save check,
preserving all actual reviewed history and failed-run evidence.
Closing evidence: device/network, binary/assets, audible results, durable Save,
reload/report and independent QA records. Stop at missing device/firewall
permission or a concrete failure; record its unblock condition and keep open.

**Acceptance Criteria:**

Own the original authoring checklist points 4, 5 and 10 below, with their
original wording and numbering. The retained detailed D1–D6 bullets and owner
map in [authoring_01](DONE/NS-6_authoring_01.md#retained-original-detailed-criteria-and-owner-map)
are normative: this task closes their LAN/session, physical/audio listening
and complete operator QA portions. Historic checked boxes do not replace a
current combined-path verdict.

- [ ] **4. Private-LAN startup:** Default loopback and explicitly selected
  private-LAN binding work after restart, with no access-key form or credential
  entry. A physical phone on the LAN connects; Host/Origin and same-origin
  session checks remain effective, no token appears in an audio URL, and the
  service is reachable under an installed Private/local-subnet/TCP-port and
  stable-program firewall rule without repeated Windows Defender prompts for
  each new build path.
- [ ] **5. Listen before labeling:** Original and available Pythian cue audio
  load, decode and audibly play on the operator path for 0.5-second, 5-second
  and bounded longer regions. Seek, loop, readiness and errors are clear next
  to the player on a narrow screen. Exercise malformed/unauthorized/range,
  disconnected and slow responses, followed by a successful retry; no silent
  player or `0:00` display is counted as verified sound.
- [ ] **10. Complete QA matrix:** On a copied catalog, run import → Pascal
  proposals → original/cue listening → wrong-suggestion correction → approved
  and unknown answers → queue advance → reload/restart → worker report →
  export/re-import, with at least two source groups and a long-source case.
  Include all error/retry boundaries in points 3–9, actual desktop and narrow
  browser interaction, and the physical LAN phone playback/Save path that
  previously failed. Salty Boi independently validates the frozen binary and
  pas2js assets, records exact evidence and confirms no test answer touched
  the live operator catalog.

- Record exact source revision, fixed-slot binary and all twelve browser asset hashes,
  copied-catalog identities, physical device/browser/network, audible results,
  Save/reload/producer-report evidence and independent Salty Boi verdict.
  Use only the fixed stable/QA executable slots and exact-path firewall setup
  in the LAN procedure. Isolate browser QA, close its exact process tree and
  verify no QA browser or looping audio remains. Never write test answers to
  the live operator catalog.

Physical handoff clarification: retain both the main source-review checks and
the paired `/listen.html` playback/answer Save path whose earlier phone Save
failed with HTTP 431. A successful source-label Save does not retest the distinct
listening-answer endpoint. Reuse the unchanged original paired request/assets
on the dedicated copied catalog, record both producer reports after actual
device feedback, and keep this combined operator review as existing manual
item 7 rather than adding queue entries for its steps.

First-use closure requirements for existing points 5 and 10, from the user's
2026-09-30 phone feedback:

- Before editing, explain in plain language what the listener should identify,
  why that answer is needed and what action completes it. A listening-only
  request must not appear to require a label or musical correction. Keep
  mechanical QA fixtures separate from the ordinary human review queue.
- Beside the touch controls, show the selected position or span in source time
  with sufficient precision, and make its exact source frame available without
  manual conversion. Distinguish playback position, requested listening window
  and pending label boundaries. Update feedback immediately when tapping or
  moving a marker; identify what changed and whether it is saved.
- Keep proposal identifiers, facet names and implementation diagnostics in
  inspectable details. Normal instructions must describe a musical/listening
  decision, not demand an unexplained frame number or internal candidate ID.
- On an actual narrow device, the operator can explain the intended decision,
  see the resulting time/marker change and complete the intended answer without
  developer coaching. Combine this with the existing physical checks when the
  task is selected again; do not claim understanding or audibility from a
  screenshot or an automated pass.

These make the existing human operator acceptance concrete. They add no new
feature family, task credit or prerequisite for the core/learning/WFC paths;
the accepted editor mechanics in authoring_01 retain their scoped evidence.

**Blockers**

- [NS-6_authoring_01.md](DONE/NS-6_authoring_01.md)

**Dev Notes:**

- 2026-10-02, Big Boss: the explicit solo review repairs confusing fixture
  prompts, marker feedback and repeated navigation. Actual Codex Browser tests
  separate optional developer checks from attention counts; save unknown and
  corrected-point answers, reject a point outside the request, reload saved
  answers and clear the unsaved-marker message. Listening tests also play a
  generated request and save its separate response endpoint. Exact-frame
  controls remain available behind a disclosure; seconds are the main input.
  [WORK](../WORK.md#solo-operator-usability-repair--2026-10-01) records the
  frozen artifacts, screenshots and failures under `build/solo-usability/`.
  The user-required solo batch supersedes independent Salty assignment for this
  repair, not the remaining physical and complete-workflow acceptance. No actual
  phone sound, full export/replay matrix or whole-task completion is claimed.

- 2026-10-01, Big Boss: one unearned point transfers to
  [studio_08](DONE/NS-6_studio_08.md) for explicit starting actions, shared queue
  navigation and connection of existing private music. Every physical-device
  and end-to-end criterion here remains required; scoping earns no credit.

- 2026-09-30, Big Boss: user explicitly prioritizes intuitive operator-driven
  training/audition preparation and feedback. New studio_01/02/03 own setup,
  jobs and iteration; this task retains every original physical/source-review
  criterion and failure. Four unearned points move to the Studio allocation;
  no acceptance is inferred. Reuse physical evidence only where the exact
  changed consumer is actually exercised.

- 2026-09-30 user phone feedback and priority decision, Big Boss: the supplied
  Brave screenshot shows an internal instruction to correct a deliberately
  wrong proposal to frame 8784, a one-frame-point instruction and an exposed
  proposal identifier. The user reports not understanding the labeling purpose,
  excessive wording and little frame/time feedback when placing a marker.
  Capture this as a first-use usability problem, not an accepted playback,
  precise placement, Save or restart verdict. The screenshot shows the UI only;
  actual audibility and durable answers remain unverified. The exact frame
  instruction was a mechanical QA control, not a required musical judgment from
  the user. Big Boss owns the mistaken human handoff. Their instruction is to
  continue this task now only if it critically blocks others. Dependency review
  finds only delivery_03 directly blocked, with integration_01 and blends_01
  also outstanding; no upstream synthesis/WFC/reference task is unblocked by
  another phone run. Defer implementation and further user labeling, retain the
  requirements above under existing points 5/10, and resume only for a named
  ready consumer or explicit reprioritization. Prior failures, runtime budgets,
  prerequisite links and zero unearned credit remain intact. The screenshot
  stays private; no device identifiers, private paths or image bytes enter Git.

- 2026-09-30 physical handoff orchestration stop, Big Boss: the dedicated short
  catalog is prepared with four source requests and one original paired request,
  all pending/zero completed. Automatic approval review rejected the combined
  setup/launch command without a specific reason. Salty retried via a script
  before the chief stop arrived; it started the service then failed on the
  reserved PowerShell HOME variable. This retry was an orchestration/policy
  handling error, not product acceptance. Big Boss stopped further launches and
  completed exact accidental-process cleanup: zero stable/QA listeners and zero
  QA browser processes, preserving prepared inputs and evidence. No Save occurred.
  Reserve the full 30-second failed handoff allowance:
  automated total 904.0239101 / 1,050, cold total unchanged. A concrete ordinary-
  terminal operator launcher is prepared under ignored
  physical-handoff; it verifies the fixed binary/assets/interface/rule and runs
  only the existing dedicated catalog. Salty caught an elevation requirement in
  its draft firewall cmdlets; Big Boss replaced them with ordinary read-only
  netsh verification. The repaired preflight passes; its launch path has not
  been agent-executed. No retry,
  reset, physical verdict or task credit follows from this preparation.

- 2026-09-30 guarded recovery accepted by Big Boss after Salty's independent QA:
  native SHA-256 `7215051a64f4c0d494b1854b0bd20ed8d7b7f8d1825293e0e7cff689ce695762`
  and frozen driver submit one 16,141-byte POST, receive HTTP 200 with exact
  duplicate status and download a packet matching prior CLI/browser SHA-256
  `ab753f47dd7ae30c99b93f28ccfc58b67861da5c05d65bf316256b21b3e02b6e`.
  Existing revision-one history is preserved. Both native targets also pass
  fresh short import, duplicate and same-size corruption rejection before
  publication, with zero leaks. The long recovery takes 55.4574401 seconds;
  automated usage is 874.0239101 / 1,050 and conservative cold/copy usage is
  573.8977266 / 720. Browser/comparison logs have zero leaks and cleanup has
  zero QA listeners/profile processes. Earlier fresh long replay remains
  incomplete evidence, not relabeled success. No more long reads or retries.
  Both fixed slots now contain the qualified native and browser assets. Big Boss
  releases only the prepared 30-second dedicated short phone-service handoff,
  covering both source-review and original paired-listening endpoints. Physical
  audible play, both actual Save/reload paths and full task acceptance remain open.

- 2026-09-30 actual replay timeout and chief repair: one valid 16,141-byte POST
  published all three revision-one journals and the linked proposal, but exceeded
  its 120-second cap before HTTP 200/re-export. Preserve that history and test
  recovery as a duplicate, not a reset fresh import. Big Boss replaces replay's
  separate hash-and-close with the existing immutable source guard used by final
  packet verification. Qualify fresh import, duplicate replay and cold same-size
  tamper rejection before publication on checked Win32/Win64, then both native
  builds. Only after these and independent frozen-input review pass may Salty
  run one changed 120-second recovery requiring HTTP 200 duplicate and exact
  re-export bytes. One cold long read, 1,559,617,614 bytes, is authorized; no copy.
  Carry 812.5293219 automated seconds forward and prospectively extend the ceiling
  from 870 to 1,050 for this repair and targeted regression. Cold/copy reservations
  are 518.4402865 / 720 seconds, including the entire last operation. Stop at the
  first failure without retry. Earlier worker failures and nonclosing batches
  remain counted; no criterion or physical verdict is accepted by this change.

- 2026-09-30 physical coverage correction, Big Boss: the prepared four source
  requests and source-label unknown Save omitted the previous paired-listening
  Save failure on `/listen.html`. Chief review of existing manual item 7 and the
  retained phone failure identifies this as an untested part of original point
  10, not a new goal. Neo receives only disjoint preparation of the original
  paired request and existing ten-second assets; no product/driver repair,
  rendering, inference, long read or live-catalog edit. Hold stable launch until
  this original endpoint and source-review checks share a concrete copied-input
  handoff. Listening answers must reflect what the user actually hears. No extra
  manual row, worker-count reset or credit follows from correcting the plan.

- 2026-09-30 corrected fresh/no-queue control passes: actual short-source
  selection reveals the work column, hit-tested pointer interaction submits
  exactly one 16,141-byte POST, and semantic HTTP 422 confirms admission reached
  the two-versus-three source-count guard before hashing or writing. Heap and
  cleanup are zero; cumulative automated runtime is 691.7212953 seconds.
  This evidence-backed repair changes the next action to the first actually
  submitted long replay and durable three-track packet equivalence. Big Boss
  prospectively adds 150 seconds to the original automated ceiling (870 total),
  preserving all prior consumption/failures and the 120-second operation cap.
  Authorize two required integrity reads, 3,119,235,228 logical bytes, no media
  copy and one same-process cached re-export. Conservatively retain both failed
  attempts as possible cold work (120 and 112.8143733 seconds); known copy/export
  plus reservations totals 397.6322599 seconds of the unchanged 720-second cold
  allowance. First failure stops without retry. Success permits at most a further
  30-second prepared phone-service handoff, never a physical listening verdict.
  No criterion, task or count is reset by this explicit ceiling extension.

- 2026-09-30 two-nonclosing replay reassessment: the final instrumented attempt
  retained no POST and no imported history. Big Boss identifies a concrete
  driver failure: a fresh no-queue catalog has a hidden work column until a
  source is selected, but the driver clicked its hidden import control. It also
  matched the initial "No reviewed packet imported" text as success. That PASS
  line is invalid; native header rejections are not evidence about an absent
  import POST. The driver now selects the exact short source, verifies actual
  source geometry and visible/enabled hit-tested controls, requires a POST within
  five seconds, and accepts only the explicit imported status plus exactly one
  HTTP 200 POST. Preserve the failed source/executable and 112.8143733 seconds;
  automated consumption is 678.6483254 of 720 seconds, with no heap-zero claim
  for the terminated driver. The reassessed next deliverable is a single
  25-second framing check on the existing fresh two-track/no-queue short catalog.
  It must reach semantic HTTP 422 for the unchanged three-track packet, before
  any source hash or write. Stop on failure; no automatic long retry, budget
  reset, original-task reopening or task credit follows. Earlier counts remain.

- 2026-09-30 transport diagnostic and final replay authorization: the same
  16,141-byte packet travels through the normal UI with an exact 16,141-byte
  POST and reaches semantic HTTP 422 in the two-track short catalog. This
  source-count rejection occurs before hashing or writing; heap and cleanup
  are zero. The diagnostic consumes 11.372771 seconds, taking automated usage
  to 565.8339521 of 720 seconds. No product parser change is justified by this
  passing transport check. The first replay's 431 cannot be conclusively bound
  to its POST because the old observer retained no request verdict. Big Boss
  permits one final replay with five-second progress/request snapshots and
  immediate error failure, under the same enclosing 120-second cap. Reuse the
  still-fresh destination and exact downloaded packet. Authorize at most two
  required integrity reads, 3,119,235,228 logical bytes, with no new media copy;
  conservatively charge the earlier failed replay its whole 120 seconds and
  up to two possible reads because actual progress is unknown. Known copy/export
  times plus that conservative debit total 284.8178866 seconds of the separate
  720-second cold/copy allowance. No count resets or exactly-six-pass claim.
  Stop at the first failure with no further retry; full physical/task criteria
  remain open even if the replay succeeds.

- 2026-09-30 long-phase stop and chief reassessment: the corrected stale-media
  probe and positive desktop/narrow playback/recovery pass; the existing short
  review state and producer report retain the correction, second-group unknown
  and original long revision one. The exact final five-second long region
  plays. Fresh native CLI export (42.1990536 seconds) and browser export
  (49.359542 seconds) pass with identical 16,141-byte packets, SHA-256
  `ab753f47dd7ae30c99b93f28ccfc58b67861da5c05d65bf316256b21b3e02b6e`.
  These execute two approved cold verifications; bounded playback is not a full
  source hash. Fresh replay exceeded its enclosing 120-second limit and stopped
  with no published history. Its server reports HTTP 431 with an implausible
  21,823,487-byte header count; no successful replay or cold-pass count can be
  inferred from the wait. Preserve failed logs under ignored
  `build/qa-authoring-operator-20260930/long-phase/`. Automated consumption is
  554.4611811 seconds, with all previous failed submissions/debits retained.
  Big Boss authorizes one 25-second framing diagnostic: submit the same packet
  through the normal UI to an existing two-track short catalog. The destination
  track-count rejection precedes source hashing, so expected HTTP 422 isolates
  transport without reading the long recording or publishing an answer. The
  driver now records body byte counts and fails promptly on an explicit replay
  error instead of waiting after rejection. Stop on any unexpected verdict;
  no long retry, new read allowance or physical launch is implied.

- 2026-09-30 rebuilt media reset submitted for final QA: Big Boss adds the
  explicit media reload to all three source-clearing paths; the qualified
  pas2js build passes and QA serves the new six-asset set. The first repaired
  negative probe is inconclusive: decoded state resets to no data, unknown
  duration and zero clock, but its oracle incorrectly requires an empty
  currentSrc or rejected play promise. The retained URL behavior is documented
  in [WHATWG issue 10410](https://github.com/whatwg/html/issues/10410); it is not
  proof that media remains playable. Preserve this failed probe and its
  31.7198813-second debit, taking automated consumption to 278.3741521 seconds.
  The corrected probe samples actual Play ten times over one second, requiring
  no source attribute, no decoded/buffered data, unknown duration, zero clock
  and no resolved play promise throughout. Positive original/cue/retry checks
  remain required. Exact rebuilt assets and corrected driver are frozen under
  ignored `build/authoring-media-reset/READY-r4.json`. No product failure,
  long integrity read, full-criterion closure or counter reset follows from
  this browser-observer correction.

- 2026-09-30 confirmed product failure and repair reassessment: after loading
  a half-second development source, switching to the other recording's ten-
  second window and failing the new request, the native media control still
  played the old blob (clock 0.09527, duration 0.5, unpaused) while the UI named
  the new source and said no region was loaded. Salty's corrected source-bound
  probe proves the old/new blob identity under ignored
  `build/qa-authoring-operator-20260930/private-audio-stale-chief-r2/`;
  it saved no answer and used no long integrity read. Both earlier wrong-source
  QA probes and the chief probe's repaired missing separator remain evidence,
  including the two failed probe exception heaps; they prove no product result.
  Big Boss owns the fix: explicitly reload the native media element after
  clearing its source during track/window changes and media errors, discarding
  the decoded old resource. Criterion 5 is advanced by source-correct playback
  after selection/failure; closing evidence requires this exact negative probe,
  positive original/cue recovery and durable workflow preservation against the
  rebuilt assets. Stop on stale playback, failed current playback, identity or
  budget mismatch. The stopped batch has consumed 246.6542708 automated seconds;
  two source copies consumed 73.259291 seconds and all four cold guards remain.
  These carried-forward limits and two blocked Neo submissions are not reset.
  No acceptance or credit follows until the full operator/device criteria pass.

- 2026-09-30 mandatory repair transfer: two known blocked Neo final-QA
  submissions transfer implementation, this task and failure evidence to Big
  Boss. Submission one contained unquoted numeric CSS selectors. Submission
  two fixed those selectors but its observer assumed relative API URLs;
  current FetchApi sends absolute URLs, so session capture, fault matching and
  transport filters were invalid. Salty observed the actual loaded source and
  two waiting requests with no browser errors; native session/Host/Origin/
  malformed/write-token boundaries passed. This is a submitted driver defect,
  not demonstrated product failure. Preserve both frozen submissions and logs,
  older unknown cumulative counts and the same batch's 75.3959822-second runtime
  debit. Salty's separate missing-inbox-manifest runner failure is retained but
  not attributed to the implementation worker. Cleanup and unfreed blocks are
  zero; no browser audio or long cold verification ran. Chief repair is isolated
  under ignored `build/authoring-operator-chief-repair/`; Neo/Ticket continue
  only disjoint physical-control preparation. No acceptance or credit follows.

- 2026-09-30 first blocked submitted driver: after the QA handoff and before
  browser execution, Neo found unquoted numeric CSS selector values in Request
  and Audio. Big Boss counts one known blocked authoring_02 implementation
  submission; older cumulative counts remain unknown/retained. Original driver
  and manifest bytes are preserved. The two-selector repair compiles checked
  Win64 and is refrozen in ignored
  `harness/ASSEMBLED-submission2.json` SHA-256
  `510bb2cb0edc7aeb5a8b6967ad6cd2552ecf9162f04b43a23f683c42140bcacd`.
  Same-batch Salty review resumes; second blocking implementation submission
  transfers to Big Boss. No product failure, source read, count reset or credit.
  Separate empty-inbox and missing-merger-path orchestration errors are retained
  in private runner/preparation evidence and are not attributed to product behavior.

- 2026-09-30 runnable candidate frozen: ignored
  `build/authoring-operator-plan/harness/ASSEMBLED.json` SHA-256
  `f3078945823e50fb2b9ce834a9bd6c08424788dadc36f6246e02d3c8a1dfee4c`
  binds current binary/six assets and actual assembled inputs/checked Win64
  Pascal drivers. Salty's same-batch runtime remains pending; no credit.
  Two long copies finished in 73.259291 seconds, four cold guards remain.
  Two pre-QA queue-admission rejections are retained: missing frozen short
  proposal JSON and then its directory-placement error. Exact source-hash path
  repair verifies the three unchanged packets and admits two waiting short
  requests plus original long completed revision-one history, with zero leaks.
  No analyzer rerun, additional long read, product failure or final-QA submission
  occurred. Prior failures/unknown cumulative task counts remain unchanged.

- 2026-09-30 selected bounded preparation after accepted authoring_01:
  [WORK](../WORK.md#current-physical-lanoperator-preparation--2026-09-30) records
  exact criterion/deliverable/evidence/stop. Neo owns task/WORK/integration;
  Ticket Guy exclusively prepares ignored `build/authoring-operator-plan/controls/`
  with the existing two 20-second source assets and unchanged metadata, fresh
  copied-catalog CLI import/proposals and actual initial-state/evidence inventory.
  Neo owns the complex A+B driver under disjoint ignored `harness/`; Ticket
  authors no integration driver and may compile supplied code only by explicit
  handoff. Verify
  actual history from journals/API; do not infer no events from missing locks.
  Existing evaluation concealment stays intact, and cue uses legitimately
  available development proposals. Salty alone runs fixed-slot isolated QA
  after both startup/session and audio/current combined-workflow components are
  ready. Transfers are at most ten seconds; waits stop at 45 seconds, slow/retry
  at 90 seconds and automated runtime at 12 minutes, excluding preparation/user
  wait. Big Boss approves the long phase: two copies plus four cold integrity
  verifications, exactly 9,357,705,684 long-source read bytes and 3,119,235,228
  copied write bytes, at most 120 seconds each and 720 seconds total separate
  from automated runtime. Ticket owns disjoint ignored `long-controls/` copies
  only; no standalone rehash/long import/inference or early export. Salty's final
  combined state must pass one fresh-output CLI export, actual browser packet
  equivalence and fresh source-only replay preserving original history/metadata.
  Count any additional unavoidable read before execution; first defect/overrun
  stops without retry or integrity bypass. Physical audible phone play/Save remains
  external under the existing queued item 7. Prior physical silent-player and
  HTTP 431 failures, repairs and unknown cumulative task counts remain attached;
  no reset, new musical ground truth, partial credit or full acceptance follows.
- 2026-09-30 frozen short controls: fifteen current native runs pass with zero
  leaks and both fresh catalogs have actual revision-zero/empty histories. Two
  requests wait. Original 0.5/5/10-second playback is required; available cues
  are 5/10 seconds. Big Boss's criterion interpretation preserves the valid
  half-second packet's empty candidate list as unavailable/disabled cue behavior,
  never a played cue or permission to crop/relabel a different window. Physical
  listening must retain the same availability matrix.
- 2026-09-30 current prerequisite status: the user installed the exact fixed QA
  rule and Big Boss verified its enabled Private/local-subnet/inbound TCP scope,
  fixed QA program path and assigned Private interface. Big Boss also verified
  the exact fixed stable rule, matching current binary and unused stable port.
  No further administrator action is currently indicated. These preflights do
  not qualify restarted stable startup, physical-phone playback/Save or the
  complete operator matrix. authoring_01
  is now accepted; this dependent task earns no credit until its own complete
  criteria pass.
  The dated missing-rule records below preserve their historical status.
- 2026-09-29 current complete-goal credit basis: this task owns 8 NS-6
  goal points (+0.80 overall) by deliverable value. Nine open NS-6
  tasks allocate 85 goal points (+8.50 overall); the accepted contract and
  native checkpoint allocate 15 goal points (+1.50 overall), with zero baseline.
  Lifecycle support and actual ecosystem adoption are now explicit required
  outcomes. Earlier point amounts and conserved split totals are historical,
  superseded by this user-directed scope reassessment. Criteria and evidence
  requirements remain intact; planning earns no acceptance.


- 2026-09-29 the split preserves original points 4, 5 and 10 and every
  associated detailed acceptance condition. Current evidence includes a
  physical-phone Save failure with HTTP 431 and focused cookie/header repair;
  the repaired isolated 390 px path is not the physical-phone retest. The
  exact-path QA firewall rule requires a one-time elevated install before
  another isolated server/browser run; see the linked LAN procedure and work
  record. Next deliverable: a copied-catalog full matrix plus the actual
  physical LAN play/Save verdict using the frozen current assets. Stop at a
  missing device/firewall permission or concrete failure, record the unblock
  condition, and keep this task open. No musical ground-truth, independent
  consumer or final style credit follows from accepting this operator path.

- 2026-10-01, Big Boss: one further unearned point funds
  [studio_09](DONE/NS-6_studio_09.md)'s actual large-collection refresh prerequisite.
  Current allocation is 2 goal / 0.20 overall points; every physical and
  complete-workflow criterion remains required. No acceptance follows from
  this transfer.

- 2026-10-01, Big Boss: one further unearned point transfers to
  [studio_10](NS-6_studio_10.md) for trusted phone HTTPS/certificate onboarding.
  Current allocation is 1 goal / 0.10 overall points. Every original physical
  and complete-workflow criterion and earlier failure remains required; neither
  scoping nor browser emulation qualifies the actual phone verdict.
