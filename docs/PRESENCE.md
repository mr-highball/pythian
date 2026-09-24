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
rest identity to use contrast evidence. Here a reviewed rest means no audible
instrument in the reference window; room or electronic noise may remain.
A window known only to lack one target instrument is a different comparison
and cannot be asserted as this API's reviewed rest. An unreviewed reference
yields `unknown` for nonzero candidates; exact digital zero remains directly
observable. A WAV
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

| Source role | Historical comparison window | Scored windows | Contrast output | Compatible output | False active | Missed active | Abstained known labels |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| Development player 01 | 1 | 2, 3 | 0 | 2 | 0 | 0 | 0 |
| Development player 02 | 4 | 5, 6 | 0 | 2 | 0 | 0 | 0 |
| Reserved player 05 | 9 | 7, 8 | 1 | 0 | 0 | 0 | 1 |

Clips 1 and 4 were audible `other_noise`, so they are reviewed **no-guitar**
comparisons, not reviewed generic rests for `pythian.presence`. The four
development `compatible_with_reviewed_rest` rows above are reproducible
historical scorer outputs but cannot be accepted as generic presence decisions.
Clip 9, heard as nothing, is the only reviewed no-instrument reference in
this packet. The table preserves what the frozen scorer emitted; its
false/missed columns are historical scoring counts, not calibrated generic
instrument accuracy for the development rows.

The reserved source was scored once on checked Win64 (TSV SHA-256
`9f8dbd121eb3379f8f43e435d4b3ffee3ddecd22ccd974ce326b49cb47724779`),
with zero leaks. Clip 7 is a correct contrast candidate; guitar-positive
clip 8 is `unknown`, an explicit coverage loss. Reference windows are excluded
from scoring. No source lacked a reference; all nine listener labels are known.
The fixed fourfold/1.5-fold observation ratios were not retuned.

This closes the source-bound acoustic-label and source-group convention in
[NS-3_notes_05](TODO/NS-3_notes_05.md) criterion 1 at this packet scope;
it does not validate clips 1 and 4 as generic rests.
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

## Stem-supported source-contribution control — 2026-09-23

The user-directed source-quality path screened a development-exposed URMP
Nocturne flute stem. The fixed annotation-only natural-rest screen found a
250-ms flute-note interior but no 250-ms flute rest with a half-second margin
and another active instrument in the first 30 seconds. Checked stable Pascal
stopped before PCM; two exact replays reported zero leaks. This does not
provide a microphone-style natural rest label.

A distinct controlled pair used the same original 16-kHz frames
`[35264,39264)` from three hash-bound recorded stems. One window contained
0.25 times violin and clarinet; the other contained the *identical* background
plus 0.25 times flute. Native Win32/Win64 verified source identity, no clipping
and the exact physical addition. The background RMS 0.008132706 and candidate
RMS 0.008577905 give a 1.054741761 contrast despite scaled flute RMS
0.003010764. The first runner incorrectly supplied `ReferenceReviewed=True`:
violin and clarinet in the comparison window make it **invalid as a generic
instrument rest**. Its rest-compatible report is rejected. Corrected Win32/
Win64 replay sets `ReferenceReviewed=False` and emits byte-identical `unknown`
reports (SHA-256
`deb3edfb626e981e113dde70ce053ffeee788ab23d34b6f8f0e89e0972dfdaa7`),
with zero leaks. This is a physical contribution check under active background,
not a valid generic presence score or human-audible miss. The source is exposed
development material; no independent recorded or phrase result is claimed.

The measured total-RMS change demonstrates that source contribution and
overall level differ under accompaniment. It does not justify lowering the
fourfold ratio or treating an omitted part as instrument-free rest. Generic
presence still needs a separately grounded no-instrument acoustic reference;
source-specific attribution belongs to later part ownership. Criterion 3
remains open.

The [MedleyDB publisher's annotation description](https://medleydb.weebly.com/description.html)
was screened as another possible reference route. Its stem activations are
derived from each stem's smoothed envelope and were not manually corrected;
some stems also contain bleed. Those labels can support a source-contribution
study but are not independent exact-window judgments of audible instrument
rest. No MedleyDB audio was acquired or promoted into this task's reference.

The distinct [MAPS Disklavier source](https://adasp.telecom-paris.fr/resources/2010-07-08-maps-database/)
offers audio-synchronized returned MIDI from a solo recorded piano, so a
key-up/pedal-up interval could support a physical rest candidate. A private
policy under ignored `build/maps-presence-source/` froze two full-piece works,
MIDI and PCM gates before source access. The 2,661,240,101-byte Zenodo object
was too slow for a proportional full transfer. A revised byte-range policy
stopped at its first 32-byte validator probe: HEAD had no ETag, and the valid
206 range response supplied neither ETag nor Last-Modified. No archive index,
MIDI, WAV or presence score was opened. The 209,244,160-byte interrupted
download is unverified; the publisher MD5 was not checked. This is an access
integrity stop, not evidence that MAPS lacks a usable rest. The partial file
remains in ignored build because automatic policy review rejected its removal.
Together with MedleyDB's dependent annotations, this is two nonclosing source
batches; stop the source-search sequence. Criterion 3 and task credit remain
open. The current paired Pythian listening comparison remains the next core
decision before selecting another source or algorithm batch.

## Full-recording isolated-stem source gate stopped — 2026-09-23

One prospective Pascal source screen used the entire 92.79-second isolated
flute track of URMP `14_Waltz_fl_fl_cl`, not a short excerpt. The ignored
`build/presence-full-recording/POLICY.md` froze work identity, 250-ms grid,
50-ms note interiors, 500-ms rest halos, companion F0 requirements, PCM
RMS/peak gates, score rule and stop condition before PCM scoring. Archive and
extracted Notes/F0/WAV hashes were bound. The distinct `40_Miserere` work was
reserved for independent use only after a development pass and remains unopened.

The 351 full-recording windows yielded 70 strong positive labels. Only five
windows had a note-free rest halo; three also had curator-zero F0 throughout
that halo. All three failed the fixed acoustic rest gate: their RMS values were
0.011170712, 0.009277533 and 0.010878819, versus the predeclared maximum
0.0001; peaks were 0.018951416, 0.022125244 and 0.018920898 versus 0.001.
The result is **zero qualified rest windows**, no nonzero rest reference, and
no presence score. A zero F0 annotation in this source is not evidence that
the PCM contains no audible instrument. No threshold, stem, gain or window was
changed after this result. The exact source, policy and 351-row report remain
ignored under `build/presence-full-recording/`. Salty Boi's checked stable
Win64 QA reproduced the report twice byte-identically (SHA-256
`ae07a08fa40fd68176ac31a2dde5cb45af7b69e35a998d1a71891d2a4b0cca4f`),
with zero unfreed blocks and no source-gate/scorer mismatch. No task criterion
or credit closes. The original-to-derived timing transformation remains
nominal, so the screen supports no exact release-end claim.

## GuitarSet physical pickup source gate stopped — 2026-09-23

The next source strategy used the [publisher's simultaneous original six-string
pickup and acoustic microphone recordings](https://guitarset.weebly.com/uploads/1/2/1/6/121620128/xi_ismir_2018.pdf)
rather than inferring silence from
note or F0 gaps. An ignored policy under `build/guitarset-hex-source/POLICY.md`
fixed the already user-reviewed player-05 clips 7, 8 and 9, their exact
11,025-frame windows, a 10% pooled pickup-RMS rest-to-positive gate, source
identities and a reserved player-00 follow-up before pickup PCM was opened.
The user heard guitar in 7 and 8 and nothing in 9. The 11,720,384-byte pickup
member was extracted from exact HTTPS byte ranges of the publisher ZIP;
its WAV SHA-256 is
`eb48ccb65285f741253f5690cc301bdf8acd78009d664eeff5cb11d6d3dc8ae0`,
and its ZIP CRC32 is 2,817,787,952. The full 3.2-GB archive was not downloaded,
so its published whole-archive MD5 was not verified. The microphone, review
and aid-manifest hashes were rechecked by the Pascal screen.

The six-channel pickup and mono microphone both contain 976,692 frames at
44.1 kHz. Pickup pooled RMS was 0.004066296 for clip 7, 0.000643569 for
clip 8, and 0.000150761 for clip 9. Thus clip 9 is about 23.4% of the quieter
positive clip 8 and fails the predeclared <=10% gate, although its microphone
RMS is only 0.003615834 versus 0.049499761 and 0.013056256 for 7 and 8.
The pickup residual is not itself an audible guitar verdict. The result is no
qualified physical no-guitar reference under this policy, and no presence
score. Do not shift these windows or relax the gate. Reserved player 00 and
other untouched groups remain unopened. The exact Pascal screen and TSV are
ignored under `build/guitarset-hex-source/`; criterion 3 stays open.
Salty Boi independently reproduced the checked stable Win64 report byte for
byte (SHA-256
`3fdc579f97da1e8a5e04f681f2b739272acdf2292926c6abdd25929814e75418`),
verified the hashes, CRC, geometry, listener bindings and RMS formula, and
reported zero unfreed blocks. No measurement defect was found.
