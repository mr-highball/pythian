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
