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
  [string] $WebRoot
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stableRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'build\label-service\stable'))
$stableBin = Join-Path $stableRoot 'bin'
$stableWeb = Join-Path $stableRoot 'www'
$stableExe = Join-Path $stableBin 'pythian.label.catalog.exe'
$stableHashFile = Join-Path $stableRoot 'executable.sha256'
$webNames = @('index.html', 'app.js', 'style.css',
  'listen.html', 'listen.js', 'listen.css')

function Require-WithinStable([string] $Path) {
  $resolved = [IO.Path]::GetFullPath($Path)
  $prefix = $stableRoot.TrimEnd('\') + '\'
  if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Deployment target escapes stable service root: $resolved"
  }
  return $resolved
}

function Require-StableExecutable {
  if (-not (Test-Path -LiteralPath $stableExe -PathType Leaf)) {
    throw "Prepare the stable executable first: $stableExe"
  }
  if (-not (Test-Path -LiteralPath $stableHashFile -PathType Leaf)) {
    throw "Stable executable hash record is missing: $stableHashFile"
  }
  $expected = (Get-Content -LiteralPath $stableHashFile -Raw).Trim()
  if ($expected -notmatch '^[0-9a-f]{64}$') {
    throw 'Stable executable hash record is malformed'
  }
  $actual = (Get-FileHash -LiteralPath $stableExe -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw 'Stable executable differs from the checked SHA-256'
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
    ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $stableExe) })
if ($running.Count -ne 0) {
  throw 'Stable service is running; coordinate its stop before preparing another binary'
}
New-Item -ItemType Directory -Force -Path $stableBin, $stableWeb | Out-Null
$temporaryExe = Require-WithinStable ($stableExe + '.partial')
Copy-Item -LiteralPath $sourceExe -Destination $temporaryExe -Force
$copiedHash = (Get-FileHash -LiteralPath $temporaryExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($copiedHash -ne $expected) {
  throw 'Copied executable failed SHA-256 verification'
}
Move-Item -LiteralPath $temporaryExe -Destination (Require-WithinStable $stableExe) -Force
foreach ($name in $webNames) {
  $target = Require-WithinStable (Join-Path $stableWeb $name)
  Copy-Item -LiteralPath (Join-Path $sourceWeb $name) -Destination $target -Force
}
Set-Content -LiteralPath $stableHashFile -Value $expected -NoNewline
Require-StableExecutable
Write-Output "Prepared $stableExe SHA256 $expected"
Write-Output "Static root: $stableWeb"
Write-Output 'The running service and Windows Firewall were not changed.'
