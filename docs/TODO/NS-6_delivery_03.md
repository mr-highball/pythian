# NS-6_delivery_03 — Package and verify the accepted final workflow

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Deliver current source packages and reproducible examples for the accepted synthesis, WAV learning, semantic generation and three-style blend workflow.

North star: NS-6. Outcome owner: WAV-05-DELIVERY.
Completion credit: 12 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../PACKAGING.md) · [packaging/README](../../packaging/README.md) · [PROVENANCE](../PROVENANCE.md).

Integration constraint updated 2026-09-22: the former Win64 external-runtime
path is historical; [practical Pascal inference](DONE/NS-3_validation_02.md)
is accepted. The final workflow must preserve the
[full stable target contract](../CONSUMER-CONTRACT.md#compiler-target-and-dependency-scope)
and exercise every required Pascal producer on each declared target. Private
precomputed observations cannot stand in for reproducible final delivery. This
remains existing delivery scope, not extra completion credit.

**Acceptance Criteria:**

- Package exact accepted core and companion source closures, full notices, supported examples and explicit external asset/model requirements; exclude ignored development recordings and stale formats.
- From fresh extraction, build and exercise the accepted workflow on the declared target matrix, including the affected remote CI path; earlier snapshots cannot stand in for changed source.
- Verify inventory hashes, reload/generation/blend/reblend, granular controls, deterministic behavior and the documented failure/recovery guarantees outside the development checkout.
- Ensure no absolute workspace paths, removed Phanes dependencies, hidden caches or unpublished private inputs are needed for the documented reproducible consumer.
- Record final artifact identities and known limitations. Physical I/O atomicity, device real-time behavior or external asset redistribution must not be implied beyond their declared contracts.

**Blockers**

- [NS-6_delivery_02.md](DONE/NS-6_delivery_02.md)
- [NS-3_validation_02.md](DONE/NS-3_validation_02.md)
- [NS-4_integration_01.md](NS-4_integration_01.md)
- [NS-5_blends_01.md](NS-5_blends_01.md)

**Dev Notes:**

- Integration follow-up: the former external-runtime adapter was Win64-only and is no longer supported. Final packaging must exercise the accepted Pascal-only producer on the declared target matrix; private cached observations cannot replace it. See [target contract](../CONSUMER-CONTRACT.md#compiler-target-and-dependency-scope).

- The [earlier native checkpoint](DONE/NS-6_delivery_02.md) covers its frozen source revision. Its Linux artifact-content inspection was limited by an unauthenticated-download 401; retain that evidence boundary when qualifying final packages.
