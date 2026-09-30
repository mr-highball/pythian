# Caller-owned synthesis extensions

This asset-free example supplies its own source factory and stateful stereo
processor using public Pythian core interfaces. It exercises scheduling and
streaming; it is mechanical conformance evidence, not outside-user qualification
or listening acceptance. No WFC, tools, engine or playback device is needed.

From the extracted package root, create `build/units` and `build/bin`, then run:

```text
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuexamples -FUbuild/units -FEbuild/bin examples/pythian.example.extensions.lpr
build/bin/pythian.example.extensions extended.wav
fpc -B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuexamples -FUbuild/units -FEbuild/bin tests/pythian.tests.extension.conformance.lpr
build/bin/pythian.tests.extension.conformance build/conformance
```

Windows executables have `.exe` suffixes. Quote paths containing spaces. The
consumer accepts `FRESH.wav [MIX [WET [SEED [BLOCK_FRAMES]]]]`. MIX and WET are
finite dot-decimal 0..1, defaults 0.35 and 0.3; seed is unsigned decimal
0..4294967293, default 731; read cap is 1..2048 frames, default 257. MIX changes
the normalized second harmonic; WET changes cross-channel delayed amplitude.
The three seeds are consecutive. Output is 16000 Hz, stereo, 16240 frames:
16000 authored timeline frames plus the complete 240-frame delay tail.

The [caller unit](../examples/pythian.example.extension.units.pas) implements
`TCallerHarmonicFactory`/its private playback source and `TCallerStereoDelay`.
The [consumer](../examples/pythian.example.extensions.lpr) runs both paths and
reloads the actual saved WAV, checking geometry and every decoded sample against
the rendered PCM16 expectation. The [conformance program](../tests/pythian.tests.extension.conformance.lpr)
checks independent instances, reset/release, boundaries, policy admission,
nonfinite failures and replay. Its generated files may be regenerated; they are
not references for musical quality.

## Ownership and recreation

The factory is immutable and caller-owned. It must outlive all scheduled or
streamed sources that borrow it. Each `CreateSource` returns a distinct instance
owned by the scheduler or stream. Copy configuration by explicitly constructing
another factory; no generic library `Clone` method exists. Source `Reset`
restores initial phase and release state. `NoteOff` is idempotent; the envelope
owns amplitude release, so the oscillator remains usable throughout that tail.
Second-harmonic frequency must remain strictly below Nyquist.

A successful `TEffectChain.Add` transfers the effect to that chain only. Never
free or add the accepted effect elsewhere. This finite feed-forward delay stores
input history, with no feedback. Retain one chain across all streamed blocks;
append exactly DelayFrames zeros once after the complete input, not after every
block. Dropping those zeros deliberately truncates the tail. The impulse fixture
verifies the last delayed sample and exhaustion; actual chain `Reset` clears
history and failure. Graph reset delegates to its chains. No runtime source or
effect references are shared between playback instances.

## Work and failures

`FrameCost` is a caller-declared conservative weighted policy, not a measured
CPU-time bound. For this bounded implementation the source declares 64 units
and reports 55 per successful frame; the delay declares 16 and reports 14.
These fixed weights cover the authored signal operations, including validation,
sine evaluation and ring-buffer accesses. Optional probe bookkeeping and
allocation/reset/setup work are excluded. Counts are explicit policy weights,
not instruction or hardware-cycle measurements. The observer is optional,
caller-owned and must outlive everything borrowing it; it has no hidden globals.
Changing the implementation requires reviewing this policy declaration.
Scheduling/streaming and effect rendering account for their additional framework
costs separately. Conformance over-declares valid expensive work to prove
rejection before source creation/effect processing. This does not isolate or
meter arbitrary caller code, and establishes no hard real-time deadline.

Invalid range/control/admission and future replacement failures preserve
accepted scheduling state; invalid read size preserves healthy stream progress.
A processing exception or nonfinite output poisons the scheduler, stream or
chain at the relevant layer. Outputs/progress are not published, but earlier
source/effect state may have advanced: there is no processing rollback.
Scheduler/chain reset clears their owned state. Streams have no reset API;
free and recreate them. A persistently defective extension must be replaced;
reset cannot repair its implementation. The fixtures distinguish rejected
admission from processing poisoning and verify subsequent correct recovery.

Fixed inputs/seed replay through the same streamed path produces identical
PCM16 bytes for read caps 1, 7, 257 and 2048 on each checked target. Scheduled
bus effects run before the final Single conversion; streamed blocks convert to
Single before the retained caller chain, so cross-path comparison allows two
PCM16 steps (2/32768). That tolerance is separate from exact streamed replay.

The consumer requires a fresh `.wav` in an existing parent and rejects invalid
arguments before writing. It preserves existing files. Direct saving may leave
a partial new file after an I/O failure or interruption; concurrent publishers,
power-loss atomicity and automatic recovery are unsupported. Listening, an
independent consumer's actual use, and matching published package evidence remain
separate acceptance gates. The library task receives no partial credit.
