# Fundamental synthesis capability and evidence map

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[Quality review](SYNTHESIS-QUALITY.md) · [Milestones](MILESTONES.md#fund-contracts)

This map connects the native synthesis suite to its public contracts, consumers
and meaningful checks. It is a supported-capability inventory, not a claim that
every possible synthesis technique or host integration is implemented. The
portable `pythian` core owns these capabilities without WFC or playback-device
types. Actual WFC learning and saved-style adapters are consumers of this core.

## Supported capability families

Detailed limits and ownership live in the linked contracts. Fixture links identify
what exercises a boundary; they do not assert a fresh test run or broaden its
coverage. [Delivery evidence](PACKAGING.md) binds historical complete-build and
package results to snapshots; subsequent focused evidence is identified separately.

| Capability / public contract | Consumer and boundary evidence | Scope to preserve |
| --- | --- | --- |
| [Audio data and WAV](ARCHITECTURE.md#audio-data-and-wav), [bounded reading](WAVE-READING.md) | [Core example](../examples/pythian.example.core.lpr); [reader fixture](../tests/pythian.tests.wave.read.lpr), [writer fixture](../tests/pythian.tests.wave.stream.lpr) | Owned finite sample data; mono/stereo; validated RIFF/RF64 input and PCM16 output. Distinguish container admission from validation of every sample, logical position from physical stream position, and argument errors from poisoned I/O state. |
| [Musical clocks and MIDI](MIDI.md), [streamed MIDI](MIDI-STREAMS.md) | [Notes example](../examples/pythian.example.notes.lpr), [stream example](../examples/pythian.example.midi.stream.lpr); [clock](../tests/pythian.tests.clock.lpr), [export](../tests/pythian.tests.midi.export.lpr) and [stream](../tests/pythian.tests.midi.stream.lpr) fixtures | Exact tick/frame conversion under declared tempo maps, deterministic note ordering, bounded codecs and stream delays. Device clock synchronization is host-owned. |
| [Oscillators, resampling and granular playback](DSP.md) | [Resample](../tests/pythian.tests.resample.lpr), [continuous conversion](../tests/pythian.tests.resample.stream.lpr), [granular](../tests/pythian.tests.granular.lpr) fixtures | Declared oscillator quality and conversion policies; bounded taps/work and preserved history across blocks. Separate pitch/rate conversion from automatic tempo-preserving source analysis. |
| [Sources, sample regions and sustain loops](SOURCES.md) | [Source](../tests/pythian.tests.source.lpr) and [loop](../tests/pythian.tests.sample.loop.lpr) fixtures; [instrument example](../examples/pythian.example.instrument.lpr) | Immutable factory definitions create independent playing state; exact gate delivery; sample intro/sustain/tail and interpolation policy. Caller-selected loop boundaries do not imply automatic seamless-loop discovery. |
| [Wavetables and measured harmonics](SOURCES.md#harmonic-limited-wavetable-construction), [declared phase](SOURCES.md#phase-harmonic-fitting), [spectral motion](SOURCES.md#spectral-trajectory-checkpoint) | [Source fixture](../tests/pythian.tests.source.lpr); [saved-style consumer](../tests/pythian.tests.wave.style.lpr) in the WFC companion | Harmonic-limited synthesis, bounded fitting and independent shape/level controls. Explicit source evidence and numerical residual are not automatic pitch, instrument or recording admission. |
| [Envelopes, automation, additive synthesis and FM/PM](MODULATION.md) | [Modulation](../tests/pythian.tests.modulation.lpr) and [control-curve](../tests/pythian.tests.control.curves.lpr) fixtures | Declared note-relative frame curves and control bounds; borrowed immutable definitions versus owned playing state. Scoped oversampling evidence does not prove arbitrary modulation bandwidth. |
| [Layered instruments](INSTRUMENTS.md) | [Instrument](../tests/pythian.tests.instrument.lpr), [music-instrument](../tests/pythian.tests.music.instrument.lpr) fixtures; instrument example above | Explicit key/velocity zones and overlapping layers; preflight before plan publication; borrowed voice definitions. No automatic level normalization or inferred source role. |
| [Filters, dynamics and effect chains](EFFECTS.md) | [Processing example](../examples/pythian.example.processing.lpr); [effects fixture](../tests/pythian.tests.effects.lpr) | Stateful stereo processing, deliberate tail lengths and headroom. Chains own accepted stages; downstream processing failure preserves caller output but requires successful reset before reuse. |
| [Echo and buses](BUSES.md), [modulated delay](MODULATED-DELAY.md), [reverb](REVERB.md) | [Bus](../tests/pythian.tests.bus.lpr), [modulated-delay](../tests/pythian.tests.delay.modulated.lpr), [reverb](../tests/pythian.tests.reverb.lpr) fixtures | Ordered acyclic routing with explicit sends and effect-local feedback; bounded histories/costs and reset semantics. Muting does not erase a return's history. |
| [Scheduling and bounded tone streams](SCHEDULING.md), [chord streams](CHORD-STREAMS.md) | [Scheduler](../tests/pythian.tests.schedule.lpr) and [chord-stream](../tests/pythian.tests.chord.stream.lpr) fixtures | Shared synthesis path, future edits/cancellation/replacement, deterministic seeds and bounded readers. Admission can allocate; state may advance before a runtime fault poisons the consumer. |

## Support decisions and outstanding evidence

- **WAV files:** reading supports seekable streams and the encodings/layouts in
  the reader contract. Compression, additional speaker layouts, metadata
  round-trip and non-seekable decoding are unsupported. No consumer requirement
  currently justifies treating every codec as a completion prerequisite.
- **File replacement:** `SaveWavePcm16` validates before opening the destination,
  but a later I/O failure can leave a partial file. Stream writers likewise do
  not undo physical writes. Operators that stage output protect against their
  documented validation failures; final-copy atomicity is not promised. Any
  consumer requiring durable destination preservation needs an explicit file
  publication contract and fault evidence before that guarantee is offered.
- **Instrument policy:** range gaps, overlapping-zone gain, loop endpoints and
  release policy are explicit caller choices. Automatic loop selection, voice
  stealing, round robin/crossfade groups and external instrument-bank imports
  are unsupported extensions. Add one when a declared consumer needs it, with
  its own ownership/time contract; do not silently imply it from “instrument.”
- **Runtime integration:** built-in processing has bounded work and explicit
  recovery, but allocation-free callbacks, hard device deadlines, host latency
  compensation and shared hardware clocks are not established. Playback remains
  outside the core. Offline success is insufficient evidence for those promises.
- **Formats and adapters:** preserve one current native contract per artifact.
  Optional capabilities extend the current contract; retained historical readers
  require a concrete consumer need. Core/companion packages are dependency subsets.

The declared-phase fitter now has three-target source checks plus a checked
saved-style and recorded-generation consumer regression. Its public contract and
evidence are consolidated in [Sources](SOURCES.md#phase-harmonic-fitting).
The latest source packages still predate that addition and the recent layer
changes; [WAV-05-DELIVERY](MILESTONES.md#wav-05-delivery) owns their refresh.

The [combined workload](SYNTHESIS-QUALITY.md#combined-workload-checkpoint) now
checks four source families, modulation, a changing tempo, sample release,
spectral motion and a shared reverb bus through direct and scheduled rendering.
Exact replay passes at three read sizes and across three compiler targets;
native WAV conversion additionally preserves duration/read-size replay at
44.1/48 kHz. Its declared 40-note scope and work limits are recorded with the
evidence; this is a completed combined-consumer check, not universal composition
or device-performance acceptance.

The subsequent [automation work review](SCHEDULING.md#automation-work-admission--2026-09-20)
found and corrected a missing charge for the five voice automation controls.
Admission/replacement and stream/offline budgets now include those evaluations.
Three-target combined replay remains exact with the corrected reservation;
over-budget replacement preserves pending audio.

<a id="contract-review"></a>
## Contract review accepted — 2026-09-20

**FUND-CONTRACTS is complete for the supported native suite defined above.** The
review retains the pre-existing scope and exclusions. It covers all ten capability
families, their public ownership/failure contracts, mapped consumers and declared
workload limits. It does not certify every simultaneous maximum configuration or
extend numeric checks into a listening verdict.

| Reviewed boundary | Decision and supporting evidence |
| --- | --- |
| Data and publication | Finite owned mono/stereo clips, bounded WAV decoding/encoding and MIDI event streams have explicit units, size limits and ownership. Reader/writer fixtures distinguish invalid requests from irreversible I/O failure. Seekable WAV input, declared output length, host-owned sinks and possible partial output remain explicit supported-contract decisions. No durable file-replacement promise is made. |
| Musical time and composition | Integer PPQ/frame clocks, detached plans, zone expansion, release overlap and scheduler replacement have independent timing/audio references. The combined 40-note passage connects changing tempo, four source families and six buses; instrument checks additionally cover overlapping zones and expansion rejection. Authored timing does not imply inferred musical context. |
| Source and control work | Factory range/cost checks, sample step/tap limits, harmonic fitting/trajectory bounds, curve depth and envelope limits are accounted for in their consumers. The omitted voice-automation charge is corrected and checked before source construction. Static filter stability and bounded modulation remain the documented claims; arbitrary automation is not promised alias-free. |
| Processing failure and recovery | Direct DSP calls validate candidate state where their contracts promise retryability. Chains and scheduled/streamed pipelines retain their documented failed state after partial advancement. Existing fault fixtures cover output preservation, reset or terminal failure, ownership and reentrancy. Physical sink writes and consumed upstream frames cannot be rolled back by those guarantees. |
| Storage and sustained work | Finite clip/event limits, voice reservations, per-call render budgets, delay histories and converter caches remain separate bounds. Tone streams avoid full-duration PCM allocation; continuous conversion retains filter history across blocks. The 2h17m conversion establishes one long-source workload, while the combined synthesis, instrument and FM/PM studies establish their named workloads. Parameter ceilings are validation limits, not promised throughput at every combination. |

The review checked the current source contracts and fixture assertions against
the terminal [clean-snapshot build](PACKAGING.md#clean-source-snapshot) and
the later focused evidence. A raw-content comparison of all core units against
`build/delivery-trajectories/checkout/src` finds only two changed units:
`pythian.source.wavetable` (declared-phase harmonic fitting) and `pythian.synth`
(automation work accounting). Their three-target checks and affected consumer
results are recorded in [Sources](SOURCES.md#phase-harmonic-fitting) and
[Scheduling](SCHEDULING.md#automation-work-admission--2026-09-20). The other 79 core
units retain the snapshot's source content. This justifies reuse of the existing
complete-build evidence; it is not a new package or complete-build run.

Current source hashes, the changed-file list and hashes of reviewed terminal logs
are ignored under `build/fundamental-contract-review/`. No implementation or
supported range changed during this final review. No additional missing primitive
is required by the declared consumer paths. A future consumer that needs an
unsupported capability must establish its requirement explicitly; it does not
keep this completed contract review permanently open.

[FUND-QUALITY](MILESTONES.md#fund-quality) owns the remaining combined listening
verdict and any demonstrated signal defects. Delivery owns refreshed packages and
target acceptance; NS-3 owns automatic musical inference. A new failure in a
supported path reopens the relevant contract with concrete evidence. These
remaining outcomes are not waived by closing FUND-CONTRACTS.
