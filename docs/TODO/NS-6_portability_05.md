# NS-6_portability_05 — Restore the Linux corpus-text consumer gate

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Repair the maintained Ubuntu/FPC build after the shared corpus-text change.
Remote runs 434 through 445 fail; inspected runs 434, 444 and 445 stop at corpus
text execution before packaging. Windows and pas2js checks did not qualify this
Linux boundary. Preserve the scalar-text contract and every required check.

Execution status: ready, selected by Big Boss on 2026-10-27 following the user's
CI failure report. This is a zero-credit delivery prerequisite; resume the
retained-operation work afterward. Big Boss implements and verifies solo under
the current supplied operator instructions.

Next deliverable: repair the demonstrated cause and make the maintained CI
failure output useful without requiring an artifact download. Closing evidence:
checked native and actual pas2js consumers plus the real Ubuntu/FPC job and
extracted packages. Stop on changed identity/validator semantics, weaker tests,
dependency edits, or evidence of a distinct required defect; record that gap
before expanding scope.

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

- [Shared corpus intake/text contract — DONE](DONE/NS-6_portability_02.md).

**Dev Notes:**

- 2026-10-27, Big Boss: authenticated browser inspection confirms first failure
  at `c7fd150`, last passing run 433, and the same corpus-text execution failure
  in runs 434, 444 and 445. The detailed artifact download did not complete.
  A Pascal-only diagnostic using the installed FPC RTL's default conversion
  behavior reproduces `Invalid text accepted` at the over-budget fixture:
  repeated untyped astral-literal concatenation invokes Unicode conversion and
  produces 2048 substituted bytes instead of the intended 4096 UTF-8 bytes.
  The installed Windows manager passes the same original fixture. This isolates
  a concrete fixture defect; actual Linux verification is still required.
  Evidence: E-drive `runs/ci-inspection-20261027-boss` and
  `tests/ci-text-20261027-boss`. No platform or inference runtime was installed.
