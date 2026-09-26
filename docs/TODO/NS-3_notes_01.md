# NS-3_notes_01 — Resolve recorded pitch identity and register

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Resolve octave/register errors in the supported recorded monophonic scope without sacrificing real low, quiet or short notes. The current flute precision gap remains the primary reference.

North star: NS-3. Outcome owner: WAV-03-REGISTER.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [PITCH](../PITCH.md).

Progress 2026-09-21: the frozen [predictive-phase comparison](../PHRASE-EVALUATION.md#predictive-phase)
passed physical controls but made no recorded corrections, retaining all 105
flute octave-error centers. Reject this rule without a threshold sweep; the task
remains open with no credit. Reassess identity/presence evidence before declaring
another experiment; the existing independent evaluation material remains unused.

Reassessment 2026-09-21: the [native cache audit and summary](../PHRASE-EVALUATION.md#identity-evidence-reassessment--2026-09-21)
pass final QA and reconcile all 5,994 centers without changing predictions.
The 11 flute octave-error events have 42/43 available lower-hypothesis triples,
including 32 gain-guard failures, while 25/43 upper triples are unavailable.
No event passes every guard. Stop the contingent amplitude-envelope correction
experiment under its frozen gate. First inspect retained fit caches for exact
unavailability reasons and intermediate energies; if absent, predeclare bounded
all-event instrumentation of the unchanged observation path. Missing measurements
do not justify register correction, and resolving their cause alone cannot prove
identity. Preserve the separate presence task, independent evaluation material
and current thresholds. The task remains open without additional credit.

The [cache-only availability follow-up](../PHRASE-EVALUATION.md#cached-availability-attribution--2026-09-21)
now passes final QA. All unavailable triples remain unresolved; the needed
intermediates are absent. Next implement one bounded trace-only replay per
existing recording, retaining first actual exit reasons and reached values under
the unchanged calculation. Exact replay of the five original outputs is required
before interpreting causes. Keep the envelope experiment stopped; no new model,
guard, source exposure or presence/register correction belongs to this diagnostic.

The [exact trace replay](../PHRASE-EVALUATION.md#exact-availability-trace-replay--2026-09-21)
passes on both recordings and attributes all previously unavailable triples to
first/second-window phase-support exits. All original outputs and fit-work totals
match exactly. The earlier lower-hypothesis guards still pass no octave-error
event, so repairing only upper availability cannot rescue the proposal. Stop this
correction family and reassess the independent identity information needed;
preserve genuine-note controls and keep presence separately accounted. No task
credit or failed-submission increment follows from this diagnostic.

Batch 28 starts a distinct
[source-separated candidate calibration](../PHRASE-EVALUATION.md#source-separated-candidate-calibration--2026-09-21)
after that reassessment. Two labelled recorded works provide fit examples;
a separate work challenges fixed temporal harmonic features and a native fitted
candidate scorer before any application to existing development material.
The model, features, source split and stop gate are declared before measurement.
Oracle candidates make the first challenge a necessary feasibility check only,
not achieved blind inference or task acceptance. Failure stops the proposal
without a threshold/feature sweep; success still needs the existing low/quiet/
short/articulation protections and recorded gates before maintained adoption.
Final paired QA passes controls, replay, resources, source isolation and
preservation, but the fixed challenge fails: violin 546/548 correct ranks,
flute 482/514 against 98%, both 100% eligible. Stop this scorer without Spring
application or threshold/feature/epoch variants. No maintained provider,
criterion closure or credit follows. The next design must explicitly handle
unresolved candidate ambiguity under a prospective confidence/coverage contract;
post-hoc cutoffs on these errors are not a justified new observation. Keep the
separate presence gap and protected waveform/held-out requirements intact.

One-shot selective sparse-peak check 2026-09-22: the newly accepted Pascal
observation backend provides source-bound support, but its highest pitch bin is
not a reliable identity decision. A frozen, non-fitted rule chose the strongest
bin only when support was at least 0.5 and neither octave alternative was within
0.15 support. It scored the same fully contained, single-note Spring development
centers as the accepted observation study. Flute admitted 892/905, with 814
correct, 44 octave errors and 34 other errors (91.256% precision). Violin
admitted 1083/1355, with 961 correct, 82 octave errors and 40 other errors
(79.926% coverage, 88.735% precision). Flute fails the >=98% precision
requirement; violin fails both the >=80% coverage and >=98% precision
requirements. The ignored Pascal policy, scorer and bound logs are in
`build/note-sparse-identity/`; the saved observation hashes are
`e84fe81b91b3df9c0e9a457dc1111f19281793026810578227eae9e89340d89c`
and `13eb9b3dbe7538d61714f1d6f43a8bd897b8c494a51771e0f9428a7ecaad0c85`.
Stop this direct-support rule without a threshold/rank sweep. It changes no
maintained path, task credit or protected evaluation material. A later identity
proposal needs genuinely discriminating evidence and a prospective ambiguity
contract; the accepted sparse support remains an observation, not a note label.
The scorer met its time limit and reported zero unfreed heap blocks; its declared
private-memory limit was not measured and is not qualified by this failed gate.
The stopped source-separated register scorer and this direct-support rule are
two nonclosing batches for this note-identity investigation. Reassess and stop
this sequence here: resume only with an independently contrasting, frozen
source of register evidence and explicit ambiguity/coverage behavior that
protects low, quiet and short notes. No further best-bin, rank or threshold
variation is authorized by the existing evidence.

**Acceptance Criteria:**

- Declare a discriminating identity observation or decision rule before scoring; explain how it distinguishes the remaining octave errors rather than merely changing global weights or thresholds. Final development scoring must construct candidates from audio without reference pitches; oracle candidate ranks are feasibility evidence only.
- Preserve true octave changes, weak/missing fundamentals, vibrato, articulation changes and the recovered correct coverage, with explicit ambiguous alternatives.
- Pass actual waveform low/short/quiet/gap/mixture controls for any changed observation path, including transformed-model controls if rate views are adopted.
- Meet predeclared register-error and coverage criteria on recorded development inputs while retaining passing violin behavior; agreement, larger capacity and restored activation strength are not calibrated confidence. For a fitted rule, bind fit and calibration work groups separately, retain related arrangements together and protect final evaluation groups. Declare abstention and its coverage denominator before scoring; rejecting ambiguity cannot hide lost correct coverage.
- Deliver the accepted identity path through maintained Pascal code with bound source/policy evidence. Coordinate with presence/boundaries; neither task alone closes full phrase admission.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- 2026-09-25 a fresh, publisher-hosted [Yorita flute-tone collection](https://www.brinckerhoff.org/flute-tones/index.html)
  supplied two published player IDs with C4/C5 long tones, with and without
  vibrato. A frozen Pascal eight-WAV source/physical gate passed all 40 fixed
  source activity windows at 44.1-kHz PCM16 stereo. The first three scored
  members passed 5/5 each, but the first vibrato C5 member passed only 2/5
  against the declared 4/5 minimum. Stop the fixed one-versus-two-period
  ratio before scoring player ID 1; do not change its windows, lag width or
  threshold. The exact files, hashes, checked Win32 source, per-window
  residuals and zero-leak log remain under ignored `build/register-yorita-cycle/`.
  This is a source-qualified negative *physical* result, not a blind register
  result, note admission or credit. The next batch switches to the independent
  [admitted-event WFC bridge](DONE/NS-3_notes_06.md) while register evidence is
  reassessed; no source-only octave screen follows this one.
- 2026-09-25 an independently published
  [Iowa flute C4/C5 single-note](https://theremin.music.uiowa.edu/MIS-Pitches-2012/MISFlute2012.html)
  contrast stopped before any pitch scoring. Four `ff` vibrato/nonvibrato
  AIFF files were downloaded and converted to WAV by an external converter,
  with all bytes hash-bound under ignored `build/register-iowa-cycle/`. The
  prospectively frozen Pascal cycle-observation gate required 96-kHz PCM24;
  the first publisher-linked file decoded as 44.1-kHz PCM24 stereo, so the
  fixed source gate failed before any activity or register feature ran. A
  private exceptional-exit leak was repaired; the unchanged geometry gate
  reran checked FPC 3.2.2 Win32 with zero leaks. Do not reinterpret the site's
  general post-2012 24/96 description as this member's actual geometry,
  retune the gate, or credit this attempt as independent register evidence.
  The cycle rule remains untested, not rejected on physical separation.
- 2026-09-23 NSynth octave-source gate stopped: a
  [metadata-only Pascal inventory](../PHRASE-EVALUATION.md#nsynth-acoustic-flute-octave-inventory-stopped--2026-09-23)
  checked exact same-instrument acoustic-flute octave pairs in the approved
  train and development-exposed test partitions before any WAV extraction.
  The fixed source-group gate required three train instruments and one
  instrument-disjoint test instrument at pitches 48..84 and velocity 75/100,
  excluding a flute instrument reserved for presence evaluation. Train had
  33 qualifying instruments and 783 pairs; test had none. Stop this source
  route without relaxing selection or treating the train pairs as independent
  validation. No register observation, criterion or task credit follows;
  the existing requirement for contrasting source-grounded evidence and a
  prospective ambiguity/coverage contract remains.
- 2026-09-23 cross-part attribution stop: the [frozen source-bound Pascal
  screen](../PHRASE-EVALUATION.md#cross-part-register-peak-attribution-screen--2026-09-23)
  checked simultaneous raw violin annotations and WAV at all 96 saved flute
  events. Only 19/222 upper-correct cohort half peaks matched a violin note
  covering their full 1024-or-shorter analysis window; the matched flute
  single-bin share was 0.075093044 of 1.340174762 summed. Event 8 had 0/25
  matches and event 81 had 1/20. The baseline-correct controls had 141/904.
  Two checked native runs replay exactly with zero leaks. This weakens an
  active-violin-note explanation for most wrong-register peaks, but neither
  proves a flute undertone nor supplies a safe blind correction. Stop this
  source-attribution route; independent source ownership and prospective
  ambiguity/coverage remain required. No criterion or credit closes.

- 2026-09-23 saved gap-peak attribution: a [frozen Pascal screen](../PHRASE-EVALUATION.md#saved-gap-peak-attribution-screen--2026-09-23)
  separated below-55-Hz content from half-integer candidate harmonics in the
  existing 96-flute-event spectra. The 11 reference-upper-correct events have
  mean half-peak share 0.026575377 (event range 0.008621028..0.068254048);
  85 baseline-correct events have 0.000326272 (range 0..0.002847752).
  Four violin spiccato controls average 0.000391648. Source hashes,
  physical controls, replay and bounds pass; no audio was reopened or policy
  changed. These reference-defined development cohorts do not establish a
  safe blind register rule, source ownership or low/quiet/short-note coverage.
  Stop at this descriptive result under the existing task-flow reassessment;
  criterion 1 and credit remain open pending independent evidence and a
  prospective ambiguity/coverage gate.

- 2026-09-23 HarmoF0 source screen: the [author paper and repository](../PHRASE-EVALUATION.md#harmof0-source-feasibility-screen--2026-09-23)
  report strong in-domain frame pitch accuracy and publish compact weights, but
  provide no source-disjoint flute result, calibrated abstention or note-presence
  behavior for this task's gates. After the failed Pascal PESTO prescreen, an
  aggregate published score alone does not justify another model port. No
  weights or third-party runtime were used; criterion 1 and credit stay open.
  Resume only with independently supported register evidence and a prospective
  ambiguity/coverage policy that protects genuine low, quiet and short notes.

- Stopped approaches (2026-09-21): predictive-phase/envelope guards corrected none of the 105 flute octave-error centers. Availability tracing explained exits but could not rescue the failed guards; do not restart that correction family. See the [identity reassessment](../PHRASE-EVALUATION.md#identity-evidence-reassessment--2026-09-21).

- Stopped batch 28: the fixed source-separated scorer ranked violin 546/548 and flute 482/514 correctly; flute failed the 98% gate even with oracle candidates. No Spring application or feature/epoch/threshold variants follow. See [candidate calibration](../PHRASE-EVALUATION.md#source-separated-candidate-calibration--2026-09-21).

- Stopped 2026-09-22 direct-support rule: the accepted Pascal sparse-peak observation has top-12 reference recall, but a frozen best-bin/octave-margin decision fails both Spring identity gates. Do not retune the margin or promote raw support to pitch admission; the exact counts and ignored policy are in the description above.

- Investigation reassessment 2026-09-22: this is the second task-specific nonclosing batch after the stopped source-separated scorer. Suspend note-identity experiments until a genuinely new, independently contrasting observation with prospective abstention and source-bound low/quiet/short controls is declared. Accepted Pascal observation/execution work in between did not settle this note-identity cause.

- Follow-up: justify genuinely discriminating identity evidence and prospective ambiguity/coverage handling before another experiment. Coordinate with [presence](NS-3_notes_02.md); preserve genuine low/quiet/short notes and untouched phrase material. The pause retains the one-batch no-criterion-closure count in the [work record](../WORK.md#pause-retrospective--2026-09-21).

- 2026-09-23 native-model feasibility screen: porting CREPE tiny/full would
  reproduce the already failed [recorded capacity comparison](../PHRASE-EVALUATION.md#full-capacity-comparison),
  so it supplies no new register evidence. The distinct
  [SwiftF0 v0.2 source](https://github.com/lars76/swift-f0) is MIT licensed and
  provides compact harmonic-comb weights. A bounded Pascal protobuf inspector
  decoded its exact local model as one 355-node, 107-tensor graph without
  executing ONNX or another runtime. The v0.2 repository does not provide a
  source-group training manifest for those weights; the linked
  [paper](https://arxiv.org/abs/2508.18440) describes the earlier v0.1 model.
  Without that exposure identity, a source-disjoint accuracy claim on the
  existing recordings would be unsupported. Stop this model port before
  inference implementation, retain the private screen under ignored `build/`,
  and require verified model-training groups or Pascal-owned training with a
  frozen control/coverage gate before another model experiment. No criterion,
  provider or credit changes. This is the second consecutive nonclosing batch
  after journal publication. The [work reassessment](../WORK.md#core-quality-reassessment--2026-09-23)
  changes the next action to the ready NS-2 source/articulation quality review;
  register investigation resumes only with the independent evidence above.

- 2026-09-23 distinct model-source check: the [PESTO release at
  `62bc0c9`](https://github.com/SonyCSLParis/pesto/tree/62bc0c9702558f19af4593752947fb9db1eadac9)
  names MIR-1K as the training collection for its supplied model and includes
  `mir-1k_g7.ckpt`. Treat **all MIR-1K recordings as development exposure**;
  no song-level training split was established. This is a materially different
  source qualification from the stopped SwiftF0 screen, and URMP Spring is a
  separate collection. A checked FPC 3.2.2 Win32 Pascal-only container screen
  bound the ignored 534664-byte checkpoint (SHA256
  `16c32e06ddd950e3e4866dfa3c7f8a87c4988f8adf43e57977b189f031f26f3e`):
  26 ZIP entries, 7915 stored pickle metadata bytes and 22 raw storage members.
  The metadata names spectral encoder, confidence and calibration tensors; it
  was inspected as bytes, never executed. FPC's generic ZIP extractor listed
  the metadata member but emitted zero bytes; a bounded Pascal central-directory
  reader recovered the stored member for this screen. The publisher's repository
  carries an LGPL-3.0 license; weight redistribution has not been qualified.
  This qualifies one **private Pascal-port candidate**,
  not a register observation, source-disjoint accuracy result, accepted model
  or distributable dependency. Next bound an independent Pascal tensor/CQT
  decode and forward control before any recorded scoring; stop this candidate
  if exact model bytes/geometry cannot be reproduced within the declared
  budget. The existing 98% precision, coverage and low/quiet/short gates remain
  unchanged. This is one nonclosing note-identity batch after reassessment.

- 2026-09-23 PESTO private forward/prescreen: a bounded FPC 3.2.2 Win32 Pascal
  decoder and forward probe read the exact checkpoint as raw weights; no pickle
  or third-party inference runtime executed. Frozen physical controls returned
  440 Hz at MIDI 69.322, 55 Hz at 33.253, weak-fundamental 110 Hz at 45.000,
  and quiet 440 Hz at 69.321, all within the declared 50-cent gate. The 55-Hz
  and quiet-440 confidence values were 0 and 0.108, so the model's confidence
  is not qualified as a note-presence threshold. The independently frozen
  recorded policy in ignored `build/pesto-source-screen/recorded-policy.txt`
  then scored every twelfth eligible, fully contained center in the first 30
  seconds of two distinct URMP works. Sonata violin passed with 147/148
  correct (99.324%; one octave error). Allegro flute failed with 26/36 correct
  (72.222%; ten lower-octave errors), against the >=98% per-group necessary
  gate; selected coverage was 100% in both. Several flute octave errors carried
  high confidence. The 57.234-second Pascal run stayed within the 120-second
  time budget; private memory and exact parity with the publisher's runtime
  were not established. Bound WAV/Notes hashes and the exact model identity are
  in the policy; the ignored `recorded.log` SHA256 is
  `8d8d77cd04948e1fa534ea29ead8d105ffe5717892f8d554519f218d1982fd97`.
  Stop this checkpoint candidate under the frozen policy: no shift, threshold,
  feature or checkpoint retuning, no Spring/held-out score, and no maintained
  model provider. This and the preceding source-qualification screen are two
  consecutive nonclosing note-identity batches. The result does not satisfy
  the recorded precision, low/quiet/short, or maintained-delivery criteria and
  earns no credit. Reassess by following the ready
  [NS-2 source/articulation listening task — DONE](DONE/NS-2_synthesis-quality_01.md);
  resume note identity only with independently supported register evidence and
  a prospective ambiguity/coverage contract.
