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
  [Parameter(Mandatory=$true)][string] $DomModule,
  [ValidateSet('recovery','references')][string] $Suite = 'recovery'
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$output = Join-Path $repository "build/studio-$Suite-tests"
$testProgram = if ($Suite -eq 'references') { 'pythian.tests.listening.references' } else { 'pythian.tests.studio.recovery' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$domPath = (Resolve-Path -LiteralPath $DomModule).Path
& $Compiler '-B' '-Tbrowser' '-Mdelphi' '-Jc' "-Ji$RtlJavascript" "-Fu$RtlSource" `
  "-Fu$(Join-Path $repository 'src')" "-Fu$(Join-Path $repository 'tools/label-workbench')" `
  "-FU$output" "-FE$output" (Join-Path $repository "tests/$testProgram.lpr")
if ($LASTEXITCODE -ne 0) { throw 'Studio recovery test compilation failed' }
# Only test-host setup lives here; behavior and assertions are Pascal-owned.
$hostScript = @'
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require(DOM_MODULE);
const dom = new JSDOM(fs.readFileSync(STUDIO_HTML, 'utf8'), {
  url: 'http://localhost/studio.html', pretendToBeVisual: true, runScripts: 'outside-only'
});
const nativeTimer = dom.window.setTimeout.bind(dom.window);
dom.window.setTimeout = (fn, delay, ...args) =>
  nativeTimer(fn, delay === 15000 ? 30 : delay === 3000 ? 5 : delay, ...args);
// DOM host only: no real device or speaker is opened by these checks.
dom.window.HTMLMediaElement.prototype.pause = function() { this.testPauseCount = (this.testPauseCount || 0) + 1; };
dom.window.HTMLMediaElement.prototype.load = function() {};
dom.window.HTMLMediaElement.prototype.testPauseCount = 0;
dom.window.eval(fs.readFileSync(path.join(__dirname, TEST_PROGRAM), 'utf8'));
dom.window.rtl.run();
const started = Date.now();
const check = setInterval(() => {
  const result = dom.window.document.body.getAttribute('data-test-result');
  if (result || Date.now() - started > 5000) {
    clearInterval(check);
    console.log(result || 'FAIL no result');
    if (!result || !result.startsWith('PASS')) {
      console.log(dom.window.document.body.textContent);
      process.exitCode = 1;
    }
    dom.window.close();
  }
}, 20);
'@
$hostScript = $hostScript.Replace('TEST_PROGRAM', (("$testProgram.js") | ConvertTo-Json -Compress)).Replace('DOM_MODULE', ($domPath | ConvertTo-Json -Compress)).Replace(
  'STUDIO_HTML', ((Join-Path $repository 'tools/label-workbench/studio.html') | ConvertTo-Json -Compress))
$hostPath = Join-Path $output 'run.cjs'
[IO.File]::WriteAllText($hostPath, $hostScript)
& node $hostPath
if ($LASTEXITCODE -ne 0) { throw 'Studio recovery DOM contract checks failed' }
