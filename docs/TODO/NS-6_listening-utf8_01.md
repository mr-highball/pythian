# NS-6_listening-utf8_01 — Preserve Unicode in saved listening queues and feedback

[Active tasks](README.md) · [Form](NS-5_musical-form_01.md) · [Work](../WORK.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 3/10
**Status:** In progress
**Owner:** Big Boss (single agent)

**Description:**

Use the primary native JSON writer for listening publication, fingerprints,
responses and export/replay. The current legacy AsJSON-to-host-String path can
publish bytes that the primary UTF-8 reader then rejects. Primary attribution:
NS-6. Repair this concrete review blocker without another serialization framework.

**Acceptance Criteria:**

- AC1: A real Unicode prepared title/question survives publish, append, reload,
  saved notes and export/replay. Preserve exact existing ASCII request/export
  fingerprints and reject malformed scalar text without replacing accepted data.
- AC2: Recover the affected local queue with all original requests/answers intact;
  preserve the rejected bytes, the original prepared packet and failure evidence.
  Confirm prior answered request fingerprints/revisions remain unchanged.
- AC3: Exercise the actual browser review on desktop/phone, exact native feedback
  lineage and relevant native consumers. Save never starts learning/generation;
  stage matched checked service/worker through the fixed slots.

**Blockers**

- None. This is the actual prerequisite for publishing the current form review.

**Dev Notes:**

- 2026-11-01, Big Boss: checked sourcecc45248 is now live in the fixed stable
  slot with all fourteen hashes matched and existing LAN/TLS approval preserved.
  Trusted HTTP/HTTPS133 passes cleanly; optional media fixtures are explicitly
  outside that check. The original Unicode review packet publishes successfully;
  its front-facing brief is shortened through guarded ordinary publication,
  before any response. Seven historical completed hashes/revisions remain exact.
  The actual review's49second playback and answer controls work at390px. QA is
  stopped, owned tabs closed and playback paused. Complete CI541 atcc45248 is
  the outstanding check; keep this task open until its result is known.

- Fixed-slot loopback QA passes actual desktop Save and390px reload with the
  exact note `Big Boss QA only: mélodie 🎵 音 stays exact.` Two synthetic answers
  remain in that isolated fixture only. All inspected playback is paused. Keep
  the observed narrow Remove-button wrapping as a [review UX follow-up](NS-6_synthesis-reviews_01.md);
  no general UI audit is selected. Stable deployment and complete CI are pending.

- Big Boss: the native regression first reproduces the production self-read
  failure. The repaired complete listening suite passes Unicode title/question,
  reviewer/notes, idempotent Save, exact export/replay, legacy ASCII export hash,
  reviewed-feedback race/history and malformed-byte preservation, with a clean
  heap. The first malformed fixture accidentally let the host convert a valid
  code-page scalar; replace it with an actual invalid byte before calling the
  native publisher. Retain both test logs. Guarded native recovery verifies all
  original request hashes before restoring the old queue; all seven completed
  responses and eight pending requests validate unchanged. Production is healthy;
  checked deployment and actual browser Unicode Save/reopen remain pending.

- 2026-11-01, Big Boss: primary form validation passes192 cells/1152000 music
  frames/12 chunks with a clean heap. Publishing the deliberate review then
  writes a queue whose first invalid UTF-8 byte is at25833. ReadListeningQueue
  rejects through ParseNativeJSON/ReadJSONString. Replacing only the new title
  with ASCII cannot repair already-published invalid bytes. Preserve the raw
  queue SHA dca561e3c47a01e895a704ae574313007d3732d701cfeef94cafc22428ffba8a,
  prepublication report and exact valid prepared packet under
  `E:/CodexWork/pythian/runs/form-listening-20261101-boss/`. No operator response
  was submitted for this new review. Use primary encoding for the whole writer
  boundary, preserving historical ASCII identities and existing response events.
  Deliver recovery plus the actual usable review; stop at that boundary.
