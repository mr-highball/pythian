# NS-3_tempo_04 — Qualify bounded beat candidates from WAV

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver reusable, source-bound candidate evidence for beat period and phase
before deciding which candidate is the musical pulse. A retained pool must
expose plausible half/double-time and competing-phase explanations, plus
missing or unsupported evidence, through the maintained native tracker and
clock boundary. Its successful result is candidate availability and bounded
provenance, not automatic beat-level selection.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 2 goal percentage points (0.50 overall points), split from
the original 5 points of [NS-3_tempo_01](NS-3_tempo_01.md).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md#candidate-survival-and-path-diagnosis--2026-09-19) · [BEAT-GRIDS](../BEAT-GRIDS.md).

**Acceptance Criteria:**

- Freeze source windows, annotated development groups, candidate identity,
  eligibility, per-window support and a candidate-only challenge group before
  scoring. Fix availability/coverage and work limits prospectively; do not use
  the later untouched whole-track timing evaluation group for tuning.
- Preserve true fast, half/double-time and same-tempo competing-phase
  alternatives on the declared authored controls and source-separated recorded
  challenge, within a bounded candidate pool. Report reference-compatible
  candidate recall at the declared 30-ms timing tolerance separately from the
  path's selected beat accuracy; a reference may identify a missing candidate
  only after inference has saved the pool.
- Distinguish absent source pulses, distractor observations, fitting omission,
  candidate suppression and capacity loss. Missing or ambiguous evidence stays
  explicit rather than becoming an invented pulse or a reference-selected band.
- Expose the qualified pool through maintained Pascal WAV observation,
  `TBeatTrackWindow`, path reselection and selected-clock contracts with exact
  candidate indices, source coordinates, policy identity and deterministic
  replay. A selection must not erase its unused alternatives; no downstream
  caller may treat availability or a top score as musical confidence.
- Pass checked native boundary, failure and work tests on the changed path and
  its consumer. Retain the original stable/deceptive/polyrhythm/changing-rate
  controls as regression evidence; this task does not claim their beat-level
  acceptance or change the stopped metrical experiments' verdicts.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-23 publisher archive audit: the already acquired official zip has
  [25 mixed WAVs and paired beat CSV/MIDI annotations](../BEAT-TRACKING.md#publisher-archive-contents-checked--2026-09-23),
  but no listed stems or source-event MIDI. Its beat MIDI cannot identify which
  arpeggio or drum event supplied a pulse in a failed 02/04 window. This
  resolves the earlier uninspected-archive uncertainty without source-pulse
  truth, a candidate-policy change or completion credit. Stop this archive
  route; the task still awaits independently aligned source evidence.

- 2026-09-23 publisher source-pulse inventory: an independent read-only
  [official-page check](../BEAT-TRACKING.md#publisher-source-pulse-inventory--2026-09-23)
  lists whole-mix beats for ARTBeaT 02/04 but finds no listed stems, score/events
  or source-separated pulse labels. The archive contents were not inspected, so
  absence is not proven. Its arpeggio/drum description cannot classify failed
  windows. This and the shared-waveform subtraction stop are two consecutive
  nonclosing source-evidence batches. Suspend 02/04 policy fitting until an
  independently attributable pulse reference is aligned to the exact WAV clock;
  preserve the frozen gates and reports. No criterion or credit closes.

- 2026-09-23 post-reassessment shared-arpeggio screen: the publisher calls
  ARTBeaT 02/03/04 openings the same arpeggio, so a frozen Pascal check tested
  whether their exact original WAVs share a subtractable intro waveform.
  [Both fixed comparisons](../BEAT-TRACKING.md#shared-arpeggio-source-isolation-screen-stopped--2026-09-23)
  failed the predeclared gain and -60-dB residual gates; normalized residuals
  were .983200 and .990077. Stop waveform subtraction without another slice
  or threshold. This is one nonclosing batch after the omission reassessment;
  no source-pulse truth, retained-candidate change or credit follows. Seek
  independently reviewable source-pulse evidence before a new fit/retention
  policy attempt.
- 2026-09-23 second post-freeze batch: the optional [native omission trace](../BEAT-TRACKING.md#current-policy-omission-stage-trace)
  reproduces every saved candidate pool and fit-work count without reference
  input to inference. The 02 failures split into one no-compatible-fit, three
  local-peak-filtered and one suppressed proposal; 04 splits into three
  no-compatible-fit, one peak-filtered and two capacity losses. Admitted onsets
  near annotated beats and other onsets in the owned intervals are reported
  separately. Their acoustic meaning remains unadjudicated: absence of an
  admitted onset does not prove absence of a source pulse. The frozen 02/04
  candidate gates still fail and criterion 3's source-pulse distinction remains
  open. This is the second consecutive nonclosing batch since criterion 1;
  stop pool experiments and follow the [work reassessment](../WORK.md#beat-candidate-omission-reassessment--2026-09-23).
- 2026-09-23 first post-freeze batch: a [maintained Pascal checker and
  baseline](../BEAT-TRACKING.md#first-current-policy-candidate-baseline)
  now bind saved pre-reference reports to exact WAV/CSV hashes, default
  policies, source windows and path replay. Authored fast/half/double and
  absent-observation controls pass on stable Win32/Win64. The frozen recorded
  candidate gates fail: 02 has 12/17 eligible windows (target at least 90%),
  04 has 8/14 (target at least 80%); 01 and 03 pass their challenge gates.
  Current 02 window 16 retains its reference-compatible phase at index 2, so
  the old isolated rank-13 loss is historical, not the present missing row.
  This batch closes no further criterion and earns no credit. Trace the current
  failed rows through onset, fit, eligibility, suppression and capacity stages
  before changing retention; do not enlarge the pool solely from the old trace.
- 2026-09-23 criterion 1 closed by specification review: the [candidate qualification packet](../BEAT-TRACKING.md#bounded-candidate-qualification-protocol--2026-09-23)
  fixes exact six WAV/annotation identities, recording-disjoint development
  roles, native window geometry, candidate identity/eligibility, 30-ms
  per-window matching, authored event controls and finite coverage/work gates
  before any new candidate-policy score. Local SHA-256 identities and maintained
  default geometry/work constants were checked against the frozen text; no
  inference or reference scoring was run. The remaining criteria still require
  a qualified retained pool, omission accounting, replay and changed-path
  checks, so no task credit is earned. The challenge shares one
  authored dataset and was previously timing-exposed; independent natural
  music acceptance remains with tempo_03.
- 2026-09-23 deliverable split: the original tempo_01 combined candidate
  availability with choosing musical beat level and phase. In the recorded
  arpeggio diagnosis, a reference-compatible phase survived fitting but was
  lost beyond the eight retained slots; in the doubling case, a correct-rate
  candidate was already retained while the path chose another. The later
  source-accent and parity selection experiments failed their frozen gates.
  Candidate evidence is an independently consumable native result, so this task
  receives 2 of the original 5 goal points and tempo_01 retains 3. The total
  unearned credit and the original acceptance scope do not change. See the
  [work reassessment](../WORK.md#beat-candidate-deliverable-split--2026-09-23).
- Next bounded deliverable after the reassessment: obtain independently
  reviewable source-pulse status for ambiguous windows and declare one finite
  fit/retention decision before changing policy. The old 32-candidate walk is
  historical evidence, not an accepted provider or a diagnosis of current
  failures. Simply enlarging the default pool or retuning transition penalties
  does not pass the criteria.
