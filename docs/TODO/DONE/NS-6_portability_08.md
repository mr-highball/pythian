# NS-6_portability_08 — Use the primary binary codec in tempo evidence

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Original gap (repaired at the accepted checkpoint below):

The actual portable voice consumer reaches primary tempo-evidence serialization
and fails on native-only Move. Its integer fields also retain private copies of
the already accepted little-endian primitives. Consolidate those fields into
`pythian.binary` and replace raw memory copies with portable byte operations.

Execution status: **Accepted 2026-10-28** at Pythian
`d37072302436b3b8b2e95f6bab1ac2b0571afd5f`, after exact published integration,
clean extracted core/full consumers and the native/actual pas2js gates below.
All criteria and prerequisites pass at this engineering scope. No musical,
browser/device or independent-use credit follows.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit:0 additional.
This closes no scientific tempo inference or musical acceptance.

**Acceptance Criteria:**

- Use the primary checked UInt32 little-endian primitives, retaining the codec's
  own body limits. Preserve exact native canonical artifact bytes and SHA-256;
  byte copies and hexadecimal digest emission work on native and pas2js.
- Actual codec consumers exercise selected/unknown/observed tempo spans,
  canonical round-trip, malformed/truncated/hash rejection and detached input/
  output on both targets. Preserve the original selection and source policies.
- The actual portable voice consumer, original native controls, published
  integration and extracted core/full consumers pass. Preserve failures and
  repair incoming links/accounting together before moving to DONE.

**Blockers**

All prerequisites below are accepted. Their discovery descriptions are historical.

- [Retained archive portability](NS-6_portability_09.md) — the codec's own native/
  portable fixture passes, but the full voice consumer reaches this separate gap.
- [Shared primary binary fields — DONE](NS-6_binary-codec_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss accepts all criteria after exact
  [CI471](https://github.com/mr-highball/pythian/actions/runs/40789537394) succeeds: native job
  12m43s, maintained integration 11m39s and extracted consumers 40s. Clean exact Win64 core 107
  owned/120 inventory and full 159 owned/280 inventory packages pass. Native passing logs report
  zero leaks. Full named-voice construction/generation/retry passes 13939 checks/10 original
  abort-retries/13396 callbacks on Win32/Win64 and actual pas2js. Win32/Win64 and actual pas2js
  preserve the frozen 263-byte artifact and SHA256
  b46b93a0a903db930cc06e91c04f385b32b87b987114b095a351f538af0c5040.
  Selected/unknown/observed/override, malformed geometry/status/checksum/budget and detached-copy
  controls pass. UInt32 fields and fixed ASCII digest fields share primary implementations; source
  and tempo policies are unchanged. Preserve the rejected compiles and CI470 cadence failure; its
  repair retains exactly 1885 model/profile callbacks under the unchanged 2000 bound, reporting
  primary measurement 1078 and UTF-8 160 separately. Both native targets pass 57 checks with zero
  leaks. Evidence: dedicated E-drive archive-portability-20261028-boss,
  voice-integration-20261028-boss and wfc-voice-progress-20261028-boss packets. Incoming
  links/accounting move together; completion remains 52.45, with no scientific counter reset.

- 2026-10-28, Big Boss: digest fields now share primary pythian.hash's fixed
  ASCII helper with the context/style archives. Current native Win64 and actual
  pas2js retain frozen263bytes/b46b93a0a903db930cc06e91c04f385b32b87b987114b095a351f538af0c5040
  and all original codec rejection/ownership controls. Linked09/10 repairs let
  full portable named-voice preparation execute13939/10/13396. New exact
  published/extracted gates remain open; predecessor242563f/CI469 passed
  integration14m18s and extracted46s, but predates these later changes.

- 2026-10-28, Big Boss local repair: tempo evidence now delegates UInt32 fields
  to pythian.binary, copies its body with the portable array operation and
  writes the fixed ASCII digest bytes without native Move. Frozen native,
  current Win32/Win64 and actual pas2js retain263 canonical bytes and SHA256
  b46b93a0a903db930cc06e91c04f385b32b87b987114b095a351f538af0c5040.
  Existing selected/unknown/ambiguous/override, malformed geometry/status/
  checksum/budget and detached copy controls pass; native exits have zero leaks.
  Preserve initial test-harness StdErr/Halt compilation rejections; remove
  its native-only wrapper so actual failures propagate on both targets.
  The full portable voice consumer next exposes archive09; this task remains
  open for that retained consumer plus published/extracted qualification.

- 2026-10-28, Big Boss: after caller-codec bytes compile, actual pas2js rejects
  primary tempo evidence line288, identifier Move. The source also has a body
  Move and duplicate UInt32 field assembly. Record this separate owner before
  editing; do not widen the UTF-8 task into binary or scientific tempo work.
  Retain rejection under E-drive voice-integration-20261028-boss. Counts55 open/
  82 DONE/137 total, NS6 17 open;52.45/47.55 and delivery entry2 remain until
  real acceptance. Native voice consumer already passes13939 checks/10 original
  abort-retries on both targets; UTF-8 admission passes340/3 natively and actual
  pas2js. Neither result establishes the still-failing full portable voice path.
