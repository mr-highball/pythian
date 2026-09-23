# Style references and comparator specification

[Corpus protocol](CORPUS-EVALUATION.md) · [Specification task](TODO/NS-5_evaluation_01.md) ·
[Musical evaluation](MUSICAL-EVALUATION.md) · [Milestones](MILESTONES.md#ns-5)

## Status and reference requirements

This is the working specification for chillwave, stoner rock and lofi, dated
2026-09-21. It is **not frozen for preference-scoped style evaluation**. The
three original source families remain development material with unverified genre
assignments, song boundaries and musical annotations. Their measured signal features
below support a controlled measurement example, not complete musical style cards.
The specification task stays open with no completion credit until its reference
grounding and quantitative criteria are complete.

User clarification 2026-09-23: these names identify the user's test preferences,
not authoritative genre definitions. The user personally selected three new
full-length mixes and confirmed that each fits its intended label. They are
development-exposed training candidates, held privately under ignored `build/`;
their source-specific identities and review packet are not part of this tracked
corpus record. That holistic preference judgment does not verify metadata song
cuts, timed musical traits or an independent evaluation group. The earlier A/B/C
candidates below remain historical development screens and do not automatically
represent the user's chosen preferences. Compare later outputs to supported,
source-bound preference traits rather than to a supposed universal genre norm.

Each style requires its own source-bound card. Every observation identifies the
WAV/preparation hashes, recording family, exact source interval and clock, method,
annotator or deterministic measurement policy, uncertainty and exposure. Derive
reference values from independent annotations or measurements, never by treating
the current learner's output as truth. Freeze trait definitions and bins using
development references before evaluating untouched material. Corpus coverage and
independent provider accuracy remain separate acceptance requirements.

| Card | Reference assignment | Required dimensions | Present support |
| --- | --- | --- | --- |
| Chillwave | C-early candidate; declared work has an artist chillwave tag | Context, groove, harmony, bass/voice relationships, evolving sound and structure | Bound acoustic observations; edition correspondence and musical annotations pending |
| Stoner rock | A-early candidate; declared work has an artist stoner-rock tag | Context, groove, harmony, bass/voice relationships, evolving sound and structure | Bound acoustic observations; recording correspondence and musical annotations pending |
| Lofi | B-middle candidate; declared work appears in a label-described lofi release | Context, groove, harmony, bass/voice relationships, evolving sound and structure | Bound acoustic observations; recording correspondence and musical annotations pending |

For all three, vocals, a particular instrument and a particular key are optional
unless their recordings establish a narrower declared support requirement.
Universal transcription, arbitrary instrument recognition and arbitrary voice
counts are unsupported. Missing evidence for a required dimension is **pending**,
not an excuse to relabel that dimension optional or unsupported. A source label
is an operator selection, not evidence that a genre was learned.

## Candidate reference cards

These dated development selections connect the previously audited WAV bytes to
specific evidence to review. They are **candidate assignments**, not accepted
genre cards or changes to the frozen inventory's unassigned labels. The chapter
audit binds a declaration to an excerpt; catalogue agreement supports the declared
work association but does not authenticate the recording or its edition. All
three candidates retain their original broad family and development exposure.
The 30-second excerpts served native signal and learning probes. **None has had
a whole-work listening verdict**, so none can establish holistic chillwave,
stoner-rock or lofi suitability, groove or section structure. Review the complete
declared work in its containing source before assigning a genre or preparing
musical reference annotations. The chapter boundaries below are description
claims, not verified audio cut points.

| Retained source | Original video and declared candidate chapter | Local excerpt used so far |
| --- | --- | --- |
| WAV-A / `source-A.opus` | [Liquify compilation](https://www.youtube.com/watch?v=aWfgFaABhEY), "Forgotten Years" [0,508) s | A-early [120,150) s |
| WAV-B / `source-B.opus` | [Lofi Girl x Secret Lair compilation](https://www.youtube.com/watch?v=P12XxVMbYXg&t=1897s), "Beach Pomodoros - Lost Alara" [1897,2063) s | B-middle [1937,1967) s |
| WAV-C / `source-C.opus` | [EXODUS compilation](https://www.youtube.com/watch?v=E8CaKFh52CU), "Sub Morphine - DownShift" [0,228) s | C-early [120,150) s |

The original compressed recordings are retained privately under ignored
`build/wav-source-study/sources/`; the excerpts are under `masters/` there.
The original video, not an artist catalogue page or the rejected Pro Sensory
file, is the listening source for each of these three candidate declarations.

| Candidate | Bound excerpt and local clock | Existing acoustic observations | Assignment evidence and remaining uncertainty |
| --- | --- | --- | --- |
| Stoner rock / A-early | WAV-A, source seconds [120,150); local frames [0,1440000) at 48000 Hz, stereo PCM16 | RMS 0.101975, peak 0.755249, zero endpoint samples | The declared work appears on an [artist page tagged stoner rock](https://liquify.bandcamp.com/track/forgotten-years). The declaration covers the excerpt without a chapter crossing; acoustic correspondence and musical traits still need review. |
| Lofi / B-middle | WAV-B, source seconds [1937,1967); same local geometry | RMS 0.254321, peak 1.0, 99 endpoint samples | The declared work appears in the [label's track list](https://lofigirl.bandcamp.com/album/secret-lair-x-lofi-girl-beats-to-cast-to), and the [label describes the release as lofi](https://lofigirlshop.com/collections/pre-order/products/lofi-girl-x-secret-lair-special-vinyl-edition). This supports a candidate association, not an acoustic match. Endpoint hits prevent treating this as an unqualified clean sound reference. |
| Chillwave / C-early | WAV-C, source seconds [120,150); same local geometry | RMS 0.358167, peak 1.0, 1709 endpoint samples | The declared work belongs to an [artist release tagged chillwave](https://submorphine.bandcamp.com/album/cyberdawn). Its catalogue duration differs from the declared chapter extent, so edition/cut correspondence remains unresolved. Endpoint hits also require sound-quality review. |

Exact master SHA256 identities, already accepted by the original inventory and
chapter audit, are:

| Candidate | Master SHA256 |
| --- | --- |
| A-early | `3e2a00177cee2e37eb0ef7a964e0d1a6a06fbce6477ec78d8d1fb1c76d9504b6` |
| B-middle | `0525e9612b9263604708d866233c19a1386a51b907339ce851c67dc1661db583` |
| C-early | `0f947e15f6022d9512937a85174e6253dee58c18bd3763ce00552e2693306cdd` |

For each candidate, the unfinished reference packet must contain the following
observations on that exact local clock. Every annotation needs its method,
annotator, uncertainty and source/preparation binding. Catalogue tags or scalar
level measurements cannot fill any of these musical fields.

| Required dimension | Reference observations to supply | Current state |
| --- | --- | --- |
| Context | Beat/downbeat positions, meter, tempo spans, tonal regions and ambiguous alternatives | Pending for all three |
| Groove | Attributed attack/accent positions, bar grouping and signed timing offsets against the reference beat grid | Pending for all three |
| Harmony | Timed chord or pitch-class sets, bass relationships and uncertain intervals | Pending for all three |
| Bass/voice | Supported role notes, overlaps, register, rests and explicit unattributed material | Pending for all three |
| Sound/envelope | Attributed stable/evolving note regions, gates/releases and source-quality exclusions | Aggregate levels measured; note-relative references pending |
| Phrase/section structure | Phrase and section boundaries, repetitions and their relation to a longer recording | Pending; a 30-second cut cannot establish whole-song organization |

B-early remains excluded from single-song candidate cards because it crosses a
declared chapter boundary. B-middle avoids that declared crossing; it is not new
or untouched evidence, and neither candidate creates a new independent group.
Do not tune a comparator to make these candidates pass before the missing packet
and numerical criteria are frozen. The existing evaluation/corpus tasks own this
work; no additional task, completion credit or artifact format is introduced.

### Recording correspondence screen — 2026-09-22

The retained, hash-bound source descriptions identify the declared chapters
containing these three excerpts. Published track listings support the work
associations, but do not authenticate the compilation's audio edition or its
exact cut points. The lengths below compare declared chapter spans with published
track lengths; they are not a waveform alignment.

| Candidate | Declared containing chapter | Published catalogue length | Disposition |
| --- | ---: | ---: | --- |
| A-early | 508 s | [8:29 (509 s)](https://musicbrainz.org/release/63eaefa1-c94b-4411-a31e-45720ccd9be0) | One-second difference; recording and cut correspondence still unverified. |
| B-middle | 166 s | [2:45 (165 s)](https://lofigirl.bandcamp.com/album/secret-lair-x-lofi-girl-beats-to-cast-to) | One-second difference; recording correspondence and endpoint quality still unverified. |
| C-early | 228 s | [3:55 (235 s)](https://submorphine.bandcamp.com/album/cyberdawn) | Seven-second difference; the declared compilation is labelled a later remaster, so the album track is not an authenticated edition match. |

The chapter-correspondence screen had no independently checked isolated
recording to compare against these compilation bytes, and still has no
curator-reviewed musical annotations for them. A reviewer must verify each
recording and cut, then bind beat/meter,
harmony, roles, sound/envelope and structure observations to exact source clocks,
including unknown regions. An independently reviewed replacement can serve the
same role if a candidate fails correspondence or quality review. Until then the
three cards and their numerical trait thresholds remain pending; the existing
acoustic and generic-guitar controls cannot close their musical dimensions.

### Pro Sensory isolated source rejected — 2026-09-22

The artist-posted [Chill (Pro Sensory)](https://opengameart.org/content/chill-pro-sensory)
page identifies Pro Sensory, tags the work chillwave among synthwave and chiptune,
lists CC0, and asks users to include the name Alex McCulloch. Its directly linked
`Chill.wav` is a standalone published WAV. Preserve that name and page notice if
the recording is used. This is a **new candidate source family**, not a match to
the existing C-early compilation excerpt or a new untouched evaluation song.

The exact public [WAV download](https://opengameart.org/sites/default/files/Chill.wav)
was acquired without conversion into ignored
`build/style-reference-source/Chill-Pro-Sensory.wav`. A temporary Pascal audit
using Pythian's `TWaveFrameReader` and `Sha256Stream`, compiled with checked FPC
3.2.2 i386-win32, decoded all **10,159,104 frames**: 44,100 Hz, stereo PCM16,
230.365170 seconds and 40,636,460 bytes. SHA256 is
`db725f3a6fbbc57dd40ad9ff659177824e2473e5684479d2fdf9e41860e6771f`.
Across both channels the decoded peak is 0.979950, RMS is 0.251012 and zero
samples reach an encoding endpoint. The ignored audit source, binary and local
WAV are retained under that build directory; the recording is not committed.

The user listened to the **full 230-second file** in the 2026-09-22 handoff chat.
They described a dreary or ominous, spooky sound and an unsuitable tempo feel,
and explicitly rejected it as a **holistic chillwave reference**. They could not
identify clear beat, bass, lead or section-change times. Playback device and
level were not reported. These are source-bound listening judgments, not a
measured BPM, section annotation or 0..3 generation score.

**Disposition: stop this source for chillwave reference selection.** The
artist's multi-genre tags and exact WAV geometry cannot override the listener's
genre rejection. Keep its byte identity and attribution here only to explain
the rejected screen; do not include this file in chillwave training, calibration
or evaluation roles. C-early remains the unaccepted existing candidate. No
style-reference criterion, numerical gate or genre acceptance closes.

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

### Replayable within-recording permutation — specification v1

Use this permutation for the six within-recording comparator rows above. It
specifies **which complete units move**, not how a provider learns or renders
them. All hashes below are computed by Pythian's Pascal SHA-256 over exact
bytes; no platform RNG, locale-specific number format or hash-map iteration
order participates.

For each recording and each compatible scope, form the movable-unit list in
ascending original source-frame onset, then source-frame end, then a frozen
unique UTF-8 unit ID compared bytewise. Reject duplicate IDs, invalid
boundaries and a scope that mixes recording identities. The source WAV SHA-256,
recording ID, annotation-policy SHA-256, dimension tag and compatibility-scope
ID come from the frozen reference manifest. A scope with fewer than two
movable units is explicitly **unsupported**, with its count and reason; it
does not yield a passing or unchanged shuffled baseline.
The exact ASCII dimension tags are `context`, `groove`, `harmony`,
`bass_voice_order`, `bass_voice_relation`, `sound_envelope` and `structure`;
the last two bass/voice tags distinguish the joint-preserving order shuffle
from its separately reported relationship ablation.

For each unit's zero-based canonical ordinal, serialize this seed record in
the stated order:

1. The ASCII bytes `pythian-style-shuffle-v1` followed by a zero byte.
2. The 32 raw source-SHA-256 bytes decoded from lowercase hex, then the 32 raw
   annotation-policy-SHA-256 bytes in the same form.
3. The global evaluation seed as an unsigned 32-bit little-endian integer.
4. Recording ID, dimension tag and scope ID as three length-prefixed fields:
   unsigned 32-bit little-endian UTF-8 byte length followed by those bytes.
5. The canonical ordinal as an unsigned 32-bit little-endian integer.

Hash that record with SHA-256. Sort units by the resulting 32 digest bytes in
ascending byte order, breaking a digest tie by canonical ordinal. The sorted
ordinal sequence is the output-position-to-original-unit permutation. If it
is the identity and the scope has at least two units, rotate it left by one
position. Record every permutation, including the identity-avoidance flag,
alongside the exact input hashes, IDs, scope, seed and unit count. Never
substitute a new random draw or choose the most disruptive of several draws.
The permitted global seeds are the fixed packet's 731, 1731 and 2731; the
separately named seed-731 paired edits keep their own non-shuffle identity.

Apply each permutation **only within its declared scope**. Context spans move
with duration, units and uncertainty before descendants are reprojected onto
the resulting clock. Groove bars move within one song and meter, carrying
complete role/event/velocity/offset tuples. If a held event crosses adjacent
bars of the same song/meter scope, merge the touched bars transitively into
one compound movable unit before canonical ordering; retain every held
event's original offset within that unit. If a held event crosses a scope
boundary, mark the affected scope unsupported rather than cutting or moving
only part of the event. Harmonic spans move within one song and compatible key
scope. The main bass/voice shuffle moves complete multi-role phrase bundles;
the relationship ablation has a separate dimension tag and permutes one
role's complete phrases against fixed compatible roles. Sound/envelope
trajectories move only among same-song compatible role/gate regions, retaining
all knots and units. Structure moves complete sections with their internal
phrases. Recompute destination positions from the ordered complete units and
their durations, and report the actual transitions or pairings broken; a
preserved marginal alone does not prove the intended relationship was broken.
If the non-identity ordinal permutation changes none of the dimension's
declared target transitions or pairings, report **no effect / unsupported
comparator** with the full permutation and unchanged relationship counts.
Do not redraw, call it a successful ablation, or treat it as an unchanged-
baseline pass.

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
