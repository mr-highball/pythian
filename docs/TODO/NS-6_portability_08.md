# NS-6_portability_08 — Use the primary binary codec in tempo evidence

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

The actual portable voice consumer reaches primary tempo-evidence serialization
and fails on native-only Move. Its integer fields also retain private copies of
the already accepted little-endian primitives. Consolidate those fields into
`pythian.binary` and replace raw memory copies with portable byte operations.

Execution status: demonstrated prerequisite of
[voice observation17](NS-6_observability_17.md)'s portable consumer, also required
by [caller-codec portability07](NS-6_portability_07.md)'s full consumer gate.
Deliverable: the same tempo-evidence codec executable on native/pas2js, with
unchanged canonical bytes, digest, source/selection identity and malformed-input
proof. Stop on format/clock/selection changes, duplicated binary algorithms or
another distinct required gap. Big Boss works solo.

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

- [Retained archive portability](NS-6_portability_09.md) — the codec's own native/
  portable fixture passes, but the full voice consumer reaches this separate gap.
- [Shared primary binary fields — DONE](DONE/NS-6_binary-codec_01.md).

**Dev Notes:**

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
