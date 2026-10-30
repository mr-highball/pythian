# NS-6_portability_14 — Provide shared bounded resizable byte streams

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Actual pas2js journal cancellation/recovery reaches the installed RTL memory
stream's shrink path: its buffer reallocation copies a larger view into a
smaller allocation and raises `RangeError: offset is out of bounds`. A large
incomplete record cannot recover to the valid172-byte header with that provider.
Native32/64 pass the unchanged case. Keep this failure; do not reduce the input,
skip recovery, patch generated JavaScript or edit the toolchain dependency.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit: 0 additional.
This demonstrated prerequisite belongs to [retained interiors04](../RETIRED/2026-10-29/NS-6_observability_04.md).
Big Boss owns implementation and verification solo. Deliver a primary portable
bounded mutable byte stream and shared read/seek behavior for the existing
borrowed read-only byte view. Caller-supplied streams still own their I/O and
truncate contracts; an arbitrary broken provider cannot promise recovery.
Closing evidence: actual native32/64/pas2js storage and journal consumers, original
canonical bytes, all-checkpoint abort/reopen/recovery and clean exact published
and extracted consumers. Stop on alias, size/cursor, byte or recovery drift.

Accepted2026-10-29 at `d68895fbde1ed4f23634abccbec8efb4e32d23b4` after
[CI489](https://github.com/mr-highball/pythian/actions/runs/40932461993/job/123654180480)
completed successfully: native job19m48s, integration18m41s/extracted consumers45s.
Every original criterion and prerequisite passes. Big Boss verified solo;
this is not independent review. Native32/64 and actual pas2js each pass70039
storage checks and74356 journal intake checks/102 original observer aborts.
The full large journal checksum below remains exact. Original384 journal/
identity/binding,38 stream-byte and55 WAV controls pass on all three targets;
native integrity/recovery and zero-leak checks pass.

Clean exact Win64 core/full packages pass107/159 owned units and120/280 content
hashes. Core ZIP SHA256
`45686d9c505d020e985beb8bd52e3c786b6b610d67e968aaf77e23b255a351fe`;
full `4128493f51b6b87d4d34cb19baa0ed0824aeebd9a23260e84bce5bec08d41d33`.
Both new public API consumers also execute from extracted core sources only on
native32/64 and actual pas2js, with the same70039/74356/102 results and checksum.
The actual native worker passes382 original checks, zero leaks, retaining its
320044-byte WAV SHA256
`fea82882480eceae982305a79487e91eecbcc281f6a9c27c8746bab3e6409c07`.
Browser assets compile; actual browser/phone presentation, deployment, whole
parent04 and musical acceptance remain open. No completion points are added.

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

- [Shared journal/stream portability12 — DONE](NS-6_portability_12.md).

**Dev Notes:**

- 2026-10-29, Big Boss: exact published CI489 and clean extracted consumers
  qualify all original task14 criteria. Counts54open/92DONE/146→53open/93DONE/146,
  NS6 16→15 open;52.45/47.55 unchanged. Whole required task closure keeps delivery
  nonclosing at0; scientific stops/exposure histories never reset. Parent04
  retains construction/index, nested read forwarding, duration/scheduler and
  other retained-operation boundaries. Actual Studio18 remains separate. The
  original external RTL crash and repaired native32 implementation failure stay
  recorded; neither input nor acceptance assertions were reduced.

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
