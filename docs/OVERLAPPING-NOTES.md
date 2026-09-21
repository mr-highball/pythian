# Overlapping-note timing evaluation

[Role evaluation](PART-EVALUATION.md) · [Shared evaluation](MUSICAL-EVALUATION.md) ·
[Task](TODO/DONE/NS-3_parts_01.md)

`pythian.evaluation.notes` supplies native interval scoring for one declared role
at a time. It accepts chords, arbitrary input order and overlapping repeated
pitches. The existing monophonic scorer keeps its ordered-matching contract;
this API provides unrestricted one-to-one assignment where chordal timing needs
it. Neither scorer determines musical role or acoustic ground truth.

For example, references `(100,400,69)` and `(110,200,69)` and predictions
`(100,200,69)` and `(110,400,69)` describe two overlapping notes of the same pitch.
With a ten-frame onset tolerance and exact offsets, two full-note matches require
crossing the input ordering. The ordered matcher permits one. The new matcher
permits both, with twenty frames total onset error and zero offset error.
Onset-only matching instead pairs equal starts, with zero onset error and four
hundred frames offset error. Those are separate assignments, not contradictory
error reports.

## Inputs and reference coverage

`EvaluateOverlappingNotes` takes reference and prediction arrays, a reference
region partition, an absolute half-open source-frame scope and explicit options.
Each event has a stable `Id`, integer `StartFrame`, `EndFrame` and MIDI `Pitch`.
Intervals are nonempty; IDs are unique within each side, trimmed, nonempty, at
most 256 bytes and contain no NUL. Two events can share pitch and timing while
retaining distinct IDs and multiplicity. Inputs are borrowed and remain unchanged.

Reference regions must exactly partition the entire scope without gaps or
overlaps. `esValue` declares complete exact note annotations, including gaps
between supplied events. `esRest` additionally asserts that no reference note
intersects the region. An intersecting reference contradicts that state and
rejects. Unknown, ambiguous and unsupported regions retain separate frame counts.
Reference coverage is known value/rest frames divided by the entire scope.

Events not wholly inside the common edge-excluded scope are reported as
`ReferenceCensored` or `PredictionCensored`; intervals are never clipped. Of the
remaining events, any that intersect uncertain reference regions are reported as
`ReferenceUncertain` or `PredictionUnscorable`. Such events are excluded from
both matching denominators. This is explicit region exclusion, not a claim to
match uncertain onset/end ranges. A long prediction crossing an uncertain region
is wholly unscorable; callers must inspect those counts and reference coverage
before making any acceptance claim. The API itself provides no acceptance verdict.

Known regions include independently annotated gaps, so unmatched predictions
there count as extras, including notes in explicit rests. Uncertainty is not
silence. Role assignment, complete annotations, source identity and exposure
history remain caller obligations. Evaluate every role separately; do not copy
unassigned events into multiple roles or let a dominant role hide missing parts.

## Matching and reports

An eligible onset pair has equal MIDI pitch and absolute onset error no greater
than `OnsetToleranceFrames`. Full-note eligibility additionally requires offset
error no greater than the larger of `MinimumOffsetToleranceFrames` and the
reference duration times `OffsetFractionNumerator / OffsetFractionDenominator`.
The fraction is compared with bounded integer products, without floating rounding
at an admission boundary. Onset/offset minima are explicit; there are no inferred
tempo or acoustic-latency corrections.

For each metric independently, matching maximizes pair count, then minimizes
total onset error, then total offset error. A residual bipartite graph and shortest
augmenting paths permit reassignment of earlier pairs. Negative reverse costs
are represented as two integer cost fields; costs are not packed into a large
scalar. Exact ties follow deterministic canonical UTF-8-byte ID traversal. This
does not promise the lexicographically smallest pair list among tied optima.

`Onsets` and `FullNotes` each return their own event-ID pairs, per-pair errors,
total errors, missed/extra IDs, recall, precision and F1. One event can appear
only once in an assignment. Zero denominators yield zero. Pairs and unmatched
IDs are returned in canonical reference/ID order, independent of input ordering.
Candidate checks, eligible edges and matching work are reported separately.

## Resource and failure contract

Limits are 4096 events per side, 256 selected events per pitch per side, 16384
reference regions, 16777216 event/region checks, 262144 eligible onset edges and
50000000 edge examinations across both assignments. The scope is at most
1000000000000 frames; absolute coordinates still reach 2^53-1. These limits keep
duration products and aggregate costs within signed 64-bit integers. The offset
fraction denominator is 1..1000000 and numerator 0..denominator. Timing tolerances
are 0..10^9 frames. Edge exclusion must leave a nonempty interior.
An optional `AMatchingWorkLimit` argument can lower the 50000000 matching limit
to any value from zero through that maximum. Its default preserves the ordinary
per-call limit; a caller evaluating multiple roles can pass the remaining shared
budget to each call. Zero allows results requiring no edge examinations and
rejects as soon as matching work would begin.

Malformed inputs, contradictory rests and exceeded work bounds raise `EAudio`.
No partial result replaces the caller's previously assigned managed result.
Long sources need explicitly scoped evaluation windows and retained censored
counts, not silent event truncation or changing tolerances to fit a budget.

## Validation status

Final checked stable Win32/Win64 QA passes with zero leaks. The maintained fixture
includes three counterexamples to ordered
matching, a brute-force assignment oracle for 64 small cases, independent
onset/full-note error accounting, permutation/tie replay, repeated-note
multiplicity, rational tolerance boundaries, uncertain/censored regions, rest
errors and rejection preserving an earlier result. This tests the evaluator;
recorded role inference and mixture acceptance remain open.

The [authored stem/mix packet](PART-EVALUATION.md#authored-stem-mix-controls--2026-09-21)
also consumes this API per role. Exact timing yields 4/9/5/3 pairs for its four
roles, all with zero error. Reversing the lead prediction order preserves all
five pairs, including the overlapping same-pitch events. Extending one endpoint
by 160 frames preserves five onset matches with 160 total offset-error frames;
full-note matching instead returns four exact pairs and the specific missed/extra
event IDs. An explicit uncertain region excludes one reference/prediction pair
and retains two known matches. These are authored nominal-gate controls, not
learned acoustic boundaries. Commands, byte identities, source review and target
resource logs remain under `build/qa-batch-15/`.

## File-bound role timing

The existing `pythian.evaluate CASE.json` operator now exposes the interval API
through `output`/`metric: "part-notes"`, `input_class: "attributed-parts"`,
`unit: "role-MIDI-sets"` and diagnostic purpose. It uses the same current case,
source hashes, clocks and ancestry checks as other comparisons. The distinct
`part-note-sets` metric remains useful for center-only diagnostics; neither is a
historical format reader.

Start with the complete [part-set reference/prediction](PART-EVALUATION.md#source-bound-operator)
documents and add a `timing` array to both. Arrays contain every role in policy
vocabulary order. Each reference role has exactly `role_id,regions,events`; each
prediction role has exactly `role_id,events`. Event objects contain
`id,start_frame,end_frame,note`; region objects contain
`first_frame,end_frame,state`. Example reference entry:

```json
{"role_id":"lead","regions":[
  {"first_frame":0,"end_frame":8000,"state":"value"}],
 "events":[{"id":"lead-a","start_frame":1200,"end_frame":2400,"note":60}]}
```

Event IDs must be unique across all roles on their respective side. All event
intervals must lie inside the prepared source clock, even when the selected
comparison scope later censors them. Missing roles, reordered identities,
contradictory regions and duplicate ownership of one event ID reject.

The operator also checks that interval pitch unions equal the supplied center
sets. Repeated same-pitch events collapse only for this set-consistency check;
interval matching retains their multiplicity. Reference centers inside uncertain
regions must carry that same uncertainty state. Known reference regions require
known centers; predicted intervals cannot coexist with a contradictory empty or
different center set. Unassigned pitch observations retain their existing frame
accounting and gain no role-event credit; this schema does not invent unassigned
event intervals from those observations.

Scoring preserves the existing phrase timing policy: 50-ms onset/minimum offset
tolerances, 1/5 reference-duration offset tolerance and 110-ms edge exclusion,
using the existing native frame conversion. The policy's `tolerance_frames` and
`scalar_tolerance` are zero; `minimum_f1` is at least 0.70. Every role must retain
positive scorable reference events, complete timing reference coverage, onset
F1 at least 0.80 and full-note F1 meeting the declared minimum. All existing
per-role center/ownership/crossing gates must also pass. Timing errors and both
assignments are reported separately, including excluded event IDs.

Across roles, each side has at most 4096 input events, annotation work totals at
most 16777216 event/region checks, matching at most 50000000 edge examinations,
and center consistency at most 50000000 event/center checks. Role-local core
limits still apply. No partial report is returned on a failed binding, invalid
input or exhausted budget. Primary purpose remains rejected; a diagnostic pass
does not grant independent-case or mixture-provider acceptance.

Final checked stable Win32/Win64 file-bound and interval fixtures pass with zero
leaks, including unchanged phrase/ancestry cases and the caller-budget boundary.
Both operator builds pass. New controls retain the full-note failure when center
and onset scores are perfect, reject contradictory event/center evidence and
cross-role duplicate IDs, and preserve uncertainty, clocks and diagnostic scope.
Commands, source review, report replay and resource evidence remain under
`build/qa-batch-16/`.
