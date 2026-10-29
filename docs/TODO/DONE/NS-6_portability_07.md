# NS-6_portability_07 — Validate caller-codec UTF-8 bytes on every target

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Original gap (repaired at the accepted checkpoint below):

Actual pas2js compilation of the named-voice preparation consumer fails in
`TProviderCodecAdmission.DecodeChoice`: native `Move` converts the caller's
canonical UTF-8 payload bytes into a native string before validation. A byte
array is not UTF-16 text on the browser target. Fix this in the primary shared
text contract and admission path, preserving payload bytes and original policy.

Execution status: **Accepted 2026-10-28** at Pythian
`d37072302436b3b8b2e95f6bab1ac2b0571afd5f`, after exact published integration,
clean extracted core/full consumers and the native/actual pas2js gates below.
All criteria and prerequisites pass at this engineering scope. No musical,
browser/device or independent-use credit follows.

North star: NS-6. Outcome owner: REUSABLE-OPERATIONS. Completion credit:0 additional.
Big Boss works solo. This repair adds no musical or independent-use acceptance.

**Acceptance Criteria:**

- Share canonical UTF-8 scalar decoding between existing native scalar text and
  direct byte-array validation. Preserve empty/NUL policy, byte caps, malformed
  rejection and no normalization. Keep UTF-16 scalar text behavior on pas2js.
- Caller-codec admission validates original detached canonical payload bytes on
  native and actual pas2js, without `Move`, a host decoder or encoding changes.
  Preserve reservations, callback ownership/original exceptions, unknown flags
  and canonical token round-trip. Include BMP/astral, malformed/overlong/surrogate,
  exact byte cap, empty/NUL and original cancellation controls.
- Existing native codec/scalar controls, actual portable voice consumer,
  published integration and clean extracted core/full consumers pass. Preserve
  failures and repair incoming links/accounting together before moving to DONE.

**Blockers**

All prerequisites below are accepted. Their discovery descriptions are historical.

- [Portable tempo-evidence codec](NS-6_portability_08.md) — the actual voice
  consumer next reaches a separate native Move; shared byte checks already pass.
- [Shared primary scalar text — DONE](NS-6_metadata_01.md).

**Dev Notes:**

- 2026-10-28, Big Boss accepts all criteria after exact
  [CI471](https://github.com/mr-highball/pythian/actions/runs/40789537394) succeeds: native job
  12m43s, maintained integration 11m39s and extracted consumers 40s. Clean exact Win64 core 107
  owned/120 inventory and full 159 owned/280 inventory packages pass. Native passing logs report
  zero leaks. Full named-voice construction/generation/retry passes 13939 checks/10 original
  abort-retries/13396 callbacks on Win32/Win64 and actual pas2js. Win32/Win64 and actual pas2js pass
  340 checks/3 original abort-retries/178 callbacks for original canonical payload bytes, including
  BMP/astral extremes, malformed/overlong/surrogate/truncated forms, empty/NUL and exact caps.
  Native scalar 73, portable 65 and original native caller-codec 231 controls remain qualified.
  Admission retains reservations, unknown flags, canonical tokens, detached results, original
  exceptions and same-context retry without renewing spent budgets. Preserve the rejected compiles
  and CI470 cadence failure; its repair retains exactly 1885 model/profile callbacks under the
  unchanged 2000 bound, reporting primary measurement 1078 and UTF-8 160 separately. Both native
  targets pass 57 checks with zero leaks. Evidence: dedicated E-drive
  archive-portability-20261028-boss, voice-integration-20261028-boss and
  wfc-voice-progress-20261028-boss packets. Incoming links/accounting move together; completion
  remains 52.45, with no scientific counter reset.

- 2026-10-28, Big Boss: linked09/10 repairs now permit the full actual portable
  named-voice preparation consumer to execute13939 checks/10 original aborts/
  13396 callbacks. Native caller/scalar and340/3/178 byte-admission results remain
  retained. New source still needs exact published integration and extracted
  consumers before this task can move; no percentage or counter reset follows.

- 2026-10-28, Big Boss local repair: primary UTF-8 byte validation reuses the
  same decoder as native scalar text. Caller admission removes its private
  Move/string conversion and validates the original bytes. Win32/Win64 and
  actual pas2js each pass340 checks/3 original abort-retries/178 callbacks,
  including scalar extremes, malformed/overlong/surrogate/truncated bytes,
  explicit empty/NUL and byte caps, detached payloads, retained output and
  same-admission retry without renewing spent budgets. Native scalar73 and
  portable65 controls pass; original native caller codec231 passes with zero
  leaks. Actual full voice compile still reaches separate08/09, so do not
  accept this task yet. The pitch adapter's transitive-type compile failure
  is repaired with the existing canonical TWfcModelToken import, not a codec.

- 2026-10-28, Big Boss: actual pas2js voice preparation compile rejects
  `pythian.wfc.provider.codecs.pas` line467, identifier Move. Preserve the
  rejection in the dedicated E-drive voice-integration-20261028-boss packet.
  The native voice fixture also wrongly expected an interior capacity callback
  from a short scan; repair its test point, retaining production cadence.
  Stop further voice scope expansion, record this zero-credit prerequisite,
  then repair the shared byte validation before returning to task17. Counts
  become54 open/82 DONE/136 total, NS6 16 open;52.45/47.55 and delivery entry2
  remain unchanged until real acceptance. Upstream WFCc4e7569/CI56 is live;
  its generic fix and the Pythian candidate pin are not yet accepted.
