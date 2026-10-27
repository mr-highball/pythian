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
$output = Join-Path ([IO.Path]::GetFullPath($OutputRoot)) 'synthesis-portability'
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
$fixtures = @('pythian.tests.render.progress', 'pythian.tests.synthesis.portable',
  'pythian.tests.time.portable')
foreach ($program in $fixtures) {
  $source = Join-Path $repository "tests/$program.lpr"
  & $nativePath @NativeTargetArguments '-B' '-Sa' '-Cr' '-Co' '-Ci' '-gl' '-gh' `
    "-Fu$(Join-Path $repository 'src')" "-FU$units" "-FE$output" $source `
    *> (Join-Path $output "$program.native-build.log")
  if ($LASTEXITCODE -ne 0) { throw "Native compilation failed: $program (see $output)" }
  & (Join-Path $output "$program$suffix") `
    1> (Join-Path $output "$program.native.log") `
    2> (Join-Path $output "$program.native-stderr.log")
  if ($LASTEXITCODE -ne 0) { throw "Native checks failed: $program (see $output)" }
  $script = Join-Path $output "$program.js"
  & $compilerPath '-B' '-Tnodejs' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" `
    "-Fu$RtlSource" "-Fu$(Join-Path $repository 'src')" "-o$script" $source `
    *> (Join-Path $output "$program.pas2js-build.log")
  if ($LASTEXITCODE -ne 0) { throw "pas2js compilation failed: $program (see $output)" }
  # Test-host startup only. All synthesis, timing and comparisons are Pascal.
  & $nodePath '-e' 'const fs=require("node:fs"),vm=require("node:vm");vm.runInThisContext(fs.readFileSync(process.argv[1],"utf8"));process.exitCode=rtl.exitcode;' $script `
    *> (Join-Path $output "$program.pas2js.log")
  if ($LASTEXITCODE -ne 0) { throw "pas2js checks failed: $program (see $output)" }
  if ($program -ne 'pythian.tests.render.progress') {
    $nativeLog = Join-Path $output "$program.native.log"
    $jsLog = Join-Path $output "$program.pas2js.log"
    & (Join-Path $output "$program$suffix") '--compare' $nativeLog $jsLog `
      1> (Join-Path $output "$program.parity.log") `
      2> (Join-Path $output "$program.parity-stderr.log")
    if ($LASTEXITCODE -ne 0) { throw "Cross-target comparison failed: $program (see $output)" }
    # Prepare incomplete inputs; the Pascal comparator owns their rejection.
    $emptyLog = Join-Path $output "$program.empty.log"
    $truncatedLog = Join-Path $output "$program.truncated.log"
    [IO.File]::WriteAllText($emptyLog, '', [Text.UTF8Encoding]::new($false))
    $completeText = [IO.File]::ReadAllText($nativeLog)
    [IO.File]::WriteAllText($truncatedLog,
      $completeText.Substring(0, [int][Math]::Floor($completeText.Length / 2)),
      [Text.UTF8Encoding]::new($false))
    foreach ($negativeLog in @($emptyLog, $truncatedLog)) {
      & (Join-Path $output "$program$suffix") '--compare' $negativeLog $negativeLog `
        1> "$negativeLog.rejection.log" 2> "$negativeLog.rejection-stderr.log"
      if ($LASTEXITCODE -eq 0) { throw "Incomplete logs were accepted: $program (see $output)" }
    }
    Get-Content -LiteralPath (Join-Path $output "$program.parity.log") |
      Select-Object -First 1
  }
  Write-Output "Native and pas2js PASS: $program"
}
# Expected negative comparator runs leave a nonzero native status. Return the
# successful overall result explicitly to callers and CI shell wrappers.
exit 0
