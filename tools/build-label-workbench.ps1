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
  [string] $Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else {
    'D:\ProgramsAndSuch\fpcupdeluxe\lazarus-trunk\fpc\bin\i386-win32\pas2js.exe'
  }),
  [string] $RtlSource = 'D:\ProgramsAndSuch\fpcupdeluxe\lazarus-trunk\ccr\pas2js-rtl\packages\rtl\src',
  [string] $RtlJavascript = 'D:\ProgramsAndSuch\fpcupdeluxe\lazarus-trunk\fpcsrc\utils\pas2js\dist\rtl.js'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $PSScriptRoot 'label-workbench'
$outputRoot = Join-Path $repositoryRoot 'build\label-workbench'
$unitRoot = Join-Path $outputRoot 'units'
$webRoot = Join-Path $outputRoot 'www'
$program = Join-Path $sourceRoot 'app.lpr'

foreach ($required in @($program, (Join-Path $sourceRoot 'index.html'),
    (Join-Path $sourceRoot 'style.css'), $RtlJavascript,
    (Join-Path $RtlSource 'web.pas'))) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Missing workbench source or matched pas2js RTL: $required"
  }
}

New-Item -ItemType Directory -Force -Path $unitRoot, $webRoot | Out-Null
$scriptPath = Join-Path $webRoot 'app.js'
Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
$compilerArguments = @(
  '-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RtlJavascript",
  "-Fu$RtlSource", "-FU$unitRoot", "-FE$webRoot", $program
)
& $Compiler @compilerArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf) -or
    (Get-Item -LiteralPath $scriptPath).Length -eq 0) {
  throw "pas2js did not produce $scriptPath"
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'index.html'),
  (Join-Path $sourceRoot 'style.css') -Destination $webRoot -Force
Write-Host "Label workbench staged at $webRoot"
