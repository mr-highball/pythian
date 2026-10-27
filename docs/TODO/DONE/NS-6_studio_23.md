# NS-6_studio_23 — Release failed listening-response construction

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Fix ownership of a partially constructed listening response when validation
rejects a transaction. The existing empty-reviewer fixture leaves the result
object and its fields allocated. Failed Save validation must preserve the
catalog and release temporary objects.

North star: NS-6. Outcome owner: OPERATOR-STUDIO. Completion credit: 0 additional.
Accepted 2026-10-27: Spike repaired the primary response builder and maintained
fixture. Checked FPC 3.2.2 Win32/Win64 runs, Spiegel's independent checked Win64
run/source review and Big Boss's optimized checked Win64 run pass with zero
leaked blocks. Successful response/export identities and rejected-write
preservation pass. The repair is deployed in the fixed native service slot;
browser and musical acceptance remain separate. Big Boss owns final judgment.
Accepted deliverable: exception-safe construction through the current implementation,
with identical successful responses and unchanged rejected-write behavior.
Closing evidence: checked native Win32/Win64 valid/malformed/append/replay checks,
zero leaks and preserved request/review bytes. Stop on changed answer semantics,
format, validation policy or catalog mutation from failed validation.

**Acceptance Criteria:**

- AC1: Release a partially built response on failure, retaining exact exception
  behavior and single ownership of choice/score/comment arrays after transfer.
- AC2: Preserve successful response fields, canonical hashes, revision/history
  behavior and refusal before publication for invalid transactions.
- AC3: The maintained native listening fixture passes the existing malformed
  reviewer case and relevant invalid/publish/replay paths on checked Win32/Win64
  with zero leaked blocks and unchanged prior catalog/review data.

**Blockers**

- [Existing editor/queue contract — DONE](NS-6_authoring_01.md).

**Dev Notes:**

- 2026-10-27, Big Boss: failed result construction now frees its result, and
  transferred child arrays are cleared from temporary ownership. Wrong-type
  choices/scores/comments exposed another ownership path within this task:
  freeing an input array before a throwing replacement left a dangling pointer.
  The earlier CLI reproduced access violations with 10/7/4 leaked blocks;
  `FreeAndNil` now preserves the intended validation error with zero leaks.
  Maintained malformed fixtures cover all three fields. Evidence stays under
  E-drive `runs/feedback-single-20261027-spike`,
  `runs/feedback-response-20261027-spike`, `runs/feedback-race-20261027-spike`,
  `runs/feedback-readiness-20261027-spiegel-qa` and
  `runs/feedback-readiness-20261027-boss`. No operator answer was written.

- 2026-10-27, Big Boss: discovered during [studio_03](../NS-6_studio_03.md)'s prepared
  single-review work. Full fixture assertions pass but report 11 unfreed blocks
  (748 bytes on Win64, 392 on Win32). The unchanged HEAD fixture against the
  candidate unit reproduces the same failure; the product diff is confined to
  the separate experiment factory and `NormalizeResponse` is unchanged. Its
  result is allocated before reviewer validation can throw, with no result
  cleanup in the nested exception handlers. Preserve those logs under E-drive
  `runs/feedback-single-20261027-spike`. The new single factory's focused valid
  probe is leak-free. This discovered repair is not a failed implementation QA
  submission for that independent factory and earns no musical credit.
