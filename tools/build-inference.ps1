<#
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>
param([string]$Compiler = 'fpc')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source
$compilerVersion = (& $compilerPath '-iV' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler version probe failed' }
$targetFlags = @('-Twin64', '-Px86_64')
$compilerCpu = (& $compilerPath @targetFlags '-iTP' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler CPU probe failed' }
$compilerOs = (& $compilerPath @targetFlags '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler OS probe failed' }
if ($compilerVersion -ne '3.2.2' -or $compilerCpu -ne 'x86_64' -or $compilerOs -ne 'win64') {
  throw 'The supervised Pascal inference consumer currently requires an x86_64-win64 compiler'
}

$buildRoot = Join-Path $projectRoot "build/inference-$compilerVersion-$compilerCpu-$compilerOs"
$unitRoot = Join-Path $buildRoot 'units'
New-Item -ItemType Directory -Force $unitRoot | Out-Null
Write-Output "Compiler: $compilerPath ($compilerVersion $compilerCpu-$compilerOs)"
Push-Location $projectRoot
try {
  $compilerArgs = @('-Twin64', '-Px86_64', '-O2', '-Sa', '-Cr', '-Co', '-Ci', '-gh', '-gl',
    '-Fusrc', '-Futools', '-Fuadapters/inference', "-FU$unitRoot", "-FE$buildRoot")
  & $compilerPath '-B' @compilerArgs 'tools/pythian.inference.wav.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Pascal inference consumer compilation failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.inference.native.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Pascal inference backend fixture compilation failed' }
  Write-Output "Pascal inference consumer and backend fixture compiled: $buildRoot"
  Write-Output 'Compilation only; recorded fidelity and long-source qualification remain separate.'
} finally {
  Pop-Location
}
