# MIT License
#
# Copyright (c) 2026 mr-highball
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

[CmdletBinding()]
param(
  [string] $CheckedExecutable,
  [string] $ExpectedSha256,
  [string] $CheckedWorker,
  [string] $ExpectedWorkerSha256,
  [string] $WebRoot,
  [ValidateSet('stable', 'qa')]
  [string] $Slot = 'stable'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$targetRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "build\label-service\$Slot"))
$targetBin = Join-Path $targetRoot 'bin'
$targetWeb = Join-Path $targetRoot 'www'
$targetExe = Join-Path $targetBin 'pythian.label.catalog.exe'
$targetWorker = Join-Path $targetBin 'pythian.studio.worker.exe'
$targetHashFile = Join-Path $targetRoot 'executable.sha256'
$webNames = @('index.html', 'app.js', 'style.css',
  'listen.html', 'listen.js', 'listen.css',
  'studio.html', 'studio.js', 'studio.css', 'capture-worklet.js', 'workspace-nav.css',
  'phone-setup.html')

function Require-WithinTarget([string] $Path) {
  $resolved = [IO.Path]::GetFullPath($Path)
  $prefix = $targetRoot.TrimEnd('\') + '\'
  if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Deployment target escapes $Slot service root: $resolved"
  }
  return $resolved
}

function Require-TargetExecutable {
  if (-not (Test-Path -LiteralPath $targetExe -PathType Leaf)) {
    throw "Prepare the $Slot executable first: $targetExe"
  }
  if (-not (Test-Path -LiteralPath $targetHashFile -PathType Leaf)) {
    throw "$Slot executable hash record is missing: $targetHashFile"
  }
  $expected = (Get-Content -LiteralPath $targetHashFile -Raw).Trim()
  if ($expected -notmatch '^[0-9a-f]{64}$') {
    throw "$Slot executable hash record is malformed"
  }
  $actual = (Get-FileHash -LiteralPath $targetExe -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "$Slot executable differs from the checked SHA-256"
  }
}

if ([string]::IsNullOrWhiteSpace($CheckedExecutable) -or
    [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
  throw 'Build staging requires -CheckedExecutable and -ExpectedSha256'
}
if ($ExpectedSha256 -notmatch '^[0-9a-fA-F]{64}$') {
  throw 'ExpectedSha256 must be 64 hexadecimal characters'
}
$sourceExe = (Resolve-Path -LiteralPath $CheckedExecutable).Path
$expected = $ExpectedSha256.ToLowerInvariant()
$sourceHash = (Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceHash -ne $expected) {
  throw 'Checked executable does not match ExpectedSha256'
}
$sourceWorker = $null
if (-not [string]::IsNullOrWhiteSpace($CheckedWorker)) {
  if ($ExpectedWorkerSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'Supply the checked worker SHA-256 with -ExpectedWorkerSha256'
  }
  $sourceWorker = (Resolve-Path -LiteralPath $CheckedWorker).Path
  if ((Get-FileHash -LiteralPath $sourceWorker -Algorithm SHA256).Hash -ine $ExpectedWorkerSha256) {
    throw 'Studio worker differs from its checked SHA-256'
  }
} elseif (Test-Path -LiteralPath $targetWorker -PathType Leaf) {
  throw 'This slot contains a Studio worker; stage its checked matching worker with the service'
}
$sourceWeb = if ([string]::IsNullOrWhiteSpace($WebRoot)) {
  Join-Path $repositoryRoot 'build\label-workbench\www'
} else {
  (Resolve-Path -LiteralPath $WebRoot).Path
}
foreach ($name in $webNames) {
  if (-not (Test-Path -LiteralPath (Join-Path $sourceWeb $name) -PathType Leaf)) {
    throw "Missing staged browser asset: $name"
  }
}
$running = @(Get-CimInstance Win32_Process -Filter "name = 'pythian.label.catalog.exe'" |
  Where-Object { $_.ExecutablePath -and
    ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $targetExe) })
if ($running.Count -ne 0) {
  throw "$Slot service is running; coordinate its stop before preparing another binary"
}
$runningWorker = @(Get-CimInstance Win32_Process -Filter "name = 'pythian.studio.worker.exe'" |
  Where-Object { $_.ExecutablePath -and
    ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $targetWorker) })
if ($runningWorker.Count -ne 0) {
  throw "$Slot Studio worker is running; wait for its job or stop its service before staging"
}
New-Item -ItemType Directory -Force -Path $targetBin, $targetWeb | Out-Null
$temporaryExe = Require-WithinTarget ($targetExe + '.partial')
Copy-Item -LiteralPath $sourceExe -Destination $temporaryExe -Force
$copiedHash = (Get-FileHash -LiteralPath $temporaryExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($copiedHash -ne $expected) {
  throw 'Copied executable failed SHA-256 verification'
}
Move-Item -LiteralPath $temporaryExe -Destination (Require-WithinTarget $targetExe) -Force
if ($sourceWorker) {
  $temporaryWorker = Require-WithinTarget ($targetWorker + '.partial')
  Copy-Item -LiteralPath $sourceWorker -Destination $temporaryWorker -Force
  if ((Get-FileHash -LiteralPath $temporaryWorker -Algorithm SHA256).Hash -ine $ExpectedWorkerSha256) {
    throw 'Copied Studio worker failed SHA-256 verification'
  }
  Move-Item -LiteralPath $temporaryWorker -Destination (Require-WithinTarget $targetWorker) -Force
  Set-Content -LiteralPath (Join-Path $targetRoot 'worker.sha256') -Value $ExpectedWorkerSha256.ToLowerInvariant() -NoNewline
}
foreach ($name in $webNames) {
  $target = Require-WithinTarget (Join-Path $targetWeb $name)
  Copy-Item -LiteralPath (Join-Path $sourceWeb $name) -Destination $target -Force
}
Set-Content -LiteralPath $targetHashFile -Value $expected -NoNewline
Require-TargetExecutable
Write-Output "Prepared $targetExe SHA256 $expected"
Write-Output "Static root: $targetWeb"
Write-Output 'The running service and Windows Firewall were not changed.'
