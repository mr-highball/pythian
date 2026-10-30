# NS-6_observability_05 — Observe and cancel retained corpus archives

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Make retained acoustic-corpus serialization and reconstruction observable through
the primary Pascal implementation and the maintained archive operator. This is a
bounded retained artifact, not the journal-based many-hour semantic pipeline.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
Accepted 2026-10-27: optional primary callbacks and Pythian WFC adapter/CLI
forwarding pass checked FPC 3.2.2 Win32/Win64 and independent focused QA.
All 11,712 final capped-fixture checks pass on both targets, with zero leaks.
The maintained WFC corpus fixture covers adapter abort/retry and model/audio
replay. Big Boss's comparison with `e0049c8` preserves exact archive bytes,
inspection JSON and saved-model rendered WAV. Spike implemented the archive
component; Spiegel independently reviewed and executed it, and Big Boss owns
integration/final judgment. No format, scientific or musical acceptance change.
Closing evidence: exact bytes/replay, interior abort/retry, checked native
consumers and measured workload/cadence. Stop on invented percentages, changed
scientific results or expansion into companion source.

**Acceptance Criteria:**

- AC1: Add optional shared callbacks to primary archive encode/decode and nested
  corpus validation. Count actual serialized features, copied/hash bytes and
  validated items. State remaining synchronous boundaries and work limits;
  neither a static cap nor an end callback establishes elapsed-time guarantees.
- AC2: Forward callbacks through the Pythian WFC corpus adapter and maintained
  archive CLI. Keep companion internals and durable file publication distinct
  from completed core stages; retain parseable stdout and input ownership.
- AC3: Verify identical nil/observed archive bytes, decode/re-encode identity,
  model replay, unchanged source bytes, interior feature/hash/validation abort,
  exact exception propagation, cleanup and successful retry. Exercise a
  substantial authored corpus/attachment with measured counts and cadence on
  checked native Win32/Win64, and execute the maintained CLI.

**Blockers**

- [Shared callbacks and audit — DONE](NS-6_observability_01.md).

**Dev Notes:**

- Final authored workload: 65,536 features and a 1-MiB opaque attachment.
  Encode reports 257 feature callbacks and 17 attachment callbacks; decode
  reports 258 feature, 257 validation and 17 attachment callbacks. Features and
  validation use 256-item checkpoints, attachments 64-KiB blocks, existing SHA
  8-KiB blocks. Decode feature totals remain unknown until counted. Native
  Win32/Win64 output agrees. Independent pre-integration core runs pass 10,104
  checks; Big Boss's added unit/cadence assertions bring the final total to
  11,712. These counts describe this workload, not performance or musical quality.
- Archive QA submission 1 failed because `ValidateWfcCorpusModel` was wrongly
  called a generic companion boundary. It is Pythian-owned. The repaired second
  submission reports actual lookup entries (4,096 cadence), state items across
  its two passes (256 cadence) and corpus tokens (256 cadence). Independent
  re-review passes with exact exception propagation, nil failed-decode model,
  unchanged inputs and retry. One failed formal submission, no transfer threshold.
  Maintained regression uses order four and a 512-token authored case; Big Boss
  added explicit observed encode replay after each abort as well as decode retry.
- Actual old/new native CLI proof uses one authored source and unchanged recipe:
  7,658-byte archive SHA `d06967d0e62d9a6c349e62dfda7eb51fd00997e993b8932728ed67b53fc21727`;
  inspection JSON and 1,045,548-byte remix WAV also match byte for byte.
  The CLI sends new named counts to stderr, retaining its stdout contract.
  No audio was played. All valid checked native consumers report zero leaks.
- Remaining synchronous work includes allocation/whole-array copies, small
  bounded metadata and generic companion learning/text operations. There is no
  maximum cancellation-latency promise. Existing CLI file writes are direct and
  non-atomic; a completed callback is not durable publication. The archive cap
  remains 32 MiB, attachment 16 MiB and features 65,536. This does not qualify
  many-hour semantic persistence, actual browser presentation or pas2js archives.
- Evidence: dedicated E-drive `build/tests/runs/archive-progress-20261027-*`
  and `runs/retained-progress-20261027-{boss,spiegel-qa}/`. Root baseline/current
  artifacts, checked commands, counts, source hashes and private-state check are
  retained in the boss manifest. Only test measurement/retry additions followed
  the accepted product source; independent source review covers those additions.
- 2026-10-27, Big Boss: independently useful split from
  [observability_04](../RETIRED/2026-10-29/NS-6_observability_04.md), original AC1 corpus/archive
  serialization/validation and its consumer/replay/cancellation portions of AC5.
  No credit is transferred or added. Original retained-style/provider, batch
  evaluation and inference obligations remain there; composition has its own
  [consumer task](NS-6_observability_06.md). No generic WFC defect is demonstrated.
