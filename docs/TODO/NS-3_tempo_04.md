# NS-3_tempo_04 — Qualify bounded beat candidates from WAV

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Accept the maintained beat-candidate pool on a source-separated recorded
challenge with independently attributable physical pulse evidence. The
source-independent Pascal pool, clock contract and authored controls are owned
by [NS-3_tempo_05](DONE/NS-3_tempo_05.md). This task retains the original recorded
challenge, including missing/unsupported evidence and candidate recall rather
than beat-level selection.

North star: NS-3. Outcome owner: WAV-02-PULSE.
Completion credit: 1 goal percentage point (0.25 overall points). The original
unearned +2 NS-3 / +0.50 overall allocation, split from the original 5 points
of [NS-3_tempo_01](NS-3_tempo_01.md), is now shared equally with
[NS-3_tempo_05](DONE/NS-3_tempo_05.md); total credit is unchanged.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [BEAT-TRACKING](../BEAT-TRACKING.md#candidate-survival-and-path-diagnosis--2026-09-19) · [BEAT-GRIDS](../BEAT-GRIDS.md).

**Acceptance Criteria:**

- Freeze exact recorded source windows, annotated development groups, candidate
  identity, eligibility, per-window support and a candidate-only challenge
  group before scoring. Fix availability/coverage and work limits prospectively;
  keep the later untouched whole-track timing evaluation group unused.
- On the source-separated recorded challenge, report 30-ms
  reference-compatible recall of the saved fast, half/double-time and
  competing-phase pool separately from selected beat accuracy. References may
  identify a missing candidate only after inference saves the pool; they may
  not supply a rate/band to the tracker.
- Bind physical source pulse, distractor, fitting omission, local eligibility,
  suppression and capacity explanations to independent source evidence.
  Missing or ambiguous evidence stays `unknown`; do not infer acoustic absence
  from a beat annotation, missing candidate or no MIDI event alone.
- Verify that the challenge uses the accepted
  [authored-control candidate contract](DONE/NS-3_tempo_05.md) without erasing its
  alternatives, indices, source coordinates, policy identity or replay link
  through `TBeatTrackWindow`, path reselection and selected clock.
- Pass focused checked native recorded-source, boundary, failure and work
  checks on the challenge and its consumer. Retain the authored regressions
  from `NS-3_tempo_05` without crediting them again. This task does not claim
  beat-level acceptance or revise the stopped metrical experiments.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
- [NS-3_tempo_05.md — DONE](DONE/NS-3_tempo_05.md)

**Dev Notes:**

- 2026-09-26 the maintained Pascal candidate evaluator now reports the
  best-F1 witness, maximum-recall witness and any candidate meeting both 75%
  precision and recall independently. It also reports best-pool source recall
  and recall-eligible-window coverage, leaving selected-path accuracy separate.
  Checked FPC 3.2.2 Win32/Win64 builds and bound saved-pool A/B runs reproduce
  32/47, 17/25, 4/10 and 2/7 from the frozen recall-first diagnostic. Salty Boi
  checked every window against the old F1-first and private recall-first outputs,
  with score agreement within 1e-12 and unchanged source/report bindings. C1's
  prospective freeze and C4's preserved candidate/index contract are evidenced.
  C2 fails the frozen recall gate; C3's full candidate-specific attribution and
  C5's challenge-specific boundary/failure checks remain open. No task credit.
  Stop this failed source route and continue with the already active operator
  authoring prerequisite for recorded learning; a later beat-candidate proposal
  needs a distinct source-independent hypothesis and fixed stop gate.
- 2026-09-26 the prospectively frozen two-work challenge completed its first
  and only source route; ignored `build/asap-beat-prospective-20260926/RESULT.md`
  holds exact source identities and checks. Pascal source correspondence,
  original PCM geometry, and physical-attack controls passed. A source-format
  parser correction accepted annotated downbeats with comma-suffixed meter
  metadata before scoring; it did not change physical thresholds. The groups
  had 47 and 25 physically supported beats, with at least 12 per half.
  Frozen Win64 inference saved both complete pools before reference CSVs were
  formed, at 22,059,540 and 21,671,055 fit visits under the unchanged cap.
  The maintained evaluator found 0/10 and 0/7 eligible windows meeting both
  75% precision and recall. A separate Pascal recall-first diagnostic of the
  same saved pools found only 32/47 (68.1%) and 17/25 (68.0%) maximum
  best-pool recall, with 4/10 and 2/7 eligible windows reaching 75% recall.
  Both miss the frozen 75% source and window gates. This result does not close
  the task or earn credit. Keep this cohort fixed; improve the source-independent
  candidate contract before any new challenge.
- 2026-09-26 a new source-separated ASAP/MAESTRO two-work challenge is
  prospectively frozen under ignored
  `build/asap-beat-prospective-20260926/POLICY.md`, SHA-256
  `f2062ce7d8ba7b8f752dcb3168d1d0501f97bb6df248e9fcc88bb3637affa147`.
  A checked Pascal metadata-only selector fixed two distinct unexposed work
  groups, exact first-30-second windows, source/physical floors, default
  candidate binary/options, 30-ms recall gates and transfer/work stops before
  either selected annotation, MIDI or WAV was fetched. The policy hash is
  committed here before source access so the earlier cohort's unprovable
  policy-timing problem is not repeated. The task and credit remain open.
- 2026-09-26 source-independent capacity attempt 1: the default six-second
  tracker windows now advance by three seconds (half overlap) rather than one,
  while explicit caller hops and the 64-million aggregate fit cap remain
  unchanged. Checked stable Win32/Win64 authored track, beat-grid, clock and
  context-profile controls pass; a new 30-second 25-onsets/second authored
  input completes in ten windows, a separate authored 120-BPM source retains
  60 aligned pulses without seam issues, and an extreme density rejects before
  replacing the previous result. The one-second path remains explicitly tested.
  After this frozen authored gate, the already exposed second ASAP/MAESTRO
  source completed once at 22,676,310 fit visits, ten windows, 494 admitted
  onsets and 84 output pulse positions; the old fixed binary had stopped at
  the aggregate cap. This repairs a development execution boundary, not
  recorded candidate recall, physical attribution or a prospective challenge.
  Exact private policy/report stay in ignored
  `build/beat-capacity-half-overlap-20260926/`. A new prospectively
  snapshotted source-separated pair remains necessary; no task credit.
- 2026-09-25 user-directed ASAP/MAESTRO source search found a more usable
  physical-beat source: ASAP v1.1 beat labels link to original MAESTRO v2.0.0
  acoustic Disklavier WAV and directly captured MIDI. Pascal ZIP/member checks
  and original-MIDI byte matches passed on four distinct works. In the exact
  first 30 seconds, source MIDI plus original-PCM attack contrast supports
  11/15 and 12/42 annotated beats in development, and 13/21 and 9/14 in the
  two nominal challenge works; all four clear the intended 8-total/3-per-half
  source floor. Unsupported beats remain `unknown`. Salty Boi verified the
  retained logs but found that the final ignored policy file was written after
  the challenge WAVs and crops were extracted, with no earlier policy hash or
  snapshot. Therefore this packet cannot prove prospective challenge source
  qualification; all four works are development-exposed. The fixed current
  checked Win32 tracker saved a report for the first nominal challenge, then
  reported `Beat tracking exceeds aggregate fit budget` for the second,
  leaving no report. No reference-selected rate, candidate recall, recorded
  criterion or task credit follows. The ignored
  `build/asap-beat-reference/RESULT.md` records identities, counts, logs, QA
  limitation and the preserved failure. Next: correct candidate capacity
  under an explicit bounded-work contract using source-independent controls,
  then use a new prospectively snapshotted source-separated pair. Do not
  retune this exposed pair to claim acceptance.
- 2026-09-25 task-flow split: prior notes saying original criteria 4–5 closed
  describe the maintained authored-control pool, link and consumer now owned
  by [NS-3_tempo_05](DONE/NS-3_tempo_05.md). They do not close this task's recorded
  challenge criteria. Original C1–C5 map as follows: 05 owns authored policy,
  alternatives, controlled loss classification, maintained API and native
  consumer; 04 owns recorded source split, recall, physical/unknown attribution,
  recorded link and challenge checks. Original unearned +2 NS-3 points became
  +1/+1, preserving +0.50 overall. The split itself earns nothing.
- 2026-09-25 KRAISLER source route stopped at its second fixed development
  recording. The publisher's [piano/violin duet
  dataset](https://zenodo.org/records/21082251) supplied directly captured
  piano MIDI, dry live stems and manually refined beats. The complete
  1,558,287,213-byte archive matched the publisher's MD5
  `22f6f51e9c356c1ea8f591d85603fd73`; Pascal checked 389 unique ZIP entries,
  all 20 paired groups and the selected files' hashes. The ignored
  `build/kraisler-reference/POLICY.md` froze distinct-piece IDs 01/02 for
  development and 03/04 for candidate-only challenge, first-30-second windows,
  a 30-ms beat/MIDI radius and 10-ms physical dry-piano contrast. Before PCM
  scoring, two source-container repairs were recorded: publisher Table 2 rather
  than archive CSV supplies composer/title, and exact tick-zero channel-prefix
  and one-hour SMPTE metadata were replaced only in a private Pascal MIDI
  projection, preserving note/tempo events and delta ticks. The first fixed
  recording passed with 43 supported beats (18/25 across halves); the second
  failed with 3 (3/0), against the frozen 8-total/3-per-half minimum. Other
  beats stay `unknown`, not absent; 03/04 were never acoustically scored, and
  no candidate tracker or reference-selected band was run. Both runs reported
  zero leaks. The private policy's v2/v3 amendments have no retained pre-score
  file hash, so their timing is supported by the work sequence rather than an
  immutable policy snapshot. This does not prove the publisher's beat
  annotations wrong or reclassify ARTBeaT 02/04; this source route ends without
  criteria 1–3 or
  task credit. The earlier BeatNet+ inventory and this full source gate are two
  consecutive nonclosing batches. Reassess away from another speculative
  pulse-source search; retained candidate contracts (criteria 4–5) remain
  available while a qualified physical pulse reference is an external blocker.
  Keep the publisher's conflicting CC BY/commercial-use statements unresolved;
  no source-trained result is accepted. Source WAV/archive and duplicate
  transfer fragments were removed after logging identities, freeing
  3,218,220,770 bytes under ignored `build/`.
- 2026-09-25 criterion 5 closes for the changed boundary and consumer. Checked
  FPC 3.2.2 Win32/Win64 beat-track and clock fixtures pass candidate ties,
  alternatives, gaps, source owners, work limits, replay and failed-result
  preservation. Both affected CLIs build. The maintained WAV reporter on the
  existing authored changing-tempo source produces 14 local windows and 24
  tracked/clock pulse points on both targets; each target's JSON replays byte
  for byte. The source SHA-256, policy, pool and clock-window links remain in
  the report. Current authored regular/polyphonic/changing-rate controls pass
  24/24, 20/20 and 24/24 through the tracked path; the wrong 192-BPM
  polyphonic fixed-grid top result remains visible. Existing deceptive and
  polyrhythm regression evidence is retained. Tiny cross-target floating-point
  text differences do not affect discrete frames or indices. Salty Boi's
  focused QA found no criterion-5 blocker. Exact commands and report hashes
  are in ignored `build/beat-pool-link/RESULT.md`. Criteria 1–3 still need a
  qualified source-separated recorded challenge; no task credit is earned.
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
