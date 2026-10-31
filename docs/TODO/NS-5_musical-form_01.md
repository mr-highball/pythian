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

- [Known future domains — DONE](DONE/NS-4_future-domains_01.md) — original24cell
  guide and real8/16cell form now pass with native/pas2js and full CI/packages.

- [NS-4_graph-controls_01](DONE/NS-4_graph-controls_01.md)
- [NS-6_instrumental-studio_01](DONE/NS-6_instrumental-studio_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss: the optional Studio Structure consumer is implemented
  and locally exercised, not full task acceptance. Named sections, repeat sources
  and retained providers save/reopen through the primary form cursor; ordinary
  bounded jobs retain actual providers and native section clocks. Native form
  consumer22 checks, callback/native-pas2js799 each and actual Studio journal564
  checks pass with clean native heaps. The browser generates48seconds A/B/A,
  verifies all eight providers return, seeks32..48seconds and stops at the section
  boundary. A shorter native section edit changes six Lead cells, preserving
  model and Before/After lineage; sound replay changes audio with exact notes.
  Desktop/390px browser interactions exercise invalid order/draft reload,
  referenced-source removal refusal, keyboard tabs, typing and contextual help.
  The existing playlist regression passes290 checks with a clean heap, retaining
  ordinary recording learning, clip reads and sound/note follow-up behavior.
  Fixed stable service is not yet updated. Evidence uses `form-studio-20261031-boss`
  under the dedicated E-drive roots. Keep the actual native publication failure
  in native01 and repaired native02/04 results. AC4 implementation/persistence
  checks now pass locally; complete CI and final integration remain pending.
  Sourcebf524af is published; Native FPC CI534 (41248537215) is in progress.
- The same browser's return-section Lead-only follow-up, seed1502445802,
  fails at cell144 in the pitched group after an earlier candidate chunk commits.
  Original job `music-1793485090576-185750` (generation seed623803102) remains
  playable; failed child `music-1793485261505-670885`, its request and
  `note-conflict.json` are preserved in the isolated QA catalog. Do not call this
  a proven impossible musical request or sweep seeds. Assess the primary passage
  editor's future kept accompaniment across candidate chunks before claiming
  general section-edit success. This is within the task's existing targeted-edit
  criterion, not an extra completed task. Structured nonneutral preferences /
  expression are explicitly rejected while per-section energy/density remain
  open. No effort units earned and no universal feasibility/listening claim.

- 2026-10-31, Big Boss: the future-domain prerequisite is accepted after full
  upstream CI63 and Pythian CI533, including extracted consumers. Return this
  task to In progress. Its eight units remain open; deliver the actual optional
  Structure consumer, section audition/targeted changes and persisted form,
  then finish per-section musical controls and operator listening criteria.
- 2026-10-31, Big Boss: actual Studio consumer assessment while CI533 runs:
  authored laboratory jobs still construct a finite `TInstrumentalPlan` in
  `tools/pythian.tools.studio.instrumental.pas`; recording-based jobs already
  use `RunStudioPlaylistStream`. Integrate forms through that primary bounded
  performance/publication/replay path, generalized to explicit authored or
  learned provider inputs. Do not add a form-only renderer or another job/player.
  Preserve actual origins, controls, saved decisions, Original/Before/After and
  historical finite-job reads. The portable finite graph API remains a genuine
  public consumer, not a reason to keep duplicate application render logic.
  Expose arrangement in the optional laboratory with contextual help; retain the
  simple ordinary playlist flow. Section audition and targeted changes should
  reuse current playback and retained passage edits. Energy/density are still
  required musical controls: reuse primary expression/preference contracts,
  never post-filter notes or claim a generic WFC gap from API inspection alone.
- 2026-10-31, Big Boss: the retained direct WFC reproduction establishes generic
  ownership, replacing the earlier unresolved assessment below. Follow
  [future domains](DONE/NS-4_future-domains_01.md): separate notified branch62c8597
  repairs that same guide and the actual unequal-phrase native/pas2js render.
  Existing form decisions and genuine Hat contradiction remain unchanged.
  Upstream/downstream integration gates are pending; this task remains blocked
  by the prerequisite, with Studio arrangement/section controls still required.
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
