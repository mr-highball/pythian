# Overlapping-note timing evaluation

[Role evaluation](PART-EVALUATION.md) · [Shared evaluation](MUSICAL-EVALUATION.md) ·
[Task](TODO/NS-3_parts_01.md)

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
