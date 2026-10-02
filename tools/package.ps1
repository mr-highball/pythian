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
  [switch]$WithWfc,
  [string]$OutputDirectory = '',
  [string]$TargetCpu = '',
  [string]$TargetOs = ''
)

$ErrorActionPreference = 'Stop'

function Copy-SourceDirectory([string]$Source, [string]$Destination) {
  New-Item -ItemType Directory -Force $Destination | Out-Null
  Get-ChildItem -LiteralPath $Source -File |
    Where-Object { $_.Extension -in '.pas', '.pp', '.inc' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Destination }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source
$targetArgs = @()
if ($TargetCpu -ne '') { $targetArgs += '-P' + $TargetCpu }
if ($TargetOs -ne '') { $targetArgs += '-T' + $TargetOs }
$compilerVersion = (& $compilerPath @targetArgs '-iV' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler version probe failed' }
$compilerCpu = (& $compilerPath @targetArgs '-iTP' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler CPU probe failed' }
$compilerOs = (& $compilerPath @targetArgs '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler target probe failed' }
$sourceRevision = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Source revision probe failed' }
$sourceChanges = (& git -C $projectRoot status --porcelain --untracked-files=normal | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Source state probe failed' }
$sourceState = if ($sourceChanges -eq '') { 'clean' } else { 'dirty candidate; base revision alone does not identify delivered bytes' }
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))
if ($OutputDirectory -eq '') {
  $OutputDirectory = Join-Path $buildRoot ('packages/' + [Guid]::NewGuid().ToString('N'))
}
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$buildPrefix = $buildRoot + [IO.Path]::DirectorySeparatorChar
$pathComparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if (-not $outputRoot.StartsWith($buildPrefix, $pathComparison)) {
  throw 'Package output must stay under the project build directory'
}
if (Test-Path -LiteralPath $outputRoot) {
  throw 'Package output already exists; choose a fresh directory to avoid stale files'
}
$stage = Join-Path $outputRoot 'pythian'
$checkRoot = Join-Path $outputRoot 'consumer-check'
$unitRoot = Join-Path $checkRoot 'units'
$coreUnitRoot = Join-Path $checkRoot 'core-units'
$binRoot = Join-Path $checkRoot 'bin'
New-Item -ItemType Directory -Force $stage, $unitRoot, $coreUnitRoot, $binRoot | Out-Null
Copy-SourceDirectory (Join-Path $projectRoot 'src') (Join-Path $stage 'src')
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $stage
Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging/README.md') -Destination $stage
Copy-Item -LiteralPath (Join-Path $projectRoot 'packaging/PROVENANCE.md') -Destination $stage
$exampleRoot = Join-Path $stage 'examples'
New-Item -ItemType Directory -Path $exampleRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.core.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.notes.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.midi.stream.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.instrument.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.processing.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.extensions.lpr') -Destination $exampleRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.extension.units.pas') -Destination $exampleRoot
$testRoot = Join-Path $stage 'tests'
$docRoot = Join-Path $stage 'docs'
New-Item -ItemType Directory -Path $testRoot, $docRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/pythian.tests.extension.conformance.lpr') -Destination $testRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/CALLER-EXTENSIONS.md') -Destination $docRoot
$wfcRevision = 'not included'
if ($WithWfc) {
  $wfcRoot = Join-Path $projectRoot 'vendor/wfc'
  $wfcRevision = (& git -C $wfcRoot rev-parse HEAD | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'WFC revision probe failed' }
  $wfcChanges = (& git -C $wfcRoot status --porcelain | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $wfcChanges -ne '') { throw 'Package requires an unchanged WFC checkout' }
  $adapterRoot = Join-Path $stage 'adapters'
  $vendorRoot = Join-Path $stage 'vendor/wfc'
  New-Item -ItemType Directory -Force $adapterRoot, $vendorRoot | Out-Null
  Copy-SourceDirectory (Join-Path $projectRoot 'adapters/wfc') (Join-Path $adapterRoot 'wfc')
  Copy-SourceDirectory (Join-Path $wfcRoot 'src') (Join-Path $vendorRoot 'src')
  Copy-Item -LiteralPath (Join-Path $wfcRoot 'LICENSE') -Destination $vendorRoot
  [IO.File]::WriteAllText((Join-Path $vendorRoot 'REVISION'), $wfcRevision + "`n")
  Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.wfc.lpr') -Destination $exampleRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.wfc.provider.lpr') -Destination $exampleRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.provider.extension.units.pas') -Destination $exampleRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.provider.extensions.lpr') -Destination $exampleRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/pythian.tests.provider.extension.lpr') -Destination $testRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/CALLER-PROVIDERS.md') -Destination $docRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'examples/pythian.example.events.lpr') -Destination $exampleRoot
  $toolRoot = Join-Path $stage 'tools'
  New-Item -ItemType Directory -Path $toolRoot | Out-Null
  foreach ($toolName in @('pythian.learn.lpr', 'pythian.tools.files.pas',
      'pythian.tools.features.pas', 'pythian.tools.journal.learning.pas',
      'pythian.tools.annotations.export.pas', 'pythian.tools.annotations.sourceguard.pas',
      'pythian.tools.annotations.catalog.pas', 'pythian.tools.annotations.proposal.pas',
      'pythian.tools.annotations.review.pas', 'pythian.tools.annotations.contract.pas')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "tools/$toolName") -Destination $toolRoot
  }
}
$packagingHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
$packageInfo = "Development source snapshot`nBase source revision: $sourceRevision`nSource state: $sourceState`nDelivered identity: SHA256SUMS inventory (including this metadata)`nPackaging script SHA256: $packagingHash`nCompiler: $compilerVersion $compilerCpu-$compilerOs`nWFC: $wfcRevision`n"
[IO.File]::WriteAllText((Join-Path $stage 'PACKAGE-INFO.txt'), $packageInfo)

# Bind the delivered inventory before compression; verify extracted bytes before
# compiling consumers. The manifest excludes itself, as in standard checksum lists.
$inventory = @(Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
  [PSCustomObject]@{
    Path = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
    Length = $_.Length
    Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
} | Sort-Object Path)
$manifestText = (($inventory | ForEach-Object { $_.Sha256 + '  ' + $_.Path }) -join "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $stage 'SHA256SUMS'), $manifestText,
  [Text.UTF8Encoding]::new($false))

# Verify the delivered ZIP after extraction, with fresh external unit output.
$archivePath = Join-Path $outputRoot 'pythian-source.zip'
Compress-Archive -LiteralPath $stage -DestinationPath $archivePath
$unpackedRoot = Join-Path $outputRoot 'unpacked'
Expand-Archive -LiteralPath $archivePath -DestinationPath $unpackedRoot
$stage = Join-Path $unpackedRoot 'pythian'
if (@(Get-ChildItem -LiteralPath $stage -Recurse -File).Count -ne $inventory.Count + 1) {
  throw 'Extracted package inventory differs from the staged file count'
}
if ([IO.File]::ReadAllText((Join-Path $stage 'SHA256SUMS')) -cne $manifestText) {
  throw 'Extracted package checksum manifest differs from the staged manifest'
}
foreach ($entry in $inventory) {
  $path = Join-Path $stage $entry.Path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
      (Get-Item -LiteralPath $path).Length -ne $entry.Length -or
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Sha256) {
    throw "Extracted package content differs from the staged source: $($entry.Path)"
  }
}
$exampleRoot = Join-Path $stage 'examples'
$unitPaths = @((Join-Path $stage 'src'))
$searchArgs = @('-Fu' + (Join-Path $stage 'src'))
if ($WithWfc) {
  $unitPaths += Join-Path $stage 'adapters/wfc'
  $unitPaths += Join-Path $stage 'tools'
  $searchArgs += '-Fu' + (Join-Path $stage 'adapters/wfc')
  $searchArgs += '-Fu' + (Join-Path $stage 'vendor/wfc/src')
  $searchArgs += '-Fu' + (Join-Path $stage 'tools')
}

# Compile every delivered owned unit in one generated build driver, then run
# separate consumer programs. All source paths point into the extracted ZIP.
$unitNames = @($unitPaths | ForEach-Object {
  Get-ChildItem -LiteralPath $_ -File -Filter '*.pas' | Select-Object -ExpandProperty BaseName
} | Sort-Object)
$unitProbeText = 'program pythian_package_units;' + "`n" + '{$mode delphi}{$H+}' +
  "`nuses`n  " + ($unitNames -join ",`n  ") + ";`nbegin`nend.`n"
[IO.File]::WriteAllText((Join-Path $checkRoot 'pythian.package.units.lpr'), $unitProbeText)
Copy-Item -LiteralPath (Join-Path $exampleRoot 'pythian.example.core.lpr') -Destination $checkRoot
$compilerArgs = $targetArgs + @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', "-FU$unitRoot", "-FE$binRoot") + $searchArgs
$coreCompilerArgs = $targetArgs + @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', "-FU$coreUnitRoot", "-FE$binRoot", ('-Fu' + (Join-Path $stage 'src')))
$executableSuffix = if ($compilerOs -eq 'win32' -or $compilerOs -eq 'win64') { '.exe' } else { '' }

function Test-NativeConsumer([string]$Name, [string]$Prefix, [string]$BaseGain,
    [string]$ChangedGain, [string]$Rate, [string]$Frames, [string]$Ratio) {
  $consumer = Join-Path $binRoot ($Name + $executableSuffix)
  & $consumer ($Prefix + '-base.wav') $BaseGain '731' > ($Prefix + '-base.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Native consumer failed: $Prefix base" }
  & $consumer ($Prefix + '-changed.wav') $ChangedGain '731' > ($Prefix + '-changed.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Native consumer failed: $Prefix changed control" }
  & $consumer ($Prefix + '-replay.wav') $BaseGain '731' > ($Prefix + '-replay.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Native consumer failed: $Prefix replay" }
  & (Join-Path $binRoot "pythian.tests.delivery.native$executableSuffix") `
    ($Prefix + '-base.wav') ($Prefix + '-changed.wav') ($Prefix + '-replay.wav') `
    $Rate '2' $Frames $Ratio > ($Prefix + '-verify.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Saved-file control/replay proof failed: $Prefix" }
  $oldHash = (Get-FileHash -LiteralPath ($Prefix + '-base.wav')).Hash
  $failures = @(
    @{ Arguments = @(); Output = '' },
    @{ Arguments = @(($Prefix + '-bad-gain.wav'), '-1'); Output = $Prefix + '-bad-gain.wav' },
    @{ Arguments = @(($Prefix + '-bad-number.wav'), 'NaN'); Output = $Prefix + '-bad-number.wav' },
    @{ Arguments = @(($Prefix + '-bad-seed.wav'), $BaseGain, '4294967296'); Output = $Prefix + '-bad-seed.wav' },
    @{ Arguments = @(($Prefix + '-base.wav'), $BaseGain, '731'); Output = '' },
    @{ Arguments = @((Join-Path 'absent-parent' ($Prefix + '.wav')), $BaseGain, '731'); Output = Join-Path 'absent-parent' ($Prefix + '.wav') }
  )
  for ($case = 0; $case -lt $failures.Count; $case++) {
    $arguments = $failures[$case].Arguments
    & $consumer @arguments > ($Prefix + '-reject-' + $case + '.log') 2>&1
    if ($LASTEXITCODE -eq 0) { throw "Bad input/output accepted: $Prefix case $case" }
    if ($failures[$case].Output -ne '' -and (Test-Path -LiteralPath $failures[$case].Output)) {
      throw "Rejected native consumer published an output: $Prefix case $case"
    }
    if ((Get-FileHash -LiteralPath ($Prefix + '-base.wav')).Hash -ne $oldHash) {
      throw "Rejected native consumer changed an existing valid output: $Prefix case $case"
    }
  }
}
Push-Location $checkRoot
try {
  & $compilerPath @compilerArgs 'pythian.package.units.lpr' > 'units-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Package unit closure failed; see $checkRoot/units-build.log" }
  & $compilerPath @coreCompilerArgs 'pythian.example.core.lpr' > 'core-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Core consumer build failed; see $checkRoot/core-build.log" }
  & (Join-Path $binRoot "pythian.example.core$executableSuffix") 'core.wav' > 'core-run.log'
  if ($LASTEXITCODE -ne 0) { throw 'Core consumer failed' }
  Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/pythian.tests.delivery.native.lpr') -Destination $checkRoot
  & $compilerPath @coreCompilerArgs 'pythian.tests.delivery.native.lpr' > 'native-proof-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Native saved-file verifier compilation failed' }
  Test-NativeConsumer 'pythian.example.core' 'core-control' '1' '0.5' '44100' '67032' '0.5'
  # Caller extensions resolve only extracted core/examples, even with WFC enabled.
  $extensionCompilerArgs = $coreCompilerArgs + @('-gh', ('-Fu' + $exampleRoot))
  & $compilerPath @extensionCompilerArgs (Join-Path $exampleRoot 'pythian.example.extensions.lpr') > 'extensions-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Extracted caller extension compilation failed' }
  & (Join-Path $binRoot "pythian.example.extensions$executableSuffix") 'extensions.wav' > 'extensions-run.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Extracted caller extension failed' }
  & $compilerPath @extensionCompilerArgs (Join-Path $stage 'tests/pythian.tests.extension.conformance.lpr') > 'extension-conformance-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Extracted caller conformance compilation failed' }
  & (Join-Path $binRoot "pythian.tests.extension.conformance$executableSuffix") 'extension-evidence' 'extensions.wav' > 'extension-conformance-run.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Extracted caller conformance failed' }
  foreach ($exampleName in @('pythian.example.notes', 'pythian.example.midi.stream', 'pythian.example.instrument')) {
    Copy-Item -LiteralPath (Join-Path $exampleRoot ($exampleName + '.lpr')) -Destination $checkRoot
    & $compilerPath @compilerArgs ($exampleName + '.lpr') > ($exampleName + '-build.log') 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Example compilation failed: $exampleName" }
    $exampleOutput = switch ($exampleName) {
      'pythian.example.notes' { 'notes' }
      'pythian.example.midi.stream' { 'streamed.mid' }
      'pythian.example.instrument' { 'instrument.wav' }
    }
    & (Join-Path $binRoot ($exampleName + $executableSuffix)) $exampleOutput > ($exampleName + '-run.log')
    if ($LASTEXITCODE -ne 0) { throw "Example failed: $exampleName" }
  }
  if ($WithWfc) {
    $callerProviderArgs = $compilerArgs + @('-gh', ('-Fu' + $exampleRoot))
    & $compilerPath @callerProviderArgs (Join-Path $exampleRoot 'pythian.example.provider.extensions.lpr') > 'caller-provider-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Extracted caller codec consumer compilation failed' }
    & (Join-Path $binRoot "pythian.example.provider.extensions$executableSuffix") 'caller-provider.wav' '731' > 'caller-provider-run.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Extracted caller codec saved-style/native consumer failed' }
    & $compilerPath @callerProviderArgs (Join-Path $stage 'tests/pythian.tests.provider.extension.lpr') > 'caller-provider-conformance-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Extracted caller codec conformance compilation failed' }
    & (Join-Path $binRoot "pythian.tests.provider.extension$executableSuffix") 'caller-provider-control' > 'caller-provider-conformance-run.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Extracted caller codec admission/persistence/blend conformance failed' }
    Copy-Item -LiteralPath (Join-Path $exampleRoot 'pythian.example.wfc.provider.lpr') -Destination $checkRoot
    & $compilerPath @compilerArgs 'pythian.example.wfc.provider.lpr' > 'provider-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Caller-provider consumer compilation failed' }
    Test-NativeConsumer 'pythian.example.wfc.provider' 'provider-control' '0.25' '0.5' '16000' '16000' '2'
    Copy-Item -LiteralPath (Join-Path $exampleRoot 'pythian.example.wfc.lpr') -Destination $checkRoot
    & $compilerPath @compilerArgs 'pythian.example.wfc.lpr' > 'wfc-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "WFC consumer build failed; see $checkRoot/wfc-build.log" }
    & (Join-Path $binRoot "pythian.example.wfc$executableSuffix") 'core.wav' 'learned.wav' > 'wfc-run.log'
    if ($LASTEXITCODE -ne 0) { throw 'WFC consumer failed' }
    Copy-Item -LiteralPath (Join-Path $exampleRoot 'pythian.example.events.lpr') -Destination $checkRoot
    & $compilerPath @compilerArgs 'pythian.example.events.lpr' > 'events-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Saved event consumer build failed; see $checkRoot/events-build.log" }
    & (Join-Path $binRoot "pythian.example.events$executableSuffix") 'core.wav' 'instrument.wav' 'events' > 'events-run.log'
    if ($LASTEXITCODE -ne 0) { throw 'Saved event consumer failed' }
    $toolRoot = Join-Path $stage 'tools'
    Copy-Item -LiteralPath (Join-Path $toolRoot 'pythian.learn.lpr') -Destination $checkRoot
    & $compilerPath @compilerArgs "-Fu$toolRoot" 'pythian.learn.lpr' > 'journal-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Packaged journal operator compilation failed' }
    $learner = Join-Path $binRoot "pythian.learn$executableSuffix"
    & $learner 'cache' 'core.wav' 'core.pyaf' '--batch-features' '7' > 'journal-cache.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged feature journal failed' }
    & $learner 'journals' 'journal' '--range' '0' '24' 'core.wav' 'core.pyaf' '--range' '32' '24' 'core.wav' 'core.pyaf' > 'journal-learn.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged section learning failed' }
    & $learner 'cache' 'instrument.wav' 'instrument.pyaf' > 'partition-cache.log'
    if ($LASTEXITCODE -ne 0) { throw 'Partition development cache failed' }
    & $learner 'journals' 'partitioned' '--partition' 'training' `
      '--group' 'authored-development' 'development' 'unverified' 'used' '--range' '0' '24' 'instrument.wav' 'instrument.pyaf' `
      '--group' 'authored-training' 'training' 'verified' 'used' '--range' '0' '24' 'core.wav' 'core.pyaf' `
      '--group' 'authored-training' 'training' 'verified' 'used' '--range' '32' '24' 'core.wav' 'core.pyaf' > 'partition-learn.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged partition selection failed' }
    foreach ($extension in @('.wav', '.wfcs')) {
      if ((Get-FileHash -LiteralPath ('journal' + $extension)).Hash -ne
          (Get-FileHash -LiteralPath ('partitioned' + $extension)).Hash) {
        throw 'Partitioned model/audio differs from explicit training-only input'
      }
    }
    # This verifier stays outside the archive; all its library units come from
    # the extracted package, like the other external consumer checks.
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/pythian.tests.learning.profile.lpr') -Destination $checkRoot
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/pythian.tests.audio.session.pas') -Destination $checkRoot
    & $compilerPath @compilerArgs 'pythian.tests.learning.profile.lpr' > 'partition-check-build.log' 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Partition report verifier compilation failed' }
    & (Join-Path $binRoot "pythian.tests.learning.profile$executableSuffix") 'partition' 'journal' 'partitioned' '3' 'training' > 'partition-check.log'
    if ($LASTEXITCODE -ne 0) { throw 'Partition audit/profile parity failed' }
    & $learner 'journals' 'partition-invalid' '--partition' 'training' `
      '--group' 'authored-training' 'training' 'verified' 'used' '--range' '0' '24' 'core.wav' 'core.pyaf' `
      '--group' 'authored-evaluation' 'evaluation' 'verified' 'used' '--range' '0' '24' 'instrument.wav' 'instrument.pyaf' > 'partition-reject.log' 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'Exposed evaluation input was accepted' }
    & $learner 'journals' 'partition-invalid-starter' '--partition' 'training' '--palette-from' 'journal' `
      '--group' 'authored-evaluation' 'evaluation' 'verified' 'unused' '--range' '0' '24' 'core.wav' 'core.pyaf' `
      '--group' 'authored-training' 'training' 'verified' 'used' '--range' '0' '24' 'instrument.wav' 'instrument.pyaf' > 'partition-starter-reject.log' 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'Evaluation source entered through a palette starter' }
    foreach ($rejectedPrefix in @('partition-invalid', 'partition-invalid-starter')) {
      foreach ($extension in @('.json', '.wav', '.wfcs')) {
        if (Test-Path -LiteralPath ($rejectedPrefix + $extension)) {
          throw 'Rejected partition plan published an output'
        }
      }
    }
    & $learner 'blend' 'journal' 'journal' 'journal-blend' '1' '2' > 'journal-blend.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged saved blend failed' }
    & $learner 'blend' 'journal-blend' 'journal' 'journal-derived' '1' '1' > 'journal-derived.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged further blend failed' }
    & $learner 'fit' 'journal-derived' 'journal-fit.json' '0.25' '--range' '0' '24' 'core.wav' 'core.pyaf' '--range' '32' '24' 'core.wav' 'core.pyaf' > 'journal-fit.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged frozen-palette fit failed' }
    & $learner 'contexts' 'journal-derived' 'journal-contexts' '8' 'core.pyaf' 'core.pyaf' > 'journal-contexts.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged source context attachment failed' }
    & $learner 'replay' 'journal-contexts' 'journal-replay' '--context-grains' '8' 'core.wav' > 'journal-replay.log'
    if ($LASTEXITCODE -ne 0) { throw 'Packaged saved-context replay failed' }
  }
  Copy-Item -LiteralPath (Join-Path $exampleRoot 'pythian.example.processing.lpr') -Destination $checkRoot
  & $compilerPath @compilerArgs 'pythian.example.processing.lpr' > 'processing-build.log' 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Processing consumer build failed; see $checkRoot/processing-build.log" }
  & (Join-Path $binRoot "pythian.example.processing$executableSuffix") 'core.wav' 'processed.wav' > 'processing-run.log'
  if ($LASTEXITCODE -ne 0) { throw 'Processing consumer failed' }
} finally {
  Pop-Location
}
Write-Output "Verified $($unitNames.Count) owned units and external consumers with $compilerVersion $compilerCpu-$compilerOs"
Write-Output "Verified $($inventory.Count) content hashes plus SHA256SUMS after ZIP extraction"
Write-Output "Base source revision: $sourceRevision ($sourceState)"
Write-Output "Archive SHA256: $((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Output "Source package: $archivePath"
Write-Output "Consumer logs: $checkRoot"
