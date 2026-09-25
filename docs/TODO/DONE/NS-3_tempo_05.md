# NS-3_tempo_05 — Preserve bounded beat candidates on authored controls

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Deliver the independently usable Pascal beat-candidate pool, source and policy
ownership, and selected-clock link on authored controls. This is the
source-independent half of the original [beat-candidate task](../NS-3_tempo_04.md),
split after repeated recorded-source qualification stops. The result gives
downstream beat-level selection genuine alternatives and explicit uncertainty;
it does not certify recorded pulse recall or choose a musical beat level.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 1 goal percentage point (0.25 overall points), transferred
from the original unearned +2 NS-3 / +0.50 overall allocation of
[NS-3_tempo_04](../NS-3_tempo_04.md). The two tasks together retain +2 / +0.50;
creating this file earns no credit.

Starting evidence: [BEAT-TRACKING](../../BEAT-TRACKING.md#maintained-phase-family-measurement--2026-09-19) · [BEAT-GRIDS](../../BEAT-GRIDS.md) ·
the existing checked candidate/clock boundary and consumer in
`build/beat-pool-link/RESULT.md` (ignored local evidence).

Accepted 2026-09-25: the already maintained Pascal pool, `TBeatTrackWindow`
and selected-clock link retain source/policy identity, exact alternative
indices, unchanged alternatives and deterministic caller replay. Checked
FPC 3.2.2 Win32/Win64 beat/track/clock fixtures and the authored WAV consumer
passed as recorded in ignored `build/beat-pool-link/RESULT.md`; regular,
polyphonic and changing-rate tracked controls report 24/24, 20/20 and 24/24,
while the polyphonic fixed-grid top remains visibly wrong. A new pre-run
hash-bound authored policy and focused maintained Pascal control under ignored
`build/beat-candidate-authored-acceptance/` checked 60/120/240 BPM, competing
120-BPM phases, no admitted input, <4 insufficient observations, 1,602 zero-fit
trials, local rejection, suppression and capacity as distinct cases. Both
checked stable targets passed with zero leaks and identical discrete counts:
990 positive fitted trials, 800 local eligibility rejections, and bounded
8/16-candidate pools. Test SHA-256 is
`975c982069d12e6070a1da2a1d8748ba06bfa162fbd55c7c782ebcfc65171cc7`;
the private result records exact commands, policy/log/executable hashes and
scope limits. Salty Boi's focused QA accepted this complete authored contract
and ledger correction. Empty input is only no admitted onset, not proven
acoustic silence; no recorded pulse recall, beat-level selection, learned
style or user listening verdict is claimed.

**Acceptance Criteria:**

- Freeze exact authored control identities, expected rate/phase alternatives,
  candidate policy, eligibility, support and work bounds before the final
  validation run. Expose plausible fast, half/double-time and same-tempo
  competing-phase candidates in the bounded pool; report their availability
  separately from the selected path. Reference annotations may score a saved
  pool but must not enter its construction.
- On source-free controls, distinguish insufficient or absent observations,
  no fitted proposal, proposal rejected by local eligibility, nearby
  suppression and capacity loss. Do not call an unsupported source beat
  physically absent; this task makes no recorded acoustic truth claim.
- Expose every surviving alternative through maintained Pascal WAV observation,
  `TBeatTrackWindow`, path reselection and selected-clock contracts with exact
  candidate indices, source coordinates, policy identity, uncertainty and
  deterministic replay. A selection must leave unused alternatives intact;
  availability or a top score is not musical confidence.
- Pass focused checked native boundary, failure and work tests on the changed
  path and its consumer, including the declared authored rate/phase and loss
  controls. Retain stable/deceptive/polyrhythm/changing-rate regression evidence
  with its actual limits. Obtain Salty Boi QA of the complete bounded scope.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-25 split after the GMD, GuitarSet, BeatNet+ and KRAISLER source routes
  failed their frozen source qualification gates. The maintained pool/clock
  boundary and consumer already passed focused Win32/Win64 QA; authored
  regular/polyphonic/changing-rate lab results are 24/24, 20/20 and 24/24.
  A static artifact audit found that the saved changed-path report does not
  itself bind the maintained 60/120/240-BPM and competing-phase assertions or
  the complete controlled loss taxonomy. The bounded Pascal authored-control
  validation above closed that gap. Recorded candidate recall,
  the ARTBeaT 02/04 unknowns and source-separated challenge remain solely in
  [NS-3_tempo_04](../NS-3_tempo_04.md); no credit moved merely with the split.
