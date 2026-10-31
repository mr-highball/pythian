# NS-4_motif-coupling_01 — Keep selected pitch motifs compatible with musical context

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Accepted — 2026-10-30
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

- [Joint context — DONE](NS-4_joint-context_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss: AC1–3 accepted. Canonical ctx2 choices retain the full
  synchronized symbolic ensemble and an explicit driven role. Actual WFC context
  decisions constrain harmony, rhythm and that selected part; the remaining two
  pitched parts stay unpinned and independently solved. Providers carry absolute
  MIDI identity and role order/identity. No source PCM becomes an instrument.
  Three conditional groups remain; no cross-group backtracking is claimed.
- Closing evidence under motif-coupling-20261030-boss in the dedicated E-drive
  roots: 1438 shared checks each on checked Win32/Win64 and actual pas2js, including
  the exact failed melody, lead/bass/harmony assignments, major/minor contexts,
  corrections, deterministic seeds, deep ownership, rejection, witness cancellation
  and preceding-plan preservation. Ordinary native generation passes43 checks on
  Win32/Win64, including recording-derived corrected motifs and Original lineage.
  Native heaps are clean; provider UTF checks340 and authored Studio checks41 pass.
  Fresh source-free authored PCM is byte-identical to the preserved baseline.
- Real desktop/390-pixel isolated Edge edits, Save, explicit Generate, mix/solo
  and Jobs exercise the repair. Saving corrected cells creates no job; explicit
  generation changes actual model/audio. A native job completes after its page
  closes. Original failed jobs remain unchanged. Actual graph details now report
  three conditional groups and the driven-role input; proof-dependent pass counts
  differ with vocabulary (17 and20 in these examples). A missing model_reused
  boolean no longer produces a false cache-reuse claim. Automated playback was
  muted; no physical-phone or musical-quality acceptance is claimed. Exact owned
  QA processes/audio are closed and both QA ports are absent. No WFC source/pin
  or separate branch changed. Return to experimental learning AC3; effort5 closes
  this repair only. Consecutive nonclosing count is zero.

- 2026-10-30, Big Boss: Full synchronized symbolic context repairs the original
  lead case but a bass assignment still reaches the original32-pass limit at
  coverage.2, identically native/pas2js. Preserve both prototype failures. Refine
  the coupling to make the operator's selected pitch role an explicit upstream
  context decision together with H/R; the remaining roles stay independently
  solved. This is one driven part, not a pinned ensemble or a larger budget.

- 2026-10-30, Big Boss: Select AC1–3. Deliver a shared symbolic context that
  retains synchronized role pitches/actions/velocities before projecting H/R to
  the named graph. Other parts remain independently solved; the context is a
  feasibility witness, not a pinned performed score. Closing evidence: the exact
  failed melody, representative role/context edits, original motifs and authored
  replay, native/actual pas2js contracts and ordinary Studio generation. Stop at
  this concrete repair and return to experimental learning; no corpus/form or
  larger search-budget work. Prior goal turn made progress by closing actual
  Studio criteria; consecutive nonclosing count remains zero.

- 2026-10-30, Big Boss: Required prerequisite for
  [experimental learning AC3](../NS-3_experimental-learning_01.md). Preserve the
  actual failed Studio job, desktop screenshot and Pascal diagnostic under
  musical-editor-20261030-boss in the dedicated E-drive roots. Exact case:
  root9/natural_minor, lead MIDI60,62,64,67,64,62,60,55, velocity80 and attacks,
  16 cells, seed731. Context and independent projected H/R solve; named graph
  returns gnsContradiction at harmony. Earlier joint-context acceptance remains
  scoped to its recorded controlled motif and original budgets.
- Before implementation, identify the audible criterion, usable deliverable,
  relevant evidence and stopping point. Return to the existing Studio task after
  this concrete prerequisite; corpus/form/blends remain separately scoped.
