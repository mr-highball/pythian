# NS-4_motif-coupling_01 — Keep selected pitch motifs compatible with musical context

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

The Studio editor exposes a required gap beyond the accepted controlled motif.
A normal eight-note manual melody in A minor produces a valid paired harmony/
rhythm context, and those projected inputs solve independently, but the named
instrumental graph contradicts them at harmony. The context can recombine
musically valid marginals without retaining enough information about the selected
part's pitch sequence. Preserve the selected motif's musical relationships while
leaving the other instrumental roles generated through WFC.

Primary attribution: NS-4. This is demonstrated musical adaptation in Pythian;
no generic WFC defect has been demonstrated. More seeds, larger search limits,
silently relaxed constraints and pinning every part are not the deliverable.

**Acceptance Criteria:**

- AC1: Retain the selected part's pitch/context relationship in real providers
  and dependency edges. Document the actual vocabulary and conditional scope;
  independently generated other parts must remain real graph decisions.
- AC2: The discovered A-minor eight-note case and accepted/corrected recording
  motif generate six-part instrumental plans within declared limits. Exercise
  representative context/role changes, deterministic replay, explicit rejection,
  cancellation and preservation of preceding accepted plans.
- AC3: Ordinary Studio edit/save/generate consumes the repaired shared path and
  reports useful contradictions. Validate native and actual pas2js consumers and
  the real browser path. Do not silently regenerate or retrain on Save.

**Blockers**

- [Joint context — DONE](DONE/NS-4_joint-context_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: Required prerequisite for
  [experimental learning AC3](NS-3_experimental-learning_01.md). Preserve the
  actual failed Studio job, desktop screenshot and Pascal diagnostic under
  musical-editor-20261030-boss in the dedicated E-drive roots. Exact case:
  root9/natural_minor, lead MIDI60,62,64,67,64,62,60,55, velocity80 and attacks,
  16 cells, seed731. Context and independent projected H/R solve; named graph
  returns gnsContradiction at harmony. Earlier joint-context acceptance remains
  scoped to its recorded controlled motif and original budgets.
- Before implementation, identify the audible criterion, usable deliverable,
  relevant evidence and stopping point. Return to the existing Studio task after
  this concrete prerequisite; corpus/form/blends remain separately scoped.
