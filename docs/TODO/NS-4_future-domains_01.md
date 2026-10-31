# NS-4_future-domains_01 — Fit known future musical domains before committing a prefix

[Tasks](README.md) · [Musical form](NS-5_musical-form_01.md) · [Workflow](../TASKFLOW.MD)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

The actual authored guide admits a complete24cell joint musical plan, but the
same models, seed and sparse domains fail at cell16 when WFC commits8cell chunks.
This reproduces directly in the companion voice stream without Pythian's form
cursor or audio renderer. Add explicit bounded future-aware planning to that
primary stream, then use it in Pythian's musical-form consumer. Primary NS-4
attribution; these units repair a distinct generic shared-stream prerequisite,
not Studio form/section controls or additional credit for NS-5's implementation.

**Acceptance Criteria:**

- AC1: Preserve the actual whole-plan/stream discrepancy with the same models,
  guide and seed, and a small owned upstream regression. Distinguish genuine
  incompatible domains from avoidable committed-prefix dead ends.
- AC2: The primary stream can solve an explicitly bounded future window while
  committing only the returned prefix. Preserve original model/boundary proof,
  hard domains, coverage, frontier ownership, deterministic replay and terminal
  cancellation/failure behavior. Expose actual planning and returned extents;
  retain bounded memory and allow edits only beyond the committed prefix.
- AC3: Implement generic behavior in the separate WFC repository on the notified
  new branch. Validate native/actual pas2js and affected default consumers, then
  upstream CI. Do not edit Pythian vendor source or merge unrelated WFC work.
- AC4: Integrate the reviewed pin and actual Pythian native/pas2js consumer. The
  retained guide and8/16cell form render through real instruments. Preserve
  supported existing form/default streams, genuine motif conflicts and portable
  core independence. No whole-form or musical-quality acceptance follows alone.

**Blockers**

- [Shared instrumental runtime — DONE](DONE/NS-4_instrumental-runtime_01.md)
- Reviewed WFC sequence-continuation pin from
  [context continuation — DONE](DONE/NS-4_context-continuation_01.md).

**Dev Notes:**

- 2026-10-31, Big Boss: implement the primary companion extension at
  [62c8597](https://github.com/mr-highball/wfc/commit/62c8597bc8add1d2e1956a9ed5cef3ddaf569d70)
  on the notified separate branch. Native1834 and actual pas2js1890 checks pass:
  small fork finite-vs-prefix regression, bounded lookahead, prefix/EOS/coverage
  ownership, future edits, replay, cancellation, genuine contradiction, invalid
  caps and a hook trying to erase a future hard domain. Initial test incorrectly
  used an order-one overlap model with zero prior-token history; native01/02
  preserve that fixture failure, repaired with an actual order-two dependency.
  Native heaps are clean. Default planning remains one returned segment; current
  stream/signature versions2 bind the actual checked extent and prefix boundary.
- Pythian applies known form/context domains across the bounded voice window;
  only returned voice choices commit. Fixed context/drum pending cells remain
  protected. Voice limits are capped at256cells and the combined state budget;
  actual limits/extents are public. Native Win64/actual pas2js pass798 form and
  4,043,522 unchanged default-stream checks. The original no-context8/16cell
  guide renders six audible parts and replays across PCM pulls. The old80second
  form retains decision digest `c4355af4...124a1130`; the genuine adjacent-Hat
  motif contradiction remains rejected. Core-only native passes18 without WFC
  paths. Native heaps are clean. Actual80second and6second mix/stems plus journals
  are in `tests/form-frontier-20261031-boss/audio01` under the dedicated E root.
  The short journal digest is `716dccfe...e2fa38a`. These are implementation
  checks, not operator musical-quality approval. Upstream CI63 is running;
  candidate pin integration and downstream CI remain open. No effort accepted.
- 2026-10-31, Big Boss: direct `TNamedVoiceSession` over24cells succeeds; direct
  `TWfcMusicVoicesStream` with the same guide, seed731 and8cell chunks commits16
  cells, then fails harmony pass0. No AForm, audio rendering or Pythian stream
  participates in that second reproduction. Native heap is clean. Evidence is
  `form-frontier-20261031-boss/frontier-probe.lpr` and `probe01.log` in dedicated
  E-drive runs. The operator is notified that the generic extension belongs in
  separate WFC branch `codex/pythian-future-domains`, based on accepted7b3c0a5.
  Inspect existing worktrees and repository guidance before creating it. Current
  WFC primary checkout is unrelated `expansion`; do not disturb it or its private
  attachments. No generic source edit has occurred at task creation.
