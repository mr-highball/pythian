# NS-5_musical-form_01 — Generate evolving phrases, sections and useful variation

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 8/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Give instrumental generation musically meaningful repetition and development over time. Begin with editable authored/experimental phrase material, then allow learned proposals. Stop on renaming solver chunks as musical sections or copying an input arrangement as the generated result.

Primary attribution: NS-5. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Represent phrases, motifs, sections and transitions as explicit reusable graph/provider decisions. Permit operator arrangement and repetition/variation controls, including changing energy/density across sections.
- AC2: Connect structural decisions to bass, percussion, harmony and lead constraints on the shared timeline. Retain selected motifs or parts while varying dependent material, with clear boundary/hold semantics.
- AC3: Render a sustained multi-section instrumental piece and expose section audition and targeted regeneration in Studio. Retain weak passages and use actual operator listening to choose the next model change.
- AC4: Save/reload the structure and verify meaningful boundary, replay and continuation behavior. Existing authored long-form templates can bootstrap material, but must remain editable and correctly labeled.

**Blockers**

- [NS-4_graph-controls_01](DONE/NS-4_graph-controls_01.md)
- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss: the shared runtime slice is implemented, not full task
  acceptance. [Musical form](../MUSICAL-FORM.md) owns explicit section/phrase
  records and a bounded detached motif cursor in the portable library. The
  primary instrumental stream applies retained musical tokens to actual context,
  named-voice and drum domains; it does not splice notes or PCM. Known upcoming
  returns constrain bounded context/drum lookahead before a contrast commits.
  Source completion, real frontiers, separate regenerated states and continuous
  note/effect state remain explicit. No vendor source was edited.
  The actual80second five-section consumer returns A exactly and varies other
  parts while holding Lead/Hat: Bass/Harmony change55 of64cells each, Kick4 and
  Snare15; Lead/Hat change0. The primary decision reader verifies
  these actual results. Mix/six WAV stems and the complete decision journal are
  under `tests/musical-form-20261031-boss/audio08` on E. Native Win64/actual
  pas2js pass767 form checks with identical decision digest `c4355af4...124a1130`;
  pure core passes18, including a no-WFC consumer, and the old stream passes
  4,043,522 on both targets. Native heaps are clean.
  Complete arrangement UI, per-section energy/density, saved form and targeted
  regeneration remain open. No eight-unit acceptance or musical-quality credit.
- Preserve the real failures. The first context-only frontier chose an exit that
  could not reach the requested return. Known-future context/drum planning repairs
  that dependency. The four-section adjacent return/variation request remains
  correctly rejected: a separate primary cyclic graph proves the captured Hat
  motif cannot close. The explicit five-section arrangement includes a generated
  bridge with the same seed/models; no seed sweep, relaxed Keep or invented edge.
  A separate no-context authored-guide probe (8/16cell phrases, seed731) fails at
  cell16 in both targets. Preserve `instrumental.form-native06/07.log`, matching
  pas2js logs and `instrumental.form-sourcefree-repro.lpr` in the run packet.
  It is not a current passing consumer or an established generic WFC defect.
  Before accepting this task, isolate the same request without AForm and compare
  the full24cell finite graph. Follow the cross-repository procedure and notify
  the operator before any demonstrated generic repair; never patch vendor here.
  Do not turn that unresolved positive probe into a required-failure CI assertion.
  The maintained passing form fixture covers the supported authored-context path;
  the broader criterion and full task remain open. Current batch is progress but
  earns no full criterion closure; consecutive nonclosing count is one.

- 2026-10-31, Big Boss: select the shared phrase-retention/runtime slice first.
  Deliver an explicit caller-authored section/phrase plan, source phrase links
  and named retained providers that constrain the actual future WFC graphs.
  Other providers remain generated, and real frontiers still decide whether a
  repeat fits. Subdivide phrase lengths without treating solve chunks as form;
  preserve one continuous primary instrument/effect performance. Minimal closing
  checks: actual six-part output, retained public musical choices, context/drum
  relationships, real boundary rejection, replay across PCM pulls, cancellation
  and native/actual pas2js parity. Stop at that public usable library consumer.
  No effort acceptance before the complete arrangement/section Studio consumer,
  per-section energy/density, saving and targeted regeneration pass. Existing
  ConfigureSegment/domain APIs suffice; no generic WFC gap is demonstrated.
  Previous goal turn is progress; consecutive nonclosing count starts at zero.
  New artifacts use `musical-form-20261031-boss` in dedicated E-drive roots.
- 2026-10-31, Big Boss: musical controls and optional Lab are now accepted;
  the actual prerequisite is satisfied. Ready for the least-complete NS-5
  outcome. Preserve this task's explicit phrase/section decisions and audible
  operator consumer; solver chunks alone are not musical form.
- 2026-10-29, Big Boss: The core has an authored 144-bar two-part composition and musical scheduling, but semantic styles explicitly lack a phrase/form vocabulary. Build the missing representation and integration using existing primitives.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
