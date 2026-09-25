# Bounded WFC harmony composition

[Home](../README.md) · [Architecture](ARCHITECTURE.md) ·
[Task](TODO/NS-4_composition_02.md) · [Work](WORK.md)

The portable [`pythian.music.compose`](../src/pythian.music.compose.pas)
accepts a caller-owned 16-bar chord schedule and generates an owned two-part
note sequence. It knows the schedule labels and its own seeded form/rhythm
rules. It does not claim to know how a caller obtained the schedule.

The optional [`pythian.wfc.compose`](../adapters/wfc/pythian.wfc.compose.pas)
adapter learns an order-2 open WFC model from up to eight complete chord-only
source schedules. Its 16-bar whole-path solve is constrained to a C opening,
G at bars 4/8/12/14, F at bar 13, and a C ending at bars 15/16. The source
model and constraints have a bounded latent-state reachability check before
the solve, including proof that at least one complete path differs from every
complete source progression. A solved path must differ from the fixed composer
schedule at two or more bars and change pitches in both parts. The adapter
reports source, model, token and event identities plus complete-path and
aligned four-bar phrase source comparisons. It preserves a caller's previous
output on failure.

The native [`pythian.wfc.composition`](../tools/pythian.wfc.composition.lpr)
consumer reads 1–8 lines of 16 whitespace-separated chord labels (`C`, `Am`,
`F`, `G`, `Em`) from a bounded text file. `#` lines are comments. The tracked
[first-party example](../examples/wfc-chord-sources.txt) contains eight chord
outlines and no authored note, bar, phrase or song audio. Build with
`./tools/build.ps1`, then run from the repository root using the executable in
the generated target directory (for example, `build/3.2.2-i386-win32`):

```text
build/3.2.2-i386-win32/pythian.wfc.composition.exe OUTPUT.wav examples/wfc-chord-sources.txt 1731
```

The consumer refuses an existing output path, writes a new WAV through a
temporary sibling, and prints provenance and the solve report to standard
output. The same native synthesis and articulation path is used for the
accepted source-free composer. The core build with `-CoreOnly` does not load
WFC. The separate `pythian.compose` tool can also accept a caller chord
schedule as a third argument for direct non-WFC comparison:

```text
pythian.compose OUTPUT.wav 1731 "C Am F G C Am Em G F G F G F G C C"
```

The frozen development model has eight sources, five public tokens and 13
states. Its first seed-1731 WFC path is a new complete progression and changes
three bars from the accepted fixed schedule. Three of four aligned chord
phrases occur in its source union; one phrase is new. The resulting 35.56-second
WAV changes 8 bass and 9 melody pitches against the accepted seed-1731
composition while keeping the same note timing. The producer, consumer and
WAV identities are in ignored `build/wfc-chord-composition/RESULT.md` and the
[work record](WORK.md). This is a core recording-free WFC composition exercise,
not recorded-WAV learning or genre style acceptance. Its musical listening
verdict and task credit remain pending.
