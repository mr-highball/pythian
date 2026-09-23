# NS-3_notes_02 — Resolve note presence, attacks and endings

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-3)

**Description:**

Resolve false notes in rests and incorrect event boundaries together with reliable pitch identity, preserving quiet/repeated notes and genuine transitions.

North star: NS-3. Outcome owner: WAV-03-BOUNDARIES.
Completion credit: 4 goal percentage points (1.00 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PHRASE-EVALUATION](../PHRASE-EVALUATION.md) · [PITCH](../PITCH.md) · [ONSETS](../ONSETS.md).

Current evidence 2026-09-21: the [cached contour diagnostic](../PHRASE-EVALUATION.md#cached-contour-support-does-not-recover-both-short-notes--2026-09-21)
does not recover the missing 30-ms 55-Hz note: its expected pitch wins none of
three raw rows or three scoring centers. The 440-Hz short note wins, but its
pitch also wins all four centers in the real repeated-note gap. Stop this common
fallback; no recorded comparison or contour-threshold sweep follows. Prior direct
head and waveform-anchor decoders already fail false-rest admission, while coherent
cycle support preserves synthetic short notes without improving recorded results.
The next presence observation must retain that low/quiet/gap capability and
distinguish sustained harmonic sound from rest/ending evidence; rearranging
existing head cuts alone is insufficient. All acceptance criteria remain open.

Reassessment before batch 28: existing event-context and coherent-cycle evidence
does not distinguish continuing notes from all annotated rests or residual tails.
Many false-rest centers already locally favor note states, so changing decoder
costs alone does not supply missing acoustic discrimination. A prospective
presence observation needs contrasting labelled continuation/release/unvoiced
examples with source-separated calibration and unchanged waveform protections.
The current [register-candidate experiment](../PHRASE-EVALUATION.md#source-separated-candidate-calibration--2026-09-21)
does not train on rests or claim to resolve this task. Keep this gap separate;
do not turn a candidate pitch score into a note-presence probability.

**Acceptance Criteria:**

- Separate note presence from pitch identity and distinguish attacks, continuations, rests and endings using supported source evidence. Include contrasting labelled continuation, release-tail and rest cases; a high pitch-candidate score alone is not note-presence evidence.
- Handle repeated same-pitch notes, short/quiet notes, passing notes, glides, gaps and articulation transfer without blanket trimming, gap bridging or quiet-note fragmentation.
- Pass the low/quiet/gap/mixture controls and recorded boundary/false-rest limits declared before scoring; retain the synthetic short low-note recovery where applicable. Report false notes in rests separately from missed active notes and attack/end errors, including each case's unknown coverage, so a boundary improvement cannot conceal a presence regression.
- Preserve original source timing, rounding conventions and unknown spans through the maintained event API; unsupported mixtures must not become confident monophonic notes.
- Demonstrate the combined development path can reach the shared phrase gates with the register work; record tradeoffs and unchanged controls instead of counting rejected variants as completion.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)

**Dev Notes:**

- Stopped fallback (2026-09-21): contour support missed the 30-ms 55-Hz note while supporting 440 Hz inside the true repeated-note gap. Direct-head and waveform-anchor alternatives already failed false-rest admission; coherent-cycle support preserved controls without recorded improvement. See [contour evidence](../PHRASE-EVALUATION.md#cached-contour-support-does-not-recover-both-short-notes--2026-09-21).

- Follow-up: obtain contrasting continuation, release-tail and rest evidence before changing admission. Many false-rest centers already favor note states locally; decoder costs alone do not supply discrimination. Keep pitch rank separate from presence and coordinate combined gates with [register work](NS-3_notes_01.md).

- 2026-09-22 accepted-observation boundary: the Pascal sparse-peak scorer reported support >=0.5 at 89/329 fully isolated Spring flute rest centers and 14/191 violin rest centers. These are source-bound raw observations, not false admitted notes or a calibrated presence probability. Do not use support alone for attack, continuation, ending or rest decisions; the contrasting labelled evidence required above remains open.

- 2026-09-22 source-separated contrast packet: a frozen native Pascal selector reuses the six hash-bound URMP parts from three distinct work groups in `build/note-calibration/binding.json`, without reading Spring or reserved evaluation audio. On the first 30 seconds of each mono 16-kHz WAV, fixed 50-ms centers and 2048-sample windows yield 1,441 fully internal note-continuation centers, 137 immediate post-annotation-end candidates and 439 distant-rest centers; 1,577 edge/overlap/ambiguous centers are excluded. Exact source/note hashes, partition/group IDs, frames, nearest preceding note indexes and waveform RMS are retained in ignored `build/presence-contrast/cohorts.csv` (SHA256 `393e175f3237b4ff1b5f241645d929eb3c3974e3820606d0f6bbdf15fc0e7d85`). Stable FPC 3.2.2 Win32 compiled the temporary Pascal selector; two complete runs produced the same CSV hash after a traceability repair bound post-end rows to their preceding annotations. The 137 post-end rows are **not confirmed release-tail labels** because supplied note endpoints and audible releases may differ. This packet advances the required contrast preparation but closes no presence criterion or task credit. Next adjudicate release versus true rest on these fixed windows, retain uncertain cases, then freeze an acoustic observation and source-separated scoring policy before changing the maintained event path. Do not widen time intervals or tune to the cohort counts.

- 2026-09-22 companion F0 reassessment: a fixed Pascal audit verified every selected raw Notes and F0s hash against the same bound manifest, aligned 46-ms frame annotations within 5 ms and required their windows to start after the preceding note end. All 137 post-end candidates have a complete unvoiced companion annotation; none is annotated at the prior or another pitch. The clock/annotation controls agree at 1,440/1,441 internal continuations and 439/439 distant rests. Two final runs reproduce ignored `build/presence-contrast/f0-audit.csv`, SHA256 `5504aff291af64df025a1b152947ed8ae2b05fb6d64b9fc2501d53e1edeb6d72`. The frame and note annotations are related curator products, and an unvoiced F0 does **not** prove acoustic silence or absence of a release tail. This result ends the current annotation-only route: it cannot furnish a curator-supported voiced-tail reference. The contrast packet and this audit are two consecutive nonclosing presence batches. Reassess toward a source with separately anchored gate/release observations and controlled physical tails before any new presence scorer; do not relabel these 137 windows as release truth or retune their timing. No criterion or credit closes.
