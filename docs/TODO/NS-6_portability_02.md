# NS-6_portability_02 — Share corpus intake text and accounting across targets

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Make the primary caller-defined corpus intake and contribution contract runnable
in native Pascal and pas2js without duplicating accounting or weakening its text
and identity rules. A real pas2js compile stops at the native-only `UTF8String`
declaration before the new contribution fixture can execute. Intake also depends
on the full acoustic corpus unit solely for its shared text validator.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This is a portability repair, not musical/vocabulary credit. Native contribution
accounting under [vocabulary_01](NS-5_vocabulary_01.md) can proceed independently.
Primary beat/hash/WAV analysis portability stays with
[portability_01](NS-6_portability_01.md).

Next deliverable: one shared text/identity contract and the same intake/accounting
implementation executed on both targets. Closing evidence: actual native/pas2js
fixtures with Unicode, bounds, original mappings, duplicate/multiplicity handling,
caller ownership and large exact counters. Stop at a target-only accounting fork,
lossy alias, changed native acceptance, invented source identity or broad analyzer
changes unrelated to intake.

**Acceptance Criteria:**

- Preserve bounded UTF-8/Unicode identity, NUL rejection and exact caller text
  through target-appropriate representations. A blind `String` alias does not
  establish byte/text parity. Consolidate the primary corpus validator rather
  than copy its logic into a browser adapter.
- Decouple declaration-only intake from unnecessary acoustic implementation
  dependencies while keeping one primary source-mapping, coverage, contribution
  and training-admission implementation. Preserve native results and exceptions.
- Execute meaningful native and actual pas2js cases for Unicode/text rejection,
  duplicate and derivative mappings, unknowns, partitions, detached arrays and
  exact-integer multiplication/addition boundaries. Declare unsupported versus
  future WASM scope; compilation alone is insufficient.

**Blockers**

- None beyond the maintained corpus intake contract. The native contribution
  batch can finish independently; the full primary analyzer is outside this scope.

**Dev Notes:**

- 2026-10-27, Spike / Big Boss: the independent contribution fixture compiles
  and passes checked Win64 boundaries, but actual `pas2js -Tnodejs` compilation
  fails at `pythian.corpus.intake.pas` with `identifier not found UTF8String`.
  No substitute runtime, text alias or duplicate algorithm was used. Commands
  and exact error remain under `E:/CodexWork/pythian/runs/spike-20261027/`.
  This discovered gap is recorded before expanding scope; return to finishing
  the current native vocabulary contribution/consumer batch.
