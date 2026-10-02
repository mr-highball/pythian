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

- Big Boss: primary `pythian.wave.stream.WavePcm16Header` now owns geometry,
  RIFF/RF64 choice and header bytes. Native writer construction consumes it;
  capture calls it at stop and reuses `pythian.audio.QuantizePcm16` per sample.
  Only the platform stream-write calling convention is conditional. Hand-written
  capture headers and asymmetric local rounding are removed, without preserving
  their differing bytes. Existing two-minute/buffer bounds and device lifecycle
  remain in the adapter.
- The same maintained fixture produces identical complete byte output on
  checked Win32/Win64 and matched pas2js. Independent endpoint/half-step PCM and
  exact RIFF/RF64 oracles, invalid format/extent/NaN, empty header, memory-sink
  adapters and existing streamed write/failure/ownership checks pass. Both native
  targets report zero heap leaks; native capture regression passes 53 checks.
  Evidence: `build/shared-capture/`; `-VerifyCodec` in the workbench build maintains
  the pas2js path. The initial compile exposed an unsupported `AnsiString` type;
  the primary ASCII tag helper now uses portable `String`. An orchestration check
  also exposed multiple Node installations; the optional verifier selects the
  first resolved executable. No alternate codec was introduced.
- Actual Codex Browser, desktop/390 px: recorder opens, retained authored input
  analyzes and previews to its eight-second end; native streamed generation with
  the shared header ends at five seconds. No horizontal overflow or console
  warnings/errors; all owned tabs are closed and viewport reset. No physical
  microphone or phone recording was performed. Encoding itself is covered by
  the shared native/pas2js oracle, not an invented device verdict. Frozen assets
  and evidence await exact-code CI before acceptance.

- 2026-10-02, Big Boss: `TStudioCapture.ProcessorMessage` contains independent
  signed PCM16 scaling, and `FinishRecording` manually writes a 44-byte RIFF
  header. This distinct gap was found while reviewing shared capture requests
  for [live playback](DONE/NS-6_studio_14.md); it has no browser-device justification.
  It is separated from streaming acceptance and receives no duplicate credit.
