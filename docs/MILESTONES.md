# North-star goals and active milestones

[Home](../README.md) · [Project](../PROJECT.md) · [Assessment](REBALANCE-2026-09-29.md) ·
[Codebase](CODEBASE-ASSESSMENT.md) · [Tasks](TODO/README.md) · [Work](WORK.md)

## North-star assessment

Updated **2026-09-30** on the user-authorized 2026-09-29 credit basis:
**47.10 outcome-weighted points credited; 52.90 remaining.**
The previous 71.55%, 55.5-baseline and older 89.8% assessments are retired.
At the rebase, implementation did not regress by 26.05 points; the old weights overstated
progress toward the unclosed end-to-end results.

The destination is the standard reusable Pascal audio synthesis library:
dependable fundamentals, trustworthy supported learning from WAV, and
caller-defined styles that generate through granular WFC passes and survive
selective blends and further blends, eventually learned across many hours.
Chillwave, stoner rock and lofi are **internal preferences only**.
“Any style, any user” means generic contracts and explicit support/unknown
limits, not a claim of universal transcription. WFC is integral to the full
composition and synthesis product while the portable core works alone. Actual
ecosystem adoption is unmeasured and is a required completion gate.

### Goal scorecard

| North star | Completion | Weight | Accepted scope | Remaining outcome / goal points |
| --- | ---: | ---: | --- | --- |
| <a id="ns-1"></a>**NS-1 — Independent Pascal foundation** | 100% | 5 | Portable core, extraction/Phanes removal and notices. [Audit](REFERENCE-REMOVAL.md). | Preserve invariants; 0 |
| <a id="fund-contracts"></a><a id="ns-2"></a>**NS-2 — Dependable synthesis fundamentals** | 90% | 25 | Declared synthesis/processing/scheduling families and bounded source, processing and combined listening union. [Map](FUNDAMENTALS.md). | Caller-owned source/effect extension conformance: 1 task / 10 |
| <a id="wav-02"></a><a id="wav-03"></a><a id="ns-3"></a>**NS-3 — Trustworthy musical learning from WAV** | 25% | 25 | Measurement foundation, Pascal observations/execution, qualified references/scoring, unknown/manual context, catalog and admitted-event bridge. | Independently accepted recorded context, notes, parts, harmony, groove and evolving sound: 19 tasks / 75 |
| <a id="wfc-preferences"></a><a id="ns-4"></a>**NS-4 — Granular WFC layers and reusable blends** | 55% | 15 | Actual layers, typed controls, persistence, selective reuse and bounded event/composition evidence. | Caller-defined providers plus full recorded-provider workflow through reusable styles and audio: 2 tasks / 45 |
| <a id="wav-04"></a><a id="ns-5"></a>**NS-5 — User-defined styles that generate and blend usefully** | 14% | 20 | Bounded identity, maintained caller intake, raw corpus, journal, balance, listening packet and acoustic continuation; style-card AC1 only. | Grounded references, semantic scale, structure/continuity, useful one/many-recording and new-user styles, blends: 15 tasks / 86 |
| <a id="wav-05"></a><a id="ns-6"></a>**NS-6 — Independently usable library and delivery** | 23% | 10 | Supported consumer contract, native checkpoint and exact-revision minimal core/caller-provider package. | Full packages, actual outside use, operator workflow, maintained support, ecosystem adoption and final handoff: 8 tasks / 77 |
| **Total** | **47.10 weighted** | **100** | **33 accepted task records plus explicit baseline** | **45 open tasks / 52.90 weighted points** |

Arithmetic:
`5×1 + 25×.90 + 25×.25 + 15×.55 + 20×.14 + 10×.23 = 47.10`.
These are declared scope weights, not measured accuracy, effort, test coverage,
release prediction or market adoption. The
[current basis](REBALANCE-2026-09-29.md#current-credit-basis) explains the
allocation; no credit was earned by writing this plan.

### Acceptance dashboard

| User-visible gate | Current verdict | Closing owner |
| --- | --- | --- |
| Dependable declared synthesis | Built-in scope accepted; external source/effect conformance remains open. | [FUND-QUALITY](#fund-quality), [extension](TODO/NS-2_extension_01.md) |
| Automatic recorded musical learning | Open. Preferred flute precision 91.57% vs required98%; raw support, oracle feasibility and references do not substitute for admitted notes. Beat/key/parts gaps remain. | [NS-3](#ns-3) |
| Modular styles and selective reuse | Built-in mechanisms accepted; caller provider extensions and full recorded-provider audio workflow open. | [providers](TODO/NS-4_providers_01.md), [integration](TODO/NS-4_integration_01.md) |
| Useful style from one recording | No accepted inferred-event style result yet. | [style_01](TODO/NS-5_style_01.md) |
| Many-hour learning with sustained musical benefit | No accepted full musical style. Accepted 2.322-hour raw workload is not semantic training. | [scale](#corpus-scale), [style_02](TODO/NS-5_style_02.md) |
| New caller and further cross-style reuse | No accepted new-caller full style or three-parent musical blend result. | [style_03](TODO/NS-5_style_03.md), [blends](TODO/NS-5_blends_01.md) |
| Outside consumer can use current package | Historical isolated native checkpoint accepted; actual independent minimal/full use remains open. | [NS-6](#ns-6) |
| Maintained library and de facto standard | Supported release lifecycle and external adoption evidence remain open; a project-count floor alone proves no standard claim. | [support](TODO/NS-6_support_01.md), [adoption](TODO/NS-6_adoption_01.md) |

### Scope reconciliation

One primary task owner earns each credit. Shared providers and aggregate
outcomes do not add credit again. NS-3 owns inference accuracy; NS-4 composition
and integration; NS-5 corpus/style quality and scale; NS-6 usability/delivery.
Source-free composition remains accepted evidence with zero extra NS-4 credit.

## Active backlog

Task files own requirements and blockers; the following is a navigation map,
not a second acceptance definition. “DONE” is an accepted scoped result, never
a claim that all downstream outcomes pass.

| Outcome | North star | Required task owners |
| --- | --- | --- |
| <a id="fund-quality"></a>**FUND-QUALITY** | NS-2 | [NS-2_synthesis-quality_01 — DONE](TODO/DONE/NS-2_synthesis-quality_01.md), [NS-2_synthesis-quality_02 — DONE](TODO/DONE/NS-2_synthesis-quality_02.md), [NS-2_synthesis-quality_03 — DONE](TODO/DONE/NS-2_synthesis-quality_03.md) |
| <a id="fund-extension"></a>**FUND-EXTENSION** | NS-2 | [NS-2_extension_01](TODO/NS-2_extension_01.md) |
| <a id="wav-validation"></a>**WAV-VALIDATION** | NS-3 | [NS-3_validation_01 — DONE](TODO/DONE/NS-3_validation_01.md), [NS-3_validation_02 — DONE](TODO/DONE/NS-3_validation_02.md), [NS-3_validation_03 — DONE](TODO/DONE/NS-3_validation_03.md) |
| <a id="wav-02-pulse"></a>**WAV-02-PULSE** | NS-3 | [NS-3_tempo_04](TODO/NS-3_tempo_04.md), [NS-3_tempo_01](TODO/NS-3_tempo_01.md), [NS-3_tempo_02](TODO/NS-3_tempo_02.md), [NS-3_tempo_03](TODO/NS-3_tempo_03.md) |
| <a id="wav-02-context"></a>**WAV-02-CONTEXT** | NS-3 | [NS-3_context_01](TODO/NS-3_context_01.md), [NS-3_context_02](TODO/NS-3_context_02.md) |
| <a id="wav-03-register"></a>**WAV-03-REGISTER** | NS-3 | [NS-3_notes_01](TODO/NS-3_notes_01.md) |
| <a id="wav-03-labeling"></a>**WAV-03-LABELING** | NS-3 | [NS-3_labeling_01 — DONE](TODO/DONE/NS-3_labeling_01.md) |
| <a id="wav-03-boundaries"></a>**WAV-03-BOUNDARIES** | NS-3 | [NS-3_notes_05](TODO/NS-3_notes_05.md), [NS-3_notes_02](TODO/NS-3_notes_02.md) |
| <a id="wav-03-phrases"></a>**WAV-03-PHRASES** | NS-3 | [NS-3_notes_03](TODO/NS-3_notes_03.md) |
| <a id="wav-03-parts"></a>**WAV-03-PARTS** | NS-3 | [NS-3_parts_02](TODO/NS-3_parts_02.md), [NS-3_parts_05](TODO/NS-3_parts_05.md), [NS-3_parts_03](TODO/NS-3_parts_03.md) |
| <a id="wav-02-harmony"></a>**WAV-02-HARMONY** | NS-3 | [NS-3_harmony_01](TODO/NS-3_harmony_01.md), [NS-3_harmony_02](TODO/NS-3_harmony_02.md) |
| <a id="wav-02-groove"></a>**WAV-02-GROOVE** | NS-3 | [NS-3_groove_01](TODO/NS-3_groove_01.md), [NS-3_groove_02](TODO/NS-3_groove_02.md) |
| <a id="wav-03-timbre"></a>**WAV-03-TIMBRE** | NS-3 | [NS-3_timbre_01](TODO/NS-3_timbre_01.md), [NS-3_timbre_02](TODO/NS-3_timbre_02.md) |
| <a id="wfc-layers"></a>**WFC-LAYERS** | NS-4 | [NS-4_layers_01 — DONE](TODO/DONE/NS-4_layers_01.md), [NS-4_layers_02 — DONE](TODO/DONE/NS-4_layers_02.md), [NS-4_layers_03 — DONE](TODO/DONE/NS-4_layers_03.md), [NS-4_layers_04 — DONE](TODO/DONE/NS-4_layers_04.md) |
| <a id="wfc-style"></a>**WFC-STYLE** | NS-4 | [NS-4_styles_01 — DONE](TODO/DONE/NS-4_styles_01.md), [NS-4_styles_02 — DONE](TODO/DONE/NS-4_styles_02.md) |
| <a id="wfc-extension"></a>**WFC-EXTENSION** | NS-4 | [NS-4_providers_01](TODO/NS-4_providers_01.md) |
| <a id="wav-04-integration"></a>**WAV-04-INTEGRATION** | NS-4 | [NS-4_integration_01](TODO/NS-4_integration_01.md) |
| <a id="corpus-setup"></a>**CORPUS-SETUP** | NS-5 | [Accepted NS-5_corpus_05](TODO/DONE/NS-5_corpus_05.md), [NS-5_corpus_06](TODO/NS-5_corpus_06.md), [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md), [NS-5_evaluation_04](TODO/NS-5_evaluation_04.md) |
| <a id="wav-04-vocabulary"></a>**WAV-04-VOCABULARY** | NS-5 | [NS-5_vocabulary_01](TODO/NS-5_vocabulary_01.md), [NS-5_vocabulary_02](TODO/NS-5_vocabulary_02.md) |
| <a id="corpus-scale"></a>**CORPUS-SCALE** | NS-5 | [NS-5_scale_01](TODO/NS-5_scale_01.md), [NS-5_scale_02](TODO/NS-5_scale_02.md) |
| <a id="wav-04-continuity"></a>**WAV-04-CONTINUITY** | NS-5 | [NS-5_continuity_01](TODO/NS-5_continuity_01.md) |
| <a id="song-structure"></a>**SONG-STRUCTURE** | NS-5 | [NS-5_structure_01](TODO/NS-5_structure_01.md), [NS-5_structure_02](TODO/NS-5_structure_02.md) |
| <a id="style-eval"></a>**STYLE-EVAL** | NS-5 | [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md), [NS-5_evaluation_04](TODO/NS-5_evaluation_04.md), [NS-5_evaluation_02](TODO/NS-5_evaluation_02.md), [NS-5_style_01](TODO/NS-5_style_01.md), [NS-5_style_02](TODO/NS-5_style_02.md), [NS-5_style_03](TODO/NS-5_style_03.md), [NS-5_blends_01](TODO/NS-5_blends_01.md) |
| <a id="wav-05-authoring"></a>**WAV-05-AUTHORING** | NS-6 | [NS-6_authoring_01](TODO/NS-6_authoring_01.md), [NS-6_authoring_02](TODO/NS-6_authoring_02.md) |
| <a id="wav-05-delivery"></a>**WAV-05-DELIVERY** | NS-6 | [NS-6_delivery_06](TODO/DONE/NS-6_delivery_06.md), [NS-6_delivery_03](TODO/NS-6_delivery_03.md) |
| <a id="delivery-release"></a>**DELIVERY-RELEASE** | NS-6 | [NS-6_delivery_07](TODO/NS-6_delivery_07.md), [NS-6_delivery_04](TODO/NS-6_delivery_04.md), [NS-6_delivery_05](TODO/NS-6_delivery_05.md) |
| <a id="delivery-support"></a>**DELIVERY-SUPPORT** | NS-6 | [NS-6_support_01](TODO/NS-6_support_01.md) |
| <a id="delivery-adoption"></a>**DELIVERY-ADOPTION** | NS-6 | [NS-6_adoption_01](TODO/NS-6_adoption_01.md) |

<a id="immediate-acceptance-result"></a>
<a id="wav-04-continuation"></a>
<a id="wav-04-boundaries"></a>

## Completion accounting

The new baseline is NS-1..6 **100/70/10/20/0/0**; current accepted task points
are **0/20/15/35/14/23**. Baseline contributes 28.00 weighted points and DONE
contributes 19.10. The [open](TODO/README.md) and [DONE](TODO/DONE/README.md)
ledgers exhaustively map the 78 current tickets. Baseline + DONE + open equals
100 within each goal. Historical figures are retained only as dated evidence,
not current allocation rules.

### Credit ledger

Current credits live in the first Completion credit field of each task and
the two ledgers. The user-authorized rebase changes planning weights; it does
not erase failed experiments or change whether a recorded result passed.
Future acceptance updates task move, links, both ledgers, scorecard and WORK
in the same change. Scope changes get an explicit new rationale.

### Operator-authored recorded-label workbench

The native catalog is accepted separately. [Editor/queue](TODO/NS-6_authoring_01.md)
and [physical LAN/final use](TODO/NS-6_authoring_02.md) retain every original
criterion under distinct owners. Current allocation 8+8 NS-6; older 4-point
splits are historical. Physical phone Save remains an actual review gate.

### NS-5 admitted-pitch balance task split

The [accepted token balance](TODO/DONE/NS-5_vocabulary_03.md) retains one NS-5
point. [Full vocabulary](TODO/NS-5_vocabulary_01.md) now owns six; bounded mass
balance never closes broad vocabulary coverage/diversity.

### Mixture preparation task split

[Reference preparation](TODO/DONE/NS-3_parts_01.md) and
[measurement controls](TODO/DONE/NS-3_parts_04.md) remain accepted one-point
NS-3 results. Recorded event recovery, stable ownership and independent
mixture accuracy stay in parts_02/05/03; source packaging cannot substitute.

### Note-presence reference split

The [accepted reference](TODO/DONE/NS-3_notes_04.md) retains one point.
[Presence](TODO/NS-3_notes_05.md) and [events](TODO/NS-3_notes_02.md) now own
three and five respectively. Quiet-tail/rest and recorded boundary gates
remain open; metadata does not prove audible sound.

## Execution order and blocking links

Start at **NS-5 (14%)**, follow real prerequisites and return to that outcome.
The [delivery order](REBALANCE-2026-09-29.md#delivery-order) owns the current
selection sequence. Final harmonic/groove consumers require independent
acceptance tasks harmony_02/groove_02, not merely their development providers.
Notes_02 requires accepted identity and presence; parts_03 follows stable
role ownership. The graph has no intentionally circular acceptance edges.

## Direction for the next work package

Generic user corpus intake is accepted; the executable style-card contract
closes AC1 only, with independent reference/calibration still open. The first learned-style path needs
actual accepted note inference. Current register, presence, timing and key
investigations have explicit stopped/evidence-blocked states; do not restart
nearby variants. The current minimal package is accepted; an actual outside
consumer is still needed. Its prepared packet and caller extension conformance
are useful next work when the learning path is blocked.

### Next work to schedule

- Ticket Guy Neo: [independent minimal use](TODO/NS-6_delivery_07.md), with a
  concrete [reviewer packet](MINIMAL-CONSUMER-HANDOFF.md) and actual reviewer
  availability still required; coordinate the next bounded library component.
- Ticket Guy: [caller source/effect extension](TODO/NS-2_extension_01.md)
  conformance/example/guide preparation with exclusive files before edits;
  independent consumer/listening acceptance remains unearned. Big Boss retains
  architecture, priorities and final judgment, including the larger custom
  provider design. New evidence is required before blocked inference restarts.
- Salty Boi: final QA after at least two tasks/components are ready, under the
  [current team and publication rules](TASKFLOW.MD#delegated-validation-and-publication).

### Checkpoint accounting

Before each batch record criterion, deliverable, closing evidence and stop
condition. After two consecutive nonclosing batches reassess the action,
retaining counts across handoffs and renamed experiments. Scientific rejection
and implementation QA failure are distinct. Split distinct required gaps into
owned tasks without silently growing the current ticket or relaxing its gate.
