# NS-6_support_01 — Establish maintained library support and update use

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Turn a usable source snapshot into a maintained supported library surface.
Declare the supported public APIs, targets and artifact scope, make changes and
regeneration understandable to callers, and demonstrate a real outside-user
update or issue-resolution cycle. This owns lifecycle support across the final
native synthesis/learning/WFC workflow, rather than another isolated example
build. It does not promise a permanent ABI or every historical artifact reader.

North star: NS-6. Outcome owner: DELIVERY-SUPPORT.
Completion credit: 10 goal percentage points (1.00 overall points).
Allocation-time basis: 2026-09-29; NS-6 weight 10, zero baseline, then 15
accepted goal points and 85 open goal points. Current accepted totals belong to
[milestones](../MILESTONES.md#ns-6). This required outcome earns no
acceptance from its creation. Its value is a supportable public library and an
observed successful maintenance cycle, not documentation volume.
Credit is earned only when every acceptance criterion and task-flow completion
requirement passes.

Starting evidence: [consumer contract](../CONSUMER-CONTRACT.md) ·
[packaging](../PACKAGING.md) · [minimal package](DONE/NS-6_delivery_06.md) ·
[full delivery](NS-6_delivery_03.md) · [independent use](NS-6_delivery_04.md).

Execution status: open; the minimal package is accepted, while complete
acceptance remains blocked on full delivery and actual outside users.
Policy and inventory preparation can begin using
current contracts. Next deliverable: a supported public inventory/update policy
and an outside-user upgrade or issue-to-fixed-package cycle. Closing evidence:
exact versions, APIs, instructions, user reproduction, maintained change,
focused regression and the revised delivered artifact. Stop at an unavailable
consumer, unsupported reproduction or unverified final scope; record its
unblock/repair owner rather than claiming support from a README alone.

AC2 preparation batch (2026-09-30): Big Boss assigned Neo the consumer contract
and this task only. Deliver one integrated caller procedure for pinning a
published snapshot, reviewing changes, rebuilding matched dependencies/assets,
regenerating affected current-format artifacts and reporting a reproducible
failure. Closing evidence for this documentation component is focused command,
link, meaning and privacy review against the accepted `bdd55eb` package and
existing scripts/consumer evidence. Stop at an unsupported command or missing
migration evidence; do not rebuild packages, execute media/inference or invent a
release/compatibility policy. AC2's actual upgrade/regeneration qualification,
AC4's real outside-user cycle and full task acceptance remain open pending their
evidence. This batch earns zero task credit and preserves existing counters.

**Acceptance Criteria:**

- AC1: Inventory supported public core, inference/tool and WFC interfaces,
  artifacts, examples and targets for the accepted minimal and full workflows.
  Distinguish public contracts from internal details/ignored studies. Document
  ownership, clocks, errors, budgets and current stability commitments with no
  hidden implementation knowledge needed by a caller.
- AC2: Declare an identifiable supported source version/distribution policy,
  change and deprecation communication, pinning/update procedure and artifact
  regeneration rules. Exercise a changed-contract upgrade or current-artifact
  regeneration where applicable. Keep one current native format per contract;
  any retained compatibility path needs a concrete consumer justification.
  Do not invent a permanent binary ABI or perpetual legacy-format promise.
- AC3: Provide usable reference docs/examples, exact package/input requirements
  and a public issue/reproducer/support route. Verify that an outside caller
  can identify their supported scope/version, report a reproducible problem or
  follow an update without private paths, hidden caches or undocumented assets.
  Full-workflow support must match delivery_03/04's accepted scope.
- AC4: Complete at least one actual outside-user maintenance cycle: either
  migrate their supported use across a published API/artifact change using the
  maintained update/regeneration instructions, or resolve their reproducible
  reported issue through an owned implementation/documentation fix. Record the
  maintained change, focused migration/regression evidence, revised verified
  package and successful caller recheck with exact source/package/consumer
  identities. Self-run fixtures, a simulated issue or an unchanged-version
  rebuild do not substitute for that cycle.
- AC5: Publish the supported handoff, known limits, unresolved request owners
  and maintenance responsibilities under the selected distribution policy.
  Material changes after package acceptance require affected-path revalidation;
  do not repeat unrelated suites. Actual publication/external messaging still
  follows its separate authorization, and no ecosystem adoption is inferred.

**Blockers**

- [NS-6_delivery_06.md](DONE/NS-6_delivery_06.md)
- [NS-6_delivery_07.md](NS-6_delivery_07.md)
- [NS-6_delivery_03.md](NS-6_delivery_03.md)
- [NS-6_delivery_04.md](NS-6_delivery_04.md)

**Dev Notes:**

- 2026-09-30 AC2 preparation, Neo: added
  [updating a pinned consumer](../CONSUMER-CONTRACT.md#updating-a-pinned-consumer)
  to the maintained consumer contract. It distinguishes moving `hello-pythian`
  from accepted `bdd55eb` archives, gives exact pinned-checkout/change-review
  commands, matched rebuild/current-artifact recreation instructions and failure
  report fields. Existing package/consumer evidence supports the authored v2
  save/reload/replay route; no old-model migration or real outside-user cycle
  was executed in this batch. Read-only verification of the public issue page
  found issue creation restricted, so the procedure requires an available
  agreed submission channel and does not claim AC3 outside access accepted.
  Salty's focused command/link/meaning/privacy review passes the exact submitted
  files and their public support-route limitation. No regeneration or migration
  execution is inferred from that documentation verdict.
  AC2 remains unclosed pending its complete qualification; AC4, full-workflow
  prerequisites and the full task stay open, with zero credit. No source,
  compiler, asset, package, media or inference execution/change was performed.

- 2026-09-29 Neo's completeness review found that AC4's initial wording required
  an upgrade to need correction. Main revised it to accept a successful real
  caller migration across an actual supported change, without manufacturing a
  defect. The external consumer, verified updated package and exact migration
  evidence remain mandatory; unchanged-version builds do not qualify.

- 2026-09-29 completeness audit: delivery_03/04 and the consumer contract prove
  one frozen distribution/use scope; they did not require a maintained update
  policy or real outside-user maintenance cycle. This task owns those missing
  outcomes without retroactively weakening their criteria or accepting new
  work. Full-package prerequisites apply to the final supported scope; they
  do not prevent preparing the public policy or recording an earlier minimal
  consumer issue. Stop at missing real-user evidence and keep acceptance open.
