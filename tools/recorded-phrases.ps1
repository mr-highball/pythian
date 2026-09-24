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
param(
  [string]$Compiler = 'fpc',
  [ValidateSet('Development', 'HeldOut')]
  [string]$EvaluationSet = 'Development',
  [ValidateRange(1, 1024)]
  [int]$PreviewSpans = 256,
  [switch]$RegionStudy
)

# Optional reference evaluation; recordings stay outside source packages.
# Keep HeldOut unused while selecting estimator changes on Development.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source
$compilerVersion = (& $compilerPath '-iV' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler version probe failed' }
$compilerCpu = (& $compilerPath '-iTP' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler CPU probe failed' }
$compilerOs = (& $compilerPath '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler OS probe failed' }
$buildRoot = Join-Path $projectRoot "build/recorded-phrases-$compilerVersion-$compilerCpu-$compilerOs"
$cacheRoot = Join-Path $projectRoot 'build/recorded-phrases'
$unitRoot = Join-Path $buildRoot 'units'
$executableSuffix = if ($compilerOs -in @('win32', 'win64')) { '.exe' } else { '' }
New-Item -ItemType Directory -Force -Path $buildRoot, $cacheRoot, $unitRoot | Out-Null

$revision = '3a62b3a1c8bb263a6a6ac37559070339ddb81080'
$baseUrl = "https://huggingface.co/datasets/J1mmymm/MIMuT_Data_v2/resolve/$revision/data/urmp/urmp_yourmt3_16k"
$cases = @(
  @('Development', '08_Spring_fl_vn', '1_fl_08_Spring', 'spring-fl',
    '595d9a858fcecb0478692a806b961c967f6309de01e58821a4ce69de10fa5d30',
    '70cbb79326ac89f10cdb4424d24aca0098d173dda632fdc30bfbc8eacc1f1c05'),
  @('Development', '08_Spring_fl_vn', '2_vn_08_Spring', 'spring-vn',
    'bfa0c3038f58126730fa3e2ec4a6cd5740cfa18a12173f4bef6de54b01ca5e1a',
    '711934ba728f02bff3906b590589efe7b0f621677f262ca1cb0ebdfc1ab15c09'),
  @('HeldOut', '03_Dance_fl_cl', '1_fl_03_Dance', 'dance-fl',
    '9a6d49039909805a493c684208351e46589c38687e5ac489ffbb29f5397f876d',
    'eaa16ccad9ae07b5d66d1e78e29433de4d2bec834d82050f0a3eb7f4efa6c373'),
  @('HeldOut', '03_Dance_fl_cl', '2_cl_03_Dance', 'dance-cl',
    '48a740e6d93cdc8cda8b74a48d9bf02face37244e3c618ab1eb66bf413854792',
    '0d428443ca96bcc66171f0ccd90fd4778254e8ba4f777b100868acd828f6d50b')
)

function Invoke-Native([string]$Name, [string[]]$Arguments, [string]$LogName) {
  $logPath = Join-Path $buildRoot $LogName
  & (Join-Path $buildRoot ($Name + $executableSuffix)) @Arguments *> $logPath
  $nativeExit = $LASTEXITCODE
  Get-Content -LiteralPath $logPath
  if ($nativeExit -ne 0) { throw "$Name failed with exit $nativeExit; see $logPath" }
}

Push-Location $projectRoot
try {
  $compilerArgs = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-Fusrc',
    '-Futools', "-FU$unitRoot", "-FE$buildRoot")
  foreach ($program in @('tests/pythian.tests.pitch.lpr', 'tools/pythian.phrase.wav.lpr')) {
    & $compilerPath @compilerArgs $program *> (Join-Path $buildRoot ([IO.Path]::GetFileNameWithoutExtension($program) + '-build.log'))
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $program" }
  }
  Invoke-Native 'pythian.tests.pitch' @() 'scoring-checks.log'
  if ($EvaluationSet -eq 'Development') {
    & $compilerPath @compilerArgs '-Fuadapters/wfc' '-Fuvendor/wfc/src' 'tools/pythian.pitch.wav.lpr' *> (Join-Path $buildRoot 'learner-build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Duration learner compilation failed' }
  }
  foreach ($case in $cases) {
    if ($case[0] -ne $EvaluationSet) { continue }
    $names = @("AuSep_$($case[2]).wav", "Notes_$($case[2]).txt")
    for ($assetIndex = 0; $assetIndex -lt $names.Count; $assetIndex++) {
      $assetPath = Join-Path $cacheRoot $names[$assetIndex]
      if (-not (Test-Path -LiteralPath $assetPath)) {
        Invoke-WebRequest -Uri "$baseUrl/$($case[1])/$($names[$assetIndex])" -OutFile $assetPath
      }
      if ((Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $case[4 + $assetIndex]) {
        throw "Reference input hash mismatch: $assetPath"
      }
    }
    $sourcePath = Join-Path $cacheRoot $names[0]
    $referencePath = Join-Path $cacheRoot $names[1]
    foreach ($windowFrames in @(0, 880)) {
      $name = "$($case[3])-$windowFrames"
      if ($RegionStudy) { $name += '-regions' }
      $prefix = Join-Path $buildRoot $name
      $phraseArguments = @($sourcePath, $referencePath, $prefix, '0', '30', "$windowFrames")
      if ($RegionStudy) { $phraseArguments += '--region-study' }
      Invoke-Native 'pythian.phrase.wav' $phraseArguments "$name.log"
    }
    if ($EvaluationSet -eq 'Development') {
      # Learner reads the encoded PCM16 excerpt, which is separately fingerprinted.
      # Generation is diagnostic even when the evaluation correctly rejects quality.
      $name = "$($case[3])-0"
      if ($RegionStudy) { $name += '-regions' }
      $prefix = Join-Path $buildRoot $name
      Invoke-Native 'pythian.pitch.wav' @('learn-runs', "$prefix.source.wav",
        "$prefix-learned", '0', '--monophonic') "$name-learned.log"
      $previewArgs = @('generate-runs', "$prefix-learned.model.txt",
        "$prefix-preview-$PreviewSpans.wav", '10', '731', '--spans', "$PreviewSpans")
      Invoke-Native 'pythian.pitch.wav' $previewArgs "$name-preview-$PreviewSpans.log"
    }
  }
  Write-Output "Completed $EvaluationSet evaluation. Native reports determine quality admission; command success alone does not."
}
finally {
  Pop-Location
}
