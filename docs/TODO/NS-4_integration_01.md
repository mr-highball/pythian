# NS-4_integration_01 — Deliver the recorded WAV-to-style-to-audio workflow

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-4)

**Description:**

Connect accepted WAV musical providers to saved semantic styles, actual modular WFC generation and useful native synthesis through a reusable public consumer.

North star: NS-4. Outcome owner: WAV-04-INTEGRATION.
Completion credit: 2 goal percentage points (0.30 overall points), after
reallocating the other 2 original unearned NS-4 points between
[NS-4_note-events_01](DONE/NS-4_note-events_01.md) and
[NS-4_composition_01](DONE/NS-4_composition_01.md). The three tasks retain the
original 4 NS-4 points / 0.60 overall points; no new credit was created.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAV-LEARNING](../WAV-LEARNING.md) · [INDEPENDENT-VOICES](../INDEPENDENT-VOICES.md) · [LAYERED-STYLE](../LAYERED-STYLE.md).

**Acceptance Criteria:**

- Reproduce recorded WAV admission -> saved style -> selective blend -> further blend -> actual base/harmony/rhythm/part passes -> native audio, retaining source/model/policy identities.
- Use accepted recorded context, events/roles, harmonic/groove and evolving sound evidence; label any intentionally authored accompaniment or unsupported dimension explicitly.
- Demonstrate paired key, BPM, rhythm, bass, voice, timbre and envelope edits with dependency preservation, explicit contradictions/unknowns and the supported changing-duration/stream policy.
- Verify save/reload replay, detached ownership, original/normalized timing, MIDI/native note correspondence where supported, and sustained audio within declared budgets.
- Record actual listening observations with the accepted synthesis path and document concise external-consumer usage. This completes workflow integration, not genre-style acceptance.

**Blockers**

- [NS-4_note-events_01.md — DONE](DONE/NS-4_note-events_01.md)
- [NS-4_styles_02.md](DONE/NS-4_styles_02.md)
- [NS-4_layers_04.md](DONE/NS-4_layers_04.md)
- [NS-3_context_02.md](NS-3_context_02.md)
- [NS-3_notes_03.md](NS-3_notes_03.md)
- [NS-3_parts_03.md](NS-3_parts_03.md)
- [NS-3_harmony_01.md](NS-3_harmony_01.md)
- [NS-3_groove_01.md](NS-3_groove_01.md)
- [NS-3_timbre_02.md](NS-3_timbre_02.md)
- [NS-2_synthesis-quality_03.md — DONE](DONE/NS-2_synthesis-quality_03.md)

**Dev Notes:**

- 2026-09-24 the first score-conditioned two-part WFC diagnostic stopped
  before solve/render at a 40,424-frame training-grid displacement. The
  sampled active-pitch representation loses retrigger ownership, and the
  existing acoustic-event token lacks part and onset-delta semantics. The
  distinct maintained note-event adapter is split into
  [NS-4_note-events_01](DONE/NS-4_note-events_01.md) as a prerequisite. Recorded
  providers, selective styles and broad audio workflow acceptance remain
  here; neither task earned credit from the split.
