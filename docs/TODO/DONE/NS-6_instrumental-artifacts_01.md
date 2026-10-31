# NS-6_instrumental-artifacts_01 — Store generated audio once with bounded, responsive access

[Tasks](../README.md) · [Goal](../../GOAL.md) · [Long consumer](NS-6_instrumental-streams_01.md)

**Goal:** instrumental-exploration-2026-10-29
**Effort:** 5/10
**Status:** Accepted
**Owner:** Big Boss (single agent)

**Description:**

Make the actual long-generation consumer practical: generated WAVs use one
canonical host-configured store, with fresh workstation output on E. Hash while
writing through the primary Pascal implementation, publish complete audio without
copying it again, and reuse shared verified-file access for playback. Primary
attribution: NS-6. Existing private audio, catalogs and answers remain readable.
This is a discovered prerequisite, not accepted musical progress.

Accepted 2026-10-31 by Big Boss's solo verification. The primary SHA accumulator
and hashed sink serve bytes, streams and the actual native mix/stem/reference
writer. Each output now reaches one configured content-addressed store; jobs,
reviews and bounded media delivery share it. Original import inputs and legacy
catalog/job audio remain readable. Native Windows receipts prime the existing
locked-file guard; other hosts retain full hash verification.

Evidence packet: `instrumental-artifacts-20261031-boss` in the dedicated E-drive
tests/runs workspace. Portable SHA/sink fixtures pass 337224 native and 337225
actual pas2js checks, including 24 original publication abort/retries. Native
asset ownership/identity checks pass22; durable Studio smoke passes23, musical
generation/reference checks99, and retained listening catalog/replay passes with
clean heaps. Primary writer/reader RIFF/RF64 boundary fixtures pass, including
virtual large-file metadata without full payload allocation. The actual browser
learns a selected synthetic passage, generates, reconnects, plays synthesized
and Original audio, downloads identical bytes, and plays the same review asset.
Canonical mix/reference and an older per-job WAV return HTTP206. Stable deploy
uses existing slots/security; live Studio and retained output pass HTTP checks.
This accepts storage/access only: single-performance stems, long-job admission
and the Studio duration cap remain with the parent task.

**Acceptance Criteria:**

- AC1: One primary incremental SHA implementation serves byte, stream and
  output-sink callers. Confirmed output blocks alone enter its digest; a failed
  write cannot publish a successful asset or digest. Native/pas2js vectors and
  partition/rejection checks protect exact bytes and failure state.
- AC2: Generated output is written once into owned staging, then atomically
  published into one content-addressed store. Host configuration selects its
  root, including the dedicated E-drive workspace. Existing source/import files
  are not consumed. Deduplication and failed/cancelled staging preserve ownership
  and identifiable evidence. Catalogs stay isolated.
- AC3: Job and review playback resolve the same canonical audio. Native publication
  identity can prime the existing guarded-file cache without rereading every
  gigabyte on first playback; changed identity/content is rejected or reverified.
  Preserve ordinary verification for original sources and legacy recordings.
  Keep host paths/private verification details out of browser payloads.
- AC4: The actual native generated-output consumer and legacy read/import paths
  pass meaningful ownership, corruption, repeated-open and configured-root checks.
  Exercise bounded RIFF/RF64 metadata through the primary reader/writer. No new
  security prompt, alternate codec or duplicate source tree is introduced.

**Blockers**

- [Instrumental progress — accepted](NS-6_instrumental-progress_01.md)

**Dev Notes:**

- 2026-10-31, Big Boss: current instrumental jobs render seven fresh performances,
  keep per-job WAVs and copy/hash them again into listening assets. A24-hour
  24kHz stereoPCM16 request is about8.3GB per file, so this prevents practical long
  output and responsive first playback. The retained library stream already
  provides continuous synthesis; this task owns canonical output/verification,
  while its parent owns single-performance mix/stem routing, job admission and UX.
  Before implementation: deliver the actual writer/store/read consumer; check
  byte identity, ownership, failures and legacy access; stop before unrelated
  catalog migration, broad security changes or a general observability audit.
- 2026-10-31, Big Boss: fixed an initial incremental-hash tail-padding rejection
  and pas2js unsafe integer-constant cast. Final independent known vectors and
  partitioned updates pass on both targets; failed/partially emitted/reentrant
  output cannot publish a digest. Source objects are not consumed.
- 2026-10-31, Big Boss: browser verification caught a second HTTP reconstruction
  of the removed per-job path. The sender now uses the opened stream's actual
  filename. Preserve `qa-final-server-error.log`; repaired playback, Original,
  download and the listening queue all pass. The copied QA catalog also retained
  its original indexed synthetic library root; correcting the QA launch binding
  resolved that expected refusal. No operator data was changed for these tests.
- 2026-10-31, Big Boss: fixed-slot staging now uses exact process paths through
  Get-Process, avoiding the observed slow CIM inventory. It still refuses a
  running exact slot, and the stop/stage boundary was exercised. No firewall or
  certificate changes. QA tabs/audio/workers/server are closed after verification.
