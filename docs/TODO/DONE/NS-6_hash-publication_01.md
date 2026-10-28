# NS-6_hash-publication_01 — Preserve caller digest results on cancellation

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Fix a demonstrated primary SHA callback publication defect. Both hash functions
assign their managed String result before the final observer call. Native FPC
can forward that result slot through callers: actual context `ParentIdentity`
propagates the original final exception while overwriting its caller's sentinel.
The context archive/profile cancellation fixture fails on Win32 and Win64 at
that real consumer. Intermediate stages and modes0–9 already pass.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Big Boss works solo. This is a required primary prerequisite of the active
[retained-operation task04](../NS-6_observability_04.md), not a wrapper workaround.
Keep the current context component's partial work and failure evidence intact.
Starting source is `f7f7881`; WFC remains reviewed `6b419e6`.

Deliverable: defer digest result publication in the existing byte and stream
SHA implementation until the final borrowed callback succeeds. Preserve exact
digests, input validation, callback records, original exceptions and consumed
stream position. Closing evidence: direct and forwarded managed-result sentinels,
interior/final original abort/retry, empty/padding/block/8192-byte boundaries,
actual checked native/pas2js fixtures, actual failing context consumer and clean
published integration/extracted consumers. Stop on changed cryptographic math,
input/count policy, silent stream rewind, swallowed exception or a distinct gap.

Accepted AC1–3 on 2026-10-28, Big Boss solo, at
`dde2df39331739a0339427718cab3b9faeaa3788` after checked native/actual portable
return-slot evidence, repaired actual context consumers and exact prior outputs.
[Ubuntu CI458](https://github.com/mr-highball/pythian/actions/runs/40630263217),
job122624749001, is terminal Success: total12m28s/job12m24s, maintained integration
11m21s and core-only/full extracted consumer verification42s. This closes the
primary digest guarantee, not full parent04 or musical acceptance. The associated
context component passes its named scope; later session/batch/inference/operator
obligations stay required. The real criterion closure resets the retained delivery
nonclosing count1 to0; creating this task did not reset it.

Displayed artifact-container digests, not independently downloaded ZIP hashes:
logs `b993cecdc6686a324acd2c0e73ae7ceee77495a435adc8b1a044ad8230e50165`;
packages `7316209738372b1ad0d47ab44c2b6a27373913c42d6af249877f1d2bcb2e7580`.
Evidence: dedicated E-drive hash-publication/context-profile build/test/run roots.
Earlier pending statements below are intermediate history.

**Acceptance Criteria:**

- AC1: Both primary SHA APIs return the same exact digests while leaving a caller's
  existing digest String unchanged on original interior/final callback failure,
  including when a public wrapper forwards the managed return slot. No parallel
  hashing algorithm or special context workaround.
- AC2: Checked Win32/Win64 and actual pas2js tests cover known vectors, byte and
  fragmented-stream paths, empty/partial/padded/block/chunk boundaries and retry.
  A stream abort retains consumed position; the caller explicitly rewinds for
  fresh retry. The actual context identity consumer's failed publication case
  passes after the primary fix, with its source/profile unchanged and zero leaks.
- AC3: Maintained integration and core-only/full extracted consumer packages pass
  at the exact published revision. Record repaired failure evidence and update
  task links/accounting together; no musical credit or unrelated counter reset.

**Blockers**

- [Shared callback contract — DONE](NS-6_observability_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss local repair: both SHA APIs compute into a private digest,
  call the original final observer, then assign Result. Checked Win32/Win64 each
  pass336565 portable hash checks/24 original publication abort-retries; actual
  pas2js passes336566. Existing hash vectors/stream errors and385 callback checks
  pass, zero native leaks. Both frozen native source builds reproduce direct
  byte/stream sentinel loss before the fix, including empty input. The actual
  context fixture now passes268601 checks/234 original abort-retries/66835 callbacks
  per native target with zero leaks, including the failing identity consumer.
  Twelve prior artifacts/target and actual CLI receipts are exact; callback
  instrumentation changes no mathematical hash/model/profile/PCM bytes. Clean
  published integration/extracted consumers remain the open acceptance gate.

- 2026-10-27, Big Boss: actual context fixture modes0–9 pass, then mode10 final
  `verify_audio_bytes` cancellation changes the caller output. Preserve both
  initial logs in E-drive `context-profile-20261027-boss` test records. Source
  inspection finds the same final-result ordering in both primary hash APIs.
  Follow this prerequisite before claiming context component acceptance. The
  active parent component and its original criteria remain open; naming a task
  resets no batch counter and earns no points.
