# Learned ensemble planning and streamed audio

[Home](../README.md) · [Chord renderer](CHORD-STREAMS.md) ·
[Negotiated layers](LAYERS.md) · [Provenance](PROVENANCE.md) · [Work](WORK.md)

The native ensemble example learns actual WFC harmony, rhythm and complete-voice
models from two authored four-bar phrases. It plans a bounded phrase with a
regular rhythm and a C-major ending, then realizes that plan through
`TWfcMusicEnsembleStream`. Pythian's incremental renderer preserves held chords
and bass notes across the generated segment boundaries.

This is a symbolic learning consumer. Recorded-WAV learning remains in the
[corpus](CORPUS.md) and [passage](PASSAGES.md) paths; this example does not infer
notes or chord labels from a recording.

The separate [independent-voice example](INDEPENDENT-VOICES.md) now exercises one
learned model per voice through WFC's voice graph and stream. It shares native
capacity validation, frame admission, exact clocks and the chord renderer.

## Model admission

`WfcEnsembleCapacities` in `pythian.wfc.music` scans the complete public vocabulary
of an actual ensemble model and returns detached maximum chord sizes by voice.
It retains silent slots, requires consistent voice count and checks all pitches
and velocities against the native preview contract before rendering begins.

Inspection allows at most 200000 public tokens and 200000 combined voice/tone
visits, at most 4096 voice slots and 4096 maximum tones across those slots. The
actual WFC decoder validates each token; one decoded frame is temporary before
the native size checks. Returned capacities survive model destruction. A rejected
scan preserves the caller's previous result. The native renderer separately
checks envelope work against these capacities. Learned edge/hold validity stays
with WFC's stream constructor.

## Native example

```text
pythian.ensemble.demo OUTPUT.wav [SEED [CELLS [SEGMENT_CELLS]]] [--verify]
```

Defaults are seed 731, 64 cells and five cells per segment. The tool accepts
4..1024 total cells and 1..64 cells per segment. The output clock is 44100 Hz,
480 PPQ, 240 ticks per cell and 500001 microseconds per quarter. This deliberately
exercises fractional frame carry. Eight cells form a four-quarter-note bar.

The [implementation](../tools/pythian.ensemble.demo.lpr) performs these steps:

1. Encode two independent 32-cell training phrases and learn order-2 models
   through `LearnSequenceModelCorpus`. The phrases use C–F–G–C and C–Am–F–G
   harmony with independent chord and bass attacks. No external music is bundled.
2. Use Pythian's existing layer adapter and actual WFC solver to plan the complete
   bounded ensemble path. Token domains preserve one chord attack per bar and
   bass attacks on quarter notes. The final pitch-class set is C major; observed
   start and end states are required. Harmony between those constraints is learned.
3. Project the plan into exact ensemble, rhythm and harmony constraints for the
   actual `TWfcMusicEnsembleStream`. Each yielded segment retains and validates
   its preceding latent state in all three models. This follows WFC's distinction
   between a developed plan and its streamed realization.
4. Feed each actual ensemble frame to `AdmitWfcEnsembleFrame` using one persistent
   native clock and renderer. Write detached blocks through `TWavePcm16Writer`.
   Ending a segment does not close voices; ending the full input drains elapsed
   duration without adding a release tail.

The phrase plan and sparse realization constraints are bounded by total cells.
Each realization graph is bounded by segment cells. PCM uses an 882-frame delay
and output blocks of at most 997 frames. There is no complete PCM clip allocation;
the example is not an unbounded or device-clock generator.

`--verify` also feeds WFC's actual preview renderer and compares every PCM sample
before writing it. The default operator mode avoids that second rendering pass.
The normal build includes the verified demo.

The `.wav.json` sidecar stores the clock, seed, guide, complete model text and
hashes, every segment seed/boundary, latent states and public tokens, final frame
count and verification flag. It contains no wall-clock timestamps or output paths.
Infeasible phrase planning rejects before opening output files. I/O or unexpected
realization failure after output begins can leave a partial WAV; WAV/sidecar
publication is not yet atomic.

## Why phrase planning precedes realization

An initial independently negotiated five-cell harmony/rhythm run reached the
companion's pass-retry limit at segment 5. A short independent provider choice
does not prove compatibility with the requested later ending. The final workflow
plans the correlated ensemble phrase through its learned model with explicit
rhythm and endpoint constraints, then realizes that plan. It does not raise the
stream's search budgets or silently relax constraints.

The complete `wfc_music_arrangement.pas` review also distinguishes its older
three-lane section iterator from ensemble continuation. It accepts source-owned
finite compositions, validates timing/signatures, carries a detached public-token
tail and delegates model-specific continuity to the source. Sections must begin
with an attack or rest, rather than a hidden melody hold. Those symbolic policies
remain in the companion. The ensemble stream's actual latent frontier is the
appropriate contract for sustained voices across audio segment boundaries.

## Evidence — 2026-09-14

Both FPC 3.2.2 and 3.3.1 i386-win32 compile and run the new example and capacity
checks. Existing music projection, clock and canonical SMF checks also pass.
No owned-unit compiler warning was reported; existing upstream warnings remain.

- Default output: 705601 mono frames, approximately 16.000023 seconds, eight bars,
  13 segments and 17 voice holds crossing segment boundaries. Every PCM sample
  matches WFC during verification.
- Changing segment size to seven yields ten segments and thirteen continued voice
  holds, with identical WAV bytes. This identity follows from the fixed phrase
  plan; it is not a general promise for unplanned WFC streams.
- Both compilers reproduce identical default WAV and complete sidecar bytes.
- A six-cell request contradicts the guide and observed-end constraints. It
  rejects before opening output and preserves the prior WAV and sidecar exactly.
- Capacity checks cover a chord larger than the initial frame, a silent voice,
  an unsupported vocabulary pitch, failed-result preservation and model ownership.

Artifact: `build/3.3.1-i386-win32/ensemble.wav`, SHA256
`911586f7f46fe4fa984703ed4b33668fa1e512408c01aeab3f717611e03bd418`.
Peak is 0.477478; RMS is 0.150210. Listening quality remains unevaluated.

Logs: `build/ensemble-stream-build.log`, `build/ensemble-stream-demo.log`,
`build/ensemble-stream-development.log`, `build/ensemble-stream-replay.log`,
`build/ensemble-stream-rejection.log`, `build/ensemble-stream-inspect.json`,
`build/ensemble-capacity-validation.log`, `build/ensemble-capacity-development.log`
and `build/ensemble-existing-music.log`.
