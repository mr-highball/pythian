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

- 2026-09-25 criterion 4 closes at the composed maintained Pascal boundary.
  `SelectedBeatClockWindows` now carries the exact track-window and selected
  candidate indices, including `-1` for a gap, without discarding the caller's
  retained alternatives. The source-bound WAV report already records source
  SHA-256, geometry, grid/track/clock policies, the full candidate pool and
  selected indices, with clock segments referring to the same window order.
  Checked FPC 3.2.2 Win32/Win64 clock fixtures verify selected index 1 of two
  distinct candidates, source owners, gap, replay, detachment and invalid-index
  failure preservation; both affected CLI consumers rebuild on both targets.
  Salty Boi's focused read-only QA found no criterion-4 blocker. The clock JSON
  resolves through adjacent track windows rather than repeating the link.
  Candidate availability on a qualified recorded challenge (criteria 1–3) and
  final changed-path acceptance (criterion 5) remain open; no task credit.
- 2026-09-25 a read-only alternative-source check found that the
  [BeatNet+ authors](https://reference-global.com/article/10.5334/tismir.198?tab=article)
  describe manually corrected beat/downbeat annotations for MUSDB18 and
  URSing, which have isolated audio stems. The current public
  [BeatNet+ repository](https://github.com/mjhydri/BeatNet-Plus)
  tree contains no `annotations/` directory or `.beats` files,
  despite the paper's release link; MUSDB18 audio also requires a separate
  academic-use access request. Stop this route before downloading, source
  scoring or using predicted beats as independent truth. No recorded pulse
  challenge or criterion closes. Reassess the existing maintained candidate
  pool boundary with current authored evidence instead of another speculative
  source screen.
- 2026-09-24 QA found a report-only limitation in the stopped GuitarSet
  qualifier: 21 beat rows without an event inside the 30-ms match radius store
  `High(Int64)` in `nearest_signed_error_frames` instead of the exact nearest
  signed distance promised by its private policy. The saved event ledger still
  reconciles 105 notes, 48 beats, 12 supported onsets and 6 supported beats;
  the frozen 6/2/4 source-gate failure is unaffected. Retain the report and
  this limitation rather than rerunning or presenting the field as valid.
- 2026-09-24 one source-free six-channel decoder fixture passed, then the sole
  repaired GuitarSet Win32 preflight reached and failed its frozen acoustic
  source gate on development recording `01_BN1-129-Eb_comp`: 48 beats and 105
  annotated note onsets produced 12 pickup-supported onsets and 6 supported
  beat positions, split 2/4 across the recording halves. The declared gate
  required at least 8 total and 3 per half. The other 93 annotated onsets and
  beats without supported guitar attacks remain unknown, not declared absent;
  this does not prove a physical source error or justify a threshold change.
  The 05 challenge, Win64 and beat tracker were not run. The fixed source route
  stops here without substitution or retuning; no additional criterion or credit
  closes. This and the preceding decoder stop are two nonclosing batches after
  the identity reassessment. Return to task selection and require a genuinely
  qualified, independent source-pulse reference before another candidate-pool
  decision. Ignored report SHA-256:
  `2ca860b55b2fb3f25778cc043aa7a77477d17189951b888cd02a0f7ff9d8dd9c`.
- 2026-09-24 the one identity-only GuitarSet repair passed the corrected 01
  comp mic, JAMS, original-hex SHA and ZIP CRC gates, then stopped before PCM
  at a tool contract mismatch: the preflight used the portable mono/stereo
  `TWaveFrameReader` on the declared six-channel original pickup. No beat/event
  counts, challenge run or candidate score exists. Preserve both STOP reports.
  Reassess to one Pascal six-channel PCM16 reader adaptation in the ignored
  source qualifier, reusing the prior pickup screen's pattern; leave the
  maintained reader and every source/acoustic threshold fixed. Stop on the
  next source or acoustic failure rather than trying another setting.
- 2026-09-24 first fixed GuitarSet source preflight stopped before annotation
  parsing or pickup PCM measurement because the frozen expected hash for
  `01_BN1-129-Eb_comp_mic.wav` was copied from the different
  `01_BN1-129-Eb_solo_mic.wav` despite their equal byte lengths. The exact
  comp member re-extracted from the publisher-MD5-verified mic archive matches
  the selected existing comp file at SHA-256
  `4f7f2359cc26d32307c8cc6793579d9d5ce602f483194ca079efd719a870b671`;
  the erroneously expected SHA is the solo file's exact hash. This and the RWC
  screen are two nonclosing source batches. Reassess to one identity-only
  repair of the same selected comp source under its official archive proof,
  preserving every source, clock, acoustic and support gate; retain the failed
  report and stop at the next gate failure. No candidate score or credit yet.
- 2026-09-24 metadata-only RWC 2.0 source screen stopped before audio or
  candidate scoring. The [publisher release](https://zenodo.org/records/18656623)
  and [curated annotations](https://github.com/rwc-music/rwc-annotations)
  offer full-mix WAVs, beat times and aligned MIDI drum events, but no listed
  isolated drum stem. An event transcription can support a new beat challenge;
  it cannot establish whether a pulse in a failed mixed-audio window was
  physically sounded. The annotation repository was inspected at commit
  `0a1a6c31dbe73a7f5d44f7caef8cd0999402a4c2`; no annotation payload or
  RWC WAV was opened, and its 4.1-GB popular-music archive was not acquired.
  Stop this source route for criterion 3. The next bounded source candidate is
  the already acquired [GuitarSet](https://guitarset.weebly.com/) microphone,
  six-string pickup and beat/note annotations on two distinct player/material
  groups. Freeze its identities, clock and source-event gate before scoring;
  keep the original ARTBeaT 02/04 failures and thresholds unchanged.
- 2026-09-24 the first full GMD paired-audio acquisition stopped at the
  frozen one-transfer gate. The official 5,111,599,714-byte object returned
  the expected length and a stable ETag, but the sole sequential HTTP 200
  download reset after 3,949,543,424 bytes (curl exit 56, 371.359 seconds).
  No archive member, WAV, beat model or scorer was opened. A Pascal paired
  qualification tool compiled on checked FPC 3.2.2 Win32/Win64 but was not
  run; Salty Boi verified the freeze, transfer, target outputs and stop.
  This is a transport failure, not failed acoustic evidence or task credit.
  Together with the earlier metadata-only GMD source screen, it is two
  nonclosing source batches. Reassess to one byte-range resume of the exact
  preserved prefix under the same object generation/ETag, followed by the
  publisher's full SHA-256 gate; stop if range identity or final hash fails.
  This changes the acquisition method, not source selection, acoustic gates
  or beat-candidate policy. No further whole-archive restart loop follows.
- 2026-09-24 one conditional Range recovery completed the exact missing
  1,162,056,290 bytes. The verified full archive is 5,111,599,714 bytes and
  matches the publisher SHA-256
  `21559feb2f1c96ca53988fd4d7060b1f2afe1d854fb2a8dcea5ff95cf3cce7e9`;
  the original prefix hash is unchanged. A PowerShell integer-overload error
  interrupted read-only post-transfer verification; a corrected read-only
  check passed without another request. The frozen extractor then stopped
  before opening a member because all four selected relative member names
  have a literal `groove/` container prefix. Salty Boi independently verified
  exactly one matching prefixed entry for each selected path, no member access,
  and no WAV or qualifier run. This is a packaging-path discrepancy, not a
  changed source identity or acoustic failure. The next bounded action is to
  freeze the exact one-to-one `groove/` mapping and duplicate guard, then
  continue only the prior two-pair acoustic policy; no selection or threshold
  changes. Task criteria and credit remain open.
- 2026-09-24 exact `groove/` mapping and both MIDI-member identity hashes
  passed; only the two selected WAVs were extracted (24,434,020 and
  14,551,374 bytes), each matching its member hash. The first checked Win32
  development qualifier stopped before WAV decode at the frozen
  `DefaultMidiNoteOptions` call: GMD performance MIDI requires an explicit
  ignore-and-report policy for non-note events. The structure/metadata parser
  had already succeeded, so this is a decoder-options contract mismatch, not
  evidence of malformed MIDI or failed onset alignment. No challenge or
  Win64 qualifier ran; the exceptional exit reported six unfreed blocks
  totaling 275 bytes. Salty Boi independently verified the four members,
  two-target compilation, stop location and lack of acoustic analysis.
  Together with the prior prefix-lookup stop, these are two nonclosing
  post-reassessment batches. Reassess to one explicit percussion-event
  admission policy using the already exercised native GMD metadata parser's
  documented ignore/report semantics, preserving every source, clock and
  acoustic threshold. Require counts and ownership of ignored event kinds
  before any onset comparison. Stop if the event contract or fixed acoustic
  gates fail; do not loop through option variants. No task credit yet.
- 2026-09-24 the one explicit GMD event-admission policy passed MIDI-only
  preservation on checked FPC 3.2.2 Win32/Win64 for both selected pairs;
  exact event ledgers matched across targets with zero reported leaks. The
  sole acoustic run, development Win32, decoded the bound 44.1-kHz stereo
  WAV and localized 794 onset frames. Only 770 of 1,807 distinct MIDI
  attack ticks matched within 30 ms (42.6121%), below the frozen 80% gate.
  Matched-event median/p95 errors were 4.172336/24.172336 ms. Salty Boi
  independently confirmed source/policy hashes, the counts, exact run order
  and the stop; no Win64 or challenge acoustic run occurred. The exceptional
  exit reported six unfreed blocks totaling 274 bytes. The report mixes a
  maximum raw MIDI event tick with seconds at the last note-gate end tick;
  matching uses gate start ticks and is unaffected. Preserve that frozen
  failed report and stop this GMD source route without localizer/threshold
  tuning. The generic candidate-pool task remains open, with no credit or
  source-pulse claim for ARTBeaT 02/04.
- 2026-09-23 independent-source screen: a frozen Pascal metadata/MIDI-only
  check of the [official Groove MIDI Dataset](https://magenta.withgoogle.com/datasets/groove)
  found two different-drummer/session
  performances with explicit tempo, meter and over 30 seconds of drum-hit
  events. The publisher lists paired synthesized audio and claims alignment
  within 2 ms; no WAV or test split was opened, and composition identity and
  acoustic hit alignment were not verified. Exact policy, hashes and report are
  under ignored `build/gmd-pulse-source/`. This is possible future source
  material, not source-pulse truth for the frozen ARTBeaT 02/04 windows. No
  candidate policy, criterion or credit changes; stop at this source gate.

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
