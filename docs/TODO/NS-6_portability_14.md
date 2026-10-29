# NS-6_portability_14 — Provide shared bounded resizable byte streams

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Actual pas2js journal cancellation/recovery reaches the installed RTL memory
stream's shrink path: its buffer reallocation copies a larger view into a
smaller allocation and raises `RangeError: offset is out of bounds`. A large
incomplete record cannot recover to the valid172-byte header with that provider.
Native32/64 pass the unchanged case. Keep this failure; do not reduce the input,
skip recovery, patch generated JavaScript or edit the toolchain dependency.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This demonstrated prerequisite belongs to [retained interiors04](NS-6_observability_04.md).
Big Boss owns implementation and verification solo. Deliver a primary portable
bounded mutable byte stream and shared read/seek behavior for the existing
borrowed read-only byte view. Caller-supplied streams still own their I/O and
truncate contracts; an arbitrary broken provider cannot promise recovery.
Closing evidence: actual native32/64/pas2js storage and journal consumers, original
canonical bytes, all-checkpoint abort/reopen/recovery and clean exact published
and extracted consumers. Stop on alias, size/cursor, byte or recovery drift.

Local implementation now passes70039 storage checks and74356 journal intake
checks/102 original observer aborts per target on native32/64 and actual pas2js.
The large case retains its frozen full journal checksum below. Original384
journal/identity/binding,38 stream-byte and55 WAV controls also pass on all three
targets; native recovery/integrity and zero-leak checks pass. Exact published
and extracted qualification remain pending; this task stays OPEN.

**Acceptance Criteria:**

- Supply one primary Pascal byte-stream implementation for owned bounded
  mutable storage and borrowed read-only views, sharing their read/seek logic.
  Keep only raw-buffer I/O bridges conditional; no browser API, native-only
  storage algorithm, generated-code patch, dependency edit or parallel journal
  implementation. Native raw-buffer copying is I/O, never shared resize logic.
- Validate bounds before changing bytes, size or cursor. Cover growth, shrink,
  zero-filled gaps and regrowth, seek/read/write/resize failure, empty streams,
  detached snapshots and explicit ownership/allocation limits. Preserve the
  existing borrowed read-only contract and canonical codec bytes.
- Execute the full large-journal case on native32/64 and actual pas2js, including
  truncation from more than65536 bytes to the valid172-byte header, recovery
  after every emitted observer abort, original exceptions and failure/retry
  publication rules. Preserve the original runtime failure separately; compiler
  success, smaller cases or accepting that crash cannot substitute.
- Qualify actual primary consumers and clean extracted core/full packages at
  the exact published source. Keep actual browser/phone and full parent04 gates
  separate; no musical acceptance or completion points follow from this repair.

**Blockers**

- [Shared journal/stream portability12 — DONE](DONE/NS-6_portability_12.md).

**Dev Notes:**

- 2026-10-29, Big Boss: the primary owned byte stream retains bounded capacity
  while separating logical size/cursor, zeroes regrowth/gaps and returns detached
  snapshots. The existing borrowed view shares its read/seek implementation.
  Both native raw-buffer overloads forward to the shared wide resize; thin
  native buffer copying remains I/O. The large journal fixture now uses this
  primary provider on every target, preserving the full failing input, all
  recovery/cancellation checks and original native checksum. The broken external
  RTL provider remains recorded rather than silently declared repaired.
- 2026-10-29, Big Boss: checked native32 initially selected the inherited silent
  LongInt resize overload, leaving no backing bytes before write. The private
  full-assertion diagnostic locates the range failure at the raw write bridge.
  Explicit wide dispatch and a native overload forwarding shim repair the actual
  primary owner; an external descendant's Integer resize now has a regression
  on all targets. Preserve the first range-error log/diagnostic. No assertion is
  removed or weakened, and no scientific counter or credit changes.
- 2026-10-29, Big Boss: journal-intake-20261029-boss private E-drive packet
  retains the actual pas2js failure in `TMemoryStream.Realloc`/`SetCapacity`/
  `SetSize` during `RecoverTail`. The unchanged large fixture passes74355 checks/
  102 observer aborts on both native targets, zero leaks, journal SHA256
  `95c3bf82c28af1f9e4d75a06f12deaa9546f94053d5d39219346b820686f4759`.
  Original384 journal,38 stream and native journal recovery controls still pass.
  New API consumer qualification remains open. Creating this task grants no
  credit, closes no parent criterion and resets no counter or scientific stop.
