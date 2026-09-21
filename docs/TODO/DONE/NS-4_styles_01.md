# NS-4_styles_01 — Persist reusable semantic providers and joint evidence

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-4)

**Description:**

Extend the current immutable style contract to the supported harmonic, groove, role, phrase and sound providers without adding permanent historical format branches.

North star: NS-4. Outcome owner: WFC-STYLE.
Completion credit: 4 goal percentage points (0.60 overall points).
Credit is earned only when every acceptance criterion and the task-flow completion requirements pass.

Starting evidence: [WAVE-STYLE](../../WAVE-STYLE.md) · [LAYERED-STYLE](../../LAYERED-STYLE.md) · [CONTEXT-PROFILES](../../CONTEXT-PROFILES.md).

Infrastructure review 2026-09-21 identified an unresolved part of derivative
evidence acceptance: the draft source ledger records exact asset hashes/groups
and source-relative runs, but no parent-coordinate/preparation mapping or required
hash-bound audit. Two differently encoded overlapping excerpts can therefore be
replayed as separate contributions without retaining evidence of that overlap.
Passing current round-trip fixtures does not cover this case. This remains within
the existing task allocation and acceptance criteria, with no duplicate task.

Completed 2026-09-21 after repair: the primary agent added direct original identity/clock
and excerpt mapping, retained preparation bytes bound to both asset geometries,
and exact original-coordinate contribution auditing. Distinct encodings cannot
double-contribute overlapping material to a provider; explicit run weights retain
intentional repetition. Source/derived reload, fractional resampling boundaries,
contradictory lineage and missing evidence have focused native controls. Checked
stable FPC 3.2.2 Win32/Win64 final QA passed all criteria, including actual WFC
model replay, joint evidence, detached ownership, exposure, corruption/bounds
and original/reloaded sound hash equality. Commands, source hashes and zero-leak
logs are retained under `build/qa-batch-06/` and `build/semantic-provenance/`.
The [maintained semantic adapter](../../SEMANTIC-STYLES.md) keeps one current
format. Actual listening, recorded provider accuracy and genre quality remain
unassessed here. Accept the original +4 NS-4 points (+0.60 overall); the two
previous failed delegated submissions and ownership transfer remain historical.

**Acceptance Criteria:**

- Persist supported per-layer models, choices, dependencies, vocabulary/time contracts, unknowns, evidence, extraction policies and source identities; absent dimensions remain explicit.
- Retain observed cross-layer relationships and independent source/run/gap boundaries rather than rebuilding joint evidence from marginal selections.
- Bind corpus split/exposure and derivative/source-contribution evidence sufficiently for later reuse audits, including frozen vocabulary ancestry and external source requirements.
- For declared derivatives, retain parent identity/clock, mapped contribution
  ranges and preparation/audit identity, or require an exact hash-bound external
  audit with fail-closed verification at reuse. Verify overlapping versus disjoint
  differently encoded excerpts, missing/mismatched audit evidence, retained
  exposure and exact source/derived round trips. Intentional repeated contributions
  must be explicit; automatic discovery of recording relationships is not required.
- Round-trip a source style and a derived style with identical supported generation behavior; enforce ownership, bounds, corruption and incompatible-contract rejection.
- Keep one current format per artifact, regenerate superseded development fixtures and remove transitory readers unless a concrete consumer value justifies retention. Controlled inputs may establish this contract; recorded accuracy is credited elsewhere.

**Blockers**

- [NS-4_layers_03.md](NS-4_layers_03.md)
