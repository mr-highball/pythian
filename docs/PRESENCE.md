# Source-grounded presence evidence

[Work record](WORK.md) · [Observation task](TODO/NS-3_notes_05.md) ·
[Event task](TODO/NS-3_notes_02.md)

Pythian keeps four different facts separate:

1. **Control:** a MIDI note-off or a dataset's annotated note end is a control
   event. It is not the audible endpoint.
2. **Signal:** a WAV window can contain exact digital zero, energy above a
   reviewed rest, or energy compatible with that rest. None alone identifies
   an instrument.
3. **Audible instrument:** a direct listener or independently supported
   acoustic label can identify instrument sound in an exact window. Static,
   room noise, and electronic noise remain different labels.
4. **Event:** an attack, continuation, release or rest decision combines
   qualified presence evidence with musical context and pitch. It is owned by
   [NS-3_notes_02](TODO/NS-3_notes_02.md), not by the observation API.

## First maintained observation boundary

`pythian.presence` measures an exact source-frame window and a disjoint
same-recording reference window. The caller must supply a source-bound reviewed
rest identity to use contrast evidence. An unreviewed reference yields `unknown`
for nonzero candidates; exact digital zero remains directly observable. A WAV
annotation alone cannot promote a reference to reviewed rest. Both windows have
a fixed 262,144-frame work cap. Clip and streaming-source entry points share
the same calculation; streaming coordinates use 64-bit frames. The observation
reports source geometry, RMS, peak and first/second-half RMS for the candidate,
reference RMS, exact frame coordinates, reviewed identity and
`pythian.presence.rest-contrast.v1` policy identity. It reports one of:

| Evidence | Meaning |
| --- | --- |
| `exact_zero` | Every candidate sample is digital zero. This says nothing about the note-off clock. |
| `above_reviewed_rest` | Candidate RMS is at least four times a nonzero reviewed-rest RMS. This is activity contrast, not proof of audible instrument sound. |
| `compatible_with_reviewed_rest` | Candidate RMS is at most 1.5 times that rest RMS. An instrument can still be buried there. |
| `unknown` | No reviewed rest, zero reference RMS with nonzero candidate, or contrast between the two fixed ratios. |

The ratios are a **source-free structural policy**, frozen before recorded
presence scoring. They are not calibrated audible-instrument thresholds. A
recorded evaluation must report unknown coverage and false/missed activity
against separately obtained acoustic labels. It may reject this policy without
changing the already exposed NSynth held-out results. No scorer may use this
unit's `above_reviewed_rest` alone to assert a note or boundary.

## Validation and stop gate — 2026-09-23

Checked stable FPC 3.2.2 Win32 and Win64 builds passed the focused
`pythian.tests.presence` controls: exact-zero gaps, quiet/short candidate
signals, a 30-ms 55-Hz quiet signal, fading envelope, rest-compatible noise, mixed
amplitudes, opposing stereo phases, unreviewed and exact-zero references,
overlap, source bounds, reviewed identity, work cap, repeated observation,
partial streaming read failure and 64-bit source coordinates. Both reported
zero unfreed blocks. The maintained `pythian.presence.inspect` WAV consumer
compiled on both targets. With hash-bound synthetic stereo `reference.wav`
(SHA256 `7c0c5a40979a39301ce4dc842d0caabd193dd120c6a474857404dd3505472022`),
both emitted the same TSV row for frames 70,000–170,000 and an unreviewed
reference at frames 0–24,000. The 100,000-frame observation crosses the
65,536-frame WAV read chunk, preserves 24-kHz/2-channel/264,000-frame source
geometry, and reports `unknown`. The low 55-Hz signal also reports `unknown`
at peak 0.005 against a 0.001-RMS reference: its finite RMS is retained, but
the fixed fourfold contrast does not admit it. A wrong source hash exits nonzero
before any TSV row. These checks validate the boundary and failure behavior, not audible
instrument detection, source-independent calibration, or event accuracy.

The criterion's recorded development/independent cases and calibrated
false-active/missed-active/unknown coverage remain open. GuitarSet's stopped
packet and previously exposed NSynth test/train groups remain protected.
