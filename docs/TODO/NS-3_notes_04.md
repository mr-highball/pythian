# NS-3_notes_04 — Qualify independent note-presence references

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Deliver a source-bound reference packet for the note-presence and boundary
problem. Separate a measured note control or annotation from audible activity:
pickup/MIDI note ends, a residual acoustic tail and an actual rest are different
facts. This packet is a prerequisite for the acoustic decision in
[NS-3_notes_02](NS-3_notes_02.md), not a new decoder or a genre verdict.

North star: NS-3. Outcome owner: WAV-03-BOUNDARIES.
Completion credit: 1 goal percentage point (0.25 overall points), split from
the original 4 points of NS-3_notes_02. Credit is earned only when every
acceptance criterion and the task-flow completion requirements pass.

Starting evidence: the [URMP annotation stop](../PHRASE-EVALUATION.md),
[known-gate controls](../PHRASE-EVALUATION.md#fixed-gate-release-controls--2026-09-22)
and [rejected gate-slope rule](../PHRASE-EVALUATION.md#fixed-gate-slope-diagnostic-rejected--2026-09-22).

**Acceptance Criteria:**

- Bind an accessible, properly attributed multi-recording source with at least
  two separate performer or instrument groups and separately acquired note
  control/annotation and audio. Verify complete notices, identities, formats,
  timing offsets and source coordinates. State which labels are physical controls,
  which are derived from sound, and which remain unknown.
- Publish explicit, reviewed continuation, post-annotation-end audible tail and
  distant-rest examples with source group, pitch, time bounds and evidence.
  Preserve uncertain endings and overlap; neither MIDI note-off nor unvoiced F0
  alone proves the acoustic tail's end. Include attack, short, quiet, repeated
  and gap candidates or record the exact uncovered scenarios for the decoder
  task without inventing labels.
- Freeze the selection, label convention and source-separated roles before
  scoring a presence observation. A Pascal reader/checker must reproduce the
  packet and verify identities, geometry, label boundaries and deterministic
  replay. Keep source audio and generated reports under ignored `build/`; the
  tracked contract and evidence must let another checkout reacquire inputs.
- Show that the packet can test a note-presence decision separately from pitch
  identity, with unsupported coverage reported. Do not claim recorded phrase
  accuracy, audible tail endpoints, or a note-off rule from this packet alone.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

Current status: criteria 1, 2 and 4 are accepted only at their declared
synthetic development scopes; criterion 3 and task credit remain open. The
entries below are reverse-chronological checkpoints. Earlier `uncertain`
labels, stop instructions and open-criterion counts record their former state
and are superseded by the numbered review and fixed consumer entries.
Next deliverable: run the fixed pitch-independent activity consumer once on the
now-reviewed independent NSynth train packet without tuning. Report unsupported
coverage and every miss. The failed NSynth valid gate stays stopped; do not
relax it, open its audio or rescore development data. Any future distinct
selection policy needs separate evidence-backed review and a pre-audio freeze.

- 2026-09-23 the user's numbered review supplied five audible and three
  not-audible labels for the train packet before scoring. The flute late tail
  (#7) was not audible despite nonzero PCM; the guitar late tail (#10) was
  audible but quiet. Checked Pascal Win32/Win64 bound exact identities,
  coordinates, roles and labels to the same reviewed packet SHA256
  `abbf3b4b3d4243498e99f2b677406292008893961cbc17649744aa6c2f675b19`
  with zero unfreed blocks. The input review TSV SHA256 is
  `46a722f3817d21ff680ae54dbe2debeff056b4e078f41740047b700c11866ba7`.
  The [source record](../PHRASE-EVALUATION.md#nsynth-train-source-separated-packet)
  preserves every label and limit. No train activity score has run yet.
- 2026-09-23 independent NSynth train source packet passed the same frozen
  metadata gate before its WAVs were extracted: nine eligible long-release
  instruments, 54 fast-decay instruments, and selected flute/guitar positive
  versus bass/brass negative source groups disjoint from exposed test groups.
  Pascal verified the complete 23.8 GB archive, extracted only metadata and
  four selected WAVs, checked their hashes and full PCM geometry, and prepared
  eight exact, unchanged-gain repeated listening aids. The maintained packet
  checker now binds the independent roles and eight pending windows on checked
  stable Win32/Win64 with matching hashes, while preserving the previous
  development packet hash. The
  [source record](../PHRASE-EVALUATION.md#nsynth-train-source-separated-packet)
  has identities, coordinates and limits. All four groups are reserved as
  independent evaluation material. Its then-pending human review was supplied
  in the later checkpoint above; criterion 3 and task credit remain open.
- 2026-09-23 independent NSynth valid source screen stopped at the frozen
  metadata selection gate. The official JSON/WAV archive was verified at
  1,068,767,009 bytes, published MD5
  `87e94a00a19b6dbc99cf6d4c0c0cae87` and SHA256
  `00dea2645fbe0069258567da30807a90825e0bab54c077d6481f253096c4e2a0`;
  `examples.json` SHA256 was
  `050e0bf55d1a87eee2abbbc3d273c7f525404c0a51ac378561b905f2da31a7286`.
  A checked Pascal selector reused the exact prior acoustic, pitch, velocity,
  quality and distinct-family rules and found only one eligible long-release
  instrument against six fast-decay instruments. It required two long-release
  instruments, so selection stopped before extracting, hearing or scoring
  valid audio. No independent role is admitted by this failed attempt.
  The private policy and selector remain under ignored
  `build/presence-independent/`; the large source archive can be reacquired
  from the [official NSynth page](https://magenta.withgoogle.com/datasets/nsynth).
  The downloaded 1.07 GB archive was later removed during local cleanup;
  the policy, metadata hash and official reacquisition path remain recorded.
- 2026-09-23 fixed development consumer result: the new maintained Pascal
  [activity decision tool](../../tools/pythian.presence.decision.lpr) completed
  its source-free zero, subfloor and above-floor PCM16 controls before one
  frozen eight-window pass. It used existing analysis/activity defaults and
  decided activity without pitch identity before opening the review packet.
  Six `activity_present` and two `no_activity` decisions matched the six
  audible and two not-audible reviews. Checked FPC 3.2.2 Win32/Win64 output
  hashes were identical
  (`3a707b395fdd354cf8a9c9fada3a407d27866661551ea2a740f772bc31b2c97c`)
  with zero unfreed blocks. Criterion 4 is satisfied as a bounded demonstration
  that this packet tests a pitch-independent activity decision. Both negatives
  are exact PCM zero, so no noise rejection, recorded transfer, independent
  accuracy or acoustic ending follows. Criterion 3 remains open; no task
  credit is earned.
- 2026-09-23 prospective consumer batch (before any new activity result): test
  the fixed default Pascal `AnalyzeAudio` and `AnalyzeAcousticActivity` path as
  a pitch-independent binary activity observation on the eight already exposed
  development windows. Analyze each exact 4,000-frame crop independently;
  decide present iff any activity action is not silence. Keep the existing
  analysis and activity defaults, including `SilenceRms=0.0001`, unchanged.
  First require source-free zero, subfloor and above-floor controls and checked
  deterministic native replay. Then make one eight-window pass, with no tuning:
  the hypothesis predicts six present and two silent decisions. A miss stops
  this candidate for diagnosis. Read human labels only for comparison after
  decisions; report source and role identities and unsupported cases. The
  cost is one frozen pass, not a search over thresholds. This is development
  diagnostic evidence, never independent or recorded-phrase accuracy.
- 2026-09-23 numbered mobile review supersedes the uncertain late-rest labels.
  The user heard the original fast-decay guitar as a strum (#1) and a single
  initial strike in the original mallet (#3), while hearing nothing in their
  exact repeated [3.75,4.00)-second aids (#2 and #4). This distinguishes
  whole-clip timbre from the frozen late windows. The review TSV now binds six
  `audible` long-release windows and two human-reviewed `not_audible` distant
  rests. Checked stable FPC 3.2.2 Win32/Win64 Pascal checkers replayed the
  reviewed packet byte-identically (SHA256
  `ab2ee369964d23d88c26f3c4a6cf0f8cefb2908f513efb9d800fdb8c4d337a6b`),
  with zero unfreed blocks. Criterion 2 is satisfied at the declared synthetic
  single-note scope: continuation, post-control audible tails and distant
  rests are explicitly reviewed with source, pitch and time coordinates;
  attack, short, quiet, repeated, phrase-gap and overlap coverage remain
  explicitly unsupported. No acoustic ending is inferred from note-off or
  file end. At this review-only checkpoint, criteria 3 and 4 remained open:
  no independent source or presence-decision consumer had been demonstrated.
  No task credit followed.
- 2026-09-23 role packet and playback discrepancy: the tracked Pascal checker
  now emits `role=development` for all eight frozen rows, rejects unsupported
  roles and conflicting roles within a source group, and reproduces identical
  checked FPC 3.2.2 Win32/Win64 reviewed packets (SHA256
  `45666b565f71390c50ed0029e93d8992c96335f6c77c89934b38bfc957381c00`).
  This prevents the exposed examples from silently becoming independent test
  material, but no independent source or downstream scorer is admitted yet;
  criterion 3 remains open. The listener clarified that only brass clips sound
  like static and reported instrument-like sound for the two late fast-decay
  aids. A separate Pascal audit found both exported late aids byte-identical
  and all-zero in their PCM data (SHA256
  `20eaebffe1816e0ffa6f7f854f5ef4ea80d5349faaf0ce1fec1b713e7fde58fa`).
  The reported sound could not then be bound to those exported bytes. At that
  checkpoint both labels stayed `uncertain`, with no rest verdict, presence
  score, criterion 2 closure or task credit. This was one nonclosing batch
  since criterion 1 closed. The numbered original-versus-aid review above
  later resolved playback identity and superseded this stop.
- 2026-09-23 source-bound criterion review: criterion 1 is satisfied at the
  declared synthetic single-note scope. The official CC BY 4.0 NSynth JSON/WAV
  test archive, attribution, archive/metadata hashes, fixed Pascal selection
  hash, four WAV hashes, distinct brass/guitar/mallet instrument groups,
  16-kHz PCM16/64,000-frame geometry, pitch/velocity IDs and documented
  3.0-second renderer gate are recorded in the
  [fixed-gate source audit](../PHRASE-EVALUATION.md#fixed-gate-release-controls--2026-09-22).
  Pitch/velocity are renderer metadata paired with separate WAVs; the official
  3-second hold is a dataset-wide render control, not a per-note MIDI or
  physical release trace. Quality tags are partly heuristic, and the audible
  ending remains unknown. This closes criterion 1 only at the synthetic
  single-note scope and resets the task's nonclosing-batch count. At that
  checkpoint, criteria 2, 3 and 4 remained open: reviewed tail/rest coverage,
  the final source-role and
  consumer decision, and a presence decision distinct from pitch identity. No
  independent inference accuracy or task credit follows.
- 2026-09-23 uncertain-rest clarification: the listener corrected the earlier
  interpretation and said only clips named `brass` sounded like static. That
  timbre did not apply to either fast-decay late playback aid. Both judgments
  stayed `uncertain` at this checkpoint; the later numbered review resolved
  them without inferring a verdict from their exact-zero source PCM.
- 2026-09-23 reviewed-window checkpoint: the user labeled all three frozen
  brass windows and all three fading-guitar windows `audible` under the
  source-sound convention. They explicitly identified the repeated brass
  [3.75,4.00)-second aid when clarifying the late sound. They answered
  `uncertain` for the bell-like guitar and mallet late windows. The ignored
  review TSV replayed at that checkpoint through the prior no-role Pascal
  packet format with byte-identical checked FPC 3.2.2 Win32/Win64 packets (SHA256
  `9407073b8277938c91a358688e94806e2a504943f576825743cda9aa47dc081c`)
  and zero leaks. Six-decimal RMS output repairs two nine-decimal cross-target
  rounding differences; no source coordinate or review label changed. The
  [packet](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
  retains the exact scope. Neither `uncertain` rest window is a human-reviewed
  `not_audible` example despite exact-zero PCM, so criterion 2 and task credit
  remained open then. The later numbered review supplied the human rest labels
  before the fixed activity comparison. No silence endpoint was inferred from
  file end or MIDI note-off.
- 2026-09-23 listener wording correction: the earlier question asked for an
  audible *pitched note*, conflating source audibility with pitch identity.
  The user clarified that the brass is audible source sound but resembles
  unpleasant old-TV/radio static across attacks and holds. For this presence
  packet, `audible` means heard source sound regardless of pitch or timbre;
  clear pitch and quality remain separate observations. The
  [packet convention](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
  is corrected before any scorer run without changing frozen windows, TSV
  labels or the three exact guitar labels. At that point, the brass statement
  was not a three-window answer, so five exact judgments awaited review. This
  repair earns no criterion or credit by itself.
- 2026-09-23 frozen-window playback aid: an ignored Pascal tool repeated the
  five still-pending 250-ms windows with equal digital-silence gaps for mobile
  review. Checked stable Win32/Win64 runs bind original WAV hashes, verify
  exact repeated PCM and emit matching WAV hashes. Both fast-decay late source
  windows have 0/4,000 nonzero PCM frames; all three brass windows contain
  nonzero samples without proving an identifiable pitch. See the
  [packet evidence](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22).
  This aid adds no source/window, listener label, accepted criterion or credit.
  Stop playback-aid variations here; do not treat digital silence or loud
  static as a human verdict.
- 2026-09-23 exact-window listener update: the user marked the fading
  `guitar_acoustic_030-061-100` pitched sound audible in all three frozen
  windows, including [3.75,4.00) seconds after the 3.0-second renderer
  note-off. Their brass description, "audible, but sounds like loud static",
  does not say whether source sound is heard in each of its three exact
  windows. At that checkpoint both fast-decay late windows also lacked exact
  labels. The three reviewed guitar labels and five then-pending labels are in the
  [listening packet](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22).
  That was partial human evidence, not an endpoint, completed source-separated
  packet, presence scorer or task credit. The five labels were subsequently
  reviewed under the corrected question. Do not expand the source screen or
  infer window labels from whole-clip words.
- 2026-09-22 split rationale: two consecutive nonclosing batches after the
  NSynth source change showed that a known gate and long-release tags do not
  provide reviewed acoustic tail/rest labels. The measured gate-slope rule
  failed both long-release controls; a fast-decay mallet is silent well before
  note-off. This task owns the independently useful reference deliverable,
  while [NS-3_notes_02](NS-3_notes_02.md) retains the observation, decoder,
  controls and recorded accuracy requirements. Original 4-point credit is
  redistributed 1+3; no progress or credit is earned by the split itself.
- Candidate source: [Guitar-TECHS](https://zenodo.org/records/14963133)
  offers CC BY 4.0 separate direct-input/microphone captures and per-string
  pickup MIDI across performers, including single notes. Its publisher warns
  of up to 100-ms intersignal misalignment. Verify exact local files and any
  correction before using it for tight boundary labels. Pickup MIDI may itself
  follow string vibration rather than a physical key/gate; retain that
  distinction. Stop if no separately supportable tail/rest contrast exists.

- 2026-09-22 source-screen stop: official P1 single-note archive identity,
  Pascal WAV/MIDI decode and 142 track-paired notes pass. A candidate rule
  frozen before audio selected four notes on tracks 1 and 6, but none meets
  the predeclared tail/rest residual-signal contrast in both direct input and
  amp mic. Two Pascal audits reproduce CSV SHA256
  `fee855ce8496a64ac0dff0358a41aa537f3d55be75320c89c15db754be76f3e3`;
  [source, scores and limitations](../PHRASE-EVALUATION.md#guitar-techs-p1-reference-screen-stopped--2026-09-22).
  Stop this P1/P2 route without lowering its gate or moving windows; P2 was not
  acquired. This is the first nonclosing batch on the split reference task.
  Next verify a source that publishes distinct control-release and acoustic or
  pedal-extended offsets, its label derivation, license and per-file access
  before acquiring new audio. Do not confuse a pedal-derived frame offset
  with a reviewed acoustic silence boundary.

- Next bounded source check: the official [PianoVAM dataset card](https://huggingface.co/datasets/PianoVAM/PianoVAM_v1/blob/main/README.md)
  exposes `key_offset` and `frame_offset` in individual TSVs beside WAV/MIDI
  recordings. It describes the latter as sound ending after pedal use, but the
  TSV is derived from MIDI; verify the derivation and actual file alignment
  before treating it as acoustic tail truth. Its CC BY-NC-SA 4.0 license limits
  reuse, so keep any probe evaluation-only and do not incorporate its data into
  a distributable or commercially reusable learned style.
- 2026-09-22 PianoVAM source-screen stop: the current v1.1 card says its TSV
  labels are derived from captured MIDI. `key_offset` is key release, while
  `frame_offset` considers sustain pedal; the authors' [paper source](https://github.com/alexanderlerch/2025-ISMIR-PianoVAM/blob/main/ISMIR2025_template.tex)
  explicitly adjusts transcription offsets to pedal release. Neither is an
  independently reviewed acoustic silence boundary. The card provides
  per-file Audio/MIDI/TSV access, but its current CC BY-NC-SA 4.0 license
  restricts reuse. Do not acquire audio or use the symbolic `frame_offset` as
  tail truth. This is the second nonclosing reference batch after Guitar-TECHS.
  At the task-flow checkpoint, finish a bounded review packet from the already
  verified CC BY 4.0 NSynth controls: freeze exact continuation, post-gate and
  distant-rest listening windows and ask for judgments with `uncertain` allowed.
  Only then decide whether this synthetic instrument-group packet can close
  the reference criterion; recorded phrase transfer remains separate.
- 2026-09-22 review-packet batch: the tracked
  [Pascal checker](../../tools/pythian.presence.reference.lpr) now verifies all
  four fixed WAV identities and eight windows, and validates an exact-boundary
  review TSV without deriving listening labels from energy. Stable/trunk
  pending-packet replay and the malformed-boundary rejection are recorded in
  the [packet](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22).
  This is one nonclosing batch after reassessment: listener judgments, coverage
  assessment and any required source-separated role decision remain open.
- 2026-09-22 partial human review: the user described all four named clips,
  including an audible-seeming fade on the long-release guitar, harsh brass,
  bell-like fast-decay guitar and an inaudible mallet. The comments are not
  tied to the frozen 250-ms windows. Retain their
  [exact scope and uncertainty](../PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22);
  request window-specific labels before running a presence scorer or claiming
  a reviewed acoustic tail/rest endpoint. This is the second consecutive
  nonclosing batch after reassessment. Stop packet expansion and further source
  screens; the external unblock is exact labels for the frozen windows, with
  `uncertain` allowed. No criterion or credit closes.
- 2026-09-22 follow-up: the user heard the brass fade after the 3.0-second
  renderer note-off. This is direct evidence of perceived post-control decay,
  but still leaves the frozen early/late 250-ms windows and audible endpoint
  unlabelled. Do not equate the fade with a measured note-off decision.
