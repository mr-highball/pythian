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
  [string] $Compiler = $(if ($env:PAS2JS) { $env:PAS2JS } else { 'pas2js' }),
  [string] $RtlSource = $env:PAS2JS_RTL_SOURCE,
  [string] $RtlJavascript = $env:PAS2JS_RTL_JS,
  [switch] $VerifyCodec
)

$ErrorActionPreference = 'Stop'
# The caller supplies the RTL matching their verified compiler. Do not infer
# an RTL from an unrelated installation or a developer-specific filesystem.
if ([string]::IsNullOrWhiteSpace($RtlSource) -or
    [string]::IsNullOrWhiteSpace($RtlJavascript)) {
  throw 'Supply matched pas2js RTL with -RtlSource/-RtlJavascript or PAS2JS_RTL_SOURCE/PAS2JS_RTL_JS.'
}
$compilerCommand = Get-Command -Name $Compiler -CommandType Application -ErrorAction Stop
$Compiler = $compilerCommand.Source
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $PSScriptRoot 'label-workbench'
$outputRoot = Join-Path $repositoryRoot 'build\label-workbench'
$unitRoot = Join-Path $outputRoot 'units'
$webRoot = Join-Path $outputRoot 'www'
$program = Join-Path $sourceRoot 'app.lpr'
$listenProgram = Join-Path $sourceRoot 'listen.lpr'
$studioProgram = Join-Path $sourceRoot 'studio.lpr'
$captureProgram = Join-Path $sourceRoot 'capture-worklet.lpr'

foreach ($required in @($program, $listenProgram, $studioProgram, $captureProgram,
    (Join-Path $sourceRoot 'index.html'),
    (Join-Path $sourceRoot 'style.css'),
    (Join-Path $sourceRoot 'listen.html'),
    (Join-Path $sourceRoot 'listen.css'),
    (Join-Path $sourceRoot 'studio.html'),
    (Join-Path $sourceRoot 'studio.css'),
    (Join-Path $sourceRoot 'workspace-nav.css'),
    (Join-Path $sourceRoot 'phone-setup.html'), $RtlJavascript,
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
$listenScriptPath = Join-Path $webRoot 'listen.js'
Remove-Item -LiteralPath $listenScriptPath -Force -ErrorAction SilentlyContinue
$listenCompilerArguments = @(
  '-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RtlJavascript",
  "-Fu$RtlSource", "-FU$unitRoot", "-FE$webRoot", $listenProgram
)
& $Compiler @listenCompilerArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $listenScriptPath -PathType Leaf) -or
    (Get-Item -LiteralPath $listenScriptPath).Length -eq 0) {
  throw "pas2js did not produce $listenScriptPath"
}
$studioScriptPath = Join-Path $webRoot 'studio.js'
Remove-Item -LiteralPath $studioScriptPath -Force -ErrorAction SilentlyContinue
$studioCompilerArguments = @(
  '-B', '-Tbrowser', '-Mdelphi', '-Jc', "-Ji$RtlJavascript",
  "-Fu$RtlSource", "-Fu$(Join-Path $repositoryRoot 'src')", "-FU$unitRoot", "-FE$webRoot", $studioProgram
)
& $Compiler @studioCompilerArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $studioScriptPath -PathType Leaf) -or
    (Get-Item -LiteralPath $studioScriptPath).Length -eq 0) {
  throw "pas2js did not produce $studioScriptPath"
}
$captureScriptPath = Join-Path $webRoot 'capture-worklet.js'
Remove-Item -LiteralPath $captureScriptPath -Force -ErrorAction SilentlyContinue
$captureCompilerArguments = @(
  '-B', '-Tmodule', '-Mdelphi', '-Jc', "-Ji$RtlJavascript",
  "-Fu$RtlSource", "-FU$unitRoot", "-FE$webRoot", $captureProgram
)
& $Compiler @captureCompilerArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $captureScriptPath -PathType Leaf) -or
    (Get-Item -LiteralPath $captureScriptPath).Length -eq 0) {
  throw "pas2js did not produce $captureScriptPath"
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'index.html'),
  (Join-Path $sourceRoot 'style.css'),
  (Join-Path $sourceRoot 'listen.html'),
  (Join-Path $sourceRoot 'listen.css'),
  (Join-Path $sourceRoot 'studio.html'),
  (Join-Path $sourceRoot 'studio.css'),
  (Join-Path $sourceRoot 'workspace-nav.css'),
  (Join-Path $sourceRoot 'phone-setup.html') -Destination $webRoot -Force
Write-Host "Label workbench staged at $webRoot"
if ($VerifyCodec) {
  $codecRoot = Join-Path $outputRoot 'codec-check'
  New-Item -ItemType Directory -Force -Path $codecRoot | Out-Null
  $nodeCommand = Get-Command -Name node -CommandType Application -ErrorAction Stop | Select-Object -First 1
  & $Compiler '-B' '-Tnodejs' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" `
    "-Fu$RtlSource" "-Fu$(Join-Path $repositoryRoot 'src')" "-FE$codecRoot" `
    (Join-Path $repositoryRoot 'tests/pythian.tests.wave.portable.lpr')
  if ($LASTEXITCODE -ne 0) { throw 'Portable WAV pas2js compilation failed' }
  & $nodeCommand.Source (Join-Path $codecRoot 'pythian.tests.wave.portable.js')
  if ($LASTEXITCODE -ne 0) { throw 'Portable WAV pas2js checks failed' }
  & $Compiler '-B' '-Tnodejs' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" `
    "-Fu$RtlSource" "-Fu$(Join-Path $repositoryRoot 'src')" "-FE$codecRoot" `
    (Join-Path $repositoryRoot 'tests/pythian.tests.progress.portable.lpr')
  if ($LASTEXITCODE -ne 0) { throw 'Portable progress pas2js compilation failed' }
  & $nodeCommand.Source (Join-Path $codecRoot 'pythian.tests.progress.portable.js')
  if ($LASTEXITCODE -ne 0) { throw 'Portable progress checks failed' }
}
