# Style references and comparator specification

[Corpus protocol](CORPUS-EVALUATION.md) · [Specification task](TODO/NS-5_evaluation_01.md) ·
[Musical evaluation](MUSICAL-EVALUATION.md) · [Milestones](MILESTONES.md#ns-5)

## Status and reference requirements

This is the working specification for chillwave, stoner rock and lofi, dated
2026-09-21. It is **not frozen for genre evaluation**. The three initial source
families remain development material with unverified genre assignments, song
boundaries and musical annotations. Their independently measured signal features
below support a controlled measurement example, not complete musical style cards.
The specification task stays open with no completion credit until its reference
grounding and quantitative criteria are complete.

Each style requires its own source-bound card. Every observation identifies the
WAV/preparation hashes, recording family, exact source interval and clock, method,
annotator or deterministic measurement policy, uncertainty and exposure. Derive
reference values from independent annotations or measurements, never by treating
the current learner's output as truth. Freeze trait definitions and bins using
development references before evaluating untouched material. Corpus coverage and
independent provider accuracy remain separate acceptance requirements.

| Card | Reference assignment | Required dimensions | Present support |
| --- | --- | --- | --- |
| Chillwave | Pending verified recordings and documented traits | Context, groove, harmony, bass/voice relationships, evolving sound and structure | No grounded musical card yet |
| Stoner rock | Pending verified recordings and documented traits | Context, groove, harmony, bass/voice relationships, evolving sound and structure | No grounded musical card yet |
| Lofi | Pending verified recordings and documented traits | Context, groove, harmony, bass/voice relationships, evolving sound and structure | No grounded musical card yet |

For all three, vocals, a particular instrument and a particular key are optional
unless their recordings establish a narrower declared support requirement.
Universal transcription, arbitrary instrument recognition and arbitrary voice
counts are unsupported. Missing evidence for a required dimension is **pending**,
not an excuse to relabel that dimension optional or unsupported. A source label
is an operator selection, not evidence that a genre was learned.

## Reference observations from the original master sections

A native development study reopens the nine original 48-kHz stereo PCM16 masters,
verifies their inventory hashes and geometry, and measures 300 nonoverlapping
100-ms windows per section. It applies no gain, resampling or channel mixing.
RMS averages squared samples across both channels; source peak is absolute peak.
These windows describe level variation, not note envelopes or phrase boundaries.

| Section | RMS | Peak | Samples at a PCM16 endpoint |
| --- | ---: | ---: | ---: |
| A early | 0.101975 | 0.755249 | 0 |
| A middle | 0.146099 | 0.999969 | 4 |
| A late | 0.215351 | 0.928406 | 0 |
| B early | 0.096911 | 0.632904 | 0 |
| B middle | 0.254321 | 1.000000 | 99 |
| B late | 0.243312 | 1.000000 | 142 |
| C early | 0.358167 | 1.000000 | 1709 |
| C middle | 0.268448 | 1.000000 | 39 |
| C late | 0.295299 | 1.000000 | 58 |

Six masters touch an encoding endpoint. That is a source-quality flag, not proof
of audible clipping; it is distinct from the five prepared derivatives previously
flagged. Keep these qualifications in each source's preparation audit. Attenuating
a derivative cannot restore information lost upstream. Do not use affected
regions as clean timbre/envelope calibration references without an explicit
review and uncertainty treatment. Existing genre-corpus tasks already own this
source/preparation requirement.

The study bins window RMS at the exact linear boundaries
`0.001, 0.003981071706, 0.015848931925, 0.063095734448, 0.251188643151, 1`.
All lower edges are inclusive; the penultimate bin includes 1 and the final bin
contains values above 1. No silent or uncertain window is dropped. Reversing
channel order and polarity leaves every histogram unchanged. Replacing every
window with silence gives distance 1 for eight sections and 0.88 for B early,
whose original histogram already has 36/300 windows below 0.001.

The private native study, exact counts, source hashes and policy are under
`build/style-protocol/`. Final checked stable FPC 3.2.2 Win32/Win64 fixtures and
native observation studies pass with no unfreed blocks. All counts, histograms
and distances agree across targets; two Win32 RMS values differ from Win64 only
by 1e-17 and 6e-17. The complete reports are therefore not byte-identical across
targets. Final evidence is retained in `build/qa-batch-03/`.
These are neither genre assignments nor independent style acceptance. The earlier
onset, pulse, key and periodic-pitch candidates remain [unverified observations](WAV-STUDIES.md#initial-wav-source-passes--2026-09-15).

## Separate provider accuracy from generated-style fit

Provider accuracy compares predictions with annotations on **the same recording
and clock**, using the accepted file-bound evaluator. Generated music has its
own timeline. It must not be graded by exact note-for-note alignment to a source
song. Its comparison instead covers distributions, joint musical relationships,
temporal structure, coverage and listening. Copying a source can trivially match
a distribution and still fail useful style generation.

`pythian.evaluation.style.CompareStyleDistributions` supplies the common
distribution measure. For each declared recording group, normalize known counts
to unit mass, then average groups equally. Compute total variation as
`0.5 * sum(abs(reference_probability - candidate_probability))`. Distance 0
means the specified histograms match; 1 means their known supports are disjoint.
Longer recordings do not gain greater weight merely by contributing more windows.
Merge excerpts from one recording family before the call. Generated runs have
separate group IDs; do not pretend they are reference recordings.

The bound policy defines units, fixed bin edges/labels, observation opportunities,
rest handling and the reference packet. Both sides must use the same policy hash
and exact vocabulary. Identities are caller verified, not authenticated by this
numeric helper. Unknown, ambiguous and unsupported counts stay separate in the
denominator. Report pooled, equal-group mean and minimum-group coverage. If any
group has zero known observations, `Comparable` is false: its zero distance field
is undefined and cannot pass a gate. Rest is a known bin where meaningful.

Bounds are 256 groups, 4096 bins, 1..256-byte sorted unique bin/group identities
and a total count at most 2^53-1 per distribution. Inputs are borrowed read-only;
invalid contracts/counts reject before publishing a comparison. This adds no
persisted style format or historical reader.

For prospective generation comparisons, declare a minimum reference and generated
coverage per required trait **and per recording**, an acceptable distance and a
minimum meaningful advantage over each comparator. Record raw counts and per-seed
results. These thresholds are still uncalibrated; freezing arbitrary numbers now
would not satisfy the task's reference-grounded criteria. Existing note-provider
accuracy floors remain unchanged: coverage >=0.80, precision >=0.98, onset F1
>=0.80 and full-note F1 >=0.70. Primary beat timing remains 30 ms, with 70 ms a
separate diagnostic. Neither supplies a universal generated-style threshold.

## Required measures and comparator transformations

Each card must instantiate the following contracts with its actual references,
vocabulary/bins, uncertainty and numerical criteria. The rows define what must
be measured; they do not assert that all providers currently supply it.

| Dimension | Generated trait and reference scope | Within-recording shuffled comparator |
| --- | --- | --- |
| Base context | Tempo occupancy/change magnitude, root/mode occupancy and changes over annotated tonal regions; retain absolute and relative representations separately | Permute complete context spans within one song, including duration and uncertainty; reproject descendants onto the resulting declared clock. Never shuffle tempo numbers independently from their units or create a cross-song edge |
| Groove | Per-role phase, inter-onset duration, accent and signed microtiming; joint role/phase counts and bar-to-bar transitions, including rest | Permute complete annotated bars within the same song and meter. Keep each bar's role/event/velocity/offset tuples together; do not cut held events. This destroys inter-bar order, not within-bar groove, so only inter-bar claims may require superiority over it |
| Harmony | Key-relative chord/pitch-class-set occupancy, duration and successive chord relationships on annotated harmonic regions | Permute whole harmonic spans within the song and compatible key scope, retaining duration and chord identity together; explicitly report any constrained subset with fewer than two movable spans |
| Bass/voice | Per-role register, intervals and durations; simultaneous bass/chord and bass/voice joint distributions; crossing and missing-role coverage | Move complete multi-role phrase bundles within a song to test phrase order. A separately named relationship ablation permutes one role's complete phrases against the fixed other roles on compatible clocks; never present that ablation as the joint-preserving shuffle |
| Sound/envelope | Independently measured normalized spectra and note-relative envelope shapes on attributed regions, plus their dependence on role/articulation | Permute complete spectral/envelope trajectories among compatible same-song role/gate regions; retain trajectory knots and associated units. Do not shuffle individual FFT bins or samples. Keep recording gain and synthesis rendering policy fixed |
| Phrase/section structure | Annotated section-duration, return/repetition and transition relationships across a song; full generated duration and declared truncation | Permute complete sections within a song, retaining internal phrases and exact boundaries. Report immovable one-section cases as unsupported for this comparator; processing chunks do not become sections |

Freeze the permutation algorithm and per-recording seed derivation before running
the comparator; record the complete permutation so replay does not depend on a
platform RNG. A shuffle is an ablation of the relationships it actually removes.
It need not worsen marginal histograms. The native controlled fixture therefore
compares both marginals and joint tuples: two distributions can have identical
low/high marginals while their bass/voice pairings are completely disjoint.

The **single-recording** comparator selects its training recording before scoring,
uses only that family's admitted events and inherited assets, and cannot import
another recording's learned palette as an undeclared starter. Fix vocabulary from
the allowed training partition for all paired models and include its ancestry.
Report retained sample mass; repeating the chosen song does not add independent
coverage. The **unlearned** comparator uses a declared authored vocabulary and
constraints, with equal legal-choice preferences and no recording-derived
transition/frequency weights. Shared training-derived representation, if required
by a provider, must be named explicitly as a representation-controlled baseline;
it must not be advertised as wholly unlearned. Record retries and rejected seeds.

Within-recording shuffles preserve the selected song boundaries, source weights,
event distributions and declared tuples. No transition is learned between songs.
Multi-recording, single-recording, unlearned and shuffled cases use the same
supported provider scope, renderer and output-level policy. Compare timbre with
musical providers fixed; compare musical relationships with rendering fixed.

## Fixed execution and listening packet

Retain seeds **731, 1731, 2731**, **120-second** complete outputs and exact source,
model, policy and parameter identities. Score each full duration; report unknowns,
source contributions, repeated passages, joins and structure. Do not cherry-pick
the best seed or discard a failed render. A partial final phrase is identified
under one fixed boundary policy, not silently removed from coverage.

Listen to the complete multi-recording seed-731 output, the first 30 seconds of
each other seed, and the first 30 seconds of every matched baseline. Retain the
existing 0..3 rubric: absent/unusable, intermittent with substantial defects,
useful within support, consistently evidenced. Every required trait and usefulness
dimension must score at least 2, with actual reviewer judgments and timestamps.
No metric substitutes for that listening verdict.

Use seed 731 for paired **15-second** key, BPM, rhythm, bass, voice and sound edits.
Verify intended changed and preserved WFC states and audio. Save/reload, blend and
blend again with predeclared per-provider weights and complete inherited ancestry.
The later [comparison implementation task](TODO/NS-5_evaluation_02.md) owns the
full operator packet; this specification does not claim it has been executed.

## Remaining specification work

### Reference screening and musical controls — 2026-09-21

The reference screen distinguishes declared source traits from complete musical
annotations. A [lo-fi piano-loop collection](https://github.com/patchbanks/Lo-Fi-Chords-Dataset)
offers rendered progressions; the inspected JSON sample supplies instrument,
tempo and meter, without note/chord timing. It does not supply the missing full
reference packet, and no audio from that collection was admitted.

Two original microphone WAV excerpts and their annotations from
[GuitarSet 1.1.0](https://zenodo.org/records/3371780) are now retained privately.
The publisher archives match their published checksums. Xi, Bittner, Pauwels, Ye
and Bello provide the dataset under CC BY 4.0. Its
[annotation methods](https://guitarset.weebly.com/) distinguish string-derived
notes, supplied beat grids and instructed versus performed chords. The selected
recordings exclude the publisher-linked timing and duplicate-note error cases.
Both remain in one conservative development exposure group; acoustic-guitar
examples labelled Rock do not establish any of our three target genre assignments.

A small native study binds original WAV/JAMS bytes, retains annotation metadata
and unspecified confidence, and constructs note-register/pitch-class controls.
Reversing event order preserves register counts; an octave shift preserves
pitch classes while changing register; a semitone shift changes
pitch-class counts. These are transformations of external annotations, not
Pythian predictions or measured audio transformations. The supplied-note
denominator is distinct from time coverage and rest accuracy. Final checked stable
FPC 3.2.2 Win32/Win64 execution passes: the two references retain 403/547 supplied
notes, all with unspecified confidence, all six string arrays and the 17-block
annotation inventory. Derived counts/frame rows match; one semitone distance
differs by about 1.11e-16 across targets, within the declared 1e-12 tolerance.
Original JAMS bytes remain authoritative. Evidence is in `build/qa-batch-07/`.
No numerical genre threshold, listening verdict or completion credit is claimed.

The retained descriptions for the original WAV families also contain declared
track titles and boundary times. In particular, **B-early spans 120..150 seconds
and crosses a declared boundary at 125 seconds**. It must not be admitted as a
single-song reference without resolving that boundary. A second small native
audit binds those declarations to all nine original master excerpts and reports
every intersecting chapter. Final checked-target QA passes with byte-identical
reports: eight sections intersect one declared chapter, and B-early intersects
two. All four reference-audit runtime logs report zero unfreed blocks. Displayed
times are not frame-accurate acoustic cuts, and publisher tags are candidate genre
evidence rather than complete musical cards. Preserve existing broad family
exposure and uncertainty; splitting a previously examined source cannot create
untouched evaluation data. Existing corpus tasks own verified segmentation,
duplicate relationships and genre admission, so this creates no duplicate ticket.

Bind each of the three cards to verified WAV examples and independent annotations
across all required dimensions. Establish per-provider numerical criteria and
uncertainty from those references, exercise relevant preserving/breaking controls,
then freeze the packet before evaluation. Existing evidence supports acoustic
level and external note-register/pitch-class distribution controls. Genre labels,
complete musical annotations, calibrated trait
thresholds and complete provider-specific controls remain unresolved in
[NS-5_evaluation_01](TODO/NS-5_evaluation_01.md); no new task or extra credit is
created for work already covered by its acceptance criteria.
