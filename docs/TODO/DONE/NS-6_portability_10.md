# NS-6_portability_10 — Execute the primary streamed chord renderer on pas2js

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Original gap (repaired at the accepted checkpoint below):

The actual full voice consumer now reaches `pythian.chord.stream` and pas2js
rejects its nested strict-private TToneStates type inside TVoiceState. Earlier
portable synthesis acceptance exercised the general chord synthesizer, not this
streamed triangle preview. Keep those scopes distinct. This is a primary core
prerequisite, not part of the retained archive implementation.

Execution status: **Accepted 2026-10-28** at Pythian
`d37072302436b3b8b2e95f6bab1ac2b0571afd5f`, after exact published integration,
clean extracted core/full consumers and the native/actual pas2js gates below.
All criteria and prerequisites pass at this engineering scope. No musical,
browser/device or independent-use credit follows.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit:0 additional.
This earns no new synthesis quality, musical learning or independent-use credit.

**Acceptance Criteria:**

- Internal tone/voice types compile on native and pas2js while renderer fields
  remain strict private. Keep one primary implementation; no adapter renderer
  or duplicate oscillator, envelope or frame-admission logic.
- Execute the actual streamed renderer and existing independent gate/WFC PCM
  comparisons on native/pas2js. Preserve exact samples, hold phase, detached
  output, rejection/retry and cancellation. Reject counts outside the target's
  exact counter domain without changing state; preserve native Int64 support
  and document the portable exact-integer limit rather than accepting rounding.
- Original native controls, actual portable full voice consumer, published
  integration and clean extracted core/full consumers pass. Preserve failure
  evidence and update links/accounting together before moving to DONE.

**Blockers**

All prerequisites below are accepted. Their discovery descriptions are historical.

- [Primary synthesis portability — DONE](NS-6_portability_03.md) — general
  synthesis qualification remains valid at its recorded scope.
- [Shared exact clocks — DONE](NS-6_portability_04.md).

**Dev Notes:**

- 2026-10-28, Big Boss accepts all criteria after exact
  [CI471](https://github.com/mr-highball/pythian/actions/runs/40789537394) succeeds: native job
  12m43s, maintained integration 11m39s and extracted consumers 40s. Clean exact Win64 core 107
  owned/120 inventory and full 159 owned/280 inventory packages pass. Native passing logs report
  zero leaks. Full named-voice construction/generation/retry passes 13939 checks/10 original
  abort-retries/13396 callbacks on Win32/Win64 and actual pas2js. Native Win32/Win64 and actual
  pas2js preserve all 55,861 ordered reference PCM samples across 44,100/48,000/32,000Hz, including
  finite gate, hold, detached output, rejection/retry and Cancel. Native Int64 and portable 2^53-1
  admission remain explicit; admitting the maximum does not claim a render of that duration. Private
  types/getters share one unchanged renderer, with strict-private state. Preserve the rejected
  compiles and CI470 cadence failure; its repair retains exactly 1885 model/profile callbacks under
  the unchanged 2000 bound, reporting primary measurement 1078 and UTF-8 160 separately. Both native
  targets pass 57 checks with zero leaks. Evidence: dedicated E-drive
  archive-portability-20261028-boss, voice-integration-20261028-boss and
  wfc-voice-progress-20261028-boss packets. Incoming links/accounting move together; completion
  remains 52.45, with no scientific counter reset.

- 2026-10-28, Big Boss local candidate: private nested types and typed property
  getters compile on native/pas2js while fields remain strict private. Shared
  exact counter admission rejects portable overflow/fraction/nonfinite input
  before state change; native Int64 support remains. Win32/Win64 and actual
  pas2js preserve all55861 ordered WFC reference samples across44100/48000/
  32000Hz, including zero/20ms/1000ms release cases, finite-gate/hold/ownership/
  cancellation controls. Native exits have zero leaks. Full actual portable
  named-voice preparation passes13939/10 original aborts/13396 callbacks after
  its preserved-layer index uses the existing explicit Entry property. Preserve
  strict-private type, record-property and default-indexer compile failures.
  Exact new publication/extracted gates remain open; predecessor242563f/CI469
  success does not qualify this later source. Counts and musical credit unchanged.

- 2026-10-28, Big Boss: actual portable voice compile rejects chord.stream
  line91, strict private TToneStates. Native context archive remains exact at
  986bytes/aaf34c83fc4c91b45d5f03a2da0ee57fd8eb8ff9897073f847a739c4cf9aa39d.
  Shared text conversion passes2803checks/12 original abort-retries/2654callbacks
  on native/actual pas2js. Scope this separate renderer owner before editing;
  preserve those passing archive/core checks and rejected compile in the E-drive
  archive-portability-20261028-boss packet. Existing stream tests also probe
  High(Int64), which requires honest target-domain checks on pas2js. Counts
  become57 open/82 DONE/139 total, NS6 19 open;52.45/47.55 and delivery entry2
  remain. No renderer source has changed at scoping, no musical credit follows.
