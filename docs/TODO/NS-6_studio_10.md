# NS-6_studio_10 — Enable trusted phone recording on the private LAN

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Let the operator record from Android Brave through a trusted HTTPS connection
to the existing local Windows service. Supply concise certificate onboarding
from the disabled microphone state while retaining HTTP bootstrap and host
localhost recording. Portable synthesis and WFC remain independent of TLS.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 1 goal percentage point (0.10 overall points).
Basis: one unearned point transfers from [authoring_02](NS-6_authoring_02.md);
all physical-device and complete-workflow criteria there remain required.

Execution status: selected on 2026-10-01; OPEN with no earned credit. Big Boss
owns HTTP/build/deployment integration and final judgment; Neo owns native
Schannel transport and tests; Ticket Guy owns the disjoint setup/capture link
and accounting. The same-port HTTPS service, public certificate download and
setup page are deployed for limited local review; independent native boundary
checks pass, while trusted browser and physical-phone checks remain open.
Next closing work: verify trusted capture on the host and the actual phone.
Closing evidence: independent
native/browser transport and capture checks plus the operator's actual Android
Brave recording, Stop and audible preview. Preserve input, catalog and device
cleanup identities. Stop on private-key exposure, a certificate-warning bypass,
lost state or a phone-success claim supported only by emulation.

**Acceptance Criteria:**

- AC1: Pascal-owned Windows Schannel TLS serves the existing private-LAN port,
  with bounded connection/handshake/read/write failures and correct shutdown,
  worker/media socket ownership and cleanup. HTTP bootstrap and host localhost
  remain supported. Core/WFC acquire no TLS or browser dependency.
- AC2: `/phone-ca.cer` downloads only this computer's public CA DER certificate,
  at most 16 KiB. `/phone-setup.html` shows the supplied HTTPS Studio URL and
  matching public certificate SHA-256, concise Android CA-install/Brave steps,
  and removal details. The insecure-LAN capture state links to setup. No private
  key, accounts, tunnel, warning bypass or extra application confirmation enters
  the flow. Opening setup does not discard pending input or request microphone
  permission automatically.
- AC3: Independently verify trusted HTTPS, exact HTTPS Origin/session handling,
  bounded malformed/untrusted/timeout failures, reconnect/media handoff and
  desktop/narrow onboarding. Exercise actual secure-context record, Stop,
  playback, upload/inspection and device/context cleanup with preserved data.
  Native/browser mechanics alone do not establish physical-phone acceptance.
- AC4: The actual operator installs the public certificate on the selected
  Android phone, opens the trusted HTTPS Studio URL in Brave, grants microphone
  permission, records, stops and hears the retained preview. Record the actual
  device/browser/origin and outcome privately. Keep this criterion open until
  observed; do not substitute localhost on another computer or emulation.

**Blockers**

- [NS-6_studio_06.md](DONE/NS-6_studio_06.md)
- [NS-6_studio_08.md](DONE/NS-6_studio_08.md)

**Dev Notes:**

- 2026-10-01, Big Boss / Neo: user explicitly selects phone recording. One
  unearned authoring_02 point funds this separate secure-origin prerequisite;
  authoring_02 retains all original obligations at 1 goal / 0.10 overall points.
  Accepted completion stays 50.80; 88 tasks comprise 46 open and 42 DONE.
  Prior transferred UI/native failures and historical unknown counters remain
  with their original tasks. This new component starts at zero submitted QA
  failures and earns no credit from planning or compilation. A second failed
  implementation submission transfers the assigned task directly to Big Boss.
- 2026-10-01, Big Boss / Neo, retained development corrections: the first
  Windows PowerShell 5.1 parameter-binding attempt failed before certificate
  mutation. Native startup then exposed an incorrect Schannel client protocol
  mask; Neo corrected it to the TLS 1.2 server mask `0x400`. The original failed
  startup and zero-leak trace remain in `build/studio-phone-https/`. A normal
  noninteractive Windows trust import refused its required confirmation UI;
  the interactive OS confirmation remains pending. No repeated installer or
  trust-warning bypass qualifies any result.
- 2026-10-01, Big Boss, maintained-tool boundary correction: certificate setup
  is documented as direct Windows PKI commands in the
  [LAN procedure](../LAN-REVIEW-SERVICE.md#phone-microphone-over-the-lan).
  The provisional setup script bytes at removal are preserved only in ignored
  `build/studio-phone-https/EXECUTED-LOCAL-CERTIFICATE-SETUP.ps1`
  (SHA-256 `a6d96e3f97f04726640736730a6bbed254aa7ce4aca23dc8f96e39957fdda842`).
  Its generation logic produced the installed identities; diagnostic printing
  changed after the first trust attempt, so the archive is not a byte-for-byte
  record of every earlier execution. It is excluded from maintained publication;
  existing certificate identities
  and non-exportable OS keys are unchanged. Pascal validates the bounded public
  DER, CA constraints/time/self-signature and the selected leaf's issuer/signature.
- 2026-10-01, Salty / Neo, independent native preparation PASS: checked FPC 3.2.2
  Win32 and Win64 each pass 31 no-network baseline assertions and 38 assertions
  in certificate mode (including the same baseline), with zero unfreed blocks.
  Evidence is `build/salty-studio-phone-https-20261001/`; producer development
  logs and frozen source hashes are in `build/phone-tls-dev/`. The independent
  WinHTTP integration client compiles on both targets; normal trusted HTTPS
  execution and TLS media-worker handoff are not inferred from compilation.
  Big Boss separately verified HTTPS Studio and exact public-CA download using
  an explicit CA and normal chain/name/time checks. The private offline CA has
  no CRL distribution point; curl's best-effort revocation policy was recorded,
  without disabling certificate-chain or hostname validation.
- 2026-10-01, Big Boss / Salty, current UI and execution limits: static review
  found the setup link would replace the current Studio tab. Big Boss added
  `target="_blank"` and `rel="noopener"`; matched browser compilation passes.
  Candidate 2 changes only `studio.js`; native binaries and eleven other web
  assets match candidate 1. These link attributes have static evidence only.
  Automatic approval review rejected isolated HTTP-browser preparation/launch
  before execution; no browser or preparation files were created and no
  alternate launch bypassed that rejection. This is an execution gate, not an
  implementation QA failure. Trusted host browser/capture and actual Android
  Brave recording/preview remain unverified. AC3 and AC4 stay OPEN; task credit
  remains zero and accepted completion remains 50.80.
- 2026-10-01, Salty / Neo, limited native/static engineering PASS: one actual
  outbound raw-failure run passes 119 assertions in 10.188 seconds with zero
  unfreed blocks. Idle initial bytes close in 5.063 seconds, invalid zero-length
  TLS in 47 milliseconds and an incomplete ClientHello in 5.063 seconds. No
  failed TLS connection downgrades to HTTP; HTTP setup and session recovery
  pass after each case. The final verdict and `raw-final/` logs are retained in
  `build/salty-studio-phone-https-20261001/`; verdict SHA-256 is
  `7f90dd5e3ebcab56a39bbbddcd53244aae4777937f0ffe3366a7c7fd3ebf5f01`.
  Exact isolated QA server, listener and profile counts are all zero. No browser
  launched, and forced server cleanup does not establish a natural server
  heap-exit trace. Independent implementation QA failures remain zero; local
  development corrections and the tool rejection remain recorded separately.
- 2026-10-01, Big Boss, limited review deployment: candidate 2's fourteen
  artifacts match the fixed stable slot. Explicit-CA HTTPS Studio, HTTP setup
  and the exact 791-byte public CA download pass; all 2,567 prior catalog
  metadata identities remain unchanged. Private deployment evidence is
  `build/studio-phone-https/LIVE-DEPLOYMENT.json`. Normal trusted WinHTTP media,
  HTTPS browser capture and actual Android Brave Record/Stop/audible preview
  remain unexecuted. This is consecutive nonclosing batch 1: no complete
  criterion closes, no task moves to DONE and accepted completion stays 50.80.
