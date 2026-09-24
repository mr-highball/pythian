# NS-3_notes_05 — Admit source-grounded note-presence evidence

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver a reusable Pascal observation of audible instrument activity and
uncertainty separately from pitch identity. It must distinguish evidence for
attack, continuation, release-tail candidate and rest without treating an
annotation end, nonzero PCM, or a high pitch score as proof of an audible note.
The later [event-decision task](NS-3_notes_02.md) owns integration with pitch,
event boundaries and the shared recorded phrase gates.

North star: NS-3. Outcome owner: WAV-03-BOUNDARIES.
Completion credit: 1 goal percentage point (0.25 overall points), reallocated
from the original 3 unearned points of NS-3_notes_02. The two tasks retain
the original 3-point total with no new credit.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: the accepted [source-bound reference packet](DONE/NS-3_notes_04.md),
its fixed Pascal activity consumer's 7/8 held-out result, and the
[recorded boundary evidence](../PHRASE-EVALUATION.md#residual-boundary-emission-audit--2026-09-20).
The user-inaudible flute late tail is a visible false-active result at RMS
0.000999; the quiet audible guitar late tail must remain protected. Both exact
zero rest controls are too easy to establish recorded noise rejection. The
extra NSynth train and first-stem URMP development selectors were stopped at
their frozen metadata gates before listening/scoring; neither can be repaired
by changing its failed pair or window in place.

The first frozen GuitarSet listener packet is now bound and scored. The
[source-bound review](../PRESENCE.md#first-listener-bound-guitarset-comparison--2026-09-23)
meets criterion 1's reference-convention and source-group separation at this
packet scope; criteria 2 and 4 were already met at the maintained observation
and consumer scope. Development yielded four correct rest-compatible decisions
but no scored guitar-positive window. The reserved recording yielded one
correct contrast candidate and one guitar-positive abstention. Criterion 3
and all task credit remain open; this evaluation recording is now exposed and
cannot become a fresh held-out test after a policy change.

**Acceptance Criteria:**

- Establish a source-bound development/reference convention for audible
  instrument sound, explicitly separating note control, residual audio,
  room/electronic noise, and unknown. Retain source-group disjoint roles and
  human or independently supported acoustic labels before scoring. Protect
  untouched evaluation groups; the now-exposed NSynth train result cannot be
  silently reused as a fresh held-out test for a replacement rule.
- Expose a maintained Pascal pitch-independent presence observation with
  explicit activity/unknown evidence, source-frame coordinates, policy identity
  and bounded work. Do not infer a note-off or audible ending from one fixed
  RMS gate or nonzero samples.
- Prospectively freeze the decision, resource budget and stop gate, then pass
  meaningful source-free low, quiet, short, gap, attack, tail, rest and mixture
  controls plus source-separated recorded development and independent cases.
  Report false-active, missed-active and unknown coverage separately; retain
  an audible quiet-tail case and expose failures rather than retune on the
  independent packet.
- Exercise the maintained observation through a native consumer that preserves
  unknown and original source coordinates. Demonstrate deterministic checked
  target replay and failure preservation; this task does not grant combined
  event-decoder or recorded phrase accuracy.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
- [NS-3_notes_04.md](DONE/NS-3_notes_04.md)

**Dev Notes:**

- 2026-09-23 development-onset stop and independent handoff: a two-aid
  follow-up froze the first 250 ms after each existing player-01/02 selected
  event onset, but its no-other-note annotation gate failed before onset PCM
  read, playback or scoring. No window was replaced. Reassessment treats the
  already exposed, user-reviewed player-05 positives and same-source rest as
  development evidence only. The newly frozen player-03 Rock2-85-F solo source
  is player/material-disjoint; checked Pascal verified its JAMS geometry and
  archive identities before mic extraction. Three exact repeated aids 12–14
  have matching checked stable Win32/Win64 manifest SHA-256
  `879a1e81180c3690d9e945805468fe9b7dafb09f51783f9868b7c6d713b0c934`,
  zero leaks, and preflighted binders. The unchanged observation and
  same-source reference/score rule were frozen before review. User labels
  for player 03 are pending; no new inference or criterion 3/task credit.
- 2026-09-23 first real listener-bound score: the user clarified that 1, 4,
  5 and 6 sounded piano/keyboard-like rather than guitar; 2, 3 and 9 were
  inaudible; 7 and 8 sounded like acoustic guitar. A checked Pascal binder
  verified all nine aids and produced identical Win32/Win64 reviewed packets.
  The frozen production scorer chose source-local reference clips 1, 4 and 9.
  Win32/Win64 development results match exactly: four correct rest-compatible
  windows, zero positives. The reserved source produced one correct contrast
  candidate and one guitar-positive abstention, with zero false-active or
  missed-active decisions; all runs report zero leaks. This closes criterion 1
  at the declared packet scope, while criterion 3 remains open because there
  is no positive development sensitivity and the independent positive has
  only one of two candidates covered. Do not retune the fourfold/1.5-fold
  ratios to clip 8 or treat the exposed player as held-out again. A new
  prospective development-positive reference and fresh independent source
  are needed before changed-decision acceptance. No task credit.
- 2026-09-23 private score binding repair: the first scorer accepted a
  self-hashed synthetic review without independently checking its manifest or
  listener input. The production Pascal runner now requires the frozen
  manifest, all aid hashes, exact reviewed source rows and normalized label
  rows before source scoring. Two synthetic packets still replay byte-for-byte
  on checked stable Win32/Win64 with zero unfreed blocks; wrong input, manifest,
  reviewed label and source WAV reject before output. A separately compiled
  synthetic fixture mode cannot be used by the production binary, which
  rejects the fixture manifest. This repairs review integrity only; no real
  GuitarSet labels, recorded result or task credit exist yet.
- 2026-09-23 focused API/consumer acceptance without listening: criteria 2
  and 4 are met at their stated observation and native-consumer scope.
  Fresh checked stable FPC 3.2.2 Win32/Win64 builds passed the focused
  source-free controls with zero unfreed blocks. The original 264,000-frame,
  24-kHz stereo WAV emitted byte-identical hash-bound inspector rows on both
  targets (TSV SHA-256
  `22639cfffd9a372c9aed7bbdfaa5cd0a10196b18ac2e9ca4aa0ddc803c08b327`):
  the 100,000-frame candidate crosses the WAV read chunk, retains original
  coordinates and reports `unknown` for an unreviewed rest. A wrong source
  hash rejected before a TSV row; the unit controls also cover partial reads,
  bounds, work cap and prior-result preservation. The inspector now rehashes
  the full source after observation and before output; fresh checked
  Win32/Win64 builds preserve the exact TSV replay and zero-leak result.
  This closes no recorded acoustic or event-decision gate. Criteria 1 and 3,
  including the pending user-reviewed development/evaluation packet, remain
  open; no task credit.
- 2026-09-23 score-runner preparation: the private ignored packet's Pascal
  scorer binds the binder output SHA-256, verifies original WAV identities,
  uses the frozen lowest-numbered same-source rest rule, and separates
  development from reserved evaluation. A synthetic three-source fixture
  exercised no-reference, correct-candidate, false-active, unknown-label,
  missed-active, exact-zero correct-rest and abstention routing. Checked stable
  Win32/Win64 score TSVs were byte-identical with zero unfreed blocks; a wrong
  reviewed hash rejected without output. No real listener labels have arrived,
  so neither the real
  binder nor the scorer has run on GuitarSet. Recorded calibration, independent
  cases and task credit remain open.
- 2026-09-23 listener handoff preflight: a private Pascal binder under the
  ignored recorded packet verifies the frozen manifest and all nine aid hashes
  before it will accept exactly nine ordered guitar/other-noise/nothing/uncertain
  labels. Checked stable Win32/Win64 preflight passed with zero unfreed blocks.
  It has not run its bind mode, created reviewed labels or scored inference;
  the user's one-pass review is pending. The frozen score policy chooses only
  same-recording listener-confirmed no-guitar windows as rest references and
  reserves player 05 from tuning. Stop packet preparation here; no extra clip
  or reference selection is justified without the review. No task credit.
- 2026-09-23 recorded listening packet prepared after the observation API
  batch: a new frozen GuitarSet policy selected three distinct player and
  broad musical-family recordings before microphone extraction. The stopped
  player-00 packet was not relaxed; player 05 is prospectively reserved for
  acoustic evaluation after its annotation eligibility had been exposed but
  before its microphone audio, human labels or inference score were used.
  Checked Pascal reverified archive/JAMS/WAV hashes and PCM geometry, then
  made nine unchanged-gain 250-ms windows repeated for mobile listening.
  Win32/Win64 aid manifests match SHA256
  `7151d48e59515633f0e2ac02a9f932581a254de7370de2a68a2d5c5b1d04c91c`;
  every repeated PCM segment matches its source and both targets reported
  zero unfreed blocks. Human guitar/noise/silence/uncertain labels are pending.
  No scored recorded result, calibrated presence claim or task credit follows
  from aid preparation.
- 2026-09-23 maintained observation boundary after source reassessment:
  [PRESENCE](../PRESENCE.md) defines control, signal, audible instrument and
  event separately. `src/pythian.presence.pas` now measures exact candidate and
  disjoint same-source rest windows through clip and 64-bit streaming APIs,
  with fixed policy identity, work caps, contrast evidence and explicit unknown.
  The native WAV inspector retains source hash/geometry and rejects a wrong
  hash before output. Checked stable Win32/Win64 source-free controls and a
  100,000-frame stereo consumer path passed with zero unfreed blocks. This
  advances the observation/API and consumer criteria; it makes no audible-note
  or recorded score claim. A 30-ms 55-Hz low sine at peak 0.005 remains
  `unknown` against a 0.001-RMS rest, with its measured RMS retained; this is
  visible missed-active coverage, not permission to retune the frozen ratio.
  The rest reference's `reviewed` flag remains a
  caller assertion needing source-bound acoustic evidence. Recorded
  development/independent cases, broader controls and QA acceptance remain
  open; no task credit is earned.
- 2026-09-23 second nonclosing source batch and reassessment: a frozen
  annotation-only GuitarSet screen audited all 360 JAMS members in checked
  stable Win64 Pascal, excluding three publisher-named timing/duplicate-note
  cases. Seventy-three recordings have at least two fully isolated candidate
  ends, but reserved player 00 has zero, so no player/material-disjoint
  three-recording packet exists under the predeclared gate. It stopped before
  microphone audio, listening or scoring; no threshold or split was changed.
  Together with the stopped two-recording inventory, this reaches the task-flow
  checkpoint. Change the next action from repeated source selectors to the
  maintained pitch-independent evidence/unknown contract and source-free
  controls. Recorded calibration and independent cases remain open; the
  player-00 result cannot be treated as an acoustic label or a reason to tune
  a presence threshold.
- 2026-09-23 full-overlap result: checked Win64 Pascal verified the two
  GuitarSet JAMS hashes and 105/57 note events, rounded annotation times to
  exact 44.1-kHz source frames, and required no other note throughout three
  consecutive 250-ms windows surrounding each annotated end. The comp
  excerpt has zero eligible events; the solo excerpt has two. Both share BN1
  musical material and are development players. This two-recording route
  stopped before a listening selector, labels or scorer. These annotation
  windows have no acoustic audibility ground truth; a future recorded packet
  needs prospectively distinct player/material roles and direct listening.
- 2026-09-23 read-only source inventory: the official
  [GuitarSet](https://guitarset.weebly.com/) microphone and hexaphonic-pickup
  annotation routes are separately recorded. Existing verified archives and
  two extracted development-player microphone WAVs are present locally.
  Checked stable Win64 Pascal inspection confirmed both are 44.1-kHz mono
  PCM16 with 984,506 frames; two JAMS members parse with 17 annotations each.
  The prior native feasibility audit lists six/two preliminary note-onset-gap
  events; it did not exclude other notes sustaining into a candidate rest.
  No source window, acoustic label or scorer was chosen in this inventory.
  The two guitar examples alone do not prove cross-instrument transfer.
- 2026-09-23 split after two consecutive nonclosing NS-3_notes_02 batches:
  the extra NSynth train filter lacked a positive two-family pair after
  exposure exclusions; the first-bound URMP violin stem lacked a post-end
  candidate in the frozen cohort. Both stopped before labels or scores. This
  task owns a reusable observation and source-grounded calibration; the
  remaining [NS-3_notes_02](NS-3_notes_02.md) keeps event integration,
  pitch/register coordination, timing/unknown semantics and recorded gates.
  A new source route must be justified by what those failed gates could not
  supply, with labels frozen before a new candidate is scored. No task credit
  follows from creating this file.
