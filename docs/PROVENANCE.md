# Extraction provenance

[Home](../README.md) · [Profile and pins](../PROJECT.md#dependencies) ·
[Architecture](ARCHITECTURE.md) · [Work](WORK.md)

`pythian.beat.wave` extracts the existing native beat operator's analysis,
localization, event admission and weighting into a reusable core unit. Beat
fitting still uses `pythian.beat`; phase/context conversion uses the existing
exact PPQ clock. The original beat report is byte-identical on the controlled
before/after comparison. This is reuse of owned code, not a second estimator.

Extensible WAV decoding is new native Pythian code within the existing bounded
reader. Its subtype identifiers, valid-bit alignment and speaker-mask meanings
follow Microsoft's
[format definition](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ksmedia/ns-ksmedia-waveformatextensible)
and [GUID mapping](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/converting-between-format-tags-and-subformat-guids),
checked 2026-09-15. No external decoder code or platform units are copied.

The root license is MIT, copyright 2026 mr-highball. WFC's applicable copyright
is 2021 mr-highball; Phanes's is 2026 mr-highball. Adapted files retain complete
MIT notices and applicable attribution. No source music or application assets
are bundled in the library. The demonstration phrase is authored here. Two
optional published CC0 recordings were downloaded under ignored build output
for [WAV learning evidence](WAV-LEARNING.md#published-recording-evidence);
their provenance is pinned in the [corpus manifest](../tests/fixtures/wav-corpus.json).

Six additional isolated acoustic instrument samples from
[VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE) provide independent pitch
references through its SFZ mappings. They are CC0 recordings by Sam Gossner and
Simon Dalzell, with sample cutting by Elan Hickler/Soundemote. Pinned revisions,
source SHA-256 identities, explicit native resampling and the failed bassoon
case are retained in [recorded pitch evidence](PITCH.md#recorded-instrument-evidence).
Acquisition is optional and confined to ignored build output; no dependency was added.

Three development WAVs and their author-supplied beat timestamps from Rico
Rosenbusch's [ARTBeaT dataset (2024)](https://audiolabs-erlangen.de/resources/MIR/2024-ARTBeaT)
provide the [annotated beat baseline](BEAT-TRACKING.md#independent-annotated-development-baseline--2026-09-19).
The dataset is CC BY 4.0; its complete license and README are retained with the
ignored acquisition. Source WAVs are unchanged; listening variants add Pythian
pulse markers. No source media or external implementation is bundled in the library.

<a id="mapped-register-reference-bank"></a>
## Mapped register reference bank

The [register coverage study](PHRASE-EVALUATION.md#register-reference-bank-checkpoint)
uses 40 samples from
[VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE/tree/6dd651d55dde97fd4028699be9d4481f26917891)
at source/SFZ revision `6dd651d55dde97fd4028699be9d4481f26917891`.
The upstream CC0 license and attribution to Sam Gossner, Simon Dalzell and
Elan Hickler/Soundemote are retained with the acquisition. SFZ root/tuning labels
identify the nominal source pitches; filename octave conventions are not used.
This comprises 32 flute/solo-violin sustain references and eight separate
articulation challenges, all under ignored build output. The native catalog,
channel-zero resampling and spectral measurement reuse Pythian code; no external
implementation, sample assets or instrument format is added to the library.

The [spectral power partition query](ANALYSIS-WAVE.md#spectral-power-partitions)
is new native Pythian code for summing caller-selected bin ranges and their
complementary gaps. It reuses the owned Fourier value type without copying an
external implementation or adopting a pitch/solver dependency. Its recorded
consumer reuses the attributed reference bank and existing phrase study inputs;
no additional source media or saved format is introduced.

<a id="optional-native-observation-adapter"></a>
## Optional native observation adapter

[NS-3_validation_02](TODO/NS-3_validation_02.md) selects a Win64 CPU observation
adapter as a bounded route from the private model study to a maintained native
consumer. Controlled/recorded fidelity, performance, memory and representative
cancellation checks passed, including one continuous hour. Qualification is reopened
for a progress snapshot race that can falsely terminate a healthy worker; see
[the current disposition](NATIVE-INFERENCE.md#qualification--2026-09-21). The portable core and
default packages remain independent of the acquired binary runtime.

The converted CREPE tiny topology and thirteen weight shards come from
[marl/crepe revision de4888e6](https://github.com/marl/crepe/tree/de4888e6d448357ceafea10fc6010061c6f19a55).
Preprocessing references remain pinned to
[c9b71ce6](https://github.com/marl/crepe/tree/c9b71ce61491454125a0693f584f7244f29d9884).
Retain the full upstream MIT license, copyright 2018 Jong Wook Kim, alongside
the model and applicable derived implementation. Weights remain unmodified;
the exact topology/weight identity differs from a promise of parity with every
other model export. Existing [numerical comparisons](PHRASE-EVALUATION.md#native-model-fidelity-checkpoint)
are the starting evidence; maintained-path acceptance is recorded separately in
[native inference](NATIVE-INFERENCE.md#qualification--2026-09-21).

The TensorFlow 2.18.1 CPU archive is the Win64 C package linked by the
[official C installation page](https://www.tensorflow.org/install/lang_c).
Its SHA256 is `28acdcea6c6b34828cf0e95e67802b0f3577d51bc2e8915de811b7aa0b04452d`;
the DLL SHA256 is `07687defc3f36ee93e372b692d37317b348369a80b3a36201a55d69d7d9edba8`.
Preserve the archive's complete Apache-2.0 `LICENSE` and
`THIRD_PARTY_TF_C_LICENSES`. The official page identifies 2.18 as the final
Windows x86 C-package release: this is a frozen compatibility choice, not a
claim of a continuing upstream binary upgrade stream.

The [acquisition lock](../adapters/inference/assets.lock.json) binds every selected
model file, runtime archive, loaded DLL and retained notice by byte count and
SHA256. [Explicit acquisition](../tools/get-inference-assets.ps1) stages the complete
verified assets under ignored `build/`, preserves an existing destination and
supports verified local caches. It neither runs upstream Python/JavaScript nor
installs the DLL globally. Current source packages do not bundle model/runtime
assets or silently gain this optional adapter; accepted-workflow distribution
remains owned by the existing delivery tasks.

The maintenance cost includes the roughly 254-MB archive/954-MB DLL footprint,
pinned ABI and graph/weight validation, Windows process resource accounting and
future runtime availability. The current scalar cost makes this optional edge
worth qualifying before attempting another full kernel implementation. That
measured execution met the frozen limits, but supervision qualification remains
open pending repair and focused QA. Its
supported output is raw 360-bin salience and AC RMS, not the rejected note
admission rule. Preserve uncertain training/annotation exposure; arithmetic
agreement does not establish musical accuracy or independent evaluation.

<a id="note-head-reference-model"></a>
## Optional note-head reference model

The [separate-head feasibility probe](PHRASE-EVALUATION.md#note-head-feasibility-checkpoint)
uses Spotify's official
[Basic Pitch](https://github.com/spotify/basic-pitch/tree/fa5997af0a8210982619003269994a1be25eddf3)
SavedModel at revision `fa5997af0a8210982619003269994a1be25eddf3`, inspected
2026-09-20. Its graph, variable index/data and source references are retained
under ignored `build/note-head-feasibility/`, with unmodified upstream Apache-2.0
LICENSE and NOTICE, including Spotify's 2022 attribution and third-party notices.
Their identities are recorded in the probe report and acquisition/checkpoint ledger.

The owned Pascal probe loads that model through the previously acquired
TensorFlow 2.18.1 CPU C API, whose complete license/notices remain with the
reference runtime. Downloaded upstream Python files are read as reference material;
none is executed and no Python/JavaScript toolchain is introduced. This is optional
reference execution under ignored build output, not a native Pascal model port,
production dependency, submodule change or distributable library asset. Adoption
or distribution would need its own dependency/provenance review and declared scope.

The subsequent [recorded comparison](PHRASE-EVALUATION.md#note-head-recorded-checkpoint)
reuses the same pinned model/runtime and the existing attributed development
recordings. Owned native resampling, explicit source-coordinate interpolation and
a declared monophonic decoder are comparison policy, not upstream postprocessing
parity. Study code and outputs stay under ignored `build/note-head-recordings/`;
the unsuccessful comparison adds no production dependency or distributed asset.

<a id="beat-model-reference"></a>
## Optional beat-model reference

The [learned beat comparison](BEAT-TRACKING.md#learned-model-reference) uses
Beat This!'s small1 model as a published ONNX export from
[beat-this-rs](https://github.com/danigb/beat-this-rs/tree/089b509247e6fdcec666511c0dcf0d5f39c21e73),
revision `089b509247e6fdcec666511c0dcf0d5f39c21e73`, inspected 2026-09-20.
The export repository identifies small1 as its checkpoint and records
[upstream Beat This!](https://github.com/CPJKU/beat_this/tree/b95c8ab0c58c2d9fcfd40508ae8dffbc05ac4f5c)
revision `b95c8ab0c58c2d9fcfd40508ae8dffbc05ac4f5c` for its reference fixtures.
Our acquisition retains both full MIT notices: the Institute of Computational
Perception, JKU Linz (2024), and danigb's port (2025). The owned Pascal consumer
adapts chunk/peak processing with those notices alongside the owned 2026 notice.
No Rust or Python implementation is executed.

| Acquired artifact | SHA256 |
| --- | --- |
| `beat_this_small.onnx` | `a5f8d39d989f31859454ba27afe61c5317ca95e4d9373e6853e5361b8937172f` |
| `mel_spectrogram.onnx` | `fdd59e65c515331308e4c8841edf99972deca646bdf6197744c2a5b7755e3de9` |
| ONNX Runtime Win64 1.30.0 release ZIP | `c6ba983baf5681af108599675d2a89c2d145512d02de28aed0bff177cd0ba949` |
| Executed `onnxruntime.dll` | `7e39e2bdbba836d98071ef28620735ba36a47c554cf794585269aecc50fab0da` |

The runtime comes from Microsoft's
[official 1.30.0 release](https://github.com/microsoft/onnxruntime/releases/tag/v1.30.0).
Its ZIP digest matches the release API's SHA256; full LICENSE and
ThirdPartyNotices remain with the acquisition. The Pascal probe uses the C API
17 prefix on Win64, with one CPU thread. This is private reference execution,
not a production runtime dependency or a bundled library asset.

Preprocessing controls use the owned Fourier primitive and the mathematical
parameters of upstream `LogMelSpect`, with
[torchaudio's transform contract](https://docs.pytorch.org/audio/stable/generated/torchaudio.transforms.MelSpectrogram.html)
and [filter-bank definitions](https://docs.pytorch.org/audio/stable/_modules/torchaudio/functional/functional.html)
checked 2026-09-20. The original and exported network are not independently
compared here. The published
[annotation inventory](https://github.com/CPJKU/beat_this_annotations/tree/fd9fcc0896cb78730bae735102c8753ef3a3badd)
was inspected at `fd9fcc0896cb78730bae735102c8753ef3a3badd` without reading unused
timing labels. Directory absence alone is not proof of source-level training
disjointness. All assets and source references remain ignored under
`build/beat-model-reference/`; no dependency pin or maintained format changes.

## Current extraction inventory

The counted journal acoustic adapter preserves the open-boundary state, BOS,
start/end and first-seen token semantics of WFC's `wfc_sequence_learn.pas` at the
retained pin. It uses public `TWfcSequenceModel` contracts, with a bounded state
lookup and explicit whole-segment multiplicity instead of retained token arrays.
The adapter retains WFC's 2021 notice alongside the 2026 owned adaptation notice.
Journal readers, weighted streaming palette coordination and bounded representative
selection are owned Pythian code. No companion source is modified.

Independent layer scopes directly reuse WFC's `ConfigurePassLayouts` and its
per-pass sequence boundary/capture contracts. Pythian owns scope validation,
copying, budgets and selective session coordination. Explicit held context uses
one state from each original saved model; it does not create repeated learning
samples or infer a longer measured source scope. [Contract and evidence](LAYERS.md#per-layer-scopes).

Periodic pitch estimation is new native Pythian code derived from the mathematical
method in de Cheveigne and Kawahara's YIN paper (JASA 111, 2002), not copied source
code. It implements a bounded single-window subset with explicit weak-result
rejection. The controlled harmonic WAV is authored here; pitch learning uses the
actual WFC learner. [Algorithm reference, differences and evidence](PITCH.md).

Shared pitch-cell measurement and the current saved-style extension are native Pythian
coordination. Two authored harmonic WAVs, one an octave above the other, provide
independent known-note evidence for saved weighted blending and melody generation.
Actual WFC pitch/session/voice contracts remain in use. No mixed recording is
relabeled as a separated melody; accompaniment and note lengths remain authored.

Independent rhythm/intensity and pitch weights extend the native style
coordination, using the same companion learners and complete source/parent
evidence. Recorded Pixel rhythm can be combined with measured monophonic WAV
pitch and blended again; this does not establish joint pitch/onset learning.

Onset-window RMS and relative intensity admission are native Pythian primitives.
The joint onset/intensity profile uses the existing WFC sequence learner and
projection/session contracts. Its equal relative amplitude bands and authored
velocity scaling are explicit realization policies, not transcribed MIDI or
precursor sound parity. No external code or dependency change was introduced.
[Measurement, archive and listening evidence](ONSET-DYNAMICS.md).

Saved WAV onset-style admission, weighted profile ancestry and named layer-session
ownership are new Pythian coordination logic. They call WFC's existing sequence
learner, overlay passes and selective negotiated regeneration; no solver or learner
was copied or replaced. Musical source evidence retains the corpus attribution
above. The voice realization policy supplies authored pitches, voicings and gates.
See [onset-style evidence](WAVE-STYLE.md) and [session contracts](LAYERS.md#named-sessions-and-selective-regeneration).

Interior sample-loop addressing is new Pythian logic over the existing immutable
clip, source factory and sinc kernel. The interpolation oracle physically expands
authored test PCM; the listening sample is synthesized here. No external code,
sample recording or dependency change is introduced.

The saved-context option in the independent-voice operator reuses actual WFC
provider and voice passes. Its scale-degree mapping and profile coordination
are new authored operator policy. Voice training remains the native symbolic
score, including when base context comes from admitted WAV measurements.
No new external music, solver or inference implementation is introduced.

[Explicit WAV context admission](WAVE-CONTEXT-ADMISSION.md) is new native
coordination over existing tonal rankings, exact clocks, bounded WAV analysis
and saved actual WFC providers. No external inference code is introduced.
Its controlled C-major fixture is synthesized here; its recorded comparison
reuses the previously attributed Pixel Sprinter source.

[Selective context profiles](CONTEXT-PROFILES.md) are new Pythian coordination
and persistence over existing admitted bundles and actual WFC model replay.
They copy selected dimensions and retain complete parent archives without
pooling observations or duplicating a learner/solver. Their native selector
and four-pass demonstration introduce no external code or sound material.

The [stereo reverberator](REVERB.md) is a new Pythian implementation of standard
damped feedback comb and Schroeder allpass structures, with mathematical sources
linked in its contract. It reuses native delay storage and effect integration.
No Freeverb/STK implementation or tuning table is copied. Its listening phrase
is authored with existing native synthesis; no external audio is introduced.

The [WAV analysis adapter](ANALYSIS-WAVE.md) is new native Pythian coordination
over the existing FFT engine and seekable reader. Bounded stream hashing reuses
the existing SHA256 algorithm. No new external code, solver or sound assets are
introduced; recorded learner comparisons use the previously attributed corpus.

The [seekable WAV reader](WAVE-READING.md) consolidates native RIFF/PCM/float
decoding with new bounded reads and RF64 size handling. Existing WFC-derived
codec notices remain on the shared decoder and reader. RF64 structure follows
EBU Tech 3306; no external decoder implementation was copied. Recorded fixture
transcodes preserve the earlier decoder's audio bytes, with source attribution
unchanged and all generated files confined to build output.

Fractional delay history and its automated stereo effect are new native Pythian
implementations. The existing fixed delay now reuses the same ring primitive;
its recurrence is checked independently. Chorus/flanger listening settings are
authored example policies using existing synthesis and immutable automation.
No external DSP implementation or source music is copied.
[Contract and evidence](MODULATED-DELAY.md).

Typed musical context and its scoped PPQ grid are new Pythian implementations,
using the existing native tempo map and tonal mode vocabulary. The context
adapter calls the actual WFC corpus learner and existing negotiated layer
adapter; no new solver or copied precursor inference is introduced.
Its four-pass listening example uses authored key/tempo labels and native
synthesis. See [musical context](MUSIC-CONTEXT.md) for admission and evidence.
The [context bundle](CONTEXT-ARCHIVE.md) is a new Pythian archive around those
admitted grids and actual companion models. It uses the existing native SHA256
and corpus text validation helpers. The demo's source declarations are authored
text, with exact bytes hashed and rebound after loading; they are not recorded
music or automatically inferred labels.

| Precursor | Source | Pythian disposition |
| --- | --- | --- |
| WFC | `src/wfc_music_audio.pas` | Extracted Q12 frequency table, 24-bit phase, triangle and integer envelope into `pythian.oscillator`; detached ownership and PCM/WAVE conventions generalized into `pythian.audio` and `pythian.wave` |
| WFC | `test/wfc_music_audio_test.lpr` | Preserved boundary WAVE golden fixture; bridge check compares all PCM16 values against the actual precursor encoder |
| WFC | `src/wfc_music_audio_stream.pas` | Extracted sequential RIFF/RF64 writing, borrowed sinks, confirmed-block counts, recoverable input errors and poisoned sink failures into `pythian.wave.stream`; generalized to stereo and unified memory/file encoding |
| WFC | `src/wfc_sequence_learn.pas`, `wfc_sequence.pas`, `wfc_sequence_graph.pas` | Used directly through the companion adapter; no copied learning or solver implementation |
| WFC | `src/wfc_music_audio.pas` exact tempo anchors | Fractional microsecond carry generalized into `pythian.time` with explicit floor/ceiling frame conversion and wider sample-rate/timeline bounds |
| WFC | `src/wfc_music_ensemble_audio.pas` | Complete unit reviewed. Fractional clock carry lives in `TIncrementalTempoClock`; voice admission, held phase, delayed release-ring revision, headroom and pull/cancel/end behavior are extracted into `pythian.chord.stream`. Existing native fixed oscillator helpers are reused. `AdmitWfcEnsembleFrame` binds actual frames and native clock with rejected-call rollback; [PCM parity and limits](CHORD-STREAMS.md) are explicit |
| WFC | `src/wfc_music_ensemble.pas` complete-frame reconstruction | Actual `RebuildWfcMusicEnsembleScore` reused by `ProjectWfcEnsembleNotes`; WFC validates independent chords, rests and identical held pitches/velocities. Native projection retains tempo, track and voice identities, and per-voice synthesis preserves held gates across tempo changes |
| WFC | `src/wfc_music_ensemble.pas`, `src/wfc_music_ensemble_training.pas`, `src/wfc_music_ensemble_graph.pas` complete contracts | Complete units reviewed: ordered frame/rhythm/set vocabularies, common-excerpt joint training and structural-edge/hold admission remain companion behavior. Shared frame execution is already native; exact versus subset harmony and caller work limits are explicit. [Disposition](PRECURSOR-BOUNDARIES.md#ensemble-vocabulary-training-and-graph) |
| WFC | `src/wfc_midi_smf.pas` | Standalone native `pythian.midi.smf` preserves bounded SMF parsing, opaque event data, canonical VLQs and explicit-status encoding; complete-byte parity checked |
| WFC | `src/wfc_midi_stream.pas` | Complete unit reviewed and extracted into `pythian.midi.stream`: constant-size counting plan, two-pass format-0 emission, bounded blocks, long-delay bridges and replay lifecycle. Native plan construction adds an invalid-default guard. Complete actual companion bytes/counts/signatures and native codec parity pass; [contract](MIDI-STREAMS.md) |
| WFC | `src/wfc_music_midi_import.pas`, `src/wfc_music.pas` | Stable global event ordering and strict channel/pitch pairing inform `pythian.midi.notes`; `pythian.wfc.music` projects real scores into detached gates, retaining tempo and source indices |
| WFC | `src/wfc_music.pas`, `src/wfc_music_midi_import.pas` complete contracts | Full source review now distinguishes symbolic score partitions, rational notation coordinates, monophonic lane allocation, meter admission and measure padding from already extracted native note/timing behavior. These remaining score policies stay in WFC; [disposition and deliberate differences](PRECURSOR-BOUNDARIES.md#score-model-and-midi-projection) |
| WFC | `src/wfc_music_midi.pas` | Complete unit reviewed; deterministic tick/metadata/off/on/source ordering informs `pythian.midi.export`. Native explicit channels, collision rejection and long-delay streaming generalize note output; meter/score policies stay in WFC. Actual companion note/tempo bytes agree after explicit meter removal; [contract](MIDI-EXPORT.md) |
| WFC | `src/wfc_music_sequence.pas`, `src/wfc_music_training.pas` | `pythian.wfc.activity` uses real rest/attack/hold rhythm cells and learns each recording as an independent sample through the actual sequence corpus learner. This preserves the symbolic trainer's sample-boundary principle without calling its score-only excerpt API; source analysis hops remain explicit sample-time quanta |
| WFC | `src/wfc_music_sequence.pas`, `src/wfc_music_training.pas`, `src/wfc_music_graph.pas` complete contracts | Complete source review: canonical monophonic cells, independent excerpt admission and named conjunctive projections stay with WFC. Chord rejection, hold validation, sounding harmony under melody rests and caller budgets are explicit; native notes/frames/clocks already cover execution. [Disposition](PRECURSOR-BOUNDARIES.md#monophonic-cells-training-and-pass-projections) |
| WFC | `src/wfc_music_text.pas`, `src/wfc_music_passes_text.pas` | Complete source review: canonical score and public-composition serialization remain companion contracts. Composition text omits models, latent capture and training/blend lineage; it cannot substitute for a style archive or resume checkpoint. [Disposition](PRECURSOR-BOUNDARIES.md#score-and-composition-text) |
| WFC | `src/wfc_music_sequence.pas`, `src/wfc_sequence_learn.pas`, `src/wfc_sequence_graph.pas` joint observed labels | `pythian.wfc.joint` pairs existing acoustic tokens with actual encoded rhythm cells, trains the real sequence model and intersects simultaneous locks. Pairing and action-aware grain selection are new native policies; no second learner/solver or inferred beat certainty is introduced |
| WFC | `src/wfc_music_form.pas` | Complete unit reviewed: authored phrase grammar, caller-declared catalogs, chord-slot/upper-line motion and negotiated realization remain companion policy. WAV labels/anchors must be verified by an acoustic consumer; [disposition](PRECURSOR-BOUNDARIES.md#form-planning) |
| WFC | `src/wfc_music_voices_training.pas`, `wfc_music_voices_graph.pas`, `wfc_music_voices_stream.pas` | Complete units reviewed: independent learned voices, common excerpt admission, collective harmonic coverage, pair constraints and exact per-model continuation remain in WFC. The [independent-voice consumer](INDEPENDENT-VOICES.md) now exercises training, planning and streaming with complete preview PCM parity. [Contracts](PRECURSOR-BOUNDARIES.md#independent-voices) |
| WFC | `src/wfc_sequence_analyze.pas` | Complete unit reviewed: symbolic path/cycle feasibility and per-position state domains remain WFC algorithms; this is not PCM or musical-feature analysis. [Limits](PRECURSOR-BOUNDARIES.md#sequence-analysis) |
| WFC | `src/wfc_music_passes.pas`, `src/wfc_music_ensemble_passes.pas` | Complete units reviewed: finite transactions, selective roots/dirty descendants, provider reuse and ensemble voice-slot locks remain WFC APIs. Actual unmodified fixtures pass on both installed compilers; [disposition and evidence](PRECURSOR-BOUNDARIES.md#finite-pass-pipelines-and-selective-regeneration) |
| WFC | `src/wfc_music_ensemble_stream.pas` | Complete unit reviewed: exact model-bound frontiers, sparse future constraints, independent segment capture and terminal failure stay with WFC. Native renderer/clock already consume its frames; [lifecycle and limits](PRECURSOR-BOUNDARIES.md#ensemble-stream-lifecycle) |
| WFC | `src/wfc_music_ensemble_midi.pas` | Complete reviewed transport extracted into `pythian.midi.chord`: bounded active/pending frames, exact holds, timing/off/on order, channel binding and counting/replay wrappers. Shared native frame data lives in `pythian.chord`; audio aliases preserve existing callers. Actual companion bytes/plans and native consumer/PCM regression checks pass; [contract](CHORD-MIDI.md) |
| WFC | `src/wfc_sequence_graph.pas` segment boundary API; `wfc_music_arrangement.pas` | Actual boundary API and section seed reused. Complete arrangement unit reviewed: finite source-owned compositions, timing/signature checks, detached public-token tails and source-defined continuity remain symbolic companion policy. Its sections reject initial melody holds; ensemble continuation uses the separate latent-frontier stream. [Consumer/disposition](ENSEMBLE-STREAMS.md) |
| Phanes | `src/phanes.audio.synth.pas` | Explicit seeded noise recurrence retained; voice/envelope/filter/pan architecture generalized into native primitives; native filter/envelope implementation differs from Web Audio |
| Phanes | `src/phanes.audio.synth.pas` scheduled frequency/filter ramps and detune | Exponential 125->42 Hz pitch and 600->160 Hz cutoff ramps generalized into owning frame curves and tone automation; cents conversion supports explicit detune. Voice/style presets remain application/example policy; no Web Audio sample-parity claim |
| Phanes | `src/phanes.audio.synth.pas` shared finite noise buffer, per-note source allocation and `onended` cleanup | Reusable owned sample regions and independent source instances now cover finite playback, natural exhaustion and per-note cleanup. Seeded recurrence passes through the waveform factory. Pascal ownership replaces browser node disconnects; loop modes and harmonic-limited tables are new Pythian primitives |
| Phanes | `src/phanes.audio.synth.pas` biquad, master compressor and target gains | Native biquad/EQ, linked peak compression and gain-target smoothing now support the general behavior; threshold/ratio/attack/release defaults retain Phanes's -14 dB/4:1/5 ms/150 ms values. The 6 dB knee and time-constant semantics are explicit native policy; no Web Audio sample-parity claim |
| Phanes | `src/phanes.audio.synth.pas` music/echo/effects graph | Extracted ordered native buses with owning chains, pre/post-fader sends and gain smoothing. Stereo filtered echo retains the 375 ms delay and 0.23 return/feedback gains; dry music and echo share one output fader, effects bypass it, and both reach the master. Explicit native Butterworth Q and compressor policy differ from browser defaults. Return-mute fixtures preserve continuing echo history |
| Phanes | `src/phanes.audio.synth.pas` active/scheduled counts, voice limit and cancellation | Extracted bounded native pending/active counts, group-scoped future cancellation and committed-voice release in `pythian.schedule`. Exact frame boundaries replace browser timing margins; declared ADSR release replaces fixed gain/stop timing. Shared per-note state and bus tails survive cancellation; atomic future replacement and explicit work/ownership recovery are new native contracts |
| Phanes | `src/phanes.music.types.pas` | Complete unit reviewed: native notes/clocks/voices cover execution concepts; ten style presets, four lanes, weighted tempo/blend and fixed section schema remain application policy |
| Phanes | `src/phanes.audio.dimension.pas`, `phanes.audio.browser.lpr` | Complete units reviewed: DOM style/tempo controls, layout, supplied transport statistics and browser startup remain application responsibilities; no additional DSP or beat inference. [Disposition](PRECURSOR-BOUNDARIES.md#phanes-application-controls) |
| Phanes | `tools/phanes.tools.files.pas` | Exact-byte provenance-helper contract retained in `pythian.hash` and reused by tools and archive integrity. The native FIPS 180-4 implementation replaces the development-only FCL hash dependency for stable FPC; known vectors, actual FCL parity and old archive/music replay are recorded in [delivery evidence](PACKAGING.md) |
| Phanes | `src/phanes.audio.player.pas` tempo scheduling | Grid-aligned future tempo pivot and committed clock prefix generalized into immutable `TTempoMap` candidates. The native scheduler now accepts future frame-note replacements while preserving committed instances. Device clock mapping, context lifecycle and UI request coalescing stay with host/application orchestration |
| Phanes | `tools/phanes.tools.midi.pas` note pairing | FIFO overlaps and end closure retained as explicit, counted options. Pythian pairs globally by channel/pitch and closes at global sequence end; Phanes pairs within tracks and closes at each track end. No minimum-note-count or silent percussion exclusion copied |
| Phanes | `tools/phanes.tools.midi.pas` `ScoreIdentity` | Reviewed transposition/time-offset-normalized, velocity-omitting deduplication. This remains an application corpus policy and does not replace exact-file source provenance |
| Phanes | `tools/phanes.tools.midi.pas` `ExtractSamples` | Duration histogram and tonic/fifth-biased major/natural-minor fit extracted into `pythian.tonal`, with explicit caps, full ranking and score gaps; actual precursor selection parity verified. Stored WAV chroma now uses the same inspectable profile contract. Forced scale-degree mapping, three fixed 32-beat excerpts and density bins remain application policies |
| Phanes | `tools/phanes.tools.midi.pas` complete contract | Full source review reconciles all three public functions and private parser/fraction helpers with the preceding extracted contracts and deliberate differences. No additional core audio extraction identified; [complete disposition](PRECURSOR-BOUNDARIES.md#phanes-midi-corpus-helper) |
| Phanes | `src/phanes.audio.preview.pas` | Reviewed complete preview scheduling and WAV export. Native rendering/scheduler/buses/codec cover reusable mechanisms; incremental musical timing now has a constant-storage clock. Fixed section counts/lengths, BPM limits, preroll/tail and browser suspension are application/host policy. Native PCM scaling and synthesis deliberately differ; see the preview disposition below |
| Phanes | `src/phanes.audio.player.pas` complete player | Reviewed scheduling, tempo admission, transport, worker lifecycle, feedback and export. Native clock/scheduler integration preserves old timing on rejected replacement and crossing gates on success; browser/UI and generation-request policies remain host/application responsibilities. See the player disposition below |
| Phanes | `src/phanes.music.track.pas` | Complete unit reviewed: authored five-phase forms, 304-second duration target, 4..40 sections, style rotation and phase-specific event shaping remain application composition policy. Learned transitions, fixed-prefix constraints and exact continuation belong to the real WFC companion. The new generic stream preserves full learned history; macro-form controls remain open |
| Phanes | `src/phanes.music.generate.pas` | Complete unit reviewed. Negotiated correlated models and complete projection relations generalized in `pythian.wfc.layers`; fixtures exercise pairs and temporal intervals. Lane anchors/locks remain explicit WFC constraints. Fixed corpus quotas, style selection and lossy note-arrangement recipes remain application policies |
| Phanes | `src/phanes.music.wire.pas`, `phanes.music.worker.lpr` | Complete units reviewed. Browser JSON schemas, job IDs, worker lifetime, track indices and monotonic plan publication stay at the host boundary. Native library admission uses bounded values, detached candidates, exact source hashes and actual learned-model validation; no browser wire schema is imported |
| Phanes | `tools/phanes.tools.music.pas` | Complete unit reviewed. Manifest path/hash/license admission and canonical stale-corpus checks inform explicit native source provenance and archive integrity. Fixed 100-reference quota, allowed asset categories, source-edition scanning, semantic deduplication and 32-beat extraction are application corpus policies |

Shared corpus persistence and admission are new Pythian implementations around
the extracted analysis/provenance contracts and WFC's actual sequence model.
No second learner or solver was copied into the archive adapter. Its independent
admission pass counts stored observations against the real model API.
Activity peak selection and sampled-overlap beam planning are new native Pythian
policies. They preserve observed source coordinates and requested WFC tokens;
they do not transfer Phanes's MIDI beat certainty to mixed WAV audio.

Polynomial oscillator correction and Blackman-windowed sinc conversion are new
Pythian implementations. Their mathematical references, chosen policies and
measured limits are recorded in [DSP documentation](DSP.md). No additional
precursor source or external DSP implementation was copied. The extracted
fixed-point waveform and seeded recurrence retain their existing contracts.
The [continuous converter](DSP.md#continuous-conversion) extends the existing
native sinc kernel with a bounded input ring, exact integer/fractional position
carry, centered lookahead and explicit EOF/poison behavior. It copies no further
precursor code. Scheduled synthesis feeds it directly into the sequential WAV
writer; existing default scheduling and offline conversion bytes are preserved.
Frame automation, independent additive partial envelopes and sine/FM/PM operators
are native Pythian implementations. [Modulation documentation](MODULATION.md)
records the precursor scheduling behavior, mathematical references, ownership,
sideband evidence and remaining routing/streaming boundaries.
The [shared source contract](SOURCES.md) connects the existing primitives and
new wavetable/sample voices to one renderer. Its explicit ownership, source
exhaustion, loop-release and stereo behavior are checked independently; this
does not by itself close the remaining extraction or Phanes removal gates.
The [filter/dynamics/effect implementation](EFFECTS.md) records its cookbook
equation reference, compression policy and signal evidence. Its serial chain
owns stages and preserves history across clip boundaries. The sample limiter
and chain failure/recovery policy are new Pythian behavior, with no copied
external processor source.
The [bus and echo extraction](BUSES.md) implements the precursor's signal
connections using native owning processors. General ordered sends, explicit
pre/post taps, poisoned-graph recovery and bounded clip rendering are new
Pythian contracts. The demo feeds a shared sequential WAVE writer; no browser
runtime or Phanes source/assets are required to build or run it.
The [scheduler](SCHEDULING.md) shares the offline note implementation, owns
copied automation and per-note playback, and borrows source factories and the
graph explicitly. Candidate preparation preserves the old future schedule on
failure; retained voices and echo are checked against independent reference
schedules. Source/graph recovery is explicit and does not reinterpret failed
processing as a successful timeline advance.
The [output articulation stage](ARTICULATION.md) adds native PPQ-grid and MIDI
gate envelopes after reconstruction, reusing the extracted exact tempo clock.
Its bounded maximum-envelope composition and post-mix rests are new Pythian
contracts. It copies no additional precursor implementation and leaves measured
WAV activity labels unchanged.
The [joint archive adapter](JOINT-ARCHIVE.md) adds independent paired-state count
admission and an exact activity-policy attachment to the existing core archive.
It serializes the actual WFC model with WFC's codec. The binary envelope and
bounded sparse observation lookup are new Pythian code; no precursor source
was copied or patched for persistence.
The [timing bridge](TIMED-LEARNING.md) reuses the extracted PPQ clock and native
articulation gates to construct actual WFC onset-candidate locks. Integer
nearest-cell mapping, explicit error/collision contracts and the combined
native remix tool are new Pythian code. Source SHA256 binding is shared between
the existing archive tool and this workflow; neither reads Phanes source/assets.

## Track organization disposition

The remaining generator, wire, worker and corpus-tool review is recorded in
[generation disposition](#generation-and-corpus-disposition), with reusable
negotiation covered by the native [layer adapter](LAYERS.md).

The complete `phanes.music.track` unit learns an order-2 sequence model from
three authored macro-form examples, constrains observed opening/landing and
interior phases, fixes the existing prefix during extension, and applies
optional one-third/two-thirds landmarks outside that prefix. These five named
phases and examples express application composition choices; they are not
learned structure from recorded WAV music. The 304-second planning target,
32-beat sections and 4..40-section bound likewise remain explicit application
policy. A preserved prefix containing its old terminal landing is not silently
rewritten to make extension possible.

Featured styles rotate through connected styles. Arrival/landing adjust gain
by beat and omit selected voices; drift reduces density/gain, crest boosts
velocity with saturation, and the final section clips gates to its boundary.
These presets can be implemented by callers using native voice/gain/gate
controls without embedding Phanes style/voice identifiers in the library.

The reusable learned continuation mechanism uses the companion's actual latent
sequence contract through [learned streams](LEARNED-STREAMS.md). It preserves
all model history across chunk boundaries and borrows WFC's section-seed
function. This is a new generic adapter, not a claim that the Phanes macro-form
planner or full symbolic WFC arrangement iterator has been ported. Long-form
musical controls remain open; the generator/wire/corpus review is recorded below.

## Preview disposition

The complete `phanes.audio.preview` unit has two responsibilities: schedule
ordered sections into an offline browser context, and export its stereo buffer
as PCM16 WAV. Its reusable signal mechanisms are covered by native tone/source
rendering, the scheduler, bus/echo graph and sequential WAV writer.
Pending native voices do not process preceding silence; callers can admit
later phrases incrementally while preserving committed voices and bus history.
The [incremental clock](MIDI.md#incremental-streaming-clock) supplies exact
constant-storage timing for a chosen sequence of PPQ intervals and integer
microsecond tempos.

The preview's 1..32 sections, 32-beat section length, 60..160 BPM range,
twelve-minute limit, 50 ms preroll, two-second tail and 0.65 music gain remain
application preview policy. Browser promises, suspend/resume at 100 ms before
a section, and context construction remain host responsibilities. Native
microsecond tempos and ADSR/effect behavior are explicit contracts; they do
not claim browser floating-point BPM or Web Audio sample parity.

Phanes export clips and scales samples by 32767 with host rounding. Pythian
intentionally retains its documented 32768 PCM scale, saturation and halves-
away-from-zero rule, plus finite-value checks and explicit mono/stereo formats.
No second Phanes-specific WAV codec is needed. This review closes the preview
unit's inventory. Subsequent generator and ensemble/arrangement work is recorded
below; the overall extraction gate remains open.

## Player disposition

The complete `phanes.audio.player` unit was reviewed at the recorded Phanes pin.
It owns transport and application orchestration around the already inventoried
synth and preview. Its scheduling mechanisms map to exact PPQ clocks, retained
native voices, group cancellation and atomic future replacement. The player
keeps current and queued sections, maps beats into context seconds, and reports
late, dropped and scheduled events. Pythian uses explicit integer frames and
admission results; the browser's 40 ms late tolerance and 750 ms startup margin
are host policy, not implicit core timing rules.

Tempo changes choose a future four-beat bar with a 350 ms commitment margin.
Imminent changes coalesce into a deferred request. If faster playback requires
more sections to satisfy the application's 304-second target, the player first
requests a longer form and preserves the current clock/audio on rejection.
These margins, minimum track duration, section counts and request coalescing
remain application policy. The reusable invariant is that candidate admission
precedes publication and leaves already committed notes intact.

The native [scheduler fixture](../tests/pythian.tests.schedule.lpr) now combines
`NextGridTick`, `WithTempoFrom` and `TryReplaceFuture`. Independent reference
frame positions verify both rejected and accepted tempo changes sample-for-sample,
including a sounding note and a pending note beginning before the pivot whose
original gates cross it, another group, and continuing echo. The caller publishes
the candidate clock only after successful batch admission. This is a synchronous
caller transaction, not a thread-safe clock/scheduler coordinator. Native batch
admission is deliberately stronger than the player's cancel-then-schedule path.

Worker job IDs, stale-response rejection, worker termination and error reporting
remain host orchestration. Cryptographic seed acquisition, forty section seeds,
style/blend/lane-lock requests, current/queued section selection and automatic
new-track generation are application policies; their musical generator has the
separate disposition below. Pythian's explicit seeds and source attribution
remain independent of browser randomness and DOM credits.

Separate music/effects contexts, pause/resume and visibility/freeze recovery,
the 25 ms scheduler/100 ms visual polling, panel focus management, editor/camera
feedback tones and browser download URL lifecycle stay with the browser host.
Native groups and buses provide independent signal control, but do not implement
two independently pausable device clocks. Phrase export uses the already reviewed
preview/WAV path. This closes the player unit's inventory without asserting
browser execution, Web Audio parity, long-form generator extraction or device
integration. Evidence: `build/player-tempo-validation.log`.

## Recorded passage path

Native `pythian.passage` adds interval feature aggregation and full recorded-passage
rendering over the extracted audio/WAV foundation. Its loop-grid helper uses ACID
declarations read by the existing native RIFF helpers. Format facts were checked
against libsndfile's reader and loop-information documentation; no implementation
or library dependency was imported. See [passage contracts and sources](PASSAGES.md).
The operator tool applies the retained WFC acoustic learner and solver to these
larger observations. Its opening/reprise/ending pins are explicit authored policy,
not extracted Phanes macro-form behavior or a learned composition claim.

## Generation and corpus disposition

All of `phanes.music.generate`, `phanes.music.wire`, `phanes.music.worker` and
`phanes.tools.music` were read at the recorded pin. The generator trains every
reference excerpt as a separate sample for each lane; order-2 lane models retain
one preceding token. It also learns observed voice pairs and relative interval
sequences, then negotiates four overlay passes. `pythian.wfc.layers` generalizes
that mechanism with actual model/projection contracts, bounded resources and
detached publication. [Native evidence](LAYERS.md) includes an incompatible pair
of otherwise legal lanes, provider retry, budget failure and a synthesis example.

Phanes's minimum 100 references, four fixed lane vocabularies, 32-beat sections,
source rotation offsets, beat-4..7 anchors and first-token seam lock remain caller
policy. Per-position constraints and full spans are available through WFC. Its
restore path checks individual lane sequences; the native coupled request can
also revalidate declared pair/interval relationships. Retaining an emitted token
is weaker than retaining arbitrary latent history; the separate stream adapter
handles exact continuation when required.

The style graph uses weighted values, optional featured-style locks and a
two-style presence quota. These remain direct companion constraints; the ten
Phanes style identities are not synthesis primitives. Four scale tables, octave
placement, pad/bass strides, arpeggiation, drum recipes, intensity scaling and
strong-beat triad remapping are lossy application arrangements. Native notes,
exact clocks, voice factories, automation, scheduling and synthesis provide their
reusable execution mechanisms without imposing those musical choices.

The wire layer bounds integer seeds, indices, styles, weights and fixed-size
arrays; its JSON names and six-field event rows belong to the browser application.
The worker handles initialize/begin/extend/next commands, rejects duplicate section
indices and changed locks, and publishes successful candidate plans. Job echoing,
fresh browser entropy, process reset and exception-to-message conversion stay with
the host. Native synchronous APIs use caller-owned state and explicit results;
this inventory does not claim browser execution or worker transaction parity.

The corpus tool checks unique IDs, exact hashes for source artifacts, permitted
asset notices, semantic score identities and canonical generated JSON. Pythian
retains exact byte identity and measured provenance independently of semantic
deduplication. Fixed corpus sizes, score/license admission categories and excerpt
recipes belong to corpus curation. No Phanes corpus or bundled assets were imported.

This completes review of these named Phanes units, not the overall extraction or
removal gate. Learned ensemble/arrangement generation, broader native consumer
delivery and the full synthesis/learning acceptance remain open. The subsequent
streaming extraction below covers ensemble audio voice admission and release.

## Ensemble synthesis boundary

The native music renderer now maps source voice indices to explicit synthesis
voice records. This removes the single-timbre restriction from projected ensemble
scores without imposing program numbers, instruments or style names. Its common
planner retains exact PPQ endpoints and detached candidate publication; the coupled
layer demo now uses it with unchanged audio. [MIDI/ensemble evidence](MIDI.md#independent-synthesis-voices-and-ensemble-frames)
records the complete-frame bridge, independent stereo reference and failed binding.

`ProjectRetimedWfcNotes` adds a native boundary projection over validated WFC
notes. WFC retains logical score/meter validation and actual voice planning;
Pythian maps explicit cell lengths into native note, audio and MIDI timing.
[Duration-driven accompaniment](INDEPENDENT-VOICES.md#measured-duration-driving-dependent-voices)
reuses those contracts without duplicating a learner or padding measured output.

The reviewed ensemble audio admission/hold/release paths distinguish two intended
contracts. WFC's pull renderer deep-copies staged frames, retains oscillator phase
through identical holds, advances a fractional clock, and uses a release-window
mix ring to revise the last samples of a completed gate. End input drains elapsed
duration and cancel discards pending PCM. Native scheduled voices use declared
post-note-off ADSR release and may append a tail. The complete-frame bridge adopts
native synthesis explicitly. The separate `pythian.chord.stream` extraction now
preserves the delayed-release preview contract, accepting native sample-frame
intervals without WFC types. Its WFC adapter carries exact PPQ timing and rolls
back rejected admission. Actual companion PCM parity passes at three rates with
different block sizes; the native finite-gate oracle independently checks release
overlap and held-note lifetimes. [Streaming evidence](CHORD-STREAMS.md) records
the bounded-memory implementation and native WAV example. End-to-end learned
ensemble segment generation now has a [native consumer](ENSEMBLE-STREAMS.md):
actual order-2 model learning, bounded correlated phrase planning, exact projected
constraints and streamed realization with retained latent history. Full-vocabulary
capacity admission protects native preview bounds before output. Generated PCM
matches WFC; the fixed plan survives changes in realization segment size. This
does not turn the finite authored rhythm/ending guide into inferred WAV structure
or unbounded composition. The subsequent [form/voice review](PRECURSOR-BOUNDARIES.md)
records companion contracts and the remaining independent-voice integration.

The new [source onset localizer](ONSETS.md) is an independently authored native
PCM energy measurement built on existing Pythian clips, analysis and activity.
It adds no external source or dataset dependency and does not alter precursor
or persisted feature contracts. Its controlled reference WAVs are generated by
the native laboratory; external recording attribution remains in the corpus
manifest. Energy-rise estimates are distinct from source beat annotations.
The independent finer timing preset reuses the same analysis/activity algorithms
and preserves the wider learning defaults. Its optional audition path uses the
existing native oscillator and PCM16 encoder to mark measured locations; these
generated cues add no external sound assets or inferred beat annotations.
The [event-learning adapter](EVENT-LEARNING.md) uses WFC's actual sequence learner
for joint acoustic/duration/onset symbols. Native onset-event planning is new
Pythian code, and reconstruction reuses the existing passage aggregate/renderer.
No precursor learner or solver is copied. Original source/report/archive identities
and recording attribution accompany the generated event fragments.

The [beat-grid estimator](BEAT-GRIDS.md) is a new native sparse periodicity/phase
implementation; its mathematical references and ranking policy are recorded
there. It copies no external code or precursor solver. Onset admission reuses
the event planner, and the common audition helper retains the prior native
oscillator/mixer/encoder behavior. Controlled WAVs and quarter-note clocks are
authored by the native laboratory. Source-declared tempo does not select the
recording's estimated grid.
The separate [local tracker](BEAT-TRACKING.md) reuses that estimator with tapered
windows and a native dynamic-programming path over tempo/phase candidates.
Bounded source-onset alignment retains the original grid and selected input
identities. These are new analysis policies, not copied WFC/Phanes solvers or
inferred musical-form labels. The existing native reference WAVs are unchanged.

[Pulse interval admission](PULSE-EVENTS.md) is independent Pythian policy over
the retained track and original onset identities. It reuses source passage
measurement/rendering and the existing joint event tokens. A small adapter
helper partitions admitted intervals into separate samples for WFC's actual
corpus learner; neither its solver nor a precursor learner is copied. Pulse
remixes contain attributed recording slices. The controlled smoke uses the
existing native percussion WAV, with no new external assets.

The initial revisions are recorded in the [project profile](../PROJECT.md).

The [independent-voice consumer](INDEPENDENT-VOICES.md) uses the actual WFC
training bundle, training-document learner, separate voice graph and stream.
Its authored symbolic phrases and stereo timbre choices are new Pythian example
material. Full-vocabulary capacity inspection shares the existing native
ensemble checks under one aggregate budget. Native preview rendering uses the
previously extracted chord/clock bridge; stereo rendering reuses note projection,
per-voice synthesis, ADSR, filters and oscillators. No new precursor solver or
learner is copied, and no external audio is included.

The named music/audio source inventory is now reconciled with extracted behavior
and explicit companion/application dispositions. The temporary Phanes reference
has been removed after its [final audit](REFERENCE-REMOVAL.md); source identity,
applicable notices and captured tonal regression results remain in this project.

The [instrument zone map](INSTRUMENTS.md) is a new Pythian composition primitive.
It copies ordered key/velocity regions and emits existing frame tones for every
matching layer, reusing native pitch conversion, voice/source admission and
rendering/scheduling. No precursor instrument format or second synthesis backend
is copied. Its four sample regions are authored native demo material.

The [shared recorded-event corpus](EVENT-CORPUS.md) is new Pythian coordination
code over native measured passages, palette training and WFC's existing corpus
learner. It preserves independent recording/run boundaries and source identities.
Multi-source passage reconstruction generalizes the existing native sample/fade
implementation; no second WFC solver or learner is copied. Recorded auditions
reuse the previously attributed CC0 corpus sources.

[Recorded-event persistence](EVENT-ARCHIVE.md) uses the existing native measured
corpus envelope with a distinct companion attachment. Its independent event
count admission follows the existing bounded archive-validation approach; actual
WFC model parsing and generation remain in the retained companion. No additional
external recordings or precursor implementations are introduced.

## Measured pulse tempo

[pythian.tempo](../src/pythian.tempo.pas) is new native code over the existing
Pythian spectral-flux analysis. The use of onset-strength autocorrelation is
informed by Daniel P. W. Ellis,
[Beat Tracking by Dynamic Programming (2007)](https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf).
No external implementation is copied. Bounded normalized correlation, local
background removal, candidate admission and report integration are project code;
the paper's Mel frontend, tempo prior and dynamic-programming beat tracker are
not implemented here. Recorded validation reuses the previously attributed CC0
Pixel Sprinter source. Candidate selection uses the current native context/style
contracts and actual WFC providers; no second learner or solver is introduced.

## Saved-style performance coordination

`pythian.wfc.performance` extracts reusable coordination from Pythian's native
voice demo. It composes existing saved-style models, actual named WFC sessions,
typed context adapters and native musical time. Model ownership, typed joint
locks and detached plan validation are new project code. No additional precursor
implementation, external recording or persisted format is introduced.

Local tonal region admission composes Pythian's existing FFT/chroma analysis,
native source-grid mapping and extracted Phanes tonal ranking. Region partitioning,
bounded independent analysis and explicit admission are new project coordination
code. Controlled phrases use native synthesis; recorded checks reuse the already
attributed Pixel Sprinter and VSCO evidence. No new external algorithm or format
is introduced, and selected region labels are not automatic key detection.

## Harmonic/percussive separation

`pythian.fourier` extracts Pythian's existing native analysis butterfly engine,
adding inverse scaling, input admission and detached result ownership.
`pythian.separation` is new native implementation informed by Derry FitzGerald,
[Harmonic/Percussive Separation using Median Filtering, DAFx 2010](https://dafx.de/paper-archive/2010/DAFx10/DerryFitzGerald_DAFx10_P15.pdf).
No external source implementation is copied. Shared stereo magnitude masks,
explicit edge rules, bounded planning and complementary reconstruction are
documented in [separation](SEPARATION.md). Recorded components derive from the
previously attributed CC0 Pixel Sprinter source; reports bind exact input/output
bytes and style provenance retains the transformation-report hash. Controlled
fixtures are authored native tones/impulses. Separation does not establish
instrument identities, isolated voices or automatic monophonic admission.

## Stationary harmonic recipes

`FitWavetableHarmonics` is new native Pythian code in the existing wavetable
source unit. It implements a joint real harmonic least-squares fit using streaming
Givens QR. The projection principle is described by Julius O. Smith in
[Sinusoidal Amplitude and Phase Estimation](https://www.dsprelated.com/freebooks/sasp/Sinusoidal_Amplitude_Phase_Estimation.html),
checked 2026-09-15. No third-party implementation was copied. Selected-window
geometry, rank/work admission, factory limits and residual diagnostics are
Pythian contracts. Controlled signals are authored native data. Recorded checks
reuse the attributed CC0 VSCO 2 CE sources; their hashes and explicit window
choices remain in the [harmonic-fit evidence](SOURCES.md#harmonic-fitting-across-a-wav-interval).

The subsequent stationary-timbre style capability is native Pythian orchestration
of this fitter, existing style lineage and source factories. It stores measured
coefficients/diagnostics and applies explicit weighted harmonic magnitudes with
zero sine phase. Musical learning and generation retain the actual WFC models;
no additional solver, external fitting implementation or instrument assets are
bundled. [Saved timbre evidence](WAVE-STYLE.md#stationary-timbre-and-rendering)
retains the selected VSCO intervals, source hashes and remaining inference limits.
