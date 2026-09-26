# WAV study evidence

[Home](../README.md) · [Current milestones](MILESTONES.md) · [Work record](WORK.md) ·
[Style architecture](LAYERED-STYLE.md)

These dated checkpoints preserve the evidence formerly embedded in the milestone
backlog. They describe what each study established at the time, including its
limits and rejected approaches. They are not the current work queue. Any historic
percentage or scope allocation below is superseded by the
[current north-star assessment](MILESTONES.md#north-star-assessment).

The [current corpus inventory and evaluation protocol](CORPUS-EVALUATION.md)
rechecks the pilot WAV identities, preparation caveats and known unique coverage,
and records its development-only status. It is the starting point for independent
many-recording style evaluation; the dated studies below do not supply that verdict.

## Initial WAV-source passes — 2026-09-15

Nine WAV sections, three per long source, provide an initial mixed-recording
probe: early, middle and late 30-second excerpts, totaling 4.5 minutes. Analysis
uses 16-kHz stereo PCM16 with fixed existing defaults. Source sections, hashes,
commands, reports, models and auditions remain under ignored
`build/wav-source-study/`. Public documentation uses neutral source labels.
The high-level style targets are chillwave, stoner rock and lofi; the pilot does
not infer those labels or establish a complete learned style.

The initial pass set is complete: native levels, tonal/global-pulse inspection,
onsets, local pulse tracking and left/right periodic-pitch inspection on every
section, plus harmonic/percussive separation on the three middle sections.
Fifty-six of these 57 invocations completed; one separation export rejected
headroom. A separate offline conversion probe rejected its work budget. These
are execution outcomes, not 56 musical-accuracy passes. No reference note/beat
annotations or listener acceptance were supplied for this set.

| Area | Observation | Interpretation |
| --- | --- | --- |
| Input handling | A 30-second 48-kHz stereo to 16-kHz conversion exceeds the native offline tap-visit budget. External preparation supplied the fixed pilot inputs. | Long-source preparation needs the existing bounded streaming contracts exposed through a usable workflow; increasing an offline budget is not the acceptance criterion. |
| Levels and separation | Five prepared sections reach PCM16 full scale. A floating-point probe of one section measures peaks 1.0273/1.0172, confirming preparation headroom matters. One separation export rejects component peaks; the other two reconstruct natively within 2.99e-8 maximum sample error. | Retain preparation/quantization as a confound. Correct reconstruction does not prove voice separation. Define float/headroom and export gain policies before comparing sound quality. |
| Timing and key | Onset candidates range from 116 to 396 per 30 seconds. Two sections yield no global pulse candidate. Examples of competing candidates include 101/202.5 BPM; local tracks report seam issues in eight sections. Tonal top-score gaps range 0.0029–0.0228. | Detector output is abundant but beat level, local continuity and key admission remain uncertain. A local tempo change is not verified merely because a track reports one. |
| Periodic pitch in mixtures | Per-channel candidates on a fixed 120-cell inspection grid range 13–71 for source A, 1–4 for B and 0–3 for C. Some simultaneously admitted left/right cells disagree. | This is a periodicity survey on an authored inspection clock, not transcription accuracy or a monophonic declaration. Role ownership and mixture-aware musical inference remain open. |
| Saved acoustic/activity learning | Three per-source corpora and one combined corpus learn, save, load and generate through actual WFC. Eight free/constrained auditions each contain 128 grains / 8.384 seconds; the selected onset/sustain locks hold. Combined saved replay is byte-identical. | Persisted measured generation and coarse activity controls work on these inputs. They do not establish learned genre phrasing, independent parts or semantic style blends. |
| Continuity and source use | Combined free generation reduces the planner's normalized seam metric from 0.9340 to 0.1835, with 91 contiguous links but still 36 source jumps. One source-C free run selects 119/128 grains from one excerpt and none from another. | Fixed-seed observations motivate contribution balance, repetition and musical continuity evaluation. The seam metric is not a perceptual-quality score, and one seed does not characterize the full distribution. |

Several generated auditions also reach PCM16 full scale; their loudness and
transition quality are not accepted. The PCM preparation finding is preserved
with the initial results rather than silently replacing inputs mid-comparison.
The native core and analysis defaults were not changed during this pilot.

## Preparation and learning checkpoints

### WAV-01 preparation checkpoint — 2026-09-15

The conversion CLI now connects the existing bounded WAVE reader, continuous sinc
resampler and streamed PCM16 writer. The previously rejected 30-second 48-kHz
stereo request completes at 16 kHz with 480000 output frames and 411 history
frames; the checked stable Win32 run takes approximately 32.35 seconds locally.
This establishes bounded conversion of that case, not multi-hour throughput or
resumable analysis. Explicit gain or an attenuation-only peak ceiling prevents
silent PCM16 clipping; encoding failures preserve the prior destination.

The separate 16-kHz float probe retains a source peak of 1.0273228884. Preparing
it with a 0.5 ceiling applies gain 0.4867018984; the previously rejected separation
then exports and reconstructs within 2.24e-8 maximum sample error. That probe's
prior rate conversion was external; it does not establish native 48-kHz filtering
for this source. Pilot inputs and observations remain unchanged. These are
supporting fundamentals checks within [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint), with no additional
completion credit. Many-hour ingestion and learning remain open.

Focused checked stable/development Win32 and stable Win64 builds pass the stream
fixture and produce byte-identical converted WAVs. Read-block sizes 127/4096
replay exactly; same-rate PCM identity and rejected-output preservation pass.
Logs and prepared variants are in ignored `build/wav-convert-{stable,trunk,win64}/`.
This evidence does not refresh packages or establish Linux/remote CI acceptance.

<a id="native-rate-scale-checkpoint"></a>
### WAV-01 full-source native filtering checkpoint — 2026-09-19

Native `pythian.convert` completes a 2h17m stereo floating-point WAV conversion
from 48000 to 16000 Hz. Source preparation preserved the 48-kHz rate; Pythian
performed the rate-changing filter. The checked stable Win64 run exits zero in
1360.673 seconds locally, including source/output hashing and staged publication.
Sampled peak working set is 8249344 bytes (about 7.9 MiB).

| Observation | Verified result |
| --- | --- |
| Input | 3162491094 bytes; 395311368 stereo frames at 48000 Hz |
| Output | 131770456 stereo PCM16 frames at 16000 Hz; 527081868 bytes |
| Duration | 8235.653500 seconds, exact ceiling frame count |
| Gain/headroom | Source peak 1.170678139; filtered peak 1.461604967; fixed gain 0.25; decoded PCM peak 0.365386963 |
| Bounded buffers | 4096-frame reads, 411-frame history, one cached phase of 411 Double coefficients |
| Independent output check | Full irregular-block PCM decoding, exact EOF and report/output SHA-256 agreement |
| Offline reference | All eleven PCM probes match exactly, including read boundaries, source positions beyond 2 GiB and the true final frame |

The independent verifier exits zero. The filtered peak exceeds the input peak,
reinforcing the need to apply headroom policy after filtering. This run uses one
audio pass with explicit gain; it does not test full-source automatic peak scanning.
The optional exact rational-phase cache avoids recomputing the same coefficients.
Its cached/uncached Double parity, bounded fallback, signal and failure fixtures
pass on checked stable/development Win32 and stable Win64; the full-source run
itself was performed only on stable Win64. No filter or format version changed.

Output SHA-256:
`1efecef983467b81e87c9f1a92954ee0f3c9d001a801db06a7aa2fa2c8da5afc`.
Evidence is in ignored `build/native-rate-scale/`: `conversion.json`,
`process-metrics.json`, `verify.log` and `verify-exit.json`.
The command uses output rate `16000 --gain 0.25 --block-frames 4096`.
Focused fixtures are in `build/native-rate-{stable,trunk,win64}/`.

This clears [WAV-01-SCALE](WAV-STUDIES.md#native-rate-scale-checkpoint) for the stated source/rate/target.
It does not certify every ratio, real-time deadlines, listening quality or complete
many-recording style learning. Existing prepared-source journals remain bound to
their original PCM; adopting the new PCM requires a new source-bound journal.
No earlier pilot input or learned profile was silently replaced. Remaining
synthesis-quality, annotated context, phrase and style-integration gates retain
their links and allocations; this supporting result awards no additional points.

### WAV-01 long-source analysis checkpoint — 2026-09-15

The existing analysis engine now supplies bounded feature ranges and WAVE batches
with Int64 source coordinates. A resumed batch reconstructs the preceding spectrum
for continuous flux, emits only its own observations and pads windows only at real
EOF. Checked stable/development Win32 and stable Win64 fixtures match whole-source
features exactly across varied hops and batch sizes, including silence, a transient,
antiphase stereo and partial final windows. A virtual RF64 source exercises positions
beyond 32-bit frame coordinates. Existing core and actual WFC corpus fixtures pass.

One full WAV source contains 131770456 stereo frames at 16 kHz: 8235.654 seconds,
approximately 2h17m. Batches of 1024 produce 128683 observations in 412.719 seconds
locally. A fresh process resumes at observation 126977 with batches of 137; all
1706 remaining feature records match the uninterrupted tail byte-for-byte.
This establishes source-grid continuity and repeatable resume computation, not
durable checkpoint storage or many-hour learned styles.

The full floating source peaks at 1.3670556545, beyond the short-section pilot's
headroom probe. Native same-rate preparation applies gain 0.3657495570 for a 0.5
peak ceiling, preserving all 131770456 frames. The source's prior decoding/rate
preparation was external; this is not full-length native sinc filtering evidence.
Sampled process peak working sets stay below 8 MiB for both analysis and conversion.
Artifacts, hashes, comparison and preparation reports remain in ignored
`build/wav-long-source/`; focused fixtures are in `build/wav-batch-{stable,trunk,win64}/`.

Next in [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint): bind saved progress to source hash, geometry and analysis
options; commit each observation batch before advancing its durable next index;
recover interrupted writes without gaps or duplicates. Then [WAV-04](MILESTONES.md#wav-04)
consumes those batches with stable vocabulary and recording-aware transition
aggregation. Existing corpus/model limits are unchanged. This supporting checkpoint
does not close the milestone or award percentage points.

### WAV-01 feature journal checkpoint — 2026-09-15

One current [feature-journal contract](ANALYSIS-WAVE.md#persistent-feature-journal)
now stores measured batches independently of finished corpus/style artifacts.
`pythian.learn cache` creates or resumes it using exact source/options binding,
checksummed ordered records, exclusive file access and a file flush before progress
advances. An incomplete final write can be removed; complete corrupt records and
changed bindings reject without modifying accepted data. No historical format
readers or alternate style encodings were added.

The 2h17m prepared source is cached in two invocations: the first commits 2048
observations, then a fresh process appends 124 batches to reach all 128683. The
journal occupies 17526764 bytes. Combined elapsed time is 460.605 seconds locally,
including source hashing and file commits; sampled peak working set is 7049216
bytes. This is feature storage over the full source, not palette/model training.
The final current executable verifies the completed journal and appends nothing;
its bytes remain unchanged after that reopen.

Checked stable/development Win32 and stable Win64 fixtures cover exact feature
round trips, duplicate-range rejection, partial header/payload/digest recovery,
flush failure with a surviving complete record, binding mismatch and complete
corruption rejection. All three targets reopen the stable-produced short cache.
A physical file truncated 17 bytes before its last digest ends resumes at index
348, removes 16643 incomplete bytes and regenerates the original cache exactly.
Supplying a different WAV leaves the accepted cache unchanged. The original
learner's JSON and WFC model remain byte-identical to the retained earlier tool.

Evidence is in ignored `build/feature-journal-{stable,trunk,win64}/`, with final
focused builds under `current/`. The new core journal and its focused fixture
are included in the ordinary build; no full ordinary build, package refresh,
Linux or remote-CI execution is claimed. No milestone points are awarded.

The next connected result is [WAV-04](MILESTONES.md#wav-04)'s bounded palette and actual WFC
learning from these journals. Carry sequence history across stored batches, reset
at declared recording/song boundaries, and make source weighting explicit. Respect
the companion's public model/state limits. Base context and semantic part styles
still wait on [WAV-02](MILESTONES.md#wav-02) and [WAV-03](MILESTONES.md#wav-03); stored acoustic features do
not supply those missing providers.

### WAV-04 journal learning and audition checkpoint — 2026-09-15

The shared palette engine now accepts repeatable bounded vector readers. Journal
training declares nonoverlapping recording/song segments and positive whole-segment
multiplicities. The new companion adapter accumulates state/start/end counts through
public WFC model contracts; storage batches do not reset sequence history. Existing
array budgets and companion state/count limits remain in place. Source-window
auditions seek retained Int64 coordinates and load only the selected small windows.

The full 2h17m cache trains 128683 observations into 16 tokens and 244 WFC states,
then generates 128 grains / 134144 stereo frames at 16 kHz (8.384 seconds). Local
training, source checks and rendering take 49.892 seconds. Stable Win32 and Win64
produce identical model/audio bytes; the final current stable tool replays them
exactly. An independent native operator loads the model from disk without training
and reproduces every generation token. Selected source frames reach 122473472,
beyond the old clip budget. No whole long WAV or feature/token corpus is allocated.

A two-source probe uses 129152 unique observations. Multiplicities 1 and 274 make
training mass nearly equal (128683 versus 128506), totaling 257189 weighted
observations and 242 WFC states. The 275 weighted samples represent two actual
recordings, not additional unique material. Its generated source use is 107 versus
21 grains; balanced training mass does not imply a balanced audible blend.

The single-source audition repeats one representative in 75/127 adjacent pairs;
the weighted probe does so in 88/127. Both use only one nearest source window per
palette token. These observations establish a concrete quality backlog: bounded
candidate pools, source contribution controls and broader repetition/continuity
evaluation. They do not establish learned key/tempo, independent parts, genre
recognition or satisfactory musical phrasing. Repeated saved semantic blends
remain dependent on [WAV-02](MILESTONES.md#wav-02)/[WAV-03](MILESTONES.md#wav-03) and explicit vocabulary bindings.

Focused stable/development Win32 and stable Win64 fixtures match counted WFC models
exactly to the companion learner for orders 1..4, varied batch sizes, multiplicity
and declared boundaries. Controlled weighted centers agree within 1e-12 with
expanded evidence. Original learner artifacts remain byte-identical; the core
reader builds independently of WFC and core corpus regression passes. Evidence and
auditions are in ignored `build/journal-learning-{stable,trunk,win64}/`, with final
focused builds under `current/`. No overall percentage credit, package refresh or
Linux/remote-CI acceptance is added by this checkpoint.

<a id="journal-selection-checkpoint"></a>
### WAV-04 candidate selection checkpoint — 2026-09-15

[WAV-04-SELECTION](WAV-STUDIES.md#journal-selection-checkpoint) now supplies bounded temporal candidate pools
and independent generation weights. Training and WFC generation remain unchanged.
The two-source probe retains 129152 unique observations, 257189 weighted
observations, 242 states and every one of its 128 generated tokens. Model SHA256
remains `9b6266e38bb11db0824596afe2547a6367152f4a99a8c09cb8807878fe440f19`.
The selectors below use four bins per segment/token. Weights address source C/A;
their training multiplicities remain 1/274 in every case.

| Selection | Source C/A grains | Distinct windows | Immediate repeats / 127 | Source switches / 127 |
| --- | ---: | ---: | ---: | ---: |
| Previous one-representative baseline | 107 / 21 | 15 | 88 | Not recorded |
| Generation weights 1:1, selection seed 731 | 69 / 59 | 62 | 0 | 117 |
| Generation weights 3:1, selection seed 731 | 99 / 29 | 63 | 0 | 58 |
| Generation weights 1:1, selection seed 732 | 69 / 59 | 62 | 0 | 117 |

All current auditions contain 134144 stereo frames at 16 kHz (8.384 seconds).
An initial rotated selection exposed a shorter output when the last candidate
reached partial EOF. Rendering now pads those windows to the analysis window,
preserving the clock and actual source extent separately. The corrected rotated
audition has SHA256 `52767555567255ee9d50040dd6f7591e532b73d76a39d842743fe57898eebcee`.
Equal-weight and 3:1 auditions respectively have SHA256
`65de5f37e5919ea30715134c3ea4ee57af763a97a95c0b8c2f6f8ba88b4a6972` and
`4459577e81eab4891eda8ad8e52ec8a7c360132d82753fb36105df4ce3573837`.

A separate native inspector reloads each saved model, compares its tokens with the
baseline, verifies source hashes and reconstructs the WAV from reported candidate
coordinates. All three current variants replay exactly, including the padded tail;
decoded peaks remain below 0.35. Stable Win32/Win64 equal-weight model/audio bytes
match. Stable/development Win32 short-source audio bytes also match. Checked
fixtures on all three targets verify temporal-bin assignment/nearest candidates,
storage-batch invariance, deterministic rotation, feasible 1:3 shares, unavailable
token rejection and unavoidable single-candidate repetition. The new core unit
compiles without companion paths. An excluded-source CLI request preserves all
three existing output files.

These results close the missing selection mechanism, not musical quality. All
three long-source variants have zero contiguous source links; source switching
is frequent. The short-source probe still has 17 immediate repeats because some
tokens have too few alternatives. Source weights express soft grain shares, not
perceptual energy or exact quotas, and bin rotation has only as many distinct
offsets as bins. [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity) now tracks bounded waveform
join planning and listening acceptance. [WAV-04-BINDINGS](WAV-STUDIES.md#journal-profile-checkpoint) tracks
saved palette/timebase compatibility. Neither blocks independent
[context](MILESTONES.md#wav-02-context), [phrase](MILESTONES.md#wav-03-phrases) or
[duration-provider](WAV-STUDIES.md#duration-scope-checkpoint) work. Held-out recording and genre-level
learning acceptance remain open; no new percentage credit is awarded.

Evidence is in ignored `build/journal-selection-{stable,trunk,win64}/`, with final
tools/auditions under `current/`. Pre-fix rotated output remains a diagnostic only.
There is no new full ordinary build, package refresh or Linux/remote-CI result.

<a id="journal-join-checkpoint"></a>
### WAV-04 bounded waveform join checkpoint — 2026-09-15

The new core [journal join planner](ANALYSIS-WAVE.md#journal-join-planning) consumes
bounded waveform probes at retained source coordinates. It improves a feasible
selection using same-segment candidates and equal-token source swaps with alternate
windows. Per-token/segment counts, caller-locked positions and the initial immediate
repeat ceiling remain fixed constraints. The existing whole-corpus planner now
shares its normalized seam calculation through `pythian.granular`.

The following paired runs keep the learned model, all 128 WFC tokens, source
contribution counts and the 134144-frame output clock unchanged. They use four
passes, 16 overlap probes and weights seam 1 / source switch 0.2 / center 0.05.
An independent native inspector additionally measures every sample across each
3072-frame overlap, avoiding reliance on the planner's sparse objective alone.

| Selection / preserved C:A grains | Source switches before → after | Sampled seam before → after | Full-overlap seam before → after | Distinct windows before → after |
| --- | ---: | ---: | ---: | ---: |
| Equal weights, rotation 731 / 69:59 | 117 → 53 | 0.975118 → 0.747173 | 0.989548 → 0.900159 | 62 → 52 |
| Weights 3:1, rotation 731 / 99:29 | 58 → 33 | 0.983387 → 0.762718 | 0.987541 → 0.912141 | 63 → 56 |
| Equal weights, rotation 732 / 69:59 | 117 → 46 | 0.981950 → 0.752445 | 0.996966 → 0.894615 | 62 → 52 |

All three retain zero immediate repeats. Only the first has a contiguous source
link, and it has just one. The rotated result slightly increases mean center
distance, consistent with the weighted objective trading between measurements.
The smaller improvement under dense measurement and reduced window diversity
limit the quality conclusion: these are improved local joins in short auditions,
not demonstrated sustained phrasing or listener acceptance.

Every saved model replays its tokens from disk, and source-coordinate rendering
reproduces each saved WAV exactly. Per-token/source histograms match the respective
unplanned baselines, not merely the overall source totals. The equal-weight
audition's SHA256 is
`a59fe2d9c6817160696928994261af44e0912b771afc42df462bbd71f331c3f1`;
its model remains `9b6266e38bb11db0824596afe2547a6367152f4a99a8c09cb8807878fe440f19`.
The weighted and rotated audition hashes are respectively
`066808bfb0bfa83bb7dba94a612f9a6d3284438ea65f61c69af5e6ff8d29b000` and
`313d8a36c09a8d3452608766e79a9df09ded68ddc0a0bee4e4f081bdddbcd8d0`.
Decoded peaks remain below 0.34.

Checked stable/development Win32 and stable Win64 fixtures pass contribution/token
preservation, window locks, untouched input selections, deterministic replay,
repeat ceilings, analytic opposite-signal improvement and preflight work-budget
rejection. Construction reads each candidate once; repeated planning does not
reread audio. Existing activity/whole-corpus continuity fixtures pass after the
shared metric extraction, and the new unit compiles without companion paths.
Final stable Win32/Win64 long-probe model/audio bytes match; stable/development
Win32 short-source audio matches. Disabling the optional join pass preserves the
prior short audition byte-for-byte.

[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity) remains open for sustained continuation,
dense waveform fidelity and listening across recordings. Its bounded-access
prerequisite is now available. [WAV-04-BINDINGS](WAV-STUDIES.md#journal-profile-checkpoint) can proceed with
the current pool/model/selection contracts; semantic integration still depends on
[context](MILESTONES.md#wav-02-context), [recorded parts](MILESTONES.md#wav-03-phrases) and the relevant
[duration-provider repair](WAV-STUDIES.md#duration-scope-checkpoint). No additional percentage credit is
awarded for these supporting mechanisms or diagnostic scores.

Evidence is under ignored `build/journal-join-{stable,trunk,win64}/`, with final
focused tools, fixtures and auditions under `current/`. `verify.lpr` is the native
saved-output and dense-overlap inspector. No full ordinary build, package refresh,
Linux or remote-CI result is added by this checkpoint.

<a id="journal-profile-checkpoint"></a>
### Saved vocabulary, source-only replay and compatible starters — 2026-09-19

The current journal report/model pair now loads through a public companion
profile without caches, feature extraction or training. Canonical digests bind
the ordered palette and analysis/timebase to exact model bytes. Source ranges,
candidate grid/bin/EOF extents and actual model sample geometry are checked.
Replay verifies explicitly supplied WAVs by hash, independent of argument order,
and shares the core selection renderer with journal learning. Integrity checks
establish internal consistency, not proof of claimed measurements.

The two-recording long study retains its 242-state model and vocabulary digest
`8e1e9362db77585a9a31c444131722c948219515e581f4d6997e9654dee1f48f`.
Training the short recording with `--palette-from` produces a distinct 59-state
model in exactly that vocabulary. Both load as compatible; the independently
trained short-source palette correctly rejects compatibility. Parent vocabulary
and model digests identify the starter. This is new evidence under fixed centers,
not yet a combination of the two saved models.

| Saved audition | Replay evidence |
| --- | --- |
| Equal source weights | Exact 134144-frame stereo WAV across stable/development Win32 and stable Win64, SHA-256 `a59fe2d9c6817160696928994261af44e0912b771afc42df462bbd71f331c3f1`; matches the preceding joined audition. |
| Source weights 3:1 | Save/replay and a second replay preserve WAV SHA-256 `066808bfb0bfa83bb7dba94a612f9a6d3284438ea65f61c69af5e6ff8d29b000`; final bounded-parser builds also reproduce it on all three targets. |
| Short source under shared palette | New-model replay preserves WAV SHA-256 `5f4ff94a6ad304830d00feffe85a80a3b03c7d0cdc967b13d7c60900e0d79d0f`. |

Checked profile fixtures on all three targets cover changed palette/timebase/model
rejection, count and grid mismatches, duplicate members, excessive JSON nesting,
Int64 source coordinates, detached restoration and shared EOF rendering. A rejected
disabled-source replay preserves existing outputs. Final tools and fixtures are
under ignored `build/journal-profile-{stable,trunk,win64}/final/`; source studies,
starter models and earlier replay evidence are in their parent directories.
The independent native inspector reconstructs the final weighted WAV directly
from saved source coordinates, checks model/token/source-count replay and confirms
99/29 grains with no immediate repeated window. Dense overlap mismatch remains
0.912141338803, exactly the prior weighted join result; this adds replay evidence,
not an audible-quality improvement. Owned builds have no warnings; upstream
compiler/library warnings remain.

[WAV-04-BINDINGS](WAV-STUDIES.md#journal-profile-checkpoint) now supplies the prerequisite for
[WAV-04-BLENDS](WAV-STUDIES.md#journal-blend-checkpoint). Its next clearing result is a persisted weighted
model blend reused in a further blend, with repeated-parent evidence accounted
for and independent generation controls retained. Continuity/listening and
context/part admission remain separate gates. No new percentage credit, complete
genre learning, current package, Linux or remote-CI result is claimed.

<a id="journal-blend-checkpoint"></a>
### Saved acoustic blend and further derived blend — 2026-09-19

`BlendJournalProfiles` combines actual companion state, start and end counts from
compatible saved profiles without caches or retraining. It remaps token indices,
coalesces repeated exact source ranges and retains explicit integer evidence
multiplicities. Candidate pools follow retained source identities. Immediate
parent report/model hashes and flat cumulative training lineage survive reload.
Generation source weights remain independent. The CLI writes the same current
report/model pair; no historical reader or additional format version is added.

The controlled fixture compares every merged state and boundary count with the
actual learner on independently repeated token corpora, at orders 1, 2 and 4.
It exercises different parent token ordering, a saved/reloaded second blend,
repeated-parent source coalescing, zero-weight exclusion, detached lineage,
independent candidate source exclusion, cache conflicts and count-budget rejection.
Checked stable/development Win32 and stable Win64 fixtures and tools pass with
no owned warnings; upstream compiler/library warnings remain.

Let A be the saved two-recording study and B its short-source shared-palette
starter. `A + 2B` has 258127 weighted observations and 277 weighted samples.
Reloading that blend and forming `2(A + 2B) + 3B` yields 517661 observations and
557 samples. Both retain only two distinct source ranges and 129152 raw
observations. The second blend's source multiplicities are 2 and 555; its original
profile contributions are 2A and 7B. Repeated evidence is explicit, not counted as
additional independent recordings.

| Artifact | Evidence |
| --- | --- |
| First blend | Model SHA-256 `89c8b031211546037341652ff0ba27cf025dfa4b3c2df60a62a353cdab2c6664`; generated WAV `d261e90902aa6c29546a04ce6ff4729890d076c1e6344d146e9b44235db7befd`. |
| Second blend | Model SHA-256 `dfe7511c27122686da9d9f2bc99d77dfa829eebf34f0d9b5452a2859ab235cc9`; generated WAV `9208388a972f5004b95ed707de671a4b5ac4588e8cc071dadff97d1e7afd698b`, exact on all three targets. |
| Independent source-weight edit | Second-blend source use changes 68/60 to 98/30 grains at weights 3:1; learned model remains unchanged. The edited audition and another saved replay share WAV SHA-256 `6cf0e45c0d402e7863c8c44034122a545e0170bd4e96140829d4cceaadeb7dac`. |

All auditions retain 134144 stereo frames at 16 kHz. The independent native
inspector reconstructs the second-blend WAV directly from saved source coordinates
and replays its disk model. It reports 52 distinct windows, no immediate repeated
window, 68/60 source grains and dense overlap mismatch 0.879203157910. This is a
diagnostic fragment, with no listener or genre-quality acceptance. Its changed
model/tokens prevent treating comparison with an earlier audition as a controlled
quality improvement.

Evidence is under ignored `build/journal-blend-{stable,trunk,win64}/`.
[WAV-04-BLENDS](WAV-STUDIES.md#journal-blend-checkpoint)'s mechanical reuse criterion is now satisfied.
Next connected acceptance work is sustained continuity and diversity across
recordings/seeds under [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity); annotated context,
part inference and the duration-provider repair remain independent ready work.
No new completion credit, full build/package, Linux or remote-CI result is claimed.

<a id="journal-sustained-checkpoint"></a>
### Sustained acoustic passages and local join search — 2026-09-19

The saved second blend generates 1024-grain passages: 1051648 stereo frames at
16 kHz, or 65.728 seconds. The original global four-pass join request rejects
its conservative probe-work bound. The new explicit `SwapRadius` policy limits
equal-token swap proposals to nearby output positions; zero retains the existing
global search. Radius four admits this study without increasing the 64-million
probe-sample budget. Preflight counts all equal-token pairs in the neighborhood,
since their source assignments can change. Per-token/source counts, output tokens,
locks and the initial immediate-repeat ceiling remain hard constraints.

The following paired comparisons keep the saved model, generation seed, selection
seed, source weights and grain count fixed. They compare planning off with four
passes at radius four; compiler targets are listed below. Dense seam measurement uses every overlap sample
through the independent native inspector, separate from the planner's sparse probes.

| Seed | Dense seam before → after | Source switches before → after | Unique windows before → after | Source grain counts, unchanged | Planned probe bound |
| --- | --- | --- | --- | --- | --- |
| 731 | 0.978187 → 0.889085 | 949 → 527 | 95 → 93 | 549 / 475 | 19374080 |
| 732 | 0.980038 → 0.869493 | 922 → 511 | 97 → 96 | 563 / 461 | 20758528 |
| 733 | 0.987228 → 0.846271 | 958 → 484 | 95 → 94 | 545 / 479 | 21151744 |

Immediate exact-window repeats remain zero. This does not establish diversity:
90.6–90.9% of grain positions reuse a window already selected in the passage.
Effective window counts, calculated as exp(Shannon entropy of slot usage), decline
82.14 → 71.83, 82.60 → 70.52 and 84.58 → 74.64 respectively. Repeated four-window
sequences decline 158 → 127, 226 → 191 and 227 → 142; this counts each occurrence
after its first appearance, including overlapping sequences. For seed 733 the
most-used window rises from 28 to 34 occurrences. The tradeoff is visible.

Source-contiguous runs reach only one grain (0.256 seconds) for seed 731 and two
grains (0.320 seconds) for seeds 732/733. Contiguous-link counts are 0, 2 and 5.
These are source-coordinate diagnostics, not measured musical phrase boundaries
or a requirement to copy existing passages. They expose how little sequential
source context the current nearest-bin representation retains. Listening and
genre/style acceptance remain unverified. This study covers one fixed two-recording
blend and three seeds, not recording-level held-out generalization.

Checked stable/development Win32 and stable Win64 fixtures verify the sustained
local path, sparse locks, counts, deterministic replay and unchanged global-budget
rejection. Tools compile on all three targets with no owned warnings; upstream
diagnostics remain. Seed 731 was generated on stable Win32, 732 on development
Win32 and 733 on stable Win64. A saved seed-731 replay on Win64 inherits radius
four and is byte-identical to Win32, WAV SHA-256
`726b57f292b2ddf6954383cb098103284cb02aa5118e113f14a19c31b07e4539`.
The existing short global audition remains byte-identical. Independent disk-model
replay and source-coordinate reconstruction pass all six paired auditions, and
all three pairs preserve exact token/source contribution counts.

Evidence is under ignored `build/journal-local-{stable,trunk,win64}/` and
`build/journal-sustained-study/`. The native `study.lpr` records selection diversity;
the preceding native join inspector supplies dense mismatch and reconstruction.
[WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation) is the next linked representation task;
automatic context and recorded-part admission remain separate prerequisites for
semantic integration. No new completion points, full ordinary build/package,
Linux or remote-CI evidence are added.

<a id="journal-context-checkpoint"></a>
### Source-context availability diagnosis — 2026-09-19

The next native probe distinguishes missing source context from context discarded
by representative selection. It streams the two hash-bound feature journals,
encodes observations through the saved second blend's exact palette, and checks
the three existing 1024-token outputs. Source boundaries reset matching history.
Training multiplicities do not duplicate observations. The saved four-bin pool
retains 99 of 129152 distinct observations.

Each cell below counts output positions whose complete token substring occurs
contiguously within at least one source segment. The first number uses all journal
observations; the second requires every source window to remain in the saved pool.

| Context length in grains | Possible output positions | Seed 731: journal / pool | Seed 732: journal / pool | Seed 733: journal / pool |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1024 | 1024 / 1024 | 1024 / 1024 | 1024 / 1024 |
| 2 | 1023 | 1023 / 4 | 1023 / 5 | 1023 / 10 |
| 4 | 1021 | 981 / 0 | 969 / 0 | 970 / 0 |
| 8 | 1017 | 454 / 0 | 523 / 0 | 502 / 0 |
| 16 | 1009 | 33 / 0 | 54 / 0 | 62 / 0 |
| 32 | 993 | 0 / 0 | 0 / 0 | 2 / 0 |

Thus the near-absence of short continuations is substantially a retained-candidate
limitation: every generated pair has source support, while only 4–10 remain
available as adjacent retained windows. Longer contexts also expose a model/source
limit: the order-two generated paths rarely contain a source-observed 32-window
substring. A larger representative pool alone cannot guarantee those contexts.
These are availability upper bounds. They do not impose source quotas, locks,
reuse limits or waveform quality, and they do not measure musical phrase accuracy.

[WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation) should retain bounded source context
with explicit variable lengths and an unsupported-context fallback, then compare
selection and audible generation while preserving token paths, source controls
and lineage. Do not require one fixed long copied run or increase a scalar bin
limit and treat duration as acceptance. Preserve one current saved-style contract;
any added context must survive reload, compatible blending and a further blend.
This supplies [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity); admitted musical context and
parts still depend on their separate provider gates.

The streaming matcher passes an independent exhaustive substring oracle covering
all six lengths, source boundaries and gaps in retained windows. Cache hashes and
every retained candidate's token/source coordinate match the saved profile.
Evidence: checked stable Win64 native scratch program and three terminal logs in
ignored `build/journal-context-study/`. This diagnostic reads saved measurements,
not newly analyzed WAVs; it adds no runtime implementation, artifact format,
listening acceptance or percentage credit. Cross-target diagnostic replay is not
claimed.

<a id="journal-context-selection-checkpoint"></a>
### Bounded context selection and sustained auditions — 2026-09-19

The new portable `TJournalContextPool` retains forward context around existing
representatives in one journal pass, with at most 32 grains per anchor, 2048 anchors
and 65536 windows. The native study retains 99 contexts / 786 windows at a maximum
length of eight, preserving the saved second blend's exact palette and source
bindings. Variable-length matching consumes exact per-token/source quotas from
the existing selection; positions 0, 511 and 1023 are locked.

Initial greedy selection exhausted some source quotas early, stranding rare
tokens in a source with only one candidate. Same-source substitutions could not
repair those repeats. The final bounded repair also permits equal-token position
swaps, preserving counts and locks and requiring both edited neighborhoods to
remain repeat-free. The initial repeated-window ceiling remains a hard gate;
unrepairable results return the entire original selection.

These paired comparisons use the existing locally planned 65.728-second paths as
baseline. All three final context selections retain the exact 1024 tokens and
per-token/source counts, all three locks and deterministic replay.

| Seed | Dense seam before → after | Source switches before → after | Contiguous links before → after | Unique windows before → after | Effective windows before → after |
| --- | ---: | ---: | ---: | ---: | ---: |
| 731 | 0.889085 → 0.394495 | 527 → 217 | 0 → 617 | 93 → 363 | 71.83 → 259.79 |
| 732 | 0.869493 → 0.384003 | 511 → 209 | 2 → 631 | 96 → 378 | 70.52 → 269.95 |
| 733 | 0.846271 → 0.343304 | 484 → 184 | 5 → 673 | 94 → 351 | 74.64 → 265.78 |

All final immediate-repeat counts are zero. The planner retains 834/851/897
context grains after 19/26/10 repair edits; remaining grains use fallback.
The conservative matching/repair work bound is 16830464, within the unchanged
64-million limit. Longest source-contiguous runs reach eight grains (0.704 seconds),
up from one/two/two. Effective windows use exp(Shannon entropy).

There is a repetition tradeoff: repeated four-window sequences change
127 → 144, 191 → 176 and 142 → 197. The most-used window remains at 52/40 uses for
the first two seeds and falls from 34 to 28 for the third. Longer source copying,
lower seam mismatch and increased window diversity do not by themselves establish
musical phrasing. Listening and recording-level held-out acceptance remain open.

All three native WAVs contain 1051648 stereo frames at 16 kHz. Peaks are
0.662842/0.662842/0.648447, below PCM16 clipping. Twenty-one independent
cosine-window overlap-add probes per output agree within 6.59e-9 before PCM
encoding. Source/cache hashes, output clocks, token/count/lock invariants and
in-process deterministic replay pass on checked stable Win64. Output SHA-256:

- Seed 731: `2c66034dee9c6b49ab054376c0fdb3db3d5a829ae911fa29e6016d690dc6967b`.
- Seed 732: `fb23406ea605dfee580d2133995f39c160ae1243cbcd99b2e129ede8fce79d65`.
- Seed 733: `4f62530a968426624ab3968af2ad50a906f8a1edbdea9be1b3ec5936ce47bb91`.

The extended maintained journal fixture passes checked stable/development Win32
and stable Win64, including a small independent single-window quota-repair case.
The core compiles without companion paths. Evidence: ignored
`build/journal-context-core-{stable,trunk,win64}/` and
`build/journal-context-audition/seed*-final.*`; earlier rejected experiments and
the targeted quota diagnosis remain separate. Sustained cross-target audio replay
is not claimed.

This implements the core part of [WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation).
The subsequent [saved-context checkpoint](#journal-context-save-checkpoint) now
connects it to the current saved-profile, replay and repeated-blend path.
[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity)
still requires diversity and listening acceptance; context/part semantic providers
retain their separate gates. No new format version or completion credit is added.

<a id="journal-context-save-checkpoint"></a>
### Saved contexts, further blends and maintained replay — 2026-09-19

The current profile has one optional source-context capability, with no additional
format version or historical reader. Portable restoration owns detached data and
validates bounds, coordinates and source ranges. Saved measurements are structurally
validated, not authenticated or remeasured. Compatible blends remap sources and
coalesce matching anchors, retaining the longer compatible prefix and minimum
shared center distance. Conflicting tokens reject; zero-weight parents contribute
no contexts. Model weights do not multiply retained context windows.

The maintained `pythian.learn contexts` command attaches contexts from exact saved
cache identities without retraining or rendering. Model bytes remain unchanged.
`replay --context-grains 8` enables bounded selection after optional join planning;
run length and context-start reuse controls persist for subsequent replay. Replay
requires the saved profile/model and matching WAVs, not the training journals.
Final coordinates and actual source use are reported separately from baseline
slots; join metrics describe the pre-context stage. Positional locks remain a
core API capability, exercised by fixtures, not a maintained CLI option.

The real-source workflow attaches eight-grain contexts to a mixed profile and
sixteen-grain contexts to a compatible single-source profile. A first weighted
blend and a further blend retain two distinct source ranges, 99 contexts and
1058 windows. Independent native checks verify every parent's remapped coverage,
matching token/coordinate prefixes and coalesced anchors. The final model contains
1037667 weighted observations and 1119 weighted samples; context storage remains
independent of those multiplicities.

Both auditions generate 1024 tokens at seed 731, with four local join passes,
swap radius four, maximum context length eight and unrestricted context starts.
The second audition changes only generation source weights to 3:1. Model bytes
and all generated tokens stay exact; source C/A contributions change from
579/445 to 802/222 grains. Context planning preserves each baseline's exact
per-token/source counts.

| Metric | Default weights: baseline → contexts | Weights 3:1: baseline → contexts |
| --- | ---: | ---: |
| Dense seam mismatch | 0.893449 → 0.398256 | 0.898192 → 0.365167 |
| Source switches | 473 → 243 | 346 → 153 |
| Source-contiguous links | 4 → 615 | 0 → 647 |
| Unique windows | 93 → 361 | 94 → 352 |
| Effective windows | 72.68 → 251.78 | 75.51 → 254.98 |
| Repeated four-window sequences | 157 → 143 | 134 → 167 |

Final immediate repeats are zero; longest runs are eight grains. Context/fallback
grain counts are 842/182 and 880/144 after 23/13 repairs, with no full-path fallback.
Both work bounds are 19615744 within the unchanged 64-million limit. Repetition
still worsens in the weighted case despite improved seam and diversity measures.

Each output has 1051648 stereo frames at 16 kHz (65.728 seconds), PCM peak 0.662842.
Twenty-one independent cosine-window source probes agree with each published
PCM16 output within 0.000015005 (less than one PCM16 step). The saved default
audition replays byte-identically on stable Win64 and stable Win32, including
reversed WAV argument order and inherited controls. Development Win32 builds and
fixtures pass; a full audition on that target is not claimed. SHA-256:

- Final model: `11a8498f5bd65bb4e9fd73f175cc828e32f05e8784cf86d5f23e35b483a2d602`.
- Default WAV: `92230cf394818429fa324fc4033a0089bef0aefbf7c6f3105df914b4b6bea1d1`.
- Weighted WAV: `e7d1fd71d98f773b0317608bdf30c848ca8c9f906169290c42f2fad2c08e34b7`.

Checked profile fixtures and maintained-tool builds pass on stable/development
Win32 and stable Win64. Coverage includes detached ownership, malformed restored
data, partial EOF, locks, remapping, further blends and conflicting anchors.
Wrong cache order rejects before output publication. Core-only compilation uses
no companion paths. Evidence is under ignored
`build/journal-context-save-{stable,trunk,win64}/` and
`build/journal-context-save-study/`; all processes are terminal.

This clears [WAV-04-CONTEXT-SAVE](WAV-STUDIES.md#journal-context-save-checkpoint)'s mechanical integration
gate. The subsequent [reuse study](#journal-context-reuse-checkpoint) supplies a
paired repetition comparison and isolates final-boundary regression.
[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity) still needs listening assessment across
recordings using the saved path. Independent
[context](MILESTONES.md#wav-02-context) and [phrase](MILESTONES.md#wav-03-phrases) provider work remains
ready; their admission failures still block semantic integration. No listener,
genre-quality, current-package, Linux or remote-CI acceptance or percentage
credit is claimed.

<a id="journal-context-reuse-checkpoint"></a>
### Context reuse and assembled-boundary diagnosis — 2026-09-19

A native diagnostic evaluates chunk lengths four/eight and per-anchor start caps
unrestricted/one/two/four/eight against the saved default and 3:1 source-weight
paths: twenty cases, all at seed 731 with the same model and generated tokens.
Exact per-token/source counts and deterministic replay pass in every case, with
no whole-path fallback. Source bytes are verified against saved identities.
This is development evidence on the existing C/A source pair, not a new
recording-level or held-out evaluation. No defaults are changed.

Four starts per anchor at chunk length eight reduces repeated four-window
sequences in both weight policies. Overall dense seam mismatch increases relative
to unrestricted context selection, while remaining below the pre-context path.
More aggressive caps reduce repetition further at greater continuity cost.

| Source weights / path | Overall dense mismatch | Assembled-boundary mismatch | Assembled boundaries | Repeated four-window sequences |
| --- | ---: | ---: | ---: | ---: |
| Default / pre-context | 0.893449 | 0.896956 | 1019 | 157 |
| Default / unrestricted starts | 0.398256 | 0.998568 | 408 | 143 |
| Default / four starts | 0.470944 | 0.989272 | 487 | 108 |
| 3:1 / pre-context | 0.898192 | 0.898192 | 1023 | 134 |
| 3:1 / unrestricted starts | 0.365167 | 0.993526 | 376 | 167 |
| 3:1 / four starts | 0.464398 | 0.987691 | 481 | 115 |

Each path has 1023 transitions. Source-contiguous transitions have exactly zero
overlap mismatch in the measured PCM. The assembled-boundary column excludes
those transitions and averages the remaining dense normalized overlap errors.
It exposes worse new joins after context selection despite lower overall error.
This is an acoustic diagnostic, not a perceptual score; silence and waveform
phase also affect it. Increased source copying alone does not prove better
assembly. Current join planning precedes context selection, whose ranking uses
token matches, adjacency and reuse rather than waveform compatibility.

The controls have narrower meanings than global copying limits. Chunk length
four with a one-start cap produces a six-grain source-contiguous run in both
cases: adjacent choices/repairs can reconnect. A start cap does not cap individual
window use, because contexts overlap and fallback/repair may reuse windows.
Public option comments and operator documentation now state these limits.

The maintained tool renders both four-start variants with only `--context-uses 4`
changed. Each remains 1051648 stereo 16-kHz frames / 65.728 seconds with peak
0.662842 and zero immediate repeats. Independent native verification checks
parent remapping, saved-path coordinates, token/source counts, hashes and clock;
21 source-derived cosine-window probes per output agree with PCM16 within
0.000015005. The context work bound remains 19615744. Output SHA-256:

- Default weights: `7b36d3f5b352728982161dd6d0c13f85266934d7cd61363706403f24e9deacc4`.
- Weights 3:1: `d3c6a7b98042e8d61263d3fe70f780be9151570f16c0c8397169c0593de42b5c`.

Evidence is under ignored `build/journal-context-reuse-study/`: `default.log`
and `weighted.log` retain the twenty-case sweep; `*-boundaries.log` separate
transition classes; `*-cap4.*` retain maintained auditions and `verify-*.log`
their independent checks. Native `survey.lpr` accepts a saved audition prefix
and source WAVs in profile order; optional `all` selects the full sweep, otherwise
it compares length eight with unrestricted/four starts. Checked stable Win64 only;
all processes are terminal. No production algorithm, current format, package,
cross-target evidence or percentage estimate changes.

[WAV-04-BOUNDARIES](MILESTONES.md#wav-04-boundaries) must account for final assembled joins
before [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity) can pass. Compare fixed-policy paths
with separate assembled/all-boundary costs and repetition measures; preserve
exact controls and bounded work. Listening and broader recording/seed evaluation
remain open. Context/phrase provider work continues independently.

<a id="journal-boundary-refinement-checkpoint"></a>
### Whole-context boundary refinement and saved auditions — 2026-09-19

Portable `PlanJournalContextJoins` adds a separate optional refinement after
context selection. It partitions the initial selection into maximal
source-contiguous chunks and swaps only equally long chunks with identical token
sequences. Any chunk containing a locked position stays fixed. Exact window and
metadata multiplicities, token positions and source contributions are preserved.
This retains the preceding context-start decisions and window diversity.

Each accepted swap reduces total sampled seam error without increasing assembled
boundary mean or immediate repeats. The shared `ExtractGrainJoinProbe` now serves
both candidate and context-boundary planning, with complete sample validation,
partial-EOF padding and nonoverlapping endpoints. The native independent constant
fixture caught a reporting precision loss from overloaded floating-point clamping;
explicit Double arithmetic now passes the analytic cost oracle.

The maintained replay command exposes `--context-join-passes 0..8` (default zero),
`--context-join-probes 1..64` and `--context-join-radius 1..64` (forward chunks).
Saved controls and `context_join_planning` fit the current profile without a
version branch. Final coordinates/usage refer to refined output; the preceding
context report remains stage-specific. Refiner limits include 4096 grains and a
64-million preflight budget covering reads, deduplication, comparisons and probes.

Four maintained auditions use maximum context length eight, four starts per
anchor, four refinement passes, 64 probes and radius eight. Each pair below uses
the same model, tokens, selected windows and source weights before/after refinement.
Dense costs independently inspect every overlapping PCM sample, rather than the
planner's sampled probes. These remain development comparisons on source C/A.

| Weights / seed | Dense assembled mismatch before → after | Overall dense mismatch before → after | Repeated four-window sequences | Swaps / work bound |
| --- | ---: | ---: | ---: | ---: |
| Default / 731 | 0.989272 → 0.975339 | 0.470944 → 0.464311 | 108 → 103 | 71 / 26050560 |
| 3:1 / 731 | 0.987691 → 0.974243 | 0.464398 → 0.458075 | 115 → 106 | 67 / 25853952 |
| Default / 732 | 0.980612 → 0.968849 | 0.453401 → 0.447963 | 107 → 104 | 53 / 25591808 |
| 3:1 / 733 | 0.977988 → 0.964577 | 0.447408 → 0.441273 | 156 → 150 | 39 / 25427968 |

All four keep exact window multiplicities, unique/effective window counts and
zero immediate repeats. Source switches change 241→239, 150→152, 247→239 and
142→144; the objective does not constrain them. An additional seed-731 diagnostic
with unrestricted starts also improves dense joins in both weight policies, but
the weighted case adds one repeated four-window sequence (167→168). No universal
repetition or listening improvement is claimed. Newly assembled joins still
score worse than the corresponding pre-context baselines (about 0.88–0.90).

Each published audition contains 1051648 stereo frames at 16 kHz / 65.728 seconds,
peak 0.662842. Independent native checks verify source/model/output hashes,
parent context remapping, exact window multiplicities, tokens, source counts,
saved coordinates and clock. Twenty-one analytic cosine-window probes per WAV
agree within 0.000015112, less than one PCM16 step. Output SHA-256:

- Default / 731: `13613ef2bd5c9f9a8ddb1e37456527159f3e7930788fa23b776e7f950b0fbf6e`.
- 3:1 / 731: `d2f5293ecd7a0adcb713ade4b915035eb54cfa31c3263d3a01819db12670dcba`.
- Default / 732: `98ebdffa5515fcc9b7f789d92b6444c1166a63d5b1937f3a11d88c29771b6ecc`.
- 3:1 / 733: `e972a162ca4ab46b1d6b40c07d62a377d5a0e30b9461ad658f3facaec3e8b913`.

Saved default/731 replay is byte-identical on stable Win64 and stable Win32,
including reversed WAV order and inherited controls. Disabling the new stage
retains the earlier four-start WAV byte-for-byte. An enabled boundary stage with
disabled contexts rejects without publishing output. Checked existing journal
fixtures and maintained-tool builds pass stable/development Win32 and stable
Win64. Fixture coverage includes exact multiplicities/metadata, token positions,
locks, incompatible chunks, no-op paths, replay, an independent waveform oracle,
EOF/endpoints and work rejection before reads. Core compilation uses no WFC path.

Evidence: ignored `build/journal-boundary-{stable,trunk,win64}/` and
`build/journal-boundary-study/`. No new unit/fixture program, format version,
vendor or package is added. Development Win32 sustained replay, Linux and remote
CI remain unclaimed. [WAV-04-BOUNDARIES](MILESTONES.md#wav-04-boundaries) now supplies a verified
refinement mechanism; broader source-choice quality and listening still gate
[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity). Independent context/phrase admission
remains ready. No percentage credit is awarded.

<a id="acoustic-generation-capacity-checkpoint"></a>
### Explicit generation budget and full richer-model output — 2026-09-19

The [three-source study](#journal-third-source-checkpoint) found that the 771-state
model's requested 1024 grains need 789504 logical state cells. Its 340-grain
diagnostic did not satisfy that request. An intact-graph probe now establishes
feasibility before adding an explicit bounded adapter/CLI control. The same WFC
graph, model, seed, constraints and solver are retained; no states are discarded
and no independent passages are stitched to bypass the model.

`DefaultAcousticGenerationOptions` retains 262144 state cells.
`StateCellBudget` and maintained `replay --state-cells N` permit explicit budgets
from 1 through 1048576, with at most 1024 grains. The current report persists
`state_cell_budget`; omission retains the default. Streaming keeps its separate
262144-cell guard. This adds no historical format or implicit budget escalation.

| Evidence | Observed result |
| --- | --- |
| Isolated intact graph, 340 positions | 262140 cells; 6417 ms process elapsed; sampled peak working set 27234304 bytes |
| Isolated intact graph, 1024 positions | 789504 cells; 12498 ms process elapsed; sampled peak working set 27418624 bytes |
| Full maintained pipeline, stable Win64 | 40376 ms; sampled peak working set 68423680 bytes; full 1024-grain output |
| Independent WFC validation | All 1023 learned transitions, state/token projection and graph domains pass; every maintained token matches the separately solved graph |
| Published audio | 1051648 stereo 16-kHz frames / 65.728 seconds; peak 0.502410888672 |
| Independent rendering | Exact tokens/window multiplicities, context remapping and coordinates pass; 21 analytic PCM probes differ by less than one PCM16 step |
| Saved replay | Stable Win32 inherits the budget and produces identical WAV bytes to stable Win64 with reversed source arguments |
| Failure boundaries | Default and 789503-cell requests reject the full length; zero and 1048577 reject; no output files are published |

These resource measurements describe this model and environment. Logical cells
are not allocated bytes or a time guarantee; other model shapes, constraints and
search outcomes need separate evidence. The unit fixture additionally exercises
an exact small-model budget, one-cell shortage, caller locks, maximum/invalid
budgets, seeded path stability and preservation of previously published output.
Checked learning and stream fixtures and maintained-tool builds pass stable and
development Win32 plus stable Win64. The real full-length pipeline and independent
output checks run on stable Win64, with saved audio replay on stable Win32.
Other direct consumers of the generation options rebuild on stable Win64.

The audition retains seed/selection seed 731, four join passes with radius four,
context length eight with four starts per anchor, and four boundary-refinement
passes. It uses 489 distinct windows and no immediate repeats. Refinement lowers
dense assembled mismatch 0.997338353805 to 0.980668787027, still worse than the
pre-context 0.909442240442. Repeated four-window sequences change 126 to 123;
source switches increase 256 to 260. These diagnostics keep continuity and
listening acceptance open.

Model SHA-256 remains
`33bead9fad07036e6f40c6ffbf3cc93e5ca72e9a256d631e84c0f167491becbb`.
Output WAV SHA-256 is
`6642a1048fe683efda696dc7bcf7dac0de50184f09b3bfe2834fd1a87203e8e3`.
Evidence is under ignored `build/acoustic-capacity-study/` and checked builds
under `build/acoustic-capacity-{stable,trunk,win64}/`. The full maintained command
uses `replay` on `build/journal-third-source-study/joint32-context` with
`--frames 1024 --state-cells 789504 --seed 731 --selection-seed 731
--join-passes 4 --join-swap-radius 4 --context-grains 8 --context-uses 4
--context-join-passes 4` and the three bound WAVs in that study.

This clears [WAV-04-GENERATION](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint) for the measured request.
[WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary), [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity)
and admitted base/part providers still gate [WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration).
No listening acceptance, general style-quality percentage or extra ledger credit
is inferred from the capacity result.

<a id="journal-range-checkpoint"></a>
### Selected WAV sections through saved blends — 2026-09-19

The maintained `journals` and `fit` commands now accept a non-sticky
`--range FIRST_FEATURE COUNT` immediately before a WAV/cache pair. This exposes
existing library range contracts without cutting audio, changing source identity,
adding format branches or altering whole-journal defaults. Overlapping selected
observations reject before output publication. Weights continue to address each
declared segment; processing batches never become musical boundaries.

Source A supplies ranges `[20,160)` and `[200,340)`, weighted 3 and 1. Training
learns 280 distinct / 560 weighted observations into 57 WFC states. A compatible
tail profile uses `[340,469)` with weight 2. Blending the first profile with twice
the tail, then doubling that blend and adding the first profile again, retains
three source ranges with multiplicities 9/3/8: 409 distinct observations, 2712
weighted observations and 20 weighted samples. Those samples represent one
recording, not 20 independent recordings. Saved attachment retains 58 contexts /
451 windows, and replay uses one source WAV without journals or retraining.

Separately, the existing 2h17m source C supplies 938 observations starting at
feature 938 (60.032 seconds) and another 938 at feature 112500 (7200 seconds).
These distant sections train as two samples: 1876 observations and 145 WFC states.
Only selected observations enter learning, while full source/cache identities
remain verified. This demonstrates long-source section access; it does not prove
automatic song boundaries, corpus balance or musical quality.

Native audit reconstructs tokens directly from the bound caches and relearns
separate weighted samples through the array-based companion learner. All emitted
token/history states and observation/start/end counts match for the initial,
further-blended and long-source profiles. Candidates retain selected absolute
coordinates; saved contexts never cross their declared range. Fit reports measure
280 distinct observations for the two A ranges. A mixed range/whole-input check
measures 140 A observations plus all 469 B observations, verifying that range
selection does not carry over to the next pair.

Checked maintained builds on stable Win32/Win64 and development Win32 produce
identical initial ranged model/WAV bytes. Saved further-blend replay also matches
WAV bytes across all three targets. Each audition has 134144 stereo frames /
8.384 seconds. No listening acceptance is recorded. Initial ranged audition
SHA-256 is `f746521f2eca1920cce960096be7c4a3b994e798afd135cac8a339e746d5d72c`;
further-blend replay is
`b4955b9736b3c0768c3b253f45756ad0ae7c29d08fab1353d6037fcb915b84c3`.

The unchanged whole-journal command produces exact pre-change report/model/WAV
bytes on stable Win64. Negative/zero, out-of-bounds and extreme-count ranges,
overlap, intervening options and incomplete range syntax reject while preserving
existing output files. The operator change adds no new maintained fixture program;
independent audit and logs are ignored under `build/journal-ranges/`.
Long-source section learning and the count audit ran
on stable Win64; cross-target evidence is scoped to the short training/replay.

[WAV-04-RANGES](WAV-STUDIES.md#journal-range-checkpoint) clears section selection as an input to
[WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary) and
[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity). Next declare recording splits and coverage,
weighting and capacity criteria before policy selection. These sections are all
development evidence and do not create a held-out set. Corpus/semantic/listening
gates in [WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration) remain open. The ledger stays
89.8% with the original 10.2-point package unchanged.

<a id="palette-fit-checkpoint"></a>
### Maintained per-recording vocabulary measurements — 2026-09-19

The native library and maintained `pythian.learn fit` command now expose the
frozen-palette diagnostic previously confined to an ignored study. See the
[API and command contract](ANALYSIS-WAVE.md#measuring-frozen-vocabulary-coverage).
One journal pass retains per-range distances, explicit-limit counts, token
occupancy, repetition and nonsilent evidence without retraining or generation.
Training multiplicity is distinct from observation count. Source hashes,
analysis/timebase bindings and vocabulary/model identities accompany the report.

The existing three development sources supply 129621 distinct observations:
C = 128683, A = 469, B = 469. Both saved joint palettes were evaluated with an
explicit squared-distance limit of 0.25, chosen for this diagnostic before its
reports were inspected. This is not a musical acceptance threshold. Existing
mean-distance, token-count and run results agree with the prior study:

| WAV source | Joint 16 mean squared distance | Joint 32 mean squared distance | Observations within 0.25, joint 16 → 32 | Longest token run, joint 16 → 32 |
| --- | ---: | ---: | --- | --- |
| C | 0.179738 | 0.143914 | 106406/128683 (82.69%) → 117846/128683 (91.58%) | 173 → 306 |
| A | 0.143822 | 0.097379 | 426/469 (90.83%) → 459/469 (97.87%) | 25 → 25 |
| B | 0.091454 | 0.073278 | 467/469 (99.57%) → 466/469 (99.36%) | 17 → 18 |

Lower average distance does not improve every coverage statistic: B loses one
observation at the declared limit despite its better mean. C's longest token run
grows even as overall self-transitions fall from 80321 to 75618. The richer
vocabulary also retains the recorded 235→771 model-state cost. These measurements
must inform separate coverage, repetition and capacity criteria; none selects a
preferred default. C has 117 silent observations, explicitly excluded from its
nonsilent mean; A and B have none. No additional recordings or listening verdict
are introduced.

A separate check evaluates B against the original C/A profile: 429/469 observations
fall within the same limit, with mean distance 0.167415. The report correctly
marks B outside that profile's source membership. B has already been used in
development, so this is not held-out evidence or learned genre accuracy.

The existing journal fixture passes with checked FPC 3.2.2 Win32/Win64 and 3.3.1
Win32. Analytic checks cover known distances and entropy, distinct versus weighted
counts, silence, storage/segment boundaries, ownership and invalid-limit rejection
before reader rewind. The maintained tool builds and all source comparisons run
on stable Win64. Invalid limits, mismatched WAV/cache bindings and output/profile
aliasing reject while preserving existing outputs/inputs; hashes of all ten joint
comparison inputs remain unchanged. No new fixture program is added.

Builds, reports and checks remain ignored under `build/palette-fit/`. This clears
only measurement availability for [WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary).
Recording-level policy and held-out acceptance still gate
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration); continuity and semantic-provider gates
remain separate. The 89.8% ledger and original 10.2-point package are unchanged.

<a id="journal-third-source-checkpoint"></a>
### Third-source reuse, vocabulary coverage and generation capacity — 2026-09-19

The existing headroom-preserved source B section adds a third recording to the
saved journal workflow. Its 30-second stereo 16-kHz WAV has 480000 frames and
SHA-256 `be2497a2728cd84e7467ef48c9eadb792b8914df2da0fd7eef2cf5ec4bfc66ea`.
The native complete cache contains 469 observations in 64160 bytes. The study
reuses C's full 2h17m recording and A's existing 30-second section. These sources
were already development material; neither the third source nor new vocabulary
fits constitute held-out evaluation or learned genre labels.

Under the existing shared 16-token palette, B occupies 13 tokens, with effective
token count 9.449 and mean squared feature-to-center distance 0.167415. A palette
trained only on B occupies all 16, with effective count 13.455 and distance
0.052507. The shared palette's in-sample error is about 3.2 times the B-only
palette's; this is not a musical accuracy target. The fixed palette retains variation, but exact compatibility
alone does not establish representative source coverage.

Fresh joint training assigns source multiplicities C/A/B = 4/1115/1115, giving
approximately equal weighted observation mass: 514732/522935/522935. Multiplicity
does not create new recordings or independent evidence. The actual corpus has
three source ranges and 129621 distinct observations. Native per-source fits:

| Source | Existing shared 16 | Joint 16 | Joint 32 |
| --- | ---: | ---: | ---: |
| C | 0.175399 | 0.179738 | 0.143914 |
| A | 0.121016 | 0.143822 | 0.097379 |
| B | 0.167415 | 0.091454 | 0.073278 |

Values are mean squared distances in the same 15-dimensional acoustic feature
space, unweighted within each recording. Joint 16 improves B while worsening A
and C. Joint 32 lowers error on all three but raises actual WFC states from 235
to 771. More capacity does not imply better temporal behavior: C's longest
same-token run increases from 173 to 306 observations between these joint fits.
No threshold, preferred capacity or source-weight policy is admitted by this study.

The maintained `journals --max-tokens 1..32` now exposes existing library capacity;
the default remains 16. A cap is incompatible with `--palette-from`, whose ordered
centers are frozen. Explicit 16 reproduces the prior B report/model/WAV exactly.
Caps one and 32 execute; zero/33 and cap-plus-starter reject. Different 16/32
vocabularies reject direct blending without publishing artifacts. Relearning
compatible profiles is required; there is no new format version or legacy reader.

Separately, B is trained in the original shared vocabulary with multiplicity 1115
and gains 44 contexts / 340 windows. Blending it into the existing C/A derived
profile, then using that result in another blend with B, retains three ranges,
143 contexts / 1398 windows, 2083537 weighted observations and 3349 weighted samples.
Those samples represent explicit multiplicity, not 3349 recordings. Model SHA-256:
`2b8542947c4ea34e0ef9393d0d790572d65b4b4d1f74791184d5fc68c47b13b3`.

Both 1024-grain auditions use context length eight, four starts per anchor and
the existing local candidate/boundary policies. Default source weights give
C/A/B contributions 378/330/316. Changing only generation weights to 1/1/6 gives
182/137/705 with identical model bytes and generated tokens. Shares remain soft,
limited by token eligibility. Independent checks verify remapped parent contexts,
saved replay, tokens, exact window multiplicities and source counts. Dense
assembled mismatch improves 0.997146→0.979290 and 0.984077→0.962810 through boundary
refinement. Final immediate repeats are zero; broader musical quality stays open.
Each WAV has 1051648 stereo frames / 65.728 seconds and PCM peak 0.662842:

- Default weights: `65006a00f181e4ae9e4d06539cbb4e0d74fcdf7169ebf5074f47e7fbc425d213`.
- B-favored: `6299f089e37cf7d10060389ca1cd7a6d36cb5b82a4b15bc89c71be1289e385cf`.

The joint 32-token model retains 223 contexts / 1757 windows, but its requested
1024-grain replay rejects: 771 states × 1024 = 789504 state cells exceeds 262144.
The generation error now reports requested cells, the fixed limit and the
model-specific maximum. The boundary is exercised: 340 grains use 262140 cells
and render 351232 frames / 21.952 seconds; 341 need 262911 and reject without
publishing output. The shorter output is a capacity diagnostic, not completion
of the sustained request. Its SHA-256 is
`67717338bcece8fd8ca66abad98c75c8e72c88386389b2ed82a848b90125a7e2`.
All three audited WAVs pass source/model/output hashes, exact clock and 21
independent cosine-window source probes (error below one PCM16 step).

Evidence is under ignored `build/journal-third-source-study/` and
`build/journal-vocabulary-{stable,trunk,win64}/`. Checked maintained-tool builds
and existing learning/generation fixtures pass stable/development Win32 and
stable Win64. B-only 32-token training produces identical model/WAV bytes and
vocabulary identity on all three; JSON candidate-distance decimals differ
slightly, so full report-byte parity is not claimed. Full three-source training,
fit comparisons and sustained auditions ran on stable Win64 only.

The observations add linked [WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary) coverage and
[WAV-04-GENERATION](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint) capacity results to the ordered backlog.
These block their specific richer-corpus acceptance, not independent context,
phrase or smaller-model work. No genre/listening acceptance, refreshed package,
Linux, remote CI or percentage credit is claimed.

<a id="duration-scope-checkpoint"></a>
### Duration scope diagnosis and monophonic span rendering — 2026-09-19

The former 32-span rejection is an evidence limit, not a solver-budget failure.
The isolated-note saved style's performance model has three states, three
observations and one sample. Exact companion domain analysis accepts prefixes
1..3, then finds no path from position 2 to position 3 (zero-based). The actual
32-span session reports contradiction. Key and tempo models remain feasible.
`TStylePerformance.AnalyzeProvider` now exposes this structural analysis at the
definition's independent provider scopes; the voice operator reports the named
provider/path failure separately from solver or pass backtrack exhaustion.

The existing development flute/violin WAV excerpts produce 245/238 raw duration
spans. They are diagnostic inputs whose phrase-quality criteria still fail.
For this scope probe, context keeps key unknown and explicitly declares 120 BPM;
no automatic key/tempo admission is claimed. A saved blend and further blend
retain two sources with weights 2:1, 728 observations and 482 duration states.
Actual key, tempo and performance passes generate 32 spans, and public native
capture preserves unknown key and the 4762-tick endpoint. The authored accompaniment
operator correctly rejects unknown key; the monophonic duration consumer accepts it.

Independent PCM verification found a separate defect: the preceding note's release
entered a following pitched span. At span 4, expected MIDI 76 measured as the
preceding MIDI 64 (329.628 Hz). Monophonic `pythian.pitch.wav` span auditions now
use zero post-gate release with the existing 44-frame interior articulation fades.
The general polyphonic renderer and its release policy are unchanged.

The PCM verifier bounds each measurement to its own span and raises its minimum
measurable frequency only when the available duration requires it; it never tunes
the estimator to the expected note. All 18 pitched spans now pass, including
shorter spans that cannot hold the old fixed low-frequency measurement window.
The original leaking audio still fails this same verifier, preserving the negative
control. Unknown/silent spans, exact WFC model/state paths and tempo/gate timing
also pass. The output is 218754 stereo frames at 44100 Hz (about 4.96 seconds),
not a claim of sustained or accurate musical phrasing.

| Probe | Result |
| --- | --- |
| Supported saved second blend | 32 spans / 18 pitched notes; WAV SHA-256 `0a58b2f723996f08fbc87a3b8d38de85839b2e5ad98be4f335ca986264d1ab05`, identical on checked stable/development Win32 and stable Win64. |
| Duration-only lock at cell 0 to 1680 ticks | Performance regenerates while key/tempo states remain exact; 32 spans / 17 pitched notes, 214803 frames; all PCM pitch/timing checks pass. WAV SHA-256 `056b0f0cc3999292e73d33f48c000975ad5cc0f54c8df7346c54ac178e131448`. |
| Unsupported isolated-note 32-span prefix | All three targets reject with the same structural path diagnosis. The model and request semantics are retained. |
| Earlier supported three-span audition | Independent pitch/timing checks pass and original PCM bytes remain identical, SHA-256 `f31690dead54cc844a758f6ad6ae42bf6093376e4d3c7de4bc3a93e7629bdb98`. |

The extended existing performance fixture passes on all three targets. Evidence
is under ignored `build/duration-scope-{stable,trunk,win64}/` and
`build/duration-scope-study/`; the native inspector compares exact structural
analysis with actual sessions and capture. Owned builds have no warnings; upstream
diagnostics remain. No format, vendor, package, full ordinary build or remote-CI
change is included. [WAV-03-DURATION](WAV-STUDIES.md#duration-scope-checkpoint)'s mechanical request gate
is resolved; [WAV-03-PHRASES](MILESTONES.md#wav-03-phrases) still blocks admitted recorded-part
quality. The broader musical goal remains open and receives no new percentage credit.
