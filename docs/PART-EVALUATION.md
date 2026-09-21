# Simultaneous notes and role evaluation

[Shared evaluation](MUSICAL-EVALUATION.md) · [File operator](EVALUATION-OPERATOR.md) ·
[Task](TODO/NS-3_parts_01.md) · [Separation](SEPARATION.md)

`pythian.evaluation.parts` compares simultaneous MIDI pitch sets for explicitly
named roles. Bass, chordal and lead parts can contain different numbers of notes
at the same center. Role identity comes from the caller's annotation contract;
frequency order, stereo channel, instrument program and stem filename do not
establish musical role. The portable scorer does no inference or source I/O.

The companion [overlapping-note interval API](OVERLAPPING-NOTES.md) now supplies
separate onset/full-note assignments for chordal roles and repeated pitches;
final checked Win32/Win64 validation passes. It does not change the diagnostic-only file
metric below.

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
report cannot grant `independent_case_pass`: event timing and the attributed
mixture acceptance packet are not yet implemented. Existing note/event metrics
and their acceptance contracts remain separate.

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
a demonstrated cause of the residual or permission to widen its bound. A future
explicitly derived mix could have its own verified construction; it must retain
separate identity and must not be called the original mixture. These are existing
task criteria, not a new allocation. The task remains open without partial credit.

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
Next publish the complete reproducible operator packet and establish representative
frozen reference groups, including external role and acoustic timing evidence.
The owning task remains open with unchanged completion credit.
