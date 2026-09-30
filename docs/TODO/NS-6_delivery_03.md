# NS-6_delivery_03 — Package and verify the accepted final workflow

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Deliver current source packages and reproducible examples for the accepted synthesis,
WAV learning, semantic generation and arbitrary user-defined style blend/reblend workflow.

North star: NS-6. Outcome owner: WAV-05-DELIVERY.
Completion credit: 10 goal percentage points (1.00 overall points).
Current complete-goal allocation, 2026-09-29, with NS-6 weighted at 10 overall points,
under the user's authorization
to rebalance without preserving historical point allocations. All existing
acceptance criteria remain required; this plan revision earns no acceptance.
Allocation rationale: The complete reproducible synthesis, WAV-learning and style/blend workflow needs its own verified delivery closure.
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../PACKAGING.md) · [packaging/README](../../packaging/README.md) · [PROVENANCE](../PROVENANCE.md).

Integration constraint updated 2026-09-22: the former Win64 external-runtime
path is historical; [practical Pascal inference](DONE/NS-3_validation_02.md)
is accepted. The final workflow must preserve the
[full stable target contract](../CONSUMER-CONTRACT.md#compiler-target-and-dependency-scope)
and exercise every required Pascal producer on each declared target. Private
precomputed observations cannot stand in for reproducible final delivery. This
remains existing delivery scope, not extra completion credit.

Execution status: blocked by the unaccepted full workflow prerequisites below.
Next deliverable: package the frozen accepted synthesis/learning/style/operator
closure and verify fresh extracted consumers on the declared target matrix.
Closing evidence: exact source/input inventories, hashes, target/CI commands,
reload/generation/blend/reblend results and limits. Stop at an unaccepted
prerequisite or nonreproducible input and follow its owning task.

**Acceptance Criteria:**

- Package exact accepted core and companion source closures, full notices, supported examples and explicit external asset/model requirements; exclude ignored development recordings and stale formats.
- From fresh extraction, build and exercise the accepted workflow on the declared target matrix, including the affected remote CI path; earlier snapshots cannot stand in for changed source.
- Verify inventory hashes, reload/generation/blend/reblend, granular controls, deterministic behavior and the documented failure/recovery guarantees outside the development checkout.
- Ensure no absolute workspace paths, removed Phanes dependencies, hidden caches or unpublished private inputs are needed for the documented reproducible consumer.
- Record final artifact identities and known limitations. Physical I/O atomicity, device real-time behavior or external asset redistribution must not be implied beyond their declared contracts.

**Blockers**

- [NS-6_delivery_02.md](DONE/NS-6_delivery_02.md)
- [NS-6_authoring_01.md](NS-6_authoring_01.md)
- [NS-6_authoring_02.md](NS-6_authoring_02.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)
- [NS-4_integration_01.md](NS-4_integration_01.md)
- [NS-5_blends_01.md](NS-5_blends_01.md)

**Dev Notes:**

- 2026-09-29 current complete-goal credit basis: this task owns 10 NS-6
  goal points (+1.00 overall) by deliverable value. Nine open NS-6
  tasks allocate 85 goal points (+8.50 overall); the accepted contract and
  native checkpoint allocate 15 goal points (+1.50 overall), with zero baseline.
  Lifecycle support and actual ecosystem adoption are now explicit required
  outcomes. Earlier point amounts and conserved split totals are historical,
  superseded by this user-directed scope reassessment. Criteria and evidence
  requirements remain intact; planning earns no acceptance.


- 2026-09-29 owner mapping: all five original packaging criteria remain here
  in their original order and full scope. delivery_06 owns a distinct current
  minimal consumer artifact and cannot substitute for final-workflow acceptance.
  Next deliverable: freeze the accepted provider/style/operator workflow,
  stage its exact source/input closure and exercise the extracted package on
  the declared targets and changed remote CI path. Closing evidence is the
  source/artifact inventory, commands, hashes, replay/blend/reblend outcomes
  and scoped limitations. Stop when a prerequisite is unaccepted or an input
  is not reproducible; follow its owning task rather than substituting cached
  private observations or a genre-specific shortcut.
- Historical allocation, 2026-09-25: the user-required Pascal/pas2js annotation workbench is split as
  an independently usable tool before final package verification. This task
  retains accepted-workflow packaging and remote-consumer checks, including
  the workbench's native service and compiled browser assets. The then-original
  +12 NS-6 points were split as +4 authoring and +8 final delivery; no credit is
  earned by task creation.
- Integration follow-up: the former external-runtime adapter was Win64-only and is no longer supported. Final packaging must exercise the accepted Pascal-only producer on the declared target matrix; private cached observations cannot replace it. See [target contract](../CONSUMER-CONTRACT.md#compiler-target-and-dependency-scope).

- The [earlier native checkpoint](DONE/NS-6_delivery_02.md) covers its frozen source revision. Its Linux artifact-content inspection was limited by an unauthenticated-download 401; retain that evidence boundary when qualifying final packages.
