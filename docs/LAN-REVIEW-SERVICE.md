# Windows LAN review service

The durable reviewed catalog lives outside `build/`. Checked native binaries
and the ten matching browser assets use fixed ignored `stable` and `qa` slots.
Studio jobs use the matching `pythian.studio.worker.exe` beside the service.
The paths stay fixed across rebuilds so Windows Firewall does not see a new
application identity. Host addresses and catalog locations are local settings;
never copy a historical machine address or process ID into a new launch.

## Configure this machine

Run from the repository root. Supply the private IPv4 assigned to this machine
and existing prepared inbox/durable catalog roots. Keep these values in local
configuration or ignored build records, not tracked project files. Repeat this
setup in an elevated terminal when installing a firewall rule.

```powershell
$pythianRoot = (Get-Location).Path
$reviewIPv4 = Read-Host 'Private IPv4 assigned to this host'
$reviewInbox = (Resolve-Path -LiteralPath (Read-Host 'Prepared inbox directory')).Path
$reviewCatalog = (Resolve-Path -LiteralPath (Read-Host 'Durable catalog directory outside build')).Path
$stableProgram = Join-Path $pythianRoot 'build\label-service\stable\bin\pythian.label.catalog.exe'
$stableWeb = Join-Path $pythianRoot 'build\label-service\stable\www'
$qaProgram = Join-Path $pythianRoot 'build\label-service\qa\bin\pythian.label.catalog.exe'
$qaWeb = Join-Path $pythianRoot 'build\label-service\qa\www'
```

Verify that the selected interface has the Private network profile. The service
also rejects an invalid bind address. The user-selected inbox and catalog must
be correct for the intended mode; QA always uses separate copies.

## Stage and run the stable slot

Stage a checked Win64 executable and matching assets. Replace both placeholders
with the exact checked build and its recorded SHA-256.

```powershell
& .\tools\build-label-lan-service.ps1 -CheckedExecutable 'build\<checked-target>\pythian.label.catalog.exe' -ExpectedSha256 '<recorded-service-sha256>' -CheckedWorker 'build\<checked-target>\pythian.studio.worker.exe' -ExpectedWorkerSha256 '<recorded-worker-sha256>'
```

Staging verifies the binary hash and refuses to replace a running slot. It does
not change a running service or firewall rules. Build the browser assets with
explicit matched pas2js/RTL settings documented in the
[workbench build configuration](LABEL-CATALOG.md#workbench-build-configuration).

**One-time administrator step:** inspect the existing rule first. If it is
absent, create the exact fixed-program, Private/local-subnet rule below in
Windows PowerShell as Administrator. Do not create duplicate same-name rules.

```powershell
netsh advfirewall firewall show rule name="Pythian Stable LAN Review" verbose
New-NetFirewallRule -DisplayName 'Pythian Stable LAN Review' -Direction Inbound -Action Allow -Enabled True -Profile Private -Program $stableProgram -Protocol TCP -LocalPort 18097 -LocalAddress $reviewIPv4 -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block
```

Verify exact Program, LocalIP, TCP18097, Private, LocalSubnet and Allow.
If the address or checkout root changes, update the existing rule and launch
settings together. After the old listener has stopped and the port is free,
run the staged Pascal server in a foreground terminal:

```powershell
& $stableProgram serve-app-open $reviewInbox $reviewCatalog $stableWeb $reviewIPv4 18097
```

Open the selected host on port18097: source review is at `/`, and complete
single/paired listening is at `/listen.html`, and project/source setup is at
`/studio.html`. Saving a Studio draft preserves setup; its Generate action starts
an explicit worker job. Run from the repository root. The private audio drop
folder defaults to `local-audio/collections/`; `PYTHIAN_AUDIO_LIBRARY` can point
to another private root containing `collections/`. No access-key form is needed in
this selected private-LAN mode; Host/Origin and same-origin write-session checks
still apply. Read-only host HTTP success is not a physical-phone play/Save verdict;
[authoring_02](TODO/NS-6_authoring_02.md) owns that acceptance.

The same service also listens at `http://127.0.0.1:18097/studio.html` on the host
computer, providing the browser context needed for microphone capture. A phone
on plain LAN HTTP can import a WAV; microphone access there requires a supported
secure origin. Capture is explicit and stops its device tracks on Stop or exit.

Connection status exposes Retry after ten seconds. The source player shows
actual transferred WAV bytes when Content-Length is known; source verification
remains indeterminate. Full-output playback reports buffered duration. Preserve
the existing session/queue responsiveness checks for changed serving paths.

## Isolated QA slot

Stage the same checked binary/assets into the fixed QA slot; the live stable
slot remains independent.

```powershell
& .\tools\build-label-lan-service.ps1 -Slot qa -CheckedExecutable 'build\<checked-target>\pythian.label.catalog.exe' -ExpectedSha256 '<recorded-service-sha256>' -CheckedWorker 'build\<checked-target>\pythian.studio.worker.exe' -ExpectedWorkerSha256 '<recorded-worker-sha256>'
```

Use this slot for **every native HTTP or browser QA launch**, even loopback.
A fixed path does not itself install a firewall rule. On hosts requiring the
explicit rule, do not launch QA until its exact scope is installed; the prior
development host also prompted on loopback. Inspect before creating:

```powershell
netsh advfirewall firewall show rule name="Pythian QA LAN Review" verbose
New-NetFirewallRule -DisplayName 'Pythian QA LAN Review' -Direction Inbound -Action Allow -Enabled True -Profile Private -Program $qaProgram -Protocol TCP -LocalPort 18129 -LocalAddress $reviewIPv4 -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block
```

Verify exact Program, LocalIP, TCP18129, Private, LocalSubnet and Allow.
Use separate fixture directories and a foreground terminal:

```powershell
$qaInbox = (Resolve-Path -LiteralPath (Read-Host 'Isolated QA inbox directory')).Path
$qaCatalog = (Resolve-Path -LiteralPath (Read-Host 'Isolated QA catalog directory')).Path
& $qaProgram serve-app-open $qaInbox $qaCatalog $qaWeb $reviewIPv4 18129
```

Never write test answers into the live operator catalog. Stop the exact QA
listener before replacing its slot. If the required rule is unavailable, use
CLI checks and authorized read-only checks of an existing service, recording
browser/phone acceptance as unverified. The staging script neither launches
servers nor changes firewall rules.

Browser QA uses an isolated profile and records the exact process tree. In
`try/finally`, pause audio, close that QA process and its children, and confirm
no process uses the QA profile and no looping audio remains. Keep the operator's
normal browser separate. A documentation/build-configuration check needs no
service or browser.

Before disabling an old broad application rule, verify the retired executable
path has no process or listener depending on it. Match exact Program plus the
obsolete broad scope, never display name alone. Preserve narrow active rules.
