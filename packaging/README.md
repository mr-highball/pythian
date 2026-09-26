# Pythian source package

This is a development snapshot of the reusable Pascal audio library. It includes
owned source, full license notices and small consumer examples. It is not an
installed compiler, a precompiled library or a tagged release.

Use native FPC with the standard RTL/FCL. Compile from this directory, after
creating separate `build/units` and `build/bin` output directories:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.core.lpr
build/bin/pythian.example.core core.wav
```

On Windows the executable has the `.exe` suffix. Quote paths containing spaces.
The core example renders a short phrase and checks its WAV round trip. Library
units have no WFC, Phanes, engine, browser or playback-device dependency.

The shared WAV reader accepts ordinary and extensible RIFF/RF64 PCM8/16/24/32
and float32, within the mono/stereo contract. Extensible PCM retains explicit
valid-bit precision; unsupported speaker layouts or subtypes reject. Analysis,
loading and WFC examples use this same reader. Output remains canonical PCM16.

Beat measurement and context admission share native source analysis. Explicit
pulse selection can retain a quantized source origin; rhythm and pitch cells use
that origin, with uncertainty preserved separately from key/tempo decisions.
Current style evidence retains each source start tick through repeated blends.
Regenerate earlier development style files after schema changes; no historical
PYS reader is included.

`pythian.beat.clock` reconstructs continuous phase from caller-selected pulse
windows. Use `DefaultBeatClockOptions` and `ReconstructBeatClock`; choose linear
phase or an endpoint-constrained step where feasible. `SelectedBeatClockWindows`
in `pythian.beat.track` converts an existing explicit selection. Missing pulses
and path restarts break continuity; alignment also excludes rejected phase spans.
Raw/aligned points,
phase segments and observation indices stay visible. This is clock reconstruction,
not automatic tempo, musical-change or metrical admission. Calls are bounded to
512 windows, 1024 segments, 8192 observations and 65536 candidate crossings.

`AdmitBeatClockRange` in `pythian.music.context.admission` reconstructs selected
clock windows and admits an inclusive pulse range into the existing context grid.
The caller explicitly declares each interval one quarter; source offset and
cumulative rounding errors remain visible. Admission rejects missing spans,
restarts and unavailable/ambiguous phase intervals. The resulting grid can use
the existing WFC context profile and independent key/tempo providers; no new
saved format or automatic musical admission is implied.

Further native examples cover musical notes, forward MIDI transport and instruments:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.notes.lpr
build/bin/pythian.example.notes notes
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.midi.stream.lpr
build/bin/pythian.example.midi.stream streamed.mid
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.instrument.lpr
build/bin/pythian.example.instrument instrument.wav
```

The notes example creates two authored voices with a tempo change, exports
`notes.mid` on two explicit channels and renders `notes.wav`. Strict MIDI import
must reproduce the exact rendered WAV bytes before either output is written.
The MIDI stream example counts and replays an authored event source, draining
bounded blocks directly to its host-owned file. These examples write directly
to the requested paths; publication is not an atomic filesystem transaction.
The instrument example accepts `OUTPUT.wav [NOTES.mid]`. Without MIDI it renders
an authored bass/melody phrase; with MIDI it voices the decoded notes and tempo map.
Its bass and brighter layer use independent held/release envelope curves, while
the softer layer retains ADSR. Curves explicitly use 44100-Hz output frames.
The authored phrase renders through keyboard
zones and overlapping velocity ranges: 16 notes expand into 20 synthesis layers.

The processing example reads WAV blocks, applies stereo reverb through an effect
chain, writes PCM16 blocks with one second of explicit tail, then analyzes the
saved WAV and hashes both files using bounded input buffers:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -FUbuild/units -FEbuild/bin examples/pythian.example.processing.lpr
build/bin/pythian.example.processing core.wav processed.wav
```

It uses 257-frame blocks and no whole-clip storage. Mono is duplicated to stereo.
Existing sample and FFT budgets apply. The example rejects samples exceeding
PCM headroom instead of silently clipping; a late failure can leave partial
output. Reverb tail length and gains are explicit example policy.

Packages made with the WFC option also contain `adapters/wfc`, `vendor/wfc/src`,
the companion license/revision and a WAV-learning consumer. Use a separate unit
output directory for it:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src -FUbuild/wfc-units -FEbuild/bin examples/pythian.example.wfc.lpr
build/bin/pythian.example.wfc core.wav learned.wav
```

That consumer analyzes WAV features, learns through the actual WFC model and
reconstructs generated tokens from recorded grains. It demonstrates the integration
contract; it is not transcription or a musical-quality guarantee.

A second WFC example learns from two recordings, saves their event model and
generates from the reloaded archive. Use the two native example WAVs above:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src -FUbuild/wfc-units -FEbuild/bin examples/pythian.example.events.lpr
build/bin/pythian.example.events core.wav instrument.wav events
```

It uses eight explicit equal intervals per recording, without claiming onset or
beat detection. Each source remains an independent training run in one shared
event vocabulary. The example writes `events.pyac`, frees the original learning,
loads it from disk, verifies exact archive replay and generates `events.wav`
through the actual saved WFC model. Source audio stays external and is bound by
exact WAV hashes. This demonstrates reusable recorded-event learning, not a
complete musical-style profile. No maintained workspace tool or music asset is
required by either packaged consumer.

The WFC package also includes the maintained `pythian.learn` operator and its
three helper units. Compile it with the same core/companion source paths plus
`-Futools`; generated files stay outside the delivered sources:

```text
fpc -B -Sa -Cr -Co -Ci -gl -Fusrc -Futools -Fuadapters/wfc -Fuvendor/wfc/src -FUbuild/wfc-units -FEbuild/bin tools/pythian.learn.lpr
build/bin/pythian.learn cache core.wav core.pyaf --batch-features 7
build/bin/pythian.learn journals journal --range 0 24 core.wav core.pyaf --range 32 24 core.wav core.pyaf
build/bin/pythian.learn blend journal journal journal-blend 1 2
build/bin/pythian.learn blend journal-blend journal journal-derived 1 1
build/bin/pythian.learn fit journal-derived journal-fit.json 0.25 --range 0 24 core.wav core.pyaf --range 32 24 core.wav core.pyaf
build/bin/pythian.learn contexts journal-derived journal-contexts 8 core.pyaf core.pyaf
build/bin/pythian.learn replay journal-contexts journal-replay --context-grains 8 core.wav
```

This self-contained workflow uses the core example's authored 1.5-second WAV.
It verifies mechanics, not style quality. Cache batches preserve measured source
coordinates; range boundaries create separate WFC samples without copying audio.
`--range FIRST_FEATURE COUNT` applies only to the immediately following pair;
omitting it selects the whole journal. Ranges must be disjoint and within the
completed cache. Feature indices are zero-based Int64 values; each starts at
`index * HopFrames` in the original WAV. Selection does not crop analysis windows
or reset their measured predecessor context.

`journals --multiplicity N` weights subsequent training ranges; `--source-weight N`
independently controls generated contributions. Repeated blends add explicit
evidence weights and retain lineage; the example deliberately reuses the same
recording rather than introducing independent recordings. `--palette-from PREFIX`
trains new evidence in a compatible saved vocabulary. Fresh training accepts
`--max-tokens 1..32` (default 16), which cannot be combined with a frozen starter.
The fit limit above is an exploratory vector distance, not musical confidence.
Replay verifies one supplied WAV per distinct saved source hash, with no journal
reads or learning. The source JSON/model pair uses one current contract; old
development reports must be regenerated when that contract changes.

Library callers can use `pythian.learning.journal.SelectJournalPartition` before
constructing `TJournalTrainingReader`. Its in-memory plan borrows completed
journals and declares a case-sensitive recording-family `GroupId`, partition
(`jpTraining`, `jpDevelopment`, `jpEvaluation`), `GroupVerified` and
`PreviouslyUsed` per segment. The entire plan must share the reader's analysis
contract and limits. Unknown groups are development-only; previously used
evaluation, cross-partition families, conflicting identities for one exact hash
and overlapping source feature ranges reject. The selected descriptors are owned;
journals remain borrowed and their read cursors are untouched. Caller-verified
identity, derivative/parent-range audits and truthful exposure metadata are still
required.

The `journals` operator accepts `--partition training|development` immediately
after `OUTPUT_PREFIX`, then requires `--group ID SPLIT verified|unverified
unused|used` before every optional `--range` and WAV/cache pair. Group metadata
applies only to its next pair. All bindings/declarations validate before learning;
only selected observations feed palette/model/generation. Evaluation learning and
known evaluation-source hashes in a palette starter reject. The existing report's
`partition_selection` records the full invocation audit; ordinary profile sources
remain selected-only. There is no new manifest format or automatic identity audit.
Parent-range/derivative overlap and outside-plan palette ancestry remain caller
responsibilities. Saved blends/replays do not automatically propagate this audit.

The current core also includes optional spectral-band analysis, bounded source
resampling and PCM adaptation, measured envelopes and native harmonic fitting.
Pulse measurements retain metrical alternatives; ranked fit does not automatically
admit musical beat level. These library interfaces preserve explicit uncertainty,
ownership, work limits and source coordinates independently of the operator.

Keep unit output separate by compiler and target. Voice factories, curves and
returned objects have explicit ownership in the Pascal interfaces. The examples
show caller-owned results released with `try/finally`.

`pythian.music.grid.frames.TMusicGridFrames` maps an explicit tempo history,
physical source offset and finite PPQ scope to immutable sample boundaries.
Mapped rhythm and pitch-cell APIs share that geometry; constant-clock overloads
remain available. Current WFC styles retain source maps through repeated blends.
Regenerate superseded development styles instead of retaining historical readers.
Dense style durations normalize source intervals through their own clocks to PPQ ticks.

`pythian.wfc.performance.TStylePerformance` provides reusable saved-style key,
tempo and performance sessions, typed selective locks and captured native plans.
The definition copies its input style; sessions and plans own their data and may
outlive it. Finite context must cover the generated spans; unknown values remain
explicit. Host applications choose realization and file I/O. This companion API
uses the current style format without a separate performance archive.

Core `TPitchTrack.Create` accepts an explicit analysis window independently of hop;
zero retains the default. `TWavetableSourceFactory.CreateMorph` combines two owned
cycle recipes through a cloned note-relative curve and independently capped banks.

Floating seconds convert through `pythian.time.SampleFramesFromSeconds`: multiply
at Double precision, then apply explicit floor or ceiling. Offline and scheduled
synthesis share this conversion, including early release. Integer-frame gates
and rational PPQ clocks retain their exact timing contracts.

`PACKAGE-INFO.txt` records the compiler/target used for the package checks and any
included WFC revision. This snapshot excludes Phanes and external music assets.
`SHA256SUMS` lists every other delivered file with its SHA256 digest and relative
path. Packaging verifies the extracted ZIP's complete inventory and bytes before
compiling the examples. The manifest detects content changes; it is not a signature.
See [provenance](PROVENANCE.md) and the [MIT license](LICENSE).

Finite output tempo providers use `TempoClockFromTokens` independently of learned
performance spans. Core `TTempoMap.Intervals` partitions tick ranges at changes;
the companion `TimeWfcEnsembleFrame` adapter preserves sounding continuations as
holds. No extra attacks or cropped note gates are needed for tempo changes inside
notes. These APIs retain the standalone clock / companion frame boundary.
`KeyChangesFromTokens` likewise reconstructs finite key changes, while standalone
`MapDiatonicPitch` maps scale degree and octave between known major/natural-minor
keys. The voice operator applies changing key at new accompaniment attacks and
preserves sounding notes and absolute measured melody. These additions use the
current style format, with no historical readers.

`AnalyzeWavetableCycle` in the core wavetable unit measures signed harmonic
coefficients from an explicit PCM period. The returned recipe feeds the existing
factory after the source clip is released. Cycle selection, envelope and note
generation remain separate; no additional native archive format is needed.

Core `RearticulatePitchSpans` partitions known pitch intervals at explicit attacks.
The companion's optional `DurationArticulateOnsets` source policy maps admitted
physical onsets through their own clocks before duration learning. The current
style capability mask retains this choice through weighted repeated blends.

`AdmitWaveKeyRegions` in `pythian.music.context.admission` measures independently
selected local key regions on a native source grid. Results retain regional
weights, rankings, source frames and explicit unknowns. The grid can carry
changing clocks and source offsets; labels and boundaries remain caller choices.

`pythian.fourier.Fourier` supplies shared forward/inverse complex transforms with
explicit scaling and detached results. `pythian.separation.THarmonicPercussive`
uses stereo-linked median masks and complete-length reconstruction to produce
owned harmonic/percussive clips. The source may be released after construction;
clip properties are borrowed from the separation object. Planning validates
window/hop geometry, median lengths and aggregate work before processing.
Spectral components do not establish isolated instruments or monophonic voices.

The core `pythian.spectrum.PartitionPowerSpectrum` query summarizes caller-selected
power bands and their gaps, retaining peak bins and detached result arrays. It
does not perform an FFT or decide musical pitch. `pythian.pitch.regions` also
provides source-timed boundary context for separate note-event policies.

In the WFC package, `pythian.wfc.grid.TStyleGrid` owns saved uniform-grid providers
and creates named sessions for key, tempo, onsets and available pitch/intensity
evidence. Typed locks and captured native values let a consumer edit a dimension
without putting file I/O or synthesis policy into the adapter. The separate
`pythian.wfc.performance` API serves learned duration spans. Both retain saved
generation preferences; unsupported provider preferences reject explicitly.

Both APIs expose `CopyProvider` returning `TStyleProviderDescription` from
`pythian.wfc.providers`. It owns copies of current musical choices, immediate
projection dependencies, preferences and scope. Timing distinguishes uniform
PPQ cells, held context and cumulative generated spans. Read musical fields only
when listed in each choice's `Dimensions`; unknown/silence remain explicit.
Choice tokens feed the existing session locks/preferences. Inspection reflects
the definition, not pending session edits, and does not prove joint feasibility
or infer bass/voice roles. No additional archive or historical reader is added.

Named layer sessions retain dependencies, explicit timing maps and fixed timing
partitions during selective edits. Choice preferences, hard locks and training
weights are separate controls. These APIs expose the current supported providers;
general learned bass/voice/harmony roles and genre quality remain unaccepted.
All use the current native style contract, with no additional historical reader.

`pythian.beat.alignment.AlignBeatObservationsWithContext` optionally refines
caller-owned pulse cells using nearby original onset offsets. At least two
witnesses in the same run are required. Unsupported choices retain the raw
frame with `Unknown`; insufficient context preserves the independent choice
with `ContextUnavailable`. `pythian.beat.clock` exposes this through
`bcaNeighbourSupported` and retains every decision in `AlignmentChoices`.
Independent alignment remains the default. Neither mode establishes musical
beat identity; raw fallback requires caller review before context admission.

`pythian.beat.track.SelectBeatTrackPath` selects among existing candidate windows
without remeasuring the WAV. Callers can filter a pool using explicit base context,
retain forced run boundaries, then pass the detached result through
`SelectedBeatClockWindows` and `ReconstructBeatClock`. Returned indices refer to
the supplied pool; retain any earlier index mapping separately. Reconstruct
frames after selection instead of reusing a previous track's frame arrays.
Path scores and deterministic ties do not establish musical confidence.
