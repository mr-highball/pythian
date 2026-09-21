# North-star goals and active milestones

[Home](../README.md) · [Project scope](../PROJECT.md) ·
[Work record](WORK.md) · [Style architecture](LAYERED-STYLE.md)

## North-star assessment

**Updated 2026-09-20: approximately 56% engineering completion; no accepted
genre style yet.** The destination is an independent Pascal synthesis library
that learns useful musical behavior from many hours of WAV recordings, generates
through independently controllable WFC passes, and saves styles that remain
usable through selective blends and further blends. Required initial styles:
**chillwave, stoner rock and lofi**. Core fundamentals retain priority.

The old **89.8% is retired**. The accepted planning baseline remains **55.5
weighted points**. The new [49-task catalog](TODO/README.md) allocates every
remaining point to explicit acceptance criteria and prerequisites. Accepted
corpus identity adds **0.4 points**, bringing current completion to **55.9**.
Subsequent accepted tasks update their north-star and overall percentages individually.

### Goal scorecard

Completion is a coarse scope judgment, not measured test coverage, effort spent,
a release forecast or ecosystem adoption. Weights total 100; remaining points
are the scope still assigned to each goal. Completed work is condensed here,
with detailed history in the linked evidence rather than active tasks.

| North star | Completion | Weight | Completed capability credited / evidence | Remaining outcome | Overall points left |
| --- | ---: | ---: | --- | --- | ---: |
| <a id="ns-1"></a>**NS-1 — Independent Pascal foundation** | **100%** | 10 | Independent owned core; agreed WFC/Phanes extraction, Phanes removal and complete provenance. [Audit](REFERENCE-REMOVAL.md). | No open extraction work. Preserve independence and notices. Delivery is NS-6. | **0** |
| <a id="fund-contracts"></a><a id="ns-2"></a>**NS-2 — Dependable synthesis fundamentals** | **80%** | 25 | Supported synthesis, samples, modulation, effects, buses, timing and streaming; reviewed contracts and numerical/replay evidence. [Capability map](FUNDAMENTALS.md#contract-review). | Accept the supported suite audibly and resolve demonstrated defects: **FUND-QUALITY**. | **5** |
| <a id="wav-02"></a><a id="wav-03"></a><a id="ns-3"></a>**NS-3 — Trustworthy musical learning from WAV** | **30%** | 25 | Source-bound measurements, selected-pulse clock reconstruction, explicit uncertainty/manual context, narrow pitch/duration learning and reusable event queries. [Phrase evidence](PHRASE-EVALUATION.md), [pulse evidence](BEAT-TRACKING.md). | Independently validated context, notes, mixed parts, harmony, groove and evolving sound: **17 tasks across 10 WAV outcomes**. | **17.5** |
| <a id="wfc-preferences"></a><a id="ns-4"></a>**NS-4 — Granular WFC layers and reusable blends** | **70%** | 15 | Actual dependent passes, locks/preferences, selective regeneration, owned timing APIs, weighted saved blends and lineage. [Layers](LAYERS.md), [grid](GRID-STYLE.md), [performance](PERFORMANCE.md). | Semantic role controls, saved joint providers and integrated audible generation/reblend: **WFC-LAYERS, WFC-STYLE, WAV-04-INTEGRATION**. | **4.5** |
| <a id="wav-04"></a><a id="ns-5"></a>**NS-5 — Many-hour styles that generate and blend usefully** | **27%** | 20 | Ingestion, journals, acoustic vocabulary and mechanical reuse; accepted two-recording identity pilot with derivative/exposure and inherited-palette audits. [Pilot](CORPUS-EVALUATION.md#verified-identity-pilot). | Representative genre corpora, practical scale, sustained structure and acceptance of all three styles and cross-style blends: **16 tasks / 6 corpus outcomes**. | **14.6** |
| <a id="wav-05"></a><a id="ns-6"></a>**NS-6 — Independently usable library and delivery** | **50%** | 5 | Current standalone packages/examples, fresh source snapshot and scoped native consumer/compiler checks. [Delivery](PACKAGING.md#current-api-delivery). | Remaining target/CI and accepted-workflow delivery, plus independently reproduced use: **WAV-05-DELIVERY, DELIVERY-RELEASE**. | **2.5** |
| **Total** | **≈56%** | **100** | **55.9 weighted points credited** | **48 open tasks / 22 outcomes** | **44.1** |

Arithmetic: `10×1.00 + 25×0.80 + 25×0.30 + 15×0.70 + 20×0.27 + 5×0.50 = 55.9`.
The decimal is bookkeeping, not measurement precision. NS-3 earns measurement
accuracy; NS-4 earns composition/reuse; NS-5 earns corpus/style quality; NS-6
earns delivery. Consuming an earlier result earns no duplicate provider credit.

### Acceptance dashboard

| Required result | Current evidence and assessment | Owner |
| --- | --- | --- |
| Supported synthesis sounds acceptable | Signal/replay checks and combined renders exist. A [30-second paired preview](SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20) is supplied for feedback. Listening remains **unassessed**. | [FUND-QUALITY](#fund-quality) |
| Base key/BPM can be learned reliably | Maintained timing queries retain alternatives, uncertainty and saved WFC context. The [joint candidate comparison](BEAT-TRACKING.md#model-candidate-comparison) reaches **.9863 polyrhythm F1 without supplied rate/band hints** and 1.0 on deception, but fails changing/authored controls. Perfect provider agreement can select the wrong beat level. Automatic metrical admission, independent local-key admission and useful observed coverage remain open. | [Pulse](#wav-02-pulse), [context](#wav-02-context) |
| Recorded notes are reliable enough for learning | Preferred development precision **91.57% flute / 98.55% violin**, required **98%**. Violin passes all four development gates; flute fails precision. Larger-model and coherent-observation comparisons have not resolved the recorded gap. Address presence/rest and register together before freezing independent phrase evaluation. [Evidence and rejected approaches](PHRASE-EVALUATION.md). | [Register](#wav-03-register), [boundaries](#wav-03-boundaries), [phrases](#wav-03-phrases), [validation](#wav-validation) |
| Musical layers and learned relationships survive generation/reblend | Mechanical WFC controls and saved reuse work. General recorded bass/voice/harmony providers and their integrated acceptance remain unfinished. | [NS-3](#ns-3), [NS-4](#ns-4) |
| Many hours produce a useful style | **Chillwave: unaccepted. Stoner rock: unaccepted. Lofi: unaccepted.** Duration, caller labels and source-fragment resemblance do not establish learning quality. | [NS-5](#ns-5) |
| Another consumer can use the current result | Current core/WFC ZIPs pass extracted consumer checks, including saved-grid edits and exact audio replay. Linux/remote CI and independent-use acceptance remain unverified. | [NS-6](#ns-6) |

**Musical learning and corpus quality account for 32.1 of the remaining 44.1
points (about 73%).** Additional diagnostics and mechanical adapters have value
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

**48 open task files own the remaining work across 22 outcomes; 1 task is DONE.**
See the [task catalog](TODO/README.md) for credits and a prerequisite-first order,
and [TASKFLOW.MD](TASKFLOW.MD) for the required template, gap handling, DONE moves
and completion accounting. [Corpus identity](TODO/DONE/NS-5_corpus_01.md) is accepted.
Execution started from the least-complete north star, **NS-5 (25% -> 27%)**,
and follows prerequisites: corpus coverage -> style cards ->
[shared validation](TODO/NS-3_validation_01.md), now the current task. The interrupted provider extension
remains unvalidated and belongs to its separate semantic-layer task.

The tables below retain existing outcome anchors for topic links. They are
navigation to the task files, not duplicate acceptance criteria. An outcome is
closed only when all mapped tasks are accepted, including shared prerequisites.
A mapped task's credit is counted once even if it supports more than one outcome.

| Outcome | North star | Required task files |
| --- | --- | --- |
| <a id="fund-quality"></a>**FUND-QUALITY** | NS-2 | [NS-2_synthesis-quality_01](TODO/NS-2_synthesis-quality_01.md), [NS-2_synthesis-quality_02](TODO/NS-2_synthesis-quality_02.md), [NS-2_synthesis-quality_03](TODO/NS-2_synthesis-quality_03.md) |
| <a id="wav-validation"></a>**WAV-VALIDATION** | NS-3 | [NS-3_validation_01](TODO/NS-3_validation_01.md), [NS-3_validation_02](TODO/NS-3_validation_02.md) |
| <a id="wav-02-pulse"></a>**WAV-02-PULSE** | NS-3 | [NS-3_tempo_01](TODO/NS-3_tempo_01.md), [NS-3_tempo_02](TODO/NS-3_tempo_02.md), [NS-3_tempo_03](TODO/NS-3_tempo_03.md) |
| <a id="wav-02-context"></a>**WAV-02-CONTEXT** | NS-3 | [NS-3_context_01](TODO/NS-3_context_01.md), [NS-3_context_02](TODO/NS-3_context_02.md) |
| <a id="wav-03-register"></a>**WAV-03-REGISTER** | NS-3 | [NS-3_notes_01](TODO/NS-3_notes_01.md) |
| <a id="wav-03-boundaries"></a>**WAV-03-BOUNDARIES** | NS-3 | [NS-3_notes_02](TODO/NS-3_notes_02.md) |
| <a id="immediate-acceptance-result"></a><a id="wav-03-phrases"></a>**WAV-03-PHRASES** | NS-3 | [NS-3_notes_03](TODO/NS-3_notes_03.md) |
| <a id="wav-03-parts"></a>**WAV-03-PARTS** | NS-3 | [NS-3_parts_01](TODO/NS-3_parts_01.md), [NS-3_parts_02](TODO/NS-3_parts_02.md), [NS-3_parts_03](TODO/NS-3_parts_03.md) |
| <a id="wav-02-harmony"></a>**WAV-02-HARMONY** | NS-3 | [NS-3_harmony_01](TODO/NS-3_harmony_01.md) |
| <a id="wav-02-groove"></a>**WAV-02-GROOVE** | NS-3 | [NS-3_groove_01](TODO/NS-3_groove_01.md) |
| <a id="wav-03-timbre"></a>**WAV-03-TIMBRE** | NS-3 | [NS-3_timbre_01](TODO/NS-3_timbre_01.md), [NS-3_timbre_02](TODO/NS-3_timbre_02.md) |
| <a id="wfc-layers"></a>**WFC-LAYERS** | NS-4 | [NS-4_layers_01](TODO/NS-4_layers_01.md), [NS-4_layers_02](TODO/NS-4_layers_02.md), [NS-4_layers_03](TODO/NS-4_layers_03.md), [NS-4_layers_04](TODO/NS-4_layers_04.md) |
| <a id="wfc-style"></a>**WFC-STYLE** | NS-4 | [NS-4_styles_01](TODO/NS-4_styles_01.md), [NS-4_styles_02](TODO/NS-4_styles_02.md) |
| <a id="wav-04-integration"></a>**WAV-04-INTEGRATION** | NS-4 | [NS-4_integration_01](TODO/NS-4_integration_01.md) |
| <a id="corpus-setup"></a>**CORPUS-SETUP** | NS-5 | [NS-5_corpus_02](TODO/NS-5_corpus_02.md), [NS-5_corpus_03](TODO/NS-5_corpus_03.md), [NS-5_corpus_04](TODO/NS-5_corpus_04.md), [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md); accepted prerequisite: [NS-5_corpus_01 — DONE](TODO/DONE/NS-5_corpus_01.md) |
| <a id="wav-04-vocabulary"></a>**WAV-04-VOCABULARY** | NS-5 | [NS-5_vocabulary_01](TODO/NS-5_vocabulary_01.md), [NS-5_vocabulary_02](TODO/NS-5_vocabulary_02.md) |
| <a id="corpus-scale"></a>**CORPUS-SCALE** | NS-5 | [NS-5_scale_01](TODO/NS-5_scale_01.md), [NS-5_scale_02](TODO/NS-5_scale_02.md) |
| <a id="wav-04-continuation"></a><a id="wav-04-boundaries"></a><a id="wav-04-continuity"></a>**WAV-04-CONTINUITY** | NS-5 | [NS-5_continuity_01](TODO/NS-5_continuity_01.md) |
| <a id="song-structure"></a>**SONG-STRUCTURE** | NS-5 | [NS-5_structure_01](TODO/NS-5_structure_01.md), [NS-5_structure_02](TODO/NS-5_structure_02.md) |
| <a id="style-eval"></a>**STYLE-EVAL** | NS-5 | [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md), [NS-5_evaluation_02](TODO/NS-5_evaluation_02.md), [NS-5_chillwave_01](TODO/NS-5_chillwave_01.md), [NS-5_stoner-rock_01](TODO/NS-5_stoner-rock_01.md), [NS-5_lofi_01](TODO/NS-5_lofi_01.md), [NS-5_blends_01](TODO/NS-5_blends_01.md) |
| <a id="wav-05-delivery"></a>**WAV-05-DELIVERY** | NS-6 | [NS-6_delivery_02](TODO/NS-6_delivery_02.md), [NS-6_delivery_03](TODO/NS-6_delivery_03.md) |
| <a id="delivery-release"></a>**DELIVERY-RELEASE** | NS-6 | [NS-6_delivery_01](TODO/NS-6_delivery_01.md), [NS-6_delivery_04](TODO/NS-6_delivery_04.md), [NS-6_delivery_05](TODO/NS-6_delivery_05.md) |

## Completion accounting

The task ledger subdivides the **existing remaining scope**, without increasing
the accepted baseline or claiming that planning itself advances completion.

| Goal | Baseline | Accepted task credit | Current | Open task credit | Open tasks |
| --- | ---: | ---: | ---: | ---: | ---: |
| NS-1 | 100% | 0 | 100% | 0 | 0 |
| NS-2 | 80% | 0 | 80% | 20 | 3 |
| NS-3 | 30% | 0 | 30% | 70 | 17 |
| NS-4 | 70% | 0 | 70% | 30 | 7 |
| NS-5 | 25% | 2 | 27% | 73 | 16 |
| NS-6 | 50% | 0 | 50% | 50 | 5 |

Each completed task adds its declared **goal percentage points** to that goal;
multiply by the goal weight / 100 for overall movement. The
[TASKFLOW formula](TASKFLOW.MD#complete-move-and-update-percentages) governs
reopened tasks and new/split scope. Move an accepted task to DONE and update
these totals, the scorecard and the task index in the same logical change.
Evidence must support the actual task criteria; no partial or test-count credit.

For example, accepted `NS-3_notes_01` moves NS-3 from 30% to 34% and overall
completion from 55.9% to 56.9%, assuming no other changes. This makes bounded
outcome progress visible without waiting for all WAV learning to finish.
The remaining open task credits add **44.1 overall points**, reaching 100 only
when the required work and final scope audit are accepted.

## Execution order and blocking links

1. Establish shared admission/scoring contracts; resolve pitch identity and
   presence together, then freeze independent phrase acceptance. Timing follows
   stable pulse -> changing clock/meter -> independent acceptance; key admission
   joins accepted timing in the reusable context task.
2. Accept supported roles from attributed stems and mixtures, then harmonic,
   groove and evolving sound behavior. Synthesis listening proceeds independently
   until its required verdicts and demonstrated fixes are complete.
3. Extend semantic WFC controls, compatibility, saved providers and repeated
   blending, then integrate the accepted WAV providers through native audio.
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
outcome packages, each above the requested ten-point minimum:

| Package | Accepted result and included work | Conditional overall gain |
| --- | --- | ---: |
| **A — Dependable sound and trustworthy recorded musical inputs** | All NS-2 quality tasks (+5); NS-3 validation, tempo, context and notes tasks (+9.5). Actual listening and independent native note/context admission. | **+14.5** |
| **B — Recorded parts through reusable semantic generation** | NS-3 parts, harmony, groove and timbre (+8); all NS-4 controls, persistence, blend/reblend and audible integration (+4.5). | **+12.5** |
| **C — Accepted many-hour styles and independent delivery** | Remaining NS-5 corpus, vocabulary, scale, continuity, structure and three-style/cross-style acceptance (+14.6); all NS-6 delivery and independent use (+2.5). Corpus identity already earned +0.4. | **+17.1 remaining** |

**55.9 current + 14.5 + 12.5 + 17.1 = 100.**
These are scope allocations, not time estimates or promises of success. Record
task credit as each accepted task finishes; preparation from later packages can
be useful sooner when the selected outcome requires it.

### First work to schedule

The user's execution direction supersedes package A as the starting priority:
start with NS-5 and follow its actual prerequisite links. The shared
[admission/scoring task](TODO/NS-3_validation_01.md) can establish the bounded
inference decision; [source quality](TODO/NS-2_synthesis-quality_01.md) and
[processing quality](TODO/NS-2_synthesis-quality_02.md) have existing auditions.
Use [accepted corpus identity](TODO/DONE/NS-5_corpus_01.md) as the preparation
baseline. Do not resume the interrupted voice extension
merely because it is underway; its scope now belongs to
[the semantic-role task](TODO/NS-4_layers_01.md).

The main measured bottleneck remains recorded note/context admission: preferred
flute/violin precision is 91.57% / 98.55% against 98%, and automatic metrical
selection still has changing-pattern failures. Zero genre styles are accepted.
The acceptance dashboard above and linked topic evidence remain the baseline.

### Checkpoint accounting

Follow TASKFLOW.MD: **goal -> task -> accepted evidence -> DONE move -> percentage
update -> changed blocker -> next outcome**. Discoveries get a new linked task
immediately; return to the current task's scope, or retain it open if the new gap
is a true prerequisite. Completed work leaves the active queue. Keep detailed
experiments in topic evidence and WORK.md rather than accumulating more active
milestone prose. The final delivery audit prevents a bookkeeping total from
substituting for complete results.
