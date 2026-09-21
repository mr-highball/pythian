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

# Optional network-backed evidence run; excluded from the ordinary build.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source
$compilerVersion = (& $compilerPath '-iV' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler version probe failed' }
$compilerCpu = (& $compilerPath '-iTP' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler CPU probe failed' }
$compilerOs = (& $compilerPath '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler OS probe failed' }
$buildRoot = Join-Path $projectRoot "build/recorded-pitch-$compilerVersion-$compilerCpu-$compilerOs"
$cacheRoot = Join-Path $projectRoot 'build/recorded-instruments'
$unitRoot = Join-Path $buildRoot 'units'
$executableSuffix = if ($compilerOs -in @('win32', 'win64')) { '.exe' } else { '' }
New-Item -ItemType Directory -Force -Path $buildRoot, $cacheRoot, $unitRoot | Out-Null

$revision = '440300901dfe9275fd84e0b7763af1f8443ae62e'
$mappingRevision = '6dd651d55dde97fd4028699be9d4481f26917891'
# Reference MIDI numbers are the upstream SFZ pitch_keycenter, not filename octaves.
$cases = @(
  @('Flute', 'LDFlute_stac_A3_v1_rr1', '69', '31dae3abbfa450de1a7dce156e8d966427e7ce562d62151a6a7173d29ef7df88'),
  @('Flute', 'LDFlute_stac_C4_v1_rr1', '72', 'befba17301cc5ce3a4d55e05374659464040339b5cea8e35259df54f3bad44b3'),
  @('Clarinet', 'DCClar_stac_D3_v1_rr1_sum', '62', '86f8fcb56a1b89a5e467bb846912c6a001b07b3b3e5cdeacc0e745f7a9feae28'),
  @('Clarinet', 'DCClar_stac_A#3_v1_rr1_sum', '70', '502b786af28107bde66d78a000edc14705f512dc1aa07bc03de4ff1bccf1d729'),
  @('Bassoon', 'PSBassoon_C2_v1_rr1', '48', '8bf2da51dc4e2b2d29aa492972f12326507cffbc05749e7bae992d1322f04f1e'),
  @('Bassoon', 'PSBassoon_A2_v1_rr1', '57', '9d06ba4c8a536f5c89acc7c94d5967cfddf9a5915044908794a4bea4170fe477')
)
function Invoke-Native([string]$Name, [string[]]$Arguments) {
  & (Join-Path $buildRoot ($Name + $executableSuffix)) @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit $LASTEXITCODE" }
}

Push-Location $projectRoot
try {
  $compilerArgs = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-Fusrc',
    '-Fuadapters/wfc', '-Fuvendor/wfc/src', '-Futools', "-FU$unitRoot", "-FE$buildRoot")
  foreach ($program in @('tools/pythian.convert.lpr', 'tools/pythian.pitch.wav.lpr',
    'tools/pythian.context.wav.lpr', 'tools/pythian.onsets.lpr', 'tools/pythian.style.lpr',
    'tools/pythian.voices.demo.lpr', 'tools/pythian.sources.demo.lpr',
    'tools/pythian.instrument.style.lpr', 'tests/pythian.tests.pitch.lpr',
    'tests/pythian.tests.wave.style.lpr')) {
    & $compilerPath @compilerArgs $program > (Join-Path $buildRoot ([IO.Path]::GetFileNameWithoutExtension($program) + '-build.log'))
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $program" }
  }
  foreach ($mapping in @('FluteStac.sfz', 'ClarinetStac.sfz', 'BassoonStac.sfz')) {
    # Store by pinned revision so another mapping cannot silently replace the reference.
    $mappingPath = Join-Path $cacheRoot "$mappingRevision-$mapping"
    if (-not (Test-Path -LiteralPath $mappingPath)) {
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sgossner/VSCO-2-CE/$mappingRevision/$mapping" -OutFile $mappingPath
    }
  }
  $licensePath = Join-Path $cacheRoot "$revision-LICENSE"
  if (-not (Test-Path -LiteralPath $licensePath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sgossner/VSCO-2-CE/$revision/LICENSE" -OutFile $licensePath
  }
  $admitted = @{}
  $windowAdmitted = @{}
  foreach ($case in $cases) {
    $name = $case[1]
    $rawPath = Join-Path $cacheRoot "$name.wav"
    if (-not (Test-Path -LiteralPath $rawPath)) {
      $relativePath = 'Woodwinds/' + $case[0] + '/stac/' + [Uri]::EscapeDataString("$name.wav")
      Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sgossner/VSCO-2-CE/$revision/$relativePath" -OutFile $rawPath
    }
    if ((Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $case[3]) {
      throw "Source hash mismatch: $name"
    }
    $prefix = Join-Path $buildRoot $name
    Invoke-Native 'pythian.convert' @($rawPath, "$prefix.wav", '8000')
    Invoke-Native 'pythian.pitch.wav' @('inspect-runs', "$prefix.wav", "$prefix.json", '0', '--monophonic')
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") recording $rawPath $case[2] 0 *> "$prefix-raw.log"
    $rawResult = $LASTEXITCODE
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") recording "$prefix.wav" $case[2] 0 *> "$prefix-reference.log"
    $convertedResult = $LASTEXITCODE
    Get-Content -LiteralPath "$prefix-reference.log"
    $admitted[$name] = ($rawResult -eq 0) -and ($convertedResult -eq 0)
    if ($admitted[$name]) { Write-Output "REFERENCE PASS: $name" }
    else { Write-Output "DEFERRED: $name; raw exit=$rawResult; converted exit=$convertedResult" }
    # One declared 110 ms policy across all pinned 44100 Hz originals and 8000 Hz copies.
    Invoke-Native 'pythian.pitch.wav' @('inspect-runs', "$prefix.wav", "$prefix-window.json",
      '0', '--monophonic', '--window-frames', '880')
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") recording $rawPath $case[2] 0 4851 *> "$prefix-window-raw.log"
    $windowRawResult = $LASTEXITCODE
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") recording "$prefix.wav" $case[2] 0 880 *> "$prefix-window-reference.log"
    $windowConvertedResult = $LASTEXITCODE
    Get-Content -LiteralPath "$prefix-window-reference.log"
    $windowAdmitted[$name] = ($windowRawResult -eq 0) -and ($windowConvertedResult -eq 0)
    if ($windowAdmitted[$name]) { Write-Output "110 MS REFERENCE PASS: $name" }
    else { Write-Output "110 MS DEFERRED: $name; raw exit=$windowRawResult; converted exit=$windowConvertedResult" }
    Get-FileHash -LiteralPath $rawPath, "$prefix.wav" -Algorithm SHA256 |
      Format-List | Out-File -LiteralPath "$prefix-hashes.log"
  }

  # Two independently checked recordings; retain full evidence through a second blend.
  foreach ($name in @('LDFlute_stac_A3_v1_rr1', 'PSBassoon_A2_v1_rr1')) {
    if (-not $admitted[$name]) { throw "Selected style source failed its independent pitch reference: $name" }
    $prefix = Join-Path $buildRoot $name
    $sourceHash = (Get-FileHash -LiteralPath "$prefix.wav" -Algorithm SHA256).Hash.ToLowerInvariant()
    Invoke-Native 'pythian.context.wav' @('admit', "$prefix.wav", $sourceHash, '500000', '0', 'major', "$prefix-context")
    Invoke-Native 'pythian.onsets' @("$prefix.wav", "$prefix-onsets.json", '512', '64')
    $provenance = "VSCO 2 CE; CC0; Sam Gossner and Simon Dalzell; sample cutting Elan Hickler/Soundemote; raw revision $revision; isolated sample $name; explicit native conversion to 8000 Hz; declared key and tempo"
    Invoke-Native 'pythian.style' @('learn-duration', "$prefix-context.pcp", "$prefix.wav",
      "$prefix-onsets.json", '1000', "$prefix.pys", '0', '--monophonic', $provenance)
  }
  $left = Join-Path $buildRoot 'LDFlute_stac_A3_v1_rr1.pys'
  $right = Join-Path $buildRoot 'PSBassoon_A2_v1_rr1.pys'
  $blend = Join-Path $buildRoot 'blend.pys'
  $reblend = Join-Path $buildRoot 'reblend.pys'
  Invoke-Native 'pythian.style' @('blend', $left, $right, '0', '0', '1', '1', $blend)
  Invoke-Native 'pythian.style' @('blend', $blend, $left, '0', '0', '1', '1', $reblend)
  Invoke-Native 'pythian.style' @('inspect', $reblend, (Join-Path $buildRoot 'reblend.json'))
  $baseline = Join-Path $buildRoot 'reblend.wav'
  $edited = Join-Path $buildRoot 'edit.wav'
  Invoke-Native 'pythian.pitch.wav' @('generate-style-runs', $reblend, $baseline,
    '--spans', '3', '--extent', 'prefix', '--context', 'hold')
  Invoke-Native 'pythian.pitch.wav' @('generate-style-runs', $reblend, $edited,
    '--spans', '3', '--extent', 'prefix', '--context', 'hold', '--duration-lock', '1:374')
  foreach ($output in @($baseline, $edited)) {
    Invoke-Native 'pythian.tests.wave.style' @('duration-output', $reblend, $output)
  }
  Invoke-Native 'pythian.tests.wave.style' @('duration-controls', $baseline, $edited, '1:374')
  $voiceBaseline = Join-Path $buildRoot 'voices.wav'
  $voiceEdited = Join-Path $buildRoot 'voices-edit.wav'
  Invoke-Native 'pythian.voices.demo' @($voiceBaseline, '--style', $reblend,
    '--duration-spans', '3', '--verify')
  Invoke-Native 'pythian.voices.demo' @($voiceEdited, '--style', $reblend,
    '--duration-spans', '3', '--duration-lock', '1:374', '--verify')
  foreach ($output in @($voiceBaseline, $voiceEdited)) {
    Invoke-Native 'pythian.tests.wave.style' @('duration-voices', $reblend, $output)
  }
  Invoke-Native 'pythian.tests.wave.style' @('duration-voice-controls', $voiceBaseline, $voiceEdited, '1:374')
  # Explicit approximate flute period, not automatic cycle/pitch detection.
  $cycleSource = Join-Path $cacheRoot 'LDFlute_stac_A3_v1_rr1.wav'
  Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot 'cycle-voices.wav'),
    '--cycle', $cycleSource, '5000', '100', '0', '32', '--midi', "$voiceBaseline.mid")
  Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot 'cycle-voices-edit.wav'),
    '--cycle', $cycleSource, '5000', '100', '0', '32', '--midi', "$voiceEdited.mid")
  # Two declared approximate periods with original phase/amplitude; no automatic alignment.
  $morphSource = Join-Path $cacheRoot 'PSBassoon_A2_v1_rr1.wav'
  Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot 'cycle-morph-voices.wav'),
    '--morph-cycle', $cycleSource, '5000', '100', '0', '32',
    $morphSource, '5000', '200', '0', '32', '4800', '--midi', "$voiceBaseline.mid")
  # The newly admitted bassoon C uses its longer window; flute retains its default window.
  if (-not $windowAdmitted['PSBassoon_C2_v1_rr1']) { throw 'Longer-window bassoon C reference failed' }
  $windowSource = Join-Path $buildRoot 'PSBassoon_C2_v1_rr1.wav'
  $windowPrefix = Join-Path $buildRoot 'window-bassoon'
  $windowHash = (Get-FileHash -LiteralPath $windowSource).Hash.ToLowerInvariant()
  Invoke-Native 'pythian.context.wav' @('admit', $windowSource, $windowHash, '500000', '0', 'major', $windowPrefix)
  Invoke-Native 'pythian.onsets' @($windowSource, "$windowPrefix-onsets.json", '512', '64')
  Invoke-Native 'pythian.style' @('learn-duration', "$windowPrefix.pcp", $windowSource,
    "$windowPrefix-onsets.json", '1000', "$windowPrefix.pys", '0', '--monophonic',
    '--window-frames', '880', "VSCO 2 CE CC0; bassoon C; declared 110 ms dense integration, key and tempo; source revision $revision")
  Invoke-Native 'pythian.style' @('blend', "$windowPrefix.pys", $left, '0', '0', '1', '1', "$windowPrefix-blend.pys")
  Invoke-Native 'pythian.style' @('blend', "$windowPrefix-blend.pys", "$windowPrefix.pys", '0', '0', '1', '1', "$windowPrefix-reblend.pys")
  Invoke-Native 'pythian.style' @('inspect', "$windowPrefix-reblend.pys", "$windowPrefix-reblend.json")
  Invoke-Native 'pythian.voices.demo' @("$windowPrefix-voices.wav", '--style', "$windowPrefix-reblend.pys", '--duration-spans', '3', '--verify')
  Invoke-Native 'pythian.voices.demo' @("$windowPrefix-edit.wav", '--style', "$windowPrefix-reblend.pys", '--duration-spans', '3', '--duration-lock', '1:316', '--verify')
  foreach ($output in @("$windowPrefix-voices.wav", "$windowPrefix-edit.wav")) {
    Invoke-Native 'pythian.tests.wave.style' @('duration-voices', "$windowPrefix-reblend.pys", $output)
  }
  Invoke-Native 'pythian.tests.wave.style' @('duration-voice-controls', "$windowPrefix-voices.wav", "$windowPrefix-edit.wav", '1:316')
  Invoke-Native 'pythian.tests.wave.style' @('performance-api', "$windowPrefix-reblend.pys")
  # Independent frequency measurement and shorter stationary timbre interval.
  Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot 'harmonic-bassoon-voices.wav'),
    '--harmonics', (Join-Path $cacheRoot 'PSBassoon_C2_v1_rr1.wav'),
    '5000', '1500', '0', '32', 'auto:4851', '0.25', '--midi', "$windowPrefix-voices.wav.mid")
  Write-Output 'Recorded style generation checks passed; consult per-recording PASS/DEFERRED results for accuracy limits.'
  # Stationary timbre is independently weighted inside the current saved style.
  $timbreC = Join-Path $buildRoot 'timbre-bassoon-c.pys'
  $timbreA = Join-Path $buildRoot 'timbre-bassoon-a.pys'
  Invoke-Native 'pythian.style' @('learn-timbre', "$windowPrefix.pys", $windowSource,
    '907', '272', '0', '24', 'auto:880', '0.25', $timbreC)
  Invoke-Native 'pythian.style' @('learn-timbre', $right, (Join-Path $buildRoot 'PSBassoon_A2_v1_rr1.wav'),
    '907', '272', '0', '16', 'auto:880', '0.25', $timbreA)
  $timbreBlend = Join-Path $buildRoot 'timbre-blend.pys'
  Invoke-Native 'pythian.style' @('blend-layers', $timbreC, $timbreA, '0', '0', '1', '0', '1', '0', '1', '1', $timbreBlend)
  foreach ($timbreVariant in @('reblend', 'edit')) {
    $timbreSource = if ($timbreVariant -eq 'reblend') { $timbreC } else { $timbreA }
    $timbreWeight = if ($timbreVariant -eq 'reblend') { '1' } else { '0' }
    $timbreStyle = Join-Path $buildRoot "timbre-$timbreVariant.pys"
    $timbreOutput = Join-Path $buildRoot "timbre-$timbreVariant.wav"
    Invoke-Native 'pythian.style' @('blend-layers', $timbreBlend, $timbreSource,
      '0', '0', '1', '0', '1', '0', $timbreWeight, '1', $timbreStyle)
    Invoke-Native 'pythian.voices.demo' @($timbreOutput, '--style', $timbreStyle, '--duration-spans', '3', '--verify')
    Invoke-Native 'pythian.tests.wave.style' @('timbre-voices', $timbreStyle, $timbreOutput)
  }
  Invoke-Native 'pythian.tests.wave.style' @('timbre-controls', (Join-Path $buildRoot 'timbre-reblend.wav'), (Join-Path $buildRoot 'timbre-edit.wav'))
  Write-Output 'Saved recorded timbre, second derivation and independent musical controls passed.'
  # Measured amplitude alone, with a declared gate and explicit truncation limit.
  foreach ($envelopeNote in @('C', 'A')) {
    $envelopeCount = if ($envelopeNote -eq 'C') { '5319' } else { '4643' }
    $envelopeSource = Join-Path $buildRoot "PSBassoon_$($envelopeNote)2_v1_rr1.wav"
    Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot "envelope-$envelopeNote.wav"),
      '--envelope', $envelopeSource, '0', $envelopeCount, '1023', '0', '256', '0.05')
    Invoke-Native 'pythian.sources.demo' @((Join-Path $buildRoot "envelope-$envelopeNote-midi.wav"),
      '--envelope', $envelopeSource, '0', $envelopeCount, '1023', '0', '256', '0.05',
      '--midi', (Join-Path $buildRoot 'timbre-reblend.wav.mid'))
  }
  Write-Output 'Measured envelope transfer passed; gate is declared, timbre and instrument roles are not inferred.'
  # Persist envelope evidence with independent selection inside the current style.
  $envelopeC = Join-Path $buildRoot 'envelope-bassoon-c.pys'
  $envelopeA = Join-Path $buildRoot 'envelope-bassoon-a.pys'
  Invoke-Native 'pythian.style' @('learn-envelope', $timbreC,
    (Join-Path $buildRoot 'PSBassoon_C2_v1_rr1.wav'), '0', '5319', '1023', '0', '256', '0.05', $envelopeC)
  Invoke-Native 'pythian.style' @('learn-envelope', $timbreA,
    (Join-Path $buildRoot 'PSBassoon_A2_v1_rr1.wav'), '0', '4643', '1023', '0', '256', '0.05', $envelopeA)
  $envelopeBlend = Join-Path $buildRoot 'envelope-blend.pys'
  Invoke-Native 'pythian.style' @('blend-layers', $envelopeC, $envelopeA,
    '0', '0', '1', '0', '1', '0', '1', '1', '1', '1', $envelopeBlend)
  foreach ($envelopeVariant in @('reblend', 'edit')) {
    $envelopeSource = if ($envelopeVariant -eq 'reblend') { $envelopeC } else { $envelopeA }
    $envelopeWeight = if ($envelopeVariant -eq 'reblend') { '1' } else { '0' }
    $envelopeStyle = Join-Path $buildRoot "envelope-$envelopeVariant.pys"
    $envelopeOutput = Join-Path $buildRoot "envelope-$envelopeVariant.wav"
    Invoke-Native 'pythian.style' @('blend-layers', $envelopeBlend, $envelopeSource,
      '0', '0', '1', '0', '1', '0', '1', '0', $envelopeWeight, '1', $envelopeStyle)
    Invoke-Native 'pythian.style' @('inspect', $envelopeStyle, "$envelopeStyle.json")
    Invoke-Native 'pythian.voices.demo' @($envelopeOutput, '--style', $envelopeStyle, '--duration-spans', '3', '--verify')
    Invoke-Native 'pythian.tests.wave.style' @('timbre-voices', $envelopeStyle, $envelopeOutput)
  }
  Invoke-Native 'pythian.tests.wave.style' @('envelope-controls',
    (Join-Path $buildRoot 'envelope-reblend.pys'), (Join-Path $buildRoot 'envelope-edit.pys'),
    (Join-Path $buildRoot 'envelope-reblend.wav'), (Join-Path $buildRoot 'envelope-edit.wav'))
  Write-Output 'Saved envelope second derivation and independent musical/timbre controls passed.'
  # Accept the music once through actual WFC passes, then bind each role's sound.
  $instrumentStyle = Join-Path $buildRoot 'envelope-reblend.pys'
  $instrumentMusic = Join-Path $buildRoot 'instrument-music.wav'
  Invoke-Native 'pythian.voices.demo' @($instrumentMusic, '--style', $instrumentStyle,
    '--duration-spans', '3', '--verify')
  foreach ($instrumentVariant in @('reblend', 'edit')) {
    $melodyEnvelope = if ($instrumentVariant -eq 'reblend') { $instrumentStyle } else { $envelopeA }
    Invoke-Native 'pythian.instrument.style' @((Join-Path $buildRoot "instrument-$instrumentVariant.wav"),
      "$instrumentMusic.mid", $envelopeC, $envelopeC, $envelopeA, $envelopeA,
      $instrumentStyle, $melodyEnvelope)
  }
  Invoke-Native 'pythian.tests.wave.style' @('instrument-controls',
    (Join-Path $buildRoot 'instrument-reblend.wav'), (Join-Path $buildRoot 'instrument-edit.wav'))
  Write-Output 'Independent saved instruments passed: melody envelope edit preserves sounding bass/chord stems and accepted MIDI.'
  # Longer music uses authored phrase training with admitted key/tempo context.
  # Isolated recorded note styles do not imply a learned multi-note phrase.
  $streamMusic = Join-Path $buildRoot 'instrument-context-music.wav'
  Invoke-Native 'pythian.voices.demo' @($streamMusic, '--context', "$windowPrefix.pcp", '--verify')
  foreach ($streamVariant in @('reblend', 'edit')) {
    $streamEnvelope = if ($streamVariant -eq 'reblend') { $instrumentStyle } else { $envelopeA }
    Invoke-Native 'pythian.instrument.style' @((Join-Path $buildRoot "instrument-stream-$streamVariant.wav"),
      "$streamMusic.mid", $envelopeC, $envelopeC, $envelopeA, $envelopeA,
      $instrumentStyle, $streamEnvelope)
  }
  Invoke-Native 'pythian.tests.wave.style' @('instrument-controls',
    (Join-Path $buildRoot 'instrument-stream-reblend.wav'),
    (Join-Path $buildRoot 'instrument-stream-edit.wav'))
  Invoke-Native 'pythian.instrument.style' @((Join-Path $buildRoot 'instrument-stream-blocks.wav'),
    "$streamMusic.mid", $envelopeC, $envelopeC, $envelopeA, $envelopeA,
    $instrumentStyle, $instrumentStyle, '--block-frames', '127')
  Invoke-Native 'pythian.tests.wave.style' @('instrument-replay',
    (Join-Path $buildRoot 'instrument-stream-reblend.wav'),
    (Join-Path $buildRoot 'instrument-stream-blocks.wav'))
  Write-Output 'Sustained instrument streams passed: independent stems, exact read-block replay and retained musical controls.'
}
finally {
  Pop-Location
}
