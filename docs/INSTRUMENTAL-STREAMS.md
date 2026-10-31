# Persistent instrumental synthesis

[Home](../README.md) · [Finite runtime](INSTRUMENTAL.md) ·
[Stream task](TODO/NS-6_instrumental-streams_01.md) · [Studio](OPERATOR-STUDIO.md)

The library now has a bounded WFC-to-instruments stream and a native caller that
saves sustained instrumental audio. **Studio still exposes finite 2–30-second
previews.** Its long-job, playback and output-resource integration remains open.
The new caller's example material is explicitly authored; it is not evidence of
recording-derived style quality.

## Musical graph and performance

```mermaid
flowchart LR
  C[Context WFC] --> M[Joint harmony / rhythm / named-voice WFC]
  M --> D[Independent rhythm-conditioned drum WFC streams]
  M --> P[Persistent Pascal instruments / buses / effects]
  D --> P
```

Each musical window defaults to **16 time cells**, each half a quarter note.
The context sequence is one bounded graph. Harmony, rhythm, ordered pitched
roles and harmonic coverage proofs use the companion's joint voices graph.
Each pass has the current window's `N × 1 × 1` shape; vocabulary sizes and
coverage-pass counts come from the actual models. Percussion uses one sequence
graph per drum constrained by the solved rhythm, with exact latent continuation
and the declared hit preferences. There is no invented giant fixed grid, extra
pinned-rhythm pass in those drum graphs, source-grain renderer or copied solver.

`TInstrumentalMusicStream` in `pythian.wfc.instrumental.stream` reuses the
companion voices stream and Pythian's existing sequence stream. Models and pitched
instruments are borrowed; the stream owns its percussion recipes. Only one
musical window, model frontiers and explicit future constraints are retained.
Sparse future edits cannot change already planned cells. A seed, segmentation,
clock, context binding, models and recipes define replay.

Context binding is explicit. `icbAllRoles`, the streaming default, retains the
joint context's complete symbolic role choices while WFC chooses its path and
the role graphs authenticate their own paths. `icbDrivenRole` constrains H/R and
the selected role while other roles remain free. Those freer frontiers can reach
incompatible continuations; small-window failures are retained evidence, not
hidden by restarting notes or looping audio. Neither mode promises arbitrary
future solvability. Finite context behavior retains its selected-role contract.

The portable `TInstrumentMusicStream` in `pythian.music.stream` has no WFC, browser,
file or playback-device dependency. It admits native rest/attack/hold frames into
the primary scheduler and instrument planner. Holds retain the actual sources,
oscillators, envelopes and effect history. Drum bindings are natural one-shots;
a later rest does not choke them. Each PCM pull is at most 2,048 stereo frames
and obeys the primary weighted-work bound. Music/tail extents each have a one-day
bound. Pause freezes state; Stop discards future output.

Shared chord validation replaces the preview's duplicate validator. Shared
scheduler batch admission stages every new source before releasing predecessors;
failed preparation/cancellation leaves existing sound intact. Processing or
post-render observation failure is terminal and returns no partial failed block.
The adapter also treats failed future planning as terminal. Previously returned
PCM remains identified by `Position`.

## Native caller

Compile `examples/pythian.example.instrumental.stream.lpr` with `src`,
`adapters/wfc` and `vendor/wfc/src` on the unit path. Supply explicit `-FU` and
`-FE` directories outside the checkout. Run:

```text
pythian.example.instrumental.stream OUTPUT.wav [SECONDS [SEED [BPM]]]
```

Defaults are 120 seconds, seed731 and120BPM, plus one second of release/effects.
Durations1–86,400 seconds and40–240BPM are accepted. The primary PCM16 writer
selects RIFF/RF64 for the declared extent. Output disk use grows with duration;
graph and PCM working storage do not. The JSON sidecar retains settings and
actual provider model texts. It describes this versioned authored example;
it is not a complete general-purpose instrument/style archive.

Native and actual pas2js fixtures exercise continuous note/echo performance,
pull-partition replay, layered admission failure, pause/stop/cancellation,
planning cancellation, partial final cells and24-hour clocks. Same-target
sample replay is exact; these fixtures do not claim identical native/JS WAV
bytes. `tools/check-synthesis-portability.ps1 -IncludeWfc` adds the WFC consumer
to the core portability checks. The maintained native build runs both callers.

Big Boss's saved two-minute consumer produced121 seconds including its tail,
30 planning windows,608 drum hits and12 peak active voices. Its WAV is an
audition artifact, not a musical-quality verdict. No generic WFC source change
was required; all musical binding and performance adaptation stays here.
