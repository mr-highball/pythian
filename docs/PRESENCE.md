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

At this validation point, recorded development/independent cases and calibrated
false-active/missed-active/unknown coverage remained open. Earlier stopped
GuitarSet packets and previously exposed NSynth test/train groups remained
protected.

Fresh focused acceptance on 2026-09-23 rebuilt the maintained observation
unit, tests and WAV inspector with checked stable FPC 3.2.2 Win32/Win64.
Both tests passed with zero unfreed blocks. The hash-bound 100,000-frame
consumer observation above produced identical TSV bytes across targets
(SHA-256 `22639cfffd9a372c9aed7bbdfaa5cd0a10196b18ac2e9ca4aa0ddc803c08b327`)
and preserved `unknown` and original source coordinates. A wrong SHA-256
exited before output. The inspector now hashes the complete input again after
observation and before output; fresh checked Win32/Win64 builds preserve the
same TSV bytes and zero-leak result. This second full-file pass is part of its
cost. This meets the API and consumer acceptance criteria of
[NS-3_notes_05](TODO/NS-3_notes_05.md) at their source-free scope; it does not
meet the remaining source-grounded acoustic and recorded-calibration criteria.

## First listener-bound GuitarSet comparison — 2026-09-23

A later frozen packet selected three player and musical-family groups from
GuitarSet before opening their microphone audio. The user reviewed nine
unchanged-gain, repeated 250-ms source windows, then clarified that clips
1, 4, 5 and 6 sounded piano/keyboard-like rather than like guitar. Those
four are listener-labelled `other_noise`: audible sound without identified
guitar, **not** a claim that a piano was physically recorded. Clips 2, 3 and
9 were inaudible (`nothing`); 7 and 8 sounded like acoustic guitar (`guitar`).
The note-control phases and original microphone identities did not override
these acoustic labels. The original replies and normalized labels are kept
separately under ignored `build/`.

Checked stable Pascal Win32/Win64 binders verified the frozen aid manifest and
all nine WAV hashes, then emitted byte-identical source-bound reviewed TSVs
(SHA-256 `22e8589b58fe2ed54afeeb839fae076eebd154648461503fe35c5d2cb913aa7c`),
with zero leaks. The unchanged production scorer rechecked the reviewed and
normalized input, every aid hash and original WAV identity before output.
The development scorers agree byte for byte across Win32/Win64 (SHA-256
`05bd16a0e0986c8918325ea85148d72c4f0d58cce10ee24dadbaf99af11e288a`).

| Source role | Reviewed same-source rest | Scored windows | Correct contrast | Correct rest-compatible | False active | Missed active | Abstained known labels |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| Development player 01 | 1 | 2, 3 | 0 | 2 | 0 | 0 | 0 |
| Development player 02 | 4 | 5, 6 | 0 | 2 | 0 | 0 | 0 |
| Reserved player 05 | 9 | 7, 8 | 1 | 0 | 0 | 0 | 1 |

The reserved source was scored once on checked Win64 (TSV SHA-256
`9f8dbd121eb3379f8f43e435d4b3ffee3ddecd22ccd974ce326b49cb47724779`),
with zero leaks. Clip 7 is a correct contrast candidate; guitar-positive
clip 8 is `unknown`, an explicit coverage loss. Reference windows are excluded
from scoring. No source lacked a reference; all nine listener labels are known.
The fixed fourfold/1.5-fold observation ratios were not retuned.

This closes the source-bound listener-reference convention in
[NS-3_notes_05](TODO/NS-3_notes_05.md) criterion 1 at this packet scope.
Its original development sources have **no scored guitar-positive windows**,
so they cannot establish positive detection or calibration. The two originally
reserved positive windows yield one candidate and one abstention, not
independent phrase accuracy. Criterion 3 and task credit remain open. The
exposed player-05 source can now serve as development evidence, while a
replacement rule requires fresh independent validation. Player 05 cannot be
recycled as held-out evidence after tuning.

## Fresh player-03 listener result — 2026-09-23

The prospectively frozen player-03 Rock2-85-F solo packet exposed three 250-ms
windows: the last 250 ms of one annotated note and the first two successive
250-ms windows after its end. The user heard guitar-like sound in 12, guitar
with slackened strings in 13, and sliding guitar strings in 14. All three are
listener-labelled `guitar`; the descriptions do not establish an actual change
in string tension. In particular, an annotation end did not establish audible
rest in either adjacent window.

Checked Pascal Win32/Win64 binders verified the aid manifest and produced an
identical reviewed packet (SHA-256
`f15b461752b4e0192a7a6a983fe7ef856ad0fe86cc0c34ded7b4ae77cff45c7b`).
The frozen source-local reference rule found no listener-confirmed no-guitar
window. Checked Win32/Win64 scorer reports agreed byte-for-byte (SHA-256
`123d517bdecc7eb4a0836cc92e032b2e69e5b7faa4b55419be10c23a2fb06deb`)
and marked all three `not_observed`/`no_reference`. There was no presence
inference result to accept or reject. Both binder and scorer targets reported
zero leaks. Player 03 is acoustically exposed and cannot serve as a fresh
held-out source after a changed rule. Criterion 3 remains open.

A subsequent fixed player-04 BN2-166-Ab annotation-only screen sought a
250-ms final-note window and a distant 1.0–1.25-second post-end window with
no other note across the union. Checked stable Pascal verified its JAMS hash
and 48 note extents but found no eligible event, with zero leaks. It stopped
before microphone extraction, listening aids or presence scoring. No further
acoustic claim follows from that screen.

## Dataset evidence allocation — 2026-09-23

The user wants recorded-dataset quality to bear the labeling burden and their
listening time reserved mainly for Pythian's generated music. The already
reviewed GuitarSet windows retain their exact acoustic labels, but no further
routine GuitarSet microclip review is planned. The earlier suggested budget of
eight additional user labels is withdrawn.

The [GuitarSet authors' annotation method](https://guitarset.weebly.com/uploads/1/2/1/6/121620128/xi_ismir_2018.pdf)
supports carefully checked performed-note onsets: the six-string pickup gave
per-string recordings, and annotators corrected onsets and omitted masked
muted-string events. Offsets were estimated automatically. The microphone WAV
used by Pythian was a separate capture. Therefore these annotations can
support a source-bound played-note hypothesis, but cannot by themselves
establish that an exact microphone window contains audible guitar or audible
rest. The [publisher release](https://zenodo.org/records/3371780) lists two
timing errors and a duplicate-note error; source qualification must account
for them. Future reference candidates need independently supported acoustic
labels, verified source identity and disjoint evaluation groups. Where that
evidence is absent, retain `unknown` and leave recorded decision acceptance
open. No synthetic-output listening judgment is inferred from these source
checks.
