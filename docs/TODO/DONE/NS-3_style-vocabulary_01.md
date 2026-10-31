# NS-3_style-vocabulary_01 — Learn reusable musical vocabularies from coarse classified corpora

[Active tasks](../README.md) · [Goal](../../GOAL.md) · [Milestones](../../MILESTONES.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 7/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Teach from whole tracks or coarse passages across private collections without exhaustive annotation. Build musical/provider vocabularies that can drive instruments, with incremental additions and honest coverage. Stop on treating feature buckets or file processing alone as learned musical roles.

Primary attribution: NS-3. Accepted 2026-10-31 after the actual portable, native
worker and Studio consumers passed. Effort estimates implementation/integration
complexity, not musical quality, inference accuracy or elapsed time.

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

- [NS-3_experimental-learning_01](NS-3_experimental-learning_01.md) — accepted.

**Dev Notes:**

- 2026-10-31, Big Boss, accepted AC1–AC5. Caller collection/whole-track and clip
  labels now choose actual teaching material through the primary portable
  music.selection rule; this is explicit source selection, not genre or stem
  identification. Whole-track precedence prevents duplicated clip time; invalid
  or overlapping matching clips reject atomically. Native canonicalization
  recomputes inclusion rather than trusting browser flags. Excluded tracks remain
  saved and their payloads are never opened. Source/clip labels and coverage
  receipts state actual inclusion, influence and the nine proposed providers.
  Same-seed, same-instrument native classification changes produce different
  real model and synthesized WAV hashes. Disjoint ranges analyze only their
  selected time. Stable rebuild identities and bounded whole/multiple-recording
  traversal/reuse from the preceding batches remain in the actual worker path.
- Final checks: native/actual pas2js selection93 and corpus377; native full
  playlist/worker203, all native heaps clean. Ordinary desktop/phone Studio saves
  a labelled1–5second clip, excludes the other saved recording, generates real
  instruments and plays the3second result plus its exact4second Original. Closing
  the tab while running and reopening restores that same completed job and label.
  Optional coverage shows selected/analyzed/model-used time and excluded names.
  No feedback answers were saved; no musical preference or universal transcription
  acceptance is claimed. Practical sampling/resource limits remain documented in
  [the API](../../INSTRUMENTAL.md#experimental-coarse-musical-providers).
- Preserve first full-playlist compile rejection (an obsolete LText assignment)
  and its repaired log. Strict optional-field canonicalization retains legacy
  playlist shapes. Browser inspection exposed buried clip labels and late job
  restoration overriding navigation: labels now sit by the range controls and
  user interaction takes navigation priority. Evidence packet:
  classified-learning-20261031-boss under E-drive tests/runs; solo verification.
  This closes the task and the linked simple Studio prerequisite. No extra
  genre mapping, style archive or manual source-label queue is introduced.

- 2026-10-31, Big Boss: selected AC1/AC4 classification-driven source selection.
  A caller-defined collection/whole-track or clip label chooses actual teaching
  material using a shared native/pas2js rule. Matching whole tracks suppress
  their clips, avoiding duplicate time; overlapping matching clips reject.
  Keep this optional in Selection and preserve excluded saved choices. Native
  learning receipts must explain actual inclusion/exclusion and the providers
  taught. Verify actual learned counts and synthesized changes, then ordinary
  browser save/reopen/Generate. No genre/instrument truth mapping or extra
  mandatory tuning. Evidence packet: classified-learning-20261031-boss under E.

- 2026-10-31, Big Boss, AC2 rebuild boundary closed: actual provider tokens now
  have content-bound codec/key/schema/value identities and exact model-local
  index mappings. Admitted open samples retain unique original source/range,
  policy/clock and symbolic evidence identities; weights remain separate.
  Adding/reordering/removing recordings or rebuilding a warm cache never
  reinterprets a meaning or adds parent counts twice. Joint role schema edits
  change positional rhythm/context identity. Native and actual pas2js377 checks
  pass; all eleven provider/token fingerprints, including Unicode, match.
  Native actual playlist/worker177 checks pass with clean heap. Ordinary browser
  Generate runs the external fixed-slot worker, saves nine vocabularies and five
  real contributions, plays its result and retains truthful source coverage.
  Full bindings are saved in musical-vocabulary.json; ordinary receipts omit
  full token text. See [the shared contract](../../INSTRUMENTAL.md#stable-musical-meaning-across-rebuilds).
  Preserve initial parity evidence: synthesized fixture source WAV bytes differ
  between native/JS, so their source-bound ancestry hashes need not match. The
  initial Unicode fixture cast also transcoded through Windows' code page;
  identical canonical fixture input repairs that test without a product workaround.
  The first isolated service launch rejected LAN-open mode with a loopback
  address; its corrected loopback command keeps the fixed approved QA slot.
  Evidence: musical-vocabulary-20261031-boss under E-drive tests/runs. Stop before
  blending. Classification-driven corpus/control behavior and final task criteria
  remain open;66/119 effort stays unchanged. This is solo verification.

- 2026-10-31, Big Boss: selected AC2 rebuild contract after accepted long Studio
  output. Give actual musical tokens stable content-bound identities while
  retaining each model's local ordered index mapping. Save unique admitted sample
  identities/source clocks and explicit training multiplicity; rebuilding the
  complete selected corpus must not add old observations a second time. Native
  and actual pas2js source-addition/reorder/weight checks and the ordinary native
  learning worker close this boundary. Stop before the separate styles/blends
  archive. Evidence packet: `musical-vocabulary-20261031-boss` under E.

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
  [the actual API](../../INSTRUMENTAL.md#experimental-coarse-musical-providers).
  Evidence: E-drive musical-corpus-20261030-boss. Preserve initial native array
  alias-type compile rejection, overly specific spectral-note/fixed-pass test
  assumptions, test variable-scope errors and the whole-render work-bound
  rejection. Tests now use native type aliases, actual graph dependencies,
  periodic-versus-spectral origins and bounded primary render blocks. The
  optional semantic archive pas2js rejection is linked to the existing
  [style consumer](../NS-5_instrumental-styles_01.md); it is not introduced as a
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
- Read [the implementation review](../../ASSESSMENT-2026-10-29.md) and [retirement/replacement map](../RETIRED/2026-10-29/README.md) before repeating prior work. Preserve original failure evidence. Experimental musical proposals may be auditioned and corrected without independent inference-accuracy acceptance; never relabel them as established measurements.
- Before implementation, state the audible/operator criterion, concrete deliverable, minimal closing checks and stop condition. Record repaired defects, failed approaches and linked follow-ups here. Do not broaden infrastructure work beyond an actual blocker.
