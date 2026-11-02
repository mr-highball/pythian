# NS-6_review-entry_01 — Reach pending listening questions from Studio

[Tasks](../README.md) · [Listening workbench](NS-6_synthesis-reviews_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** Accepted — 2026-11-02
**Owner:** Big Boss (single agent)

**Description:**

Ordinary Studio now shows a compact waiting-question count and Review action,
plus a completed track's own feedback link. The three main steps remain. Primary
attribution: NS-6; shared queue/count/session polling and same-origin links.

**Acceptance Criteria:**

- AC1: Studio visibly offers waiting listening questions with a truthful count,
  and a completed result can open its own question when one exists. Explain an
  empty/unavailable queue without blocking music selection or generation.
- AC2: Keep Library → Selection → Generate and the compact phone header. Actual
  desktop/390px navigation reaches the intended request and returns to preserved
  playlist/result state. Reading or opening reviews does not train, generate,
  change answers or play competing audio.

**Blockers**

- [Listening workbench — DONE](NS-6_synthesis-reviews_01.md).
- [Current shared Help — DONE](NS-6_current-studio-guide_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: AC1–2 and prerequisites pass. Shared navigation has a
  listening-only mode without duplicate Help ownership or the old large cards.
  Actual desktop/390px pending count, exact result question, return/reload,
  preserved selection/result, no implicit jobs/answers and paused audio pass.
  Empty/unavailable API responses are deliberately simulated; selection and
  playback remain usable. Current live Studio reports six waiting questions.
  Full pas2js web05 and CI570 at fa15d2b pass; compact frontend eeb8bd7 has its
  own actual consumers over the identical417 native inputs. All three artifact
  digests,138/320 package content hashes,12 served assets and fixed-slot HTTPS
  delivery verify. All27 jobs/3 clips/3 styles and7,312 prior metadata hashes stay
  exact. Private proof: E/runs/review-retry-browser01, review-retry-ci570 and
  review-retry-release01. Big Boss solo checks are not independent review or a
  physical-phone/musical-quality verdict. Isolated processes/audio close; one
  inactive host error tab cannot be closed by Browser policy/host-UI restriction.

- 2026-11-02, Big Boss: select with the existing generation-retry consumer after
  delivered recording ideas/headroom; nonclosing count0. Criterion: an operator
  can find waiting musical questions and the current result's question without
  hunting through Help, while retained failure recovery stays explicit. Deliver
  a compact waiting-count action and same-origin result links using the shared
  queue contract; keep the three main steps. Close with actual desktop/390px
  pending/empty/unavailable counts, intended request/return, preserved result/
  playlist state and zero implicit jobs/answers/audio. Reuse qualified unchanged
  native code; check the actual pas2js/browser boundary. Stop at both tickets'
  complete outcomes or a distinct required native gap, linked before expansion.

- 2026-11-02, Big Boss: final consumer check finds listen.html only in the shared
  guide, with no ordinary Studio link/count in studio.html, studio.lpr, Songs or
  laboratory. Link this distinct one-unit gap before expanding accepted review/
  Help scope. The review page itself and current guide remain delivered. An
  operator can use its direct URL now; do not invent a native API or a mandatory
  extra step. No implementation or musical credit is accepted by this ticket.
