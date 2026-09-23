# NS-3_context_01 — Admit local key and tonal uncertainty

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Turn tonal measurements into supported local-key decisions with calibrated admission, explicit unknowns and independently checked changes.

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Completion credit: 3 goal percentage points (0.75 overall points), after
assigning 1 of its original 4 unearned points to the independent
[reference packet](DONE/NS-3_context_03.md).
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

The [decision/contribution audit](../TONAL.md#rejected-profile-decision-audit)
now exactly replays every correlation score and reconciles lost/gained frames.
Both sources lose previously correct predictions in fully labelled constant
contexts; substantial losses are fifth-related or more distant, not only relative
mode confusions. Stop profile variations. Define evidence distinguishing tonic
from sustained dominant and actual note activity from folded spectral contributions
before another inference proposal. Preserve frequency provenance and temporal
order; this audit alone selects no physical explanation or replacement classifier.

The subsequent [harmonic-dictionary feasibility study](../TONAL.md#harmonic-dictionary-feasibility)
tests joint spectral decomposition before pitch-class folding. Corrected numerical
QA passes, but 31/72 synthetic cases fail the frozen preservation gates, including
false class mass from pure tones and an octave error with a missing fundamental.
Stop this fixed-shape representation before recorded execution. The next observation
contract must distinguish spectral-envelope variation from genuinely simultaneous
notes; fitting extra pitches to explain timbre does not satisfy key admission.
Temporal tonic evidence and independent key/change evaluation remain required.

Focused current-checkout QA 2026-09-23 closes **criterion 4** for source-frame
regions, musical-time mapping and manual-selection provenance. The
[source-bound replay](../WAVE-CONTEXT-ADMISSION.md#source-bound-manual-region-replay--2026-09-23)
passes stable FPC 3.2.2 Win32 core and saved-profile checks. A deliberately
selected rank-18 key remains explicitly caller-selected in the JSON and
report-bound profile after reload; it is not presented as automatic inference.
At that checkpoint, criteria 1, 2, 3 and 5 remained open, including calibrated
uncertainty and independent recorded accuracy. This partial criterion earns no
task credit.

Prospective policy batch 2026-09-23: the [source-window and admission-gate
policy](../TONAL.md#prospective-local-key-admission-gates--2026-09-23) fixes
whole-recording development/evaluation groups, both reviewed acoustic no-key
windows, supported major/minor and excluded modes, groupwise key coverage,
precision, conflict/no-key abstention, agreed-change and false-transition
limits before independent candidate inference. The maintained Pascal scorer
now reports admitted supported frames and spurious known-key transitions from
continuous same-key reference interiors under `swd-localkey-score-2`. This is
policy and denominator plumbing, not a trained estimator or accuracy result.
Focused QA passed the frozen policy, checked Win32/Win64 controls, and byte
replay of the all-unknown D911-02 development control. Criterion 1 is met;
criteria 2, 3 and 5 remain open. No inference accuracy or completion credit
is claimed.

**Acceptance Criteria:**

- Using the qualified reference packet, declare supported key/mode cases and source windows, including ambiguous, non-tonal and changing-key regions; fix key/change/coverage limits before evaluation.
- Evaluate ranked tonal evidence and any confidence/calibration claim against annotated development recordings, retaining close alternatives and unsupported modes.
- Freeze and pass independent local-key/change evaluation with unknown coverage and false-admission results; authored scale-degree guides are not recording inference.
- Retain source-frame regions, policy identity and any normalization needed to create musical-time key regions; manual overrides remain distinct and traceable.
- Expose the accepted inference through maintained native context admission without inventing a known key for an unknown region.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
- [NS-3_context_03.md](DONE/NS-3_context_03.md)

**Dev Notes:**

- 2026-09-23 frozen note-aware candidate stopped: the ignored Pascal probe
  preserved note-specific peak support and onset evidence through a two-second
  context before folding to pitch classes. After one formula-preserving numeric
  repair made before any score, checked Win32/Win64 source-free controls and
  three development WAV runs passed their resource and leak bounds. The
  [frozen development result](../TONAL.md#frozen-note-aware-local-key-candidate-stopped--2026-09-23)
  reports identical integer tonal scores across targets. D911-02 and D911-16
  fail exact, admitted coverage/precision, conflict abstention and stable
  transition gates; D911-16 misses its one agreed change. The reviewed rain
  window has zero false-key frames, but cannot offset these failures. Stop this
  candidate without threshold/context tuning; D911-05, D911-19 and applause
  stay untouched. This does not close criterion 2, 3 or 5 or earn credit.
- 2026-09-23 task-flow checkpoint: the 22,050-Hz source-rate preparation and
  this frozen candidate are two consecutive batches since criterion 1 closed,
  neither closing another criterion. The first removed a real input barrier;
  the second showed sparse note support plus local ranking is still far below
  the key/unknown/change limits. Do not resume a ranker, support threshold,
  context-window or profile variation from these results. The next action is
  the existing [reviewed note-presence reference](DONE/NS-3_notes_04.md) at its
  exact frozen listening windows; key inference resumes only after a genuinely
  distinct, source-grounded observation of note activity and tonic/change
  evidence with a new prospective gate. This changes the work from key
  candidate tuning to a separately accepted core reference deliverable.
- 2026-09-23 native source-rate prerequisite: the qualified HU33 WAVs are
  22,050 Hz, which the accepted inference identity allowlist previously
  rejected despite a capable Pascal resampler. The focused adapter change
  admits that exact rate and retains source hash/clock in the identity.
  Authored PCM16 whole/adjacent-scope replay passes checked stable Win32 and
  Win64 with zero unfreed blocks; see the [work record](../WORK.md#original-22050-hz-wav-inference-preparation--2026-09-23).
  Focused integrated QA passed with exact 50-observation halves, completed
  scopes, byte-identical adjacent replay and unsupported-rate rejection. This
  enables a future inference candidate but proves no key accuracy, closes no
  other criterion and earns no separate credit.
- 2026-09-23 source-rate fixture repair: focused QA found the initial
  adjacent-scope comparison could pass an early-truncated half because it
  compared only produced observations. The fixture now requires completed,
  non-aborted sinks and exactly 50 windows/observations in each half; checked
  Win32 and Win64 runs pass sequentially with zero leaks. A concurrent test
  invocation briefly collided on its shared ignored output path and passed
  when rerun after the first process ended; no source-path fallback was used.
- 2026-09-23 focused QA accepted criterion 1: source/group roles, complete
  windows, key support, ambiguous/no-key/change cases and all coverage,
  precision, abstention and transition limits are frozen in TONAL.md before
  candidate inference. Checked stable FPC 3.2.2 Win32/Win64 scorer controls
  pass, including both exact one-second edges of a merged same-key span; the
  all-unknown D911-02 development replay is byte-identical on both targets
  (SHA-256 `d2effc9e3c5ba983344be1953841bbfb6dd55853d0535ad57dcf706f5a248b57`).
  It admits zero supported frames and counts zero false transitions. This
  closes only the prospective-policy criterion; no candidate inference,
  accuracy result or task credit follows.
- 2026-09-23 scorer boundary repair: focused QA found that the first scorer
  draft omitted a known-key transition exactly one second from the right edge
  of a stable reference span, despite the inclusive written policy. The
  comparison is now inclusive on both edges; a symmetric source-free control
  and checked Win32/Win64 replay pass. The original error is repaired before
  any candidate inference or independent scoring.
- 2026-09-23 changed path after the accepted reference packet: stop further
  ranker/profile/dictionary variants. Freeze explicit outcome limits and
  separately observable coverage/flicker counts before proposing a Pascal
  source-aware inference path. Checked stable Win32/Win64 scorer controls and
  all-unknown D911-02 development replay match byte for byte (SHA-256
  `d2effc9e3c5ba983344be1953841bbfb6dd55853d0535ad57dcf706f5a248b57`);
  that authored control has zero admitted supported frames and zero false
  transitions, so it cannot masquerade as accepted key inference. Stop this
  batch after focused policy/scorer QA. The next candidate must preserve
  frequency provenance, temporal order and explicit unknowns, then face the
  frozen development gates before any independent candidate run.
- 2026-09-23 reference split: after two nonclosing batches, source/interval
  qualification moved to [NS-3_context_03](DONE/NS-3_context_03.md) with 1 of this
  task's original 4 unearned NS-3 points. This task retains the prospective
  admission policy, ranked evidence, calibration, independent key/change
  accuracy and native delivery. The [stopped four-loop screen](../TONAL.md#loop-level-reference-qualification-stop--2026-09-23)
  shows why publisher labels cannot silently become local interval truth.
  No criterion or credit closes from the split.
- 2026-09-23 recorded percussion candidate: the [frozen source-bound
  screen](../TONAL.md#percussion-only-recording-screen--2026-09-23) ran a
  separately described Navy Band drum cadence through the same Pascal
  WAV/chroma/ranker path. All 24 cells returned ranked keys; the largest
  top-two gap (.009387836) stayed below the authored triad's .015870574.
  This description supplies no expert no-key labels for local intervals.
  The declared decision requires broader independently verified tonal and
  no-key/ambiguous recordings with a prospective temporal, threshold and
  coverage rule. Stop testing this source's gap; no criterion or credit closes.
- 2026-09-23 authored negative-control screen: a [frozen Pascal WAV-analysis
  probe](../TONAL.md#authored-tonal-negative-screen--2026-09-23) ran silence,
  white noise, click train, an equal 12-note cluster and a C-major triad through
  the unchanged chroma/ranker path. The triad ranks C major and its gap exceeds
  all three authored negative gaps, so the fixed decision is to require
  independent recorded evaluation before any threshold. Every non-tonal
  signal still has 24 ranked candidates; rank zero is not admission. Stop
  authored gap variants here. No criterion or credit closes because recorded
  non-tonal/ambiguous labels, temporal evidence and prospective admission
  limits remain missing.
- Stopped representations (2026-09-21): spectral-peak chroma improved one timed source but regressed the other; the published profile pair then failed both. The contribution audit found fifth-related and distant losses as well as relative-mode errors. Stop profile variations; see [decision evidence](../TONAL.md#rejected-profile-decision-audit).

- Stopped harmonic dictionary: 31/72 synthetic cases failed preservation, including pure-tone false class mass and a missing-fundamental octave error. It did not proceed to recorded execution. See [feasibility evidence](../TONAL.md#harmonic-dictionary-feasibility).

- Repaired study issues: the comparison initially misread the second reference as major rather than D minor; a later audit repaired a truncated JSON field name and exception cleanup. Preserve original failed evidence separately from the final comparisons.

- Follow-up: distinguish tonic from sustained dominant, and true note activity from spectral-envelope effects, before another inference proposal. Retain all annotators, disagreements and unlabelled spans; whole-excerpt key labels are not local-key truth.
