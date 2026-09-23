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

- 2026-09-23 read-only source inventory: the official
  [GuitarSet](https://guitarset.weebly.com/) microphone and hexaphonic-pickup
  annotation routes are separately recorded. Existing verified archives and
  two extracted development-player microphone WAVs are present locally.
  Checked stable Win64 Pascal inspection confirmed both are 44.1-kHz mono
  PCM16 with 984,506 frames; two JAMS members parse with 17 annotations each.
  The prior native feasibility audit lists six/two preliminary note-onset-gap
  events; it did not exclude other notes sustaining into a candidate rest.
  No source window, acoustic label or scorer was chosen
  in this inventory. The next batch must check full annotation overlap before
  freezing player/lead-sheet roles and exact windows, verify annotation
  identities, and obtain direct listening
  labels; the two guitar examples alone do not prove cross-instrument transfer.
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
