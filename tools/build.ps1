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
  [switch]$CoreOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Get-Command $Compiler -ErrorAction Stop).Source
$compilerVersion = (& $compilerPath '-iV' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler version probe failed' }
$compilerCpu = (& $compilerPath '-iTP' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler CPU probe failed' }
$compilerOs = (& $compilerPath '-iTO' | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Compiler OS probe failed' }
$buildRoot = Join-Path $projectRoot "build/$compilerVersion-$compilerCpu-$compilerOs"
$unitRoot = Join-Path $buildRoot 'core-units'
New-Item -ItemType Directory -Force $unitRoot | Out-Null
Write-Output "Compiler: $compilerPath ($compilerVersion $compilerCpu-$compilerOs)"

Push-Location $projectRoot
try {
  $compilerArgs = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-Fusrc', "-FU$unitRoot", "-FE$buildRoot")
  & $compilerPath @compilerArgs 'tests/pythian.tests.core.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Core compilation failed' }
  $executableSuffix = if ($compilerOs -eq 'win32' -or $compilerOs -eq 'win64') { '.exe' } else { '' }
  & (Join-Path $buildRoot "pythian.tests.core$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Core checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.evaluation.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Shared evaluation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Shared evaluation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.evaluation.parts.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Part-set evaluation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation.parts$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Part-set evaluation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.evaluation.notes.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Overlapping-note evaluation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation.notes$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Overlapping-note evaluation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.evaluation.reference.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Part reference builder compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation.reference$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Part reference builder checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.evaluation.style.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Style distribution compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation.style$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Style distribution checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tests/pythian.tests.evaluation.files.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'File-bound evaluation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.evaluation.files$executableSuffix") (Join-Path $buildRoot 'evaluation-files')
  if ($LASTEXITCODE -ne 0) { throw 'File-bound evaluation checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.evaluate.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Evaluation operator compilation failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.part.controls.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Part control operator compilation failed' }
  & (Join-Path $buildRoot "pythian.part.controls$executableSuffix") '--controls'
  if ($LASTEXITCODE -ne 0) { throw 'Part control arithmetic checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.part.prepare.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Part preparation operator compilation failed' }
  & (Join-Path $buildRoot "pythian.part.prepare$executableSuffix") '--controls'
  if ($LASTEXITCODE -ne 0) { throw 'Part preparation arithmetic checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.separation.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Fourier/separation fixture compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.separation$executableSuffix") (Join-Path $buildRoot 'separation-control')
  if ($LASTEXITCODE -ne 0) { throw 'Fourier/separation signal checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.separate.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Separation operator compilation failed' }
  & (Join-Path $buildRoot "pythian.separate$executableSuffix") (Join-Path $buildRoot 'separation-control-source.wav') (Join-Path $buildRoot 'separated') '512' '128' '17' '17'
  if ($LASTEXITCODE -ne 0) { throw 'Native separation operator failed' }
  & (Join-Path $buildRoot "pythian.tests.separation$executableSuffix") 'reconstruct' (Join-Path $buildRoot 'separation-control-source.wav') (Join-Path $buildRoot 'separated-harmonic.wav') (Join-Path $buildRoot 'separated-percussive.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Encoded separated component reconstruction failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.hash.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Hash compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.hash$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Hash checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.chord.stream.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Chord stream compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.chord.stream$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Chord stream checks failed' }
  & $compilerPath @compilerArgs 'tools/pythian.chord.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Chord demo compilation failed' }
  & (Join-Path $buildRoot "pythian.chord.demo$executableSuffix") (Join-Path $buildRoot 'chords.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Chord demo smoke failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.resample.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Oscillator/resampling compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.resample$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Oscillator/resampling checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.resample.stream.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Streaming resampling compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.resample.stream$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Streaming resampling checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.modulation.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Automation/modulation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.modulation$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Automation/modulation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.control.curves.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Periodic automation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.control.curves$executableSuffix") (Join-Path $buildRoot 'envelope-source.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Periodic automation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.delay.modulated.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Modulated delay compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.delay.modulated$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Modulated delay checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.reverb.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Reverb compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.reverb$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Reverb checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.context.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Musical context compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.context$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Musical context checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.context.admission.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'WAV context admission compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.context.admission$executableSuffix") (Join-Path $buildRoot 'key-admission-source.wav')
  if ($LASTEXITCODE -ne 0) { throw 'WAV context admission checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.source.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Source compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.source$executableSuffix") (Join-Path $buildRoot 'cycle-source.wav') (Join-Path $buildRoot 'harmonic-source.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Source checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.sample.loop.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Interior sample loop compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.sample.loop$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Interior sample loop checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.instrument.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Instrument compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.instrument$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Instrument checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.music.instrument.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Instrument sequence compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.music.instrument$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Instrument sequence checks failed' }
  & $compilerPath @compilerArgs 'tools/pythian.instrument.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Instrument demo compilation failed' }
  & (Join-Path $buildRoot "pythian.instrument.demo$executableSuffix") (Join-Path $buildRoot 'instrument.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Instrument demo failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.effects.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Effects compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.effects$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Effects checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.bus.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Bus compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.bus$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Bus checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.schedule.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Scheduler compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.schedule$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Scheduler checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.corpus.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Corpus compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.corpus$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Corpus checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.passage.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Passage compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.passage$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Passage checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.activity.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Activity compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.activity$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Activity and continuity checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.onset.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Onset localization compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.onset$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Onset localization checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.events.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Onset event compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.events$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Onset event checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.beat.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat grid compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.beat$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Beat grid checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.beat.track.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat tracking compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.beat.track$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Beat tracking checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.beat.clock.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat clock compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.beat.clock$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Beat clock checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.pulse.events.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Pulse event compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.pulse.events$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Pulse event checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.beat.lab.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat laboratory compilation failed' }
  & (Join-Path $buildRoot "pythian.beat.lab$executableSuffix") (Join-Path $buildRoot 'beat-lab')
  if ($LASTEXITCODE -ne 0) { throw 'Beat laboratory failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.beats.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat inspection compilation failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.beat.candidates.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Beat candidate evaluation compilation failed' }
  & (Join-Path $buildRoot "pythian.beats$executableSuffix") (Join-Path $buildRoot 'beat-lab-polyphonic.wav') (Join-Path $buildRoot 'beat-polyphonic.json') '--audition' (Join-Path $buildRoot 'beat-polyphonic-listen.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Beat inspection smoke failed' }
  & (Join-Path $buildRoot "pythian.beats$executableSuffix") (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'beat-track-change.json') '--track' '--audition' (Join-Path $buildRoot 'beat-track-change-listen.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Beat tracking inspection smoke failed' }
  & (Join-Path $buildRoot "pythian.beats$executableSuffix") (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'beat-clock-change.json') '--track' '--clock' 'step' '--audition' (Join-Path $buildRoot 'beat-clock-change-listen.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Continuous beat clock smoke failed' }
  & (Join-Path $buildRoot "pythian.beats$executableSuffix") (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'beat-alignment-change.json') '--track' '--clock' 'step' '--alignment-context' '--audition' (Join-Path $buildRoot 'beat-alignment-change-listen.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Contextual beat alignment smoke failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.onset.lab.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Onset laboratory compilation failed' }
  & (Join-Path $buildRoot "pythian.onset.lab$executableSuffix") (Join-Path $buildRoot 'onset-lab')
  if ($LASTEXITCODE -ne 0) { throw 'Onset laboratory failed' }
  & (Join-Path $buildRoot "pythian.onset.lab$executableSuffix") (Join-Path $buildRoot 'onset-fine') '1024' '256'
  if ($LASTEXITCODE -ne 0) { throw 'Fine-grid onset laboratory failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.onsets.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Onset inspection compilation failed' }
  & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'onset-fine-close-percussion.wav') (Join-Path $buildRoot 'onset-close.json') '--audition' (Join-Path $buildRoot 'onset-close.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Onset inspection smoke failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.granular.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Granular compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.granular$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Granular checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.wave.stream.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Streaming WAVE compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.wave.stream$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Streaming WAVE checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.wave.read.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'WAVE reader compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.wave.read$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'WAVE reader checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.spectrum.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Spectrum partition compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.spectrum$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Spectrum partition checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.analysis.wave.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'WAVE analysis compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.analysis.wave$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'WAVE analysis checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.analysis.journal.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Feature journal compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.analysis.journal$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Feature journal checks failed' }
  & $compilerPath @compilerArgs 'tools/pythian.wave.transcode.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'WAVE transcode compilation failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.music.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Music compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.music$executableSuffix") (Join-Path $buildRoot 'timing.mid')
  if ($LASTEXITCODE -ne 0) { throw 'Music checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.midi.stream.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'MIDI stream compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.midi.stream$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'MIDI stream checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.midi.chord.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Chord MIDI compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.midi.chord$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Chord MIDI checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.midi.export.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'MIDI note export compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.midi.export$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'MIDI note export checks failed' }
  & $compilerPath @compilerArgs 'examples/pythian.example.midi.stream.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'MIDI stream example compilation failed' }
  & (Join-Path $buildRoot "pythian.example.midi.stream$executableSuffix") (Join-Path $buildRoot 'streamed.mid')
  if ($LASTEXITCODE -ne 0) { throw 'MIDI stream example failed' }
  & $compilerPath @compilerArgs 'examples/pythian.example.notes.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Native notes example compilation failed' }
  & (Join-Path $buildRoot "pythian.example.notes$executableSuffix") (Join-Path $buildRoot 'notes-example')
  if ($LASTEXITCODE -ne 0) { throw 'Native notes example failed' }
  & $compilerPath @compilerArgs 'examples/pythian.example.instrument.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Instrument envelope example compilation failed' }
  & (Join-Path $buildRoot "pythian.example.instrument$executableSuffix") (Join-Path $buildRoot 'instrument-envelope.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Instrument envelope example failed' }
  & (Join-Path $buildRoot "pythian.example.instrument$executableSuffix") (Join-Path $buildRoot 'instrument-midi-envelope.wav') (Join-Path $buildRoot 'timing.mid')
  if ($LASTEXITCODE -ne 0) { throw 'MIDI instrument envelope example failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.clock.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Incremental clock compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.clock$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Incremental clock checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.articulation.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Articulation compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.articulation$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Articulation checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.alignment.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Alignment compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.alignment$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Alignment checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.tonal.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Tonal compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.tonal$executableSuffix")
  if ($LASTEXITCODE -ne 0) { throw 'Tonal checks failed' }
  & $compilerPath @compilerArgs 'tests/pythian.tests.pitch.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Pitch estimator compilation failed' }
  & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") (Join-Path $buildRoot 'pitch-source.wav') (Join-Path $buildRoot 'pitch-octave.wav') (Join-Path $buildRoot 'run-source.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Pitch estimator checks failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.phrase.wav.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Recorded phrase evaluator compilation failed' }
  & $compilerPath @compilerArgs 'tools/pythian.presence.reference.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Note-presence reference checker compilation failed' }
  & $compilerPath @compilerArgs 'tools/pythian.presence.decision.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Note-presence decision compilation failed' }
  & (Join-Path $buildRoot "pythian.presence.decision$executableSuffix") 'controls'
  if ($LASTEXITCODE -ne 0) { throw 'Note-presence decision controls failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.localkey.reference.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Local-key reference checker compilation failed' }
  & (Join-Path $buildRoot "pythian.localkey.reference$executableSuffix") 'controls'
  if ($LASTEXITCODE -ne 0) { throw 'Local-key reference controls failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.localkey.score.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Local-key packet scorer compilation failed' }
  & (Join-Path $buildRoot "pythian.localkey.score$executableSuffix") 'controls'
  if ($LASTEXITCODE -ne 0) { throw 'Local-key packet scorer controls failed' }
  & $compilerPath @compilerArgs 'tools/pythian.localkey.nokey.reference.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Acoustic no-key reference checker compilation failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.tonal.inspect.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Tonal inspection compilation failed' }
  & (Join-Path $buildRoot "pythian.tonal.inspect$executableSuffix") 'midi' (Join-Path $buildRoot 'timing.mid') > (Join-Path $buildRoot 'tonal-midi.json')
  if ($LASTEXITCODE -ne 0) { throw 'MIDI tonal inspection failed' }
  & $compilerPath @compilerArgs '-Futools' 'tools/pythian.articulate.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Articulation tool compilation failed' }
  & $compilerPath @compilerArgs 'tools/pythian.midi.render.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'MIDI renderer compilation failed' }
  & (Join-Path $buildRoot "pythian.midi.render$executableSuffix") (Join-Path $buildRoot 'timing.mid') (Join-Path $buildRoot 'timing.wav')
  if ($LASTEXITCODE -ne 0) { throw 'MIDI renderer smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.render.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Renderer compilation failed' }
  & (Join-Path $buildRoot "pythian.render$executableSuffix") (Join-Path $buildRoot 'synthesis.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Renderer smoke failed' }
  & (Join-Path $buildRoot "pythian.wave.transcode$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'synthesis-copy.wav') '137'
  if ($LASTEXITCODE -ne 0) { throw 'WAVE transcode smoke failed' }
  if ((Get-FileHash (Join-Path $buildRoot 'synthesis.wav')).Hash -ne
      (Get-FileHash (Join-Path $buildRoot 'synthesis-copy.wav')).Hash) {
    throw 'WAVE transcode changed canonical PCM16 audio'
  }
  & (Join-Path $buildRoot "pythian.tonal.inspect$executableSuffix") 'wav' (Join-Path $buildRoot 'synthesis.wav') > (Join-Path $buildRoot 'tonal-wave.json')
  if ($LASTEXITCODE -ne 0) { throw 'WAV tonal inspection failed' }
  & (Join-Path $buildRoot "pythian.articulate$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'articulation-grid.wav') 'grid' '500000' '240' 'ahrrahrrahrrahrr'
  if ($LASTEXITCODE -ne 0) { throw 'Grid articulation smoke failed' }
  & (Join-Path $buildRoot "pythian.articulate$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'articulation-midi.wav') 'midi' (Join-Path $buildRoot 'timing.mid')
  if ($LASTEXITCODE -ne 0) { throw 'MIDI articulation smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.dsp.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'DSP demo compilation failed' }
  & (Join-Path $buildRoot "pythian.dsp.demo$executableSuffix") (Join-Path $buildRoot 'dsp-comparison.wav')
  if ($LASTEXITCODE -ne 0) { throw 'DSP demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.modulation.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Modulation demo compilation failed' }
  & (Join-Path $buildRoot "pythian.modulation.demo$executableSuffix") (Join-Path $buildRoot 'modulation.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Modulation demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.control.curves.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Periodic automation demo compilation failed' }
  & (Join-Path $buildRoot "pythian.control.curves.demo$executableSuffix") (Join-Path $buildRoot 'control-curves.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Periodic automation demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.sources.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Source demo compilation failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'sources.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Source demo smoke failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'measured-envelope.wav') '--envelope' (Join-Path $buildRoot 'envelope-source.wav') '3' '5150' '1999' '1' '800' '0.04'
  if ($LASTEXITCODE -ne 0) { throw 'Measured envelope source demo failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'measured-envelope-midi.wav') '--envelope' (Join-Path $buildRoot 'envelope-source.wav') '3' '5150' '1999' '1' '800' '0.04' '--midi' (Join-Path $buildRoot 'timing.mid')
  if ($LASTEXITCODE -ne 0) { throw 'Measured envelope MIDI source demo failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'cycle-instrument.wav') '--cycle' (Join-Path $buildRoot 'cycle-source.wav') '7' '97' '1' '5'
  if ($LASTEXITCODE -ne 0) { throw 'Measured WAV-cycle source demo failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'harmonic-instrument.wav') '--harmonics' (Join-Path $buildRoot 'harmonic-source.wav') '7' '1499' '1' '5' 'auto' '0.05'
  if ($LASTEXITCODE -ne 0) { throw 'Measured multi-period harmonic source demo failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'harmonic-trajectory.wav') '--trajectory' (Join-Path $buildRoot 'harmonic-source.wav') '7' '499' '500' '3' '1' '5' '213.7' '0.001'
  if ($LASTEXITCODE -ne 0) { throw 'Measured harmonic trajectory source demo failed' }
  & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'harmonic-trajectory-shape.wav') '--trajectory-shape' (Join-Path $buildRoot 'harmonic-source.wav') '7' '499' '500' '3' '1' '5' '213.7' '0.001' '0.1'
  if ($LASTEXITCODE -ne 0) { throw 'Measured magnitude trajectory source demo failed' }
  & $compilerPath @compilerArgs 'tools/pythian.sample.loop.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Interior sample loop demo compilation failed' }
  & (Join-Path $buildRoot "pythian.sample.loop.demo$executableSuffix") (Join-Path $buildRoot 'sample-loop.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Interior sample loop demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.effects.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Effects demo compilation failed' }
  & (Join-Path $buildRoot "pythian.effects.demo$executableSuffix") (Join-Path $buildRoot 'effects.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Effects demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.delay.modulated.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Modulated delay demo compilation failed' }
  & (Join-Path $buildRoot "pythian.delay.modulated.demo$executableSuffix") (Join-Path $buildRoot 'modulated-delay.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Modulated delay demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.reverb.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Reverb demo compilation failed' }
  & (Join-Path $buildRoot "pythian.reverb.demo$executableSuffix") (Join-Path $buildRoot 'reverb.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Reverb demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.bus.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Bus demo compilation failed' }
  & (Join-Path $buildRoot "pythian.bus.demo$executableSuffix") (Join-Path $buildRoot 'buses.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Bus demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.schedule.demo.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Scheduler demo compilation failed' }
  & (Join-Path $buildRoot "pythian.schedule.demo$executableSuffix") (Join-Path $buildRoot 'scheduled.wav')
  if ($LASTEXITCODE -ne 0) { throw 'Scheduler demo smoke failed' }
  & $compilerPath @compilerArgs 'tools/pythian.convert.lpr'
  if ($LASTEXITCODE -ne 0) { throw 'Rate converter compilation failed' }
  & (Join-Path $buildRoot "pythian.convert$executableSuffix") (Join-Path $buildRoot 'dsp-comparison.wav') (Join-Path $buildRoot 'dsp-comparison-44100.wav') '44100'
  if ($LASTEXITCODE -ne 0) { throw 'Rate conversion smoke failed' }
  if (-not $CoreOnly) {
    $adapterUnitRoot = Join-Path $buildRoot 'wfc-units'
    New-Item -ItemType Directory -Force $adapterUnitRoot | Out-Null
    $adapterArgs = @('-B', '-Sa', '-Cr', '-Co', '-Ci', '-gl', '-Fusrc',
      '-Fuadapters/wfc', '-Fuvendor/wfc/src', '-Futools', "-FU$adapterUnitRoot", "-FE$buildRoot")
    & $compilerPath @adapterArgs '-dWFC_MIDI_STREAM_CHECKS' 'tests/pythian.tests.midi.stream.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC MIDI stream parity compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.midi.stream$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC MIDI stream parity failed' }
    & $compilerPath @adapterArgs '-dWFC_CHORD_MIDI_CHECKS' 'tests/pythian.tests.midi.chord.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC chord MIDI compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.midi.chord$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC chord MIDI parity failed' }
    & $compilerPath @adapterArgs '-dWFC_CHORD_CHECKS' 'tests/pythian.tests.chord.stream.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC chord bridge compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.chord.stream$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC chord bridge checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.music.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC music compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.music$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC music checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.stream.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC streaming compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.stream$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC streaming checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.layers.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC layer compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.layers$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC layer checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.context.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC context compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.context$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC context checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.context.archive.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Context archive compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.context.archive$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Context archive checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.context.demo.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC context demo compilation failed' }
    & (Join-Path $buildRoot "pythian.context.demo$executableSuffix") (Join-Path $buildRoot 'context')
    if ($LASTEXITCODE -ne 0) { throw 'WFC context demo failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.context.profile.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Context profile compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Context profile checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.context.track.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Tracked context operator compilation failed' }
    $trackSource = Join-Path $buildRoot 'beat-lab-tempo-change.wav'
    $trackHash = (Get-FileHash -LiteralPath $trackSource -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'admit' $trackSource $trackHash '0' '23' '-1' 'major' (Join-Path $buildRoot 'track-context')
    if ($LASTEXITCODE -ne 0) { throw 'Tracked context admission failed' }
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'audition' (Join-Path $buildRoot 'track-context.pcp') (Join-Path $buildRoot 'track-context.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved changing-clock audition failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") 'track' (Join-Path $buildRoot 'track-context') $trackSource
    if ($LASTEXITCODE -ne 0) { throw 'Tracked source/profile/audio replay failed' }
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'admit' $trackSource $trackHash '0' '23' '-1' 'major' (Join-Path $buildRoot 'clock-context') '--clock' 'step'
    if ($LASTEXITCODE -ne 0) { throw 'Reconstructed clock context admission failed' }
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'audition' (Join-Path $buildRoot 'clock-context.pcp') (Join-Path $buildRoot 'clock-context.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved reconstructed-clock audition failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") 'track' (Join-Path $buildRoot 'clock-context') $trackSource
    if ($LASTEXITCODE -ne 0) { throw 'Reconstructed clock/profile/audio replay failed' }
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'admit' $trackSource $trackHash '0' '23' '-1' 'major' (Join-Path $buildRoot 'alignment-context') '--clock' 'step' '--alignment-context'
    if ($LASTEXITCODE -ne 0) { throw 'Contextual alignment admission failed' }
    & (Join-Path $buildRoot "pythian.context.track$executableSuffix") 'audition' (Join-Path $buildRoot 'alignment-context.pcp') (Join-Path $buildRoot 'alignment-context.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved contextual alignment audition failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") 'track' (Join-Path $buildRoot 'alignment-context') $trackSource
    if ($LASTEXITCODE -ne 0) { throw 'Contextual alignment/profile/audio replay failed' }
    & $compilerPath @adapterArgs 'tools/pythian.context.select.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Context selector compilation failed' }
    & (Join-Path $buildRoot "pythian.context.select$executableSuffix") '--source' (Join-Path $buildRoot 'context.ptc') (Join-Path $buildRoot 'context-source.pcp')
    if ($LASTEXITCODE -ne 0) { throw 'Context source profile smoke failed' }
    & (Join-Path $buildRoot "pythian.context.select$executableSuffix") (Join-Path $buildRoot 'context.profile-1.pcp') (Join-Path $buildRoot 'context.profile-0.pcp') (Join-Path $buildRoot 'context-derived.pcp')
    if ($LASTEXITCODE -ne 0) { throw 'Derived context profile smoke failed' }
    & $compilerPath @adapterArgs 'tools/pythian.context.wav.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV context operator compilation failed' }
    $admissionSource = Join-Path $buildRoot 'key-admission-source.wav'
    $admissionHash = (Get-FileHash -LiteralPath $admissionSource -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'inspect' $admissionSource (Join-Path $buildRoot 'key-inspection.json')
    if ($LASTEXITCODE -ne 0) { throw 'WAV key inspection smoke failed' }
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' $admissionSource $admissionHash '500000' '0' 'major' (Join-Path $buildRoot 'key-admission')
    if ($LASTEXITCODE -ne 0) { throw 'WAV key admission smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") (Join-Path $buildRoot 'key-admission') $admissionSource
    if ($LASTEXITCODE -ne 0) { throw 'WAV context profile binding/generation checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.layers.demo.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Layer synthesis demo compilation failed' }
    & (Join-Path $buildRoot "pythian.layers.demo$executableSuffix") (Join-Path $buildRoot 'layers.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Layer synthesis demo failed' }
    & $compilerPath @adapterArgs 'tools/pythian.ensemble.demo.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Ensemble stream demo compilation failed' }
    & (Join-Path $buildRoot "pythian.ensemble.demo$executableSuffix") (Join-Path $buildRoot 'ensemble.wav') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Ensemble stream demo verification failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.voices.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Named independent-voice fixture compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.voices$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Named independent-voice checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.semantic.style.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Semantic style compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.semantic.style$executableSuffix") (Join-Path $buildRoot 'semantic-style')
    if ($LASTEXITCODE -ne 0) { throw 'Semantic style checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.semantic.blend.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Semantic blend compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.semantic.blend$executableSuffix") (Join-Path $buildRoot 'semantic-blend')
    if ($LASTEXITCODE -ne 0) { throw 'Semantic blend checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.duration.stream.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Duration stream compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.duration.stream$executableSuffix") (Join-Path $buildRoot 'duration-stream')
    if ($LASTEXITCODE -ne 0) { throw 'Duration stream checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.voices.demo.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Independent voices demo compilation failed' }
    & $compilerPath @adapterArgs 'tools/pythian.instrument.style.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Saved instrument consumer compilation failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'voices.wav') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Independent voices demo verification failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.voices.context.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Voice context fixture compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.voices.context$executableSuffix") (Join-Path $buildRoot 'voice-context')
    if ($LASTEXITCODE -ne 0) { throw 'Voice context fixtures failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'voices-context.wav') '--context' (Join-Path $buildRoot 'voice-context.minor.pcp') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Saved context voice realization failed' }
    & (Join-Path $buildRoot "pythian.tests.voices.context$executableSuffix") (Join-Path $buildRoot 'voice-context.minor.pcp') (Join-Path $buildRoot 'voices-context.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved context voice output checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wave.style.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV style fixture compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") (Join-Path $buildRoot 'wave-style')
    if ($LASTEXITCODE -ne 0) { throw 'Weighted saved WAV style checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.style.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV style operator compilation failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") $admissionSource (Join-Path $buildRoot 'style-onsets.json') '1024' '128'
    if ($LASTEXITCODE -ne 0) { throw 'Controlled style onset measurement failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn' (Join-Path $buildRoot 'key-admission.pcp') $admissionSource (Join-Path $buildRoot 'style-onsets.json') '400' (Join-Path $buildRoot 'learned-style.pys') 'Authored native C-major sine fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Controlled WAV style learning failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'inspect' (Join-Path $buildRoot 'wave-style.reblend.pys') (Join-Path $buildRoot 'wave-style-reblend.json')
    if ($LASTEXITCODE -ne 0) { throw 'Repeated style inspection failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'voices-style.wav') '--style' (Join-Path $buildRoot 'learned-style.pys') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Learned WAV style realization failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'learned-style.pys') (Join-Path $buildRoot 'voices-style.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Learned WAV style output checks failed' }
    # Measured pulse selection becomes an ordinary saved style and audible clock.
    & (Join-Path $buildRoot "pythian.tests.context.admission$executableSuffix") 'tempo' $admissionSource '120'
    if ($LASTEXITCODE -ne 0) { throw 'Independent controlled tempo reference failed' }
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit-tempo' $admissionSource $admissionHash '0' '0' 'major' (Join-Path $buildRoot 'measured-tempo')
    if ($LASTEXITCODE -ne 0) { throw 'Measured tempo context admission failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") (Join-Path $buildRoot 'measured-tempo') $admissionSource
    if ($LASTEXITCODE -ne 0) { throw 'Measured tempo profile replay failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn' (Join-Path $buildRoot 'measured-tempo.pcp') $admissionSource (Join-Path $buildRoot 'style-onsets.json') '400' (Join-Path $buildRoot 'measured-tempo.pys') 'Native C-major phrase; explicitly selected measured pulse tempo'
    if ($LASTEXITCODE -ne 0) { throw 'Measured tempo style learning failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'measured-tempo-voices.wav') '--style' (Join-Path $buildRoot 'measured-tempo.pys') '--style-extent' 'prefix' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Measured tempo style generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'measured-tempo.pys') (Join-Path $buildRoot 'measured-tempo-voices.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Measured tempo audible output check failed' }
    # Source pulse phase survives saved styles and a second derivation.
    Copy-Item -LiteralPath $admissionSource -Destination (Join-Path $buildRoot 'phase-source.wav')
    & (Join-Path $buildRoot "pythian.tests.context.admission$executableSuffix") 'shifted' (Join-Path $buildRoot 'phase-shifted.wav') '1000'
    if ($LASTEXITCODE -ne 0) { throw 'Shifted pulse source failed' }
    foreach ($phaseSource in @('phase-source', 'phase-shifted')) {
      $phaseWave = Join-Path $buildRoot "$phaseSource.wav"
      $phaseHash = (Get-FileHash -LiteralPath $phaseWave -Algorithm SHA256).Hash.ToLowerInvariant()
      & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit-beats' $phaseWave $phaseHash '0' '0' 'major' (Join-Path $buildRoot $phaseSource)
      if ($LASTEXITCODE -ne 0) { throw 'Pulse phase admission failed' }
      & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") (Join-Path $buildRoot $phaseSource) $phaseWave
      if ($LASTEXITCODE -ne 0) { throw 'Pulse phase profile replay failed' }
      & (Join-Path $buildRoot "pythian.onsets$executableSuffix") $phaseWave (Join-Path $buildRoot "$phaseSource-onsets.json") '256' '64'
      if ($LASTEXITCODE -ne 0) { throw 'Pulse phase onsets failed' }
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-dynamics' (Join-Path $buildRoot "$phaseSource.pcp") $phaseWave (Join-Path $buildRoot "$phaseSource-onsets.json") '80' (Join-Path $buildRoot "$phaseSource.pys")
      if ($LASTEXITCODE -ne 0) { throw 'Pulse phase dynamics style failed' }
    }
    $phaseWave = Join-Path $buildRoot 'phase-shifted.wav'
    $phaseHash = (Get-FileHash -LiteralPath $phaseWave -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' $phaseWave $phaseHash '500000' '0' 'major' (Join-Path $buildRoot 'phase-zero')
    if ($LASTEXITCODE -ne 0) { throw 'Frame-zero control context failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn' (Join-Path $buildRoot 'phase-zero.pcp') $phaseWave (Join-Path $buildRoot 'phase-shifted-onsets.json') '80' (Join-Path $buildRoot 'phase-zero.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Frame-zero rhythm control failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-pitch' (Join-Path $buildRoot 'phase-shifted.pcp') $phaseWave (Join-Path $buildRoot 'phase-shifted-onsets.json') '80' (Join-Path $buildRoot 'phase-pitch.pys') '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Shifted pitch-cell measurement failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'phase-shifted.pys') (Join-Path $buildRoot 'phase-source.pys') '0' '1' '2' '1' (Join-Path $buildRoot 'phase-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Phase style blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'phase-blend.pys') (Join-Path $buildRoot 'phase-shifted.pys') '0' '0' '2' '1' (Join-Path $buildRoot 'phase-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Phase style second blend failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'phase-style' (Join-Path $buildRoot 'phase-pitch.pys') (Join-Path $buildRoot 'phase-zero.pys') (Join-Path $buildRoot 'phase-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Phase style and pitch admission verification failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'phase-voices.wav') '--style' (Join-Path $buildRoot 'phase-reblend.pys') '--style-extent' 'prefix' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Phase style voice generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'phase-reblend.pys') (Join-Path $buildRoot 'phase-voices.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Phase style output verification failed' }
    # Dense performance retains uncertain gaps and supports independent measured tempo selection.
    foreach ($phaseSource in @('phase-source', 'phase-shifted')) {
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot "$phaseSource.pcp") (Join-Path $buildRoot "$phaseSource.wav") (Join-Path $buildRoot "$phaseSource-onsets.json") '80' (Join-Path $buildRoot "$phaseSource-duration.pys") '0' '--monophonic'
      if ($LASTEXITCODE -ne 0) { throw 'Measured phrase duration learning failed' }
    }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'phase-shifted-duration.pys') (Join-Path $buildRoot 'phase-source-duration.pys') '0' '1' '2' '1' (Join-Path $buildRoot 'phase-duration-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Measured phrase duration blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'phase-duration-blend.pys') (Join-Path $buildRoot 'phase-shifted-duration.pys') '0' '0' '2' '1' (Join-Path $buildRoot 'phase-duration-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Measured phrase duration second blend failed' }
    $phaseWave = Join-Path $buildRoot 'phase-source.wav'
    $phaseHash = (Get-FileHash -LiteralPath $phaseWave -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit-beats' $phaseWave $phaseHash '1' '0' 'major' (Join-Path $buildRoot 'phase-fast')
    if ($LASTEXITCODE -ne 0) { throw 'Alternative measured pulse admission failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") (Join-Path $buildRoot 'phase-fast') $phaseWave
    if ($LASTEXITCODE -ne 0) { throw 'Alternative measured pulse replay failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot 'phase-fast.pcp') $phaseWave (Join-Path $buildRoot 'phase-source-onsets.json') '80' (Join-Path $buildRoot 'phase-fast.pys') '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Alternative pulse style learning failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'phase-duration-reblend.pys') (Join-Path $buildRoot 'phase-fast.pys') '0' '1' '1' '0' (Join-Path $buildRoot 'phase-duration-fast.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent measured pulse selection failed' }
    foreach ($phaseStyle in @('phase-duration-reblend', 'phase-duration-fast')) {
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot "$phaseStyle.wav") '--style' (Join-Path $buildRoot "$phaseStyle.pys") '--duration-spans' '32' '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Measured phrase performance generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot "$phaseStyle.pys") (Join-Path $buildRoot "$phaseStyle.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Measured phrase audio/MIDI verification failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voice-tempo' (Join-Path $buildRoot 'phase-duration-reblend.wav') (Join-Path $buildRoot 'phase-duration-fast.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Independent measured pulse control verification failed' }
    # Local source clocks feed saved rhythm/pitch layers and actual voice timing.
    & (Join-Path $buildRoot "pythian.context.select$executableSuffix") (Join-Path $buildRoot 'phase-source.pcp') (Join-Path $buildRoot 'track-context.pcp') (Join-Path $buildRoot 'local-context.pcp')
    if ($LASTEXITCODE -ne 0) { throw 'Local clock independent key selection failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'local-onsets.json') '256' '64'
    if ($LASTEXITCODE -ne 0) { throw 'Local source onset inspection failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-dynamics' (Join-Path $buildRoot 'local-context.pcp') (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'local-onsets.json') '1323' (Join-Path $buildRoot 'local-rhythm.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Local rhythm/intensity admission failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-rhythm.pys') (Join-Path $buildRoot 'phase-shifted.pys') '0' '0' '2' '1' (Join-Path $buildRoot 'local-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Mixed source-clock style blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-blend.pys') (Join-Path $buildRoot 'phase-shifted.pys') '0' '0' '2' '1' (Join-Path $buildRoot 'local-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Mixed source-clock second blend failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'local-voices.wav') '--style' (Join-Path $buildRoot 'local-reblend.pys') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Local style voice generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'changing-output' (Join-Path $buildRoot 'local-reblend.pys') (Join-Path $buildRoot 'local-voices.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Local clock voice/audio/MIDI checks failed' }
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") 'changing' (Join-Path $buildRoot 'local-pitch.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Independent changing-pitch source failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'changing-pitch-context' (Join-Path $buildRoot 'local-pitch.wav') (Join-Path $buildRoot 'local-pitch')
    if ($LASTEXITCODE -ne 0) { throw 'Independent changing-pitch context failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'local-pitch.wav') (Join-Path $buildRoot 'local-pitch-onsets.json') '256' '64'
    if ($LASTEXITCODE -ne 0) { throw 'Changing-pitch onsets failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-pitch' (Join-Path $buildRoot 'local-pitch.pcp') (Join-Path $buildRoot 'local-pitch.wav') (Join-Path $buildRoot 'local-pitch-onsets.json') '80' (Join-Path $buildRoot 'local-pitch.pys') '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Changing-pitch style learning failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'changing-pitch-style' (Join-Path $buildRoot 'local-pitch.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Changing-pitch source/clock checks failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'local-pitch-voices.wav') '--style' (Join-Path $buildRoot 'local-pitch.pys') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Independent changing-source pitch generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'local-pitch.pys') (Join-Path $buildRoot 'local-pitch-voices.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Changing-source pitch/audio/MIDI checks failed' }
    # Normalize dense evidence on each source clock before saved weighted learning.
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot 'local-pitch.pcp') (Join-Path $buildRoot 'local-pitch.wav') (Join-Path $buildRoot 'local-pitch-onsets.json') '80' (Join-Path $buildRoot 'local-duration.pys') '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Local-clock dense normalization failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'changing-pitch-style' (Join-Path $buildRoot 'local-duration.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Local-clock dense source binding failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-duration.pys') (Join-Path $buildRoot 'phase-source-duration.pys') '1' '1' '2' '1' (Join-Path $buildRoot 'local-duration-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Different source-clock duration blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-duration-blend.pys') (Join-Path $buildRoot 'phase-source-duration.pys') '0' '0' '2' '1' (Join-Path $buildRoot 'local-duration-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Normalized duration second blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-duration-reblend.pys') (Join-Path $buildRoot 'phase-fast.pys') '0' '1' '1' '0' (Join-Path $buildRoot 'local-duration-fast.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent normalized duration tempo selection failed' }
    foreach ($localDurationStyle in @('local-duration-reblend', 'local-duration-fast')) {
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot "$localDurationStyle.wav") '--style' (Join-Path $buildRoot "$localDurationStyle.pys") '--duration-spans' '32' '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Normalized duration voice generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot "$localDurationStyle.pys") (Join-Path $buildRoot "$localDurationStyle.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Normalized duration audio/MIDI verification failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voice-tempo' (Join-Path $buildRoot 'local-duration-reblend.wav') (Join-Path $buildRoot 'local-duration-fast.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Normalized duration tempo independence failed' }
    # Explicit onset ownership retains same-pitch attacks in saved duration styles.
    & (Join-Path $buildRoot "pythian.tests.pitch$executableSuffix") 'repeated' (Join-Path $buildRoot 'repeated.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Continuous-pitch attack source failed' }
    $repeatedHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'repeated.wav') -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' (Join-Path $buildRoot 'repeated.wav') $repeatedHash '500000' '0' 'major' (Join-Path $buildRoot 'repeated-context')
    if ($LASTEXITCODE -ne 0) { throw 'Repeated-attack context admission failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'repeated.wav') (Join-Path $buildRoot 'repeated-onsets.json') '512' '64'
    if ($LASTEXITCODE -ne 0) { throw 'Repeated-attack onset measurement failed' }
    foreach ($attackPolicy in @('plain', 'articulated')) {
      $attackArgs = @('learn-duration', (Join-Path $buildRoot 'repeated-context.pcp'), (Join-Path $buildRoot 'repeated.wav'), (Join-Path $buildRoot 'repeated-onsets.json'), '1000', (Join-Path $buildRoot "repeated-$attackPolicy.pys"), '0', '--monophonic')
      if ($attackPolicy -eq 'articulated') { $attackArgs += '--articulate-onsets' }
      & (Join-Path $buildRoot "pythian.style$executableSuffix") @attackArgs
      if ($LASTEXITCODE -ne 0) { throw 'Repeated-attack style learning failed' }
    }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'repeated-articulated.pys') (Join-Path $buildRoot 'local-duration.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'repeated-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Articulated duration blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'repeated-blend.pys') (Join-Path $buildRoot 'repeated-articulated.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'repeated-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Articulated duration second blend failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'repeated-plain.wav') '--style' (Join-Path $buildRoot 'repeated-plain.pys') '--duration-spans' '1' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Single sustained performance audition failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'repeated-articulated.wav') '--style' (Join-Path $buildRoot 'repeated-articulated.pys') '--duration-spans' '8' '--duration-lock' '7:464' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Rearticulated performance audition failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'repeated-reblend.wav') '--style' (Join-Path $buildRoot 'repeated-reblend.pys') '--duration-spans' '16' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Rearticulated second-blend audition failed' }
    foreach ($attackPolicy in @('plain', 'articulated', 'reblend')) {
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot "repeated-$attackPolicy.pys") (Join-Path $buildRoot "repeated-$attackPolicy.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Rearticulated actual voice/audio/MIDI checks failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-articulation' (Join-Path $buildRoot 'repeated-plain.pys') (Join-Path $buildRoot 'repeated-articulated.pys') (Join-Path $buildRoot 'repeated-reblend.pys') (Join-Path $buildRoot 'repeated-plain.wav') (Join-Path $buildRoot 'repeated-articulated.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved articulation policy/lineage and controlled audio comparison failed' }
    # Tempo provider cells advance independently, including inside sounding spans.
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-duration-reblend.pys') (Join-Path $buildRoot 'local-duration.pys') '0' '1' '1' '0' (Join-Path $buildRoot 'duration-changing-context.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Changing output context selection failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'duration-changing-context.wav') '--style' (Join-Path $buildRoot 'duration-changing-context.pys') '--duration-spans' '32' '--duration-tempo-cells' '32' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Independent duration/tempo scope generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot 'duration-changing-context.pys') (Join-Path $buildRoot 'duration-changing-context.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Independent duration/tempo scope verification failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'duration-tempo-edit.wav') '--style' (Join-Path $buildRoot 'duration-changing-context.pys') '--duration-spans' '32' '--duration-tempo-cells' '32' '--duration-tempo-lock' '3:600000' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Selective tempo provider edit failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-timed-voices' (Join-Path $buildRoot 'duration-changing-context.pys') (Join-Path $buildRoot 'duration-tempo-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Tempo change inside sounding span verification failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-tempo-edit' (Join-Path $buildRoot 'duration-changing-context.wav') (Join-Path $buildRoot 'duration-tempo-edit.wav') '3:600000'
    if ($LASTEXITCODE -ne 0) { throw 'Selective tempo edit state preservation failed' }
    # Local tonal evidence feeds changing keys through saved styles and second blends.
    & (Join-Path $buildRoot "pythian.tests.context.admission$executableSuffix") 'local-keys' (Join-Path $buildRoot 'local-key-source.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Local tonal source/region checks failed' }
    $localKeyHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'local-key-source.wav') -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit-key-regions' (Join-Path $buildRoot 'local-key-source.wav') $localKeyHash '500000' '0:0:major,16:2:minor' (Join-Path $buildRoot 'local-key-context')
    if ($LASTEXITCODE -ne 0) { throw 'Measured local key context admission failed' }
    & (Join-Path $buildRoot "pythian.tests.context.profile$executableSuffix") 'local-keys' (Join-Path $buildRoot 'local-key-context') (Join-Path $buildRoot 'local-key-source.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved local key source/report/model binding failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'local-key-source.wav') (Join-Path $buildRoot 'local-key-onsets.json') '512' '64'
    if ($LASTEXITCODE -ne 0) { throw 'Local key source onsets failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot 'local-key-context.pcp') (Join-Path $buildRoot 'local-key-source.wav') (Join-Path $buildRoot 'local-key-onsets.json') '1000' (Join-Path $buildRoot 'local-key-style.pys') '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Local key duration style learning failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-key-style.pys') (Join-Path $buildRoot 'local-duration.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'local-key-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Local key style blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'local-key-blend.pys') (Join-Path $buildRoot 'local-key-style.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'local-key-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Local key second style blend failed' }
    foreach ($localKeyVariant in @('baseline', 'edit')) {
      $localKeyArgs = @((Join-Path $buildRoot "local-key-$localKeyVariant.wav"), '--style', (Join-Path $buildRoot 'local-key-reblend.pys'), '--duration-spans', '32', '--duration-key-cells', '32')
      if ($localKeyVariant -eq 'edit') { $localKeyArgs += @('--duration-key-lock', '3:2:minor') }
      $localKeyArgs += '--verify'
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") @localKeyArgs
      if ($LASTEXITCODE -ne 0) { throw 'Local key voice generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot 'local-key-reblend.pys') (Join-Path $buildRoot "local-key-$localKeyVariant.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Local key audio/MIDI checks failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-key-edit' (Join-Path $buildRoot 'local-key-baseline.wav') (Join-Path $buildRoot 'local-key-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Local key edit preservation failed' }
    # Independently generated keys map new accompaniment attacks; existing notes hold pitch.
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'modulation-source' (Join-Path $buildRoot 'local-duration.pys') (Join-Path $buildRoot 'duration-key-source.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Authored modulation provider failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'duration-changing-context.pys') (Join-Path $buildRoot 'duration-key-source.pys') '1' '0' '1' '0' (Join-Path $buildRoot 'duration-changing-key.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent saved key selection failed' }
    foreach ($keyVariant in @(@('duration-key-baseline', '8:0:major'), @('duration-key-edit', '3:2:minor'))) {
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot ($keyVariant[0] + '.wav')) '--style' (Join-Path $buildRoot 'duration-changing-key.pys') '--duration-spans' '32' '--duration-tempo-cells' '32' '--duration-key-cells' '32' '--duration-key-lock' $keyVariant[1] '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Independent key scope realization failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot 'duration-changing-key.pys') (Join-Path $buildRoot ($keyVariant[0] + '.wav'))
      if ($LASTEXITCODE -ne 0) { throw 'Changing-key audio/MIDI verification failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-key-edit' (Join-Path $buildRoot 'duration-key-baseline.wav') (Join-Path $buildRoot 'duration-key-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Selective key mapping and held-note preservation failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'duration-key-tempo-edit.wav') '--style' (Join-Path $buildRoot 'duration-changing-key.pys') '--duration-spans' '32' '--duration-tempo-cells' '32' '--duration-key-cells' '32' '--duration-key-lock' '3:2:minor' '--duration-tempo-lock' '3:600000' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Combined independent context edit failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-timed-voices' (Join-Path $buildRoot 'duration-changing-key.pys') (Join-Path $buildRoot 'duration-key-tempo-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Combined context gates/timing verification failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-tempo-edit' (Join-Path $buildRoot 'duration-key-edit.wav') (Join-Path $buildRoot 'duration-key-tempo-edit.wav') '3:600000'
    if ($LASTEXITCODE -ne 0) { throw 'Tempo edit changed independent changing-key states' }
    & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'duration-cycle-voice.wav') '--cycle' (Join-Path $buildRoot 'cycle-source.wav') '7' '97' '1' '5' '--midi' (Join-Path $buildRoot 'duration-key-tempo-edit.wav.mid')
    if ($LASTEXITCODE -ne 0) { throw 'Measured cycle audition of generated performance failed' }
    & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'duration-cycle-morph.wav') '--morph-cycle' (Join-Path $buildRoot 'cycle-source.wav') '7' '97' '1' '5' (Join-Path $buildRoot 'cycle-source.wav') '7' '97' '1' '1' '4800' '--midi' (Join-Path $buildRoot 'duration-key-tempo-edit.wav.mid')
    if ($LASTEXITCODE -ne 0) { throw 'Measured cycle morph of generated performance failed' }
    & (Join-Path $buildRoot "pythian.sources.demo$executableSuffix") (Join-Path $buildRoot 'duration-harmonic-voice.wav') '--harmonics' (Join-Path $buildRoot 'harmonic-source.wav') '7' '1499' '1' '5' 'auto' '0.05' '--midi' (Join-Path $buildRoot 'duration-key-tempo-edit.wav.mid')
    if ($LASTEXITCODE -ne 0) { throw 'Measured harmonic fit audition of generated performance failed' }
    foreach ($timbreCase in @(@('local-duration', 'local-pitch'), @('phase-source-duration', 'phase-source'))) {
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-timbre' (Join-Path $buildRoot ($timbreCase[0] + '.pys')) (Join-Path $buildRoot ($timbreCase[1] + '.wav')) '1000' '512' '0' '5' 'auto:880' '0.25' (Join-Path $buildRoot ($timbreCase[0] + '-timbre.pys'))
      if ($LASTEXITCODE -ne 0) { throw 'Saved controlled harmonic evidence failed' }
    }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-layers' (Join-Path $buildRoot 'local-duration-timbre.pys') (Join-Path $buildRoot 'phase-source-duration-timbre.pys') '0' '0' '1' '0' '1' '0' '1' '1' (Join-Path $buildRoot 'timbre-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent timbre blend failed' }
    foreach ($timbreVariant in @('reblend', 'edit')) {
      $timbreLeftWeight = if ($timbreVariant -eq 'reblend') { '1' } else { '0' }
      $timbreStyle = Join-Path $buildRoot ("timbre-$timbreVariant.pys")
      $timbreOutput = Join-Path $buildRoot ("timbre-$timbreVariant.wav")
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-layers' (Join-Path $buildRoot 'timbre-blend.pys') (Join-Path $buildRoot 'local-duration-timbre.pys') '0' '0' '1' '0' '1' '0' $timbreLeftWeight '1' $timbreStyle
      if ($LASTEXITCODE -ne 0) { throw 'Saved timbre second derivation failed' }
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") $timbreOutput '--style' $timbreStyle '--duration-spans' '32' '--duration-tempo-cells' '32' '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Saved timbre voice generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'timbre-voices' $timbreStyle $timbreOutput
      if ($LASTEXITCODE -ne 0) { throw 'Saved timbre native audio/MIDI reconstruction failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'timbre-controls' (Join-Path $buildRoot 'timbre-reblend.wav') (Join-Path $buildRoot 'timbre-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Timbre selection changed independent musical state' }
    $keyOutput = Join-Path $buildRoot 'duration-key-edit.wav'
    $keyBefore = @{}
    foreach ($suffix in @('', '.json', '.mid', '.preview.wav')) {
      $keyBefore[$suffix] = (Get-FileHash -LiteralPath ($keyOutput + $suffix) -Algorithm SHA256).Hash
    }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") $keyOutput '--style' (Join-Path $buildRoot 'duration-changing-key.pys') '--duration-spans' '32' '--duration-tempo-cells' '32' '--duration-key-cells' '4' '--verify' 2> (Join-Path $buildRoot 'duration-key-scope-rejection.log')
    if ($LASTEXITCODE -eq 0) { throw 'Insufficient finite key scope was accepted' }
    foreach ($suffix in @('', '.json', '.mid', '.preview.wav')) {
      if ((Get-FileHash -LiteralPath ($keyOutput + $suffix) -Algorithm SHA256).Hash -ne $keyBefore[$suffix]) {
        throw 'Rejected key scope changed accepted output'
      }
    }
    $timedOutput = Join-Path $buildRoot 'duration-tempo-edit.wav'
    $timedBefore = @{}
    foreach ($suffix in @('', '.json', '.mid', '.preview.wav')) {
      $timedBefore[$suffix] = (Get-FileHash -LiteralPath ($timedOutput + $suffix) -Algorithm SHA256).Hash
    }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") $timedOutput '--style' (Join-Path $buildRoot 'duration-changing-context.pys') '--duration-spans' '32' '--duration-tempo-cells' '4' '--verify' 2> (Join-Path $buildRoot 'duration-tempo-scope-rejection.log')
    if ($LASTEXITCODE -eq 0) { throw 'Insufficient finite tempo scope was accepted' }
    foreach ($suffix in @('', '.json', '.mid', '.preview.wav')) {
      if ((Get-FileHash -LiteralPath ($timedOutput + $suffix) -Algorithm SHA256).Hash -ne $timedBefore[$suffix]) {
        throw 'Rejected tempo scope changed accepted output'
      }
    }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-dynamics' (Join-Path $buildRoot 'key-admission.pcp') $admissionSource (Join-Path $buildRoot 'style-onsets.json') '400' (Join-Path $buildRoot 'dynamic-style.pys') 'Authored native C-major sine fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Measured WAV dynamics learning failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'voices-dynamics.wav') '--style' (Join-Path $buildRoot 'dynamic-style.pys') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Measured WAV dynamics realization failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'dynamic-style.pys') (Join-Path $buildRoot 'voices-dynamics.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Measured WAV dynamics output checks failed' }
    # Derived spectral components enter the same saved style and actual WFC path.
    $separatedWave = Join-Path $buildRoot 'separated-percussive.wav'
    $separatedHash = (Get-FileHash -LiteralPath $separatedWave -Algorithm SHA256).Hash.ToLowerInvariant()
    $separationReportHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'separated.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $separationSourceHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'separation-control-source.wav') -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' $separatedWave $separatedHash '500000' '-1' 'major' (Join-Path $buildRoot 'separated-context')
    if ($LASTEXITCODE -ne 0) { throw 'Separated context admission failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") $separatedWave (Join-Path $buildRoot 'separated-onsets.json') '512' '64'
    if ($LASTEXITCODE -ne 0) { throw 'Separated onset measurement failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-dynamics' (Join-Path $buildRoot 'separated-context.pcp') $separatedWave (Join-Path $buildRoot 'separated-onsets.json') '1000' (Join-Path $buildRoot 'separated-style.pys') "Native controlled percussive component; separation_report_sha256=$separationReportHash; original_source_sha256=$separationSourceHash"
    if ($LASTEXITCODE -ne 0) { throw 'Separated dynamics style learning failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'dynamic-style.pys') (Join-Path $buildRoot 'separated-style.pys') '0' '1' '0' '1' (Join-Path $buildRoot 'separated-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Separated style selection failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'separated-blend.pys') (Join-Path $buildRoot 'dynamic-style.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'separated-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Separated style second derivation failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'voices-separated.wav') '--style' (Join-Path $buildRoot 'separated-reblend.pys') '--style-extent' 'prefix' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Separated style voice generation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'separated-reblend.pys') (Join-Path $buildRoot 'voices-separated.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Separated style voice/model validation failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.pitch.wfc.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Pitch learner fixture compilation failed' }
    & $compilerPath @adapterArgs 'tools/pythian.pitch.wav.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Pitch WAV operator compilation failed' }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'learn' (Join-Path $buildRoot 'pitch-source.wav') (Join-Path $buildRoot 'pitch-learned') '500000' '0' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'WAV pitch learning failed' }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate' (Join-Path $buildRoot 'pitch-learned.model.txt') (Join-Path $buildRoot 'pitch-generated.wav') '500000'
    if ($LASTEXITCODE -ne 0) { throw 'Saved pitch model generation failed' }
    & (Join-Path $buildRoot "pythian.tests.pitch.wfc$executableSuffix") (Join-Path $buildRoot 'pitch-source.wav') (Join-Path $buildRoot 'pitch-learned') (Join-Path $buildRoot 'pitch-generated.wav')
    if ($LASTEXITCODE -ne 0) { throw 'WAV pitch output checks failed' }
    # Dense monophonic duration learning with explicit silence and unknown spans.
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'learn-runs' (Join-Path $buildRoot 'run-source.wav') (Join-Path $buildRoot 'run-learned') '1' '--monophonic'
    if ($LASTEXITCODE -ne 0) { throw 'Dense pitch duration learning failed' }
    foreach ($durationQuantum in @('10', '20')) {
      $durationOutput = Join-Path $buildRoot "run-generated-$durationQuantum.wav"
      & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-runs' (Join-Path $buildRoot 'run-learned.model.txt') $durationOutput $durationQuantum
      if ($LASTEXITCODE -ne 0) { throw 'Measured duration generation failed' }
      & (Join-Path $buildRoot "pythian.tests.pitch.wfc$executableSuffix") 'runs' (Join-Path $buildRoot 'run-source.wav') (Join-Path $buildRoot 'run-learned') $durationOutput
      if ($LASTEXITCODE -ne 0) { throw 'Measured duration/audio checks failed' }
    }
    # Saved measured pitch styles, repeated blending and selective melody control.
    foreach ($pitchSourceName in @('pitch-source', 'pitch-octave')) {
      $pitchSourcePath = Join-Path $buildRoot "$pitchSourceName.wav"
      $pitchSourceHash = (Get-FileHash -LiteralPath $pitchSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
      & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' $pitchSourcePath $pitchSourceHash '500000' '0' 'major' (Join-Path $buildRoot "$pitchSourceName-context")
      if ($LASTEXITCODE -ne 0) { throw 'Pitch style context admission failed' }
      & (Join-Path $buildRoot "pythian.onsets$executableSuffix") $pitchSourcePath (Join-Path $buildRoot "$pitchSourceName-onsets.json") '512' '64'
      if ($LASTEXITCODE -ne 0) { throw 'Pitch style onset measurement failed' }
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-pitch' (Join-Path $buildRoot "$pitchSourceName-context.pcp") $pitchSourcePath (Join-Path $buildRoot "$pitchSourceName-onsets.json") '400' (Join-Path $buildRoot "$pitchSourceName.pys") '0' '--monophonic' 'Native authored monophonic ground truth'
      if ($LASTEXITCODE -ne 0) { throw 'Measured pitch style learning failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'grid-api' (Join-Path $buildRoot 'pitch-source.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Reusable saved grid API checks failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'pitch-source.pys') (Join-Path $buildRoot 'pitch-octave.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'pitch-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style blending failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'pitch-blend.pys') (Join-Path $buildRoot 'pitch-source.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'pitch-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style second derivation failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'inspect' (Join-Path $buildRoot 'pitch-reblend.pys') (Join-Path $buildRoot 'pitch-reblend.json')
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style inspection failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'pitch-style' (Join-Path $buildRoot 'pitch-source.pys') (Join-Path $buildRoot 'pitch-octave.pys') (Join-Path $buildRoot 'pitch-blend.pys') (Join-Path $buildRoot 'pitch-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style archive checks failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'pitch-style.wav') '--style' (Join-Path $buildRoot 'pitch-reblend.pys') '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style voice render failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'pitch-style-edit.wav') '--style' (Join-Path $buildRoot 'pitch-reblend.pys') '--pitch-lock' '1:72' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style selective edit failed' }
    foreach ($pitchRenderName in @('pitch-style', 'pitch-style-edit')) {
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'pitch-reblend.pys') (Join-Path $buildRoot "$pitchRenderName.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Pitch style realized melody check failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'pitch-controls' (Join-Path $buildRoot 'pitch-style.wav') (Join-Path $buildRoot 'pitch-style-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Pitch style independent control check failed' }
    # Observed pitch/onset/intensity provider and coupled selective regeneration.
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'coupled.wav') '--style' (Join-Path $buildRoot 'pitch-source.pys') '--coupled-pitch' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Coupled pitch style render failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'coupled-edit.wav') '--style' (Join-Path $buildRoot 'pitch-source.pys') '--coupled-pitch' '--pitch-lock' '0:62' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Coupled pitch style edit failed' }
    foreach ($coupledRenderName in @('coupled', 'coupled-edit')) {
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'pitch-source.pys') (Join-Path $buildRoot "$coupledRenderName.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Coupled measured state/output binding failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'coupled-controls' (Join-Path $buildRoot 'coupled.wav') (Join-Path $buildRoot 'coupled-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Coupled pitch selective closure failed' }
    & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot 'coupled-reblend.wav') '--style' (Join-Path $buildRoot 'pitch-reblend.pys') '--coupled-pitch' '--pitch-lock' '0:62' '--verify'
    if ($LASTEXITCODE -ne 0) { throw 'Coupled repeated blend render failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot 'pitch-reblend.pys') (Join-Path $buildRoot 'coupled-reblend.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Coupled repeated blend output check failed' }
    # Independent rhythm/intensity and pitch source selection, then another blend.
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-dimensions' (Join-Path $buildRoot 'dynamic-style.pys') (Join-Path $buildRoot 'pitch-octave.pys') '0' '0' '1' '0' '0' '1' (Join-Path $buildRoot 'dimension-high.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent high pitch selection failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-dimensions' (Join-Path $buildRoot 'dynamic-style.pys') (Join-Path $buildRoot 'pitch-source.pys') '0' '0' '1' '0' '0' '1' (Join-Path $buildRoot 'dimension-low.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent low pitch selection failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-dimensions' (Join-Path $buildRoot 'dimension-high.pys') (Join-Path $buildRoot 'pitch-source.pys') '0' '0' '1' '0' '1' '2' (Join-Path $buildRoot 'dimension-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent dimension second derivation failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'inspect' (Join-Path $buildRoot 'dimension-reblend.pys') (Join-Path $buildRoot 'dimension-reblend.json')
    if ($LASTEXITCODE -ne 0) { throw 'Independent dimension inspection failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'dimensions' (Join-Path $buildRoot 'dynamic-style.pys') (Join-Path $buildRoot 'pitch-source.pys') (Join-Path $buildRoot 'pitch-octave.pys') (Join-Path $buildRoot 'dimension-high.pys') (Join-Path $buildRoot 'dimension-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent dimension archive checks failed' }
    foreach ($dimensionRenderName in @('dimension-high','dimension-low','dimension-reblend')) {
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot "$dimensionRenderName.wav") '--style' (Join-Path $buildRoot "$dimensionRenderName.pys") '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Independent dimension voice generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'output' (Join-Path $buildRoot "$dimensionRenderName.pys") (Join-Path $buildRoot "$dimensionRenderName.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Independent dimension realized output check failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'dimension-controls' (Join-Path $buildRoot 'dimension-high.wav') (Join-Path $buildRoot 'dimension-low.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Independent dimension control preservation check failed' }
    # Saved duration styles, repeated blending, selective edits and independent tempo.
    foreach ($durationSource in @('run-source', 'pitch-octave')) {
      $durationHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot "$durationSource.wav") -Algorithm SHA256).Hash.ToLowerInvariant()
      & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' (Join-Path $buildRoot "$durationSource.wav") $durationHash '500000' '0' 'major' (Join-Path $buildRoot "$durationSource-duration-context")
      if ($LASTEXITCODE -ne 0) { throw 'Duration source context failed' }
      & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot "$durationSource.wav") (Join-Path $buildRoot "$durationSource-duration-onsets.json") '512' '64'
      if ($LASTEXITCODE -ne 0) { throw 'Duration source onset measurement failed' }
      $durationChannel = if ($durationSource -eq 'run-source') { '1' } else { '0' }
      & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot "$durationSource-duration-context.pcp") (Join-Path $buildRoot "$durationSource.wav") (Join-Path $buildRoot "$durationSource-duration-onsets.json") '1000' (Join-Path $buildRoot "$durationSource-duration.pys") $durationChannel '--monophonic' 'Native monophonic duration performance'
      if ($LASTEXITCODE -ne 0) { throw 'Saved duration learning failed' }
    }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'run-source-duration.pys') (Join-Path $buildRoot 'pitch-octave-duration.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'duration-blend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Duration style blend failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend' (Join-Path $buildRoot 'duration-blend.pys') (Join-Path $buildRoot 'run-source-duration.pys') '0' '0' '1' '1' (Join-Path $buildRoot 'duration-reblend.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Duration style second derivation failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'inspect' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-reblend.json')
    if ($LASTEXITCODE -ne 0) { throw 'Duration style inspection failed' }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-style-runs' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-reblend.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Duration style generation failed' }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-style-runs' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-edit.wav') '--duration-lock' '0:384'
    if ($LASTEXITCODE -ne 0) { throw 'Duration style selective edit failed' }
    $durationHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'run-source.wav') -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $buildRoot "pythian.context.wav$executableSuffix") 'admit' (Join-Path $buildRoot 'run-source.wav') $durationHash '750000' '0' 'major' (Join-Path $buildRoot 'duration-slow-context')
    if ($LASTEXITCODE -ne 0) { throw 'Alternate duration tempo context failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'learn-duration' (Join-Path $buildRoot 'duration-slow-context.pcp') (Join-Path $buildRoot 'run-source.wav') (Join-Path $buildRoot 'run-source-duration-onsets.json') '1000' (Join-Path $buildRoot 'duration-slow-source.pys') '1' '--monophonic' 'Native duration performance with alternate declared clock'
    if ($LASTEXITCODE -ne 0) { throw 'Alternate duration source failed' }
    & (Join-Path $buildRoot "pythian.style$executableSuffix") 'blend-dimensions' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-slow-source.pys') '0' '1' '1' '0' '1' '0' (Join-Path $buildRoot 'duration-slow.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Independent duration tempo selection failed' }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-style-runs' (Join-Path $buildRoot 'duration-slow.pys') (Join-Path $buildRoot 'duration-slow.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Independent duration tempo render failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-style' (Join-Path $buildRoot 'run-source-duration.pys') (Join-Path $buildRoot 'pitch-octave-duration.pys') (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-slow.pys')
    if ($LASTEXITCODE -ne 0) { throw 'Saved duration model/lineage checks failed' }
    foreach ($durationRender in @('duration-reblend', 'duration-edit', 'duration-slow')) {
      $durationStyle = if ($durationRender -eq 'duration-slow') { 'duration-slow' } else { 'duration-reblend' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-output' (Join-Path $buildRoot "$durationStyle.pys") (Join-Path $buildRoot "$durationRender.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Saved duration output binding failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-controls' (Join-Path $buildRoot 'duration-reblend.wav') (Join-Path $buildRoot 'duration-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Duration edit preservation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-tempo-controls' (Join-Path $buildRoot 'duration-reblend.wav') (Join-Path $buildRoot 'duration-slow.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Duration tempo independence failed' }
    # Explicit single-state context holds with independently sized performance.
    foreach ($heldRender in @('duration-held', 'duration-held-slow')) {
      $heldStyle = if ($heldRender -eq 'duration-held-slow') { 'duration-slow' } else { 'duration-reblend' }
      & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-style-runs' (Join-Path $buildRoot "$heldStyle.pys") (Join-Path $buildRoot "$heldRender.wav") '--context' 'hold'
      if ($LASTEXITCODE -ne 0) { throw 'Held context generation failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-output' (Join-Path $buildRoot "$heldStyle.pys") (Join-Path $buildRoot "$heldRender.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Held context output check failed' }
    }
    & (Join-Path $buildRoot "pythian.pitch.wav$executableSuffix") 'generate-style-runs' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-held-edit.wav') '--context' 'hold' '--duration-lock' '0:384'
    if ($LASTEXITCODE -ne 0) { throw 'Held context duration edit failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-output' (Join-Path $buildRoot 'duration-reblend.pys') (Join-Path $buildRoot 'duration-held-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Held context edited output check failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-controls' (Join-Path $buildRoot 'duration-held.wav') (Join-Path $buildRoot 'duration-held-edit.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Held context edit preservation failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-tempo-controls' (Join-Path $buildRoot 'duration-held.wav') (Join-Path $buildRoot 'duration-held-slow.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Held context tempo independence failed' }
    # Measured performance durations drive dependent bass, chord and melody gates.
    foreach ($voiceRender in @('duration-voices', 'duration-voices-slow')) {
      $voiceStyle = if ($voiceRender -eq 'duration-voices-slow') { 'duration-slow' } else { 'duration-reblend' }
      & (Join-Path $buildRoot "pythian.voices.demo$executableSuffix") (Join-Path $buildRoot "$voiceRender.wav") '--style' (Join-Path $buildRoot "$voiceStyle.pys") '--duration-spans' '8' '--verify'
      if ($LASTEXITCODE -ne 0) { throw 'Duration-driven voices failed' }
      & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voices' (Join-Path $buildRoot "$voiceStyle.pys") (Join-Path $buildRoot "$voiceRender.wav")
      if ($LASTEXITCODE -ne 0) { throw 'Duration-driven voice output check failed' }
    }
    & (Join-Path $buildRoot "pythian.tests.wave.style$executableSuffix") 'duration-voice-tempo' (Join-Path $buildRoot 'duration-voices.wav') (Join-Path $buildRoot 'duration-voices-slow.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Duration-driven voice tempo independence failed' }
    & $compilerPath @adapterArgs '-dWFC_CLOCK_CHECKS' 'tests/pythian.tests.clock.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC ensemble clock compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.clock$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC ensemble clock parity failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.corpus.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC corpus compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.corpus$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC corpus checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.learning.journal.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Journal learning compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.learning.journal$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Journal learning checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.learning.profile.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Journal profile compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.learning.profile$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Journal profile checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.activity.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC activity compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.activity$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC activity and continuity checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.joint.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Joint WFC compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.joint$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Joint WFC checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.joint.archive.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Joint archive compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.joint.archive$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Joint archive checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.wfc.timing.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Timed WFC compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.wfc.timing$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Timed WFC checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.timed.remix.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Timed remix compilation failed' }
    & $compilerPath @adapterArgs 'tools/pythian.passage.remix.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Passage remix compilation failed' }
    & $compilerPath @adapterArgs '-dWFC_EVENT_CHECKS' 'tests/pythian.tests.events.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC event compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.events$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC event checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.event.corpus.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Recorded event corpus compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.event.corpus$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Recorded event corpus checks failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.event.archive.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Recorded event archive compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.event.archive$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'Recorded event archive checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.event.merge.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Event merge compilation failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.event.merge.output.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Event merge output checker compilation failed' }
    & $compilerPath @adapterArgs '-dWFC_EVENT_CHECKS' 'tests/pythian.tests.pulse.events.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC pulse event compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.pulse.events$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC pulse event checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.event.remix.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Event remix compilation failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.events.output.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Published event checker compilation failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.passage.output.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Published passage checker compilation failed' }
    & $compilerPath @adapterArgs 'tests/pythian.tests.learning.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WFC learning compilation failed' }
    & (Join-Path $buildRoot "pythian.tests.learning$executableSuffix")
    if ($LASTEXITCODE -ne 0) { throw 'WFC learning checks failed' }
    & $compilerPath @adapterArgs 'tools/pythian.learn.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV learner compilation failed' }
    & (Join-Path $buildRoot "pythian.learn$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'synthesis-model')
    if ($LASTEXITCODE -ne 0) { throw 'WAV learner smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.wave.read$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'extensible')
    if ($LASTEXITCODE -ne 0) { throw 'Extensible WAV source fixtures failed' }
    $referenceModelHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot 'synthesis-model.wfcs') -Algorithm SHA256).Hash
    foreach ($encoding in 0..3) {
      $extendedWave = Join-Path $buildRoot "extensible-$encoding.wav"
      & (Join-Path $buildRoot "pythian.tests.analysis.wave$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') $extendedWave
      if ($LASTEXITCODE -ne 0) { throw 'Extensible WAV analysis parity failed' }
      & (Join-Path $buildRoot "pythian.learn$executableSuffix") $extendedWave (Join-Path $buildRoot "extensible-model-$encoding")
      if ($LASTEXITCODE -ne 0) { throw 'Extensible WAV learning failed' }
      $extendedModelHash = (Get-FileHash -LiteralPath (Join-Path $buildRoot "extensible-model-$encoding.wfcs") -Algorithm SHA256).Hash
      if ($extendedModelHash -ne $referenceModelHash) { throw 'Extensible WAV changed the learned model' }
    }
    & $compilerPath @adapterArgs 'tools/pythian.remix.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV remix compilation failed' }
    & (Join-Path $buildRoot "pythian.remix$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'remix.wav') '731' '256'
    if ($LASTEXITCODE -ne 0) { throw 'WAV remix smoke failed' }
    & $compilerPath @adapterArgs 'tools/pythian.inspect.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'WAV inspection compilation failed' }
    & $compilerPath @adapterArgs 'tools/pythian.archive.lpr'
    if ($LASTEXITCODE -ne 0) { throw 'Archive tool compilation failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'learn' (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Archive training smoke failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'events-onsets.json')
    if ($LASTEXITCODE -ne 0) { throw 'Event source inspection failed' }
    & (Join-Path $buildRoot "pythian.event.remix$executableSuffix") (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'events-onsets.json') (Join-Path $buildRoot 'events.wav') '731' '16'
    if ($LASTEXITCODE -ne 0) { throw 'Event remix smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.events.output$executableSuffix") (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'events-onsets.json') (Join-Path $buildRoot 'events.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Published event smoke failed' }
    & (Join-Path $buildRoot "pythian.event.merge$executableSuffix") (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'events-merged.wav') '731' '16' (Join-Path $buildRoot 'synthesis.wav') (Join-Path $buildRoot 'events-onsets.json')
    if ($LASTEXITCODE -ne 0) { throw 'Shared event operator smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.event.merge.output$executableSuffix") (Join-Path $buildRoot 'events-merged.wav') (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Shared event output smoke failed' }
    & (Join-Path $buildRoot "pythian.event.merge$executableSuffix") '--load' (Join-Path $buildRoot 'events-merged.wav.pyac') (Join-Path $buildRoot 'events-loaded.wav') '731' '16' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved event operator smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.event.merge.output$executableSuffix") (Join-Path $buildRoot 'events-loaded.wav') (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved event output smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'learn' (Join-Path $buildRoot 'pulse-demo.pyac') (Join-Path $buildRoot 'beat-lab-tempo-change.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Pulse smoke archive failed' }
    & (Join-Path $buildRoot "pythian.onsets$executableSuffix") (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'pulse-onsets.json')
    if ($LASTEXITCODE -ne 0) { throw 'Pulse smoke onset report failed' }
    & (Join-Path $buildRoot "pythian.event.remix$executableSuffix") (Join-Path $buildRoot 'pulse-demo.pyac') (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'pulse-onsets.json') (Join-Path $buildRoot 'pulse-events.wav') '731' '16' '--pulses'
    if ($LASTEXITCODE -ne 0) { throw 'Pulse remix smoke failed' }
    & (Join-Path $buildRoot "pythian.tests.events.output$executableSuffix") (Join-Path $buildRoot 'pulse-demo.pyac') (Join-Path $buildRoot 'beat-lab-tempo-change.wav') (Join-Path $buildRoot 'pulse-onsets.json') (Join-Path $buildRoot 'pulse-events.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Published pulse smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'remix' (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'demo-archive-remix.wav') '731' '256' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Archive loading/reconstruction smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'remix-continuous' (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'demo-continuous.wav') '731' '256' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Continuity reconstruction smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'remix-joint' (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'demo-joint.wav') '731' '256' 'a???h' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Joint acoustic/activity reconstruction smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'prepare-joint' (Join-Path $buildRoot 'demo.pyac') (Join-Path $buildRoot 'demo-paired.pyac')
    if ($LASTEXITCODE -ne 0) { throw 'Joint model saving smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'inspect-joint' (Join-Path $buildRoot 'demo-paired.pyac') > (Join-Path $buildRoot 'demo-paired.json')
    if ($LASTEXITCODE -ne 0) { throw 'Joint model loading smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'remix-saved-joint' (Join-Path $buildRoot 'demo-paired.pyac') (Join-Path $buildRoot 'demo-saved-joint.wav') '731' '256' 'a???h' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Saved joint reconstruction smoke failed' }
    & (Join-Path $buildRoot "pythian.timed.remix$executableSuffix") (Join-Path $buildRoot 'demo-paired.pyac') (Join-Path $buildRoot 'demo-timed-grid.wav') '731' 'grid' '500000' '240' 'ahrr' '512' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Timed grid remix smoke failed' }
    & (Join-Path $buildRoot "pythian.timed.remix$executableSuffix") (Join-Path $buildRoot 'demo-paired.pyac') (Join-Path $buildRoot 'demo-timed-midi.wav') '731' 'midi' (Join-Path $buildRoot 'timing.mid') '512' (Join-Path $buildRoot 'synthesis.wav')
    if ($LASTEXITCODE -ne 0) { throw 'Timed MIDI remix smoke failed' }
    & (Join-Path $buildRoot "pythian.archive$executableSuffix") 'segments' (Join-Path $buildRoot 'demo.pyac') > (Join-Path $buildRoot 'demo-segments.json')
    if ($LASTEXITCODE -ne 0) { throw 'Activity segmentation smoke failed' }
  }
} finally {
  Pop-Location
}
