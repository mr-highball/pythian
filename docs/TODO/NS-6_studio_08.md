# NS-6_studio_08 — Make starting actions and review queues discoverable

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Give the sole operator a clear starting point for existing music, recording and
reviewing results. Connect the existing private collection to the deployed app,
expose recording/import before project setup, and replace plain workspace links
with consistent navigation, truthful attention badges and a useful next action.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [authoring_02](NS-6_authoring_02.md);
all of its physical-device and complete-workflow criteria remain required.

Execution status: selected after actual phone feedback on 2026-10-01. Big Boss
owns integration and existing transferred UI/HTTP repairs. Neo owns new shared
navigation and private-corpus assessment; Ticket Guy owns capture entry methods.
Closing evidence is the actual existing music appearing in the deployed library,
independent desktop/narrow starting-action and queue-state checks, and preserved
source/review identities. Stop on fabricated counts, hidden failures, lost edits,
changed source provenance or unsupported microphone claims. No credit at scoping.

**Acceptance Criteria:**

- AC1: Studio opens with prominent Record audio, Import WAV and Browse collection
  actions, before project naming. Recording remains explicitly started by the
  user; opening its panel cannot discard retained input or ask for microphone
  permission automatically. Unsupported contexts explain the actual next step.
- AC2: All three workspaces share accessible icon/text navigation with a clear
  active destination. Badges count actual requests awaiting a response, keep
  Studio feedback distinct from other listening requests, and never double-count
  hidden blind requests. Loading, empty, stale/error and pending states differ.
  Counts refresh after response changes and returning to the page, with bounded
  background work. A next-action link leads to the relevant visible workflow.
- AC3: The operator's existing private audio is discoverable by its collection
  names without copying media into Git. Preserve original bytes and available
  source provenance, family and use restrictions; retain the current review
  catalog and answers. Do not turn generated samples into independent recordings
  or silently assign unknown material to training. Explain absent versus empty
  collections, and distinguish a collection from a saved corpus/project.
- AC4: Independently exercise desktop/narrow and keyboard entry, real source and
  listening queue transitions, completed/withdrawn responses, failed queue reads
  and recovery. Verify immediate badge updates after Save, active-page state,
  next-action destination and no overflow. Record microphone capability honestly
  on the actual origin, preserving capture cancellation and device cleanup.

**Blockers**

- [NS-6_studio_09.md](NS-6_studio_09.md)
- [NS-6_studio_01.md](DONE/NS-6_studio_01.md)
- [NS-6_studio_04.md](DONE/NS-6_studio_04.md)
- [NS-6_studio_06.md](DONE/NS-6_studio_06.md)
- [NS-6_authoring_01.md](DONE/NS-6_authoring_01.md)

**Dev Notes:**

- 2026-10-01, Big Boss: navigation submission 1 failed independent recovery QA:
  a timed-out count request kept its in-flight flag forever, so Refresh could not
  replace it. Neo owns bounded request cancellation and retry; exact failure and
  cleaned-up browser evidence remain in `build/salty-studio-onboarding-20261001/`.
  Native review ownership checks pass 47 assertions on both Windows targets.
  The distinct large-library prerequisite is owned by [studio_09](NS-6_studio_09.md).
- 2026-10-01, Big Boss: the user's phone screenshots show two piano fixtures,
  a buried recording disclosure and plain source/listening links. Neo found
  the existing three preference recordings in a different private catalog;
  the deployed catalog has only the piano excerpts and the new drop folders
  are empty. This is a deployment/discoverability gap, not missing audio or a
  reason to ask the operator to recreate existing material. Paths and private
  manifests stay in ignored evidence. Studio_03's operator verdict remains open.
- 2026-10-01, Big Boss: direct phone microphone use on plain LAN HTTP is a
  separate secure-origin requirement. Do not represent a localhost link as
  connecting to the host from a phone or weaken browser security to enable it.
  Scope that prerequisite separately if phone recording is selected.
