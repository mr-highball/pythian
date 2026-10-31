# NS-3_style-vocabulary_01 — Learn reusable musical vocabularies from coarse classified corpora

[Active tasks](README.md) · [Goal](../GOAL.md) · [Milestones](../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Teach from whole tracks or coarse passages across private collections without exhaustive annotation. Build musical/provider vocabularies that can drive instruments, with incremental additions and honest coverage. Stop on treating feature buckets or file processing alone as learned musical roles.

Primary attribution: NS-3. Effort estimates relative implementation/integration complexity, not musical value, accuracy, elapsed time or assigned percentage. No part of this new outcome is accepted by planning or by historical component tests.

**Acceptance Criteria:**

- AC1: Choose included recordings/ranges and caller classifications, then explicitly learn or update supported provider vocabularies. Explain which role/context/trait each source or operator choice actually contributes.
- AC2: Keep recording/run boundaries, unknown regions, original source timing and distinct training weights/generation preferences. New recordings and vocabulary rebuilds must not silently reinterpret existing token IDs or duplicate ancestry.
- AC3: Reuse bounded journal/intake/cache machinery for longer and multiple recordings; show included, processed, excluded and model-used duration separately. Support cancellation/reuse and name practical model/resource limits.
- AC4: Use the resulting saved providers in actual multi-part instrumental generation. Demonstrate a musically audible effect of an operator classification or corpus/model edit, and preserve unsupported mappings as explicit gaps.
- AC5: The simple Studio Generate action automatically performs this learning
  from the included whole tracks/passages. Per-track influence changes training
  contributions, separately from generation preferences. Do not require manual
  microclip segmentation or proposal acceptance, ignore selected music, substitute
  authored-only material, or describe a first-eight-second observation as learning
  the entire playlist. Keep unknown/unsupported musical proposals honest and
  Experimental while still allowing the operator to audition synthesis.

**Blockers**

- [NS-3_experimental-learning_01](DONE/NS-3_experimental-learning_01.md)

**Dev Notes:**

- 2026-10-30, Big Boss, automatic playlist consumer implemented: native
  LearnStudioPlaylist traverses complete included ranges in bounded windows,
  verifies original bytes and reuses source/clock/policy-bound primary proposal
  caches. A separate admission mask selects up to 1,024 known cells in musical
  blocks spread across included time and fairly among sources. Unknowns and
  original proposals remain unchanged; source/range/omitted boundaries never
  gain artificial joins. Receipts distinguish included, excluded, analyzed,
  proposed, unknown/partial, budget-omitted and actual model-used time. Whole
  processing does not claim whole model coverage. Pitch/pulse remain bounded to
  each window's first eight seconds; spectral measurements cover the full window.
  Explicit 120BPM fallback and arranged instrument recipes stay Experimental.
- Native playlist (45 checks) covers two 75-second recordings across all six windows,
  warm reuse of all six, unchanged providers on reuse, changed influence without
  reanalysis, disjoint exact source ranges and the actual six-part worker.
  Native64/actual pas2js observation (67), corpus (165) and WAV-reader (70,061) pass,
  including portable bound proposal serialization/checksum/cancel and exact
  offset/reentry/read-boundary behavior. Native heaps are clean. Source reading
  is consolidated in the primary TWaveFrameReader.ReadClip, including whole-WAV
  decoding; no second native window reader is retained. The browser's real 5:1
  playlist reaches this worker. This closes the bounded automatic learning/job
  consumer, not stable growing-vocabulary ancestry or complete task acceptance.
  Accounting stays47/108; consecutive nonclosing count stays zero.

- 2026-10-30, Big Boss, bounded provider consumer delivered: primary
  music.observations shares one band/feature FFT; music.proposal emits explicit
  Experimental pitch/chroma arrangements and band-change percussion proposals.
  musical.corpus binds exact original ranges, preserves unknown/run/source
  boundaries, records distinct duration/contribution accounting and learns nine
  actual providers for three pitched roles plus drums. Per-track influence
  multiplies training counts. Saved provider text reloads into the primary
  six-part instrumental runtime; the 8:1/1:8 source edit changes synthesized
  music at the same seed. No starter, raw-grain factory or genre truth is used.
  Native64 and actual pas2js pass observation58/corpus162; nine provider hashes
  match across targets, with deterministic audio replay on each target. Native
  heaps are clean. Native semantic blend and progress41896 also pass after
  consolidating multiplicity into the shared learner. This closes the bounded
  AC4 provider-to-instrumental boundary, not whole-task acceptance or an operator
  quality verdict. Consecutive nonclosing count remains zero; effort stays open.
  Long-recording traversal/journal reuse and ordinary Studio Generate (AC3/AC5)
  remain required. Practical sample/vocabulary limits are documented in
  [the actual API](../INSTRUMENTAL.md#experimental-coarse-musical-providers).
  Evidence: E-drive musical-corpus-20261030-boss. Preserve initial native array
  alias-type compile rejection, overly specific spectral-note/fixed-pass test
  assumptions, test variable-scope errors and the whole-render work-bound
  rejection. Tests now use native type aliases, actual graph dependencies,
  periodic-versus-spectral origins and bounded primary render blocks. The
  optional semantic archive pas2js rejection is linked to the existing
  [style consumer](NS-5_instrumental-styles_01.md); it is not introduced as a
  blanket gate on this portable musical provider path.
- 2026-10-30, Big Boss, next bounded batch: close the source-contribution and
  instrumental-consumer boundary with shared portable musical proposals and
  weighted, source/run-aware WFC providers. Deliver two contrasting measured
  recordings through the actual multi-part synthesis runtime; swapping training
  influence must change model contributions and synthesized music. Retain exact
  source bounds, unknown regions, explicit proposal policy and actual model text.
  Use primary pitch/chroma/band measurements and chord records; do not instantiate
  the authored starter to obtain defaults or relabel source feature buckets as
  identified instruments. Minimal checks cover source/run separation, real
  weights, invalid/cancelled admission, actual native/pas2js and audible native
  output. Stop there before long-recording journals and Studio job integration;
  those remain required for this seven-unit task, not completion shortcuts.
  The preceding UI batch closed its saved-selection criterion; consecutive
  nonclosing count starts at zero. Pythian CI513 for `0c756e3` is still running
  at the first check; a wait expiry would not establish failure.
- 2026-10-30, Big Boss: This is now the real backend prerequisite to the
  [simple Studio flow](NS-6_simple-studio_01.md), per the operator's Library →
  Selection → Generate direction. The existing 7/10 scope already owns coarse
  whole/multiple recording learning and distinct training weights; this
  clarification adds no duplicate effort. Prioritize that consumer over the
  parked sound-archive slice. Use primary Pascal analysis/inference/WFC providers,
  bounded source reads and source-boundary-aware corpus machinery.
- 2026-10-30, Big Boss: Experimental learning is accepted; its bounded source-linked
  pitch/context and explicit cutoff/sustain recipes remove this prerequisite.
  Coarse whole-corpus vocabulary work remains unimplemented and earns no partial effort.
- 2026-10-29, Big Boss: Private corpus intake, classifications, journal storage, semantic styles, contribution accounting and saved model contracts exist. Raw-acoustic classifications currently affect identity rather than musical meaning; this task supplies actual mappings.
- Read [the implementation review](../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
