# Authored part timing control policy

The maintained [part control tool](PART-CONTROL-POLICY.md) also consumes its
source-bound authored events through `pythian.evaluation.notes`. These checks
score exact nominal construction gates, not inferred acoustic onsets or offsets.
They require no private assets.

Each role retains stable source event IDs and original sample-frame coordinates.
Reference event counts are bass 4, chordal 9, lead 5 and other 3. Prediction IDs
prefix the corresponding source ID with `p-`. All four role references are written
before any timing predictions. A complete `esValue` region [0, 192000) includes
annotated gaps. Onset tolerance, minimum offset tolerance and edge exclusion are
zero; the offset fraction is exactly 0/1.

## Exact and damaged controls

Exact predictions must return every reference/prediction identity pair with zero
onset and offset error. Reversing the entire lead prediction array must preserve
all five onset and full-note matches, including both overlapping pitch-69 events.
Input ordering must not erase event multiplicity.

The offset control extends only `event-15` from end frame 64000 to 64160. The
onset assignment must retain five pairs, zero onset error and total offset error
160 frames. The full-note assignment must retain four pairs with zero errors,
reporting exactly missed `event-15` and extra `p-event-15`. The two assignment
reports remain separate.

## Explicit uncertainty control

A separate other-role diagnostic declares [144000, 160000) unknown, with complete
known regions before and after. It must explicitly exclude `event-20` and
`p-event-20`, leaving two exact matches. The reference event document still records
construction truth; the report records the different scoring-region policy.
This is region exclusion, not uncertain-timestamp matching or inferred ownership.

## Evidence and scope

Seven timing reports retain both assignments, pair identities, error sums,
missed/extra IDs, uncertainty exclusions and exact scoring regions/options.
They bind the source, authored score/reference, timing policy and current timing
unit source bytes. Scripted predictions retain their authored-score dependency;
no independent model, recording or acoustic-boundary claim follows.

The timing checks share the packet's 30-second execution, 256 MiB private memory
and 8 MiB output budgets. They participate in deterministic artifact replay.
Frame-set reports still mark interval multiplicity as unscored because their
separate timing reports carry that evidence. External annotation, source timing
qualification and full NS-3_parts_01 acceptance remain separate requirements.
