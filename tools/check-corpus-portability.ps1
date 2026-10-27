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
  [Parameter(Mandatory=$true)][string] $Compiler,
  [Parameter(Mandatory=$true)][string] $RtlSource,
  [Parameter(Mandatory=$true)][string] $RtlJavascript,
  [string] $Node = 'node',
  [string] $OutputRoot = $env:PYTHIAN_BUILD_ROOT
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $repository 'build' }
$output = Join-Path ([IO.Path]::GetFullPath($OutputRoot)) 'corpus-portability'
$compilerPath = Get-Command -Name $Compiler -CommandType Application -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Source
$nodePath = Get-Command -Name $Node -CommandType Application -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Source
if (-not (Test-Path -LiteralPath $RtlJavascript -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $RtlSource 'sysutils.pas') -PathType Leaf)) {
  throw 'Supply the RTL sources and JavaScript matching the verified pas2js compiler.'
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
foreach ($program in @('pythian.tests.corpus.text', 'pythian.tests.corpus.intake',
    'pythian.tests.corpus.portability.qa')) {
  $script = Join-Path $output "$program.js"
  & $compilerPath '-B' '-Tnodejs' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" `
    "-Fu$RtlSource" "-Fu$(Join-Path $repository 'src')" "-o$script" `
    (Join-Path $repository "tests/$program.lpr")
  if ($LASTEXITCODE -ne 0) { throw "Corpus portability compilation failed: $program" }
  # Test-host startup only. All validation, fixtures and assertions are Pascal.
  # Propagate the Pascal runtime's exit status even when it catches an exception.
  & $nodePath '-e' 'const fs=require("node:fs"),vm=require("node:vm");vm.runInThisContext(fs.readFileSync(process.argv[1],"utf8"));process.exitCode=rtl.exitcode;' $script
  if ($LASTEXITCODE -ne 0) { throw "Corpus portability checks failed: $program" }
}
