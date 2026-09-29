# Windows LAN review service

The reviewed catalog lives outside `build/`. The checked native server and
pas2js files use fixed ignored `stable` and `qa` paths. Rebuilding Pythian
does not create a new Windows Firewall application identity for either slot.

From the repository root, stage a checked Win64 executable and the six current
workbench assets. Use the SHA-256 recorded with that checked build; replace
both placeholders when a later binary is deployed.

```powershell
& .\tools\build-label-lan-service.ps1 -CheckedExecutable 'build\<checked-target>\pythian.label.catalog.exe' -ExpectedSha256 '<recorded-checked-sha256>'
```

The staging step checks the binary hash, copies the browser assets, and refuses
to replace an executable that is running from the selected slot. It does not
change the live service or Windows Firewall.

**One-time administrator step:** Open **Windows PowerShell as Administrator**
and run this line. It allows only the fixed executable on the current private
Wi-Fi address, TCP port 18097, from the local subnet. The current address is
`192.168.12.109`; update it in both the rule and server command if the PC's
private address changes.

```powershell
New-NetFirewallRule -DisplayName 'Pythian Stable LAN Review' -Direction Inbound -Action Allow -Enabled True -Profile Private -Program 'D:\Docs\GitHub\pythian\build\label-service\stable\bin\pythian.label.catalog.exe' -Protocol TCP -LocalPort 18097 -LocalAddress 192.168.12.109 -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block
```

Verify with `netsh advfirewall firewall show rule name="Pythian Stable LAN Review" verbose`;
it must show the exact program path, LocalIP, port, Private profile,
LocalSubnet and Allow. Avoid running the rule-creation line twice; a duplicate
same-name rule obscures which scope is active. No access key is needed on this
private LAN route. The server still checks Host/Origin and its same-origin
session for writes.

After the old listener has stopped and port 18097 is free, run the checked
Pascal server directly in a foreground terminal:

```powershell
& 'D:\Docs\GitHub\pythian\build\label-service\stable\bin\pythian.label.catalog.exe' serve-app-open 'D:\Docs\GitHub\pythian\build\label-catalog\long-inbox' 'D:\Docs\GitHub\pythian-catalog' 'D:\Docs\GitHub\pythian\build\label-service\stable\www' 192.168.12.109 18097
```

The source-label queue is at `http://192.168.12.109:18097/` and complete
single/paired listening packets are at `/listen.html`. A direct PC HTTP check
does not establish that a physical phone can play and Save; that is an
outstanding [authoring acceptance check](TODO/NS-6_authoring_01.md).

Both pages show elapsed time while connecting. A session request that has not
completed in 10 seconds exposes Retry. The source page displays an actual WAV
byte-transfer percentage only after a response with `Content-Length` begins;
while the server verifies a source, the bar remains indeterminate. Full-output
audio streams in the browser and labels its percentage as buffered duration.
The checked native service keeps session and queue requests responsive during
cold large-WAV verification and listening-review saves.

For engineering browser QA, stage the checked binary in the separate fixed QA
slot. This can be done while the stable service is running; the script refuses
to replace the QA executable while a QA listener uses it. Give the fixture its
own ignored catalog and inbox, but always launch the staged QA executable from
the same path, even when the compiler output is under a dated directory:

```powershell
& .\tools\build-label-lan-service.ps1 -Slot qa -CheckedExecutable 'build\<checked-target>\pythian.label.catalog.exe' -ExpectedSha256 '<recorded-checked-sha256>'
```

Use the fixed QA path for native HTTP and browser checks. Windows showed an
application alert on this host even for a loopback QA executable. The fixed
path prevents a new identity on later builds; it does not itself install a
firewall rule. For zero prompts, do not launch the QA server until the scoped
rule below is installed, then use the private-LAN command. Stop that foreground
listener before staging a later checked binary. The stable slot and port 18097
are unaffected.

If a separate phone must reach an **isolated** QA catalog, use the fixed QA
executable with `serve-app-open` on the selected private IPv4 and TCP 18129.
First check whether `Pythian QA LAN Review` already exists. If it does, verify
its full scope before reuse; do not create a duplicate. Otherwise, the one-time
elevated Windows PowerShell rule is:

```powershell
New-NetFirewallRule -DisplayName 'Pythian QA LAN Review' -Direction Inbound -Action Allow -Enabled True -Profile Private -Program 'D:\Docs\GitHub\pythian\build\label-service\qa\bin\pythian.label.catalog.exe' -Protocol TCP -LocalPort 18129 -LocalAddress 192.168.12.109 -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block
```

Verify its program path, Private profile, LocalIP, LocalSubnet, TCP 18129 and
Allow with `netsh advfirewall firewall show rule name="Pythian QA LAN Review"
verbose`. Update the private IPv4 in both rule and launch command if it changes.
Then launch the isolated fixture in a foreground terminal:

```powershell
& 'D:\Docs\GitHub\pythian\build\label-service\qa\bin\pythian.label.catalog.exe' serve-app-open 'D:\path\to\isolated-inbox' 'D:\path\to\isolated-catalog' 'D:\Docs\GitHub\pythian\build\label-service\qa\www' 192.168.12.109 18129
```

If an administrator rule cannot be installed, use CLI checks and read-only
checks of the existing stable LAN service. Even loopback QA launches prompted
on this host, so do not start the QA server until an exact-path rule can be
installed. Do not accept a broad automatic program rule. No QA launch or
firewall change is part of the staging script.

Browser QA must use an isolated profile and record its process ID. In a
`try/finally` cleanup, pause loaded audio, close that exact QA browser process
and its children, and confirm no process still uses the QA profile. Do not
launch a test tab in the operator's normal Brave profile or leave a looping
player running after a check.

Windows previously created broad `pythian.label.catalog` application rules
for changing build paths. Before disabling any of them, verify that no
process still uses the retired executable path and no listener relies on it.
Once the stable service is confirmed, disable only rules whose **Program** is
the retired build executable and whose scope is Private+Public with Any local
port and Any remote address. Keep the narrow
named port rules and the new stable-program rule. Never disable a rule by its
display name alone because several build paths share the same name.
