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

The companion [overlapping-note interval API](OVERLAPPING-NOTES.md) now supplies
separate onset/full-note assignments for chordal roles and repeated pitches;
final checked Win32/Win64 validation passes. The [part-notes file metric](OVERLAPPING-NOTES.md#file-bound-role-timing)
combines interval and center evidence; the center-only diagnostic below remains
available for callers without complete event annotations.

This is a component of the open attributed-mixture task. Center agreement does
not establish event timing, continuous identity through a crossing, acoustic
source separation or an accepted mixture learner. Those criteria remain open.

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
No new note-content parsing, audio inspection or prediction exposure occurs.

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
