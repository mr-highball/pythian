# Joint acoustic and activity generation

[Home](../README.md) · [Corpus](CORPUS.md) · [Activity](ACTIVITY.md) ·
[WAV learning](WAV-LEARNING.md) · [Work](WORK.md)

## One observed pair per analysis hop

`pythian.wfc.joint` learns each stored acoustic palette token together with its
observed silence/onset/sustain label as **one** WFC public token.
It uses the actual companion sequence learner and solver; it does not run
separate acoustic and rhythm solves and then repair their disagreement.

A canonical pair looks like `pythian.joint.v1.3/wr1:a`.
The acoustic index is 0..31. The suffix comes from WFC's real rhythm-cell
encoder: `wr1:r`, `wr1:a`, `wr1:h` for rest, attack and hold.
Decoding uses the same WFC rhythm contract and requires canonical re-encoding.
Malformed/noncanonical input rejects before publishing decoded outputs.

`LearnJointAcousticModel(corpus, activityOptions, order=2)` derives activity
from stored measurements, pairs it with stored palette assignments, and trains
the actual WFC model. Order is 1..4. Each recording remains a separate sample:
no transition is invented across source-file boundaries. Vocabulary contains
only observed pairs, with at most 96 possible pairs for the existing palette.

This reuses the existing archive without FFT or palette retraining. It **does**
train a derived paired WFC model. Activity options and policy version are part
of that derivation; changing them changes the model's meaning.

The same rest/attack/hold vocabulary also represents MIDI rhythm in WFC, but
WAV cells here are analysis hops in samples. They are not inferred beats,
transcribed note events or a known MIDI clock. An onset label identifies a
spectral-change candidate over a window, not an exact transient sample.

## Simultaneous constraints and failure semantics

`TryGenerateJointSequence(model, options, constraints, var sequence, out report)`
returns native acoustic-index and action arrays together.
`TJointConstraint` specifies:

| Field | Meaning |
| --- | --- |
| Position | Zero-based output analysis cell |
| AcousticToken | One palette index, or -1 for any |
| AllowedActions | A set of silence/onset/sustain labels; empty is impossible |

For each constraint, the adapter collects only observed pairs satisfying both
fields and intersects them through real WFC token constraints. Constraints at
the same position intersect; a later one does not overwrite an earlier lock.
A valid lock on an unobserved pair becomes an empty WFC domain and reports
contradiction. It is not silently weakened.

The shared `TryGenerateTokenSequence` helper in `pythian.wfc.generation`
constructs, solves and independently captures/validates the actual WFC path.
The acoustic-only entry point retains its palette-token validation and replay.
Both paths use the existing limits: 1..1024 output cells, at most 262144
state/cell combinations, and 0..65536 backtracks. Constraint count is bounded
by the output cell count. Extent follows WFC fragment/whole/wrap semantics.
A fragment may begin during a sustain; it need not begin at a recording onset.

Successful joint output publishes both arrays together. Invalid input raises;
contradiction and exhausted search retain their distinct WFC report statuses.
Every failure preserves the caller's previous acoustic and action arrays.
A successful solve is a learned constraint result, not a proof of musical
optimality or original composition.

## Reconstruction preserves both labels

`TCorpusGrainPlanner.PlanActions(indices, actions, out report)` requires
exactly one action per requested acoustic token. Configure the planner with the
same activity options used to derive the model. It returns recorded grains
satisfying both labels.
The source clips remain borrowed and must already be bound to corpus hashes.

Each palette token has its original unconstrained candidate pool plus separate
bounded silence/onset/sustain pools. This matters when nearest-center ranking
would otherwise omit every onset under a small candidate budget.
Dynamic contiguous successors are added only when both token and action match.
The existing beam, overlap-probe and output bounds remain in force.

`ValidateGrainActions` checks recorded feature coordinates and selected action
labels. The planner's existing Evaluate pass separately checks token, extent,
rate, gain, output-grid and window contracts. Missing observed pairs reject
instead of substituting another activity class. The original Plan entry point
and its default output remain unchanged.

These are constraints on **selected source-window observations**. Overlap-add,
neighboring grains and release tails can carry sound into a cell labeled rest.
The controls do not promise sample-exact silence or an exactly timed audible
attack. Beat alignment, explicit output articulation and annotated onset
accuracy remain separate work.

## Native operator workflow

```text
pythian.archive remix-joint INPUT.pyac OUTPUT.wav SEED ACOUSTIC_FRAMES ACTIVITY_PATTERN SOURCE.wav [SOURCE.wav ...]
```

The pattern is a nonempty prefix, at most ACOUSTIC_FRAMES characters long.
`a` requests onset, `h` sustain, `r` silence and `?` allows any action.
Positions after the prefix are unconstrained; the pattern does not repeat.
For example, `a???h` locks cell 0 to onset and cell 4 to sustain.
Acoustic locks are available through the Pascal API.

All source files are checked against persisted identities and may be supplied
in any order. The original archive and its saved acoustic-only model remain
unchanged. The command derives the paired model, solves, selects matching
recorded grains, then writes audio and a mapping sidecar.

The sidecar adds joint policy/version, activity parameters, pattern, explicit
analysis-hop grid, model state/observation counts, exact paired model text and
its SHA256. Each grain records acoustic token, activity ordinal
(0 silence, 1 onset, 2 sustain) and source/output coordinates.
The embedded model is a replay/inspection record; the current command derives
it again rather than loading it as a new archive attachment.
The [joint archive adapter](JOINT-ARCHIVE.md) now supplies a separate versioned
attachment, independent count/policy admission and `remix-saved-joint` for
generation without learning. It uses the stored activity policy for grain planning.

The nearest-center comparison in joint metadata ignores activity constraints
and is labeled accordingly. Its cost is not an equally constrained optimum.
The selected plan is bounded beam search. Audio and sidecar writes remain
non-atomic on I/O failure; generation contradiction publishes neither and
preserves existing output files.

## Verified evidence

Checked FPC 3.3.1 i386-win32 full build:
`build/joint-validation.log`. All 37 core units compile without vendor paths;
the seventh WFC adapter stays outside core. Existing core, MIDI, corpus,
scheduler and WFC checks pass, followed by ordinary and joint reconstruction
smokes. There are no authored compiler warnings; upstream WFC warnings remain.

Focused native fixture: `build/joint-focused-validation.log`.
Two independent eight-cell sine recordings deliberately share one acoustic
token across onset and sustain. The test independently checks all three
paired n-gram states and their observation/start/end counts, real model text
round-trip, simultaneous locks, duplicate-position intersection, contradiction
preservation and canonical parsing. With one candidate per pool, reconstruction
still retains the required onset. Source-coordinate checks compare every
selected grain against independently derived recorded actions and tokens.

Published-recording run:

```text
pythian.archive remix-joint build/corpus/shared.pyac build/corpus/shared-joint.wav 731 512 a???h build/corpus/pixel-sprinter.wav build/corpus/opening-theme.wav
```

The source recordings and retained attribution are documented in
[the corpus evidence](CORPUS.md). The archive remains SHA256
`5405acab822bbfdd1d5534987b70ebac066a77ba5da91b48b126a8e97a3072c4`.
Its 5353 observations produce 30 paired public tokens and 243 WFC states.
The generated 512 grains include 57 onset and 455 sustain observations,
with 189 grains from the first source and 323 from the second.

Output: 527360 stereo frames at 44100 Hz, about 11.958 seconds.
Left/right PCM peaks are 0.8817138672/0.7906799316 and RMS
0.1763869154/0.1700824759. There are 341 contiguous links out of 511.
The selected plan's mean normalized seam error is 0.210004; the unconstrained
nearest-center comparison is 1.059554. These measurements do not establish
perceived quality or beat accuracy.

Audio SHA256:

`8776a742a772a5414c9b310ee1da5807002a9017314ad3ed3d43a40e9194a9e1`

Paired model SHA256:

`25cc734ffadf09430dc814fd833964133fa7da7bdda826abe9bd3783100da382`

Reversing source-file arguments reproduced the audio hash.
The optional native fixture invocation checks archive/audio/model hashes,
every published source coordinate and both recorded projections, including
the explicit onset/sustain locks:

```text
pythian.tests.wfc.joint build/corpus/shared.pyac build/corpus/shared-joint.wav.json build/corpus/shared-joint.wav
```

Logs: `build/corpus/shared-joint.log`,
`build/corpus/shared-joint-replay.log`,
`build/corpus/shared-joint-contradiction.log`.
Metrics: `build/corpus/shared-joint-metrics.json`.
Requesting an unobserved silence pair reports contradiction and preserves
the previous WAV and mapping hashes. The earlier acoustic-only continuity
remix still reproduces SHA256
`1bf753cb7507f0df486b7138a027f9f2c4602992a58f7562ad96cea15bce72f7`.

Source-beat alignment remains separate from the explicit PPQ/MIDI
[output articulation stage](ARTICULATION.md), which now supplies exact rests
and fades after reconstruction. The joint model still uses analysis-hop cells.
Operator listening, annotated onset/beat accuracy, broader corpus coverage,
stable FPC and other targets remain unverified. This closes the initial joint
observed-label generation path, not the full WAV music-learning or delivery goal.
