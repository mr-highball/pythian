# Windows LAN review service

The reviewed catalog lives outside `build/`. The checked native server and
pas2js files are staged under one fixed ignored path, so rebuilding Pythian
does not create a new Windows Firewall application identity each time.

From the repository root, stage a checked Win64 executable and the six current
workbench assets. Replace the hash when a later checked binary is deployed.

```powershell
& .\tools\build-label-lan-service.ps1 -CheckedExecutable 'build\listen-verify-worker-20260928\win64\pythian.label.catalog.exe' -ExpectedSha256 '579AD33E02759890AB873750FD6AC9251C7DCA80F34FC0314673DA57A08F80A8'
```

The staging step checks the binary hash, copies the browser assets, and refuses
to replace an executable that is running from the stable path. It does not
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

For engineering browser QA, bind to `127.0.0.1` and reuse one fixed checked
executable path. Put each isolated fixture catalog in its own ignored directory,
but do not copy the server executable into a new per-test path; Windows can
show another application alert for each distinct executable path. Stop the QA
listener before replacing its executable.

Windows previously created broad `pythian.label.catalog` application rules
for changing build paths. Before disabling any of them, verify that no
process still uses the retired executable path and no listener relies on it.
Once the stable service is confirmed, disable only rules whose **Program** is
the retired build executable and whose scope is Private+Public with Any local
port and Any remote address. Keep the narrow
named port rules and the new stable-program rule. Never disable a rule by its
display name alone because several build paths share the same name.
