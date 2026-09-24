# North-star goals and active milestones

[Home](../README.md) · [Project scope](../PROJECT.md) ·
[Work record](WORK.md) · [Style architecture](LAYERED-STYLE.md)

## North-star assessment

**Updated 2026-09-23: approximately 69% engineering completion; no accepted
genre style yet.** The destination is an independent Pascal synthesis library
that learns useful musical behavior from many hours of WAV recordings, generates
through independently controllable WFC passes, and saves styles that remain
usable through selective blends and further blends. Initial test styles:
**chillwave, stoner rock and lofi**. Core fundamentals retain priority.
These are the user's initial test preference labels. Their eventual acceptance
will be scoped to declared source evidence and evaluation listeners, not a
universal definition of each named genre. The portable core must remain useful
without these particular preferences.

**Execution resumed at the user's request.** The user additionally requires a
Pascal-only inference workflow. The former external-runtime execution credit
was withdrawn on reopening; fresh Pascal [observation](TODO/DONE/NS-3_validation_03.md)
and [execution](TODO/DONE/NS-3_validation_02.md) acceptance restores the same
1.25 overall points. Subsequent processing, source and combined-quality acceptance add
5.00 overall points; the accepted local-key/no-key and note-presence reference
packets add 0.25 each;
current completion is **68.65%**. The [retrospective](WORK.md#pause-retrospective--2026-09-21)
and [current work record](WORK.md#pascal-only-inference-requirement--2026-09-22)
preserve the earlier evidence and the new boundary. Existing note, presence,
mixture and style-reference criteria remain unchanged.

The old **89.8% is retired**. The accepted planning baseline remains **55.5
weighted points**. The [55-task catalog](TODO/README.md) allocates every
remaining point to explicit acceptance criteria and prerequisites. Accepted
corpus identity, consumer/native delivery, named
voice passes/provider compatibility, granular controls, semantic persistence,
duration/stream edits, repaired shared validation, selective semantic blends,
maintained mixture measurement with reproducible controls and qualified external
references, selective Pascal observations and supervised execution add
**7.65 points** at that checkpoint. Accepted [processing and routing quality](TODO/DONE/NS-2_synthesis-quality_02.md)
adds **1.50 points**, and accepted [source/articulation quality](TODO/DONE/NS-2_synthesis-quality_01.md)
adds **2.00**; accepted [combined quality](TODO/DONE/NS-2_synthesis-quality_03.md)
adds **1.50**, bringing completion at that checkpoint to **68.15**. The
accepted [local-key/no-key reference packet](TODO/DONE/NS-3_context_03.md)
then adds **0.25**, bringing that checkpoint to **68.40**. The accepted
[note-presence reference packet](TODO/DONE/NS-3_notes_04.md) adds **0.25**,
bringing current completion to **68.65**. The
former external-runtime observation evidence remains historical. The [preparation-task split](#mixture-preparation-task-split) preserves
the original scope and total credit; only its QA-accepted deliverable earns points.
Subsequent accepted tasks update their north-star and overall percentages individually.

The following paragraphs preserve the 2026-09-21 credit sequence; their totals
precede the Pascal-only reopening above.

Infrastructure review on 2026-09-21 found that prediction ancestry was never
required or traversed before independent eligibility. Reopening shared validation
withdrew **0.50 overall points**, taking completion to 59.1%. Final checked-target
QA now accepts that repair and restores the original allocation. New semantic
persistence and duration/stream edits add 1.20 points: **59.1 + 0.5 + 1.2 = 60.8**.
The repair creates no additional scope or duplicate credit.
Selective semantic blend/reblend now passes all criteria on both checked native
targets, adding **0.60 points: 60.8 + 0.6 = 61.4**. This accepts composition and
reuse; listening and recorded-provider/genre acceptance remain separate.

Practical native execution passed its continuous-hour qualification and initially
added 1.25 points. Infrastructure review then found a progress snapshot race
that can falsely terminate a healthy worker. Reopening the existing execution
task temporarily withdrew those points: **62.65 - 1.25 = 61.4**. Atomic progress
publication, deterministic transition checks and real-worker replay now pass
focused QA, restoring the original allocation: **61.4 + 1.25 = 62.65**. Unchanged
numerical/resource evidence is retained. Musical admission, genre quality and
whole-corpus scale remain separate; the repair adds no new scope or credit.

### Goal scorecard

Completion is a coarse scope judgment, not measured test coverage, effort spent,
a release forecast or ecosystem adoption. Weights total 100; remaining points
are the scope still assigned to each goal. Completed work is condensed here,
with detailed history in the linked evidence rather than active tasks.

| North star | Completion | Weight | Completed capability credited / evidence | Remaining outcome | Overall points left |
| --- | ---: | ---: | --- | --- | ---: |
| <a id="ns-1"></a>**NS-1 — Independent Pascal foundation** | **100%** | 10 | Independent owned core; agreed WFC/Phanes extraction, Phanes removal and complete provenance. [Audit](REFERENCE-REMOVAL.md). | No open extraction work. Preserve independence and notices. Delivery is NS-6. | **0** |
| <a id="fund-contracts"></a><a id="ns-2"></a>**NS-2 — Dependable synthesis fundamentals** | **100%** | 25 | Supported synthesis, samples, modulation, effects, buses, timing and streaming; reviewed contracts and numerical/replay evidence. Declared [source/articulation](TODO/DONE/NS-2_synthesis-quality_01.md), [processing/routing](TODO/DONE/NS-2_synthesis-quality_02.md) and [combined quality](TODO/DONE/NS-2_synthesis-quality_03.md) examples are accepted at their bounded scopes. [Capability map](FUNDAMENTALS.md#contract-review). | No open NS-2 task; preserve the accepted scope in downstream work. | **0** |
| <a id="wav-02"></a><a id="wav-03"></a><a id="ns-3"></a>**NS-3 — Trustworthy musical learning from WAV** | **41%** | 25 | Source-bound measurements, selected clocks, uncertainty/manual context, narrow pitch/duration learning, [selective Pascal observations](TODO/DONE/NS-3_validation_03.md), [supervised Pascal WAV inference](TODO/DONE/NS-3_validation_02.md), [shared scoring with repaired ancestry admission](EVALUATION-OPERATOR.md), [maintained mixture measures/control packet](TODO/DONE/NS-3_parts_04.md), [qualified external references](TODO/DONE/NS-3_parts_01.md), [reviewed local-key/no-key intervals](TODO/DONE/NS-3_context_03.md) and [source-separated note-presence reference](TODO/DONE/NS-3_notes_04.md). [Phrase](PHRASE-EVALUATION.md) and [pulse](BEAT-TRACKING.md) evidence retain the accuracy gaps. | Independently validated context, notes, mixed parts, harmony, groove and evolving sound: **16 open NS-3 tasks**. | **14.75** |
| <a id="wfc-preferences"></a><a id="ns-4"></a>**NS-4 — Granular WFC layers and reusable blends** | **96%** | 15 | Actual dependent passes, [granular musical/sound controls](INDEPENDENT-VOICES.md#granular-musical-and-sound-controls), typed replacement, [saved semantic graphs](SEMANTIC-STYLES.md), [selective blends/reblends with retained evidence](SEMANTIC-BLENDS.md) and [staged duration/committed-stream edits](DURATION-STREAMS.md). | Accepted recorded-provider audio integration: **WAV-04-INTEGRATION**. | **0.6** |
| <a id="wav-04"></a><a id="ns-5"></a>**NS-5 — Many-hour styles that generate and blend usefully** | **27%** | 20 | Ingestion, journals, acoustic vocabulary and mechanical reuse; accepted two-recording identity pilot with derivative/exposure and inherited-palette audits. [Pilot](CORPUS-EVALUATION.md#verified-identity-pilot). | Representative genre corpora, practical scale, sustained structure and acceptance of all three styles and cross-style blends: **16 tasks / 6 corpus outcomes**. | **14.6** |
| <a id="wav-05"></a><a id="ns-6"></a>**NS-6 — Independently usable library and delivery** | **72%** | 5 | Accepted [consumer contract](CONSUMER-CONTRACT.md) and [clean native delivery checkpoint](NATIVE-CHECKPOINT.md): stable Win32/Win64 builds, four extracted consumers and successful Linux CI at frozen source. | Accepted-workflow delivery and independently reproduced use: **WAV-05-DELIVERY, DELIVERY-RELEASE**. | **1.4** |
| **Total** | **≈69%** | **100** | **68.65 weighted points credited** | **36 open tasks / 18 active outcomes** | **31.35** |

Arithmetic: `10×1.00 + 25×1.00 + 25×0.41 + 15×0.96 + 20×0.27 + 5×0.72 = 68.65`.
The decimal is bookkeeping, not measurement precision. NS-3 earns measurement
accuracy; NS-4 earns composition/reuse; NS-5 earns corpus/style quality; NS-6
earns delivery. Consuming an earlier result earns no duplicate provider credit.

### Acceptance dashboard

| Required result | Current evidence and assessment | Owner |
| --- | --- | --- |
| Supported synthesis sounds acceptable | Signal/replay checks and the [bounded three-task listening union](SYNTHESIS-QUALITY.md#fund-quality-bounded-acceptance--2026-09-23) accept the declared source, processing and combined examples after favorable full-clip reviews. Broader settings and genre styles remain separately gated. | [FUND-QUALITY](#fund-quality) |
| Base key/BPM can be learned reliably | Maintained timing queries retain alternatives, uncertainty and saved WFC context. The [joint candidate comparison](BEAT-TRACKING.md#model-candidate-comparison) reaches **.9863 polyrhythm F1 without supplied rate/band hints** and 1.0 on deception, but fails changing/authored controls. Perfect provider agreement can select the wrong beat level. Automatic metrical admission, independent local-key admission and useful observed coverage remain open. | [Pulse](#wav-02-pulse), [context](#wav-02-context) |
| Recorded notes are reliable enough for learning | Preferred development precision **91.57% flute / 98.55% violin**, required **98%**. Violin passes all four development gates; flute fails precision. Larger-model, coherent-observation and [predictive-phase](PHRASE-EVALUATION.md#predictive-phase) comparisons have not resolved the recorded gap. Address presence/rest and register together before freezing independent phrase evaluation. [Evidence and rejected approaches](PHRASE-EVALUATION.md). | [Register](#wav-03-register), [boundaries](#wav-03-boundaries), [phrases](#wav-03-phrases), [validation](#wav-validation) |
| Musical layers and learned relationships survive generation/reblend | Named sessions and compatible provider replacement preserve unrelated accepted states and pending edits; typed role/clock contracts and paired demo replay pass both native targets. Saved mechanical reuse works. General recorded providers and integrated acceptance remain unfinished. | [NS-3](#ns-3), [NS-4](#ns-4) |
| Many hours produce a useful style | **Chillwave: unaccepted. Stoner rock: unaccepted. Lofi: unaccepted.** Duration, caller labels and source-fragment resemblance do not establish learning quality. | [NS-5](#ns-5) |
| Another consumer can use the current result | The [accepted native checkpoint](NATIVE-CHECKPOINT.md) passes stable Win32/Win64 full builds, four extracted source packages and Linux CI at `0ecfe34`. Final accepted-workflow packages and an actual independent-use verdict remain open. | [NS-6](#ns-6) |

**Musical learning and corpus quality account for 29.35 of the remaining 31.35
points (about 94%).** Additional diagnostics and mechanical adapters have value
only insofar as they resolve those outcomes; they do not close musical acceptance.

### Scope reconciliation

Every primary requirement has a backlog owner:

| Requirement | Owner(s) |
| --- | --- |
| Reliable fundamental audio behavior | FUND-QUALITY |
| Learn key/BPM, changes and uncertainty | WAV-VALIDATION, WAV-02-PULSE, WAV-02-CONTEXT |
| Learn notes, bass/voice ownership and musical relationships | WAV-03-REGISTER, WAV-03-BOUNDARIES, WAV-03-PHRASES, WAV-03-PARTS, WAV-02-HARMONY, WAV-02-GROOVE, WAV-03-TIMBRE |
| Small controllable base → harmony/rhythm → bass/voice passes | WFC-LAYERS |
| Save one/many-recording styles, blend, then blend again | WFC-STYLE, WAV-04-INTEGRATION |
| Learn representative many-hour corpora and sustained music | CORPUS-SETUP, WAV-04-VOCABULARY, CORPUS-SCALE, WAV-04-CONTINUITY, SONG-STRUCTURE, STYLE-EVAL |
| Practical native execution and adoption of successful studies | WAV-VALIDATION plus the affected provider; CORPUS-SCALE owns aggregate workload |
| Current distribution and independent use | WAV-05-DELIVERY, DELIVERY-RELEASE |

Keep one current native format per distinct artifact contract. Historical versions
or adapters need concrete consumer value. Preserve the core's independence from
WFC, hosts and devices. New capabilities require an explicit consumer requirement;
100% means acceptance of declared support, not universal transcription or every
possible synthesis technique. Ecosystem adoption remains separately unmeasured.

## Active backlog

The [external reference prerequisite is DONE](TODO/DONE/NS-3_parts_01.md).
The qualified two-family packet and
[curator acoustic-reference supplement](PART-EVALUATION.md#curator-acoustic-reference-supplement--2026-09-21)
supply useful role intervals/sets, all contributors and explicit scenario gaps.
Final QA accepts native replay, preservation, resource limits and relocated
scoring. This earned its allocated +1 NS-3 point / +0.25 overall, bringing the
historical 2026-09-21 total to **63.15%** before the later inference reopening.
No mixture learner or independent accuracy verdict is implied.

Continue the NS-5 prerequisite path through [recorded note identity](TODO/NS-3_notes_01.md)
and [presence/boundaries](TODO/NS-3_notes_02.md), then
[independent phrases](TODO/NS-3_notes_03.md) before actual role learning.
Reference preparation no longer blocks parts_02; accepted note primitives still
do. Keep the failed registration/tail and note-decoder families stopped. The
next note-development batch requires a discriminating observation and bounded
acceptance decision, preserving existing controls and held-out recordings.
External crossings, unison, quiet-part ownership and broader complete-reference
coverage remain explicit requirements of actual role-learning acceptance.

Batch 28's [source-separated candidate scorer](PHRASE-EVALUATION.md#source-separated-candidate-calibration--2026-09-21)
passes implementation QA but fails its fixed flute calibration challenge even
with oracle pitch candidates. Stop that proposal without applying it to the
existing development baseline or changing thresholds. Note identity and
presence tasks remain open; no completion credit changes. The next design needs
justified treatment of candidate ambiguity and presence, with prospective
confidence/coverage and source separation rather than post-hoc error cutoffs.

**36 open task files own the remaining work across 18 active outcomes; 18 tasks are DONE.**
The 22-outcome map below retains accepted FUND-QUALITY, WFC-LAYERS,
WFC-STYLE and WAV-VALIDATION anchors for evidence.
See the [task catalog](TODO/README.md) for credits and a prerequisite-first order,
and [TASKFLOW.MD](TASKFLOW.MD) for the required template, gap handling, DONE moves
and completion accounting. [Corpus identity](TODO/DONE/NS-5_corpus_01.md) is accepted.
Execution started from the least-complete north star, **NS-5 (25% -> 27%)**,
and follows prerequisites. [Shared validation](TODO/DONE/NS-3_validation_01.md)
is accepted after prediction-ancestry repair; return to [style cards and comparators](TODO/NS-5_evaluation_01.md),
then genre corpus coverage. The previous provider draft is accepted through the
[named voice API](TODO/DONE/NS-4_layers_01.md). [Provider compatibility](TODO/DONE/NS-4_layers_02.md)
and [granular controls](TODO/DONE/NS-4_layers_03.md),
[duration/stream edits](TODO/DONE/NS-4_layers_04.md) and
[semantic persistence](TODO/DONE/NS-4_styles_01.md) and
[selective blend/reblend](TODO/DONE/NS-4_styles_02.md) are also accepted. Recorded
workflow integration follows its remaining provider and listening prerequisites.

The [working style specification](STYLE-CARDS.md) now defines provider-specific
comparators, source-bound acoustic controls and external musical annotation
controls. Complete genre reference annotations, assignments and calibrated
numerical criteria are still missing. This
supporting work does not close the style-card task or change completion.

The [candidate reference cards](STYLE-CARDS.md#candidate-reference-cards) bind
existing excerpts to declared work associations and missing musical fields;
recording correspondence and complete genre annotations remain unresolved.
The former external-runtime inference results retain their historical
controlled/recorded arithmetic, short rate/channel, failure/cancellation and
continuous-hour workload evidence. The fresh [Pascal execution task](TODO/DONE/NS-3_validation_02.md)
now removes its single-file inference prerequisite from [whole-pipeline workload
budgeting](TODO/NS-5_scale_01.md); that broader workload has not run. The prospective
[2.32-hour development workload](CORPUS-SCALE.md) also retains its
[admitted-note/learning bridge](TODO/NS-3_notes_03.md) prerequisite; no whole-corpus
training result or credit is claimed. The [timed key comparison](TONAL.md#timed-development-comparison)
improves one source and regresses on the other, failing its frozen scientific
gate. The [frozen error audit](TONAL.md#frozen-key-error-audit) locates source 16's
net exact-match loss in fully labelled constant contexts, with a net increase in
relative-key errors. A subsequent [fixed profile comparison](TONAL.md#fixed-key-profile-comparison)
also fails: exact key matching falls to 32.016% / 21.142% on the two recordings.
The [decision audit](TONAL.md#rejected-profile-decision-audit) now reproduces every
score and shows new errors in fully labelled constant contexts on both sources,
including fifth-related and more distant confusions. Stop profile variations;
the next evidence must distinguish tonic from dominant activity and retain
frequency provenance and temporal order. The [note-cache reassessment](PHRASE-EVALUATION.md#identity-evidence-reassessment--2026-09-21)
stops the contingent envelope correction: no disputed event passes the fixed
guards, and the cache lacks exact unavailability reasons. The subsequent
[cache-only attribution](PHRASE-EVALUATION.md#cached-availability-attribution--2026-09-21)
cannot resolve any unavailable triple. The subsequent
[exact trace replay](PHRASE-EVALUATION.md#exact-availability-trace-replay--2026-09-21)
matches all original outputs and attributes every unavailable triple to ordered
phase-support exits. This supplies branch information, not physical identity;
all eleven flute octave-error events still fail the lower-hypothesis guard.
Stop that correction family and assess independent identity evidence. Note
presence remains independently actionable under its existing task; reuse the
retained head, event-context and short-note studies before another experiment.
The next two feasibility checks also stop before recorded comparison. The
[retained contour head](PHRASE-EVALUATION.md#cached-contour-support-does-not-recover-both-short-notes--2026-09-21)
does not recover the short 55-Hz note and supplies no reliable silence evidence
in the repeated-note gap. A [fixed harmonic dictionary](TONAL.md#harmonic-dictionary-feasibility)
passes corrected numerical QA but fails 31/72 synthetic preservation cases;
spectral-shape mismatch creates false class weight and missing-fundamental error.
These results rule out the proposed fallbacks. Next reassess the observation
contract for changing harmonic sound, genuine simultaneous notes and presence;
do not rerun rejected decoder/profile variations. No acceptance gate is relaxed.
These diagnostics inform next actions but earned no musical-acceptance credit.
Current completion is **68.65%** after accepting selective Pascal observations,
supervised WAV execution, the declared source, processing and combined quality
packets, the reviewed local-key/no-key reference packet and the qualified
note-presence reference. The maintained
measurement/control deliverable and external mixture reference packet remain
accepted.

The tables below retain existing outcome anchors for topic links. They are
navigation to the task files, not duplicate acceptance criteria. An outcome is
closed only when all mapped tasks are accepted, including shared prerequisites.
A mapped task's credit is counted once even if it supports more than one outcome.

| Outcome | North star | Required task files |
| --- | --- | --- |
| <a id="fund-quality"></a>**FUND-QUALITY — accepted at bounded scope** | NS-2 | [source/articulation — DONE](TODO/DONE/NS-2_synthesis-quality_01.md), [processing/routing — DONE](TODO/DONE/NS-2_synthesis-quality_02.md), [combined interaction — DONE](TODO/DONE/NS-2_synthesis-quality_03.md) |
| <a id="wav-validation"></a>**WAV-VALIDATION — accepted** | NS-3 | [Selective Pascal observations — DONE](TODO/DONE/NS-3_validation_03.md), [supervised Pascal WAV inference — DONE](TODO/DONE/NS-3_validation_02.md) and [shared evaluation — DONE](TODO/DONE/NS-3_validation_01.md) |
| <a id="wav-02-pulse"></a>**WAV-02-PULSE** | NS-3 | [NS-3_tempo_04 candidate evidence](TODO/NS-3_tempo_04.md), [NS-3_tempo_01 selection](TODO/NS-3_tempo_01.md), [NS-3_tempo_02](TODO/NS-3_tempo_02.md), [NS-3_tempo_03](TODO/NS-3_tempo_03.md) |
| <a id="wav-02-context"></a>**WAV-02-CONTEXT** | NS-3 | [NS-3_context_03 reference packet — DONE](TODO/DONE/NS-3_context_03.md), [NS-3_context_01 decision](TODO/NS-3_context_01.md), [NS-3_context_02](TODO/NS-3_context_02.md) |
| <a id="wav-03-register"></a>**WAV-03-REGISTER** | NS-3 | [NS-3_notes_01](TODO/NS-3_notes_01.md) |
| <a id="wav-03-boundaries"></a>**WAV-03-BOUNDARIES** | NS-3 | [NS-3_notes_04 accepted reference packet](TODO/DONE/NS-3_notes_04.md), then [NS-3_notes_05 presence observation](TODO/NS-3_notes_05.md), then [NS-3_notes_02 event decision](TODO/NS-3_notes_02.md) |
| <a id="immediate-acceptance-result"></a><a id="wav-03-phrases"></a>**WAV-03-PHRASES** | NS-3 | [NS-3_notes_03](TODO/NS-3_notes_03.md) |
| <a id="wav-03-parts"></a>**WAV-03-PARTS** | NS-3 | [NS-3_parts_02](TODO/NS-3_parts_02.md), [NS-3_parts_03](TODO/NS-3_parts_03.md); accepted prerequisites: [external reference packet — DONE](TODO/DONE/NS-3_parts_01.md), [measurement/control packet — DONE](TODO/DONE/NS-3_parts_04.md) |
| <a id="wav-02-harmony"></a>**WAV-02-HARMONY** | NS-3 | [NS-3_harmony_01](TODO/NS-3_harmony_01.md) |
| <a id="wav-02-groove"></a>**WAV-02-GROOVE** | NS-3 | [NS-3_groove_01](TODO/NS-3_groove_01.md) |
| <a id="wav-03-timbre"></a>**WAV-03-TIMBRE** | NS-3 | [NS-3_timbre_01](TODO/NS-3_timbre_01.md), [NS-3_timbre_02](TODO/NS-3_timbre_02.md) |
| <a id="wfc-layers"></a>**WFC-LAYERS — accepted** | NS-4 | No active task. [Duration/stream edits — DONE](TODO/DONE/NS-4_layers_04.md), [named voices — DONE](TODO/DONE/NS-4_layers_01.md), [provider compatibility — DONE](TODO/DONE/NS-4_layers_02.md), [granular controls — DONE](TODO/DONE/NS-4_layers_03.md) |
| <a id="wfc-style"></a>**WFC-STYLE — accepted** | NS-4 | No active task. [Selective blend/reblend — DONE](TODO/DONE/NS-4_styles_02.md), [semantic persistence — DONE](TODO/DONE/NS-4_styles_01.md) |
| <a id="wav-04-integration"></a>**WAV-04-INTEGRATION** | NS-4 | [NS-4_integration_01](TODO/NS-4_integration_01.md) |
| <a id="corpus-setup"></a>**CORPUS-SETUP** | NS-5 | [NS-5_corpus_02](TODO/NS-5_corpus_02.md), [NS-5_corpus_03](TODO/NS-5_corpus_03.md), [NS-5_corpus_04](TODO/NS-5_corpus_04.md), [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md); accepted prerequisite: [NS-5_corpus_01 — DONE](TODO/DONE/NS-5_corpus_01.md) |
| <a id="wav-04-vocabulary"></a>**WAV-04-VOCABULARY** | NS-5 | [NS-5_vocabulary_01](TODO/NS-5_vocabulary_01.md), [NS-5_vocabulary_02](TODO/NS-5_vocabulary_02.md) |
| <a id="corpus-scale"></a>**CORPUS-SCALE** | NS-5 | [NS-5_scale_01](TODO/NS-5_scale_01.md), [NS-5_scale_02](TODO/NS-5_scale_02.md) |
| <a id="wav-04-continuation"></a><a id="wav-04-boundaries"></a><a id="wav-04-continuity"></a>**WAV-04-CONTINUITY** | NS-5 | [NS-5_continuity_01](TODO/NS-5_continuity_01.md) |
| <a id="song-structure"></a>**SONG-STRUCTURE** | NS-5 | [NS-5_structure_01](TODO/NS-5_structure_01.md), [NS-5_structure_02](TODO/NS-5_structure_02.md) |
| <a id="style-eval"></a>**STYLE-EVAL** | NS-5 | [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md), [NS-5_evaluation_02](TODO/NS-5_evaluation_02.md), [NS-5_chillwave_01](TODO/NS-5_chillwave_01.md), [NS-5_stoner-rock_01](TODO/NS-5_stoner-rock_01.md), [NS-5_lofi_01](TODO/NS-5_lofi_01.md), [NS-5_blends_01](TODO/NS-5_blends_01.md) |
| <a id="wav-05-delivery"></a>**WAV-05-DELIVERY** | NS-6 | [NS-6_delivery_03](TODO/NS-6_delivery_03.md); accepted prerequisite: [native checkpoint — DONE](TODO/DONE/NS-6_delivery_02.md) |
| <a id="delivery-release"></a>**DELIVERY-RELEASE** | NS-6 | [NS-6_delivery_04](TODO/NS-6_delivery_04.md), [NS-6_delivery_05](TODO/NS-6_delivery_05.md); [consumer contract accepted](TODO/DONE/NS-6_delivery_01.md) |

## Completion accounting

### Mixture preparation task split

On 2026-09-21, repeated source diagnostics showed that the original parts_01
combined two independently deliverable outcomes. Split its **2 NS-3 points**
into **parts_04: maintained scoring/control packet, 1 point**, and
**parts_01: qualified external reference packet, 1 point**. Total credit stays
2 NS-3 / 0.50 overall points; creating the new task earns nothing. The catalog
now has 50 tasks. This work postdates the accepted baseline and was not already
credited elsewhere. Final QA verifies all five scoring/control criteria and
twelve current maintained identities against applicable checked-target evidence.
[parts_04 is now DONE](TODO/DONE/NS-3_parts_04.md): **37 + 1 = 38% NS-3** and
**62.65 + 0.25 = 62.90 overall** at that checkpoint. The external packet later
passes all criteria and earns its remaining one point: **38 + 1 = 39% NS-3**,
**62.90 + 0.25 = 63.15 overall**. Both split deliverables are now DONE.

| Original parts_01 requirement | Owner after split |
| --- | --- |
| Bound stems/mixes, identities, gains, roles and common splits | parts_01 external packet |
| Bass/chordal/lead/other, simultaneous notes, crossings, masking, rests and uncertainty | parts_04 authored measurement controls; parts_01 external annotations and scenario coverage |
| Independent per-role note/timing/coverage/leakage/crossing measures with uncertainty and frozen groups | parts_04 maintained measures and validation; parts_01 qualified frozen families |
| Supported mixtures and gates before evaluation predictions; separation is not role truth | Both contracts; parts_01 source-specific application |
| Ignored assets, accurate provenance and reproducible native scoring packet | parts_04 maintained executable control packet; parts_01 external reconstruction and scoring packet |

parts_01 now depends on parts_04, which retains the accepted shared-validation
prerequisite. parts_02 still depends on parts_01 and trusted note primitives,
therefore cannot bypass either preparation deliverable. The new
[task-size checkpoint](TASKFLOW.MD#task-size-and-investigation-stop-points) requires
reassessment after two batches without an acceptance criterion closing. The
current boundary investigation ends with its supported annotation and retained
unknowns; the next work must assemble the external packet rather than continue
segmentation variants. No original requirement or learner gate is removed.

### Note-presence reference split

On 2026-09-22, the second nonclosing known-gate presence batch showed that
note-off metadata alone cannot qualify audible release-tail and rest labels.
The external reference packet is an independently useful prerequisite, now
[NS-3_notes_04](TODO/DONE/NS-3_notes_04.md), with **1 NS-3 goal point / 0.25 overall**.
The remaining [NS-3_notes_02](TODO/NS-3_notes_02.md) observation, event
decision, controls and recorded gates retain **3 NS-3 points / 0.75 overall**.
Their original **4 / 1.00** allocation is unchanged; neither task is accepted
by this split. The new packet is a true prerequisite, and both still feed
[independent phrase acceptance](TODO/NS-3_notes_03.md).

On 2026-09-23, two further source-preparation batches failed at frozen
metadata gates before labels or inference. The broad three-point event task
was split at the reusable observation boundary: new
[NS-3_notes_05](TODO/NS-3_notes_05.md) owns a source-grounded Pascal
presence/unknown observation for **1 NS-3 point / 0.25 overall**;
[NS-3_notes_02](TODO/NS-3_notes_02.md) retains integration, event timing and
recorded phrase gates for **2 NS-3 points / 0.50 overall**. The original
four-point reference + observation + integration allocation is still **1+1+2**.
The accepted reference remains 1 point; neither new open deliverable earns
credit from the split. The 55-task catalog has one extra open task, while
NS-3's 41% completion and 59 remaining goal points are unchanged.

| Original notes_02 requirement | Owner after split |
| --- | --- |
| Contrasting source-bound continuation, acoustic tail and rest references, with provenance, uncertainty and source separation | notes_04 qualified reference packet |
| Note presence distinct from pitch rank; attack/continuation/rest/end decision | notes_02 maintained observation and event path |
| Short/quiet/repeated/gap/mixture controls and recorded false-rest/boundary limits | notes_04 candidate coverage; notes_02 implementation and accepted gates |
| Source timing, unknown spans and integrated phrase behavior | notes_02, then notes_03 independent acceptance |

### Credit ledger

The task ledger subdivides the **existing remaining scope**, without increasing
the accepted baseline or claiming that planning itself advances completion.

| Goal | Baseline | Accepted task credit | Current | Open task credit | Open tasks |
| --- | ---: | ---: | ---: | ---: | ---: |
| NS-1 | 100% | 0 | 100% | 0 | 0 |
| NS-2 | 80% | 20 | 100% | 0 | 0 |
| NS-3 | 30% | 11 | 41% | 59 | 16 |
| NS-4 | 70% | 26 | 96% | 4 | 1 |
| NS-5 | 25% | 2 | 27% | 73 | 16 |
| NS-6 | 50% | 22 | 72% | 28 | 3 |

Each completed task adds its declared **goal percentage points** to that goal;
multiply by the goal weight / 100 for overall movement. The
[TASKFLOW formula](TASKFLOW.MD#complete-move-and-update-percentages) governs
reopened tasks and new/split scope. Move an accepted task to DONE and update
these totals, the scorecard and the task index in the same logical change.
Evidence must support the actual task criteria; no partial or test-count credit.

For example, accepted `NS-3_notes_01` moves NS-3 from 41% to 45% and overall
completion from 68.65% to 69.65%, assuming no other changes. This makes bounded
outcome progress visible without waiting for all WAV learning to finish.
The remaining open task credits add **31.35 overall points**, reaching 100 only
when the required work and final scope audit are accepted.

## Execution order and blocking links

1. Preserve accepted prediction-ancestry admission; resolve pitch identity and
   presence together, then freeze independent phrase acceptance. Timing follows
   stable pulse -> changing clock/meter -> independent acceptance; key admission
   joins accepted timing in the reusable context task.
2. Accept supported roles from attributed stems and mixtures, then harmonic,
   groove and evolving sound behavior. Synthesis listening proceeds independently
   until its required verdicts and demonstrated fixes are complete.
3. Use accepted semantic controls, persistence, duration edits and repeated
   blending to integrate accepted WAV providers through native audio.
4. Prepare verified corpus identities and trait cards early. Populate each
   genre's independent splits; complete balanced vocabulary growth, many-hour
   recovery, continuity, structure and the fixed comparison packet.
5. Accept each genre and cross-style reuse, then deliver the exact accepted
   workflow and obtain independently reproduced consumer evidence.

Task files contain the actual hard dependencies. Separate preparation tasks
avoid artificial cycles; a genre verdict does not wait for another genre's
verdict. Shared corpus/training infrastructure may use verified development data
before full genre coverage is ready. Readiness does not justify moving away from
the currently selected outcome to another convenient API task.

<a id="next-work-five-outcome-milestones"></a>
## Direction for the next work package

The previous M1–M7 point split is superseded by the explicit task allocations.
The north-star totals and original end state are unchanged. Use these larger
outcome packages, each above the requested ten-point minimum. Keep former A and B
combined: after accepted measurement/control, reference delivery and selective
Pascal observations, supervised execution, bounded source, processing and
combined-quality acceptance, and local-key/no-key and note-presence reference
qualification,
they have 15.35 points remaining.
This grouping changes neither individual task credits nor the intended scope:

| Package | Accepted result and included work | Conditional overall gain |
| --- | --- | ---: |
| **A+B — Dependable sound and recorded musical learning through reusable generation** | Accepted NS-2 combined audible quality is complete; remaining NS-3 tempo, context and notes (+7.25), plus parts, harmony, groove and timbre (+7.50); remaining NS-4 recorded-provider audio integration (+0.6). | **+15.35 remaining** |
| **C — Accepted many-hour styles and independent delivery** | Remaining NS-5 corpus, vocabulary, scale, continuity, structure and three-style/cross-style acceptance (+14.6); remaining NS-6 delivery and independent use (+1.4). Corpus identity, consumer contract and native checkpoint already earned +1.5. | **+16.0 remaining** |

**68.65 current + 15.35 + 16.0 = 100.**
These are scope allocations, not time estimates or promises of success. Record
task credit as each accepted task finishes; preparation from later packages can
be useful sooner when the selected outcome requires it.

### First work to schedule

The next outcome is a **recorded-note-to-generated-audio vertical slice**,
using the existing Pascal observation and synthesis paths. The immediate
development preview makes that path listenable at a substantial length. Then
deliver a source-grounded, recording-grouped reference packet that can support both
[register identity](TODO/NS-3_notes_01.md) and
[presence](TODO/NS-3_notes_05.md). Qualify the publisher's annotation method,
source identity, known errors, acoustic positive/rest evidence and untouched
evaluation groups at the recording level. Do not request routine 250-ms source
labels from the user. If a source cannot support the needed claims, stop it
before another scorer variant; preserve the failed evidence.
The Good-sounds metadata and full-recording URMP Waltz gates have now both
stopped before a usable no-instrument reference. The next source strategy must
bind actual no-instrument acoustics independently of note/F0 gaps; no further
window search in either stopped source is scheduled. The reserved URMP
Miserere work and independent phrase recordings remain untouched.
The subsequent original six-string GuitarSet pickup comparison also failed its
frozen acoustic rest gate before scoring, with the reserved player unopened.
Stop this source/window route too. The preview's failed listening result and
three nonclosing source strategies call for a changed core work batch, not
another threshold or source-window variation.

Then complete [register identity](TODO/NS-3_notes_01.md) and
[presence](TODO/NS-3_notes_05.md), followed by
[event decisions](TODO/NS-3_notes_02.md) and
[saved phrase learning](TODO/NS-3_notes_03.md) in prerequisite order.
The checkpoint is a maintained native producer that turns recorded WAV
evidence into saved musical events and a substantial Pythian-generated audio
example for the user's listening review. A development preview can be made
earlier with explicit authored or unsupported dimensions; it earns no recorded
learning credit. Keep independent phrase material untouched until policy freeze.
The current development preview exercises the existing saved WAV-derived
pitch/duration model at a bounded 256-span extent, yielding about 30 seconds
of new native synthesis for the user's musical review. It exposes the end-to-end
consumer while register and presence admission remain open; it does not replace
the source-grounded reference packet or the independent phrase gate.
The user's full-clip review found the preview only beginning to sound musical
and stumbling over notes throughout. It is a failed musical checkpoint, so
another longer render or timbre change is not the next remedy; recorded-note
admission remains the governing prerequisite.

After that first musical provider, extend admitted key/clock, parts, harmony,
groove and timbre into the full
[recorded WFC workflow](TODO/NS-4_integration_01.md). The
[beat candidate](TODO/NS-3_tempo_04.md) and
[local-key decision](TODO/NS-3_context_01.md) investigations remain stopped
at their recorded evidence gates; do not restart a variant to fill time.
The three personal style tests and their missing musical reference annotations
remain later acceptance work under [NS-5](#ns-5), not a core prerequisite.
The accepted Pascal [observation](TODO/DONE/NS-3_validation_03.md),
[execution](TODO/DONE/NS-3_validation_02.md), bounded synthesis and WFC
layer controls remain the reusable baseline.

This order changes execution focus, not task acceptance or credit. The current
recorded bottleneck is still real: preferred flute/violin precision is
91.57% / 98.55% against 98%, changing-pattern metrical selection still fails,
and zero genre styles are accepted. The dashboard and linked task evidence
remain the acceptance baseline.

### Checkpoint accounting

Follow TASKFLOW.MD: **goal -> task -> accepted evidence -> DONE move -> percentage
update -> changed blocker -> next outcome**. Discoveries get a new linked task
immediately; return to the current task's scope, or retain it open if the new gap
is a true prerequisite. Completed work leaves the active queue. Keep detailed
experiments in topic evidence and WORK.md rather than accumulating more active
milestone prose. The final delivery audit prevents a bookkeeping total from
substituting for complete results.
