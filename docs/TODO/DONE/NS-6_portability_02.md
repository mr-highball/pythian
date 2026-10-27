# NS-6_portability_02 — Share corpus intake text and accounting across targets

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Make the primary caller-defined corpus intake and contribution contract runnable
in native Pascal and pas2js without duplicating accounting or weakening its text
and identity rules. Before this repair, a real pas2js compile stopped at the
native-only `UTF8String` declaration before the contribution fixture could execute.
Intake also depended on the full acoustic corpus solely for its text validator.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This is a portability repair, not musical/vocabulary credit. Native contribution
accounting under [vocabulary_01](../NS-5_vocabulary_01.md) can proceed independently.
Primary beat/hash/WAV analysis portability stays with
[portability_01](../NS-6_portability_01.md).

Accepted 2026-10-27: one primary scalar-text validator and canonical identity
comparison, consumed by the native corpus and shared intake. The same accounting
implementation executes under checked native FPC and actual pas2js/Node.
Spiegel implemented the shared text/core fixture; Big Boss integrated intake,
native consumers and maintained checks; Spike independently executed the final
adversarial fixture across both targets after both components were ready.
No accounting fork, normalization, invented source identity or analyzer change.
WASM and browser presentation are outside this repair's qualification.

**Acceptance Criteria:**

- Preserve bounded valid UTF-8/Unicode identity, NUL rejection and exact caller text
  through target-appropriate representations. A blind `String` alias does not
  establish byte/text parity. Consolidate the primary corpus validator rather
  than copy its logic into a browser adapter.
- Decouple declaration-only intake from unnecessary acoustic implementation
  dependencies while keeping one primary source-mapping, coverage, contribution
  and training-admission implementation. Preserve valid native results and
  failure categories; repair demonstrated malformed-byte admission.
- Execute meaningful native and actual pas2js cases for Unicode/text rejection,
  duplicate and derivative mappings, unknowns, partitions, detached arrays and
  exact-integer multiplication/addition boundaries. Declare unsupported versus
  future WASM scope; compilation alone is insufficient.

**Blockers**

- None beyond the maintained corpus intake contract. The native contribution
  batch can finish independently; the full primary analyzer is outside this scope.

**Dev Notes:**

- 2026-10-27 acceptance: checked stable FPC 3.2.2 Win32/Win64 text fixtures pass 18
  cases and the existing corpus fixture, with zero leaks. Big Boss's checked
  Win64 corpus, 29 intake and 50 native file/WFC learner checks pass, zero leaks.
  Actual pas2js/Node passes 14 text and the same 29 intake checks. Spike's
  independent Win64 and actual pas2js/Node adversarial fixture has identical
  UTF-8 identity/accounting stdout after newline normalization, with zero native
  leaks. It covers BMP/astral ordering, noncharacters, non-normalized identity,
  Unicode-vs-ASCII edge whitespace, byte budgets, malformed target encodings,
  detached definitions, derivative/unknown union, duplicate weighting,
  exposure/history rejection and exact-integer product/sum boundaries.
  Evidence is under `E:/CodexWork/pythian/runs/text-portability-20261027-{boss,spiegel,spike}/`.
  The [maintained target check](../../../tools/check-corpus-portability.ps1)
  runs the three Pascal fixtures with supplied matched RTL and propagates
  runtime failure status. The normal native build registers them as well.
  Test-only `StdErr`/`Halt` portability and multiple Node path resolution were
  repaired during integration. The native file/WFC consumer retains its
  source/admission/model behavior. No private recording, live review service,
  operator answer or browser audio was changed. Zero additional credit.
- 2026-10-27, Big Boss repair decision: before implementation, Spike's stable
  FPC3.2.2 native probe and Spiegel's stable/development probes found that the
  old `UTF8Encode(UTF8Decode(text)) = text` check admits malformed bytes,
  including overlong NUL, encoded surrogate, above-Unicode scalar and `FF`.
  Those bytes cannot preserve identity as browser Unicode text. Stop evidence
  is retained in each helper's E-drive `text-portability-20261027-*` directory.
  The user's explicit removal of inferior behavior and no backwards
  compatibility requirement authorizes a scoped primary-validator repair:
  preserve every valid Unicode scalar and exact identity without normalization,
  reject malformed UTF-8 natively and unpaired UTF-16 in pas2js, and enforce
  the same 4096 UTF-8-byte budget. Valid noncharacters are not malformed.
  This intentionally changes formerly defective native acceptance; do not
  claim otherwise. No musical credit or scientific counter reset follows.
- 2026-10-27, Spike / Big Boss: the independent contribution fixture compiles
  and passes checked Win64 boundaries, but actual `pas2js -Tnodejs` compilation
  fails at `pythian.corpus.intake.pas` with `identifier not found UTF8String`.
  No substitute runtime, text alias or duplicate algorithm was used. Commands
  and exact error remain under `E:/CodexWork/pythian/runs/spike-20261027/`.
  This discovered gap is recorded before expanding scope; return to finishing
  the current native vocabulary contribution/consumer batch.
