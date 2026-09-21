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

**Acceptance Criteria:**

- Separate note presence from pitch identity and distinguish attacks, continuations, rests and endings using supported source evidence.
- Handle repeated same-pitch notes, short/quiet notes, passing notes, glides, gaps and articulation transfer without blanket trimming, gap bridging or quiet-note fragmentation.
- Pass the low/quiet/gap/mixture controls and recorded boundary/false-rest limits declared before scoring; retain the synthetic short low-note recovery where applicable.
- Preserve original source timing, rounding conventions and unknown spans through the maintained event API; unsupported mixtures must not become confident monophonic notes.
- Demonstrate the combined development path can reach the shared phrase gates with the register work; record tradeoffs and unchanged controls instead of counting rejected variants as completion.

**Blockers**

- [NS-3_validation_01.md](DONE/NS-3_validation_01.md)
