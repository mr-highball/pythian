# NS-6_delivery_03 — Package and verify the accepted final workflow

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Deliver current source packages and reproducible examples for the accepted synthesis, WAV learning, semantic generation and three-style blend workflow.

North star: NS-6. Outcome owner: WAV-05-DELIVERY.
Completion credit: 12 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [PACKAGING](../PACKAGING.md) · [packaging/README](../../packaging/README.md) · [PROVENANCE](../PROVENANCE.md).

**Acceptance Criteria:**

- Package exact accepted core and companion source closures, full notices, supported examples and explicit external asset/model requirements; exclude ignored development recordings and stale formats.
- From fresh extraction, build and exercise the accepted workflow on the declared target matrix, including the affected remote CI path; earlier snapshots cannot stand in for changed source.
- Verify inventory hashes, reload/generation/blend/reblend, granular controls, deterministic behavior and the documented failure/recovery guarantees outside the development checkout.
- Ensure no absolute workspace paths, removed Phanes dependencies, hidden caches or unpublished private inputs are needed for the documented reproducible consumer.
- Record final artifact identities and known limitations. Physical I/O atomicity, device real-time behavior or external asset redistribution must not be implied beyond their declared contracts.

**Blockers**

- [NS-6_delivery_02.md](NS-6_delivery_02.md)
- [NS-4_integration_01.md](NS-4_integration_01.md)
- [NS-5_blends_01.md](NS-5_blends_01.md)

