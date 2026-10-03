# Windows LAN review service

The durable reviewed catalog lives outside `build/`. Checked native binaries
and the twelve matching browser assets use fixed ignored `stable` and `qa` slots.
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

For a background launch from a short-lived agent command, keep the checked
service's lifetime independent of that command. An operating-system-owned
hidden launcher can run the same guarded startup with the current user's TLS
identity and private catalog. Verify the launcher has exited while the exact
stable executable still owns the port, then check LAN HTTPS and browser loading.
A background process ID alone does not establish continued availability. Keep
machine-specific wrappers, identities and logs under ignored `build/`; do not
add automatic logon/startup registration for a one-time review launch.

Open the selected host on port18097: source review is at `/`, and complete
single/paired listening is at `/listen.html`, and project/source setup is at
`/studio.html`. Saving a Studio draft preserves setup; its Generate action starts
an explicit worker job. Run from the repository root. The private audio drop
folder defaults to `local-audio/collections/`; `PYTHIAN_AUDIO_LIBRARY` can point
to another private root containing `collections/`. No access-key form is needed in
this selected private-LAN mode; Host/Origin and same-origin write-session checks
still apply. Read-only host HTTP success is not a physical-phone play/Save verdict;
[authoring_02](TODO/NS-6_authoring_02.md) owns that acceptance.

After adding collection folders, use Studio's **Refresh library** action.
The metadata-first implementation discovers names and bounded WAV headers,
then serves the saved listing without reading full recordings. Opening a source
requests a sampled waveform; Play requests a bounded region. Adding a recording
or passage to a corpus, or preparing it for analysis/effects, explicitly verifies
only that recording. Discovery has a ten-minute worker budget and selected
preparation retains two hours, with progress, Cancel and retry. Keep enough disk
space for new selected imports. The retained legacy full-refresh operation
hashes all originals; the deployed Studio review build uses metadata discovery.
Remaining consumer checks are tracked in [studio_11](TODO/NS-6_studio_11.md).

The same service also listens at `http://127.0.0.1:18097/studio.html` on the host
computer, providing the browser context needed for microphone capture. A phone
uses the trusted HTTPS setup below. Plain HTTP can still import a WAV. Capture
is explicit and stops its device tracks on Stop or exit.

## Phone microphone over the LAN

On Windows, optional Pascal-owned Schannel transport accepts HTTPS and HTTP on
the same fixed port. The portable library has no TLS dependency. TLS uses the
current user's Windows certificate store and TLS 1.2; no external TLS runtime,
public tunnel or additional firewall rule is needed. Other native hosts retain
HTTP support and reject a requested Windows TLS configuration explicitly.

For an existing local setup, load its recorded identity under the Windows account
that runs the service. Do not generate another CA for an ordinary restart:

```powershell
$tlsConfig = Get-Content -LiteralPath .\local-audio\tls\tls.json -Raw | ConvertFrom-Json
$env:PYTHIAN_TLS_THUMBPRINT = $tlsConfig.server_thumbprint
$env:PYTHIAN_TLS_CA_FILE = $tlsConfig.public_certificate
```

For first-time setup only, use these Windows PKI commands in Windows PowerShell
5.1. First verify the selected private IPv4 is assigned to the host and that
`local-audio/tls/` does not contain an existing setup. These are operating-system
setup instructions; maintained transport and certificate validation are Pascal.

```powershell
$tlsDirectory = Join-Path $pythianRoot 'local-audio\tls'
New-Item -ItemType Directory -Path $tlsDirectory -ErrorAction Stop | Out-Null
$tlsPublicPath = Join-Path $tlsDirectory 'pythian-studio-ca.cer'
$tlsStart = (Get-Date).AddMinutes(-5)
$tlsEnd = (Get-Date).AddYears(1)
$tlsAuthority = New-SelfSignedCertificate -Type Custom -Subject 'CN=Pythian Local Studio CA' `
  -FriendlyName 'Pythian Local Studio CA' -CertStoreLocation 'Cert:\CurrentUser\My' `
  -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable `
  -KeySpec Signature -KeyUsage CertSign,CRLSign,DigitalSignature `
  -TextExtension @('2.5.29.19={critical}{text}ca=1&pathlength=0') `
  -NotBefore $tlsStart -NotAfter $tlsEnd
$tlsLeaf = New-SelfSignedCertificate -Type Custom -Subject 'CN=Pythian Local Studio' `
  -FriendlyName 'Pythian Local Studio LAN server' -CertStoreLocation 'Cert:\CurrentUser\My' `
  -Signer $tlsAuthority -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
  -Provider 'Microsoft RSA SChannel Cryptographic Provider' -KeySpec KeyExchange `
  -KeyExportPolicy NonExportable -KeyUsage DigitalSignature,KeyEncipherment `
  -TextExtension @("2.5.29.17={text}IPAddress=$reviewIPv4&IPAddress=127.0.0.1&DNS=localhost", `
    '2.5.29.37={text}1.3.6.1.5.5.7.3.1', '2.5.29.19={critical}{text}ca=0') `
  -NotBefore $tlsStart -NotAfter $tlsEnd.AddMinutes(-1)
Export-Certificate -Cert $tlsAuthority -FilePath $tlsPublicPath -Type CERT | Out-Null
[ordered]@{
  format = 'pythian.local-tls.v1'; lan_address = $reviewIPv4
  ca_thumbprint = $tlsAuthority.Thumbprint; server_thumbprint = $tlsLeaf.Thumbprint
  ca_sha256 = (Get-FileHash -LiteralPath $tlsPublicPath -Algorithm SHA256).Hash.ToLowerInvariant()
  expires_utc = $tlsLeaf.NotAfter.ToUniversalTime().ToString('o'); public_certificate = $tlsPublicPath
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $tlsDirectory 'tls.json') -Encoding UTF8
```

Load that recorded identity using the first snippet. The CA and server certificate
last one year; private keys remain non-exportable in `CurrentUser/My`. The SANs
cover the selected LAN IPv4, loopback and localhost. Public certificate and local
configuration stay in ignored `local-audio/tls/`. A changed address, expired
certificate or missing key requires deliberate replacement and renewed phone
trust. Keep the old identity recorded until its replacement is verified.

For normal browser verification on the host, install only this public CA into
`CurrentUser/Root`. Run interactively, compare the fingerprint and approve
**Pythian Local Studio CA** in the Windows confirmation; do not repeat this when
the same CA is already trusted. This does not disable certificate validation:

```powershell
Get-FileHash -LiteralPath $tlsConfig.public_certificate -Algorithm SHA256
Import-Certificate -FilePath $tlsConfig.public_certificate -CertStoreLocation 'Cert:\CurrentUser\Root'
```

Stage the checked TLS-capable service and its twelve assets, then run the usual
fixed-slot launch with both environment variables set. No certificate or private
key belongs in Git. The service only publishes a validated public CA DER file,
bounded to 16 KiB; private-key or arbitrary-file downloads are not supported.

On the Android phone, open the supplied HTTPS Studio URL, tap **Record audio**,
then **Start microphone** and allow microphone access. The operator has chosen
to allow the browser's certificate exception for this local service and reports
that it worked. Browser/version behavior can differ; this does not make the
certificate trusted or independently verify every capture step.

Certificate installation is an optional route to warning-free HTTPS:

1. Open the host's ordinary HTTP `/phone-setup.html` page and download the certificate.
2. In Android Settings, search for certificate installation, choose **CA certificate**,
   and select `pythian-studio-ca.cer`. Menu names vary by phone; use the CA option,
   not Wi-Fi or VPN/client-certificate installation.
3. Return to the setup page and tap **Open HTTPS Studio in Brave**. The HTTPS address uses
   the same host and port. Tap **Record audio**, then **Start microphone**, and
   allow the browser's microphone request.

A loaded page alone does not establish microphone support. If the browser still
blocks capture after the chosen exception, use certificate installation. Only an
actual phone recording, Stop and audible preview close
[studio_10](TODO/NS-6_studio_10.md)'s physical-device criterion. A generated QA
microphone proves the capture lifecycle, not physical audibility.

HTTP and HTTPS enforce their actual scheme in Host/Origin checks. HTTPS media
uses its own Secure, HttpOnly, SameSite cookie so a prior HTTP tab cannot replace
it. The local catalog, review records and collection membership are unchanged by
certificate setup. To remove host trust later, remove only the recorded CA
thumbprint from `CurrentUser/Root`; remove that named CA from the phone's user
credentials. Do not clear unrelated certificates.

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
