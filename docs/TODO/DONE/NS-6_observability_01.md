# NS-6_observability_01 — Long-operation observability audit and shared callbacks

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

Accepted 2026-10-03 by Big Boss under the user's solo-review direction. All four
criteria pass at the scope below. Evidence: `build/observability/QA-VERDICT.md`.
Zero additional credit; remaining bulk gaps are separately owned in the
[audit](../../OBSERVABILITY.md).

**Description:**

Audit owned core, adapters and tools for long-running work without observable
progress or cancellation. Extend the primary implementations and connect the
operator-facing paths, reusing existing streaming/checkpoint contracts.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional
points. This improves usability and callable observability of existing outcomes.

Selected batch: Big Boss solo. Deliverable: documented coverage inventory,
portable callback contract and connected analysis/pitch/effects progress.
Closing evidence: callback cancellation/output parity and actual browser checks.
Stop on DSP/output changes, swallowed cancellation, fake percentages, or expansion
into unrelated algorithm work; distinct remaining gaps get explicit linked tasks.

**Acceptance Criteria:**

- AC1: Record coverage across core, adapters and maintained tools, distinguishing
  existing bounded pull/checkpoint interfaces from silent bulk operations.
- AC2: Extend shared bulk hashing, analysis, resampling and pitch operations with
  optional callbacks and documented units, exception/cancellation semantics.
  Hosts own presentation, scheduling and throttling; portable code owns no clocks
  or browser dependencies.
- AC3: Connect relevant Studio effect, capture/inspection and pitch work to
  measured job progress and common friendly labels. Existing inference/library
  monitoring stays usable, with any unaddressed gaps explicitly owned.
- AC4: Verify unchanged output, callback abort cleanup and meaningful intermediate
  progress; validate matched native/browser artifacts, document audit limits and
  preserve operator data during deployment.

**Blockers**

- [Learning progress foundation](NS-6_studio_20.md).

**Dev Notes:**

- 2026-10-03, Big Boss: user extends the lesson to all potentially long work.
  Initial scan finds reusable library/import and inference monitoring, bounded
  streaming interfaces, and silent pitch/effects plus bulk DSP calls. This task
  owns the broader audit; studio_20 remains bounded to the learning workflow.
- AC1: static inventory of 262 owned Pascal files and manual bulk-call-chain
  review distinguishes instrumented, bounded streaming and still-silent work.
  [Catalog import](../NS-6_observability_02.md),
  [offline render/separation](../NS-6_observability_03.md) and
  [retained corpus/style work](../NS-6_observability_04.md) remain required.
- AC2: `pythian.progress` supplies optional shared records with actual units and
  pass counts. Hash, analysis, resample, pitch, onset/beat, palette and corpus
  consumers forward the same callback; raise-to-abort retains resource cleanup.
  Hosts own throttling, scheduling and terminal publication. No new DSP algorithm.
- AC3: native worker, source inspection, effects, capture and pitch paths expose
  measured stages through the common Studio component. Existing library and
  inference contracts remain. Nested import and note-render phases honestly stay
  indeterminate pending their linked owners. Repaired cancelled effects jobs
  incorrectly continuing to display “Stopping…”.
- AC4: 385 callback/parity/abort checks, known-answer hashes, WAV analysis,
  corpus/archive reconstruction, weighted journal/WFC parity, 164 real worker,
  130 effects and 53 capture checks pass. Browser source inspection shows 0→66%
  measured bytes then analysis; effects complete/cancel and pitch preview complete.
  Short pitch stages finish between UI polls, so no intermediate browser-pitch
  claim. Phone/desktop widths have no horizontal overflow or console errors.
- Full analysis under pas2js exposed an older `SizeOf` portability failure.
  [portability_01](../NS-6_portability_01.md) owns primary-code repair. Actual
  pas2js/Node callback-record checks pass for large counters and exceptions;
  this does not establish full browser-side analysis or WASM execution.
- Fourteen frozen native/browser assets match stable delivery; all 3,957 existing
  operator JSON/JSONL hashes are preserved. Owned tabs and QA service closed,
  no QA worker/audio remains. Nonclosing count: 0. No musical quality credit.
