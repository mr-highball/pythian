# NS-6_review-entry_01 — Reach pending listening questions from Studio

[Tasks](README.md) · [Listening workbench](DONE/NS-6_synthesis-reviews_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 1/10
**Status:** Ready
**Owner:** Big Boss (single agent)

**Description:**

Ordinary Studio has no direct listening-review entry; the shared Help topic can
reach it, but that is not an obvious next action. Expose waiting questions and a
finished track's review through the current three-step flow. Primary attribution:
NS-6. Reuse existing queue/count/session contracts and same-origin links.

**Acceptance Criteria:**

- AC1: Studio visibly offers waiting listening questions with a truthful count,
  and a completed result can open its own question when one exists. Explain an
  empty/unavailable queue without blocking music selection or generation.
- AC2: Keep Library → Selection → Generate and the compact phone header. Actual
  desktop/390px navigation reaches the intended request and returns to preserved
  playlist/result state. Reading or opening reviews does not train, generate,
  change answers or play competing audio.

**Blockers**

- [Listening workbench — DONE](DONE/NS-6_synthesis-reviews_01.md).
- [Current shared Help — DONE](DONE/NS-6_current-studio-guide_01.md).

**Dev Notes:**

- 2026-11-02, Big Boss: final consumer check finds listen.html only in the shared
  guide, with no ordinary Studio link/count in studio.html, studio.lpr, Songs or
  laboratory. Link this distinct one-unit gap before expanding accepted review/
  Help scope. The review page itself and current guide remain delivered. An
  operator can use its direct URL now; do not invent a native API or a mandatory
  extra step. No implementation or musical credit is accepted by this ticket.
