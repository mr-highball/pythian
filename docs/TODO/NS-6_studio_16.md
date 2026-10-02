# NS-6_studio_16 — Share microphone WAV encoding with the primary codec

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Remove Studio microphone capture's local RIFF header and float-to-PCM16
implementation. Extend the primary portable WAV codec where needed, then make
native writers and pas2js capture consume that same encoding contract. Browser
device delivery, typed-array transport and controls remain platform adapters.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned delivery_04 point transfers here; every independent
consumer criterion remains required. No credit is earned by this scope change.

Execution status: Big Boss solo; selected after discovery in the required
consolidation inventory. Deliverable: one primary PCM/header implementation.
Closing evidence: native/pas2js identical bytes on authored samples, meaningful
boundary cases and actual browser regression. Stop for an unavailable device
dependency; do not fabricate microphone or physical-phone acceptance.

**Acceptance Criteria:**

- AC1: Core WAV code owns PCM16 quantization and RIFF/RF64 header construction;
  existing native writers and browser capture reuse it. Remove the superseded
  local arithmetic and manual header writing; no compatibility duplicate.
- AC2: Native and pas2js authored controls produce identical header/sample bytes
  for endpoints, clipped/fractional input and supported geometry. Invalid
  samples/geometry fail through the primary contract; preserve streaming bounds.
- AC3: Microphone stop, empty recording, bounded buffer, upload, preview and
  analysis retain their behavior. Actual Codex Browser exercises available
  paths; device-specific coverage remains with studio_10/authoring_02.

**Blockers**

- [NS-6_studio_06.md](DONE/NS-6_studio_06.md)

**Dev Notes:**

- 2026-10-02, Big Boss: `TStudioCapture.ProcessorMessage` contains independent
  signed PCM16 scaling, and `FinishRecording` manually writes a 44-byte RIFF
  header. This distinct gap was found while reviewing shared capture requests
  for [live playback](DONE/NS-6_studio_14.md); it has no browser-device justification.
  It is separated from streaming acceptance and receives no duplicate credit.
