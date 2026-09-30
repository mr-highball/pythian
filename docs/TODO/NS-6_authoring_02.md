# NS-6_authoring_02 — Verify physical LAN listening and final operator use

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Close the actual operator listening path and full end-to-end QA after the
editor/queue contract is accepted. The native Pascal service owns media,
sessions and durable commits; the Pascal/pas2js pages provide the operator UI.
A desktop or emulated narrow-screen pass does not substitute for an audible
physical-phone playback and successful Save on the selected private LAN.

North star: NS-6. Outcome owner: WAV-05-AUTHORING.
Completion credit: 8 goal percentage points (0.80 overall points).
Current complete-goal allocation, 2026-09-29, with NS-6 weighted at 10 overall points,
under the user's authorization
to rebalance without preserving historical point allocations. All existing
acceptance criteria remain required; this plan revision earns no acceptance.
Allocation rationale: Actual physical LAN listening and full operator QA establish usable, audible feedback rather than isolated UI mechanics.
Credit is earned only when every acceptance criterion and the task-flow
completion requirements pass.

Starting evidence: [editor and queue](NS-6_authoring_01.md) ·
[LAN procedure](../LAN-REVIEW-SERVICE.md) · [review queue](../REVIEW-QUEUE.md) ·
[phone Save repair](../WORK-HISTORY.md#phone-save-request-header-repair--2026-09-29).

Execution status: open; repaired isolated browser/HTTP checks do not close the
physical-phone verdict, and the fixed QA firewall prerequisite remains external.
Next deliverable: frozen-asset copied-catalog full QA plus physical LAN play/Save.
Closing evidence: device/network, binary/assets, audible results, durable Save,
reload/report and independent QA records. Stop at missing device/firewall
permission or a concrete failure; record its unblock condition and keep open.

**Acceptance Criteria:**

Own the original authoring checklist points 4, 5 and 10 below, with their
original wording and numbering. The retained detailed D1–D6 bullets and owner
map in [authoring_01](NS-6_authoring_01.md#retained-original-detailed-criteria-and-owner-map)
are normative: this task closes their LAN/session, physical/audio listening
and complete operator QA portions. Historic checked boxes do not replace a
current combined-path verdict.

- [ ] **4. Private-LAN startup:** Default loopback and explicitly selected
  private-LAN binding work after restart, with no access-key form or credential
  entry. A physical phone on the LAN connects; Host/Origin and same-origin
  session checks remain effective, no token appears in an audio URL, and the
  service is reachable under an installed Private/local-subnet/TCP-port and
  stable-program firewall rule without repeated Windows Defender prompts for
  each new build path.
- [ ] **5. Listen before labeling:** Original and available Pythian cue audio
  load, decode and audibly play on the operator path for 0.5-second, 5-second
  and bounded longer regions. Seek, loop, readiness and errors are clear next
  to the player on a narrow screen. Exercise malformed/unauthorized/range,
  disconnected and slow responses, followed by a successful retry; no silent
  player or `0:00` display is counted as verified sound.
- [ ] **10. Complete QA matrix:** On a copied catalog, run import → Pascal
  proposals → original/cue listening → wrong-suggestion correction → approved
  and unknown answers → queue advance → reload/restart → worker report →
  export/re-import, with at least two source groups and a long-source case.
  Include all error/retry boundaries in points 3–9, actual desktop and narrow
  browser interaction, and the physical LAN phone playback/Save path that
  previously failed. Salty Boi independently validates the frozen binary and
  pas2js assets, records exact evidence and confirms no test answer touched
  the live operator catalog.

- Record exact source revision, fixed-slot binary and six browser asset hashes,
  copied-catalog identities, physical device/browser/network, audible results,
  Save/reload/producer-report evidence and independent Salty Boi verdict.
  Use only the fixed stable/QA executable slots and exact-path firewall setup
  in the LAN procedure. Isolate browser QA, close its exact process tree and
  verify no QA browser or looping audio remains. Never write test answers to
  the live operator catalog.

**Blockers**

- [NS-6_authoring_01.md](NS-6_authoring_01.md)

**Dev Notes:**

- 2026-09-29 current complete-goal credit basis: this task owns 8 NS-6
  goal points (+0.80 overall) by deliverable value. Nine open NS-6
  tasks allocate 85 goal points (+8.50 overall); the accepted contract and
  native checkpoint allocate 15 goal points (+1.50 overall), with zero baseline.
  Lifecycle support and actual ecosystem adoption are now explicit required
  outcomes. Earlier point amounts and conserved split totals are historical,
  superseded by this user-directed scope reassessment. Criteria and evidence
  requirements remain intact; planning earns no acceptance.


- 2026-09-29 the split preserves original points 4, 5 and 10 and every
  associated detailed acceptance condition. Current evidence includes a
  physical-phone Save failure with HTTP 431 and focused cookie/header repair;
  the repaired isolated 390 px path is not the physical-phone retest. The
  exact-path QA firewall rule requires a one-time elevated install before
  another isolated server/browser run; see the linked LAN procedure and work
  record. Next deliverable: a copied-catalog full matrix plus the actual
  physical LAN play/Save verdict using the frozen current assets. Stop at a
  missing device/firewall permission or concrete failure, record the unblock
  condition, and keep this task open. No musical ground-truth, independent
  consumer or final style credit follows from accepting this operator path.
