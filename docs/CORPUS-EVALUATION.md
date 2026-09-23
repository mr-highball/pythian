# Style corpus coverage and evaluation

[Home](../README.md) · [Milestones](MILESTONES.md#corpus-setup) ·
[Style architecture](LAYERED-STYLE.md#learning-a-style-from-many-hours) ·
[WAV studies](WAV-STUDIES.md) · [Work](WORK.md)

This is the initial development protocol for chillwave, stoner rock and lofi.
It defines the evidence to prepare before an independent style verdict. It does
not certify the original inventory recordings, assign their style labels or
establish a production corpus file format. Freeze a source-bound evaluation packet before
using its evaluation recordings; changes after inspecting results create a new
development comparison and require fresh independent material.

For the current user tests, those names mean the user's selected preferences,
not universal genre membership. A user-approved full mix can anchor development
of that preference while its song identities, musical traits and held-out
comparison remain separately unverified. A later acceptance verdict is scoped to
the declared source family, supported traits and listener, not every work that
shares the label.

## Earlier provisional source inventory — 2026-09-20

The native inventory rechecks all eighteen master/prepared WAV hashes for the
nine original 30-second sections, their decoded geometry and prepared peaks.
They contain **270 seconds across three provisional source families**, not nine
independent songs. Five prepared sections reach PCM16 full scale; their original
preparation remains a measurement confound. Regeneration with reviewed headroom
must keep its link to the same family and previous development exposure.

The existing full native-prepared WAV-C derivative is also reopened and hashed
against its conversion report. Its **8235.6535 seconds** include all three C
sections. Known declared coverage is therefore **8415.6535 seconds**: the full C
extent plus 90 seconds each from A and B. Preparing another variant or including
the contained C sections again adds no unique coverage. This accounting is based
on declared source-time mappings, not acoustic duplicate detection across families.
The full derivative's sample-level measurements remain in the prior
[native filtering checkpoint](WAV-STUDIES.md#native-rate-scale-checkpoint).

| Property | Current evidence |
| --- | --- |
| Experiment partition | All inventoried material is development data |
| Untouched style evaluation material | **None registered** |
| Verified independent recording/song identities | **None established by this inventory** |
| Style assignments for WAV A/B/C | Unassigned in the inventory; filenames and acquisition order do not establish style |
| Song boundaries / cross-family duplicate audit | Unverified |
| Accepted chillwave / stoner rock / lofi models | None |

The private plan retains exact master/prepared hashes, geometry, declared parent
offsets, source family, exposure and level observations. Native negative controls
reject exposed evaluation material, unverified evaluation grouping, a family
crossing splits, exact duplicate bytes and overlapping selected parent ranges.
This inventory uses a study validator. The library now offers explicit
[journal partition selection](#library-partition-selection); the command-line
operator accepts [explicit declarations](#operator-partition-selection), with a
checked study binding to two inventory entries. It does not import this inventory
automatically. Different hashes cannot establish
acoustic or musical independence. Assets, inventory, code and logs remain under ignored
`build/corpus-partition-study/`.

Subsequent [reference screening](STYLE-CARDS.md#reference-screening-and-musical-controls--2026-09-21)
found declared track names/times in retained source descriptions. B-early's
120..150-second extent crosses a declared boundary at 125 seconds. Keep that
excerpt out of any claimed single-song reference until segmentation is reviewed.
The source-bound native overlap audit passes checked Win32/Win64 QA with exact
report replay across targets: eight single-chapter excerpts and one crossing.
These declarations do not
establish exact waveform cuts, independent groups or accepted genre annotations;
the earlier inventory's development exposure and uncertainty remain intact.

<a id="verified-identity-pilot"></a>
## Verified identity pilot — 2026-09-20

The first [corpus identity task](TODO/DONE/NS-5_corpus_01.md) is accepted. The
existing manifest-bound recordings supply two verified recording groups:
[Pixel Sprinter](https://opengameart.org/content/pixel-sprinter) by Zane Little Music
and [Opening Theme](https://opengameart.org/content/opening-theme-actionsuspense)
by nene. Their publisher pages identify distinct works; Pixel's standalone,
loop and encoded variants belong to one family, and Opening's two EQ masters
belong to one family. This establishes recording-level identity for this pilot,
not independence of every instrument sample or musical motif. Both families were
already used in development. Their full published extents supply **124.285714
unique seconds**, counted once across prepared variants and blends. The
[existing public manifest](../tests/fixtures/wav-corpus.json) retains attribution,
licenses and original byte identities. No new media is bundled.

Current native `pythian.convert` prepares both at 16000 Hz stereo PCM16 with a
0.8 peak ceiling and continuous sinc filtering. Conversion reports bind original
and derivative hashes, clocks, exact ceiling frame counts and gain. One PCM16
step accommodates representation rounding in the headroom audit. A separate
gain-0.5 Pixel derivative verifies that new bytes retain the same recording,
coverage and development exposure; it adds no training mass. Whole published
recording extents are explicit boundaries, not inferred phrase/section labels.

The ledger rechecks **24 original/derivative hashes and decoded geometries**,
including all existing A/B/C inventory entries and the full C derivative.
The five legacy prepared sections reaching full scale are **quarantined from
the verified pilot**, retaining their master hashes, family, parent coordinates
and development history. Attenuation cannot repair already clipped samples.
Other A/B/C material remains qualified only by its earlier development evidence;
unknown identities and song boundaries do not become verified by this audit.
The earlier 8415.6535-second accounting remains provisional and is not added to
verified coverage. Genre training/evaluation coverage remains unestablished.

The maintained `cache`, `journals --partition development`, `blend` and `replay`
commands run on the two admitted recordings. The first palette comes from Pixel;
Opening learns with that frozen palette. Their disjoint recording models blend
into **1943 observations, 138 WFC states and two source ranges**. Reloading the
saved blend renders **134144 stereo frames** with the same model, source/range
bindings and blend lineage. This is an exercised learning/reuse path, not a
listening or style-quality verdict.

The caller audit binds operator group/exposure flags, journals, preparation and
selected ranges to the complete ledger. It follows hash-bound blend parents and
frozen-palette parents recursively. Opening's immediate source list contains no
Pixel source, but Pixel remains inherited palette evidence. Eight native negative
controls reject overlapping differently encoded derivatives, false unused/group
labels after re-encoding, cross-split registration, quarantined input, an unknown
source, an evaluation family inherited through that outside-plan palette, and an
unavailable palette parent. Counterfactual controls do not relabel actual data.

This is a **closed caller-audited pilot**. The existing CLI still relies on caller
identity declarations; it does not discover recording relationships or carry this
external ledger automatically. Every new source or reuse requires the complete
audit; unknown ancestry is not acceptable evidence. Persisted semantic lineage
and many-hour invalidation/recovery remain owned by
[saved providers](TODO/DONE/NS-4_styles_01.md) and
[semantic corpus training](TODO/NS-5_scale_02.md).

Checked stable Win64 compilation, source/cache/profile binding, replay and the
eight rejection controls pass with no unfreed blocks in the accepted runs.
Private policy, Pascal audit, logs, conversion reports, source/derivative and
profile ledger remain under `build/corpus-identity/`. Initial harness corrections
covered floating-point headroom rounding, exact text bytes and comparing replay
binding fields separately from generated-use counters; no library fix was needed.
Final inventory SHA256:
`b16d2de7dcf7d98d2cd43679867e2c400111c43d7699c10736591a36314695d1`.
There are still **zero untouched style-evaluation seconds and zero accepted
genre styles**. Preparation acceptance earns +2 NS-5 points (+0.4 overall).

## Source identity and split rules

Register the original recording/song identity and every prepared derivative,
including the source hash, sample clock, section mapping and preparation policy.
Track a leakage group covering related excerpts, stems, alternate masters,
duplicates and reused material. Keep that group wholly in one experiment split.
If several groups prove related, merge them and invalidate conflicting split
assignments before training or scoring. Unknown identity stays development-only.

Use three distinct purposes: **training** builds providers, **development** tunes
policies and **evaluation** supplies the frozen independent verdict. Any previously
examined evaluation result used to choose code, thresholds or models makes its
group development data. Existing A/B/C families cannot become untouched evaluation
material by selecting a new excerpt or changing rate, gain or encoding.

Record declared song/section boundaries separately from processing chunks. A
long compilation with unknown song boundaries is one provisional source family;
its duration does not establish a count of independent recordings. Training
must not create transitions across unrelated songs or inflate contribution by
repeated/overlapping excerpts. Explicit training weights remain distinct from
unique coverage, generated-source preferences and hard layer locks.

## Library partition selection

`SelectJournalPartition` in
[pythian.learning.journal](../src/pythian.learning.journal.pas) is an opt-in boundary
before `TJournalTrainingReader`, palette fitting or actual WFC learning. A
`TJournalPartitionPlan` entry contains the existing segment descriptor plus a
case-sensitive `GroupId`, `Partition`, `GroupVerified` and `PreviouslyUsed`.
IDs contain 1..256 bytes without surrounding whitespace. Use one ID for every
related recording/derivative; flags are caller declarations, not hash-derived
proof. Unknown groups are development-only. Exposure must reflect the entire
family, including uses outside the supplied plan.

The whole plan, including unselected partitions, must contain 1..4096 valid
nonempty segments from completed journals under the same rate/channel/analysis
contract. Existing overlap and exact weighted-mass limits apply to the full plan.
Previously used evaluation material and a family spanning partitions reject.
One source hash cannot have conflicting group IDs or frame geometry; overlapping
feature ranges from that hash also reject. Different encodings/preparations need
caller duplicate and parent-coordinate auditing. This API does not detect their
overlap or verify song boundaries, labels, independent sources or corpus coverage.

The result preserves plan order, ranges, multiplicity and song boundaries as
detached descriptors; journals stay borrowed and their read cursors are untouched.
An empty requested split rejects. Validation finishes before publishing a result,
so failure preserves an existing caller assignment. Selection neither learns from
nor reads unselected journals. Existing unpartitioned readers and command-line
ranges retain their contracts; there is no manifest reader or new file format.

The maintained journal fixture compares the selected training palette and actual
serialized WFC model with explicitly training-only construction, using distinct
development/evaluation observations. It checks no held-out reads, all three
selections, ownership/cursors and malformed-plan rejection. These synthetic
checks establish selection mechanics, not an accepted style or independent
evaluation corpus. Build evidence is under `build/journal-partitions/`.

## Operator partition selection

The maintained `journals` command optionally accepts `--partition training` or
`--partition development` immediately after its output prefix. Every WAV/cache
pair must then have `--group ID SPLIT verified|unverified unused|used` immediately
before its optional `--range FIRST COUNT`. Group metadata applies to that pair
only; it never carries forward implicitly. Omitting the selector while supplying
group metadata, or omitting metadata for any pair, rejects. Existing multiplicity,
generation weights, palette and rendering controls retain their scope.

```powershell
pythian.learn journals build/development --partition development `
  --group WAV-A development unverified used A.wav A.pyaf `
  --group WAV-B development unverified used B.wav B.pyaf
```

All supplied WAV/cache bindings and the complete declared plan are validated
before learning. The operator hashes sources and scans caches for integrity,
including unselected ones; only selected observations feed palette/WFC learning
and generation. The existing 32-pair and companion sample budgets apply to the
whole supplied plan. An empty selection or `--partition evaluation` rejects.
An unselected invalid source, exposed evaluation entry or conflicting family
also rejects before any output is written. A frozen palette starter containing
an exact source hash declared as evaluation rejects as well.

The existing report gains `partition_selection`, with the chosen split and all
input source/cache hashes, frame extents, ranges, weights, groups and exposure
declarations. Its ordinary `sources` and learned profile contain only selected
inputs. This is an invocation audit, not a new manifest format or a claim that
identity metadata propagates through later blends/replays. Related derivatives,
outside-plan uses and the full ancestry of a frozen palette still require caller
audit. `fit` retains its existing explicit-source interface; its results do not
automatically become untouched evaluation evidence.

Checked stable Win32/Win64 controls interleave unselected development/evaluation
with differently weighted training ranges. On each target, the complete report
(apart from the new audit), model and audio equal explicit training-only input.
Model/audio bytes also agree across targets; six candidate-distance diagnostics
differ in their last floating-point digits, so cross-target JSON is not exact.
The saved profile reloads through the existing consumer. Rejection controls cover
evaluation learning, exposure, conflicting groups, unknown training identity,
partial/unsolicited metadata, empty selection, an unselected mismatched cache and
known evaluation leakage through a palette starter. Invalid plans publish nothing
and preserve an existing output.

Those authored split/exposure declarations are hypothetical controls, not newly
registered independent evaluation recordings.

The real pilot uses A-early and B-early: 60 source seconds, 938 observations,
60 WFC states and 134144 output stereo frames at 16000 Hz. A native checker binds
the report hashes, geometry and declarations to the existing inventory. Both
remain previously used, unverified development families. Model/audio and ordinary
report fields equal unpartitioned learning of those same excerpts. No new identity,
style coverage or listening acceptance is inferred. Source, logs, original harness
failure and comparisons remain under `build/journal-partition-operator/`.

## First style coverage packet

The working [style-card and comparator specification](STYLE-CARDS.md) separates
same-recording provider accuracy from generated musical distributions and joint
relationships. It records source-bound level observations, remaining annotation
gaps and provider-specific shuffle semantics. Its genre cards are not yet frozen.

The following are **planning floors for the first evaluation**, not measured
genre sufficiency. Change them only before freezing/using evaluation material,
with a recorded coverage rationale. Meeting hours or counts alone does not close
[CORPUS-SETUP](MILESTONES.md#corpus-setup) or [STYLE-EVAL](MILESTONES.md#style-eval).

| Split, per style | Initial coverage floor | Required declaration |
| --- | --- | --- |
| Training | At least 3 unique hours and 6 independently identified recording groups | Recording/song and section variety; weights; repeat/overlap accounting; admitted provider coverage |
| Development | At least 2 additional groups and 30 unique minutes | Supported cases, failure cases and the policy decisions made from them |
| Evaluation | At least 3 additional groups and 30 unique minutes | Unused, group-disjoint identities, fixed references and annotation uncertainty |

For each style, predeclare a trait card grounded in its recordings. Cover base
tempo/key behavior, rhythmic phrasing, harmony, bass/voice relationships, evolving
sound/envelopes and phrase/section structure. Mark each trait required, optional
or unsupported, with observable examples and uncertainty. A caller's genre label
is not a learned feature or an accuracy reference. Do not infer trait cards from
the current unreliable note/beat outputs.

No first style is selected yet. The separate
[chillwave](TODO/NS-5_chillwave_01.md),
[stoner rock](TODO/NS-5_stoner-rock_01.md) and
[lofi](TODO/NS-5_lofi_01.md) tasks can start when their own corpus and the shared
comparison packet are ready. [Cross-style reuse](TODO/NS-5_blends_01.md) requires
all three accepted styles. Each learned provider must satisfy its own
[WAV validation](MILESTONES.md#wav-validation) and musical acceptance scope.
Audit training-data overlap for any external learned estimator separately from
the project's training/development/evaluation split.

## Generation, controls and listening packet

Use fixed seeds **731, 1731 and 2731** and **120 seconds** per generated case.
Retain complete outputs and source/model/parameter hashes. Use the same admitted
provider scope, vocabulary, renderer and output-level policy within each paired
comparison. Fix the single-recording training choice before evaluating results.

Compare multi-recording learning with a single-recording model, an unlearned
generation baseline and a within-recording shuffled-order learning baseline.
The shuffle retains the admitted event distribution but removes learned temporal
order; it must not create cross-song transitions. Provider-specific shuffling
and the unlearned generator settings must be declared before that provider's
evaluation. These comparators have not been implemented or run for an accepted
semantic style yet.

Measure the full generated duration for admitted-trait coverage, unknowns,
repetition, source contributions, joins and structural behavior. Normalize or
hold the renderer fixed when the comparison concerns musical timing/harmony;
separately compare learned timbre/envelopes so renderer choice cannot substitute
for learned musical behavior. Lower acoustic distance or recognizable source
fragments alone do not establish style quality.

For listening, review the complete seed-731 multi-recording output, the first
30 seconds of each other seed and the first 30 seconds of each matched baseline.
These positions are fixed before rendering; retain defects and timestamps. The
reviewer scores each required trait, continuity/structure and overall usefulness:

| Score | Meaning |
| ---: | --- |
| 0 | Absent, contradictory or unusable |
| 1 | Intermittent evidence; substantial defects prevent useful generation |
| 2 | Useful within declared support, with identified limitations |
| 3 | Consistent evidence across the reviewed passages |

For a style verdict, every required trait and usefulness dimension must reach
at least 2, with no unresolved synthesis defect that invalidates the comparison.
Show a repeatable advantage of multi-recording learning on predeclared coverage
or musical-relationship criteria over the matched baselines; report regressions
as well as gains. Record actual judgments rather than deriving listening scores
from signal metrics. One review establishes that review's verdict, not population
preference or ecosystem adoption.

Use seed 731 for paired **15-second** key, BPM, rhythm, bass, voice and sound edits.
Verify changed versus preserved states/audio through the actual WFC dependency
passes. Then save, reload, blend and blend again with predeclared source/provider
weights. Record inherited and selected traits, unknowns and ancestry overlap.
The cross-style task adds all three pairwise blends and one further blend involving
all three styles, with the same fixed seeds and trait-preservation checks.

## Backlog ownership and remaining decisions

- [CORPUS-SETUP](MILESTONES.md#corpus-setup): obtain/verify identities, style cards,
  groups, references and evaluation splits; maintain the parent-range/derivative
  audit and truthful declarations as the corpus grows. The CLI selection path
  and two-entry inventory binding are complete; an automatic inventory importer,
  verified recording identities and representative corpus coverage are not.
- [VOCABULARY](MILESTONES.md#wav-04-vocabulary) and
  [CORPUS-SCALE](MILESTONES.md#corpus-scale): freeze representation, contribution
  policy and measurable memory/time limits before a many-hour training run.
  The coverage floors do not override existing source/state/lineage bounds.
- [CONTINUITY](MILESTONES.md#wav-04-continuity) and
  [SONG-STRUCTURE](MILESTONES.md#song-structure): implement applicable full-duration
  measures and references; prepare the fixed listening packet.
- [INTEGRATION](MILESTONES.md#wav-04-integration) and
  [STYLE-EVAL](MILESTONES.md#style-eval): implement provider-specific comparators,
  trait measurements, paired controls and saved blend/reblend evaluation. Freeze
  quantitative trait/error limits alongside their supported providers before
  evaluation; the generic listening rubric does not replace those limits.

All three styles remain unaccepted. The initial provisional inventory and written
protocol earned no completion credit. The subsequently accepted verified-identity
pilot earns only its allocated preparation credit; no new listening evidence is claimed.
