# Simultaneous notes and role evaluation

[Shared evaluation](MUSICAL-EVALUATION.md) · [File operator](EVALUATION-OPERATOR.md) ·
[Task](TODO/NS-3_parts_01.md) · [Separation](SEPARATION.md)

`pythian.evaluation.parts` compares simultaneous MIDI pitch sets for explicitly
named roles. Bass, chordal and lead parts can contain different numbers of notes
at the same center. Role identity comes from the caller's annotation contract;
frequency order, stereo channel, instrument program and stem filename do not
establish musical role. The portable scorer does no inference or source I/O.

The [reviewed-reference builder](PART-REFERENCE.md) now expands interval truth and
complete uncertainty regions into consistent center cells. Its maintained file
consumer preserves the current reference/scoring contract without inventing labels.

The [mixture reference and admission policy](PART-MIXTURE-POLICY.md) freezes the
initial supported scope, required scenarios, role/acoustic annotation rules and
existing per-role gates before this packet is used for estimator selection or
scoring. It separates uncertainty controls from complete-reference accuracy
cases and keeps provisional recording families out of independent acceptance.

The companion [overlapping-note interval API](OVERLAPPING-NOTES.md) now supplies
separate onset/full-note assignments for chordal roles and repeated pitches;
final checked Win32/Win64 validation passes. The [part-notes file metric](OVERLAPPING-NOTES.md#file-bound-role-timing)
combines interval and center evidence; the center-only diagnostic below remains
available for callers without complete event annotations.

The [maintained measurement/control task](TODO/DONE/NS-3_parts_04.md) is accepted;
the [external reference packet](TODO/NS-3_parts_01.md) remains open. Center agreement does
not establish event timing, continuous identity through a crossing, acoustic
source separation or an accepted mixture learner. Those criteria remain open.

## Preparation coverage audit — 2026-09-21

This inventory applies the [frozen policy](PART-MIXTURE-POLICY.md) to the current
packet. The [external-packet task](TODO/NS-3_parts_01.md) owns the remaining work.
Authored controls establish measurement behavior, while external annotations
must establish what sounds and which musical functions the source supplies.

| Required scenario | Authored evidence | External development evidence | Separate evaluation evidence |
| --- | --- | --- | --- |
| Bass with lead/counterline | Four-role packet with explicit construction | Bass function reviewed locally; lead candidate retains bend and tail uncertainty | Missing |
| Chordal accompaniment and simultaneous parts | Three-note chords with other roles | Two chordal source functions reviewed; complete acoustic pitch sets/intervals unresolved | Missing |
| Pitch-order crossing | Annotated endpoint reversal and wrong-owner control | No qualified crossing annotation | Missing |
| Same-pitch overlap/unison | Two distinct overlapping lead events; coincident lead/chordal pitch | Symbolic concurrency reviewed; acoustic multiplicity/ownership not qualified | Missing |
| Quiet pitched part beneath other material | Bound isolated energy contrast and abstention control | No accepted external energy/ownership case | Missing |
| Rests and boundaries | Constructed gates, silent regions and false-rest control | One isolated bass interval exported; three source-local rests; joined/edge intervals unknown | Missing |
| Uncertain ownership or extent | Explicit uncertain regions and exclusion controls | Unresolved source roles, registration and overlapping tails retained | Missing |
| Articulation/performance | Constructed attacks/releases | Raw bends/controllers retained; source interpretation unresolved | Missing |

The development stems and exact derived mix are bound and verified. The second
recording was initially provisional; the qualified initial recording families
section below records its later accepted split. Distinct source UUID/path/score
hashes alone do not establish unrelated works. No missing row is converted to success by averaging
over the authored controls. Family qualification requires bounded source-work
and duplicate/derivative evidence, not a particular publisher attestation.

Existing operators are sufficient to represent reviewed intervals, uncertain
regions and center references. The next packet work is annotation, evaluation-family
preparation and broader packet coverage. The bounded assembly below now retains
the existing evidence and applies its scoring policy. Reconstructing the historical
renderer or perfectly transcribing all external stems is outside this preparation
requirement; useful
external role/scenario coverage and honest uncertainty remain required. These
distinctions preserve the downstream mixture learner and independent-acceptance
criteria without expanding preparation into an indefinite investigation.

## First external bass reference — 2026-09-21

The bounded seven-event review now produces a usable source-local reference
through the maintained builder. Original keys, renderer triggers and reviewed
acoustic pitches remain distinct. At 16000 Hz, the first S03 event is annotated
as bass, note 38, on `[48047,70950)`: its separately reviewed low harmonic family
supports the pitch, and exact stored support supplies the declared endpoints.
The component has 22573 nonzero and 330 internal zero samples; internal zeros
do not split the event. Bordering zero runs are 48047 and 1080 samples.

The same fixed pass retains all seven events. Events 1–4 share `[72030,117386)`;
events 5–6 share `[120078,132000)` with a context trigger and a censored right
edge. Their individual extents remain unknown. No silence threshold was fitted
to isolate more notes. The convention groups across zero runs shorter than 1024
samples, while retaining every raw run for review; it is not a perceptual limit.

The draft keeps the entire first-eight-second scope: 800 centers, one known event,
three source-local rest regions and two unknown regions. It does not certify the
complete bass role in the mix, other contributors or reference-complete accuracy.
This closes the bounded support investigation; retain the unknowns when assembling
the external packet rather than continuing segmentation variants.

Checked stable Win64 controls, support-report replay and rejection preservation
pass with zero leaks. The 22028-byte report takes 463/481 ms, at most 5459968
sampled private bytes, inside 10 seconds/64 MiB/4 MiB. The unchanged maintained
builder then produces identical 77851-byte references in 725/695 ms, at most
9158656 sampled private bytes, also with zero leaks. The final reference SHA256 is
`3e480852c296838161787e551cf9416405c6d60c52b8d4d4690b9b30704ae124`.
The complete seven-event decision and source/policy bindings are under
`build/role-reference-draft/`; final evidence is in `build/qa-batch-22/`.
This is primary reference annotation and representation acceptance, not listening
or an independent mixture-learner verdict.

## Assembled external development cases — 2026-09-21

The fixed packet now combines all ten derived stems and their exact mix, complete
notices, the eight-second source-local bass reference, contributor/scenario
inventory, uncertainty regions and exposure ancestry. The 30.25-second WAV
excerpts remain unchanged; scoring uses `[0,128000)` at 16000 Hz. Only note 38
on `[48047,70950)` has a complete reviewed acoustic interval. Other active
regions and all full-mixture role pitch sets remain unknown.

The [maintained evaluator](../tools/pythian.evaluate.lpr) scores the bundled
relative cases. With the accepted packet available locally, from the repository
root:

```powershell
New-Item -ItemType Directory -Force build/part-evaluate/units | Out-Null
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools -FUbuild/part-evaluate/units -FEbuild/part-evaluate tools/pythian.evaluate.lpr
./build/part-evaluate/pythian.evaluate.exe build/role-development-packet/qa-a/bass-copy-case.json
./build/part-evaluate/pythian.evaluate.exe build/role-development-packet/qa-a/bass-omit-case.json
./build/part-evaluate/pythian.evaluate.exe build/role-development-packet/qa-a/mix-contribution-case.json
```

Each case covers 800 centers and uses the current `part-notes` contract:

| Scripted diagnostic | Center result | Interval result |
| --- | --- | --- |
| Copy the reviewed isolated bass event | 143 correct note cells | One onset and one full-note pair |
| Omit that event | 143 missed note cells | No pairs |
| Carry the isolated contribution into the unknown mix reference | 143 admitted-unscorable note cells; no known-note denominator | Predicted event remains unscorable |

All three retain `metrics_pass: false`, `independent_case_pass: false` and
`prediction_ancestry_independent: false`, with reason
`prediction-depends-on-reference`. These controls exercise the frozen policy's
application to incomplete references; they are not learner predictions or
independent accuracy. Command exit zero means a valid report. This completes
AC4 policy application for the assembled cases, not the open external-packet
task or its remaining role/scenario and evaluation-family requirements; no task
credit is awarded.

Checked stable Win64 assembly, exact replay, overwrite/outside-root rejection
and relocated CLI scoring pass with zero leaks. The packet has 74 files:
14213152 artifact bytes plus its 9957-byte manifest, SHA256
`8a43ce9a433df6bddd00d98bea302601907a87d9cf5f4aa9a3d8ac03fa78c4c3`.
Assembly takes 6147/5611 ms, with at most 65728512 bytes sampled private memory,
within 60 seconds/128 MiB/32 MiB. Relocated scoring takes 1299 ms; report content
matches the bundled report, with only the CLI's terminal CRLF differing.

The packet's README distinguishes bundled scoring inputs from provenance-only
external caches. Cases resolve paths relative to their own files and run after
copying the packet outside the repository. Reconstructing the assembly requires
its frozen source cache and repository units; this checkpoint does not claim
asset-free reconstruction. Full commands, hashes and preservation checks remain
in `build/qa-batch-23/`. See the [reference packet contract](PART-REFERENCE.md#assembled-development-reference-cases).

## Source-family score screen — 2026-09-21

A separately authorized score-only review compares the complete original scores
of development Track00001 and reserved Track00002. It retains declared identity
text privately and compares pitched note-on content globally and per track/channel.
The fixed normalization removes leading offset, uniform tick-time scale and global
pitch transposition while retaining multiplicity. Every contiguous 32-onset window
is compared; there is no fitted distance threshold or phrase-length sweep.

The native report contains 2061/2365 pitched onsets from 9781/9348 decoded events
and 3781/4394 phrase windows. It finds no complete global or lane correspondence
and no shared 32-onset signature groups; no detail groups are omitted. These are
negative findings under the declared screen, not an automatic independence
verdict. Durations, velocity, instrumentation, performance messages and conventional
drum-channel notes are excluded. Short quotations, inversions, local rhythm edits
and changed accompaniment/interleaving can evade this comparison. Source-work
identity review and model-training overlap remain separate; the reservation is
not promoted by this report. Raw personal identity strings stay private.

Checked Win64 authored controls, exact replay and rejection preservation pass
with zero leaks. Runs take 1617/1543 ms with at most 8626176 bytes sampled private
memory, within 10 seconds/64 MiB/1 MiB. The 13606-byte private report SHA256 is
`f3284471acd321811b3cf2d607cfbd4e83b86e16a0690ba6b8f1477a64ca850e`.
Its policy and evidence remain in `build/role-family-review/` and
`build/qa-batch-23/`; no audio, role annotation, prediction or model selection
was performed for the reserved source.

## Qualified initial recording families — 2026-09-21

The source-work review supplements the frozen content screen with the publisher's
[original-filename index](https://colinraffel.com/projects/lmd/) and the
[matched-recording identity index](https://github.com/craffel/midi-dataset#file-lists).
Both original score MD5s exactly match their declared UUIDs and filename-index
keys; SHA256 bindings continue to identify the actual inputs. The development
score's original filenames agree with its embedded work title. The reserved
score has no embedded title, but its indexed work/artist agrees with the matched
recording's identity. These are coherent distinct work identities, used together
with the bounded negative content comparison, rather than inferred from hashes.

The development score's matched-recording association names a different work.
Retain that conflict: the inferred match is not authoritative over the original
score and must not become an acoustic label. Conservatively keep both development
associations ineligible for evaluation. This is a leakage restriction, not a
claim the differently named works are the same composition. Raw lookup rows,
identities and complete attribution remain private with the source packet.

Final QA accepts Track00001 as development and Track00002 as reserved evaluation
for this initial packet. Each family includes all original stems/scores, mixes,
excerpts, re-encodings, annotations and descendants; do not divide a family by
instrument or window. This qualifies AC3, not unseen archive material or future
ambiguous relationships. Reference-only score review is recorded separately from
tuning; evaluation audio and annotations were still unprepared at this family-review
checkpoint. If reference inspection
influences implementation selection, demote that entire family to development and
reserve fresh material for independent acceptance. Model-training overlap remains
unknown. The screen's stated limitations and all incomplete musical references
remain; no independent accuracy or genre verdict follows.

The frozen decision SHA256 is
`a8163978ed1cd303e79b39ed606e228676cde6a100908553e2f050214f155db5`,
with final acceptance in `build/role-family-identity/ACCEPTANCE.md`. The publisher
filename index is 24857245 bytes, SHA256
`9002b7723f3edeca779e91688802fdd283b8df0c278162a4040f95bde5895805`;
the recording index is 84046293 bytes, SHA256
`f9bb19e7f5d39b22c958a3653f0fac60411fb0e4f0405f5a547d613d81adaa3a`.
The latter was obtained through the publisher-linked HTTP endpoint when HTTPS
was unavailable; it is corroborating/conflict evidence rather than sole identity
authority. The earlier candidate ledger, native screen and development cases
retain their historically provisional fields; they are immutable snapshots.
Future preparation must bind this accepted decision and preserve the split.

Family investigation stops on this scoped disposition. AC3 and AC4 are closed;
useful external role annotations and packet coverage remain under AC1/2/5. The
subsequent evaluation preparation is recorded below. The task stays open with no
additional percentage credit.

## Reserved evaluation mixture preparation — 2026-09-21

The [maintained construction operator](PART-PREPARATION.md) now supports the
qualified reserved family alongside development, using the same fixed 1/16 gain,
PCM16 quantization and zero-offset exact stored-stem sum. The source binding
retains all ten present WAV/MIDI pairs S00–S09, the original mix, metadata/score,
complete notices and the accepted family decision. S10/S11 are declared in
metadata but absent from the inspected archive inventory; they are explicitly
recorded rather than inferred from stale rendering flags. Instrument descriptions
are source metadata, not reviewed musical roles. No musical score events are
decoded by this preparation step.

The binding is 7614 bytes, SHA256
`e41e0ce9a688f8cc2773f1dd6f67a06f73447eb3937a47346a66585249c6d2ce`.
Checked Win64 replay and existing/outside-output rejections pass; binding takes
2473/2024 ms, at most 2969600 sampled private bytes, with zero leaks. Sources are
held against ordinary writes while hashed and the binding is written only after
all required inputs pass. The prior family decision remains immutable.

From the repository root, after compiling the documented operator:

```powershell
./build/part-prepare/pythian.part.prepare.exe build/role-evaluation-reference/qa-a.json e41e0ce9a688f8cc2773f1dd6f67a06f73447eb3937a47346a66585249c6d2ce build/role-prepared/evaluation-example
```

Use a fresh output directory. Reproduction requires the bound local source cache;
generated sources/bindings stay under ignored output. Both accepted preparation
runs retain 3046087 mono frames at 16000 Hz per WAV. Every derived sample matches
the integer scaling oracle and the stored mix has zero residual against the
integer sum of all ten derived stems; its peak is 1804 PCM16 LSB. This establishes
construction, not a qualification of the original publisher mix.

Final checked Win64 controls, two complete evaluation runs, preservation/rejection
and development regression pass with zero leaks. Evaluation takes 11307/11388 ms,
at most 3522560 sampled private bytes, within 180 seconds/256 MiB/1 GiB. All
15 files replay byte-for-byte: 67047241 artifact bytes plus a 7495-byte manifest,
SHA256 `d7c3f42fc42863bc239401f3cdab02ba913052a4c0fd7c58d6a8326d4a023654`.
The development run takes 14451 ms and all eleven WAVs equal the historical
accepted files; its new provenance manifest intentionally reflects the changed
tool/policy identities and the single current `derived-stem-mixture` kind.

The manifest preserves `reference-only-evaluation`, copies the bound family
decision and distinguishes its scoped qualification from unknown training overlap
and unverified broad independence. Musical roles, acoustic timing, original-mix
qualification and independent accuracy remain false. Existing source identity,
exposure and path guards reject unsupported or inconsistent inputs before
publication. Full evidence is retained in `build/qa-batch-24/` and
`build/role-prepared/evaluation-qa-a/`. This advances AC1/5 source preparation;
role annotations and complete packet coverage still gate task completion.

## Core contract

`EvaluatePartCells` takes stable role IDs, reference/prediction cells, annotated
crossing endpoints and a nonempty half-open source-frame scope. Both arrays must
retain the same strictly increasing center grid and every declared role at every
center. The caller must establish that the grid covers the intended experiment;
matching arrays alone cannot detect jointly omitted difficult regions.

Each role has a state and a strictly increasing set of MIDI pitches 0..127.
`value` requires at least one pitch; `rest`, `unknown`, `ambiguous` and
`unsupported` require an empty set. A separate `unassigned_notes` set preserves
known pitches whose owner is unspecified. It never earns per-role credit.

Counts use **pitch/center pairs**, not events or duration. Each role reports:

- Reference and prediction counts for all five states; reference notes,
  scorable predicted notes, exact matches, misses and extras.
- Coverage = correct/reference notes; precision = correct/scorable predicted
  notes; reference coverage = known value/rest centers/all centers. Empty
  denominators produce zero. Unknown predictions remain misses against known
  notes. Predictions against uncertain references are explicitly unscorable.
- False notes in annotated rests; uniquely attributable matches; matches whose
  acoustic owner cannot be established; and extra pitches divided into known
  wrong ownership, multiple possible wrong owners, unresolved ownership and
  pitches absent from a complete reference.

The leakage matrix has reference owners as rows and incorrect predicted owners
as columns. It credits a unique owner only when every reference role is known,
exactly one role contains the pitch and reference unassigned notes do not contain
it. Same-pitch unisons can agree with role labels but cannot prove which acoustic
source was followed. Incomplete truth cannot certify unique ownership.

Crossings are explicitly annotated pairs of monophonic reference endpoints with
strictly reversed pitch order. Role indices are canonical (`first_role <
second_role`); spans sort strictly by before frame, after frame, first role,
second role. Endpoints must exist in the common grid. Predictions are correct
only when both roles match at both endpoints, wrong when all endpoints are known
but differ, and unavailable when any endpoint is uncertain. No claim is made
about the intervening path, unannotated crossings or same-pitch unison endpoints.

Budgets are 32 roles, 262144 centers, 1048576 role/center entries per side,
4194304 combined pitch entries, 4096 crossing spans and source frames through
2^53-1. Role IDs are unique nonempty trimmed strings of at most 256 bytes without
NUL. Inputs are borrowed and remain unchanged; malformed data raises `EAudio`
without replacing a caller's previously assigned result.

## Source-bound operator

Use the existing `pythian.evaluate CASE.json` command and its current case,
clock, byte-binding and exposure-ledger contract. No second case format or
historical reader is introduced. The annotation policy declares:

```json
{"output":"part-note-sets","input_class":"attributed-parts",
 "purpose":"diagnostic"}
```

These are three fields within the complete annotation object documented by the
operator. The scoring policy uses `metric: "part-note-sets"`,
`unit: "role-MIDI-sets"` and `vocabulary` containing stable role IDs in array
order. Its other required fields remain unchanged. Tolerances and `minimum_f1`
are zero. Coverage must be at least 0.80, precision at least 0.98 and reference
coverage exactly 1; experiments may tighten coverage/precision before scoring.

Reference and prediction `observations` contain cells such as:

```json
{"frame":100,"parts":[
  {"state":"value","notes":[36]},
  {"state":"value","notes":[48,52,55]},
  {"state":"unknown","notes":[]}],"unassigned_notes":[72]}
```

Every part object always contains exactly `state,notes`, including empty note
arrays. The reference additionally requires `crossings`, an array of objects
with `first_role,second_role,before_frame,after_frame`. An empty crossing array
means no crossing was evaluated. Predictions do not contain crossings.

The report includes every role separately, the leakage matrix, unassigned pitch
accounting and crossing endpoint counts. Diagnostic `metrics_pass` requires
positive annotated notes and the declared gates **for every role**, no reference
unassigned notes, no unscorable/extra unassigned predictions, correct endpoints
for every annotated crossing and a declared complete reference. Matching
unassigned predictions add no role credit. There is no pooled dominant-part
score that can hide a weak role; a role containing only rests provides no
positive evidence and cannot pass.

`purpose: "primary"` is rejected for this metric. Even a perfect diagnostic
report cannot grant `independent_case_pass`. Event timing is available through
the [part-notes metric](OVERLAPPING-NOTES.md#file-bound-role-timing); independently
qualified mixture references and learned attribution remain open. Existing
note/event metrics and their acceptance contracts remain separate.

## Validation and next evidence

The maintained core fixture includes an independent 4096-case bit-mask oracle,
chords, unisons, role swaps through crossings, unknown owners, incomplete
references, rest errors and input/result preservation. The file fixture adds
source-bound replay, per-role gating, missing centers/roles, duplicate notes and
crossings, integer overflow and rejection of a primary claim. Final checked
stable Win32/Win64 executions pass with zero leaks, including existing file-bound
phrase, annotation and ancestry regressions; both operator builds pass. Commands,
source hashes and resource logs are retained in `build/qa-batch-14/`. The build
runs the core fixture alongside shared evaluation. These authored controls prove
scoring behavior, not musical attribution from a recording.

The next evidence is a bound stem/mix preparation and per-role interval timing
packet with explicit supported mixtures, annotation uncertainty and frozen
recording families. Instrument metadata alone does not close these requirements.
The selected synthetic development source and its retained license are recorded
in [provenance](PROVENANCE.md#attributed-mixture-development-source).

### Initial stem/mix preflight — 2026-09-21

The native preflight binds one development mix and ten matching stored WAV/MIDI
pairs. All WAVs are mono 16-kHz PCM16 with 3864916 frames. It compares every
frame at the fixed candidate of unity stored-stem gain and zero offset, without
reapplying metadata gain. Raw MIDI counts retain controller/pitch-bend events;
they do not establish sounding note extents. Metadata marks all present pairs
unsaved, so the binding preserves that contradiction and the absent source entry.

The fixed sum **does not qualify** as verified mixture preparation: 3796899 frames
have nonzero residual, peak residual is 13 PCM16 LSB and RMS residual is
5.7881281944898015 LSB. There are 433 frames above the predeclared 11-LSB candidate
rounding bound. Even a pass under that bound would not prove undocumented
resampling or renderer latency. No fitted gain, offset or wider threshold follows.

Checked stable Win64 controls, complete source traversal and wrong-hash/existing-
output rejection pass with normal cleanup and zero leaks. The valid pass reads
85176724 bound bytes, takes 4257 ms including supervision, and reaches 3874816
bytes sampled peak private memory. Its 12988-byte native report is retained at
`build/role-reference/report.json`, SHA256
`bd47eb1bc7c647939ab5e5410d310cfa62f08e79edd2caac41a22ab66fea0e90`.
Binding SHA256 is
`060e2bd37e99f62be5c71166d104eee63ed2507d71276ff71ab358aaff4ca222`;
the complete source/commands and preservation checks remain in the QA directory.

The subsequent controlled packet below supplies per-role interval timing and
authored mixture cases. For this external bundle, establish preparation from
independent evidence before treating its stored mix as a verified reference.
A bounded inspection of the [pinned publisher utility](https://github.com/ethman/slakh-utils/blob/3f62d6a4b0e5952237dd5178ac3513e42161ec0a/resampling/resample.py)
shows independent mix/stem resampling, but the inspected record does not bind
that utility or its numerical environment to these archive bytes. This is not
a demonstrated cause of the residual or permission to widen its bound. The
[derived preparation operator](PART-PREPARATION.md) supplies a separate construction
from the stored stems, with its own identities and fixed quantization/gain policy.
It does not qualify the original mixture. These are existing task criteria, not
a new allocation. The task remains open without partial credit.

### Derived external development packet — 2026-09-21

The maintained [preparation operator](PART-PREPARATION.md) now constructs a
qualified **derived** packet from the ten bound development stems. Each is scaled
by the predeclared 1/16 gain, quantized once, stored and verified sample by sample
against an independent integer rounding oracle. Reopened derived stems sum exactly
to the reopened mix at all **3864916 mono frames, 16000 Hz**. Mix peak is 1819
PCM16 LSB; reconstruction residual is zero. Every stem's largest quantization
error relative to ideal scaling is half an output LSB. These attenuated,
requantized stems are the new reference assets; original files remain unchanged.

Checked stable Win32/Win64 arithmetic controls and complete Win64 preparation QA
pass with zero leaks. Two fresh runs take 14620/14549 ms, at most 3502080 bytes
sampled private memory, and produce **14 files / 85060427 bytes**. Every file,
including the manifest, replays exactly. Wrong hashes, existing output directories,
empty stem lists and unsafe paths reject without overwriting accepted output.
Stereo roundtrip and malformed-WAV geometry branches were source-reviewed;
the complete real-data run exercises mono. No broader runtime coverage is implied.

The packet's `build/role-prepared/qa-a/manifest.json` SHA256 is
`459b1156772d237a4eb41b74d6ada8880b5ddd81ac6b20895f39cc7bc008e3f1`.
It binds original ancestry, policy, tool/core sources, output identities and the
full source license. Commands and resource/preservation evidence remain under
`build/qa-batch-17/`. This qualifies the declared construction and preserves
source-frame positions; it does not establish score-to-acoustic latency, musical
roles or the publisher mix's preparation. All derivatives retain development
exposure and add no independent recording or unique source duration.

### Prospective recording groups — 2026-09-21

The native identity ledger freezes Track00001 as development and Track00002 as a
provisional evaluation reservation before accessing the latter's metadata or raw
score bytes. It checks only declared UUID/original-score path and exact score
hash. The three identity comparisons differ. This excludes those exact collisions;
related arrangements, transpositions and estimator training overlap remain unknown.
The reservation remains provisional, with `independent_family_verified: false`.
That initial identity audit performed no note-content parsing, audio inspection
or prediction exposure. The later [score-only screen](#source-family-score-screen--2026-09-21)
adds a separately declared, bounded source-work review.

Checked Win64 controls, bound ledger execution and wrong-hash/overwrite rejection
pass with zero leaks. The audit takes 248 ms and 2699264 bytes sampled private
memory. Its `build/role-groups/ledger.json` SHA256 is
`75f84d9be9597fea3cbeac4629a56bee1e0dcbd9b77e525931bf1cb7f957750d`;
the same QA directory retains its frozen source/binding and preservation checks.

The next development evidence is one fixed 30-second worksheet across all ten
derived stems and mix, retaining MIDI performance messages, original sample
coordinates and descriptive acoustic measurements. Start role and sounding-note
labels as unknown. Review functions and acoustic boundaries from the source
evidence before evaluating predictions; instrument names and key gates are not
automatic role/acoustic truth. Broader family qualification, supported scenario
coverage and frozen acceptance thresholds remain in the same open task.

### Development annotation worksheet — 2026-09-21

A bounded native diagnostic now exports the fixed first 30 seconds of all ten
derived development stems and their mix, with a separately declared 250-ms right
context. Each of eleven PCM excerpts has 484000 frames; each amplitude document
retains all 3000 consecutive 10-ms blocks in the scored scope, with exact nonzero
count, integer peak/squared sum and descriptive RMS. No amplitude threshold
creates a note, rest or role annotation.

The ten companion MIDI documents preserve raw scoped payloads, rational PPQ tempo
positions, explicit floor-to-frame mapping and symbolic key gates. Controller,
bend and SysEx evidence remains visible. Concurrent same-pitch starts retain
pairing ambiguity; unclosed gates retain right censoring. Unsupported time/routing
declarations reject instead of disappearing from a note-only projection. The
owned decoder traverses 12139 events across the full bound MIDI inputs; that is
not a count of sounding notes or events inside the 30-second scope. This fixed
source encounters no unsupported mapping. Synthesizer latency, controller effects
and acoustic tails remain unestablished; **all acoustic and role labels are unknown**.

Final checked Win64 controls, two fixed exports, replay and wrong-hash/path/overwrite
rejection pass with zero leaks. All **36 files / 13302611 bytes** replay exactly,
including the manifest. Executions take 12042/12099 ms and at most 14241792 bytes
sampled private memory, within 60 seconds/256 MiB/32 MiB. Inputs and accepted
outputs remain unchanged on rejection. The diagnostic is currently a private
Windows native study; no new portable-core platform dependency is introduced.

`build/role-annotation/qa-a/manifest.json` has SHA256
`27c443f782c47441fec8c203fc3673c58ecddd7e8e4d89bb161a45c012b65ce4`.
It binds prepared/original ancestry, producer source and policy, excerpts, symbolic
and amplitude evidence, and retained license. Complete validation records are in
`build/qa-batch-18/`. Exact coordinates belong to the attenuated/requantized derived
waveforms; their quiet tails may differ from the original stored stems.

The [maintained reference builder](PART-REFERENCE.md) separately passes checked
Win32/Win64 tests and a generated-reference roundtrip through the current
`part-notes` scorer. The next step is to review this fixed worksheet for defensible
musical functions and acoustic labels, retaining uncertainty and missing coverage,
then bind reviewed regions through that builder. No prediction is available to
influence those labels, and no separate recording is consumed by this diagnostic.

### Fixed worksheet review — 2026-09-21

A cache-only native review now verifies and summarizes the accepted worksheet's
ten symbolic and ten amplitude documents, without reading new audio, evaluating
a model or opening the reserved second recording. It retains every gate starting
in the fixed first eight seconds, plus separate full-scope and 250-ms context
counts. Rational gate occupancy distinguishes simultaneous voices, distinct pitches,
same-pitch multiplicity and conservative uncertainty. The table concerns the
existing 30-second development scope; retained raw-event totals also include
the separately declared context.

| Stem | Gates starting in scope | Maximum distinct known gate pitches | Digitally zero 10-ms blocks / 3000 |
| --- | ---: | ---: | ---: |
| S00 | 29 | 3 | 708 |
| S01 | 126 | 3 | 300 |
| S02 | 66 | 5 | 314 |
| S03 | 37 | 2 | 678 |
| S04 | 13 | 4 | 1308 |
| S05 | 29 | 5 | 694 |
| S07 | 19 | 2 | 1427 |
| S08 | 13 | 4 | 2520 |
| S09 | 7 | 1 | 2515 |
| S10 | 0 | 0 | 3000 |

The complete retained input contains **343 gates and 1521 raw events**; four gates
start in context (one S01, three S05). S02 and S03 each have one unclosed gate;
each contributes 360960/96 microseconds of conservative uncertain occupancy in
scope. S05's three unclosed gates start in context and contribute none in scope.
There are no ambiguous pairings; maximum known same-pitch gate multiplicity is
one in every active stem. That is a missing external repeated-note scenario,
not proof that acoustic
same-pitch tails never overlap. S10 has no gates and no nonzero stored samples
here; it cannot supply a positive role-accuracy case.

S01's bound source metadata identifies percussion. Its symbolic keys remain raw
events, not acoustic semitone references, and its audio stays in the mix. Pitch-bend
messages are retained for S00/S07/S08/S09 (256/128/33/32 respectively); S00 also
contains changing noncentral raw bend values during its opening key gate. The
renderer's bend range and sounding trajectories have not been established. Nominal
key numbers therefore cannot silently become exact constant-pitch acoustic truth.

The first-eight-second score-context review supports **candidate functions**, not
admitted waveform labels:

- S03's repeated pitch 50 begins with S02's simultaneous 57/62/65, and its move
  to 55 begins with S02's 55/59/62/67. Repeated root support coordinated with those
  chords makes S03 a bass candidate; this reasoning uses their relationship,
  not its instrument name or lowest frequency alone.
- S02's coordinated groups and S05's sustained 74/77/81 group support chordal
  candidates. They may share a function; one stem per role is not required.
- S00's opening changing line and later return to 64/67/64/62 support a thematic
  lead candidate. Foreground function and its bent acoustic pitches still need
  evidence. S04 and S07 retain unresolved supporting functions; S08/S09 have no
  starts in the fixed first eight seconds but do have later events in the scope.

This is a primary score-context review using the hash-bound gate table and raw
messages, with no listening verdict. Candidate functions are recorded separately
from the still-unknown acoustic references. Do not relabel whole stems over all
30 seconds from the opening passage or omit unresolved pitched contributors.
The next annotation work must examine the actual fixed passage, distinguish
per-note support from aggregate stem energy, and retain bends, acoustic tails
and unresolved roles explicitly under the [frozen mixture policy](PART-MIXTURE-POLICY.md).
It must also establish which required scenarios the external packet covers;
crossings, relative-energy masking and same-pitch acoustic overlap remain unproven.

Final checked Win64 controls, exact summary replay and output/path preservation
pass with zero leaks. Runs take 3621/3432 ms, at most 15028224 bytes sampled private
memory, and emit 20149 bytes, within 5 seconds/64 MiB/256 KiB. The first submission
exposed a signed-32-bit `Min` overload on rational time; an explicit 64-bit clamp
and regression above 2^31 pass the repaired submission without changing limits.
The private report `build/role-review/qa-a.json` has SHA256
`13703fce36ff2c5d54a8bf68ee0780d5e1adbf0c644045c039859281153b3e15`;
its source, policy, input bindings and complete QA remain in `build/qa-batch-19/`.
This review closes no task and changes no milestone credit.

### Fixed acoustic support review — 2026-09-21

The next bounded pass observes the already selected first eight seconds of
S03/S02/S05/S00, using the owned WAV reader and Fourier primitive. Each stem
retains 775 fully contained symmetric-Hann windows of 4096 frames, hop 160,
with all 2049 nonnegative-frequency powers. No resampling, fitted frequency band,
pitch estimator or new recording is involved. Raw powers, complete spectral
views and a local-maximum index remain hash-bound under ignored build output.
The view uses one fixed power reference per stem; darkness across stems does
not compare loudness. The 10-ms hop does not give 10-ms boundary resolution:
each observation spans 256 ms. Integer review markers use `start + 2048`;
the exact symmetric-window midpoint is `start + 2047.5`.

Primary review inspected all four complete views and six numerical anchors fixed
before observing results. Frequencies below are bin centers, not interpolated
fundamental estimates. This is score/spectral review with no listening verdict.

| Source and integer frame marker | Observed support | Reference consequence |
| --- | --- | --- |
| S03, 55968 and 76768 | Strongest peak 74.21875 Hz, with components near 148.4375, 218.75 and 292.96875 Hz | Harmonic spacing is consistent with roughly 73 Hz, an octave below nominal key 50; copying the key would misstate observed register |
| S03, 103968 and 123168 | Strongest peak 97.65625 Hz with 195.3125/292.96875 Hz and higher components | The changing low line is supported; nominal key 55 likewise is not a directly verified acoustic fundamental |
| S02, 55968 | Components at 218.75/292.96875/347.65625 Hz and harmonics | Supports the coordinated 57/62/65 chord candidate |
| S02, 103968 | Components at 246.09375/292.96875/390.625 Hz | Supports changing accompaniment; a complete four-note set is not established by the strongest twelve peaks |
| S05, 55968 and 76768 | Strong components at 292.96875/347.65625/441.40625 Hz plus octave/higher components | Sub-octave components relative to keys 74/77/81 prevent direct key-to-acoustic labels; registration/layer interpretation remains unresolved |
| S00, 103968 | Strongest remaining local peak 582.03125 Hz, about -56.82 dB relative to that stem's maximum | Stored spectral support persists after symbolic key-off; this is neither exact sounding duration nor perceptual presence |

The primary reviewer now assigns **source functions** over the explicit review
scope `[52000,112000)` (3.25–7 seconds): **S03 bass; S02 and S05 chordal**.
The low repeated/changing line coordinates with measured sustained multi-frequency
accompaniment and the separately retained score relationships. These bounds identify the
reviewed passage, not detected role changes or note endpoints. This is one primary
review; other contributors remain unassigned and S00 remains a lead candidate.
The later low S02 key 43 falls outside this role-review scope and requires its own
functional assessment. Acoustic pitch sets, event timings and complete ensemble
references are still unaccepted.

Do not impose a blanket octave shift or multiply note events to explain the
sub-octave components. The source metadata does not establish their rendering
cause. Preserve source-key identity separately from observed register, harmonic
layers and uncertainty. The short S03 transition at marker 92768 straddles a
256-ms window, so it does not supply a clean stationary reference. Overlapping
tails and S00's bends likewise remain unresolved. These findings belong to the
existing [reference preparation](TODO/NS-3_parts_01.md) criteria; they coordinate
with [pitch identity](TODO/NS-3_notes_01.md) and
[evolving sound](TODO/NS-3_timbre_01.md) without adding a dependency cycle.
No learner correction or newly scored estimator follows from this review.

Final checked Win64 export and view controls, full packet replay and rejection/
preservation checks pass with zero leaks. Export takes 6314/6337 ms, at most
5992448 bytes sampled private memory, and writes 50820060 bytes. View generation
takes 4312/4277 ms, at most 29396992 bytes sampled private memory, and writes
7214319 bytes. Both stay within 30 seconds/128 MiB; output limits are respectively
64/32 MiB. These are private preparation diagnostics, not new core dependencies.

`build/role-support/qa-a/manifest.json` has SHA256
`66517a2f14afdde28389b288ea6bdfea2786d41ed28c0e236d9c1c150eebbaca`;
the view manifest is
`747fde261b156c8008c6813b8fe6a964dd306b360219e462f458519124c396c4`.
The primary interpretation is retained in `build/role-support-view/ANNOTATION.md`;
complete commands and final QA remain in `build/qa-batch-20/`. Runtime verification
accepts the diagnostic mechanics, not the musical labels or independent inference.
Next resolve the demonstrated register/registration distinctions and acoustic
boundaries before constructing reference events. No task closes or earns credit.

### Original-to-trigger bass correspondence — 2026-09-21

The fixed bass comparison now verifies the already bound original score against
the separated S03 MIDI. It first selects a unique stable program-33 track/channel
without using pitch similarity: original track 0/channel 1 and separated track
1/channel 0, both PPQ 96. All **seven** gates starting in `[0,8 seconds)` pair
uniquely by exact rational onset, key-release time and onset velocity. Every gate
is closed and unambiguous; the separate context through 8.25 seconds retains
endpoints without adding later starts to the cohort.

| Original key | Separated key | Paired events | Difference |
| ---: | ---: | ---: | ---: |
| 38 | 50 | 3 | +12 semitones |
| 40 | 52 | 1 | +12 semitones |
| 43 | 55 | 1 | +12 semitones |
| 31 | 55 | 2 | +24 semitones |

Every pair matches the predeclared transformation: octave-fold the original key
into 35..79, then add 12. Simple `original + 12` fails the final two events. In
the pinned primary [rule configuration](https://github.com/ethman/slakh-generation/blob/e6454eb57a3683b99cdd16695fe652f83b75bb14/midi_rules/pitch.json),
the bass shift is enabled. Its
[rule dispatcher](https://github.com/ethman/slakh-generation/blob/e6454eb57a3683b99cdd16695fe652f83b75bb14/midi_inst_rules.py)
applies both listed rules once any is enabled, including the range rule marked
disabled. The [generation path](https://github.com/ethman/slakh-generation/blob/e6454eb57a3683b99cdd16695fe652f83b75bb14/render_by_instrument.py)
applies those rules before saving the separated MIDI. This is verified event
correspondence compatible with that implementation, not proof of the archive's
exact producer revision or preset behavior. External code was read, never executed
or adopted as a dependency.

The acoustic review's roughly 73-Hz family at markers 55968/76768 now has original
key 38 and trigger 50 linked to the same events. At marker 103968, the roughly
98-Hz family has original 43 and trigger 55. At 123168, similar acoustic support
instead accompanies original **31** and trigger **55**. Thus two different original
registers collapse to the same trigger; blindly restoring the original key would
also misdescribe this observed register. Keep original, transformed and acoustic
evidence distinct under the [reference contract](PART-REFERENCE.md#pitch-identity-in-an-acoustic-reference).
The existing waveform evidence supports local register interpretation; the MIDI
comparison supplies no new acoustic measurement, endpoint or complete pitch set.
It does not resolve the separate organ registration or guitar bend cases.

Checked stable Win64 controls, exact report replay and rejection/preservation QA
pass with zero leaks. Runs take 483/487 ms and at most 5566464 bytes sampled
private memory; each report is 17490 bytes, inside 10 seconds/64 MiB/256 KiB.
The 10781 decoded events are whole-file traversal, not sounding-note or scoped
event counts. The private report `build/role-register-compare/qa-a/report.json`
has SHA256 `febb9855cc4a10cc9a59a91bf8a93b2681c580fdeab5d6e6ed89801dd367a3fc`.
It retains source identities, raw performance evidence, all pitch pairs and
explicitly false acoustic-truth/producer-proof claims. Full QA is in
`build/qa-batch-21/`; the owning preparation task remains open without credit.

<a id="authored-stem-mix-controls--2026-09-21"></a>
### Authored stem/mix controls — 2026-09-21

The native packet in `build/role-controls/` defines 21 events across bass, chordal,
lead and other roles before rendering a twelve-second mono 16-kHz source. Each
stem is quantized first; the mix sums those stored integer samples at unity gain
and zero offset without clipping. Reopening all four stems and the mix verifies
all 192000 frames exactly, with no samples outside declared note gates. Five-ms
attack/release transitions lie inside those gates; quantization and waveform zeros
mean nonzero sample support can be shorter than nominal note extent.

Six frame-set controls pass their independently specified counts: exact known
truth, a missing chord member, a role swap through the declared crossing, a
hallucinated note in rest, abstention on a quiet lead and assignment within an
uncertain reference region. The 1200-center grid includes 100 uncertain centers.
The measured quiet-lead energy is 0.010634436272084713 and simultaneous chordal
energy 79.570625537075102 in the frozen window. This establishes the intended
energy contrast; it is not a listening judgment or inferred source attribution.

Seven per-role [timing reports](OVERLAPPING-NOTES.md#validation-status) additionally
exercise exact identities, reordered same-pitch overlaps, a damaged note offset
and explicit reference uncertainty. Frame sets intentionally collapse same-pitch
multiplicity; the interval reports preserve both authored events.

Final checked Win64 controls, two complete fresh packet runs and overwrite
rejection pass with zero leaks. All 34 nonmanifest artifacts replay byte-for-byte;
manifest elapsed time is observational. Rejection preserves all 35 packet files.
Each packet occupies 3744215 bytes; runs take 5401/5429 ms and at most 28762112
bytes sampled private memory, below the frozen 30-second/256-MiB/8-MiB budgets.
The first packet's manifest SHA256 is
`636fb10978f57be2cd85ffe79de53a24b360de6da4e21c0e441b869a61c5413d`;
its audio-verification SHA256 is
`0504e9bf94ace2bbba678fcd0a7c57e0b8f0b49a82da24741c40420df6331fd7`.
Full commands, source hashes and artifact comparisons remain in `build/qa-batch-15/`.

The manifest explicitly records the shared authored score behind source,
reference and scripted predictions. It is a control packet, not an independent
estimator case, and it does not repair the external bundle's preparation failure.
The maintained operator below publishes the reproducible construction. Next
establish representative frozen reference groups, including external role and
acoustic timing evidence.
The owning task remains open with unchanged completion credit.

### Maintained packet operator

The accepted authored construction is now available from maintained source as
[`pythian.part.controls`](../tools/pythian.part.controls.lpr), with the
[source policy](PART-CONTROL-POLICY.md) and
[timing policy](PART-CONTROL-TIMING-POLICY.md). It needs the repository's native
units and existing FPC toolchain, with no private reference assets or downloaded
models. From the repository root on Windows:

```powershell
New-Item -ItemType Directory -Force build/part-controls/units | Out-Null
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools -FUbuild/part-controls/units -FEbuild/part-controls tools/pythian.part.controls.lpr
./build/part-controls/pythian.part.controls.exe --controls
./build/part-controls/pythian.part.controls.exe build/role-controls/example
```

Use a fresh output directory for every packet. Existing directories reject before
writes; failures do not overwrite an earlier result. The maintained build also
compiles this operator and runs its small arithmetic controls; full packet
generation is explicit. It emits native stem/mix WAVs, source score, reference
and scripted predictions, reports and a manifest under ignored `build/`.

The manifest identifies tracked policies and tool source rather than private
prototype paths. It records the shared authored score behind source and
predictions; the output is an authored-control packet, not a falsely independent
`pythian.evaluate` case. These are complementary native consumers of the same
library scorers. Final checked Win64 arithmetic controls, two fresh packet runs
and overwrite rejection pass with zero leaks. Every generated WAV matches the
accepted private construction byte-for-byte; all 34 nonmanifest artifacts replay
between maintained runs, and rejection preserves all 35 files. The updated source
and policy identities appropriately change provenance JSON.

Runs take 5396/5442 ms with at most 28798976 bytes sampled private memory. Each
packet remains 3744215 bytes, within the unchanged 30-second/256-MiB/8-MiB bounds.
The maintained first manifest SHA256 is
`06c0733427f22dd961fa92381125b5150120e7f9cb7ced2666f48f8f72edea1d`.
Build commands, source identities and exact artifact comparisons are retained in
`build/qa-batch-16/`. This accepts reproducible control-packet delivery; external
mixture and role qualification still belong to the open task.
