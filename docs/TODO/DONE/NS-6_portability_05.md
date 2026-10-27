# NS-6_portability_05 — Restore the Linux corpus-text consumer gate

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Repair the maintained Ubuntu/FPC build after the shared corpus-text change.
Remote runs 434 through 445 fail; inspected runs 434, 444 and 445 stop at corpus
text execution before packaging. Windows and pas2js checks did not qualify this
Linux boundary. Preserve the scalar-text contract and every required check.

Accepted 2026-10-27 at `22afc3d`: Big Boss's solo native/pas2js checks and
actual Ubuntu 24.04/FPC 3.2.2 run446 pass. Integration and both extracted core/WFC
consumer packages complete successfully. Typed fixture operands preserve their
intended UTF-8 bytes and exact identities; the primary validator is unchanged.
The maintained workflow prints captured failure context and preserves failure
status. Resume the retained-operation work after this zero-credit repair.
No independent human/agent review is claimed for these solo checks.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS and maintained delivery.
Completion credit: 0 additional. No musical or independent-use credit follows.

**Acceptance Criteria:**

- AC1: Reproduce and repair the corpus-text failure while retaining exact valid
  Unicode identity, malformed-byte/NUL rejection and the 4096-byte boundary.
  Verify that authored fixture inputs have their intended bytes; do not add a
  platform conversion dependency merely to conceal a fixture-construction bug.
- AC2: Execute affected native and actual pas2js fixtures, then the maintained
  Ubuntu 24.04/FPC 3.2.2 integration and extracted consumer jobs on
  `hello-pythian`. An unexecuted workflow or Windows simulation is insufficient.
- AC3: Print the retained build/package log's failure context in the Actions
  output while preserving exit status and artifact retention. Preserve the
  unrelated unfinished work and document actual remaining failures honestly.

**Blockers**

- [Shared corpus intake/text contract — DONE](NS-6_portability_02.md).

**Dev Notes:**

- 2026-10-27, Big Boss acceptance: [Ubuntu run446](https://github.com/mr-highball/pythian/actions/runs/40558817533)
  succeeds at `22afc3d`, total11m9s/job11m5s. The maintained integration and
  extracted consumers complete; two retained artifacts are visible in the
  authenticated browser: `native-fpc-logs` (744 KiB) and
  `pythian-source-packages` (1.67 MiB). This closes AC1–3 together with the local
  checks and intentional failure-wrapper check below. No Linux runtime was
  installed locally and no skipped gate is treated as passing. The earlier
  live-run and failed-download notes are historical. Evidence stays under
  E-drive `runs/ci-inspection-20261027-boss`. The original validator, private
  recordings, saved answers, service and unfinished style changes are preserved.
- 2026-10-27, Big Boss: repair `22afc3d` is pushed. Checked native Win32/Win64
  passes 19 text and 44 intake cases plus the adversarial consumer, all zero
  leaks; actual pas2js passes 15 text and the same intake/adversarial consumers.
  The original fails and repaired inputs pass the default-manager diagnostic.
  Typed comparison operands also preserve the exact whitespace/BMP/astral
  identities. The exact workflow body retains an intentional failure's context
  and exit1. At this intermediate checkpoint Ubuntu run446/job122381990646 was
  live in integration and AC2 was unproven. The final acceptance above supersedes
  that wait; no restart or documentation-only cancellation occurred.
- 2026-10-27, Big Boss: authenticated browser inspection confirms first failure
  at `c7fd150`, last passing run 433, and the same corpus-text execution failure
  in runs 434, 444 and 445. The detailed artifact download did not complete.
  A Pascal-only diagnostic using the installed FPC RTL's default conversion
  behavior reproduces `Invalid text accepted` at the over-budget fixture:
  repeated untyped astral-literal concatenation invokes Unicode conversion and
  produces 2048 substituted bytes instead of the intended 4096 UTF-8 bytes.
  The installed Windows manager passes the same original fixture. This isolates
  a concrete fixture defect; actual Linux verification was still required then
  and is supplied by the final acceptance above.
  Evidence: E-drive `runs/ci-inspection-20261027-boss` and
  `tests/ci-text-20261027-boss`. No platform or inference runtime was installed.
