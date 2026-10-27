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
  [Parameter(Mandatory=$true)][string] $NativeCompiler,
  [Parameter(Mandatory=$true)][string] $Compiler,
  [Parameter(Mandatory=$true)][string] $RtlSource,
  [Parameter(Mandatory=$true)][string] $RtlJavascript,
  [string[]] $NativeTargetArguments = @(),
  [string] $Node = 'node',
  [string] $OutputRoot = $env:PYTHIAN_BUILD_ROOT
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $repository 'build' }
$output = Join-Path ([IO.Path]::GetFullPath($OutputRoot)) 'analysis-portability'
$nativePath = Get-Command -Name $NativeCompiler -CommandType Application -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Source
$compilerPath = Get-Command -Name $Compiler -CommandType Application -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Source
$nodePath = Get-Command -Name $Node -CommandType Application -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Source
if (-not (Test-Path -LiteralPath $RtlJavascript -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $RtlSource 'sysutils.pas') -PathType Leaf)) {
  throw 'Supply the RTL sources and JavaScript matching the verified pas2js compiler.'
}
$targetOs = (& $nativePath @NativeTargetArguments '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Native target probe failed' }
$suffix = if ($targetOs -in @('win32','win64')) { '.exe' } else { '' }
$units = Join-Path $output 'units'
New-Item -ItemType Directory -Force -Path $units | Out-Null
$fixtures = @('pythian.tests.hash.portable', 'pythian.tests.stream.bytes',
  'pythian.tests.binary.portable', 'pythian.tests.binary.fields', 'pythian.tests.wave.portable',
  'pythian.tests.wave.reader.portable', 'pythian.tests.analysis.portable',
  'pythian.tests.progress')
foreach ($program in $fixtures) {
  & $nativePath @NativeTargetArguments '-B' '-Sa' '-Cr' '-Co' '-Ci' '-gl' '-gh' `
    "-Fu$(Join-Path $repository 'src')" "-FU$units" "-FE$output" `
    (Join-Path $repository "tests/$program.lpr") *> (Join-Path $output "$program.native-build.log")
  if ($LASTEXITCODE -ne 0) { throw "Native compilation failed: $program (see $output)" }
  & (Join-Path $output "$program$suffix") *> (Join-Path $output "$program.native.log")
  if ($LASTEXITCODE -ne 0) { throw "Native checks failed: $program (see $output)" }
  Write-Output "Native PASS: $program"
}
foreach ($program in ($fixtures + @('pythian.tests.analysis.cooperative'))) {
  $script = Join-Path $output "$program.js"
  & $compilerPath '-B' '-Tnodejs' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" `
    "-Fu$RtlSource" "-Fu$(Join-Path $repository 'src')" `
    "-Fu$(Join-Path $repository 'adapters/pas2js')" "-o$script" `
    (Join-Path $repository "tests/$program.lpr") *> (Join-Path $output "$program.pas2js-build.log")
  if ($LASTEXITCODE -ne 0) { throw "pas2js compilation failed: $program (see $output)" }
  # Test-host startup only; product behavior and validation are Pascal-owned.
  & $nodePath '-e' 'const fs=require("node:fs"),vm=require("node:vm");vm.runInThisContext(fs.readFileSync(process.argv[1],"utf8"));process.exitCode=rtl.exitcode;' $script `
    *> (Join-Path $output "$program.pas2js.log")
  if ($LASTEXITCODE -ne 0) { throw "pas2js checks failed: $program (see $output)" }
  Write-Output "pas2js PASS: $program"
}
$parityProgram = 'pythian.tests.analysis.portable'
& (Join-Path $output "$parityProgram$suffix") '--compare' `
  (Join-Path $output "$parityProgram.native.log") (Join-Path $output "$parityProgram.pas2js.log") `
  *> (Join-Path $output 'feature-parity.log')
if ($LASTEXITCODE -ne 0) { throw "Cross-target feature comparison failed (see $output)" }
Get-Content -LiteralPath (Join-Path $output 'feature-parity.log')
