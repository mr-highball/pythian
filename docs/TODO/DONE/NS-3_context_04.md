# NS-3_context_04 — Preserve unknown tempo evidence through replay and generation

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-3)

**Description:**

Completion credit: 1 goal percentage points (0.25 overall points).
Current basis: [2026-09-29 outcome rebase](../../REBALANCE-2026-09-29.md#current-credit-basis).
Earlier point/split narratives below are historical; acceptance evidence and failures remain valid.

Deliver a source-frame tempo-evidence contract that can carry unavailable and
ambiguous timing without assigning a BPM. Retain source identity, measurement
policy and any caller override separately from the original observation. A
known-only excerpt may use the existing tempo clock; unsupported timing must
reject before timed generation. The existing known-only context profile remains
byte-compatible. Automatic beat accuracy and joined key/tempo profiles remain
with [NS-3_tempo_03](../NS-3_tempo_03.md) and
[NS-3_context_02](../NS-3_context_02.md).

North star: NS-3. Outcome owner: WAV-02-CONTEXT.
Historical allocation: 1 goal percentage point (0.25 overall points), assigned from
the original 2 unearned NS-3 points of NS-3_context_02. That task retains 1
point; their original 2-point total is unchanged.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [music context](../../MUSIC-CONTEXT.md) and the current
positive-tempo `TTempoMap`, context grid and WFC tempo-token contracts.

Completed 2026-09-28: the portable Pascal
[`TTempoEvidence`](../../../src/pythian.music.tempo.evidence.pas) validates and
copies source-bound known/unavailable/ambiguous spans, keeps measured and
selected rates and caller origin separate, and persists a bounded SHA-256-
checked v1 binary record. The maintained
[WFC context adapter](../../../adapters/wfc/pythian.wfc.context.pas) emits a
canonical tempo token only for a completely selected constant source range.
Its output-context consumer produces the exact 24,000-frame quarter at 48 kHz
for 500,000 us/quarter and rejects an unknown range before a context exists.
An override permits that range while the raw unavailable status remains saved.
Focused checked FPC 3.2.2 Win32/Win64 core and WFC tests pass with byte-identical
tempo fixture SHA-256
`b46b93a0a903db930cc06e91c04f385b32b87b987114b095a351f538af0c5040`
and zero reported leaks. Independent QA under ignored
`build/salty-context04-qa-20260928/` also passed malformed/edge/ambiguity
checks, current v1 profile/archive exact round-trips, and byte-identical
current PTC1/PCP1 and four context-demo WAVs on both targets. Existing v1
profile/archive codecs were unchanged. This accepts evidence-to-clock timing,
not automatic tempo accuracy, changing-tempo rendering or a newly listened WAV.

**Acceptance Criteria:**

- Admit bounded, source-bound, ordered half-open tempo regions with explicit
  known, unavailable and ambiguous states. Preserve candidate measurement,
  admission policy, selected tempo and caller-override origin independently;
  an unknown observation does not become a known inference after an override.
- Persist and reload the complete evidence with a versioned deterministic
  native Pascal format, detached ownership and source/policy identity. Reject
  corrupt, incomplete, overlapping and over-budget inputs without publishing a
  partial result. Retain byte-identical known-only v1 context-profile replay.
- Provide a maintained generation consumer that uses an explicit positive
  selected tempo only for a supported source range and rejects unknown or
  changing timing before timed output unless a caller override supplies the
  missing value. No default BPM, implicit interpolation or fabricated certainty.
- Pass focused checked native source-free boundary, replay, override, failure
  and consumer checks on Win32 and Win64. Explain the supported rendering scope
  and its limits in the public contract. This task does not claim automatic
  tempo estimation or measured key/tempo accuracy.

**Blockers**

- [NS-3_validation_01.md](NS-3_validation_01.md) — accepted

**Dev Notes:**

No failed approaches or follow-ups recorded yet.
