# NS-5_scale_04 — Rebuild source-bound admitted-event contributions

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-5)

**Description:**

Persist independently supplied admitted pitch-duration contributions so a
multi-recording WFC model can be rebuilt after a completed journal reload or an
additional source. This is a reusable semantic recovery boundary ahead of the
many-hour, multi-provider workload in [NS-5_scale_02](../NS-5_scale_02.md).
Reference events exercise the mechanism; they are not Pythian WAV inference.

North star: NS-5. Outcome owner: CORPUS-SCALE.
Completion credit: 1 goal percentage point (0.20 overall points), transferred
from the original unearned 6 points of `NS-5_scale_02`. Together these tasks
retain the original 6 points / 1.20 overall points. Credit is earned only when
every criterion and the task-flow completion requirements pass.

Starting evidence: the accepted [admitted-event WFC bridge](NS-3_notes_06.md)
and its [Pascal adapter](../../../adapters/wfc/pythian.wfc.admitted.pitch.pas).

Accepted 2026-09-25: the maintained [Pascal contribution journal](../../../adapters/wfc/pythian.wfc.admitted.pitch.journal.pas),
[focused fixture](../../../tests/pythian.tests.wfc.admitted.pitch.journal.lpr)
and native build hook pass checked stable FPC 3.2.2 Win32/Win64 with zero
unfreed blocks. The versioned journal stores complete admitted source and
annotation identities, typed original-frame spans and fixed policy/order;
canonical sorting, exact duplicate idempotency, rejected replacement and
explicit 8-MiB, 32-source, 65,536-span and 32-run bounds pass. Its rebuild
calls the accepted WFC learner. A separately frozen private Pascal integration
verified three published URMP source/Notes pairs in two work groups, then
matched a clean build to persisted two-source reload plus third-source append.
Both targets replay the same 25 training runs, 28 training spans, seed-731
tokens and SHA-256 identities: journal
`fc5441d6115710b5b2f16606b1b7e9f84c95f971166a1fb0e5ab6cbebd56e7c3`,
model `b1783f16b1615f20e21099a8aeefbd28381f7838f7361715444faca1b466843f`,
evidence `3fefbf31767e046af33b823bdaf2366bb0f79b5f7da3509598ee04625c4a7338`
and tokens `a35c1bf5f05b0c3e806ef9f6bb910d41e2bc7a2701f3db8a6264d22e9b74ee17`.
Salty Boi independently rebuilt/replayed the fixture on both targets and found
no blocker. Private policy, exact commands, source identities and checked logs
are under ignored `build/admitted-journal-integration/` and
`build/admitted-pitch-journal/`. This accepts bounded reference-event
contribution replay only; it does not accept online updates, filesystem crash
durability, many-hour semantic training, inferred notes or musical quality.
Earned **+1 NS-5 / +0.20 overall**; NS-5 is **29%** and total **69.85%**.

**Acceptance Criteria:**

- Provide a current, versioned Pascal contribution-journal codec that retains
  source/group/recording identity, exact source and annotation hashes, geometry,
  annotation method, typed original-frame spans, explicit unknowns and policy
  identity. Bound encoded input and reject malformed or foreign data before use.
- Add sources in deterministic canonical order. An exact repeated contribution
  is idempotent; a changed source, annotation, identity or policy under an
  existing contribution is rejected without changing the accepted journal.
  Unknown/uncovered regions and recording boundaries never become transitions.
- Rebuild through the accepted WFC admitted-pitch learner. A clean complete
  build and a persisted/reloaded staged append of the same contributions must
  produce identical journal, model, evidence and fixed-seed generation bytes.
  A rejected append or decode must preserve the prior usable result. This is
  a bounded full rebuild, not an online model update or a claim of filesystem
  crash durability.
- Exercise at least two distinct source groups plus a third addition with
  source-bound reference events, and meaningful duplicate, conflict, unknown,
  corruption, capacity and failed-rebuild cases. Keep the bridge's current
  32-source, 65,536-span and 32-run limits explicit; no many-hour scale or
  recorded-inference result follows from this packet.
- Pass focused checked stable Win32/Win64 replay, ownership, bounded work and
  failure preservation. Keep the portable core independent of WFC and all
  maintained implementation and inference Pascal-owned.

**Blockers**

- [NS-3_notes_06.md — DONE](NS-3_notes_06.md)

**Dev Notes:**

- 2026-09-25 task-flow split: this task owns the reusable source-contribution
  journal, idempotent append and deterministic pitch-duration rebuild portion
  of original `NS-5_scale_02` criteria 2 and 3. That task retains full
  many-hour multi-provider training and budgets (criterion 1), process
  interruption/publication and reusable cache recovery (remainder of 2),
  incremental semantics across all required providers (remainder of 3),
  bounded ancestry/aggregation (4), and selective policy/vocabulary
  invalidation (5). Its original +6 NS-5 / +1.20 overall allocation becomes
  +1/+5 NS-5 and +0.20/+1.00 overall. The split itself earns no credit.
