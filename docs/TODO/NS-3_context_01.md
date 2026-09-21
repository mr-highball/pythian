# NS-3_context_01 — Admit local key and tonal uncertainty

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Turn tonal measurements into supported local-key decisions with calibrated admission, explicit unknowns and independently checked changes.

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAVE-CONTEXT-ADMISSION](../WAVE-CONTEXT-ADMISSION.md) · [TONAL](../TONAL.md) · [MUSIC-CONTEXT](../MUSIC-CONTEXT.md).

In progress 2026-09-21: a fixed [development comparison](../TONAL.md#recorded-key-reference-comparison)
applies the unchanged ranking to original microphone chroma and external
string-note duration profiles from two already exposed annotated WAVs. The
native study's WAV observations pass QA. The comparer incorrectly assumed the
second reference was major; it declares D minor. A comparison-only repair binds
the frozen observations and original source separately from the repaired
comparer and passes QA without repeating waveform observations. A major ranks
second from WAV and first from supplied notes; D minor ranks first from both.
The fixed policy therefore selects waveform representation as the next
investigation, without treating a score gap as confidence. Whole-excerpt key conventions remain
distinct from local-key ground truth; no confidence threshold, automatic
admission rule, independent acceptance or completion credit is established.

The [local-key reference screen](../TONAL.md#local-key-reference-candidate)
identifies a published WAV/timed-annotation candidate for the still-missing
change evaluation. The exact archive is acquired and checksum-verified; original
notices and three annotators' files for two HU33 development compositions are
inspected. All performances of those compositions share development exposure.
Annotations disagree and leave gaps, so preserve individual labels and missing
coverage. Decoded geometry and exact timestamp-to-frame reference preparation
now pass; a frozen estimator/uncertainty policy and untouched composition-grouped
evaluation remain prerequisites to acceptance;
the existing whole-excerpt diagnostic remains unchanged.

A private native reference preflight passes checked Win64 QA under
`build/local-key-reference/swd/`. Its fixed policy binds the selected original
WAV/CSV/notice bytes, converts decimal timestamps to nearest original frames
with ties upward, and partitions coverage without filling gaps or choosing a
majority label. Both sources decode as 22,050-Hz mono, with 2,230,272 / 3,053,568
frames and retained original interval counts. The full source partitions into
unlabelled, partial, non-unanimous and unanimous reference coverage with no lost
frames or owned leaks. This prepares references; it does not score key inference.

The [representation follow-up](../TONAL.md#recorded-key-reference-comparison)
has one fixed spectral-peak experiment completed, prompted by the extractor's
coarse low-frequency bin mapping. It preserves the ranker, analysis clock and
original observations. All twelve known-tone controls and silence pass before
the two recorded runs: A major improves from rank 2 to 1, and D minor stays at 1.
Both runs retain all crop/ranking evidence within fixed budgets, with no leaks.
The [timed development comparison](../TONAL.md#timed-development-comparison)
now passes native controls, source/clock/denominator checks and fixed resource
budgets. Exact matching on unanimous labelled frames changes from 46.776% to
66.865% for source 02, but from 47.481% to 35.581% for source 16. The frozen
no-source-regression condition fails despite the improved mean; do not adopt or
retune this candidate. All three annotators, unknown duration, gaps and close
alternatives remain recorded. A stable D-minor example instead ranks its relative
F major, motivating inspection of tonic/mode and temporal evidence before a new
declared hypothesis. No independent key/change acceptance, confidence claim,
maintained algorithm change or credit follows. Other compositions stay untouched.

Diagnostic evidence 2026-09-21: the [native frozen-ranking audit](../TONAL.md#frozen-key-error-audit)
passes controls, reference/category/rank conservation and output preservation
after repairing a truncated JSON field name and exception cleanup. Every
annotator's score reconciles with the prior comparison. Source 16's net exact
loss is confined to fully labelled constant contexts, with a corresponding net
increase in relative-key errors; reference ranks still reach fourteenth.
The subsequent [fixed key-profile comparison](../TONAL.md#fixed-key-profile-comparison)
tests one published major/minor profile pair on frozen chroma before temporal
smoothing. Peak-chroma exact matching falls to 32.016% / 21.142%, failing the
predeclared gate on both sources. Reject this candidate without a profile sweep.
Next inspect changed cell decisions and pitch-class contributions before declaring
a different observation/model; this failure does not isolate its physical cause.
Unknown calibration and independent key/change acceptance remain open; no
maintained admission or completion credit is claimed.

**Acceptance Criteria:**

- Declare supported key/mode cases and source windows, including ambiguous, non-tonal and changing-key regions; fix key/change/coverage limits before evaluation.
- Evaluate ranked tonal evidence and any confidence/calibration claim against annotated development recordings, retaining close alternatives and unsupported modes.
- Freeze and pass independent local-key/change evaluation with unknown coverage and false-admission results; authored scale-degree guides are not recording inference.
- Retain source-frame regions, policy identity and any normalization needed to create musical-time key regions; manual overrides remain distinct and traceable.
- Expose the accepted inference through maintained native context admission without inventing a known key for an unknown region.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
