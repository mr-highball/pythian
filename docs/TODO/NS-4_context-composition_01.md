# NS-4_context-composition_01 — Compose context and musical voices in one verified WFC transaction

[Active tasks](README.md) · [Unguided form](NS-4_unguided-form_01.md) · [Work](../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 6/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Add generic caller-declared upstream sequence composition to the primary WFC
voice graph and bounded stream, so context can negotiate with conditional voices
before a shared prefix commits. The current separate context stream commits
choices before discovering whether the actual independent voice frontiers can
continue. Pinning all voices to context examples is not the requested repair.
Primary attribution: NS-4. Generic graph/source proof and lifecycle belong in the
separate WFC repository; Pythian keeps musical token mappings and audio adaptation.

**Acceptance Criteria:**

- AC1: A caller explicitly declares upstream sequence model(s), boundaries and
  projected relations without any Pythian token codec in WFC. The actual source
  and existing H/R/voice passes solve under one primary negotiated transaction.
- AC2: The bounded primary stream commits source and voice frontiers together,
  validates the full configured future window and publishes only its prefix.
  Do not shorten windows, raise search budgets or implicitly lock pitched parts.
  Preserve borrowed ownership, cancellation/failure and no-source replay.
- AC3: Independent capture validates exactly the declared source layout, model
  identities, latent paths/boundaries, caller domains and projection relations.
  Merely allowing arbitrary extra passes or trusting editable live requirements
  is insufficient. Retain source decisions and reject stale/undeclared layouts.
- AC4: Native/actual pas2js and relevant upstream CI pass. Integrate the checked
  revision through an explicit Pythian gitlink update and an actual adapter/
  extracted consumer, preserving core independence and notices. Upstream success
  alone does not accept this task. The linked four-unit task owns full musical
  request repair, six-part Studio rendering and operator controls.

**Blockers**

- [Positioned priors — DONE](DONE/NS-4_cell-priors_01.md)
- [Bounded future domains — DONE](DONE/NS-4_future-domains_01.md)

**Dev Notes:**

- The repaired80772b6 source now passes all five upstream CI66 jobs. The expanded
  Pythian typed-context/frame consumer passes48 checks on native and actual
  pas2js, with a clean native heap. The source37/0426149 archive and complete
  CI542 also pass, retained as exact historical evidence. Updated80772b6
  downstream CI/extraction remain the final gates. The separate
  [known-domain preparation task](NS-4_projected-domains_01.md) owns the further
  bounded-search capability exposed by the actual musical candidate; that
  failure does not disappear merely because composition's source/proof API
  works. Preserve both facts and keep this task open until repair gates finish.

- The first actual joint instrumental stream exposes a further acceptance defect
  at37c2755: CopyFrames derives pitched count from total model count and attempts
  to decode an auxiliary percussion token as an ensemble frame. The initial
  generated-layer consumers missed this endpoint despite green CI65. Do not
  accept that source from those tests. The same separate branch now publishes
  80772b6, retaining actual declared pitched count for detached frame copies.
  Expanded native/actual pas2js144 checks pass, including default replay and
  auxiliary frame-copy ownership. CI66 is running at the repair. Pythian's
  consumer now also calls CopyFrames; its candidate pin is80772b6 while the
  original CI542 at0426149/37c2755 continues unaltered. First failure and revised
  regressions are preserved under the E composition/joint packets. No task is
  accepted, and the stable review service is unchanged.

- 2026-11-01, Big Boss: upstream source37c2755 is published on the notified
  [separate branch](https://github.com/mr-highball/wfc/tree/codex/pythian-context-composition).
  The primary graph accepts explicitly named auxiliary models and token maps;
  both upstream context and downstream symbolic passes negotiate with musical
  voices. Independent proof reuses shared sequence-rule validation and rejects
  absent live relations, stale source identities, forged boundaries and caller
  domains. The stream commits all frontiers at its returned prefix after full
  lookahead proof. Native136/actual pas2js136 new checks pass; four no-composition
  signatures match an independent fresh448b2a3 build. Existing native graph187,
  partial projection29, stream1834 and complete preparation533791 checks pass
  with clean heaps, including132 original observer abort/retries. Retain the
  mistaken order-one fixture failure; order two encodes its intended transitions
  with unchanged seed/window/budgets. [CI65](https://github.com/mr-highball/wfc/actions/runs/41277896792)
  is running, not yet accepted.
- Pythian's candidate gitlink is explicitly advanced to37c2755. Its existing
  context adapter now exposes ComposeMusicalContextGraph, reusing the primary
  musical projection rather than copying a context codec. The real typed
  context finite/stream consumer passes44 checks on native and actual pas2js;
  H/R-only context permits an independently selected octave, while explicit role
  binding correctly rejects that conflict. Cancellation preserves the previous
  candidate. The consumer is wired into native build and extracted-package
  checks. Downstream CI/extraction remain pending; the ordinary Studio stream
  has not yet migrated, and no service is redeployed. No task/effort accepted.
- Existing affected native consumers also pass against the new pin: musical
  material1439 and instrumental density323 checks, both with clean heaps. All
  five upstream CI65 jobs are retained; Linux stable and official trunk have
  passed while Windows/macOS and the actual-browser job remain running.

- 2026-11-01, Big Boss: a two-cell standalone Pascal probe against pinned448b2a3
  first solves/captures the ordinary primary voice graph. Adding a declared
  abstract `a`/`b` sequence source and a harmless projected dependency also solves
  with the generic graph, but primary CaptureSolvedWfcMusicVoices rejects it as
  `wmvikGraphShape: graph layout differs`. No Pythian units or audio are involved;
  the proof has a clean heap. Current GraphLayout requires exactly musical plus
  coverage passes. This is a demonstrated composition API gap, not evidence of
  an incorrect existing closed-layout contract. Evidence/source/logs are under
  `unguided-form-20261101-boss` on E. The operator was notified before changes:
  use new separate branch `codex/pythian-context-composition` from448b2a3. Preserve
  the unrelated D-drive `expansion` checkout and its remote attachments.
- Six effort units reflect shared API/proof/frontier integration uncertainty.
  The four-unit downstream task remains separate; no partial acceptance or
  musical credit follows. Do not duplicate the primary voice verifier in Pythian.
